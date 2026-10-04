import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';

void main() {
  test('member edits preserve weekly slots; organisers can reschedule',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': 'active'});
    final week = rows((await repo.load())['meetups'])[3];
    final edit = {
      'id': week['id'],
      'title': 'Museum',
      'venue': 'Museum cafe',
      'date': '2027-01-01',
      'time': '15:00'
    };
    await repo.act('schedule', edit);
    var saved = rows((await repo.load())['meetups'])[3];
    expect(saved['date'], week['date']);
    expect(saved['time'], week['time']);
    expect(saved['title'], 'Museum');
    await repo.act('admin_schedule', edit);
    saved = rows((await repo.load())['meetups'])[3];
    expect(saved['date'], '2027-01-01');
    expect(saved['time'], '15:00');
  });

  for (final weekly in [true, false]) {
    testWidgets(
        weekly
            ? 'weekly plan keeps its slot'
            : 'extra plan has date and time pickers', (tester) async {
      Json? result;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => scheduleCircleMeetup(context, (action,
                                  [data = const {}]) async {
                            result = data;
                          },
                              meetup: weekly
                                  ? {
                                      'id': 'week4',
                                      'week': 4,
                                      'title': 'Museum',
                                      'venue': 'Cafe',
                                      'date': '2027-01-07',
                                      'time': '19:30'
                                    }
                                  : null),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton),
          weekly ? findsNothing : findsNWidgets(2));
      if (weekly) {
        await tester.enterText(find.byType(TextField).first, 'Board games');
        await tester.tap(find.text('Save plan'));
        await tester.pumpAndSettle();
        expect(result?['date'], '2027-01-07');
        expect(result?['time'], '19:30');
        expect(result?['title'], 'Board games');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
