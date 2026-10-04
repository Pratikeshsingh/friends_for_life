import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_past_meetups.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

Json stateWith(List<Json> meetups, {List<Json> checkIns = const []}) => {
      'stage': 'active',
      'circle': {'name': 'The Thursday Circle'},
      'meetups': meetups,
      'check_ins': checkIns,
    };

Json meetup(String id, int? week, String date,
        {bool completed = true, String? venue, String title = 'Dinner'}) =>
    {
      'id': id,
      'week': week,
      'title': title,
      'date': date,
      'time': '19:30',
      'completed': completed,
      if (venue != null) 'venue': venue,
    };

Future<void> pump(WidgetTester tester, Json state) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: CirclePastMeetups(state: state)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('never asks for a birthday, city, gender or phone',
      (tester) async {
    // The reported bug: this tile opened the legacy meetups app, which gated
    // on its own onboarding and demanded all of these.
    await pump(
        tester,
        stateWith([
          meetup('a', 1, '2026-10-08', venue: 'Rozey, Alkmaar'),
        ]));
    expect(find.textContaining('A little about you'), findsNothing);
    for (final asked in ['Date of birth', 'City', 'Gender', 'Phone']) {
      expect(find.textContaining(asked), findsNothing,
          reason: 'previous meetups must not collect $asked');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists only completed meetups, most recent first',
      (tester) async {
    await pump(
        tester,
        stateWith([
          meetup('a', 1, '2026-10-08', title: 'Dinner'),
          meetup('b', 2, '2026-10-15', title: 'Bowling'),
          meetup('c', 3, '2026-10-22', title: 'Not yet', completed: false),
        ]));
    expect(find.text('Not yet'), findsNothing);
    expect(find.text('2 evenings so far with The Thursday Circle.'),
        findsOneWidget);
    final bowling = tester.getTopLeft(find.text('Bowling')).dy;
    final dinner = tester.getTopLeft(find.text('Dinner')).dy;
    expect(bowling, lessThan(dinner), reason: 'newest evening comes first');
  });

  testWidgets('shows the venue, which is no longer a secret afterwards',
      (tester) async {
    await pump(tester,
        stateWith([meetup('a', 1, '2026-10-08', venue: 'Rozey, Alkmaar')]));
    expect(find.text('Rozey, Alkmaar'), findsOneWidget);
    expect(find.textContaining('Revealed 24 hours before'), findsNothing);
  });

  testWidgets('surfaces a private check-in the member already gave',
      (tester) async {
    await pump(
        tester,
        stateWith([
          meetup('a', 1, '2026-10-08')
        ], checkIns: [
          {'id': 'a', 'feeling': '😊 Great'}
        ]));
    expect(find.text('You said: 😊 Great'), findsOneWidget);
  });

  testWidgets('has an honest empty state rather than a blank page',
      (tester) async {
    await pump(
        tester, stateWith([meetup('a', 1, '2026-10-08', completed: false)]));
    expect(find.text('Nothing behind you yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
