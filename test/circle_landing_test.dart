import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/theme.dart';
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
              onApply: () => created++, onSignIn: () => signedIn++)));
      await tester.pumpAndSettle();
      expect(find.text('Strangers on week one.\nFriends by week six.'),
          findsOneWidget);
      expect(find.textContaining('Preview'), findsNothing);
      expect(find.textContaining('example people'), findsNothing);
      await tester.tap(find.text('Apply for a spot').first);
      expect(created, 1);
      await tester.tap(find.text('Sign in').first);
      expect(signedIn, 1);

      // What happens after applying is spelled out, and the old public
      // meetups section is gone.
      await tester.ensureVisible(find.text('What happens after you apply.'));
      await tester.pumpAndSettle();
      expect(find.text('1. Apply'), findsOneWidget);
      expect(find.text('3. Pay and meet'), findsOneWidget);
      expect(find.textContaining('Around the VriendTime table'), findsNothing);
      expect(find.text('Activities'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Terms'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the landing tells one story: five or six people, dinner first',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: CircleLanding(onApply: () {}, onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(find.textContaining('Five or six people'), findsWidgets);
    expect(find.textContaining('€39 total'), findsNothing);
    expect(find.textContaining('Six people.'), findsNothing);
    // Week one in the six-week timeline is a first hello, and the price
    // says two activities are included.
    expect(find.text('Hello, new faces'), findsOneWidget);
    expect(find.text('Two activities included, booked by us'), findsOneWidget);
    expect(find.text('€39'), findsOneWidget, reason: 'the price, large');
    expect(find.text('Two activities included'), findsOneWidget,
        reason: 'said at the top, as one badge');
    expect(
        find.text('€39 for six weeks · You pay only once your group is ready'),
        findsOneWidget);
    expect(find.text('What does it cost?'), findsOneWidget);
    expect(find.byType(ExpansionTile, skipOffstage: false), findsNWidgets(6),
        reason: 'six questions, no overlap');
  });

  for (final (w, h) in [(390.0, 664.0), (375.0, 548.0)]) {
    testWidgets(
        'a phone sees the people, the button and the price at once · ${w.toInt()}x${h.toInt()}',
        (tester) async {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: CircleLanding(onApply: () {}, onSignIn: () {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final apply =
          find.widgetWithText(ElevatedButton, 'Apply for a spot').first;
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(h));
      expect(find.text('Two activities included'), findsOneWidget);
      expect(
          find.text('5–6 people · 6 weekly meetups · Alkmaar'), findsOneWidget);
      expect(find.textContaining('Plus, if you like'), findsNothing,
          reason: 'the top stays light; the one-to-ones are explained below');
      if (h > 600) {
        final price = find
            .text('€39 for six weeks · You pay only once your group is ready');
        expect(tester.getRect(price).bottom, lessThanOrEqualTo(h));
      }
    });
  }

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
}
