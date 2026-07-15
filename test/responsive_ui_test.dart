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

  for (final viewport in const <Size>[
    Size(375, 740),
    Size(430, 820),
    Size(600, 900),
    Size(699, 900),
    Size(700, 900),
  ]) {
    testWidgets(
      'landing brings real meetups into the first screen at '
      '${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        final event = _responsiveTestMeetup(
          id: 'landing-density-${viewport.width.toInt()}',
          title: 'Coffee by the canal',
          startsAt: DateTime(2026, 9, 23, 10),
        );

        await _expectNoLayoutOverflow(
          tester,
          width: viewport.width,
          height: viewport.height,
          child: OnboardingScreen(
            onStart: () {},
            onSignIn: () {},
            availableEvents: [event],
          ),
        );

        final proofHeadingTop =
            tester.getTopLeft(find.text('Upcoming meetups')).dy;
        final firstMeetupTop = tester
            .getTopLeft(
              find.bySemanticsLabel(
                RegExp('Coffee by the canal.*Open meetup details'),
              ),
            )
            .dy;

        expect(
          proofHeadingTop,
          lessThan(viewport.height * 0.72),
          reason: 'Meetup proof should begin within the first screen.',
        );
        expect(
          firstMeetupTop,
          lessThan(viewport.height * 0.80),
          reason: 'A real meetup should be visible without an initial scroll.',
        );
      },
    );
  }

  testWidgets('landing keeps both account actions in a tall phone view', (
    tester,
  ) async {
    const viewport = Size(402, 874);

    await _expectNoLayoutOverflow(
      tester,
      width: viewport.width,
      height: viewport.height,
      child: OnboardingScreen(
        onStart: () {},
        onSignIn: () {},
        availableEvents: sampleEvents.take(4).toList(),
      ),
    );

    final createAccountButton =
        find.widgetWithText(ElevatedButton, 'Create an account');
    final signInButton =
        find.widgetWithText(TextButton, 'I already have an account');

    expect(createAccountButton, findsOneWidget);
    expect(signInButton, findsOneWidget);
    expect(
      tester.getBottomRight(createAccountButton).dy,
      lessThan(viewport.height),
    );
    expect(
      tester.getBottomRight(signInButton).dy,
      lessThan(viewport.height),
    );

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    expect(verticalScrollable, findsOneWidget);
    final scrollPosition =
        tester.state<ScrollableState>(verticalScrollable).position;
    final panel = find.byKey(const ValueKey('landing-meetup-proof-panel'));
    final panelBottomAtRest = tester.getBottomRight(panel).dy;

    expect(
      panelBottomAtRest - scrollPosition.maxScrollExtent,
      closeTo(viewport.height, 0.5),
      reason: 'The page should end with the panel, not a phantom bottom gap.',
    );
  });

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
        'Everything you need to decide, before you reserve.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Already have an account? Sign in'),
      findsNothing,
    );
    expect(
      find.text('Create an account or sign in to reserve.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ElevatedButton, 'Create account'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Sign in'), findsOneWidget);

    await tester.ensureVisible(
      find.text('This meetup is full. Reservations are no longer available.'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This meetup is full. Reservations are no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'public meetup explorer clips and pins its header while scrolling',
      (tester) async {
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(30));
    final explorerEvents = List.generate(
      5,
      (index) => _responsiveTestMeetup(
        id: 'pinned-explorer-$index',
        title: 'Meetup number ${index + 1}',
        startsAt: DateTime(2026, 8, 18 + index, 10 + index),
      ),
    );

    await _expectNoLayoutOverflow(
      tester,
      width: 320,
      height: 900,
      child: OnboardingScreen(
        onStart: () {},
        onSignIn: () {},
        availableEvents: explorerEvents,
      ),
    );

    final seeAll = find.widgetWithText(TextButton, 'See all');
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    final surface = find.byKey(
      const ValueKey('public-meetup-explorer-surface'),
    );
    final pinnedHeader = find.descendant(
      of: surface,
      matching: find.byType(SliverPersistentHeader),
    );
    final subtitle = find.byKey(
      const ValueKey('public-meetup-explorer-subtitle'),
    );
    final headerDecoration = find.byKey(
      const ValueKey('public-meetup-explorer-header-decoration'),
    );

    expect(surface, findsOneWidget);
    final clip = tester.widget<ClipRRect>(surface);
    expect(clip.borderRadius, sheetRadius);
    expect(clip.clipBehavior, Clip.antiAlias);
    expect(tester.widget<SliverPersistentHeader>(pinnedHeader).pinned, isTrue);
    final titleText = tester.widget<Text>(
      find.byKey(const ValueKey('public-meetup-explorer-title')),
    );
    expect(titleText.data, 'Explore upcoming meetups');
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, isNull);
    expect(tester.widget<Opacity>(subtitle).opacity, 1);
    expect(
      (tester.widget<DecoratedBox>(headerDecoration).decoration
              as BoxDecoration)
          .boxShadow,
      isEmpty,
    );

    final scrollView = find.byKey(
      const ValueKey('public-meetup-explorer-scroll-view'),
    );
    final sheetScrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    );
    final scrollPosition =
        tester.state<ScrollableState>(sheetScrollable).position;
    expect(scrollPosition.maxScrollExtent, greaterThan(300));

    scrollPosition.jumpTo(300);
    await tester.pump();

    final surfaceTop = tester.getTopLeft(surface).dy;
    final title = find.byKey(
      const ValueKey('public-meetup-explorer-title'),
    );
    final close = find.byKey(
      const ValueKey('public-meetup-explorer-close'),
    );
    expect(title, findsOneWidget);
    expect(close, findsOneWidget);
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(surfaceTop));
    expect(tester.getTopLeft(title).dy, lessThan(surfaceTop + 78));
    expect(tester.getTopLeft(close).dy, greaterThanOrEqualTo(surfaceTop));
    expect(tester.widget<Opacity>(subtitle).opacity, lessThan(0.05));
    expect(
      (tester.widget<DecoratedBox>(headerDecoration).decoration
              as BoxDecoration)
          .boxShadow,
      isNotEmpty,
    );
  });

  testWidgets('public meetup explorer header supports large text', (
    tester,
  ) async {
    final events = List.generate(
      5,
      (index) => _responsiveTestMeetup(
        id: 'large-text-explorer-$index',
        title: 'Large text meetup ${index + 1}',
        startsAt: DateTime(2026, 9, 18 + index, 10),
      ),
    );

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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: OnboardingScreen(
          onStart: () {},
          onSignIn: () {},
          availableEvents: events,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final seeAll = find.widgetWithText(TextButton, 'See all');
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    final title = tester.widget<Text>(
      find.byKey(const ValueKey('public-meetup-explorer-title')),
    );
    expect(title.data, 'Explore upcoming meetups');
    expect(title.overflow, isNull);
    expect(header.delegate.maxExtent, greaterThanOrEqualTo(190));
    expect(header.delegate.minExtent, greaterThanOrEqualTo(96));
  });

  testWidgets('public meetup card sign in uses the sign in route', (
    tester,
  ) async {
    var createAccountCount = 0;
    var signInCount = 0;
    final event = _responsiveTestMeetup(
      id: 'public-sign-in',
      title: 'Coffee and conversation',
      startsAt: DateTime.now().add(const Duration(days: 3)),
    );

    await _expectNoLayoutOverflow(
      tester,
      width: 320,
      child: OnboardingScreen(
        onStart: () => createAccountCount++,
        onSignIn: () => signInCount++,
        availableEvents: [event],
      ),
    );

    final preview = find.bySemanticsLabel(
      RegExp('Coffee and conversation.*Open meetup details'),
    );
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(signInCount, 1);
    expect(createAccountCount, 0);
  });

  testWidgets('public meetup card create account uses the signup route', (
    tester,
  ) async {
    var createAccountCount = 0;
    var signInCount = 0;
    final event = _responsiveTestMeetup(
      id: 'public-create-account',
      title: 'Dinner and conversation',
      startsAt: DateTime.now().add(const Duration(days: 4)),
    );

    await _expectNoLayoutOverflow(
      tester,
      width: 320,
      child: OnboardingScreen(
        onStart: () => createAccountCount++,
        onSignIn: () => signInCount++,
        availableEvents: [event],
      ),
    );

    final preview = find.bySemanticsLabel(
      RegExp('Dinner and conversation.*Open meetup details'),
    );
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Create account'),
    );
    await tester.pumpAndSettle();

    expect(createAccountCount, 1);
    expect(signInCount, 0);
  });

  testWidgets('public preview keeps its complete date and time on 320px', (
    tester,
  ) async {
    final event = _responsiveTestMeetup(
      id: 'narrow-date-time',
      title: 'Lunch near the old town',
      startsAt: DateTime(2026, 9, 23, 12),
    );

    await _expectNoLayoutOverflow(
      tester,
      width: 320,
      child: OnboardingScreen(
        onStart: () {},
        onSignIn: () {},
        availableEvents: [event],
      ),
    );

    expect(find.text(event.detailDateLabel), findsOneWidget);
    expect(find.text(event.detailTimeLabel), findsOneWidget);
    final dateText = tester.widget<Text>(find.text(event.detailDateLabel));
    final timeText = tester.widget<Text>(find.text(event.detailTimeLabel));
    expect(dateText.overflow, isNull);
    expect(timeText.overflow, isNull);
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
  double? height,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final previousOnError = FlutterError.onError;
  final flutterErrors = <FlutterErrorDetails>[];
  final resolvedHeight = height ?? (width < 700 ? 900.0 : 960.0);

  tester.view
    ..physicalSize = Size(width, resolvedHeight)
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
            size: Size(width, resolvedHeight),
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
