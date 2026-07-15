import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/event_detail_screen.dart';
import 'package:vriendtime/src/widgets/meetup_explorer_tile.dart';

void main() {
  testWidgets('meetup details keep practical facts without duplicate guidance',
      (tester) async {
    final event = _meetup(
      id: 'reserved-meetup',
      title: 'Sunday dinner',
      startsAt: DateTime(2035, 7, 15, 18),
    );

    await _pumpMeetupsScreen(
      tester,
      width: 375,
      event: event,
      allEvents: [event],
      selectedEventIds: {event.id},
    );

    expect(find.text('Before the meetup'), findsNothing);
    expect(find.text('The vibe'), findsNothing);
    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text(event.addressReleaseSentence), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);
  });

  testWidgets('revealed venue remains visible after guidance is simplified',
      (tester) async {
    final event = _meetup(
      id: 'revealed-meetup',
      title: 'Canal coffee',
      startsAt: DateTime(2035, 7, 16, 10),
    ).copyWith(
      venueName: 'Cafe Binnen',
      venueAddress: 'Laat 1',
    );

    await _pumpMeetupsScreen(
      tester,
      width: 375,
      event: event,
      allEvents: [event],
      selectedEventIds: {event.id},
    );

    expect(find.text('Before the meetup'), findsNothing);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Cafe Binnen, Laat 1'), findsWidgets);
  });

  testWidgets('narrow meetup cards show date and time without ellipsis',
      (tester) async {
    final reserved = _meetup(
      id: 'narrow-reserved',
      title: 'A welcoming Sunday lunch',
      startsAt: DateTime(2035, 9, 15, 12),
    );
    final available = _meetup(
      id: 'narrow-available',
      title: 'Coffee beside the old canal',
      startsAt: DateTime(2035, 9, 16, 10, 30),
    );

    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await _pumpMeetupsScreen(
        tester,
        width: 320,
        event: reserved,
        allEvents: [reserved, available],
        selectedEventIds: {reserved.id},
      );
    } finally {
      FlutterError.onError = previousOnError;
    }

    final importantLabels = <String, String>{
      'explore-meetup-date-${available.id}':
          '${available.startsAt.day} September',
      'explore-meetup-time-${available.id}': available.detailTimeLabel,
      'reserved-meetup-date-${reserved.id}':
          '${reserved.startsAt.day} September',
      'reserved-meetup-time-${reserved.id}': reserved.detailTimeLabel,
    };

    expect(find.byType(MeetupExplorerTile), findsOneWidget);

    for (final entry in importantLabels.entries) {
      final text = tester.widget<Text>(find.byKey(ValueKey(entry.key)));
      expect(text.data, entry.value);
      expect(text.overflow, isNull);
      expect(text.maxLines, isNull);
    }

    final overflowErrors = errors.where(
      (error) => error.exceptionAsString().contains('A RenderFlex overflowed'),
    );
    expect(overflowErrors, isEmpty);
  });
}

Future<void> _pumpMeetupsScreen(
  WidgetTester tester, {
  required double width,
  required MeetupEvent event,
  required List<MeetupEvent> allEvents,
  required Set<String> selectedEventIds,
}) async {
  tester.view
    ..physicalSize = Size(width, 900)
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
      home: EventDetailScreen(
        event: event,
        scrollToTopVersion: 0,
        allEvents: allEvents,
        pastEvents: const <MeetupEvent>[],
        selectedEventIds: selectedEventIds,
        isUpdatingSelection: false,
        onSelectEvent: (_) {},
        onCancelEvent: (_) {},
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
        onFocusHandled: () {},
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

MeetupEvent _meetup({
  required String id,
  required String title,
  required DateTime startsAt,
}) {
  return MeetupEvent(
    id: id,
    title: title,
    subtitle: 'A relaxed small-group meetup.',
    badge: 'Daytime',
    slot: EventSlot.daytime,
    city: 'Alkmaar',
    areaLabel: 'city centre',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2, minutes: 30)),
    activityLabel: 'Coffee',
    vibeLabel: 'Relaxed',
    policyLabel: '4+ to go',
    seatsFilled: 2,
    seatsTotal: 6,
    tags: const ['Coffee'],
    languages: const ['English'],
  );
}
