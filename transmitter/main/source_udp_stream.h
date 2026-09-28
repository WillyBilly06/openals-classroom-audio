#pragma once

#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t discovery_adverts_sent;
    uint32_t audio_packets_built;
    uint32_t audio_packets_sent;
    uint32_t audio_packets_dropped_queue;
    uint32_t audio_packets_dropped_congestion;
    uint32_t audio_crypto_fail;
    uint32_t audio_socket_send_fail;
    uint32_t pcm_blocks_dropped;
    uint32_t pcm_queue_level;
    uint32_t audio_queue_level;
    uint16_t sbc_block_bytes;
    uint16_t payload_bytes;
    uint16_t audio_port;
    uint16_t discovery_port;
    uint8_t packet_ms;
    uint8_t block_count;
    uint8_t channels;
} source_udp_stats_t;

typedef struct {
    char discovery_group[16];
    char audio_group[16];
    uint16_t discovery_port;
    uint16_t audio_port;
    uint16_t sample_rate;
    uint16_t sbc_block_bytes;
    uint16_t payload_bytes;
    uint8_t packet_ms;
    uint8_t block_count;
    uint8_t channels;
    uint32_t key_id;
    uint32_t flags;
} source_udp_info_t;

esp_err_t source_udp_stream_start(void);
void source_udp_stream_set_port(uint16_t port);
void source_udp_stream_push_sbc_block(const uint8_t *sbc,
                                      size_t len,
                                      uint32_t seq,
                                      uint32_t capture_us);
void source_udp_stream_get_stats(source_udp_stats_t *out);
void source_udp_stream_get_info(source_udp_info_t *out);

#ifdef __cplusplus
}
#endif
