import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/theme.dart';

/// Saves slowly, like a phone on a bad connection.
class SlowDemo extends DemoCircleRepository {
  SlowDemo(super.prefs);
  final gate = Completer<void>();
  @override
  Future<void> act(String action, [Json data = const {}]) async {
    if (action == 'coffee_answer') await gate.future;
    return super.act(action, data);
  }
}

void main() {
  testWidgets('a slow save shows the saving bar, then it goes away',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final repo = SlowDemo(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': 'active'});
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: CircleShell(session: null, repository: repo)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byKey(const ValueKey('saving-bar')), findsNothing);
    final yes = find.text('Yes, I’ll be there');
    await tester.ensureVisible(yes);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(yes);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('saving-bar')), findsOneWidget,
        reason: 'while saving, the bar shows');
    repo.gate.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byKey(const ValueKey('saving-bar')), findsNothing,
        reason: 'and goes away once saved');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
