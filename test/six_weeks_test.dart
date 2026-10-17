// The six weeks, version two: two included activities, week 5 for the
// group (a start in its part of the day), VriendTime in the chat, and the
// organiser's booking line.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_admin.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
import 'package:vriendtime/src/circles/circle_journey.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/i18n.dart' show t;
import 'package:vriendtime/src/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DemoCircleRepository> demo(String stage) async {
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': stage});
    return repo;
  }

  Future<void> pump(WidgetTester tester, Widget home,
      {Size size = const Size(430, 2600)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('included weeks say so, and week 5 is the group’s own',
      (tester) async {
    final repo = await demo('active');
    await pump(tester, CircleShell(session: null, repository: repo));
    expect(find.textContaining('Included in your fee'), findsWidgets);
    expect(find.text('Your group picks the place'), findsNothing,
        reason: 'only in the card that is open');
    // Week 5 offers "Plan it"; week 6 (the graduation) has no change button.
    expect(find.text('Plan it'), findsOneWidget);
    expect(find.text('Graduation: a new beginning'), findsWidgets);
  });

  testWidgets('planning week 5: the day stays, the start is theirs to choose',
      (tester) async {
    final repo = await demo('active');
    await pump(tester, CircleShell(session: null, repository: repo));
    final day = (await repo.load())['meetups']
        .firstWhere((m) => m['week'] == 5)['date'];
    final plan = find.text('Plan it');
    await tester.ensureVisible(plan);
    await tester.tap(plan);
    await tester.pumpAndSettle();
    expect(find.text('Plan it together'), findsOneWidget,
        reason: 'nothing to change yet');
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'What shall we do?'))
            .controller!
            .text,
        isEmpty,
        reason: 'no placeholder to save by accident');
    expect(find.widgetWithText(TextField, 'Costs (optional)'), findsNothing,
        reason: 'the optional fields start folded');
    await tester.tap(find.text('Add details: address, costs and more'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Costs (optional)'))
            .controller!
            .text,
        isEmpty);
    expect(
        find.text(
            'The day stays the same. Choose a start between 18:00 and 21:00.'),
        findsOneWidget);
    for (final start in ['18:00', '18:30', '19:00', '20:30', '21:00']) {
      expect(find.widgetWithText(ChoiceChip, start), findsOneWidget);
    }
    await tester.enterText(
        find.widgetWithText(TextField, 'What shall we do?'), 'Pub quiz');
    await tester.enterText(find.widgetWithText(TextField, 'Where?'), 'Jonas');
    await tester.tap(find.widgetWithText(ChoiceChip, '18:30'));
    await tester.pump();
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();
    final week5 =
        (await repo.load())['meetups'].firstWhere((m) => m['week'] == 5) as Map;
    expect(week5['time'], '18:30');
    expect(week5['venue'], 'Jonas');
    expect(week5['date'], day, reason: 'the day never moves');
  });

  testWidgets('VriendTime nudges the chat, as a note rather than a person',
      (tester) async {
    final repo = await demo('active');
    await pump(tester, CircleShell(session: null, repository: repo));
    await tester.tap(find.text(t('Messages')).last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('VriendTime'), findsWidgets);
    expect(find.textContaining('Week 5 is your call!'), findsOneWidget);
    expect(find.byTooltip('Message options'), findsNothing,
        reason: 'nothing to report on a VriendTime note');
  });

  testWidgets('the organiser books each week the way the place takes it',
      (tester) async {
    final repo = await demo('active');
    await pump(
        tester, CircleAdmin(repository: repo, onChanged: () {}, initialTab: 3),
        size: const Size(430, 4000));
    expect(find.text('Booked ✓'), findsOneWidget, reason: 'week 3, Rozey');
    expect(find.textContaining('Booking email sent on'), findsOneWidget,
        reason: 'week 2, The Boules Club, by email');
    expect(find.text('Send again'), findsOneWidget);
    expect(find.text('Book online'), findsWidgets,
        reason: 'Rozey, The Hangout, Hofman');
    expect(find.text('Booking: waiting for the group’s plan'), findsOneWidget,
        reason: 'week 5');
    // Ticking a week booked.
    final mark = find.text('Mark booked').first;
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Booked ✓'), findsNWidgets(2));
  });

  testWidgets('the weeks editor fills each week’s start and what’s included',
      (tester) async {
    final repo = await demo('active');
    await pump(
        tester, CircleAdmin(repository: repo, onChanged: () {}, initialTab: 2),
        size: const Size(430, 6000));
    final use = find.text('Use this group').first;
    await tester.ensureVisible(use);
    await tester.tap(use);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    final starts = tester
        .widgetList<TextField>(find.widgetWithText(TextField, 'Starts'))
        .map((f) => f.controller!.text)
        .toList();
    expect(starts, ['20:00', '20:00', '19:00', '20:00', '20:00', '20:00'],
        reason: 'evening activities at 20:00, the dinner at 19:00');
    final included = tester
        .widgetList<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Included in the fee'))
        .map((c) => c.value)
        .toList();
    expect(included, [false, true, false, true, false, false]);
    expect(find.text('Place (empty: the group decides)'), findsOneWidget);
  });

  testWidgets('morning-only applicants see the café version of the six weeks',
      (tester) async {
    await pump(
        tester,
        const Scaffold(
            body: SingleChildScrollView(
                child: CircleJourney(compact: true, morning: true))));
    expect(find.text('Say cheese'), findsOneWidget);
    expect(find.text('The rematch'), findsNothing);
  });

  testWidgets('the commitment card promises two included activities',
      (tester) async {
    await pump(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CircleApplication(
                    initial: const {'commitment': false},
                    initialStep: 3,
                    busy: false,
                    onSave: (_) async {},
                    onSubmit: (_) async {}))));
    expect(find.text('Two activities included'), findsOneWidget);
    expect(find.text('In the centre of Alkmaar'), findsOneWidget);
    expect(find.textContaining('€39 once, when we’ve found your group'),
        findsOneWidget);
  });
}
