// The 17 October review: the people sit 3 + 3 (left-aligned) on any width,
// and once the six weeks are over a one-to-one either happened or didn't.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shell(WidgetTester tester, String stage, double width) async {
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': stage});
    tester.view.physicalSize = Size(width, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: CircleShell(session: null, repository: repo)));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  for (final width in [390.0, 700.0, 1300.0]) {
    testWidgets('six people sit three and three · ${width.toInt()}',
        (tester) async {
      await shell(tester, 'active', width);
      final names = ['You', 'Noor', 'Sam', 'Lena', 'Daan', 'Alex'];
      final spots = [
        for (final n in names)
          tester.getCenter(find.text(n, skipOffstage: false).last)
      ];
      final rows = spots.map((p) => p.dy.round()).toSet();
      expect(rows.length, 2, reason: 'two rows');
      expect(spots.where((p) => p.dy == spots.first.dy).length, 3,
          reason: 'three on the first row');
      expect((spots[3].dx - spots[0].dx).abs(), lessThan(2),
          reason: 'the second row starts on the left, under the first');
    });
  }

  testWidgets('after six weeks a one-to-one happened or didn’t',
      (tester) async {
    await shell(tester, 'completed', 430);
    await tester.tap(find.text('Your six weeks'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Optional one-to-one'), findsNothing);
  });
}
