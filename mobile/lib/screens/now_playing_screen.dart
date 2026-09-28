import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/discovered_room.dart';
import '../state/app_scope.dart';
import '../state/connection_controller.dart';

/// Shown while connected to a room. Presents the live session, a volume slider
/// (which also drives the device output volume) and a disconnect button.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = AppScope.connectionOf(context);

    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        final room = connection.connectedRoom;
        final connecting = connection.link == LinkStatus.connecting;

        return Scaffold(
          appBar: AppBar(
            title: Text(connecting ? 'Connecting…' : 'Now Listening'),
            automaticallyImplyLeading: false,
          ),
          body: room == null
              ? const SizedBox.shrink()
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // The hero scales to fit the available height on any
                        // screen size/resolution (scaling down on shorter
                        // devices) so it never overflows.
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 340,
                                child: _SessionHero(
                                  room: room,
                                  connecting: connecting,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _VolumeControl(
                          value: connection.volume,
                          enabled: !connecting,
                          onChanged: connection.setVolume,
                        ),
                        const SizedBox(height: 20),
                        _DisconnectButton(
                          onPressed: connection.disconnect,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _SessionHero extends StatefulWidget {
  const _SessionHero({required this.room, required this.connecting});

  final DiscoveredRoom room;
  final bool connecting;

  @override
  State<_SessionHero> createState() => _SessionHeroState();
}

class _SessionHeroState extends State<_SessionHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final room = widget.room;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            return SizedBox(
              width: 330,
              height: 330,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft, blurred waves that only travel *outward* and fade —
                  // a continuous ripple rather than an in-and-out breathing.
                  // Shown only once live, as the "audio is streaming" cue.
                  if (!widget.connecting)
                    for (var i = 0; i < 4; i++)
                      _Ripple(
                        progress: (t + i / 4) % 1.0,
                        color: scheme.primary,
                      ),
                  // The hero circle is large + glowing in *both* the connecting
                  // and connected states; only the icon differs.
                  child!,
                ],
              ),
            );
          },
          child: _CoreCircle(scheme: scheme, connecting: widget.connecting),
        ),
        const SizedBox(height: 32),
        Text(
          room.roomName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Room ${room.roomCode}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        _StatusPill(connecting: widget.connecting),
        const SizedBox(height: 22),
        _InfoStrip(room: room, connected: !widget.connecting),
      ],
    );
  }
}

/// The large, glowing hero circle. Identical size/glow whether connecting or
/// connected — only the glyph differs — so the session reads as "big and alive"
/// the moment you tap a room.
class _CoreCircle extends StatelessWidget {
  const _CoreCircle({required this.scheme, required this.connecting});
  final ColorScheme scheme;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      height: 172,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        connecting ? Icons.wifi_tethering : Icons.hearing,
        color: scheme.onPrimary,
        size: 78,
      ),
    );
  }
}

/// A single outward-travelling wave emitted from the hero circle's edge: a soft
/// glowing band (radial gradient, lightly blurred) that grows and fades as it
/// expands, producing a sonar-like ripple radiating from the circle.
class _Ripple extends StatelessWidget {
  const _Ripple({required this.progress, required this.color});

  /// 0.0 (just emitted, hugging the core's edge) → 1.0 (fully expanded, faded).
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const base = 150.0; // starts just inside the 172px core's edge
    const maxExtra = 180.0; // travels well beyond it
    final size = base + progress * maxExtra;

