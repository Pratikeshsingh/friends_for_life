import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/circles/circle_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoCircleRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = DemoCircleRepository(await SharedPreferences.getInstance());
  });
  test('preview persists drafts without submitting an application', () async {
    await repository.act('draft', {
      'name': 'Asha',
      'availability': ['Thursday evening']
    });
    final restored =
        DemoCircleRepository(await SharedPreferences.getInstance());
    expect((await restored.load())['stage'], 'apply');
    expect((await restored.load())['application']['name'], 'Asha');
    await restored.act('apply', {'name': 'Asha'});
    expect((await repository.load())['stage'], 'waiting');
  });
  test(
      'preview invitation, attendance, private check-in and graduation survive reload',
      () async {
    await repository.act('preview', {'stage': 'invited'});
    await repository.act('join');
    final first = rows((await repository.load())['meetups']).first;
    await repository.act('rsvp', {'id': first['id'], 'going': true});
    await repository.act('rsvp', {'id': first['id'], 'going': true});
    expect(rows((await repository.load())['meetups']).first['confirmed'], 5);
    await repository.act('message', {'body': 'See you Thursday!'});
    await repository.act('complete_meetup', {'id': first['id']});
    await repository.act('check_in', {
      'id': first['id'],
      'feeling': '😊 Great',
      'connections': ['noor']
    });
    await repository.act('check_in',
        {'id': first['id'], 'feeling': '🙂 Good', 'connections': []});
    expect(rows((await repository.load())['check_ins']).length, 1);
    for (final m in rows((await repository.load())['meetups'])) {
      await repository.act('complete_meetup', {'id': m['id']});
    }
    expect((await repository.load())['stage'], 'completed');
    await repository.act('schedule', {
      'title': 'Coffee again',
      'date': '2026-12-01',
      'time': '19:00',
      'venue': 'Alkmaar'
    });
    expect(rows((await repository.load())['meetups']).length, 7);
    expect(rows((await repository.load())['messages']).last['body'],
        'See you Thursday!');
    await repository.act('reset');
    expect((await repository.load())['stage'], 'apply');
    expect(rows((await repository.load())['messages']), isEmpty);
  });
  test('editing one answer keeps a waiting applicant on the waiting list',
      () async {
    // This used to return them to 'apply', which showed the "Your application
    // is waiting for you" card to someone who had already applied — the
    // "update availability takes you back to onboarding" report.
    await repository.act('apply', {'name': 'Asha'});
    await repository.act('draft', {'name': 'Asha', 'age': 17});
    expect((await repository.load())['stage'], 'waiting');
  });
  test('an application that was never submitted stays in the apply stage',
      () async {
    await repository.act('draft', {'name': 'Asha'});
    expect((await repository.load())['stage'], 'apply');
  });
  test('preview organiser uses chosen start date for all six meetups',
      () async {
    await repository.act('admin_create', {
      'name': 'Friday friends',
      'schedule': 'Friday evenings',
      'start_date': '2026-11-06',
      'time': '20:00'
    });
    final ms = rows((await repository.load())['meetups']);
    expect(ms.first['date'], '2026-11-06T00:00:00.000');
    expect(ms.last['date'], '2026-12-11T00:00:00.000');
    expect(ms.last['time'], '20:00');
  });
  for (final width in [375.0, 768.0, 1440.0]) {
    for (final stage in [
      'apply',
      'waiting',
      'invited',
      'active',
      'completed'
    ]) {
      testWidgets('$stage layout fits ${width.toInt()}px', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await repository.act('preview', {'stage': stage});
        await tester.pumpWidget(MaterialApp(
            theme: buildTheme(),
            home: CircleShell(session: null, repository: repository)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('invitation demo checkout joins and can send messages',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await repository.act('preview', {'stage': 'invited'});
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: CircleShell(session: null, repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept invitation — €19'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm demo payment'), findsOneWidget);
    await tester.tap(find.text('Confirm demo payment'));
    await tester.pumpAndSettle();
    expect((await repository.load())['stage'], 'active');
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hi Circle!');
    // The composer is pinned above the menu, with an icon send button.
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Hi Circle!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed application save stays on the current step',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleApplication(
                    initial: const {
              'name': 'Asha',
              'city': 'Alkmaar',
              'date_of_birth': '1995-06-15',
              'languages': ['English'],
              'phone': '+31612345678'
            },
                    busy: false,
                    onSave: (_) async => throw StateError('offline'),
                    onSubmit: (_) async {})))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your answers could not be saved. Please try again.'),
        findsOneWidget);
    expect(find.text('Start with you.'), findsOneWidget);
  });
}
