import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/web_marketing_landing.dart';

void main() {
  for (final width in <double>[320, 768, 1440]) {
    testWidgets(
      'web marketing landing has no layout overflow at ${width.toInt()}px',
      (tester) async {
        await _pumpLanding(tester, width: width);

        expect(
            find.text('From “maybe someday” to a real plan.'), findsOneWidget);
        expect(find.text('The apps are on the way.'), findsOneWidget);
        expect(find.text('Coming soon on'), findsNWidgets(2));
      },
    );
  }

  testWidgets('web marketing landing exposes distinct account actions', (
    tester,
  ) async {
    var createCount = 0;
    var signInCount = 0;
    await _pumpLanding(
      tester,
      width: 1440,
      onCreateAccount: () => createCount++,
      onSignIn: () => signInCount++,
    );

    await tester.tap(find.text('Create account').first);
    expect(createCount, 1);
    await tester.tap(find.text('Sign in').first);
    expect(signInCount, 1);
  });

  testWidgets('web marketing landing can browse a meetup before signup', (
    tester,
  ) async {
    var openedEventId = '';
    await _pumpLanding(
      tester,
      width: 768,
      onOpenEvent: (event) => openedEventId = event.id,
    );

    final meetupCard = find.bySemanticsLabel(
      RegExp('Coffee by the canal.*Open details'),
    );
    await tester.ensureVisible(meetupCard);
    await tester.tap(meetupCard);
    expect(openedEventId, 'web-preview');
  });
}

Future<void> _pumpLanding(
  WidgetTester tester, {
  required double width,
  VoidCallback? onCreateAccount,
  VoidCallback? onSignIn,
  ValueChanged<MeetupEvent>? onOpenEvent,
}) async {
  final previousOnError = FlutterError.onError;
  final flutterErrors = <FlutterErrorDetails>[];
  tester.view
    ..physicalSize = Size(width, 1000)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  FlutterError.onError = flutterErrors.add;

  final startsAt = DateTime.now().add(const Duration(days: 5));
  final event = MeetupEvent(
    id: 'web-preview',
    title: 'Coffee by the canal',
    subtitle: 'A relaxed small-group coffee with new people.',
    badge: 'Daytime',
    slot: EventSlot.daytime,
    city: 'Utrecht',
    areaLabel: 'the city centre',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2)),
    activityLabel: 'Coffee',
    vibeLabel: 'Relaxed',
    policyLabel: '4+ to go',
    seatsFilled: 3,
    seatsTotal: 6,
    tags: const ['Coffee'],
    languages: const ['English'],
  );

  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            disableAnimations: true,
          ),
          child: WebMarketingLandingPage(
            availableEvents: [event],
            isLoadingMeetups: false,
            hasEventLoadError: false,
            onCreateAccount: onCreateAccount ?? () {},
            onSignIn: onSignIn ?? () {},
            onBrowseMeetups: () {},
            onOpenEvent: onOpenEvent ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
  } finally {
    FlutterError.onError = previousOnError;
  }

  final overflows = flutterErrors.where(
    (details) => details.exceptionAsString().contains('overflowed by'),
  );
  expect(overflows, isEmpty,
      reason: overflows.map((e) => e.exceptionAsString()).join('\n'));
}
