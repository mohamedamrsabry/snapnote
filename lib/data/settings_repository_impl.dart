import 'package:shared_preferences/shared_preferences.dart';

import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _darkModeKey = 'isDarkMode';

  @override
  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? true;
  }

  @override
  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }
}
