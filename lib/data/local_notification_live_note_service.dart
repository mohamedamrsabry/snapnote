import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/live_note_service.dart';

// Pins one note to the Android lock screen via an ongoing notification.
// A single fixed notification id means a second show() replaces the first
// in place (no flicker, no duplicates) and cancel() works after a full
// app restart without remembering anything about a prior session.
class LocalNotificationLiveNoteService implements LiveNoteService {
  static const int _notificationId = 1001;
  // v2: Importance.low ("silent") notifications are excluded from the lock
  // screen on many Android versions/devices even with visibility: public --
  // confirmed via `adb shell dumpsys notification` showing mImportance=LOW
  // on a notification that never appeared on a locked Android 15 emulator.
  // Channel importance is cached by Android at creation and can't be raised
  // later for an existing channel id, hence the bumped suffix.
  static const String _channelId = 'snapnote_live_note_v2';
  static const String _channelName = 'Live note';
  static const String _channelDescription =
      'Keeps one note pinned to your lock screen.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_live'),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> show({
    required String noteId,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    if (!enabled) return false;

    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          showWhen: false,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
    return true;
  }

  @override
  Future<void> hide() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
  }

  @override
  Future<bool> isShowing() async {
    await _ensureInitialized();
    final active = await _plugin.getActiveNotifications();
    return active.any((n) => n.id == _notificationId);
  }
}
