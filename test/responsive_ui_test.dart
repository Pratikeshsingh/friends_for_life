import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/event_detail_screen.dart';
import 'package:vriendtime/src/screens/home_screen.dart';
import 'package:vriendtime/src/screens/onboarding_screen.dart';

void main() {
  final widths = <double>[320, 375, 768, 1024, 1440];
  final sampleEvents = <MeetupEvent>[
    ...recommendedMeetupEvents,
    ...moreMeetupEvents,
  ];

  for (final width in widths) {
    testWidgets('onboarding has no layout overflow at ${width.toInt()}px',
        (tester) async {
      await _expectNoLayoutOverflow(
        tester,
        width: width,
        child: OnboardingScreen(
          onStart: () {},
          onSignIn: () {},
        ),
      );
    });

    testWidgets('home has no layout overflow at ${width.toInt()}px',
        (tester) async {
      await _expectNoLayoutOverflow(
        tester,
        width: width,
        child: HomeScreen(
          onOpenEvent: (_) {},
          userEmail: 'alex@example.com',
          firstName: 'Alex',
          city: 'Utrecht',
          selectedEvent: sampleEvents.first,
          selectedEvents: [sampleEvents.first],
          availableEvents: sampleEvents,
          unreadNotificationCount: 3,
          onOpenNotifications: () {},
        ),
      );
    });

    testWidgets('meetups has no layout overflow at ${width.toInt()}px',
        (tester) async {
      await _expectNoLayoutOverflow(
        tester,
        width: width,
        child: EventDetailScreen(
          event: null,
          scrollToTopVersion: 0,
          allEvents: sampleEvents,
          pastEvents: recentPastMeetupEvents,
          selectedEventIds: const <String>{},
          isUpdatingSelection: false,
          onSelectEvent: (_) {},
          onCancelEvent: (_) {},
          unreadNotificationCount: 0,
          onOpenNotifications: () {},
          onFocusHandled: () {},
        ),
      );
    });
  }

  testWidgets('home does not mislabel other-city meetups as local', (
    tester,
  ) async {
    await _expectNoLayoutOverflow(
      tester,
      width: 375,
      child: HomeScreen(
        onOpenEvent: (_) {},
        userEmail: 'alex@example.com',
        firstName: 'Alex',
        city: 'Utrecht',
        selectedEvent: null,
        selectedEvents: const <MeetupEvent>[],
        availableEvents: sampleEvents,
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
      ),
    );

    expect(find.text('Meetups in other cities'), findsOneWidget);
    expect(find.text('Coming up in Utrecht'), findsNothing);
    expect(find.text('Coming up in Alkmaar'), findsNothing);
  });

  testWidgets('onboarding remains usable with larger text', (tester) async {
    await _expectNoLayoutOverflow(
      tester,
      width: 375,
      textScaler: TextScaler.linear(2),
      child: OnboardingScreen(onStart: () {}, onSignIn: () {}),
    );
  });

  testWidgets('landing shows availability before signup and opens browsing', (
    tester,
  ) async {
    final startsAt = DateTime.now().add(const Duration(days: 3));
    final openMeetup = _responsiveTestMeetup(
      id: 'open-preview',
      title: 'Coffee near the old town',
      startsAt: startsAt,
    );
    final fullMeetup = _responsiveTestMeetup(
      id: 'full-preview',
      title: 'Dinner around a shared table',
      startsAt: startsAt.add(const Duration(hours: 8)),
    ).copyWith(seatsFilled: 6, seatsTotal: 6);

    await _expectNoLayoutOverflow(
      tester,
      width: 375,
      child: OnboardingScreen(
        onStart: () {},
        onSignIn: () {},
        availableEvents: [openMeetup, fullMeetup],
      ),
    );

    expect(find.text('Full'), findsOneWidget);
    final openPreview = find.bySemanticsLabel(
      RegExp('Coffee near the old town.*Open meetup details'),
    );
    await tester.ensureVisible(openPreview);
    await tester.tap(openPreview);
    await tester.pumpAndSettle();

    expect(find.text('Meetup details'), findsOneWidget);
    expect(
      find.text(
        'Browse first. Create an account only when you’re ready to reserve.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Already have an account? Sign in'),
      findsOneWidget,
    );
  });

  testWidgets('meetups distinguishes a load failure from no availability', (
    tester,
  ) async {
    var retryCount = 0;
    await _expectNoLayoutOverflow(
      tester,
      width: 375,
      child: EventDetailScreen(
        event: null,
        scrollToTopVersion: 0,
        allEvents: const <MeetupEvent>[],
        pastEvents: const <MeetupEvent>[],
        selectedEventIds: const <String>{},
        isUpdatingSelection: false,
        hasEventLoadError: true,
        onRetryEvents: () => retryCount++,
        onSelectEvent: (_) {},
        onCancelEvent: (_) {},
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
        onFocusHandled: () {},
      ),
    );

    expect(find.text('We couldn’t load meetups'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retryCount, 1);
  });

  testWidgets('snackbars stay on screen with a bottom navigation bar', (
    tester,
  ) async {
    final previousOnError = FlutterError.onError;
    final flutterErrors = <FlutterErrorDetails>[];

    tester.view
      ..physicalSize = const Size(375, 420)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    FlutterError.onError = flutterErrors.add;
    try {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved.')),
                      );
                    },
                    child: const Text('Show'),
                  ),
                ),
                bottomNavigationBar: const SizedBox(height: 120),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
    }

    final offscreenErrors = flutterErrors.where((details) {
      return details.exceptionAsString().contains(
            'Floating SnackBar presented off screen',
          );
    }).toList();

    expect(
      offscreenErrors,
      isEmpty,
      reason: offscreenErrors
          .map((details) => details.exceptionAsString())
          .join('\n\n'),
    );
  });

  testWidgets('reserve preview closes only the sheet', (tester) async {
    final event = _responsiveTestMeetup(
      id: 'reserve-preview-meetup',
      title: 'Reserve preview meetup',
      startsAt: DateTime.now().add(const Duration(days: 3)),
    );
    var selectedCount = 0;

    await _expectNoLayoutOverflow(
      tester,
      width: 375,
      child: EventDetailScreen(
        event: null,
        scrollToTopVersion: 0,
        allEvents: [event],
        pastEvents: const <MeetupEvent>[],
        selectedEventIds: const <String>{},
        isUpdatingSelection: false,
        onSelectEvent: (_) => selectedCount++,
        onCancelEvent: (_) {},
        unreadNotificationCount: 0,
        onOpenNotifications: () {},
        onFocusHandled: () {},
      ),
    );

    final eventTitle = find.text(event.title).first;
    await tester.ensureVisible(eventTitle);
    await tester.pump();
    await tester.tap(eventTitle);
    await tester.pump(const Duration(milliseconds: 500));
    final reserveButton = find.text('Reserve meetup').last;
    await tester.dragFrom(const Offset(200, 820), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(reserveButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(selectedCount, 1);
    expect(find.byType(EventDetailScreen), findsOneWidget);
  });
}

Future<void> _expectNoLayoutOverflow(
  WidgetTester tester, {
  required double width,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final previousOnError = FlutterError.onError;
  final flutterErrors = <FlutterErrorDetails>[];
  final height = width < 700 ? 900.0 : 960.0;

  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  FlutterError.onError = flutterErrors.add;
  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            disableAnimations: true,
            textScaler: textScaler,
          ),
          child: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  } finally {
    FlutterError.onError = previousOnError;
  }

  final overflowErrors = flutterErrors.where((details) {
    final message = details.exceptionAsString();
    return message.contains('A RenderFlex overflowed') ||
        message.contains('BoxConstraints forces an infinite') ||
        message.contains('was not laid out');
  }).toList();

  expect(
    overflowErrors,
    isEmpty,
    reason: overflowErrors.map((details) => details.exceptionAsString()).join(
          '\n\n',
        ),
  );
}

MeetupEvent _responsiveTestMeetup({
  required String id,
  required String title,
  required DateTime startsAt,
}) {
  return MeetupEvent(
    id: id,
    title: title,
    subtitle: 'A small test meetup.',
    badge: 'Daytime',
    slot: EventSlot.daytime,
    city: 'Alkmaar',
    areaLabel: 'centre',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2)),
    activityLabel: 'Coffee',
    vibeLabel: 'Relaxed',
    policyLabel: '4+ to go',
    seatsFilled: 1,
    seatsTotal: 6,
    tags: const ['Coffee'],
    languages: const ['English'],
  );
}
