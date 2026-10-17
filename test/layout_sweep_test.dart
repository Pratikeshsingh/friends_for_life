// Every screen, every stage, on small and large phones, with large text and
// in both languages: nothing may overflow or throw. Uses the app's real
// fonts, so text is measured as on a phone (the default test font makes
// every letter a full square and cries wolf).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_admin.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/i18n.dart';
import 'package:vriendtime/src/core/theme.dart';

Json applicant() => {
      'name': 'Asha',
      'date_of_birth': '1990-01-01',
      'languages': ['English', 'Dutch'],
      'gender': 'woman',
      'availability_slots': {
        'thu': ['evening'],
        'sat': ['afternoon', 'evening']
      },
      'interests': ['Food', 'Coffee', 'Books'],
      'activities': ['Dinner'],
      'goals': ['Regular plans'],
      'energy': 2,
      'commitment': true,
      'intro': 'New in Alkmaar, love a long walk and a good book.',
    };

Future<void> _loadFonts() async {
  for (final (family, file) in [
    ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
    ('Newsreader', 'assets/fonts/Newsreader-Variable.ttf'),
    ('Roboto', 'assets/fonts/Manrope-Variable.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(file))).load();
  }
}

const sizes = [Size(320, 568), Size(360, 740), Size(390, 844), Size(430, 932)];
const scales = [1.0, 1.3, 2.0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final problems = <String>{};
  // Dutch screens: anything still showing English words.
  final english = <String>{};
  final englishWord = RegExp(
      r'\b(the|you|your|you’re|you’ll|and|with|this|our|are|to|for|after|before|yet|today|tap|it|can|once|when|what|that|please|people)\b',
      caseSensitive: false);

  setUpAll(_loadFonts);
  tearDownAll(() {
    // ignore: avoid_print
    print(
        '\n=== ${problems.length} distinct problem(s) ===\n${problems.join('\n')}');
    // ignore: avoid_print
    print(
        '\n=== ${english.length} Dutch screen text(s) with English ===\n${english.join('\n')}');
  });

  Future<void> run(WidgetTester tester, String label, Size size, double scale,
      Widget Function() build,
      {List<String> tabs = const [], bool scroll = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final where = RegExp(r'file:///[^\s]*?/lib/[^\s:]+:\d+:\d+')
              .firstMatch(text)
              ?.group(0)
              ?.replaceAll(RegExp(r'file:///.*?/lib/'), 'lib/') ??
          '';
      final first = details.exceptionAsString().split('\n').first;
      problems.add('$first @ $where  [$label]');
    };
    try {
      await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(top: 47, bottom: 34)),
          child: MaterialApp(theme: buildTheme(), home: build())));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      void collect() {
        if (!isDutch) return;
        for (final e in find.byType(RichText).evaluate()) {
          final text = (e.widget as RichText).text.toPlainText();
          if (englishWord.hasMatch(text) &&
              !text.contains('VriendTime') &&
              !text.contains('@')) {
            english.add('$text  [$label]'.replaceAll('\n', ' '));
          }
        }
      }

      Future<void> scrollAll() async {
        collect();
        if (!scroll) return;
        for (var i = 0; i < 14; i++) {
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isEmpty) break;
          await tester.drag(scrollables.first, const Offset(0, -600),
              warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 80));
          collect();
        }
      }

      await scrollAll();
      for (final tab in tabs) {
        final f = find.text(t(tab));
        if (f.evaluate().isEmpty) continue;
        await tester.tap(f.last, warnIfMissed: false);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        await scrollAll();
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      FlutterError.onError = original;
    }
    // Any overflow or error on this screen fails the test.
    expect(problems.where((p) => p.endsWith('[$label]')), isEmpty);
  }

  for (final lang in ['en', 'nl']) {
    for (final size in sizes) {
      for (final scale in scales) {
        if (scale == 2.0 && size.width != 390) continue;
        final tag = '$lang ${size.width.toInt()}w x$scale';

        testWidgets('landing · $tag', (tester) async {
          SharedPreferences.setMockInitialValues({});
          await setLanguage(lang);
          await run(tester, 'landing $tag', size, scale,
              () => const CircleShell(session: null));
        });

        for (var step = 0; step < 4; step++) {
          testWidgets('application step $step · $tag', (tester) async {
            SharedPreferences.setMockInitialValues({});
            await setLanguage(lang);
            await run(
                tester,
                'application step $step $tag',
                size,
                scale,
                () => Scaffold(
                    body: SingleChildScrollView(
                        child: CircleApplication(
                            initial: applicant(),
                            initialStep: step,
                            busy: false,
                            onSave: (_) async {},
                            onSubmit: (_) async {}))));
          });
        }

        for (final stage in ['waiting', 'invited', 'active', 'completed']) {
          testWidgets('$stage · $tag', (tester) async {
            SharedPreferences.setMockInitialValues({});
            await setLanguage(lang);
            final repo =
                DemoCircleRepository(await SharedPreferences.getInstance());
            if (stage == 'waiting') {
              await repo.act('apply', applicant());
            } else {
              await repo.act('preview', {'stage': stage});
            }
            await run(tester, '$stage $tag', size, scale,
                () => CircleShell(session: null, repository: repo),
                tabs: ['Messages', 'Profile']);
          });
        }

        for (var tab = 0; tab < 5; tab++) {
          testWidgets('organiser tab $tab · $tag', (tester) async {
            SharedPreferences.setMockInitialValues({});
            await setLanguage(lang);
            final repo =
                DemoCircleRepository(await SharedPreferences.getInstance());
            await repo.act('preview', {'stage': 'active'});
            await run(
                tester,
                'organiser tab $tab $tag',
                size,
                scale,
                () => CircleAdmin(
                    repository: repo, onChanged: () {}, initialTab: tab));
          });
        }
      }
    }
  }
}