    // A soft gradient band (not a hard ring): the colour peaks mid-band and
    // dissolves smoothly to transparent on both sides, so each wave reads as a
    // gradient crest radiating outward and fading as it expands.
    final fade = (1.0 - progress);
    final opacity = (fade * 0.5).clamp(0.0, 1.0);

    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              // A wide, gradual band: the colour ramps up and back down across
              // a large span of the radius so each wave is almost entirely
              // gradient — a soft crest with no hard edge anywhere.
              stops: const [0.0, 0.62, 0.86, 1.0],
              colors: [
                Colors.transparent,
                Colors.transparent,
                color.withValues(alpha: opacity),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connecting});
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = connecting ? scheme.tertiary : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            connecting ? 'Connecting to stream' : 'Live · Encrypted',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color is MaterialColor ? color.shade700 : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The codec/sample/channels summary card. While connected it gains a
/// "Connection details" action that opens a polished modal sheet with the live
/// technical readout of the stream.
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.room, required this.connected});
  final DiscoveredRoom room;
  final bool connected;

  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConnectionDetailsSheet(room: room),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final decoration = BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
    );

    final summary = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _SummaryRow(room: room, scheme: scheme),
    );

    // The "Connection details" action (connected only). While connecting it is
    // kept in the layout but hidden (maintainSize) so the card — and therefore
    // the FittedBox-scaled hero above it — stays exactly the same size in both
    // states instead of shrinking once the footer appears.
    final detailsFooter = InkWell(
      onTap: () => _openDetails(context),
      // Round the ink splash to the card's bottom corners (the card's clip
      // doesn't reach the ink, which is painted on an ancestor Material).
      customBorder: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.memory, size: 17, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Connection details',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );

    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          summary,
          Visibility(
            visible: connected,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: detailsFooter,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.room, required this.scheme});
  final DiscoveredRoom room;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.audiotrack, 'Codec', room.codecLabel),
      (Icons.speed, 'Sample',
          '${(room.sampleRate / 1000).toStringAsFixed(0)} kHz'),
      (Icons.surround_sound, 'Channels', room.channelLabel),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Icon(items[i].$1, size: 20, color: scheme.primary),
                const SizedBox(height: 6),
                Text(
                  items[i].$3,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  items[i].$2,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (i != items.length - 1)
            Container(
              width: 1,
              height: 40,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
        ],
      ],
    );
  }
}

/// A polished modal sheet presenting the live technical readout, grouped into
/// Stream / Network / Security sections, headed by a technical-data chip icon.
class _ConnectionDetailsSheet extends StatelessWidget {
  const _ConnectionDetailsSheet({required this.room});
  final DiscoveredRoom room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            // Header: technical-data chip symbol + title + LIVE badge.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.memory, color: scheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Live technical readout',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _LiveBadge(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(
                children: [
                  _DetailGroup(
                    title: 'Stream',
                    rows: [
                      (Icons.graphic_eq, 'Bitrate',
                          '≈ ${room.streamBitrateKbps} kbps'),
                      (Icons.audiotrack, 'Codec', room.codecLabel),
                      (Icons.speed, 'Sample rate', '${room.sampleRate} Hz'),
                      (Icons.surround_sound, 'Channels', room.channelLabel),
                      (Icons.inventory_2_outlined, 'Packet',
                          '${room.packetMs} ms'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailGroup(
                    title: 'Network',
                    rows: [
                      (Icons.lan, 'Endpoint', room.audioEndpoint),
                      (Icons.dns, 'Source IP', room.sourceIp),
                      (Icons.timer_outlined, 'Latency',
                          '≈ ${room.approxLatencyMs} ms'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DetailGroup(
                    title: 'Security',
                    rows: [
                      (Icons.lock_outline, 'Encryption',
                          room.encrypted ? 'AES-CTR' : 'Off'),
                      (Icons.verified_user_outlined, 'Integrity',
                          room.authenticated ? 'AES-CMAC' : 'Off'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "● LIVE" pill used in the details sheet header.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section of key/value technical rows inside the details sheet.
class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.title, required this.rows});
  final String title;
  final List<(IconData, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(rows[i].$1, size: 17, color: scheme.primary),
                      const SizedBox(width: 12),
                      // Fixed-width label column so every value starts at the
                      // same x and the values line up vertically.
                      SizedBox(
                        width: 116,
                        child: Text(
                          rows[i].$2,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].$3,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [ui.FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != rows.length - 1)
                  Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  IconData get _icon {
    if (value <= 0.001) return Icons.volume_off_rounded;
    if (value < 0.4) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (value * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Volume',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              Icon(_icon, color: scheme.primary),
              Expanded(
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: enabled ? onChanged : null,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 48,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisconnectButton extends StatelessWidget {
  const _DisconnectButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Disconnect'),
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
    );
  }
}
