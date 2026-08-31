import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/settings/collapsible_settings_section.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool expanded,
  VoidCallback? onToggle,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CollapsibleSettingsSection(
          title: 'Appearance',
          expanded: expanded,
          onToggle: onToggle ?? () {},
          children: const [Text('body content')],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('collapsed: header shows, children are absent from the tree',
      (tester) async {
    await _pump(tester, expanded: false);
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('body content'), findsNothing);
  });

  testWidgets('expanded: children are in the tree', (tester) async {
    await _pump(tester, expanded: true);
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('body content'), findsOneWidget);
  });

  testWidgets('tapping the header invokes onToggle', (tester) async {
    var toggles = 0;
    await _pump(tester, expanded: false, onToggle: () => toggles++);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(toggles, 1);
  });
}
