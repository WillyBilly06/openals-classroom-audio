#include "source_udp_stream.h"

/*
 * VLAN/unicast discovery/audio support.
 *
 * This file is intentionally self-contained. Some versions of the project have
 * main/source_raud_config.h and some do not. If that header exists, we include
 * it for the original RAUD settings/keys. If it does not exist, the defaults
 * below are used so this file can still compile in the default project.
 */
#if defined(__has_include)
#  if __has_include("source_raud_config.h")
#    include "source_raud_config.h"
#    define RAUD_HAS_EXTERNAL_CONFIG 1
#  endif
#endif
#ifndef RAUD_HAS_EXTERNAL_CONFIG
#  define RAUD_HAS_EXTERNAL_CONFIG 0
#endif

#ifndef RAUD_ENABLE_UDP_STUDENT_AUDIO
#define RAUD_ENABLE_UDP_STUDENT_AUDIO        1
#endif
#ifndef RAUD_ENABLE_MULTICAST_DISCOVERY
#define RAUD_ENABLE_MULTICAST_DISCOVERY      1
#endif
#ifndef RAUD_ENABLE_MULTICAST_AUDIO
#define RAUD_ENABLE_MULTICAST_AUDIO          1
#endif
#ifndef RAUD_ENABLE_UNICAST_FALLBACK
#define RAUD_ENABLE_UNICAST_FALLBACK         0
#endif
#ifndef RAUD_ENABLE_MULTICAST_LOOPBACK
#define RAUD_ENABLE_MULTICAST_LOOPBACK       0
#endif
#ifndef RAUD_ENABLE_MULTICAST_SELFTEST
#define RAUD_ENABLE_MULTICAST_SELFTEST       0
#endif

#ifndef RAUD_DISCOVERY_MCAST_ADDR
#define RAUD_DISCOVERY_MCAST_ADDR            "239.10.10.1"
#endif
#ifndef RAUD_DISCOVERY_PORT
#define RAUD_DISCOVERY_PORT                  6969
#endif
#ifndef RAUD_AUDIO_MCAST_ADDR
#define RAUD_AUDIO_MCAST_ADDR                "239.10.10.10"
#endif
#ifndef RAUD_AUDIO_PORT
#define RAUD_AUDIO_PORT                      6970
#endif
#ifndef RAUD_MCAST_TTL
#define RAUD_MCAST_TTL                       2
#endif

#ifndef RAUD_APP_BLOCKS_PER_PACKET
#define RAUD_APP_BLOCKS_PER_PACKET           5
#endif
#ifndef RAUD_APP_PACKET_MS
#define RAUD_APP_PACKET_MS                   40
#endif
#ifndef RAUD_APP_TARGET_JITTER_MS
#define RAUD_APP_TARGET_JITTER_MS            200
#endif
#ifndef RAUD_ENABLE_STA_MULTICAST_AUDIO
#define RAUD_ENABLE_STA_MULTICAST_AUDIO      1
#endif
#ifndef RAUD_ENABLE_AP_MULTICAST_AUDIO
#define RAUD_ENABLE_AP_MULTICAST_AUDIO       0
#endif
#ifndef RAUD_APP_CHANNELS
#define RAUD_APP_CHANNELS                    2
#endif
#ifndef RAUD_APP_SAMPLE_RATE
#define RAUD_APP_SAMPLE_RATE                 48000
#endif
#ifndef RAUD_APP_BLOCK_SAMPLES
#define RAUD_APP_BLOCK_SAMPLES               384
#endif
#ifndef RAUD_APP_BLOCK_US
#define RAUD_APP_BLOCK_US                    8000
#endif
#ifndef RAUD_APP_CODEC_SBC
#define RAUD_APP_CODEC_SBC                   1
#endif
#ifndef RAUD_APP_KEY_ID
#define RAUD_APP_KEY_ID                      1
#endif
#ifndef RAUD_APP_SBC_BITRATE_KBPS
#define RAUD_APP_SBC_BITRATE_KBPS            249
#endif
#ifndef RAUD_APP_SBC_BLOCK_BYTES_MAX
#define RAUD_APP_SBC_BLOCK_BYTES_MAX         300
#endif
#ifndef RAUD_APP_PAYLOAD_BYTES_MAX
#define RAUD_APP_PAYLOAD_BYTES_MAX           (RAUD_APP_BLOCKS_PER_PACKET * RAUD_APP_SBC_BLOCK_BYTES_MAX)
#endif
#ifndef RAUD_FLAG_ENCRYPTED
#define RAUD_FLAG_ENCRYPTED                  0x00000001u
#endif
#ifndef RAUD_FLAG_AUTHENTICATED
#define RAUD_FLAG_AUTHENTICATED              0x00000002u
#endif
#ifndef RAUD_FLAG_MONO
#define RAUD_FLAG_MONO                       0x00000004u
#endif

#if !RAUD_HAS_EXTERNAL_CONFIG
#error "Copy source_raud_config.h.example to source_raud_config.h and set fresh keys"
#endif

#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <string.h>

#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include "lwip/inet.h"
#include "lwip/sockets.h"
#include "mbedtls/aes.h"
#include "mbedtls/cipher.h"
#include "mbedtls/cmac.h"
#include "source_config.h"
#include "source_wifi.h"

