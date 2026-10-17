// The installed app opens on a short welcome, not the website's landing
// page: whoever downloaded it already chose VriendTime.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_welcome.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(375, 548)]) {
    testWidgets('one picture, one line and the way in · ${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var applied = 0, signedIn = 0;
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: CircleWelcome(
              onApply: () => applied++, onSignIn: () => signedIn++)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          find.text('5–6 people · 6 weekly meetups · Alkmaar'), findsOneWidget);
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.tap(find.text('Sign in'));
      expect((applied, signedIn), (1, 1));

      await tester.ensureVisible(find.text('How Circles work'));
      await tester.tap(find.text('How Circles work'));
      await tester.pumpAndSettle();
      expect(find.text('Strangers on week one.\nFriends by week six.'),
          findsWidgets,
          reason: 'the full story is one tap away');
    });
  }
}
