import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/large_title_scaffold.dart';

void main() {
  testWidgets('shows the title and an action, renders sliver content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: LargeTitleScaffold(
        title: 'Home',
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () {})],
        slivers: [
          SliverToBoxAdapter(child: Container(height: 40, alignment: Alignment.center, child: const Text('body'))),
        ],
      ),
    ));
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });
}
