import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'state/app_scope.dart';
import 'state/connection_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

/// Root of the OpenALS app.
class AlsApp extends StatelessWidget {
  const AlsApp({
    super.key,
    required this.settings,
    required this.connection,
  });

  final SettingsController settings;
  final ConnectionController connection;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      connection: connection,
      // Rebuild the MaterialApp whenever theme-affecting settings change.
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'OpenALS',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light(
              settings.seedColor,
              highContrast: settings.highContrast,
            ),
            darkTheme: AppTheme.dark(
              settings.seedColor,
              highContrast: settings.highContrast,
            ),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              // Apply the accessibility text-size preference globally. We clamp
              // the effective scale so very large sizes stay usable instead of
              // stretching layouts apart.
              final effective =
                  (settings.textScale * mq.textScaler.scale(1.0))
                      .clamp(0.8, 1.35);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(effective),
                  boldText: settings.boldText || mq.boldText,
                ),
                child: child!,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
