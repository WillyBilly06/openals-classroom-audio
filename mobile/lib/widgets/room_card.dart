import 'package:flutter/material.dart';

import '../models/discovered_room.dart';

/// A rounded card representing one discovered room. Shows the student-facing
/// details (name + code) alongside a single tappable **hearing button** on the
/// trailing edge that joins the room's audio stream.
///
/// The card itself is *not* tappable — only the outlined hearing button is, so
/// it is unmistakably the control. Its outline uses the theme's primary color,
/// which becomes the bright yellow foreground in High-Contrast mode.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  final DiscoveredRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.roomName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Room ${room.roomCode}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _HearingButton(scheme: scheme, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

/// The single call-to-action for a room: a tappable, outlined "human hearing"
/// symbol. The outline + icon use [ColorScheme.primary] so they track the
/// active accent and remain visible (bright yellow) in High-Contrast mode.
///
/// On press-down the button *instantly* lights up — it fills solid with the
/// primary color and inverts the icon — giving immediate tactile feedback
/// rather than the slower ink ripple, then reverts on release/cancel.
class _HearingButton extends StatefulWidget {
  const _HearingButton({required this.scheme, required this.onTap});

  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  State<_HearingButton> createState() => _HearingButtonState();
}

class _HearingButtonState extends State<_HearingButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final fill = _pressed
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.12);
    final iconColor = _pressed ? scheme.onPrimary : scheme.primary;

    return Tooltip(
      message: 'Listen',
      child: Semantics(
        button: true,
        label: 'Listen',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary, width: 2),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.55),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(13),
            child: Icon(
              Icons.spatial_audio_off,
              color: iconColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
