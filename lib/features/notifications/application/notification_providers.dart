import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_service.dart';

/// The app-wide [NotificationService]. The real instance is constructed and
/// `init()`-ed in `main()` and injected with `overrideWithValue` — a `Provider`
/// body can't await the async setup. Tests can override it with a fake.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
