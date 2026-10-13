import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_invite_friend.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  testWidgets('the check-in asks, optionally, how the place was',
      (tester) async {
    Json? sent;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showCircleCheckIn(
                    context,
                    {'id': 'm1', 'venue': 'Rozey Alkmaar'},
                    {
                      'members': [
                        {'id': 'a', 'name': 'Anna'}
                      ]
                    },
                    (a, [d = const {}]) async => sent = d),
                child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('How was Rozey Alkmaar? (Optional)'), findsOneWidget);
    // The same four smileys, once for the evening and once for the place.
    expect(find.text('🙂 Good'), findsNWidgets(2));
    await tester.tap(find.text('🙂 Good').first);
    await tester.tap(find.text('😊 Great').last);
    await tester.pump();
    await tester.tap(find.text('Save privately'));
    await tester.pumpAndSettle();
    expect(sent!['feeling'], '🙂 Good');
    expect(sent!['place_feeling'], '😊 Great');
  });

  testWidgets('the invite sheet offers WhatsApp and a message to copy',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showInviteFriend(context),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Share on WhatsApp'), findsOneWidget);
    expect(find.text('Copy message'), findsOneWidget);
    expect(find.textContaining('https://vriendtime.com'), findsOneWidget);
  });
}
