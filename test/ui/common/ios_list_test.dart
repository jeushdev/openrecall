import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/ios_list.dart';

void main() {
  Widget host(Widget c) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: ListView(children: [c])));

  testWidgets('renders header + rows, divider between but not after last', (tester) async {
    await tester.pumpWidget(host(const IosSection(
      header: 'Account',
      children: [IosRow(title: 'One'), IosRow(title: 'Two')],
    )));
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget); // exactly one, between the two rows
  });

  testWidgets('row onTap fires and chevron shows', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(IosSection(children: [
      IosRow(title: 'Go', showChevron: true, onTap: () => n++),
    ])));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(n, 1);
  });

  testWidgets('destructive row renders without throwing', (tester) async {
    await tester.pumpWidget(host(const IosSection(children: [IosRow(title: 'Delete account', destructive: true)])));
    expect(find.text('Delete account'), findsOneWidget);
  });
}
