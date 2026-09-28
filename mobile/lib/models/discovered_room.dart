import 'package:flutter/foundation.dart';

/// A room/source discovered on the network.
///
/// The fields mirror the transmitter's `raud_discovery_advert_t` that is
/// broadcast on the multicast discovery group **239.10.10.1:6969**
/// (see `source_udp_stream.c`). Only the values a student needs to view and to
/// join the multicast audio stream are surfaced here.
@immutable
class DiscoveredRoom {
  const DiscoveredRoom({
    required this.roomCode,
    required this.roomName,
    required this.sourceIp,
    required this.audioGroup,
    required this.audioPort,
    required this.codec,
    required this.sampleRate,
    required this.channels,
    required this.packetMs,
    required this.encrypted,
    required this.authenticated,
    this.signal = 1.0,
  });

  /// e.g. "A10-0001" (advert.room_code).
  final String roomCode;

  /// Human-friendly name shown to students (advert.room_name).
  final String roomName;

  /// Transmitter STA IP (advert.source_ip), informational only.
  final String sourceIp;

  /// Audio multicast group to join after selecting this room
  /// (advert.audio_group), e.g. "239.10.10.10".
  final String audioGroup;

  /// UDP port for the multicast audio stream (advert.audio_port), e.g. 6970.
  final int audioPort;

  /// Codec id (1 == SBC).
  final int codec;

  /// Sample rate in Hz (48000).
  final int sampleRate;

  /// Channel count (2 == stereo).
  final int channels;

  /// Nominal packet duration in ms (advert.packet_ms).
  final int packetMs;

  /// RAUD_FLAG_ENCRYPTED present.
  final bool encrypted;

  /// RAUD_FLAG_AUTHENTICATED present.
  final bool authenticated;

  /// Relative signal strength 0..1 (derived from packet timing / RSSI later).
  final double signal;

  bool get isSbc => codec == 1;

  String get codecLabel => isSbc ? 'SBC' : 'codec #$codec';

  String get channelLabel {
    switch (channels) {
      case 1:
        return 'Mono';
      case 2:
        return 'Stereo';
      default:
        return '$channels ch';
    }
  }

  /// Compact one-line quality summary, e.g. "SBC · 48 kHz · Stereo".
  String get qualityLabel {
    final khz = (sampleRate / 1000)
        .toStringAsFixed(sampleRate % 1000 == 0 ? 0 : 1);
    return '$codecLabel · $khz kHz · $channelLabel';
  }

  /// Multicast endpoint the audio engine connects to once joined.
  String get audioEndpoint => '$audioGroup:$audioPort';

  /// Reconstructed PCM bitrate (sampleRate × channels × 16-bit), in kbps.
  int get pcmBitrateKbps => (sampleRate * channels * 16 / 1000).round();

  /// Approximate on-wire SBC stream bitrate, in kbps. SBC compresses the PCM
  /// roughly ~4.7× at high quality, scaled by sample rate / channels so it
  /// stays representative for the prototype.
  int get streamBitrateKbps =>
      isSbc ? (pcmBitrateKbps / 4.7).round() : pcmBitrateKbps;

  /// Rough end-to-end latency estimate: one packetization interval plus a
  /// small (~2 packet) jitter buffer.
  int get approxLatencyMs => packetMs * 3;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredRoom &&
      other.roomCode == roomCode &&
      other.audioGroup == audioGroup &&
      other.audioPort == audioPort;

  @override
  int get hashCode => Object.hash(roomCode, audioGroup, audioPort);
}
