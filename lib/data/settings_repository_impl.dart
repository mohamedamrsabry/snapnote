import 'package:shared_preferences/shared_preferences.dart';

import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _darkModeKey = 'isDarkMode';
  static const _liveNoteIdKey = 'liveNoteId';

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

  @override
  Future<String?> getLiveNoteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_liveNoteIdKey);
  }

  @override
  Future<void> setLiveNoteId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_liveNoteIdKey);
    } else {
      await prefs.setString(_liveNoteIdKey, id);
    }
  }
}
