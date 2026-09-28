import 'package:flutter/widgets.dart';

import 'connection_controller.dart';
import 'settings_controller.dart';

/// Provides the app-wide controllers to the widget tree without pulling in a
/// third-party state-management dependency.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.connection,
    required super.child,
  });

  final SettingsController settings;
  final ConnectionController connection;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!;
  }

  static SettingsController settingsOf(BuildContext context) =>
      of(context).settings;

  static ConnectionController connectionOf(BuildContext context) =>
      of(context).connection;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings || connection != oldWidget.connection;
}