#define RAUD_MAGIC 0x44554152u
#define RAUD_VERSION 1
#define RAUD_MSG_DISCOVERY 1
#define RAUD_MSG_AUDIO 2
#define RAUD_MSG_DISCOVERY_PROBE 3
#define UDP_SBC_QUEUE_DEPTH 2
#define UDP_APP_QUEUE_DEPTH 2
#define RAUD_UNICAST_MAX_CLIENTS 4
#define RAUD_UNICAST_CLIENT_TTL_US (15LL * 1000LL * 1000LL)

typedef struct {
    uint32_t seq;
    uint32_t capture_us;
    uint16_t len;
    uint8_t sbc[RAUD_APP_SBC_BLOCK_BYTES_MAX];
} udp_sbc_block_t;

typedef struct {
    uint32_t first_seq;
    uint32_t first_capture_us;
    uint16_t sbc_block_bytes;
    uint16_t payload_len;
    uint8_t payload[RAUD_APP_PAYLOAD_BYTES_MAX];
} udp_app_plain_t;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint8_t version;
    uint8_t type;
    uint16_t header_len;
    uint8_t source_id[16];
    uint32_t stream_id;
    uint32_t first_seq;
    uint8_t codec;
    uint8_t channels;
    uint16_t sample_rate;
    uint16_t block_samples;
    uint16_t block_us;
    uint8_t block_count;
    uint8_t packet_ms;
    uint16_t sbc_block_bytes;
    uint16_t payload_len;
    uint32_t key_id;
    uint32_t flags;
    uint8_t nonce[16];
} raud_audio_hdr_t;

typedef struct {
    raud_audio_hdr_t hdr;
    // Wire format is: header + payload_len bytes + 16-byte CMAC tag.
    // Keep the tag directly after the variable-length payload in this same
    // buffer so sendto(&pkt, pkt.len) sends the correct bytes.
    uint8_t payload[RAUD_APP_PAYLOAD_BYTES_MAX + 16];
    size_t len;
} udp_app_packet_t;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint8_t version;
    uint8_t type;
    uint16_t length;
    uint8_t source_id[16];
    uint32_t stream_id;
    char room_code[9];
    char room_name[32];
    uint32_t source_ip;
    uint16_t http_port;
    char audio_group[16];
    uint16_t audio_port;
    uint8_t codec;
    uint16_t sample_rate;
    uint8_t channels;
    uint8_t packet_ms;
    uint8_t block_count;
    uint16_t sbc_block_bytes;
    uint32_t key_id;
    uint32_t flags;
    uint32_t counter;
    uint8_t tag[16];
} raud_discovery_advert_t;

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint8_t version;
    uint8_t type;
    uint16_t length;
    uint8_t client_id[16];
    uint16_t audio_port;
    uint8_t reserved[14];
    uint32_t flags;
    uint8_t tag[16];
} raud_discovery_probe_t;

typedef struct {
    uint32_t ip;
    uint16_t port;
    int64_t last_seen_us;
} raud_unicast_client_t;

static const char *TAG = "raud_udp";
static QueueHandle_t s_sbc_q;
static QueueHandle_t s_app_q;
static volatile uint32_t s_stream_id;
static uint8_t s_source_id[16];
static volatile uint16_t s_sbc_block_bytes;
static volatile uint32_t s_discovery_adverts_sent;
static volatile uint32_t s_discovery_counter;
static volatile uint32_t s_discovery_probes_rx;
static volatile uint32_t s_discovery_selftest_rx;
static volatile uint32_t s_discovery_unicast_replies_sent;
static volatile uint32_t s_audio_packets_built;
static volatile uint32_t s_audio_packets_sent;
static volatile uint32_t s_audio_packets_dropped_queue;
static volatile uint32_t s_audio_packets_dropped_congestion;
static volatile uint32_t s_audio_crypto_fail;
static volatile uint32_t s_audio_socket_send_fail;
static volatile uint32_t s_sbc_blocks_dropped;
static volatile uint32_t s_unicast_clients_registered;
static volatile uint32_t s_unicast_audio_sent;
static volatile uint32_t s_unicast_audio_send_fail;
static raud_unicast_client_t s_unicast_clients[RAUD_UNICAST_MAX_CLIENTS];

static void ensure_source_identity(void)
{
    static bool ready;
    if (ready) {
        return;
    }
    uint8_t mac[6] = {0};
    (void)source_wifi_get_sta_mac(mac);
    memcpy(s_source_id, mac, sizeof(mac));
    memcpy(s_source_id + 6, "RAUDSRC", 7);
    s_source_id[13] = mac[3];
    s_source_id[14] = mac[4];
    s_source_id[15] = mac[5];
    uint32_t stream = ((uint32_t)mac[2] << 24) | ((uint32_t)mac[3] << 16) |
                      ((uint32_t)mac[4] << 8) | mac[5];
    if (stream == 0) {
        stream = 1;
    }
    s_stream_id = stream;
    ready = true;
}

static esp_err_t cmac16(const uint8_t key[32], const void *data, size_t len, uint8_t out[16])
{
    const mbedtls_cipher_info_t *ci = mbedtls_cipher_info_from_type(MBEDTLS_CIPHER_AES_256_ECB);
    if (!ci) {
        return ESP_FAIL;
    }
    return mbedtls_cipher_cmac(ci, key, 256, data, len, out) == 0 ? ESP_OK : ESP_FAIL;
}

