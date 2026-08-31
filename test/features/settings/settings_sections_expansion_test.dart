import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/application/settings_sections_expansion.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('every section starts collapsed', () {
    final c = container();
    expect(c.read(settingsSectionsExpansionProvider), isEmpty);
  });

  test('toggle expands a collapsed section and collapses an expanded one', () {
    final c = container();
    final notifier = c.read(settingsSectionsExpansionProvider.notifier);

    notifier.toggle('appearance');
    expect(c.read(settingsSectionsExpansionProvider), contains('appearance'));

    notifier.toggle('appearance');
    expect(
      c.read(settingsSectionsExpansionProvider),
      isNot(contains('appearance')),
    );
  });

  test('toggling one section leaves the others untouched', () {
    final c = container();
    final notifier = c.read(settingsSectionsExpansionProvider.notifier);

    notifier.toggle('appearance');
    notifier.toggle('general');
    notifier.toggle('appearance');

    expect(c.read(settingsSectionsExpansionProvider), equals({'general'}));
  });

  test('collapseAll clears every expanded section', () {
    final c = container();
    final notifier = c.read(settingsSectionsExpansionProvider.notifier);

    notifier.toggle('appearance');
    notifier.toggle('general');
    notifier.collapseAll();

    expect(c.read(settingsSectionsExpansionProvider), isEmpty);
  });
}
