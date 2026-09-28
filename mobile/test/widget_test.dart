// Basic smoke test for the OpenALS app.

import 'package:als_app/app.dart';
import 'package:als_app/state/connection_controller.dart';
import 'package:als_app/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      AlsApp(
        settings: SettingsController(prefs),
        connection: ConnectionController(),
      ),
    );

    // The splash screen shows the wordmark before transitioning out.
    expect(find.text('Assisted Listening'), findsOneWidget);
  });
}
