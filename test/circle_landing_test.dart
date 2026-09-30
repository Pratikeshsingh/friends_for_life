import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/circles/circle_landing.dart';
import 'package:vriendtime/src/widgets/circle_loading.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets(
        'public landing explains Circles without preview controls at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var created = 0, signedIn = 0;
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: CircleLanding(
              onApply: () => created++,
              onSignIn: () => signedIn++,
              loadActivities: () async => [])));
      await tester.pumpAndSettle();
      expect(find.text('Strangers on week one.\nFriends by week six.'),
          findsOneWidget);
      expect(find.textContaining('Preview'), findsNothing);
      expect(find.textContaining('example people'), findsNothing);
      await tester.tap(find.text('Apply for a spot').first);
      expect(created, 1);
      await tester.tap(find.text('Sign in').first);
      expect(signedIn, 1);
      await tester
          .ensureVisible(find.text('The next introductions are taking shape.'));
      await tester.pumpAndSettle();
      expect(find.text('The next introductions are taking shape.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Terms'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('activities use supplied real records and show details',
      (tester) async {
    final event = MeetupEvent.fromRow({
      'id': 'actual-id',
      'title': 'Coffee by the canal',
      'city': 'Alkmaar',
      'starts_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'subtitle': 'A relaxed afternoon',
      'activity_type': 'Coffee',
      'status': 'open',
      'capacity': 6
    });
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: CircleLanding(
            onApply: () {},
            onSignIn: () {},
            loadActivities: () async => [event])));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Coffee by the canal'), findsOneWidget);
    await tester.ensureVisible(find.text('About this activity'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('About this activity'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('A relaxed afternoon'), findsOneWidget);
  });
  testWidgets('failed feed offers retry rather than invented events',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: CircleLanding(
            onApply: () {},
            onSignIn: () {},
            loadActivities: () async {
              if (calls++ == 0) throw StateError('offline');
              return [];
            })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
        find.text('The next introductions are taking shape.'), findsOneWidget);
  });
  testWidgets('reduced-motion loading stays still and labels its purpose',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: Center(child: CircleLoading())))));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Opening your Circle…'), findsOneWidget);
  });
  testWidgets('pending activities show loading until the request completes',
      (tester) async {
    final request = Completer<List<MeetupEvent>>();
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: CircleLanding(
            onApply: () {},
            onSignIn: () {},
            loadActivities: () => request.future)));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    request.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