static esp_err_t cmac16_two(const uint8_t key[32],
                            const void *data1, size_t len1,
                            const void *data2, size_t len2,
                            uint8_t out[16])
{
    const mbedtls_cipher_info_t *ci = mbedtls_cipher_info_from_type(MBEDTLS_CIPHER_AES_256_ECB);
    if (!ci) {
        return ESP_FAIL;
    }

    mbedtls_cipher_context_t ctx;
    mbedtls_cipher_init(&ctx);
    int ret = mbedtls_cipher_setup(&ctx, ci);
    if (ret == 0) {
        ret = mbedtls_cipher_cmac_starts(&ctx, key, 256);
    }
    if (ret == 0 && len1) {
        ret = mbedtls_cipher_cmac_update(&ctx, data1, len1);
    }
    if (ret == 0 && len2) {
        ret = mbedtls_cipher_cmac_update(&ctx, data2, len2);
    }
    if (ret == 0) {
        ret = mbedtls_cipher_cmac_finish(&ctx, out);
    }
    mbedtls_cipher_free(&ctx);
    return ret == 0 ? ESP_OK : ESP_FAIL;
}

static esp_err_t aes_ctr_crypt(const uint8_t key[32], const uint8_t nonce[16],
                               const uint8_t *in, uint8_t *out, size_t len)
{
    mbedtls_aes_context ctx;
    uint8_t nc[16], stream[16] = {0};
    size_t offset = 0;
    memcpy(nc, nonce, sizeof(nc));
    mbedtls_aes_init(&ctx);
    int ret = mbedtls_aes_setkey_enc(&ctx, key, 256);
    if (ret == 0) {
        ret = mbedtls_aes_crypt_ctr(&ctx, len, &offset, nc, stream, in, out);
    }
    mbedtls_aes_free(&ctx);
    return ret == 0 ? ESP_OK : ESP_FAIL;
}

static void make_audio_nonce(uint32_t first_seq, uint8_t nonce[16])
{
    memcpy(nonce, s_source_id, 8);
    uint32_t stream_id = s_stream_id;
    memcpy(nonce + 4, &stream_id, sizeof(stream_id));
    memcpy(nonce + 8, &first_seq, sizeof(first_seq));
    uint32_t key_id = RAUD_APP_KEY_ID;
    memcpy(nonce + 12, &key_id, sizeof(key_id));
}

static bool raud_parse_ipv4_multicast_addr(const char *group_addr, struct in_addr *out)
{
    if (!group_addr || !out) {
        return false;
    }
    if (inet_aton(group_addr, out) != 1) {
        ESP_LOGE(TAG, "invalid multicast addr=%s", group_addr);
        return false;
    }
    uint32_t host = ntohl(out->s_addr);
    if ((host & 0xf0000000u) != 0xe0000000u) {
        ESP_LOGE(TAG, "addr=%s is not IPv4 multicast", group_addr);
        return false;
    }
    return true;
}

static int raud_create_ipv4_multicast_socket(uint16_t bind_port,
                                             uint32_t if_ip,
                                             uint8_t ttl,
                                             bool join_group,
                                             const char *group_addr)
{
    struct in_addr group = {0};
    if (!raud_parse_ipv4_multicast_addr(group_addr, &group)) {
        return -1;
    }

    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (sock < 0) {
        ESP_LOGE(TAG, "socket failed group=%s port=%u errno=%d",
                 group_addr, (unsigned)bind_port, errno);
        return -1;
    }

    int yes = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) < 0) {
        ESP_LOGE(TAG, "SO_REUSEADDR failed group=%s errno=%d", group_addr, errno);
        close(sock);
        return -1;
    }

    struct sockaddr_in bind_addr = {0};
    bind_addr.sin_family = AF_INET;
    bind_addr.sin_port = htons(bind_port);
    bind_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(sock, (struct sockaddr *)&bind_addr, sizeof(bind_addr)) < 0) {
        ESP_LOGE(TAG, "bind INADDR_ANY:%u failed group=%s errno=%d",
                 (unsigned)bind_port, group_addr, errno);
        close(sock);
        return -1;
    }

    if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl)) < 0) {
        ESP_LOGE(TAG, "IP_MULTICAST_TTL failed group=%s errno=%d", group_addr, errno);
        close(sock);
        return -1;
    }

    uint8_t loopback = RAUD_ENABLE_MULTICAST_LOOPBACK ? 1 : 0;
    if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP, &loopback, sizeof(loopback)) < 0) {
        ESP_LOGW(TAG, "IP_MULTICAST_LOOP failed group=%s errno=%d", group_addr, errno);
    }

    if (if_ip != 0) {
        struct in_addr if_addr = {.s_addr = if_ip};
        if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, &if_addr, sizeof(if_addr)) < 0) {
            ESP_LOGE(TAG, "IP_MULTICAST_IF failed group=%s errno=%d", group_addr, errno);
            close(sock);
            return -1;
        }
    }

    if (join_group) {
        struct ip_mreq imreq = {0};
        imreq.imr_multiaddr = group;
        imreq.imr_interface.s_addr = if_ip ? if_ip : htonl(INADDR_ANY);
        if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &imreq, sizeof(imreq)) < 0) {
            ESP_LOGE(TAG, "IP_ADD_MEMBERSHIP failed group=%s errno=%d", group_addr, errno);
            close(sock);
            return -1;
        }
    }

    struct timeval tx_timeout = {.tv_sec = 0, .tv_usec = 1000};
    if (setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tx_timeout, sizeof(tx_timeout)) < 0) {
        ESP_LOGW(TAG, "SO_SNDTIMEO failed group=%s errno=%d", group_addr, errno);
    }

    ESP_LOGI(TAG, "mcast socket group=%s port=%u if=%s ttl=%u join=%u loop=%u",
             group_addr, (unsigned)bind_port,
             if_ip ? inet_ntoa((struct in_addr){.s_addr = if_ip}) : "0.0.0.0",
             (unsigned)ttl, join_group ? 1u : 0u, (unsigned)loopback);
    return sock;
}

