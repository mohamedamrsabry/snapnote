import 'package:flutter/material.dart';

import '../../domain/settings_repository.dart';

class ThemeViewModel extends ChangeNotifier {
  final SettingsRepository _repository;
  bool _isDarkMode = true;

  ThemeViewModel(this._repository) {
    _load();
  }

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _load() async {
    _isDarkMode = await _repository.isDarkMode();
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await _repository.setDarkMode(value);
  }
}
