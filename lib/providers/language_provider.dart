import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Provides language state and translated strings throughout the app.
///
/// Persists the user's language choice in SharedPreferences under key
/// 'app_language' with values 'en' or 'te'.
class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'app_language';
  String _languageCode = 'en';

  LanguageProvider() {
    _loadSavedLanguage();
  }

  /// Current language code: 'en' or 'te'
  String get languageCode => _languageCode;

  /// Whether current language is Telugu
  bool get isTelugu => _languageCode == 'te';

  /// Whether current language is English
  bool get isEnglish => _languageCode == 'en';

  /// Get a translated UI string by key.
  String getString(String key) {
    return AppStrings.get(key, _languageCode);
  }

  /// Toggle between English and Telugu.
  void toggleLanguage() {
    setLanguage(_languageCode == 'en' ? 'te' : 'en');
  }

  /// Set language explicitly by code ('en' or 'te').
  void setLanguage(String code) {
    if (code != 'en' && code != 'te') return;
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    _saveLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && (saved == 'en' || saved == 'te')) {
        _languageCode = saved;
        notifyListeners();
      }
    } catch (_) {
      // Silently default to English
    }
  }

  Future<void> _saveLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _languageCode);
    } catch (_) {
      // Best effort save
    }
  }
}