static int open_audio_socket(void)
{
    return raud_create_ipv4_multicast_socket(RAUD_AUDIO_PORT,
                                             source_wifi_sta_ip(),
                                             RAUD_MCAST_TTL,
                                             false,
                                             RAUD_AUDIO_MCAST_ADDR);
}

static int open_discovery_socket(void)
{
    int sock = raud_create_ipv4_multicast_socket(RAUD_DISCOVERY_PORT,
                                                 source_wifi_sta_ip(),
                                                 RAUD_MCAST_TTL,
                                                 RAUD_ENABLE_MULTICAST_SELFTEST != 0,
                                                 RAUD_DISCOVERY_MCAST_ADDR);
    if (sock < 0) {
        return -1;
    }
    struct timeval rx_timeout = {.tv_sec = 0, .tv_usec = 100000};
    (void)setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &rx_timeout, sizeof(rx_timeout));
    return sock;
}

static bool send_multicast(int sock, const char *group, uint16_t port, uint32_t if_ip,
                           const void *data, size_t len)
{
    if (sock < 0 || if_ip == 0 || !group || !data || len == 0) {
        return false;
    }
    struct in_addr group_addr = {0};
    if (!raud_parse_ipv4_multicast_addr(group, &group_addr)) {
        return false;
    }
    struct in_addr if_addr = {.s_addr = if_ip};
    if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, &if_addr, sizeof(if_addr)) < 0) {
        ESP_LOGW(TAG, "send IP_MULTICAST_IF failed group=%s errno=%d", group, errno);
        return false;
    }

    struct sockaddr_in dest = {0};
    dest.sin_family = AF_INET;
    dest.sin_port = htons(port);
    dest.sin_addr = group_addr;
    if (sendto(sock, data, len, MSG_DONTWAIT, (struct sockaddr *)&dest, sizeof(dest)) < 0) {
        ESP_LOGW(TAG, "sendto group=%s port=%u if=%s len=%u errno=%d",
                 group, (unsigned)port, inet_ntoa(if_addr), (unsigned)len, errno);
        return false;
    }
    return true;
}

static bool send_unicast(int sock, uint32_t ip, uint16_t port, const void *data, size_t len)
{
    if (sock < 0 || ip == 0 || port == 0 || !data || len == 0) {
        return false;
    }

    struct sockaddr_in dest = {0};
    dest.sin_family = AF_INET;
    dest.sin_port = htons(port);
    dest.sin_addr.s_addr = ip;
    return sendto(sock, data, len, MSG_DONTWAIT, (struct sockaddr *)&dest, sizeof(dest)) >= 0;
}

static bool send_unicast_audio_clients(int sock, const void *data, size_t len)
{
    bool sent = false;
#if RAUD_ENABLE_UNICAST_FALLBACK
    int64_t now = esp_timer_get_time();
    for (int i = 0; i < RAUD_UNICAST_MAX_CLIENTS; ++i) {
        raud_unicast_client_t *c = &s_unicast_clients[i];
        if (c->ip == 0 || c->port == 0) {
            continue;
        }
        if (now - c->last_seen_us > RAUD_UNICAST_CLIENT_TTL_US) {
            c->ip = 0;
            c->port = 0;
            c->last_seen_us = 0;
            continue;
        }
        if (send_unicast(sock, c->ip, c->port, data, len)) {
            sent = true;
            s_unicast_audio_sent++;
        } else {
            s_unicast_audio_send_fail++;
        }
    }
#else
    (void)sock;
    (void)data;
    (void)len;
#endif
    return sent;
}

static void register_unicast_client(uint32_t ip, uint16_t port)
{
#if RAUD_ENABLE_UNICAST_FALLBACK
    if (ip == 0 || port == 0) {
        return;
    }
    int64_t now = esp_timer_get_time();
    int slot = -1;
    int oldest = 0;
    int64_t oldest_seen = INT64_MAX;

    for (int i = 0; i < RAUD_UNICAST_MAX_CLIENTS; ++i) {
        if (s_unicast_clients[i].ip == ip && s_unicast_clients[i].port == port) {
            slot = i;
            break;
        }
        if (s_unicast_clients[i].ip == 0 && slot < 0) {
            slot = i;
        }
        if (s_unicast_clients[i].last_seen_us < oldest_seen) {
            oldest_seen = s_unicast_clients[i].last_seen_us;
            oldest = i;
        }
    }
    if (slot < 0) {
        slot = oldest;
    }

    s_unicast_clients[slot].ip = ip;
    s_unicast_clients[slot].port = port;
    s_unicast_clients[slot].last_seen_us = now;
    s_unicast_clients_registered++;
#else
    (void)ip;
    (void)port;
#endif
}

