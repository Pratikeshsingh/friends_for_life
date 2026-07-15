import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/home_screen.dart';

void main() {
  testWidgets('home explains the product instead of duplicating the catalog', (
    tester,
  ) async {
    final event = _event(
      id: 'available',
      title: 'Coffee in town',
      startsAt: _futureStart(days: 30, hour: 18),
    );
    var openedMeetups = false;

    await _pumpHome(
      tester,
      HomeScreen(
        onOpenEvent: (_) => openedMeetups = true,
        firstName: 'Alex',
        city: 'Alkmaar',
        selectedEvent: null,
        selectedEvents: const <MeetupEvent>[],
        availableEvents: [event],
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
      ),
    );

    expect(find.text('Choose a time'), findsOneWidget);
    expect(find.text('Reserve your place'), findsOneWidget);
    expect(find.text('Meet your table'), findsOneWidget);
    expect(find.text(event.title), findsNothing);

    await tester.ensureVisible(find.text('Find a meetup'));
    await tester.pump();
    await tester.tap(find.text('Find a meetup'));
    expect(openedMeetups, isTrue);
  });

  testWidgets('reserved meetup shows the exact address release date', (
    tester,
  ) async {
    final event = _event(
      id: 'reserved',
      title: 'Dinner around a shared table',
      startsAt: _futureStart(days: 30, hour: 18),
    );
    final alternative = _event(
      id: 'alternative',
      title: 'Another meetup that stays in Meetups',
      startsAt: _futureStart(days: 32, hour: 18),
    );

    await _pumpHome(
      tester,
      HomeScreen(
        onOpenEvent: (_) {},
        firstName: 'Alex',
        city: 'Alkmaar',
        selectedEvent: event,
        selectedEvents: [event],
        availableEvents: [event, alternative],
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
      ),
    );

    expect(
      find.text(
        'Address available in VriendTime on '
        '${event.addressReleaseDateTimeLabel}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Open VriendTime after that time to see the exact public venue.',
      ),
      findsOneWidget,
    );
    expect(find.text('What happens next'), findsOneWidget);
    expect(find.text('Browse more meetups'), findsOneWidget);
    expect(find.text(alternative.title), findsNothing);
  });

  testWidgets('revealed address switches home to practical arrival guidance', (
    tester,
  ) async {
    final event = _event(
      id: 'revealed',
      title: 'Lunch in town',
      startsAt: _futureStart(days: 30, hour: 12, minute: 30),
    ).copyWith(
      venueName: 'Cafe Noord',
      venueAddress: 'Laat 1',
    );

    await _pumpHome(
      tester,
      HomeScreen(
        onOpenEvent: (_) {},
        firstName: 'Alex',
        city: 'Alkmaar',
        selectedEvent: event,
        selectedEvents: [event],
        availableEvents: [event],
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
      ),
    );

    expect(find.text('Cafe Noord, Laat 1'), findsOneWidget);
    expect(find.text('Open directions'), findsOneWidget);
    expect(find.text('Before you go'), findsOneWidget);
    expect(find.text('Arrive a little early'), findsOneWidget);
    expect(find.text('What happens next'), findsNothing);
  });
}

Future<void> _pumpHome(WidgetTester tester, HomeScreen home) async {
  tester.view
    ..physicalSize = const Size(375, 900)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 900),
          disableAnimations: true,
        ),
        child: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

MeetupEvent _event({
  required String id,
  required String title,
  required DateTime startsAt,
}) {
  return MeetupEvent(
    id: id,
    title: title,
    subtitle: 'A relaxed small-group meetup.',
    badge: 'Evening',
    slot: EventSlot.evening,
    city: 'Alkmaar',
    areaLabel: 'centre',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2)),
    activityLabel: 'Dinner',
    vibeLabel: 'Relaxed',
    policyLabel: '4+ to go',
    seatsFilled: 3,
    seatsTotal: 6,
    tags: const <String>['Dinner'],
    languages: const <String>['English'],
  );
}

DateTime _futureStart({
  required int days,
  required int hour,
  int minute = 0,
}) {
  final date = DateTime.now().add(Duration(days: days));
  return DateTime(date.year, date.month, date.day, hour, minute);
}
