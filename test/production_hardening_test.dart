import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/circles/circle_meetup_detail.dart';
import 'package:vriendtime/src/core/theme.dart';

Json fixture({String name = 'Fresh Circle'}) => {
      'stage': 'active',
      'profile_id': 'me',
      'exclusions': [],
      'circle': {'name': name},
      'application': {'name': 'Asha'},
      'members': [
        {'id': 'me', 'name': 'Asha'}
      ],
      'messages': [],
      'meetups': [
        {
          'id': 'past',
          'week': 1,
          'title': 'Old dinner',
          'date': '2020-01-01',
          'time': '19:30',
          'completed': false
        },
        {
          'id': 'week4',
          'week': 4,
          'title': 'Upcoming weekly plan',
          'date': '2090-01-01',
          'time': '19:30',
          'venue': 'Cafe',
          'completed': false,
          'plan_version': 0
        },
        {
          'id': 'extra',
          'week': null,
          'title': 'Extra coffee',
          'date': '2090-01-02',
          'time': '12:00',
          'venue': 'Coffee place',
          'completed': false,
          'created_by': 'me'
        },
      ],
    };

class DelayedRepository implements CircleRepository {
  int loads = 0;
  final delayed = Completer<Json>();
  @override
  bool get isDemo => true;
  @override
  Future<Json> load() {
    loads++;
    if (loads == 2) return delayed.future;
    return Future.value(fixture());
  }

  @override
  Future<void> act(String action, [Json data = const {}]) async {}
  @override
  Future<Json> adminLoad() async => {};
}

void main() {
  test('Amsterdam fallback and UTC payload represent the same instant', () {
    expect(circleMeetupStart({'date': '2026-07-01', 'time': '19:30'}),
        DateTime.utc(2026, 7, 1, 17, 30));
    expect(circleMeetupStart({'date': '2026-12-01', 'time': '19:30'}),
        DateTime.utc(2026, 12, 1, 18, 30));
    expect(circleMeetupStart({'starts_at': '2026-07-01T17:30:00Z'}),
        DateTime.utc(2026, 7, 1, 17, 30));
    expect(
        circleCalendarUri(
                {'title': 'Dinner', 'date': '2026-07-01', 'time': '19:30'})
            .queryParameters['dates'],
        '20260701T173000Z/20260701T193000Z');
  });
  testWidgets(
      'all extras are visible; a past uncompleted meetup is not featured',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleHome(
                    state: fixture(),
                    demo: false,
                    busy: false,
                    act: (_, [__ = const {}]) async {},
                    onEdit: (_) {},
                    onMessages: () {})))));
    expect(find.text('Extra coffee'), findsOneWidget);
    expect(find.text('Upcoming weekly plan'), findsNWidgets(2));
    expect(find.text('Old dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed plan save retains input and retry closes only after success',
      (tester) async {
    var tries = 0;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => scheduleCircleMeetup(context, (action,
                            [data = const {}]) async {
                          tries++;
                          if (tries == 1) {
                            throw StateError('Network unavailable');
                          }
                        }, meetup: fixture()['meetups'][1]),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Board games');
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.text('Board games'), findsOneWidget);
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tries, 2);
  });
  testWidgets('a late older snapshot cannot overwrite a newer refresh',
      (tester) async {
    final repo = DelayedRepository();
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: CircleShell(session: null, repository: repo)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 25));
    expect(repo.loads, 2);
    final refresh =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    repo.delayed.complete(fixture(name: 'Stale Circle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stale Circle'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
