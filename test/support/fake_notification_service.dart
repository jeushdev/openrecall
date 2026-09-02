import 'package:open_recall/features/notifications/data/notification_service.dart';

/// A [NotificationService] that records toggle calls and never touches the
/// platform plugin — the real `setEnabled(false)` cancels a pending reminder
/// through a method channel that isn't wired up in widget tests.
class FakeNotificationService extends NotificationService {
  final List<bool> setEnabledCalls = <bool>[];

  int cancelReturnReminderCalls = 0;

  @override
  Future<void> setEnabled(bool value) async {
    setEnabledCalls.add(value);
    enabled = value;
  }

  @override
  Future<void> cancelReturnReminder() async {
    cancelReturnReminderCalls++;
  }
}