static void format_ipv4(uint32_t ip, char *buf, size_t buf_len)
{
    if (!buf || buf_len == 0) {
        return;
    }
    struct in_addr addr = {.s_addr = ip};
    const char *text = inet_ntoa(addr);
    snprintf(buf, buf_len, "%s", text ? text : "0.0.0.0");
}

static void fill_discovery_advert(raud_discovery_advert_t *adv, bool unicast_audio_group)
{
    if (!adv) {
        return;
    }
    ensure_source_identity();
    source_config_t cfg;
    source_config_get(&cfg);

    memset(adv, 0, sizeof(*adv));
    adv->magic = RAUD_MAGIC;
    adv->version = RAUD_VERSION;
    adv->type = RAUD_MSG_DISCOVERY;
    adv->length = sizeof(*adv);
    memcpy(adv->source_id, s_source_id, sizeof(adv->source_id));
    adv->stream_id = s_stream_id;
    snprintf(adv->room_code, sizeof(adv->room_code), "%s", cfg.room_id);
    snprintf(adv->room_name, sizeof(adv->room_name), "%s", cfg.room_id);
    adv->source_ip = source_wifi_sta_ip();
    adv->http_port = 80;
    if (unicast_audio_group) {
        format_ipv4(source_wifi_sta_ip(), adv->audio_group, sizeof(adv->audio_group));
    } else {
        snprintf(adv->audio_group, sizeof(adv->audio_group), "%s", RAUD_AUDIO_MCAST_ADDR);
    }
    adv->audio_port = RAUD_AUDIO_PORT;
    adv->codec = RAUD_APP_CODEC_SBC;
    adv->sample_rate = RAUD_APP_SAMPLE_RATE;
    adv->channels = RAUD_APP_CHANNELS;
    adv->packet_ms = RAUD_APP_PACKET_MS;
    adv->block_count = RAUD_APP_BLOCKS_PER_PACKET;
    adv->sbc_block_bytes = s_sbc_block_bytes;
    adv->key_id = RAUD_APP_KEY_ID;
    adv->flags = RAUD_FLAG_ENCRYPTED | RAUD_FLAG_AUTHENTICATED;
    adv->counter = ++s_discovery_counter;
    (void)cmac16(RAUD_DISCOVERY_AUTH_KEY, adv, offsetof(raud_discovery_advert_t, tag),
                 adv->tag);
}

static bool handle_discovery_probe(int sock, const uint8_t *data, ssize_t len,
                                   const struct sockaddr_in *from)
{
#if !RAUD_ENABLE_UNICAST_FALLBACK
    (void)sock;
    (void)data;
    (void)len;
    (void)from;
    return false;
#else
    if (!data || !from || len < (ssize_t)sizeof(raud_discovery_probe_t)) {
        return false;
    }

    raud_discovery_probe_t probe;
    memcpy(&probe, data, sizeof(probe));
    if (probe.magic != RAUD_MAGIC || probe.version != RAUD_VERSION ||
        probe.type != RAUD_MSG_DISCOVERY_PROBE || probe.length != sizeof(probe)) {
        return false;
    }
    if (cmac16(RAUD_DISCOVERY_AUTH_KEY, &probe, offsetof(raud_discovery_probe_t, tag),
               probe.tag) != ESP_OK) {
        return false;
    }

    uint16_t client_audio_port = probe.audio_port ? probe.audio_port : RAUD_AUDIO_PORT;
    register_unicast_client(from->sin_addr.s_addr, client_audio_port);
    s_discovery_probes_rx++;

    raud_discovery_advert_t adv;
    fill_discovery_advert(&adv, true);
    if (send_unicast(sock, from->sin_addr.s_addr, ntohs(from->sin_port), &adv, sizeof(adv))) {
        s_discovery_unicast_replies_sent++;
        return true;
    }
    return false;
#endif
}

