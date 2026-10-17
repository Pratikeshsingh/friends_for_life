// Every button that opens a dialog, sheet or screen, on a small phone with
// larger text and with very large text, in both languages: what opens must
// fit and must not throw. Real fonts, as in layout_sweep_test.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/i18n.dart';
import 'package:vriendtime/src/core/theme.dart';

Json applicant() => {
      'name': 'Asha',
      'date_of_birth': '1990-01-01',
      'languages': ['English'],
      'gender': 'woman',
      'availability_slots': {
        'thu': ['evening']
      },
      'interests': ['Food'],
      'activities': ['Dinner'],
      'goals': ['Regular plans'],
      'energy': 2,
      'commitment': true,
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

/// Buttons, by stage, that open something.
const openers = {
  'waiting': [
    'Edit my availability',
    'Edit my interests and goals',
    'Edit birthday, languages and gender',
    'Edit my introduction',
    'Invite a friend',
    'Account details',
    'Withdraw my application',
  ],
  'invited': ['Accept invitation', 'View meetup details', 'Invite a friend'],
  'active': [
    'View meetup details',
    'Change',
    'Suggest an extra meetup',
    'Report a concern privately',
    'Previous meetups',
    'Future matching',
    'Invite a friend',
    'Account details',
    'Leave this Circle',
  ],
  'completed': [
    'Plan our next meetup',
    'Know someone who’d enjoy this? Invite a friend',
    'Check in',
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final problems = <String>{};
  final missing = <String>{};
  final english = <String>{};
  final englishWord = RegExp(
      r'\b(the|you|your|you’re|you’ll|and|with|this|our|are|to|for|after|before|yet|today|tap|it|can|once|when|what|that|please|people)\b',
      caseSensitive: false);
  setUpAll(_loadFonts);
  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== ${problems.length} problem(s) ===\n${problems.join('\n')}'
        '\n=== not found (check by hand) ===\n${missing.join('\n')}'
        '\n=== ${english.length} Dutch dialog text(s) with English ===\n${english.join('\n')}');
  });

  for (final lang in ['en', 'nl']) {
    for (final (size, scale) in [
      (const Size(320, 568), 1.3),
      (const Size(390, 844), 2.0),
    ]) {
      for (final entry in openers.entries) {
        for (final opener in entry.value) {
          final tag = '$lang ${size.width.toInt()}w x$scale';
          testWidgets('${entry.key}: $opener · $tag', (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            SharedPreferences.setMockInitialValues({});
            await setLanguage(lang);
            final repo =
                DemoCircleRepository(await SharedPreferences.getInstance());
            if (entry.key == 'waiting') {
              await repo.act('apply', applicant());
            } else {
              await repo.act('preview', {'stage': entry.key});
            }
            final original = FlutterError.onError;
            FlutterError.onError = (details) {
              final text = details.toString();
              final where = RegExp(r'file:///[^\s]*?/lib/[^\s:]+:\d+:\d+')
                      .firstMatch(text)
                      ?.group(0)
                      ?.replaceAll(RegExp(r'file:///.*?/lib/'), 'lib/') ??
                  '';
              problems.add(
                  '${details.exceptionAsString().split('\n').first} @ $where  [${entry.key}: $opener $tag]');
            };
            try {
              await tester.pumpWidget(MediaQuery(
                  data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.only(top: 47, bottom: 34)),
                  child: MaterialApp(
                      theme: buildTheme(),
                      home: CircleShell(session: null, repository: repo))));
              for (var i = 0; i < 10; i++) {
                await tester.pump(const Duration(milliseconds: 120));
              }
              // Openers can sit on Home or on Profile.
              var target = find.text(t(opener));
              if (target.evaluate().isEmpty) {
                final profile = find.text(t('Profile'));
                if (profile.evaluate().isNotEmpty) {
                  await tester.tap(profile.last, warnIfMissed: false);
                  for (var i = 0; i < 6; i++) {
                    await tester.pump(const Duration(milliseconds: 120));
                  }
                }
                target = find.text(t(opener));
              }
              if (target.evaluate().isEmpty) {
                missing.add('${entry.key}: $opener ($lang)');
                return;
              }
              await tester.ensureVisible(target.first);
              await tester.pump(const Duration(milliseconds: 200));
              await tester.tap(target.first, warnIfMissed: false);
              for (var i = 0; i < 10; i++) {
                await tester.pump(const Duration(milliseconds: 120));
              }
              void collect() {
                if (!isDutch) return;
                for (final e in find.byType(RichText).evaluate()) {
                  final text = (e.widget as RichText).text.toPlainText();
                  if (englishWord.hasMatch(text) &&
                      !text.contains('VriendTime') &&
                      !text.contains('@')) {
                    english.add(
                        '$text  [${entry.key}: $opener]'.replaceAll('\n', ' '));
                  }
                }
              }

              collect();
              for (var i = 0; i < 10; i++) {
                collect();
                final scrollables = find.byType(Scrollable);
                if (scrollables.evaluate().isEmpty) break;
                await tester.drag(scrollables.last, const Offset(0, -500),
                    warnIfMissed: false);
                await tester.pump(const Duration(milliseconds: 80));
              }
            } finally {
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(seconds: 1));
              FlutterError.onError = original;
            }
            // Anything that opens must fit and must not throw.
            expect(
                problems
                    .where((p) => p.endsWith('[${entry.key}: $opener $tag]')),
                isEmpty);
          });
        }
      }
    }
  }
}
