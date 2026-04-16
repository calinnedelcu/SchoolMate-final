import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized locale preference (Romanian / English).
///
/// Persisted in SharedPreferences and exposed as a [ChangeNotifier] so the
/// MaterialApp rebuilds whenever the user changes the language.
class LocaleService extends ChangeNotifier {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  static const String _kLocaleKey = 'app_locale';

  /// Locales supported by the app, in display order.
  static const List<Locale> supportedLocales = [
    Locale('ro'),
    Locale('en'),
  ];

  Locale _locale = const Locale('ro');
  bool _loaded = false;

  Locale get locale => _locale;
  bool get loaded => _loaded;

  /// Read persisted value once at app startup.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kLocaleKey);
      if (code != null && code.isNotEmpty) {
        _locale = _resolve(code);
      }
    } catch (_) {
      _locale = const Locale('ro');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    final resolved = _resolve(value.languageCode);
    if (resolved.languageCode == _locale.languageCode) return;
    _locale = resolved;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, resolved.languageCode);
    } catch (_) {}
  }

  Locale _resolve(String code) {
    for (final l in supportedLocales) {
      if (l.languageCode == code) return l;
    }
    return const Locale('ro');
  }
}
