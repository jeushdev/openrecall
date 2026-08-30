import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/application/decks_tab_view.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';

void main() {
  late FakeCourseRepository courses;
  late FakeDeckRepository decks;
  late ProviderContainer container;

  setUp(() {
    courses = FakeCourseRepository(courses: [
      fakeCourse(id: 'default', name: 'Uncategorized', isDefault: true),
      fakeCourse(id: 'bio', name: 'Biology', accentColor: 'green'),
    ]);
    decks = FakeDeckRepository();
    container = ProviderContainer(
      overrides: [
        courseRepositoryProvider.overrideWithValue(courses),
        deckRepositoryProvider.overrideWithValue(decks),
      ],
    );
    addTearDown(container.dispose);
  });

  CourseController controller() =>
      container.read(courseControllerProvider.notifier);

  test('the controller starts idle with a data state', () {
    expect(
      container.read(courseControllerProvider),
      const AsyncData<void>(null),
    );
  });

  test('create forwards the name and accent and returns the new course',
      () async {
    final course =
        await controller().create(name: 'Chemistry', accentColor: 'amber');

    expect(course?.name, 'Chemistry');
    expect(course?.accentColor, 'amber');
    expect(
      courses.calls,
      contains('createCourse(name=Chemistry, accent=amber)'),
    );
  });

  test('create refreshes the course list', () async {
    await container.read(coursesProvider.future);
    await controller().create(name: 'Chemistry', accentColor: 'amber');

    final after = await container.read(coursesProvider.future);
    expect(after.map((c) => c.name), contains('Chemistry'));
  });

  test('create invalidates the deck list and the decks-tab view', () async {
    await container.read(decksProvider.future);
    container.read(decksTabViewProvider);
    decks.calls.clear();

    await controller().create(name: 'Chemistry', accentColor: 'amber');

    // A rebuilt decks-tab view re-reads the deck list.
    container.read(decksTabViewProvider);
    await container.read(decksProvider.future);
    expect(decks.calls, contains('fetchDecks()'));
  });

  test('update sends only the non-null fields and returns the new row',
      () async {
    final course = await controller().updateCourse(id: 'bio', name: 'Bio 101');

    expect(course?.name, 'Bio 101');
    expect(course?.accentColor, 'green');
    expect(
      courses.calls,
      contains('updateCourse(id=bio, name=Bio 101, accent=null)'),
    );
  });

  test('delete removes the course and reassigns its decks to the default',
      () async {
    courses.deckCourseIds['deck-1'] = 'bio';
    courses.deckCourseIds['deck-2'] = 'default';

    await controller().delete('bio');

    expect(courses.calls, contains('deleteCourse(bio)'));
    expect(courses.deckCourseIds['deck-1'], 'default');
    expect(courses.deckCourseIds['deck-2'], 'default');
    final after = await container.read(coursesProvider.future);
    expect(after.map((c) => c.id), isNot(contains('bio')));
  });

  test('delete refuses the default course and never calls the repository',
      () async {
    await container.read(coursesProvider.future);

    await controller().delete('default');

    final state = container.read(courseControllerProvider);
    expect(state.hasError, isTrue);
    expect(courses.calls, isNot(contains('deleteCourse(default)')));
  });

  test('a failed call lands as AsyncError, returns null, and clears loading',
      () async {
    courses.throwOnNextCall = Exception('boom');

    final course =
        await controller().create(name: 'Chemistry', accentColor: 'amber');

    expect(course, isNull);
    final state = container.read(courseControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse);
  });
}
