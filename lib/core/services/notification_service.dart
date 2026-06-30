import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'download_channel';
  static const _notifId = 99;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/jezsic');
      await _plugin.initialize(const InitializationSettings(android: android));
      const channel = AndroidNotificationChannel(
        _channelId,
        'Downloads',
        description: 'Song download progress',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> show(String title,
      {String body = 'Downloading...'}) async {
    try {
      await init();
      await _plugin.show(
        _notifId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Downloads',
            channelDescription: 'Song download progress',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            playSound: false,
            enableVibration: false,
            showProgress: true,
            indeterminate: true,
            onlyAlertOnce: true,
            icon: 'ic_music_notification',
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> dismiss() async {
    try {
      await _plugin.cancel(_notifId);
    } catch (_) {}
  }
}
