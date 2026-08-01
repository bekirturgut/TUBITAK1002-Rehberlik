import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotifs {
  LocalNotifs._();
  static final instance = LocalNotifs._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String channelId = "scheduled_notifications";
  static const String channelName = "Zamanlı Bildirimler";
  static const String channelDesc = "Kayıt tarihine göre zamanlı bildirimler";

  bool _inited = false;

  Future<void> init({
    void Function(NotificationResponse response)? onTap,
  }) async {
    if (_inited) return;
    _inited = true;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onTap,
      onDidReceiveBackgroundNotificationResponse: onTap,
    );

    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> requestPermissionAndroid13Plus() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final enabled = await android.areNotificationsEnabled() ?? true;
    if (!enabled) {
      await android.requestNotificationsPermission();
    }
  }

  int _idFrom(String s) =>
      s.codeUnits.fold<int>(0, (p, e) => (p * 31 + e) & 0x7fffffff);

  /// stable id: uid + templateId
  int makeStableId(String uid, String templateId) => _idFrom("$uid-$templateId");

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final when = tz.TZDateTime.from(dateTime, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    //exact dene → izin yoksa inexact’e düş (hata vermesin)
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    } catch (_) {}

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  ///Anında göster (FCM foreground veya test için)
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}