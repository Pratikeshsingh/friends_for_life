// The visual pass: the plan behind "How it works", the timeline's pictures,
// and a one-time celebration at graduation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_widgets.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String day(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return DateTime(d.year, d.month, d.day).toIso8601String();
  }

  Json week(int n, int days) => {
        'id': 'w$n',
        'week': n,
        'title': circleWeekTitles[n - 1],
        'date': day(days),
        'time': '20:00',
        'venue': 'Hofman',
        'included': n == 2 || n == 4,
        'completed': days < 0,
      };

  Future<void> home(
      WidgetTester tester, String stage, List<Json> meetups) async {
    tester.view.physicalSize = const Size(430, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleHome(
                    state: {
              'stage': stage,
              'profile_id': 'me',
              'circle': {'id': 'c1', 'name': 'The Thursday Circle'},
              'members': const <Json>[],
              'meetups': meetups,
            },
                    demo: false,
                    busy: false,
                    act: (_, [__ = const {}]) async {},
                    onEdit: (_) {},
                    onMessages: () {})))));
    await tester.pumpAndSettle();
  }

  testWidgets('the rules sit behind "How it works"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await home(tester, 'active', [week(1, -6), week(2, 1), week(3, 8)]);
    expect(find.text('Week 2 of 6'), findsOneWidget);
    expect(find.textContaining('The dates are fixed.'), findsOneWidget);
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();
    expect(find.text('How the six weeks work'), findsOneWidget);
    expect(find.text('Two activities included'), findsOneWidget);
    expect(find.text('Week 5 is your group’s'), findsOneWidget);
  });

  testWidgets('every week has its picture, and says which week it is',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await home(tester, 'active', [week(1, -6), week(2, 1), week(3, 8)]);
    // Week 2 shows twice: on the next-meetup card and in the timeline.
    expect(find.byType(CircleMeetupTile), findsNWidgets(4));
    expect(find.text('WEEK 3'), findsOneWidget);
    expect(find.text('WEEK 2 · NEXT'), findsOneWidget);
    expect(find.text('Included in your fee'), findsOneWidget,
        reason: 'a positive badge on the next meetup');
  });

  testWidgets('graduation is celebrated once on this device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await home(tester, 'completed', [week(1, -40), week(6, -5)]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('vriendtime.celebrated.graduation:c1'), isTrue);
  });
}
