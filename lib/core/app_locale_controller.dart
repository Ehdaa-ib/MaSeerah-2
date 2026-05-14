import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-selected [Locale] (English / Arabic) for [MaterialApp.locale].
class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  static const _prefKey = 'app_language_code';
  static final AppLocaleController instance = AppLocaleController._();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  /// Call after [WidgetsFlutterBinding.ensureInitialized] and before [runApp].
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == 'ar') {
      instance._locale = const Locale('ar');
    } else if (code == 'en') {
      instance._locale = const Locale('en');
    } else {
      final platform = WidgetsBinding.instance.platformDispatcher.locale;
      instance._locale =
          platform.languageCode == 'ar' ? const Locale('ar') : const Locale('en');
    }
    instance.notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'en' && code != 'ar') return;
    final next = Locale(code);
    if (_locale == next) return;
    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
    notifyListeners();
  }
}
