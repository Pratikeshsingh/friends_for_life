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
      expect(find.text('3. Say yes'), findsOneWidget);
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
    expect(find.textContaining('€19 total'), findsNothing);
    expect(find.textContaining('Six people.'), findsNothing);
    // Week one in the six-week timeline is the dinner.
    expect(find.text('Dinner together'), findsOneWidget);
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
}
