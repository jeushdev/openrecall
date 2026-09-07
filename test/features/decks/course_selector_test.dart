import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/presentation/widgets/course_selector.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_course_repository.dart';
import '../../support/responsive_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('grows selected chips to show a long course name in full', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));

    const name = 'Advanced cellular and molecular biology';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: CourseSelector(
              courses: [fakeCourse(id: 'biology', name: name)],
              selectedId: 'biology',
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final selectorRect = tester.getRect(find.byType(CourseSelector));
    final labelRect = tester.getRect(find.text(name));
    expect(selectorRect.height, greaterThan(56));
    expect(tester.widget<Text>(find.text(name)).maxLines, isNull);
    expect(selectorRect.contains(labelRect.topLeft), isTrue);
    expect(selectorRect.contains(labelRect.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course labels stay complete across the responsive matrix', (
    tester,
  ) async {
    const longName = 'Advanced cellular and molecular biology';

    for (final viewport in responsiveViewports) {
      for (final scale in responsiveTextScales) {
        configureResponsiveView(tester, viewport: viewport);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: CourseSelector(
                  courses: [
                    fakeCourse(id: 'long', name: longName),
                    fakeCourse(id: 'short', name: 'Biology'),
                    fakeCourse(
                      id: 'unbroken',
                      name: 'NeuropsychopharmacologyFoundations',
                    ),
                  ],
                  selectedId: 'long',
                  onSelected: (_) {},
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
        final selector = tester.getRect(find.byType(CourseSelector));
        final label = tester.getRect(find.text(longName));
        expect(selector.contains(label.topLeft), isTrue);
        expect(selector.contains(label.bottomRight), isTrue);
        expect(
          tester.widget<Text>(find.text(longName)).overflow,
          isNot(TextOverflow.ellipsis),
        );
      }
    }
  });

  testWidgets('the last course stays reachable and selectable by scrolling', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CourseSelector(
            courses: [
              for (var i = 0; i < 8; i++)
                fakeCourse(id: 'course-$i', name: 'Course number $i'),
            ],
            selectedId: null,
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Course number 7').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Course number 7'));
    expect(selected, 'course-7');
  });
}
