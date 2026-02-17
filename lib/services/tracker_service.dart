import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../models/tracker_slot_model.dart';

typedef SlotNotificationTapCallback = void Function(String slotId);

class TrackerService {
  TrackerService._();
  static final TrackerService instance = TrackerService._();

  static SlotNotificationTapCallback? onNotificationTap;

  static const _kIsActive = 'tracker_isActive';
  static const _kInterval = 'tracker_intervalMinutes';
  static const _kStartedAt = 'tracker_startedAt';
  static const _kSlots = 'tracker_slots';
  static const _kNotifId = 'tracker_currentNotifId';

  static const _notifChannelId = 'reality_gap_tracker';
  static const _notifChannelName = 'Time Tracker';

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notif.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          if (data['type'] == 'slot_reminder') {
            onNotificationTap?.call(data['slotId'] as String);
          }
        }
      },
    );

    final android2 = _notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android2 != null) {
      await android2.requestExactAlarmsPermission();
    }
  }

  Future<bool> requestNotificationPermission() async {
    final android = _notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestExactAlarmsPermission();
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final ios = _notif.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true; // older Android — permission not required at runtime
  }

  // ── Start / Stop ────────────────────────────────────────────────────────
  Future<void> start(int intervalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsActive, true);
    await prefs.setInt(_kInterval, intervalMinutes);
    await prefs.setString(_kStartedAt, DateTime.now().toIso8601String());
    await _scheduleNext(intervalMinutes, isFirstSlot: true);
  }

  Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsActive, false);
    await prefs.remove(_kStartedAt);
    await _notif.cancelAll();
  }

  // ── Schedule next notification ─────────────────────────────────────────
  // Called by start() and after each notification fires.
  Future<void> _scheduleNext(
    int intervalMinutes, {
    bool isFirstSlot = false,
  }) async {
    final now = DateTime.now();

    // Create a slot record for the upcoming interval
    final slotStart = now;
    final slotEnd = now.add(Duration(minutes: intervalMinutes));
    final slotId = const Uuid().v4();

    final slot = TrackerSlotModel(
      id: slotId,
      startTime: slotStart,
      endTime: slotEnd,
      intervalMinutes: intervalMinutes,
    );

    await _appendSlot(slot);

    // Notification fires at slotEnd
    final notifId = slotId.hashCode.abs() % 100000;
    final scheduledTime = tz.TZDateTime.from(slotEnd, tz.local);

    await _notif.zonedSchedule(
      notifId,
      'Time to log your output',
      'What did you produce in the last ${intervalMinutes}m?',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _notifChannelId,
          _notifChannelName,
          channelDescription: 'Reminders to log your focus output',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Reality Gap',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': 'slot_reminder', 'slotId': slotId}),
    );

    // Store current notif id so we can cancel individually if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotifId, notifId);
  }

  // Called from the notification tap handler AFTER the user logs output —
  // schedules the next slot automatically.
  Future<void> scheduleNextAfterSlot() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_kIsActive) ?? false;
    if (!isActive) return;
    final interval = prefs.getInt(_kInterval) ?? 30;
    await _scheduleNext(interval);
  }

  // ── State readers ──────────────────────────────────────────────────────
  Future<bool> get isActive async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsActive) ?? false;
  }

  Future<int> get intervalMinutes async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kInterval) ?? 30;
  }

  Future<DateTime?> get startedAt async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStartedAt);
    return raw == null ? null : DateTime.parse(raw);
  }

  // ── Slot management ────────────────────────────────────────────────────

  /// Returns today's slots, sorted ascending by startTime.
  /// Automatically prunes slots older than yesterday on every call.
  Future<List<TrackerSlotModel>> getSlots() async {
    final all = await _readAllSlots();
    final pruned = _pruneOldSlots(all);

    // If we pruned anything, persist the cleaned list
    if (pruned.length != all.length) {
      await _writeAllSlots(pruned);
    }

    // Return only today's slots
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return pruned.where((s) => !s.startTime.isBefore(startOfToday)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Returns yesterday's slots (for weekly summary use if needed).
  Future<List<TrackerSlotModel>> getYesterdaySlots() async {
    final all = await _readAllSlots();
    final pruned = _pruneOldSlots(all);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    return pruned
        .where((s) =>
            !s.startTime.isBefore(startOfYesterday) &&
            s.startTime.isBefore(startOfToday))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> addSlotOutput(
    String slotId,
    String text,
    int durationMinutes,
  ) async {
    final all = await _readAllSlots();
    final updated = all.map((s) {
      if (s.id == slotId) {
        return s.copyWith(
          outputText: text,
          outputDurationMinutes: durationMinutes,
        );
      }
      return s;
    }).toList();
    await _writeAllSlots(updated);
  }

  // ── Private helpers ────────────────────────────────────────────────────

  Future<void> _appendSlot(TrackerSlotModel slot) async {
    final all = await _readAllSlots();
    all.add(slot);
    await _writeAllSlots(all);
  }

  Future<List<TrackerSlotModel>> _readAllSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSlots);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => TrackerSlotModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAllSlots(List<TrackerSlotModel> slots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSlots,
      jsonEncode(slots.map((s) => s.toJson()).toList()),
    );
  }

  /// Drop any slot whose startTime is before the beginning of yesterday.
  List<TrackerSlotModel> _pruneOldSlots(List<TrackerSlotModel> slots) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final startOfYesterday =
        DateTime(yesterday.year, yesterday.month, yesterday.day);
    return slots.where((s) => !s.startTime.isBefore(startOfYesterday)).toList();
  }
}
