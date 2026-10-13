import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  Json coffee({String? mine, String? theirs, String status = 'asked'}) => {
        'id': 'c1',
        'starts_at': DateTime.now()
            .add(const Duration(days: 3))
            .toUtc()
            .toIso8601String(),
        'place': 'De Koffiemolen',
        'address': 'Ritsevoort 26',
        'status': status,
        'mine': mine,
        'theirs': theirs,
        'other': {'id': 'anna', 'name': 'Anna'},
      };

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
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Apple or Outlook'), findsOneWidget);
  });

  testWidgets('a "no" can still change their mind', (tester) async {
    await pump(tester, state(coffee(mine: 'no', theirs: 'yes')));
    expect(find.textContaining('Anna said yes'), findsOneWidget);
    expect(find.text('I can make it after all'), findsOneWidget);
  });

  testWidgets('free week, and the tracker counts the others only',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, state(null, met: ['leo'], free: true));
    expect(find.text('Enjoy your free week'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
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
    expect(find.text('How was your coffee with Anna?'), findsOneWidget);
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
    expect(find.text('Around an hour. You pay for yourself.'), findsOneWidget);
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
}
