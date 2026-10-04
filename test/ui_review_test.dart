import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/widgets/brand_logo.dart';

void main() {
  testWidgets('an invitation can be accepted at the top and after the dates',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleHome(
                    state: const {
              'stage': 'invited',
              'profile_id': 'me',
              'circle': {
                'name': 'The Monday Circle',
                'start_date': '2099-01-05'
              },
              'members': [
                {'id': 'noor', 'name': 'Noor'}
              ],
              'meetups': [],
            },
                    demo: false,
                    busy: false,
                    act: (_, [__ = const {}]) async {},
                    onEdit: (_) {},
                    onMessages: () {})))));
    final people = tester.getTopLeft(find.text('The people in your Circle'));
    final accept = find.text('Accept invitation — €19');
    expect(accept, findsNWidgets(2));
    expect(tester.getTopLeft(accept.first).dy, lessThan(people.dy));
    expect(tester.getTopLeft(accept.last).dy, greaterThan(people.dy));
    expect(find.text('Does this group work for you?'), findsOneWidget);
  });

  testWidgets('the header shows the mark alone when the name does not fit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
            body: Center(
                child:
                    SizedBox(width: 90, child: BrandLockup(logoSize: 34))))));
    expect(find.byType(BrandLogoMark), findsOneWidget);
    expect(find.textContaining('Vriend'), findsNothing);

    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
            body: Center(
                child:
                    SizedBox(width: 400, child: BrandLockup(logoSize: 34))))));
    expect(find.textContaining('Vriend'), findsOneWidget);
  });

  test('states read as plain words', () {
    expect(circleStatusLabel('awaiting_payment'), 'Awaiting payment');
    expect(circleStatusLabel('offered'), 'Invitations sent');
    expect(circlePaymentLabel({'status': 'paid', 'refund': 'requested'}),
        'Refund requested');
    expect(circlePaymentLabel({'status': 'paid'}), 'Paid · place confirmed');
  });
}
