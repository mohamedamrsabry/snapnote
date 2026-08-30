abstract class SettingsRepository {
  Future<bool> isDarkMode();

  Future<void> setDarkMode(bool value);

  // The id of the note currently pinned to the lock screen, or null if
  // none. Only one note can be live at a time, which is why this is a
  // single value rather than a set — the invariant is enforced by the
  // storage shape rather than by discipline in calling code.
  Future<String?> getLiveNoteId();

  Future<void> setLiveNoteId(String? id);
}
