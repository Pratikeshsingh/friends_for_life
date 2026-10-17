import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_admin.dart';
import 'package:vriendtime/src/circles/circle_coffees.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  final members = <Json>[
    {'id': 'me', 'name': 'Asha'},
    {'id': 'anna', 'name': 'Anna'},
    {'id': 'leo', 'name': 'Leo'},
    {'id': 'sam', 'name': 'Sam'},
  ];
  Json state(Json? current, {List<String> met = const [], bool free = false}) =>
      {
        'profile_id': 'me',
        'coffees': {
          'started': true,
          'current': current,
          'met': met,
          'free_week': free
        }
      };
  // In three days, at a fixed Netherlands hour: 14:00 unless the test says
  // evening.
  Json coffee(
      {String? mine, String? theirs, String status = 'asked', int hour = 14}) {
    final day = DateTime.now().add(const Duration(days: 3));
    final noon = DateTime.utc(day.year, day.month, day.day, 12);
    final offset = circleAmsterdam(noon).hour - 12;
    return {
      'id': 'c1',
      'starts_at': DateTime.utc(day.year, day.month, day.day, hour - offset)
          .toIso8601String(),
      'place': 'De Koffiemolen',
      'address': 'Ritsevoort 26',
      'status': status,
      'mine': mine,
      'theirs': theirs,
      'other': {'id': 'anna', 'name': 'Anna'},
    };
  }

  Future<List<(String, Json)>> pump(WidgetTester tester, Json s) async {
    final calls = <(String, Json)>[];
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleCoffees(
                    state: s,
                    members: members,
                    busy: false,
                    act: (a, [d = const {}]) async => calls.add((a, d)))))));
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('asks yes or no, and sends the answer', (tester) async {
    final calls = await pump(tester, state(coffee()));
    expect(find.text('This week you could meet Anna'), findsOneWidget);
    expect(find.text('De Koffiemolen'), findsOneWidget);
    await tester.tap(find.text('Yes, I’ll be there'));
    expect(calls.single.$1, 'coffee_answer');
    expect(calls.single.$2, {'id': 'c1', 'answer': 'yes'});
  });

  testWidgets('a confirmed coffee: calendar, and running late only on the day',
      (tester) async {
    await pump(
        tester, state(coffee(mine: 'yes', theirs: 'yes', status: 'confirmed')));
    expect(find.text('You’re meeting Anna'), findsOneWidget);
    // Three days away: too early for "Running late".
    expect(find.text('Running late'), findsNothing);
    expect(find.text('Can’t make it after all'), findsOneWidget);
    // One calendar button; the choices open in a short sheet.
    expect(find.text('Google Calendar'), findsNothing);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Download calendar file'), findsOneWidget);
  });

  testWidgets('a "no" can still change their mind', (tester) async {
    await pump(tester, state(coffee(mine: 'no', theirs: 'yes')));
    expect(find.textContaining('Anna said yes'), findsOneWidget);
    expect(find.text('I can make it after all'), findsOneWidget);
  });

  testWidgets('an evening suggestion: as friends, and no reason needed',
      (tester) async {
    await pump(tester, state(coffee(hour: 20)));
    expect(
        find.text(
            'A drink in the evening, just as friends: whatever you like to drink. Not for you? Tap “Can’t make it”, no reason needed.'),
        findsOneWidget);
    expect(find.text('A coffee, just the two of you. Can you make it?'),
        findsNothing);
    expect(find.text('Can’t make it'), findsOneWidget);
    expect(find.textContaining('A drink · '), findsOneWidget,
        reason: 'never "coffee" at 20:00');
    expect(find.textContaining('A coffee · '), findsNothing);
    expect(
        circleOneToOneWith(
            DateTime.utc(2026, 10, 22, 18).toIso8601String(), 'Anna'),
        'A drink with Anna');
    expect(
        circleOneToOneWith(
            DateTime.utc(2026, 10, 22, 12).toIso8601String(), 'Anna'),
        'Coffee with Anna');
  });

  testWidgets('a daytime suggestion keeps its own line', (tester) async {
    await pump(tester, state(coffee()));
    expect(find.text('A coffee, just the two of you. Can you make it?'),
        findsOneWidget);
    expect(find.textContaining('just as friends'), findsNothing);
  });

  testWidgets('an evening "no" stands: nothing pulls them back',
      (tester) async {
    await pump(tester, state(coffee(hour: 20, mine: 'no', theirs: 'yes')));
    expect(find.textContaining('Anna said yes'), findsNothing);
    // Changing their own mind is still up to them.
    expect(find.text('I can make it after all'), findsOneWidget);
  });

  testWidgets('free week, and the tracker counts the others only',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, state(null, met: ['leo'], free: true));
    expect(find.text('Enjoy your free week'), findsOneWidget);
    expect(find.text('Met 1 of 3 so far'), findsOneWidget);
    expect(find.text('Asha'), findsNothing,
        reason: 'you are not in your own tracker');
    expect(find.bySemanticsLabel('Leo: met'), findsOneWidget);
    expect(find.bySemanticsLabel('Sam: not yet'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('after the coffee: one optional question', (tester) async {
    final calls = await pump(tester, {
      'profile_id': 'me',
      'coffees': {
        'started': true,
        'current': null,
        'met': ['anna'],
        'feedback_due': {'id': 'c0', 'name': 'Anna'}
      }
    });
    expect(find.text('How was meeting Anna?'), findsOneWidget);
    await tester.tap(find.text('🙂 Good'));
    expect(calls.single.$2, {'id': 'c0', 'rating': 'good'});
  });

  testWidgets('"we didn\'t meet" asks what happened, and skipping is fine',
      (tester) async {
    final calls = await pump(tester, {
      'profile_id': 'me',
      'coffees': {
        'started': true,
        'current': null,
        'met': [],
        'feedback_due': {'id': 'c0', 'name': 'Anna'}
      }
    });
    await tester.tap(find.text('We didn’t meet after all'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Waited 20 minutes');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(calls.single.$2,
        {'id': 'c0', 'rating': 'no_show', 'note': 'Waited 20 minutes'});
  });

  testWidgets('the place, its address and what to expect', (tester) async {
    await pump(tester, state(coffee()));
    expect(find.text('Ritsevoort 26'), findsOneWidget);
    expect(find.textContaining('tables aren’t reserved'), findsOneWidget);
    expect(find.textContaining('About an hour · you pay for yourself'),
        findsOneWidget);
  });

  testWidgets('directions to the place, from the card', (tester) async {
    await pump(tester, state(coffee()));
    expect(find.text('Directions'), findsOneWidget);
  });

  test('the map link: the kept one, or a search for the place', () {
    expect(
        circleCoffeeMapUri(
                {...coffee(), 'maps_url': 'https://maps.app.goo.gl/abc'})
            .toString(),
        'https://maps.app.goo.gl/abc');
    final search = circleCoffeeMapUri(coffee());
    expect(search.host, 'www.google.com');
    expect(search.queryParameters['query'],
        'De Koffiemolen, Ritsevoort 26, Alkmaar');
    // Only web links are opened as they are.
    expect(
        circleCoffeeMapUri({...coffee(), 'maps_url': 'javascript:alert(1)'})
            .host,
        'www.google.com');
  });

  testWidgets('the organiser sees which places have no opening hours',
      (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': 'active'});
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: CircleAdmin(repository: repo, onChanged: () {}, initialTab: 2)));
    await tester.pumpAndSettle();
    // The editor sits under a group picked for a new Circle.
    final use = find.text('Use this group').first;
    await tester.ensureVisible(use);
    await tester.pumpAndSettle();
    await tester.tap(use);
    await tester.pumpAndSettle();
    final places = find.text('Places for one-to-one coffees');
    await tester.ensureVisible(places);
    await tester.pumpAndSettle();
    await tester.tap(places);
    await tester.pumpAndSettle();
    // De Koffiemolen has hours in the demo; Kaldi and Mr. Gold don't.
    expect(
        find.text(
            'No opening hours yet: Kaldi. Only suggested when no other place is open.'),
        findsOneWidget);
    expect(
        find.text(
            'No opening hours yet: Mr. Gold. Only suggested when no other place is open.'),
        findsOneWidget);
    expect(find.textContaining('De Koffiemolen.'), findsNothing);
  });

  testWidgets('running late: one tap, pick how late', (tester) async {
    final soon = {
      ...coffee(mine: 'yes', theirs: 'yes', status: 'confirmed'),
      'starts_at': DateTime.now()
          .add(const Duration(minutes: 40))
          .toUtc()
          .toIso8601String(),
    };
    final calls = await pump(tester, state(soon));
    await tester.tap(find.text('Running late'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About 10 min'));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'running_late');
    expect(calls.single.$2, {'kind': 'coffee', 'id': 'c1', 'minutes': 10});
  });

  testWidgets('on an iPhone the coffee goes straight to Apple Calendar',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(
        tester, state(coffee(mine: 'yes', theirs: 'yes', status: 'confirmed')));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Apple Calendar'), findsOneWidget);
    expect(find.text('Download calendar file'), findsNothing);
    expect(find.text('Google Calendar'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
