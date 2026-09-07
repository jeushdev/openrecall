import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/large_title_scaffold.dart';
import 'package:open_recall/ui/common/navigation_obstruction.dart';

import '../../support/responsive_test_harness.dart';

Future<void> _pumpResponsiveHeader(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  configureResponsiveView(tester, viewport: size);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: LargeTitleScaffold(
        title: 'Hello, AReallyLongUnbrokenDisplayNameThatMustRemainReadable!',
        actions: [
          IconButton(
            key: const ValueKey('create-action'),
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text('offline · 99999', key: ValueKey('sync-action')),
          ),
        ],
        slivers: [
          SliverToBoxAdapter(
            child: Container(key: const ValueKey('body'), height: 1400),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

void _expectHeaderContentSeparated(WidgetTester tester, String reason) {
  expect(tester.takeException(), isNull, reason: reason);
  final title = tester.getRect(find.byKey(const ValueKey('large-title')));
  final create = tester.getRect(find.byKey(const ValueKey('create-action')));
  final sync = tester.getRect(find.byKey(const ValueKey('sync-action')));
  expect(title.overlaps(create), isFalse, reason: reason);
  expect(title.overlaps(sync), isFalse, reason: reason);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shows the title and an action, renders sliver content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LargeTitleScaffold(
          title: 'Home',
          actions: [IconButton(icon: const Icon(Icons.add), onPressed: () {})],
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 40,
                alignment: Alignment.center,
                child: const Text('body'),
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('long titles and actions stay separate throughout collapse', (
    tester,
  ) async {
    for (final size in responsiveViewports) {
      for (final scale in responsiveTextScales) {
        await _pumpResponsiveHeader(tester, size: size, textScale: scale);
        final reason = '$size at text scale $scale';
        _expectHeaderContentSeparated(tester, '$reason expanded');

        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        position.jumpTo(40);
        await tester.pump();
        _expectHeaderContentSeparated(tester, '$reason intermediate');

        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        _expectHeaderContentSeparated(tester, '$reason collapsed');
      }
    }
  });

  testWidgets('uses inherited navigation clearance exactly once', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NavigationObstruction(
          bottom: 98,
          child: LargeTitleScaffold(
            title: 'Tab',
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    ElevatedButton(
                      key: const ValueKey('last-action'),
                      onPressed: () => pressed = true,
                      child: const Text('Last action'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('large-title-bottom-clearance')))
          .height,
      114,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('last-action'))).bottom,
      lessThanOrEqualTo(568 - 98),
    );
    await tester.tap(find.byKey(const ValueKey('last-action')));
    expect(pressed, isTrue);
  });

  testWidgets('standalone screens reserve only the system bottom inset', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const LargeTitleScaffold(
          title: 'Settings',
          slivers: [SliverToBoxAdapter(child: SizedBox(height: 700))],
        ),
      ),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('large-title-bottom-clearance')))
          .height,
      40,
    );
  });
}
