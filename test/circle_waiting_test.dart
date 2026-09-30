import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

Json waitingSnapshot({
  String? slot = 'Thursday evening',
  int peers = 2,
  String? submittedAt,
}) =>
    {
      'stage': 'waiting',
      if (slot != null) 'nearest_slot': {'slot': slot, 'peers': peers},
      if (submittedAt != null) 'application_submitted_at': submittedAt,
    };

void main() {
  group('wait estimate', () {
    test('counts the applicant themselves towards the five needed', () {
      final wait = circleWaitEstimate(waitingSnapshot(peers: 2));
      expect(wait.ready, 3);
      expect(wait.stillNeeded, 2);
      expect(wait.progressLine,
          'Your group for Thursday evenings is coming together.');
      expect(wait.headline, '2 more people needed');
    });

    test('says nothing specific when the server sends no slot', () {
      final wait = circleWaitEstimate(waitingSnapshot(slot: null));
      expect(wait.isKnown, isFalse);
      expect(wait.progressLine, contains('share your language'));
    });

    test('a full slot says the group is found and gives the earliest start',
        () {
      final wait = circleWaitEstimate(waitingSnapshot(peers: 9));
      expect(wait.ready, CircleWaitEstimate.groupSize);
      expect(wait.stillNeeded, 0);
      expect(wait.progress, 1.0);
      expect(wait.complete, isTrue);
      expect(wait.progressLine, 'We found your group for Thursday evenings.');
      expect(wait.headline, 'We’re setting up your first meetup');
      expect(wait.estimate, startsWith('Earliest start: '));
      expect(wait.estimate, contains('We’ll confirm it in your invitation.'));
      // The same date the organiser panel suggests: the matching weekday at
      // least a week out, at the evening start time.
      final start = wait.earliestStart(now: DateTime(2026, 9, 30));
      expect(start, DateTime(2026, 10, 8, 19, 0));
    });

    test('a longer queue gives a longer range', () {
      String rangeFor(int peers) =>
          circleWaitEstimate(waitingSnapshot(peers: peers)).estimate;
      expect(rangeFor(3), 'Usually about a week');
      expect(rangeFor(2), 'Usually one to two weeks');
      expect(rangeFor(1), 'Usually two to three weeks');
      // Nobody else waiting yet: the Circle depends on people who have not
      // applied, so the range stops pretending to be precise.
      expect(rangeFor(0), 'Usually a few weeks');
    });

    test('days waited are counted from the application', () {
      final wait = circleWaitEstimate(
        waitingSnapshot(submittedAt: '2026-09-17T10:00:00Z'),
        now: DateTime.parse('2026-09-23T12:00:00Z'),
      );
      expect(wait.daysWaiting, 6);
    });

    test('a clock skewed into the future never reads as a negative wait', () {
      final wait = circleWaitEstimate(
        waitingSnapshot(submittedAt: '2026-09-25T10:00:00Z'),
        now: DateTime.parse('2026-09-23T12:00:00Z'),
      );
      expect(wait.daysWaiting, 0);
    });

    test('a snapshot without an application date simply omits the wait', () {
      expect(circleWaitEstimate(waitingSnapshot()).daysWaiting, isNull);
    });
  });

  group('venue reveal', () {
    Json meetup({int? week = 1, String date = '2026-10-08', String? venue}) => {
          'week': week,
          'date': date,
          'time': '19:30',
          if (venue != null) 'venue': venue,
        };

    test('is withheld while the meetup is more than a day away', () {
      expect(
          circleVenueLabel(meetup(venue: 'Rozey, Alkmaar'),
              now: DateTime(2026, 10, 6, 19, 30)),
          'Revealed 24 hours before · Alkmaar');
    });

    test('is shown once the meetup is within a day', () {
      expect(
          circleVenueLabel(meetup(venue: 'Rozey, Alkmaar'),
              now: DateTime(2026, 10, 7, 20)),
          'Rozey, Alkmaar');
    });

    test('a server that already redacted it stays redacted', () {
      expect(
          circleVenueLabel({'week': 1, 'venue_hidden': true},
              now: DateTime(2026, 10, 8)),
          'Revealed 24 hours before · Alkmaar');
    });

    test('a plan the Circle made itself was never a secret', () {
      expect(
          circleVenueLabel(meetup(week: null, venue: 'The pub on the corner'),
              now: DateTime(2026, 1, 1)),
          'The pub on the corner');
    });

    test('an unset venue reads as to be confirmed, not as a reveal', () {
      expect(circleVenueLabel(meetup(), now: DateTime(2026, 1, 1)),
          'Location to be confirmed');
    });
  });

  group('the waiting screen on a phone', () {
    Future<void> pumpWaiting(WidgetTester tester, Json state) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: CircleHome(
                      state: state,
                      demo: true,
                      busy: false,
                      act: (_, [__ = const {}]) async {},
                      onEdit: (_) {},
                      onMessages: () {})))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('shows progress towards the five people a Circle needs',
        (tester) async {
      await pumpWaiting(
          tester,
          waitingSnapshot(peers: 2, submittedAt: '2020-01-01T00:00:00Z')
            ..addAll({
              'application': {'name': 'Asha'}
            }));
      expect(find.text('Your group for Thursday evenings is coming together.'),
          findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('2 more people needed'), findsOneWidget);
      expect(find.textContaining(' of 5 people'), findsNothing);
    });

    testWidgets('an older server without the field still renders cleanly',
        (tester) async {
      await pumpWaiting(
          tester,
          waitingSnapshot(slot: null)
            ..addAll({
              'application': {'name': 'Asha'}
            }));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('share your language'), findsOneWidget);
    });
  });

  group('meetup start', () {
    test('combines the separate date and time the server sends', () {
      expect(circleMeetupStart({'date': '2026-10-08', 'time': '19:30'}),
          DateTime(2026, 10, 8, 19, 30));
    });

    test('falls back to the usual evening slot when time is missing', () {
      expect(circleMeetupStart({'date': '2026-10-08'}),
          DateTime(2026, 10, 8, 19, 30));
    });

    test('is null when there is no date to anchor to', () {
      expect(circleMeetupStart({'time': '19:30'}), isNull);
    });
  });
}