static void build_audio_packet(const udp_app_plain_t *plain, udp_app_packet_t *out)
{
    memset(out, 0, sizeof(*out));
    out->hdr.magic = RAUD_MAGIC;
    out->hdr.version = RAUD_VERSION;
    out->hdr.type = RAUD_MSG_AUDIO;
    out->hdr.header_len = sizeof(out->hdr);
    memcpy(out->hdr.source_id, s_source_id, sizeof(out->hdr.source_id));
    out->hdr.stream_id = s_stream_id;
    out->hdr.first_seq = plain->first_seq;
    out->hdr.codec = RAUD_APP_CODEC_SBC;
    out->hdr.channels = RAUD_APP_CHANNELS;
    out->hdr.sample_rate = RAUD_APP_SAMPLE_RATE;
    out->hdr.block_samples = RAUD_APP_BLOCK_SAMPLES;
    out->hdr.block_us = RAUD_APP_BLOCK_US;
    out->hdr.block_count = RAUD_APP_BLOCKS_PER_PACKET;
    out->hdr.packet_ms = RAUD_APP_PACKET_MS;
    out->hdr.sbc_block_bytes = plain->sbc_block_bytes;
    out->hdr.payload_len = plain->payload_len;
    out->hdr.key_id = RAUD_APP_KEY_ID;
    out->hdr.flags = RAUD_FLAG_ENCRYPTED | RAUD_FLAG_AUTHENTICATED;
    make_audio_nonce(plain->first_seq, out->hdr.nonce);

    if (aes_ctr_crypt(RAUD_AUDIO_ENC_KEY, out->hdr.nonce,
                      plain->payload, out->payload, plain->payload_len) != ESP_OK) {
        s_audio_crypto_fail++;
        return;
    }
    uint8_t tag[16];
    if (cmac16_two(RAUD_AUDIO_AUTH_KEY,
                   &out->hdr, sizeof(out->hdr),
                   out->payload, plain->payload_len,
                   tag) != ESP_OK) {
        s_audio_crypto_fail++;
        return;
    }
    memcpy(out->payload + plain->payload_len, tag, sizeof(tag));
    out->len = sizeof(out->hdr) + plain->payload_len + sizeof(tag);
}

static void udp_audio_task(void *arg)
{
    (void)arg;
    ensure_source_identity();

    udp_sbc_block_t block;
    udp_app_plain_t plain = {0};
    int blocks = 0;
    uint16_t packet_block_bytes = 0;
    uint32_t last_log_ms = 0;

    while (1) {
        if (xQueueReceive(s_sbc_q, &block, pdMS_TO_TICKS(500)) != pdTRUE) {
            continue;
        }
        if (block.len == 0 || block.len > RAUD_APP_SBC_BLOCK_BYTES_MAX) {
            continue;
        }
        if (blocks == 0) {
            memset(&plain, 0, sizeof(plain));
            plain.first_seq = block.seq;
            plain.first_capture_us = block.capture_us;
            plain.sbc_block_bytes = block.len;
            packet_block_bytes = block.len;
            s_sbc_block_bytes = block.len;
        }
        if (block.len != packet_block_bytes) {
            blocks = 0;
            packet_block_bytes = 0;
            continue;
        }
        size_t offset = (size_t)blocks * packet_block_bytes;
        if (offset + block.len > sizeof(plain.payload)) {
            blocks = 0;
            packet_block_bytes = 0;
            continue;
        }
        memcpy(plain.payload + offset, block.sbc, block.len);
        blocks++;

        if (blocks < RAUD_APP_BLOCKS_PER_PACKET) {
            continue;
        }
        plain.payload_len = plain.sbc_block_bytes * RAUD_APP_BLOCKS_PER_PACKET;
        udp_app_packet_t pkt;
        build_audio_packet(&plain, &pkt);
        if (pkt.len) {
            if (xQueueSend(s_app_q, &pkt, 0) != pdTRUE) {
                udp_app_packet_t old;
                (void)xQueueReceive(s_app_q, &old, 0);
                s_audio_packets_dropped_queue++;
                if (xQueueSend(s_app_q, &pkt, 0) != pdTRUE) {
                    s_audio_packets_dropped_queue++;
                }
            } else {
                s_audio_packets_built++;
            }
        }
        blocks = 0;
        packet_block_bytes = 0;

        uint32_t now_ms = (uint32_t)(esp_timer_get_time() / 1000);
        if (now_ms - last_log_ms > 5000) {
            last_log_ms = now_ms;
            ESP_LOGW(TAG, "UDP student audio: built=%u sent=%u qDrop=%u congDrop=%u sockFail=%u block=%u payload=%u ch=%u uCli=%u uSent=%u uFail=%u probes=%u replies=%u",
                     (unsigned)s_audio_packets_built, (unsigned)s_audio_packets_sent,
                     (unsigned)s_audio_packets_dropped_queue,
                     (unsigned)s_audio_packets_dropped_congestion,
                     (unsigned)s_audio_socket_send_fail,
                     (unsigned)s_sbc_block_bytes,
                     (unsigned)(s_sbc_block_bytes * RAUD_APP_BLOCKS_PER_PACKET),
                     (unsigned)RAUD_APP_CHANNELS,
                     (unsigned)s_unicast_clients_registered,
                     (unsigned)s_unicast_audio_sent,
                     (unsigned)s_unicast_audio_send_fail,
                     (unsigned)s_discovery_probes_rx,
                     (unsigned)s_discovery_unicast_replies_sent);
        }
    }
}

