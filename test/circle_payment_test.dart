import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';

void main() {
  final invitation = <String, dynamic>{
    'stage': 'invited',
    'circle': {
      'name': 'Alkmaar Circle',
      'start_date': '2027-10-07',
      'schedule': 'Thursday evenings'
    },
    'members': [],
    'meetups': [],
  };
  Widget page(Json state, CircleAction action) => MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: CircleHome(
                  state: state,
                  demo: false,
                  busy: false,
                  act: action,
                  onEdit: (_) {},
                  onMessages: () {}))));

  testWidgets(
      'manual acceptance requires explicit consent and never confirms payment',
      (tester) async {
    String? action;
    Json? payload;
    await tester.pumpWidget(page(invitation, (a, [p = const {}]) async {
      action = a;
      payload = p;
    }));
    await tester.tap(find.text('Accept invitation — €19').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Agree & accept'))
            .onPressed,
        isNull);
    expect(find.textContaining('card details'), findsNothing);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree & accept'));
    await tester.pumpAndSettle();
    expect(action, 'join');
    expect(payload, {'agree_to_pay': true});
  });

  testWidgets(
      'accepted unpaid invitation explains manual arrangement and cannot accept twice',
      (tester) async {
    await tester.pumpWidget(page({
      ...invitation,
      'payment_agreement': {'status': 'awaiting_payment'}
    }, (a, [p = const {}]) async {}));
    expect(
        find.textContaining('will send you the payment link'), findsOneWidget);
    // Accepted: a quiet confirmation, not a second accept button.
    expect(find.text('Invitation accepted'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Accept invitation — €19'),
        findsNothing);
    expect(find.textContaining('Tikkie'), findsNothing);
  });

  testWidgets(
      'cancelled paid Circle shows refund status without an active RSVP',
      (tester) async {
    await tester.pumpWidget(page(
        {...invitation, 'stage': 'cancelled', 'payment': 'paid'},
        (a, [p = const {}]) async {}));
    expect(find.textContaining('refund is being arranged'), findsOneWidget);
    expect(find.text('Accept invitation — €19'), findsNothing);
    expect(find.text('Find another Circle'), findsNothing);
  });
}
