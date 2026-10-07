import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
import 'package:vriendtime/src/circles/circle_journey.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';

Future<void> _pumpShell(WidgetTester tester, CircleRepository repo) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
      theme: buildTheme(), home: CircleShell(session: null, repository: repo)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoCircleRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = DemoCircleRepository(await SharedPreferences.getInstance());
  });

  testWidgets('the chat tab is locked until someone is in a Circle',
      (tester) async {
    await repository.act('preview', {'stage': 'waiting'});
    await _pumpShell(tester, repository);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('You’re on the list.'), findsOneWidget);
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Opens when your place is confirmed'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await repository.act('preview', {'stage': 'active'});
    await _pumpShell(tester, repository);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('My Circle'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an invitation says when to reply by', (tester) async {
    await repository.act('preview', {'stage': 'invited'});
    await _pumpShell(tester, repository);
    expect(find.textContaining('Please reply by'), findsOneWidget);
    expect(find.text('Meet your Circle.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the commitment card follows the time of day people chose',
      (tester) async {
    Future<void> pumpWith(List<String> periods) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleApplication(
                      key: UniqueKey(),
                      initial: {
                        'name': 'Asha',
                        'availability_slots': {'thu': periods},
                      },
                      initialStep: 3,
                      busy: false,
                      onSave: (_) async {},
                      onSubmit: (_) async {})))));
      await tester.pumpAndSettle();
    }

    await pumpWith(['morning']);
    expect(find.textContaining('One morning a week.'), findsOneWidget);
    await pumpWith(['morning', 'evening']);
    expect(find.textContaining('One meetup a week.'), findsOneWidget);
    expect(find.textContaining('five or six people'), findsOneWidget);
  });

  testWidgets('withdrawing lives in the profile, not on the home screen',
      (tester) async {
    await repository.act('preview', {'stage': 'waiting'});
    await _pumpShell(tester, repository);
    expect(find.text('Withdraw my application'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Withdraw my application'));
    await tester.tap(find.text('Withdraw my application'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw your application?'), findsOneWidget);
    await tester.tap(find.text('Keep my place'));
    await tester.pumpAndSettle();
    expect((await repository.load())['stage'], 'waiting');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the six weeks reveal once on screen, and can show progress',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
            body: SingleChildScrollView(child: CircleJourney()))));
    await tester.pump();
    await tester.pumpAndSettle();
    final last = tester.widget<Opacity>(find
        .ancestor(
            of: find.text('One last get-together'),
            matching: find.byType(Opacity))
        .first);
    expect(last.opacity, 1.0);

    // Inside the app: weeks behind get a tick, the next one is marked.
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
            body: SingleChildScrollView(
                child:
                    CircleJourney(compact: true, completed: 2, current: 3)))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('one interests question, and older plan answers carry over',
      (tester) async {
    Json? saved;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleApplication(
                    initial: const {
              'name': 'Asha',
              'interests': ['Books'],
              'activities': ['A walk', 'Coffee & conversation'],
              'goals': ['Local friends'],
            },
                    initialStep: 2,
                    busy: false,
                    onSave: (d) async => saved = d,
                    onSubmit: (_) async {})))));
    await tester.pumpAndSettle();
    expect(find.text('A plan you’d say yes to'), findsNothing);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(saved!['interests'], containsAll(['Books', 'Walking', 'Coffee']));
    // The database still requires the old field, so it mirrors interests.
    expect(saved!['activities'], saved!['interests']);
  });

  testWidgets('birthday is three dropdowns and rejects impossible dates',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleApplication(initial: const {
          'name': 'Asha',
          'date_of_birth': '1995-03-30',
          'languages': ['English'],
          'phone': '0612345678',
        }, busy: false, onSave: (_) async {}, onSubmit: (_) async {})))));
    await tester.pumpAndSettle();
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    // Change the month to February: 30 February does not exist.
    await tester.tap(find.text('March'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('February').last);
    await tester.pumpAndSettle();
    expect(find.text('That date doesn’t exist. Check the day and month.'),
        findsOneWidget);
  });

  testWidgets('notifications split into new and earlier, and open on tap',
      (tester) async {
    await repository.act('preview', {'stage': 'invited'});
    await _pumpShell(tester, repository);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(find.text('2 h ago'), findsOneWidget);
    await tester.tap(find.text('Your Circle is ready'));
    await tester.pumpAndSettle();
    // The sheet closes and the person lands on their Circle.
    expect(find.text('Mark all as read'), findsNothing);
    expect(find.text('Meet your Circle.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
