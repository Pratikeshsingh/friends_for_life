// Paying a week ahead, booking states that say what is really happening,
// what members actually paid, and the smaller fixes from the review.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_admin.dart';
import 'package:vriendtime/src/circles/circle_coffees.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_meetup_detail.dart';
import 'package:vriendtime/src/circles/circle_profile.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_widgets.dart';
import 'package:vriendtime/src/core/theme.dart';

/// The preview organiser, with its meetups changed first.
class _Organiser extends DemoCircleRepository {
  _Organiser(super.prefs, this.edit);
  final void Function(List<Json> meetups) edit;

  @override
  Future<Json> adminLoad() async {
    final data = await super.adminLoad();
    final circles = rows(data['circles']);
    final meetups = rows(circles.first['meetups']);
    edit(meetups);
    circles.first['meetups'] = meetups;
    return {...data, 'circles': circles};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> pump(WidgetTester tester, Widget home,
      {Size size = const Size(430, 3000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> invitation(WidgetTester tester, Json extra) => pump(
      tester,
      Scaffold(
          body: SingleChildScrollView(
              child: CircleHome(
                  state: {
            'stage': 'invited',
            'profile_id': 'me',
            'circle': {'name': 'The Monday Circle', 'start_date': day(5)},
            'members': const <Json>[],
            'meetups': const <Json>[],
            ...extra,
          },
                  demo: false,
                  busy: false,
                  act: (_, [__ = const {}]) async {},
                  onEdit: (_) {},
                  onMessages: () {}))));

  Future<_Organiser> organiser(void Function(List<Json>) edit) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _Organiser(await SharedPreferences.getInstance(), edit);
    await repo.act('preview', {'stage': 'active'});
    return repo;
  }

  Json week(List<Json> meetups, int n) =>
      meetups.firstWhere((m) => m['week'] == n);

  group('saying yes, a week ahead', () {
    testWidgets('after it closed: no accept button, a way to ask, and no',
        (tester) async {
      await invitation(tester, {'pay_by': day(-5), 'accept_until': day(-2)});
      expect(find.text('This invitation has closed'), findsOneWidget);
      expect(find.textContaining('Saying yes closed on ${circleDate(day(-2))}'),
          findsOneWidget);
      expect(find.text('Accept invitation'), findsNothing);
      expect(find.text('Message us on WhatsApp'), findsOneWidget);
      expect(find.text('This schedule doesn’t work for me'), findsOneWidget,
          reason: 'saying no still works');
      expect(find.textContaining('1 hour before'), findsNothing);
      expect(find.textContaining('Accept and pay by'), findsNothing,
          reason: 'the old pay-by date is no use any more');
    });

    testWidgets('past the pay-by date but still open: says until when',
        (tester) async {
      await invitation(tester, {'pay_by': day(-1), 'accept_until': day(3)});
      expect(find.text('Your invitation is still open'), findsOneWidget);
      expect(
          find.textContaining(
              'You can still say yes until ${circleDate(day(3))}'),
          findsOneWidget);
      expect(find.text('Accept invitation'), findsWidgets);
      expect(find.text('This invitation has closed'), findsNothing);
    });

    testWidgets('someone who already said yes can still pay', (tester) async {
      await invitation(tester, {
        'pay_by': day(-5),
        'accept_until': day(-2),
        'payment_agreement': {'status': 'awaiting_payment'}
      });
      expect(find.text('This invitation has closed'), findsNothing);
      expect(find.text('Your €39 has not arrived yet'), findsOneWidget);
    });

    testWidgets('week 5’s start time is the group’s, the dates are fixed',
        (tester) async {
      await invitation(tester, {'pay_by': day(3), 'accept_until': day(3)});
      expect(find.textContaining('The dates are fixed.'), findsOneWidget);
      expect(find.textContaining('Dates and times are fixed'), findsNothing);
    });
  });

  group('from a member’s side', () {
    Json week(int n, {String? venue, String? cost, bool included = false}) => {
          'id': 'w$n',
          'week': n,
          'title': circleWeekTitles[n - 1],
          'date': day(n * 7),
          'time': '20:00',
          'venue': venue,
          'cost_notes': cost,
          'included': included,
          'completed': false,
        };
    Future<void> member(WidgetTester tester, String stage, List<Json> meetups,
            {Json extra = const {}}) =>
        pump(
            tester,
            Scaffold(
                body: SingleChildScrollView(
                    child: CircleHome(
                        state: {
                  'stage': stage,
                  'profile_id': 'me',
                  'circle': {
                    'name': 'The Thursday Circle',
                    'start_date': day(7)
                  },
                  'members': const <Json>[],
                  'meetups': meetups,
                  ...extra,
                },
                        demo: false,
                        busy: false,
                        act: (_, [__ = const {}]) async {},
                        onEdit: (_) {},
                        onMessages: () {}))),
            size: const Size(430, 4000));

    testWidgets('week 5 has a day, and the group picks the time',
        (tester) async {
      await member(tester, 'active', [
        week(2,
            venue: 'The Boules Club',
            cost: 'Included in your fee: we book and pay for the court.',
            included: true),
        week(5, cost: 'Up to your group.'),
      ]);
      expect(find.textContaining('start time to choose'), findsOneWidget);
      expect(find.textContaining('20:00–22:00 · Next · Included'), findsNothing,
          reason: 'the cost line already says it is included');
      expect(find.textContaining('No need to sign up'), findsOneWidget);
      expect(find.textContaining('Your place is included'), findsNothing);
    });

    testWidgets('the week 5 details can be planned from right there',
        (tester) async {
      var planned = false;
      await pump(
          tester,
          Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => openCircleMeetup(
                          context, week(5, cost: 'Up to your group.'),
                          onPlan: () => planned = true),
                      child: const Text('open')))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('start time to choose'), findsOneWidget);
      expect(find.textContaining('hasn’t planned this yet'), findsOneWidget);
      await tester.tap(find.text('Plan it together'));
      await tester.pumpAndSettle();
      expect(planned, isTrue);
      expect(find.text('open'), findsOneWidget, reason: 'back on Home');
    });

    testWidgets('after graduation, no "the dates are fixed"', (tester) async {
      await member(tester, 'completed', [
        {...week(1, venue: 'Hofman'), 'date': day(-30), 'completed': true},
      ]);
      expect(find.text('Your six weeks'), findsOneWidget);
      expect(find.textContaining('The dates are fixed'), findsNothing);
    });

    testWidgets('saying yes shows the date to pay by', (tester) async {
      await invitation(tester, {'pay_by': day(3), 'accept_until': day(3)});
      await tester.tap(find.text('Accept invitation').first);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Please pay by ${circleDate(day(3))}, so the places can be booked for your group.'),
          findsOneWidget);
    });
  });

