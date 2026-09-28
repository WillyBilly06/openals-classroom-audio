import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Holds user-adjustable app preferences and persists them automatically.
///
/// Persisted values:
///  * [themeMode]  – light / dark / follow system
///  * [textScale]  – accessibility text size multiplier
///  * [seedColor]  – accent color that re-seeds the green/white theme
///  * [highContrast] – accessibility toggle for stronger contrast
///  * [boldText]   – accessibility toggle for heavier font weights
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _load();
  }

  static const _kThemeMode = 'settings.themeMode';
  static const _kTextScale = 'settings.textScale';
  static const _kSeedColor = 'settings.seedColor';
  static const _kHighContrast = 'settings.highContrast';
  static const _kBoldText = 'settings.boldText';

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = 1.0;
  Color _seedColor = AppTheme.alsGreen;
  bool _highContrast = false;
  bool _boldText = false;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  Color get seedColor => _seedColor;
  bool get highContrast => _highContrast;
  bool get boldText => _boldText;

  /// Bounds for the text-size slider. Kept to a moderate range so larger sizes
  /// improve readability without stretching layouts apart.
  static const double minTextScale = 0.9;
  static const double maxTextScale = 1.3;

  void _load() {
    final mode = _prefs.getString(_kThemeMode);
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == mode,
      orElse: () => ThemeMode.system,
    );
    _textScale = (_prefs.getDouble(_kTextScale) ?? 1.0)
        .clamp(minTextScale, maxTextScale);
    final seed = _prefs.getInt(_kSeedColor);
    if (seed != null) _seedColor = Color(seed);
    _highContrast = _prefs.getBool(_kHighContrast) ?? false;
    _boldText = _prefs.getBool(_kBoldText) ?? false;
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  void setTextScale(double value) {
    final clamped = value.clamp(minTextScale, maxTextScale);
    if (clamped == _textScale) return;
    _textScale = clamped;
    _prefs.setDouble(_kTextScale, clamped);
    notifyListeners();
  }

  void setSeedColor(Color color) {
    if (color.toARGB32() == _seedColor.toARGB32()) return;
    _seedColor = color;
    _prefs.setInt(_kSeedColor, color.toARGB32());
    notifyListeners();
  }

  void setHighContrast(bool value) {
    if (value == _highContrast) return;
    _highContrast = value;
    _prefs.setBool(_kHighContrast, value);
    notifyListeners();
  }

  void setBoldText(bool value) {
    if (value == _boldText) return;
    _boldText = value;
    _prefs.setBool(_kBoldText, value);
    notifyListeners();
  }
}
