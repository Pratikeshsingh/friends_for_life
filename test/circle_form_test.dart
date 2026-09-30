import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_widgets.dart';
import 'package:vriendtime/src/core/theme.dart';

Json applicant() => {
      'name': 'Asha',
      'date_of_birth': '1990-01-01',
      'languages': ['English'],
      'availability_slots': {
        'thu': ['evening']
      },
      'interests': ['Food'],
      'activities': ['Dinner'],
      'goals': ['Regular plans'],
      'energy': 2,
      'commitment': true,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpForm(
    WidgetTester tester, {
    required int step,
    required bool focused,
    void Function(Json)? onSave,
    VoidCallback? onDone,
    Size size = const Size(390, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CircleApplication(
                  initial: applicant(),
                  busy: false,
                  initialStep: step,
                  focusedEdit: focused,
                  onDone: onDone,
                  onSave: (d) async => onSave?.call(d),
                  onSubmit: (_) async {},
                )))));
    await tester.pumpAndSettle();
  }

  group('a focused edit', () {
    testWidgets('drops the wizard chrome and saves without walking on',
        (tester) async {
      Json? saved;
      var done = false;
      await pumpForm(tester,
          step: 1,
          focused: true,
          onSave: (d) => saved = d,
          onDone: () => done = true);

      // No "2 OF 4" counter, no Continue — the eyebrow is upper-cased.
      expect(find.textContaining('OF 4'), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      final save = find.text('Save changes');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, isNotNull, reason: 'the edit should be saved');
      expect(done, isTrue, reason: 'and the form should close itself');
      // Still on the step it was opened at — never advanced to step 2.
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('Cancel leaves without saving', (tester) async {
      Json? saved;
      var done = false;
      await pumpForm(tester,
          step: 2,
          focused: true,
          onSave: (d) => saved = d,
          onDone: () => done = true);
      final cancel = find.text('Cancel');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(done, isTrue);
    });

    testWidgets('the first run keeps every step and the counter',
        (tester) async {
      await pumpForm(tester, step: 0, focused: false);
      expect(find.textContaining('1 OF 4'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
    });
  });

  group('choosing times', () {
    testWidgets('switching to per-day times can be undone', (tester) async {
      await pumpForm(tester, step: 1, focused: false);

      final toPerDay = find.text('Different times on different days');
      expect(toPerDay, findsOneWidget);
      await tester.ensureVisible(toPerDay);
      await tester.pumpAndSettle();
      await tester.tap(toPerDay);
      await tester.pumpAndSettle();

      // The way back must exist — it used to live inside the branch it hid,
      // which made this a one-way door.
      final back = find.text('Use the same times every day');
      expect(back, findsOneWidget);
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.text('Different times on different days'), findsOneWidget);
      expect(find.text('What time of day?'), findsOneWidget);
    });
  });

  group('the action row', () {
    for (final width in [320.0, 390.0]) {
      testWidgets('fits at ${width.toInt()}px on the first step',
          (tester) async {
        await pumpForm(tester,
            step: 0, focused: false, size: Size(width, 900));
        expect(tester.takeException(), isNull);
        expect(find.text('Save for later'), findsOneWidget);
        expect(find.text('Back'), findsNothing);
      });

      testWidgets('fits at ${width.toInt()}px with Back alongside it',
          (tester) async {
        await pumpForm(tester,
            step: 1, focused: false, size: Size(width, 900));
        expect(tester.takeException(), isNull);
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('Save for later'), findsOneWidget);
      });
    }
  });

  group('confirming availability', () {
    Future<void> pumpWaiting(WidgetTester tester, String? updatedAt) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleHome(
                      state: {
                        'stage': 'waiting',
                        'application': applicant()..['name'] = 'Asha',
                        if (updatedAt != null)
                          'application_updated_at': updatedAt,
                      },
                      demo: true,
                      busy: false,
                      act: (_, [__ = const {}]) async {},
                      onEdit: (_) {},
                      onMessages: () {})))));
      await tester.pumpAndSettle();
    }

    testWidgets('reads as confirmed, not as a button, inside a week',
        (tester) async {
      await pumpWaiting(
          tester, DateTime.now().subtract(const Duration(days: 2)).toIso8601String());
      expect(find.text('Confirmed this week'), findsOneWidget);
      expect(find.text('These times still work'), findsNothing);
    });

    testWidgets('comes back once the confirmation is stale', (tester) async {
      await pumpWaiting(tester,
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
      expect(find.text('These times still work'), findsOneWidget);
      expect(find.text('Confirmed this week'), findsNothing);
    });

    testWidgets('is offered when nothing was ever confirmed', (tester) async {
      await pumpWaiting(tester, null);
      expect(find.text('These times still work'), findsOneWidget);
    });
  });

  _shellRegression();

  group('avatars', () {
    testWidgets('fall back to the initial without a URL, and never throw',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: Center(
                  child: CircleMemberAvatar('Asha',
                      photoPath: 'someone/photo.jpg')))));
      await tester.pump();
      // No Supabase in a test, so re-signing throws — and must be swallowed.
      expect(tester.takeException(), isNull);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('a URL arriving later replaces the initial', (tester) async {
      Widget build(String? url) => MaterialApp(
          home: Scaffold(
              body: Center(child: CircleMemberAvatar('Asha', photoUrl: url))));
      await tester.pumpWidget(build(null));
      expect(find.text('A'), findsOneWidget);
      await tester.pumpWidget(build('https://example.test/a.jpg'));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });
  });
}

/// The reported bug: "saving changes on update availability still takes back
/// to onboarding". Driven through the real CircleShell, because the defect
/// was in how the shell re-evaluates which screen to show once the focused
/// edit closes — not in the form itself.
void _shellRegression() {
  testWidgets('saving a focused edit never re-opens the four-step form',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    // An application saved but never submitted: the stage that made the
    // wizard spring back open.
    await repo.act('draft', applicant());

    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: CircleShell(session: null, repository: repo)));
    await tester.pumpAndSettle();

    // Go to Profile and start a focused edit of availability.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final edit = find.text('Edit my availability');
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsOneWidget,
        reason: 'the focused edit should have opened');

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // The bug: the four-step form re-opened at step 0 behind the closing
    // edit, so the user saw onboarding again.
    expect(find.textContaining('1 OF 4'), findsNothing,
        reason: 'saving an edit must not restart the application form');
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Continue my application'), findsOneWidget,
        reason: 'they should land on the home card instead');
  });
}