  group('bookings', () {
    testWidgets('a waiting email is not "sent", and can’t go twice',
        (tester) async {
      final repo = await organiser((meetups) {
        week(meetups, 2)['booking_email'] = {
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sent_at': null,
          'failed': false
        };
      });
      await pump(tester,
          CircleAdmin(repository: repo, onChanged: () {}, initialTab: 3),
          size: const Size(430, 4000));
      expect(find.text('Booking email waiting to go out (within 10 minutes)'),
          findsOneWidget);
      expect(find.textContaining('Booking email sent on'), findsNothing);
      expect(find.text('Send again'), findsNothing);
    });

    testWidgets('a failed email says so, and can be sent again',
        (tester) async {
      final repo = await organiser((meetups) {
        week(meetups, 2)['booking_email'] = {
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sent_at': null,
          'failed': true,
          'error': 'Mailbox unavailable'
        };
      });
      await pump(tester,
          CircleAdmin(repository: repo, onChanged: () {}, initialTab: 3),
          size: const Size(430, 4000));
      expect(
          find.text(
              'The booking email could not be sent. Try again, or book another way.'),
          findsOneWidget);
      expect(find.text('Send again'), findsOneWidget);
    });

    testWidgets('a booking made before a change is listed to cancel',
        (tester) async {
      final repo = await organiser((meetups) {
        final w4 = week(meetups, 4);
        w4['booking_previous'] = [
          {
            'status': 'booked',
            'venue': 'Bowling Alkmaar',
            'starts_at': DateTime.utc(2026, 10, 22, 18).toIso8601String()
          }
        ];
      });
      await pump(tester,
          CircleAdmin(repository: repo, onChanged: () {}, initialTab: 3),
          size: const Size(430, 4000));
      expect(
          find.text(
              'Was booked at Bowling Alkmaar for Thu 22 Oct 20:00: cancel that booking.'),
          findsOneWidget);
    });

    testWidgets('weeks to book in the next two weeks are on the To do list',
        (tester) async {
      final repo = await organiser((_) {});
      await pump(tester,
          CircleAdmin(repository: repo, onChanged: () {}, initialTab: 0),
          size: const Size(430, 4000));
      expect(find.text('Weeks to book'), findsOneWidget);
      // Week 2 (tomorrow) was emailed, not booked; week 3 is booked.
      expect(find.textContaining('Find out who’s secretly competitive'),
          findsOneWidget);
      expect(find.textContaining('Go beyond'), findsNothing);
    });

    testWidgets('the plan editor warns, but never blocks', (tester) async {
      final repo = await organiser((_) {});
      await pump(tester,
          CircleAdmin(repository: repo, onChanged: () {}, initialTab: 2),
          size: const Size(430, 6000));
      final use = find.text('Use this group').first;
      await tester.ensureVisible(use);
      await tester.tap(use);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.textContaining('Members are promised two included'),
          findsNothing);
      expect(find.textContaining('starts within 12 days'), findsNothing,
          reason: 'a new Circle starts at least twelve days out');
      final included =
          find.widgetWithText(CheckboxListTile, 'Included in the fee').at(1);
      await tester.ensureVisible(included);
      await tester.tap(included);
      await tester.enterText(
          find.widgetWithText(TextField, 'Starts').first, '10:00');
      await tester.pump();
      expect(
          find.text(
              'Members are promised two included activities, and this plan includes 1.'),
          findsOneWidget);
      expect(
          find.text(
              'Week 1 starts at 10:00, outside the part of the day this group is free.'),
          findsOneWidget);
    });
  });

  group('what was paid', () {
    test('amounts come from the payment', () {
      expect(circleEuros(1900), '€19');
      expect(circleEuros(3900), '€39');
      expect(circleEuros(null), '€39');
    });

    testWidgets('Profile shows an older €19 payment as €19', (tester) async {
      await pump(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: CircleProfile(
                      state: const {
                'stage': 'active',
                'profile_id': 'me',
                'circle': {'name': 'The Thursday Circle'},
                'members': [],
                'meetups': [],
                'payment_history': [
                  {
                    'status': 'paid',
                    'amount_cents': 1900,
                    'circle_name': 'The Thursday Circle'
                  }
                ],
              },
                      onEdit: (_) {},
                      onPhoto: null,
                      onAccount: null,
                      onReport: null,
                      onExport: null,
                      onBookings: null,
                      onSignOut: null))));
      await tester.tap(find.text('Payments & refunds'));
      await tester.pumpAndSettle();
      expect(find.text('€19 · Paid · place confirmed'), findsOneWidget);
    });
  });

  group('smaller fixes', () {
    test('week notes only while a week keeps our plan', () {
      expect(
          circleWeekNote(
              {'week': 1, 'title': 'Dinner together', 'time': '19:00'}),
          isNull,
          reason: 'an older Circle');
      expect(
          circleWeekNote(
              {'week': 6, 'title': 'One last get-together', 'time': '19:00'}),
          isNull);
      expect(
          circleWeekNote({
            'week': 3,
            'title': 'Go beyond “what do you do?”',
            'time': '10:30'
          }),
          circleMorningWeekNotes[2],
          reason: 'brunch in the morning, not a long meal');
      expect(
          circleWeekNote({
            'week': 3,
            'title': 'Go beyond “what do you do?”',
            'time': '19:00'
          }),
          circleWeekNotes[2]);
      expect(
          circleWeekNote({'week': 4, 'title': 'Say cheese', 'time': '10:30'}),
          circleMorningWeekNotes[3]);
      expect(circleWeekNote({'week': 5, 'title': 'Pub quiz', 'time': '20:00'}),
          isNull,
          reason: 'the group planned its own');
      expect(circleMeetupTitle({'week': 2, 'title': 'Bowling together'}),
          'Bowling together',
          reason: 'titles are shown as saved');
    });

    test('coffee times are Netherlands time on any device', () {
      expect(circleCoffeeWhen('2026-10-22T18:00:00Z'), 'Thu 22 Oct at 20:00');
      expect(circleCoffeeWhen('2026-11-05T19:00:00Z'), 'Thu 5 Nov at 20:00');
    });

    testWidgets('a big heading grows at most 1.4 times', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
          tester,
          const Scaffold(
              body: CircleHeading('Meet your Circle.',
                  subtitle: 'Look at the people and the six dates.')));
      double scale(String text) => tester
          .widget<RichText>(find
              .descendant(of: find.text(text), matching: find.byType(RichText))
              .first)
          .textScaler
          .scale(10);
      expect(scale('Meet your Circle.'), closeTo(14, 0.01),
          reason: 'the heading: 1.4 times');
      expect(scale('Look at the people and the six dates.'), closeTo(20, 0.01),
          reason: 'the text under it still grows fully');
    });
  });
}
