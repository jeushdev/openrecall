import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/theme/app_tokens.dart';
import 'package:open_recall/ui/common/app_card.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('light AppCard paints cardFill with a shadow', (tester) async {
    await tester.pumpWidget(host(const AppCard(child: Text('x'))));
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final d = box.decoration as BoxDecoration;
    expect(d.color, AppTokens.light.cardFill);
    expect(d.boxShadow, isNotEmpty);
  });

  testWidgets('dark AppCard has no shadow', (tester) async {
    await tester.pumpWidget(
      host(const AppCard(child: Text('x')), theme: AppTheme.dark),
    );
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(((box.decoration as BoxDecoration).boxShadow ?? const []), isEmpty);
  });

  testWidgets('onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(AppCard(onTap: () => tapped = true, child: const Text('go'))),
    );
    await tester.tap(find.text('go'));
    expect(tapped, isTrue);
  });
}
