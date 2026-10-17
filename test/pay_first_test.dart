// Pay first (16 October): an invitation shows seats, not people, and the
// weeks without dates; paying confirms the place; the chat and the group
// open when the organiser starts the Circle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_admin.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/theme.dart';

/// The preview organiser, with a Circle still finding its people.
class _Filling extends DemoCircleRepository {
  _Filling(super.prefs);
  final acted = <(String, Json)>[];

  @override
  Future<Json> adminLoad() async {
    final data = await super.adminLoad();
    final circles = rows(data['circles']);
    circles.first = {
      ...circles.first,
      'pay_first': true,
      'started_at': null,
      'status': 'offered',
      'members': [
        for (var i = 0; i < 6; i++)
          {
            'profile_id': 'p$i',
            'name': 'Member $i',
            'status': i < 5 ? 'joined' : 'invited',
            'payment_status': i < 5 ? 'paid' : 'unpaid',
          }
      ],
    };
    return {...data, 'circles': circles};
  }

  @override
  Future<void> act(String action, [Json data = const {}]) async {
    if (action == 'admin_start') {
      acted.add((action, data));
      return;
    }
    return super.act(action, data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<DemoCircleRepository> demo(String stage) async {
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': stage});
    return repo;
  }

  Future<void> pump(WidgetTester tester, Widget home,
      {Size size = const Size(430, 3200)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('an invitation shows seats and weeks, not people or dates',
      (tester) async {
    await pump(
        tester, CircleShell(session: null, repository: await demo('invited')));
    expect(find.text('Your seat is waiting'), findsOneWidget);
    expect(find.textContaining('We’ve found people for Thursday evenings'),
        findsOneWidget);
    expect(find.text('3 of 6 places confirmed'), findsOneWidget);
    expect(find.text('Noor'), findsNothing, reason: 'no names before paying');
    expect(find.text('Your six weeks'), findsOneWidget);
    expect(find.text('WEEK 1'), findsOneWidget);
    expect(find.textContaining('Thu '), findsNothing, reason: 'no dates yet');
    expect(find.text('Included in your fee'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Accept invitation'));
    await tester.tap(find.text('Accept invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Try joining your Circle'), findsOneWidget);
    await tester.tap(find.text('Confirm demo payment'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('You’re in'), findsOneWidget);
    expect(find.text('4 of 6 places confirmed'), findsOneWidget);
    expect(find.text('Accept invitation'), findsNothing);

    await tester.tap(find.text('Messages'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Opens when your group is booked'), findsOneWidget,
        reason: 'the chat opens at the start, not at payment');
  });

  testWidgets('a paid place waiting to start says what happens next',
      (tester) async {
    await pump(tester,
        CircleShell(session: null, repository: await demo('confirmed')));
    expect(find.text('Place confirmed'.toUpperCase()), findsOneWidget);
    expect(
        find.text(
            'We’ll tell you the dates and introduce your group as soon as it’s booked.'),
        findsOneWidget);
    expect(find.textContaining('refund'), findsNothing,
        reason: 'no prompt to ask for the money back');
  });

  testWidgets('the organiser starts a filled group on its own weekday',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _Filling(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': 'active'});
    await pump(
        tester, CircleAdmin(repository: repo, onChanged: () {}, initialTab: 0));
    expect(find.text('Groups ready to start'), findsOneWidget);
    expect(find.textContaining('5 of 6 paid'), findsWidgets);
    await tester.tap(find.text('Start this Circle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paid members hear it straight away'),
        findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.acted.single.$1, 'admin_start');
    final day = DateTime.parse('${repo.acted.single.$2['start_date']}');
    final today = DateTime.now();
    expect(day.difference(DateTime(today.year, today.month, today.day)).inDays,
        greaterThanOrEqualTo(3));
  });
}
