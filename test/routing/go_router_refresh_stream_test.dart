import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/routing/go_router_refresh_stream.dart';

void main() {
  test('notifies on a value and not on an error', () async {
    final controller = StreamController<bool>();
    addTearDown(controller.close);
    final refresh = GoRouterRefreshStream(controller.stream);
    addTearDown(refresh.dispose);

    var notifications = 0;
    // The constructor fires one notification immediately; count only what
    // follows.
    refresh.addListener(() => notifications++);

    controller.add(true);
    await pumpEventQueue();
    expect(notifications, 1);

    // An error on the auth stream (offline token-refresh failure) must not
    // reach the zone as unhandled and must not trigger a route re-eval.
    controller.addError(StateError('refresh failed offline'));
    await pumpEventQueue();
    expect(notifications, 1);
  });
}
