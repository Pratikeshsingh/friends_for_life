import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
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

  testWidgets('the chat tab only appears once someone is in a Circle',
      (tester) async {
    await repository.act('preview', {'stage': 'waiting'});
    await _pumpShell(tester, repository);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('You’re on the list.'), findsOneWidget);

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
}
