import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local-notification wrapper for the spec §8 "return to study" reminder.
///
/// v1 has exactly one kind of reminder — parked/unfinished cards from the user's
/// most recent session — so this owns a single notification slot ([_reminderId])
/// that is re-scheduled on every session exit and cancelled once the user comes
/// back. No remote push, no daily-due scheduling (that waits on the SM-2
/// decision), no user-facing preferences yet (milestone 12).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The one reminder slot. Re-scheduling reuses this id so only the latest
  /// session's reminder is ever pending.
  static const int _reminderId = 1001;
  static const String _channelId = 'study_reminders';
  static const String _channelName = 'Study reminders';
  static const String _channelDescription =
      'Nudges to come back to cards you left unfinished or parked.';

  /// How long after leaving a session the reminder fires. Inexact — Android is
  /// free to batch it with other wakeups.
  static const Duration _delay = Duration(hours: 3);

  bool _initialized = false;

  /// One-time setup: timezone database (needed by [tz.TZDateTime]), the plugin,
  /// and the Android channel. Safe to call more than once.
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        // Reuse the launcher icon — no dedicated notification drawable yet.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
      ),
    );

    _initialized = true;
  }

  /// Schedules (replacing any pending one) the reminder for a session the user
  /// just left with [unfinishedCount] cards still below Mastered. A no-op if the
  /// user denies the notification permission.
  Future<void> scheduleReturnReminder({
    required String? deckName,
    required int unfinishedCount,
  }) async {
    if (unfinishedCount <= 0) return;
    if (!await _ensurePermission()) return;

    await _plugin.cancel(_reminderId);
    await _plugin.zonedSchedule(
      _reminderId,
      reminderTitle,
      buildReminderBody(deckName, unfinishedCount),
      tz.TZDateTime.now(tz.local).add(_delay),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Drops the pending reminder — the user is back studying (or finished a
  /// session with nothing left parked).
  Future<void> cancelReturnReminder() => _plugin.cancel(_reminderId);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Requests `POST_NOTIFICATIONS` (Android 13+) the first time a reminder would
  /// actually be scheduled. Returns whether notifications are allowed.
  Future<bool> _ensurePermission() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }
}

const String reminderTitle = 'Still some cards to nail down';

/// Body copy for the return-to-study reminder. Top-level and pure so the wording
/// can be exercised without a plugin.
String buildReminderBody(String? deckName, int count) {
  final cards = count == 1 ? '1 card' : '$count cards';
  final where = deckName == null ? 'your last deck' : '"$deckName"';
  return '$cards in $where still need another pass. Jump back in?';
}