static void udp_sender_task(void *arg)
{
    (void)arg;
    int sock = open_audio_socket();
    udp_app_packet_t pkt;
    uint32_t last_no_sta_log_ms = 0;
    while (1) {
        if (xQueueReceive(s_app_q, &pkt, pdMS_TO_TICKS(250)) != pdTRUE) {
            continue;
        }
        if (sock < 0) {
            sock = open_audio_socket();
            if (sock < 0) {
                s_audio_socket_send_fail++;
                vTaskDelay(pdMS_TO_TICKS(500));
                continue;
            }
        }
        if (uxQueueMessagesWaiting(s_app_q) > 0) {
            s_audio_packets_dropped_congestion++;
            continue;
        }
        bool sent = false;
#if RAUD_ENABLE_STA_MULTICAST_AUDIO
        uint32_t sta_ip = source_wifi_sta_ip();
        if (sta_ip != 0) {
            sent |= send_multicast(sock, RAUD_AUDIO_MCAST_ADDR, RAUD_AUDIO_PORT, sta_ip,
                                   &pkt, pkt.len);
        } else {
            uint32_t now_ms = (uint32_t)(esp_timer_get_time() / 1000);
            if (now_ms - last_no_sta_log_ms > 5000) {
                last_no_sta_log_ms = now_ms;
                ESP_LOGW(TAG, "audio multicast skipped: STA IP is 0");
            }
        }
#endif
#if RAUD_ENABLE_AP_MULTICAST_AUDIO
        if (source_wifi_ap_client_count()) {
            uint32_t ap_ip = source_wifi_ap_ip();
            sent |= send_multicast(sock, RAUD_AUDIO_MCAST_ADDR, RAUD_AUDIO_PORT, ap_ip,
                                   &pkt, pkt.len);
        }
#endif
        sent |= send_unicast_audio_clients(sock, &pkt, pkt.len);
        if (sent) {
            s_audio_packets_sent++;
        } else {
            s_audio_socket_send_fail++;
        }
    }
}

static void discovery_task(void *arg)
{
    (void)arg;
    int sock = open_discovery_socket();
    int64_t next_mcast_us = 0;
    uint8_t rx_buf[256];
    uint32_t last_no_sta_log_ms = 0;

    while (1) {
        if (sock < 0) {
            sock = open_discovery_socket();
            if (sock < 0) {
                vTaskDelay(pdMS_TO_TICKS(500));
                continue;
            }
        }

        struct sockaddr_in from = {0};
        socklen_t from_len = sizeof(from);
        ssize_t n = recvfrom(sock, rx_buf, sizeof(rx_buf), 0,
                             (struct sockaddr *)&from, &from_len);
        if (n > 0) {
            if (!handle_discovery_probe(sock, rx_buf, n, &from)) {
#if RAUD_ENABLE_MULTICAST_SELFTEST
                if (n >= (ssize_t)sizeof(raud_discovery_advert_t)) {
                    const raud_discovery_advert_t *adv = (const raud_discovery_advert_t *)rx_buf;
                    if (adv->magic == RAUD_MAGIC && adv->version == RAUD_VERSION &&
                        adv->type == RAUD_MSG_DISCOVERY) {
                        s_discovery_selftest_rx++;
                    }
                }
#endif
            }
        }

        int64_t now = esp_timer_get_time();
        if (now < next_mcast_us) {
            continue;
        }
        next_mcast_us = now + 1000000LL;

        raud_discovery_advert_t adv;
        fill_discovery_advert(&adv, false);
        bool sent = false;
#if RAUD_ENABLE_STA_MULTICAST_DISCOVERY
        uint32_t sta_ip = source_wifi_sta_ip();
        if (sta_ip != 0) {
            sent |= send_multicast(sock, RAUD_DISCOVERY_MCAST_ADDR, RAUD_DISCOVERY_PORT,
                                   sta_ip, &adv, sizeof(adv));
        } else {
            uint32_t now_ms = (uint32_t)(esp_timer_get_time() / 1000);
            if (now_ms - last_no_sta_log_ms > 5000) {
                last_no_sta_log_ms = now_ms;
                ESP_LOGW(TAG, "discovery multicast skipped: STA IP is 0");
            }
        }
#endif
#if RAUD_ENABLE_AP_MULTICAST_DISCOVERY
        if (source_wifi_ap_client_count()) {
            uint32_t ap_ip = source_wifi_ap_ip();
            if (ap_ip != 0) {
                sent |= send_multicast(sock, RAUD_DISCOVERY_MCAST_ADDR, RAUD_DISCOVERY_PORT,
                                       ap_ip, &adv, sizeof(adv));
            }
        }
#endif
        if (sent) {
            s_discovery_adverts_sent++;
        }
    }
}

