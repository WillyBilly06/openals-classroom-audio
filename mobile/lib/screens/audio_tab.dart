import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/connection_controller.dart';
import 'connect_screen.dart';
import 'now_playing_screen.dart';

/// The Audio destination. Shows the room browser when disconnected and the
/// now-playing controls (volume + disconnect) once a room is joined.
class AudioTab extends StatelessWidget {
  const AudioTab({super.key});

  @override
  Widget build(BuildContext context) {
    final connection = AppScope.connectionOf(context);

    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        final connected = connection.link != LinkStatus.disconnected;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: connected
              ? const NowPlayingScreen(key: ValueKey('now_playing'))
              : const ConnectScreen(key: ValueKey('connect')),
        );
      },
    );
  }
}
