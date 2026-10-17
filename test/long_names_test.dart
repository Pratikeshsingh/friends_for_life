// Long first names and a long Circle name must not break any screen.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
      ('Newsreader', 'assets/fonts/Newsreader-Variable.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(file))).load();
    }
  });
  for (final stage in ['invited', 'active', 'completed']) {
    testWidgets('long names fit · $stage', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = DemoCircleRepository(prefs);
      await repo.act('preview', {'stage': stage});
      final state =
          jsonDecode(prefs.getString(DemoCircleRepository.storageKey)!)
              as Map<String, dynamic>;
      const long = 'Maximiliaan-Alexander';
      state['circle'] = {
        ...state['circle'] as Map,
        'name': 'The Wednesday Evening Founders Circle Alkmaar'
      };
      state['members'] = [
        for (final m in state['members'] as List)
          {...m as Map, 'name': m['id'] == 'you' ? 'Anne-Marieke' : long}
      ];
      final coffees = state['coffees'] as Map?;
      if (coffees?['current'] is Map) {
        (coffees!['current'] as Map)['other'] = {'id': 'noor', 'name': long};
        (coffees['current'] as Map)['place'] =
            'Het Alkmaars Koffiehuis aan de Gedempte Nieuwesloot';
      }
      await prefs.setString(DemoCircleRepository.storageKey, jsonEncode(state));
      final problems = <String>[];
      final original = FlutterError.onError;
      FlutterError.onError = (d) => problems.add(
          '${d.exceptionAsString().split('\n').first} @ ${RegExp(r'lib/[^\s:]+:\d+').firstMatch(d.toString())?.group(0) ?? ''}');
      try {
        await tester.pumpWidget(MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568), textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
                theme: buildTheme(),
                home: CircleShell(session: null, repository: repo))));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        for (final tab in ['', 'Messages', 'Profile']) {
          if (tab.isNotEmpty && find.text(tab).evaluate().isNotEmpty) {
            await tester.tap(find.text(tab).last, warnIfMissed: false);
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 120));
            }
          }
          for (var i = 0; i < 14; i++) {
            await tester.drag(
                find.byType(Scrollable).first, const Offset(0, -500),
                warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 80));
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        FlutterError.onError = original;
      }
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
