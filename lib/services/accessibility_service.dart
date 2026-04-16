import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized accessibility preferences (font size + high contrast).
///
/// Persisted in SharedPreferences and exposed as a [ChangeNotifier] so the
/// MaterialApp can rebuild whenever the user toggles a setting.
class AccessibilityService extends ChangeNotifier {
  AccessibilityService._();

  static final AccessibilityService instance = AccessibilityService._();

  static const String _kLargeFontKey = 'a11y_large_font';
  static const String _kHighContrastKey = 'a11y_high_contrast';

  /// Multiplier applied to text when [largeFont] is enabled.
  static const double largeFontScale = 1.30;

  bool _largeFont = false;
  bool _highContrast = false;
  bool _loaded = false;

  bool get largeFont => _largeFont;
  bool get highContrast => _highContrast;
  bool get loaded => _loaded;

  /// Effective text scale to feed into [MediaQuery].
  double get textScale => _largeFont ? largeFontScale : 1.0;

  /// Read persisted values once at app startup.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _largeFont = prefs.getBool(_kLargeFontKey) ?? false;
      _highContrast = prefs.getBool(_kHighContrastKey) ?? false;
    } catch (_) {
      // Fallback to defaults — never block app startup on a prefs failure.
      _largeFont = false;
      _highContrast = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLargeFont(bool value) async {
    if (_largeFont == value) return;
    _largeFont = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLargeFontKey, value);
    } catch (_) {}
  }

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) return;
    _highContrast = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHighContrastKey, value);
    } catch (_) {}
  }
}