esp_err_t source_udp_stream_start(void)
{
#if !RAUD_ENABLE_UDP_STUDENT_AUDIO
    return ESP_OK;
#endif
    if (s_sbc_q) {
        return ESP_OK;
    }
    ensure_source_identity();
    char sta_ip[16];
    char ap_ip[16];
    format_ipv4(source_wifi_sta_ip(), sta_ip, sizeof(sta_ip));
    format_ipv4(source_wifi_ap_ip(), ap_ip, sizeof(ap_ip));
    ESP_LOGW(TAG,
             "RAUD UDP init: discovery=%s:%u audio=%s:%u sta_if=%s ap_if=%s ttl=%u sta_disc=%u ap_disc=%u sta_audio=%u ap_audio=%u unicast=%u selftest=%u loop=%u packet_ms=%u blocks=%u",
             RAUD_DISCOVERY_MCAST_ADDR, (unsigned)RAUD_DISCOVERY_PORT,
             RAUD_AUDIO_MCAST_ADDR, (unsigned)RAUD_AUDIO_PORT,
             sta_ip, ap_ip, (unsigned)RAUD_MCAST_TTL,
             (unsigned)RAUD_ENABLE_STA_MULTICAST_DISCOVERY,
             (unsigned)RAUD_ENABLE_AP_MULTICAST_DISCOVERY,
             (unsigned)RAUD_ENABLE_STA_MULTICAST_AUDIO,
             (unsigned)RAUD_ENABLE_AP_MULTICAST_AUDIO,
             (unsigned)RAUD_ENABLE_UNICAST_FALLBACK,
             (unsigned)RAUD_ENABLE_MULTICAST_SELFTEST,
             (unsigned)RAUD_ENABLE_MULTICAST_LOOPBACK,
             (unsigned)RAUD_APP_PACKET_MS,
             (unsigned)RAUD_APP_BLOCKS_PER_PACKET);
    s_sbc_q = xQueueCreate(UDP_SBC_QUEUE_DEPTH, sizeof(udp_sbc_block_t));
    s_app_q = xQueueCreate(UDP_APP_QUEUE_DEPTH, sizeof(udp_app_packet_t));
    if (!s_sbc_q || !s_app_q) {
        return ESP_ERR_NO_MEM;
    }
    BaseType_t a = xTaskCreatePinnedToCore(udp_audio_task, "raud_pkt", 8192, NULL, 6, NULL, 0);
    BaseType_t s = xTaskCreatePinnedToCore(udp_sender_task, "raud_send", 6144, NULL, 7, NULL, 0);
    BaseType_t d = xTaskCreatePinnedToCore(discovery_task, "raud_disc", 4096, NULL, 2, NULL, 0);
    return (a == pdPASS && s == pdPASS && d == pdPASS) ? ESP_OK : ESP_FAIL;
}

void source_udp_stream_set_port(uint16_t port)
{
    (void)port;
}

void source_udp_stream_push_sbc_block(const uint8_t *sbc,
                                      size_t len,
                                      uint32_t seq,
                                      uint32_t capture_us)
{
#if !RAUD_ENABLE_UDP_STUDENT_AUDIO
    (void)sbc;
    (void)len;
    (void)seq;
    (void)capture_us;
    return;
#endif
    if (!s_sbc_q || !sbc || len == 0 || len > RAUD_APP_SBC_BLOCK_BYTES_MAX) {
        return;
    }
    if (uxQueueSpacesAvailable(s_sbc_q) == 0) {
        s_sbc_blocks_dropped++;
        return;
    }
    udp_sbc_block_t item = {0};
    item.seq = seq;
    item.capture_us = capture_us;
    item.len = (uint16_t)len;
    memcpy(item.sbc, sbc, len);
    if (xQueueSend(s_sbc_q, &item, 0) != pdTRUE) {
        s_sbc_blocks_dropped++;
    }
}

void source_udp_stream_get_stats(source_udp_stats_t *out)
{
    if (!out) {
        return;
    }
    memset(out, 0, sizeof(*out));
    out->discovery_adverts_sent = s_discovery_adverts_sent;
    out->audio_packets_built = s_audio_packets_built;
    out->audio_packets_sent = s_audio_packets_sent;
    out->audio_packets_dropped_queue = s_audio_packets_dropped_queue;
    out->audio_packets_dropped_congestion = s_audio_packets_dropped_congestion;
    out->audio_crypto_fail = s_audio_crypto_fail;
    out->audio_socket_send_fail = s_audio_socket_send_fail;
    out->pcm_blocks_dropped = s_sbc_blocks_dropped;
    out->pcm_queue_level = s_sbc_q ? uxQueueMessagesWaiting(s_sbc_q) : 0;
    out->audio_queue_level = s_app_q ? uxQueueMessagesWaiting(s_app_q) : 0;
    out->sbc_block_bytes = s_sbc_block_bytes;
    out->payload_bytes = s_sbc_block_bytes * RAUD_APP_BLOCKS_PER_PACKET;
    out->audio_port = RAUD_AUDIO_PORT;
    out->discovery_port = RAUD_DISCOVERY_PORT;
    out->packet_ms = RAUD_APP_PACKET_MS;
    out->block_count = RAUD_APP_BLOCKS_PER_PACKET;
    out->channels = RAUD_APP_CHANNELS;
}

void source_udp_stream_get_info(source_udp_info_t *out)
{
    if (!out) {
        return;
    }
    memset(out, 0, sizeof(*out));
    snprintf(out->discovery_group, sizeof(out->discovery_group), "%s", RAUD_DISCOVERY_MCAST_ADDR);
    snprintf(out->audio_group, sizeof(out->audio_group), "%s", RAUD_AUDIO_MCAST_ADDR);
    out->discovery_port = RAUD_DISCOVERY_PORT;
    out->audio_port = RAUD_AUDIO_PORT;
    out->sample_rate = RAUD_APP_SAMPLE_RATE;
    out->sbc_block_bytes = s_sbc_block_bytes;
    out->payload_bytes = s_sbc_block_bytes * RAUD_APP_BLOCKS_PER_PACKET;
    out->packet_ms = RAUD_APP_PACKET_MS;
    out->block_count = RAUD_APP_BLOCKS_PER_PACKET;
    out->channels = RAUD_APP_CHANNELS;
    out->key_id = RAUD_APP_KEY_ID;
    out->flags = RAUD_FLAG_ENCRYPTED | RAUD_FLAG_AUTHENTICATED;
}
