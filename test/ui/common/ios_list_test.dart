import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/ios_list.dart';

void main() {
  Widget host(Widget c) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: ListView(children: [c])),
  );

  testWidgets('renders header + rows, divider between but not after last', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const IosSection(
          header: 'Account',
          children: [
            IosRow(title: 'One'),
            IosRow(title: 'Two'),
          ],
        ),
      ),
    );
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(
      find.byType(Divider),
      findsOneWidget,
    ); // exactly one, between the two rows
  });

  testWidgets('row onTap fires and chevron shows', (tester) async {
    var n = 0;
    await tester.pumpWidget(
      host(
        IosSection(
          children: [IosRow(title: 'Go', showChevron: true, onTap: () => n++)],
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(n, 1);
  });

  testWidgets('destructive row renders without throwing', (tester) async {
    await tester.pumpWidget(
      host(
        const IosSection(
          children: [IosRow(title: 'Delete account', destructive: true)],
        ),
      ),
    );
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('long title and metadata reflow instead of squeezing the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const title = 'Advanced cellular respiration concepts';
    const value = '123456 cards waiting to sync';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: IosSection(
              children: [IosRow(title: title, trailingValue: value)],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text(value)).dy,
      greaterThan(tester.getTopLeft(find.text(title)).dy),
    );
    expect(tester.getSize(find.text(title)).width, greaterThan(100));
  });

  testWidgets('row text stays contained across the responsive matrix', (
    tester,
  ) async {
    const viewports = [
      Size(320, 568),
      Size(360, 640),
      Size(360, 800),
      Size(393, 873),
      Size(412, 915),
      Size(480, 960),
    ];
    const scales = [1.0, 1.3, 1.5, 2.0];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final viewport in viewports) {
      for (final scale in scales) {
        tester.view.physicalSize = viewport;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: IosSection(
                    children: [
                      IosRow(
                        leading: IosRowIcon(
                          icon: Icons.school_outlined,
                          color: Colors.blue,
                        ),
                        title: 'Advanced cellular respiration and molecular biology',
                        trailingValue: '123456 cards waiting to sync',
                        showChevron: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: '$viewport at ${scale}x',
        );
        for (final label in [
          'Advanced cellular respiration and molecular biology',
          '123456 cards waiting to sync',
        ]) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(viewport.width));
        }
      }
    }
  });

  testWidgets('trailing control and row taps keep independent callbacks', (
    tester,
  ) async {
    var rowTaps = 0;
    var switchChanges = 0;
    await tester.pumpWidget(
      host(
        IosSection(
          children: [
            IosRow(
              title: 'Study reminders',
              onTap: () => rowTaps++,
              trailing: Switch(value: true, onChanged: (_) => switchChanges++),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    expect(switchChanges, 1);
    expect(rowTaps, 0);
    await tester.tap(find.text('Study reminders'));
    expect(rowTaps, 1);
  });
}
