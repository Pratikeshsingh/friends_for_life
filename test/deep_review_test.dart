// The deep visual review, 15 October: room for the task on a phone (a
// compact bar, a quiet tab bar, no tabs while applying or typing), the
// Circle's name above its chat, a loading state that fits, and the
// organiser's full-screen chat with older messages and removal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_admin_chat.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/circles/circle_shell.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/widgets/circle_loading.dart';

class _ChatRepo extends DemoCircleRepository {
  _ChatRepo(super.preferences);
  final asked = <String>[];

  Json _msg(int i) => {
        'id': 'm$i',
        'name': 'Anna',
        'body': 'Message $i',
        'created_at': DateTime.utc(2026, 10, 1)
            .add(Duration(minutes: i))
            .toIso8601String(),
      };

  @override
  Future<List<Json>> adminMessages(String circleId) async =>
      [for (var i = 51; i <= 250; i++) _msg(i)];

  @override
  Future<List<Json>> adminMessagesBefore(String circleId, Json before) async {
    asked.add('${before['id']}');
    return [for (var i = 1; i <= 50; i++) _msg(i)];
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
      {Size size = const Size(390, 620)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  final bar = find.byKey(const ValueKey('circle-top-bar'));
  final tabs = find.byKey(const ValueKey('floating-glass-navigation'));

  testWidgets('a phone keeps most of its screen for the page', (tester) async {
    await pump(
        tester, CircleShell(session: null, repository: await demo('active')));
    expect(tester.getSize(bar).height, lessThanOrEqualTo(54));
    expect(tester.getSize(tabs).height, lessThanOrEqualTo(72));

    await tester.tap(find.text('Profile'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Profile'), findsOneWidget,
        reason: 'said once, by the tab: no title repeating it');
    expect(find.text('A familiar face'), findsNothing);
  });

  testWidgets('the chat shows its Circle and stays above the keyboard',
      (tester) async {
    final repo = await demo('active');
    final name = '${((await repo.load())['circle'] as Map)['name']}';
    await pump(tester, CircleShell(session: null, repository: repo));
    await tester.tap(find.text('Messages'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.descendant(of: bar, matching: find.text(name)), findsOneWidget,
        reason: 'which group you are talking to, while reading');

    tester.view.viewInsets = const FakeViewPadding(bottom: 290);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final box = find.widgetWithText(TextField, 'Message your Circle…');
    expect(tester.getRect(box).bottom, lessThanOrEqualTo(620 - 290),
        reason: 'the message box rides above the keyboard');
    expect(tabs, findsNothing, reason: 'no tabs while typing');
  });

  testWidgets('applying is one task: no tabs leading away', (tester) async {
    await pump(
        tester, CircleShell(session: null, repository: await demo('apply')),
        size: const Size(390, 900));
    expect(tabs, findsNothing);
    expect(find.descendant(of: bar, matching: find.text('Your application')),
        findsOneWidget);
    expect(find.text('Save for later'), findsOneWidget,
        reason: 'the way out keeps the answers');
  });

  testWidgets('the loading state fits in a short space', (tester) async {
    tester.view.physicalSize = const Size(390, 198);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                SizedBox(height: 198, child: Center(child: CircleLoading())))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the organiser reads the whole chat and can remove a message',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _ChatRepo(await SharedPreferences.getInstance());
    final acts = <(String, Json)>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => openOrganiserChat(context,
                        repository: repo,
                        circle: {'id': 'c1', 'name': 'Thursday Circle'},
                        act: (a, p) async => acts.add((a, p))),
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final list = find
        .descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    expect(find.text('Thursday Circle'), findsOneWidget);
    expect(find.text('Message 250'), findsOneWidget,
        reason: 'opens at the newest message');

    await tester.scrollUntilVisible(find.text('Load earlier messages'), 600,
        scrollable: list);
    await tester.tap(find.text('Load earlier messages'));
    await tester.pumpAndSettle();
    expect(repo.asked, ['m51'], reason: 'asks for what came before the first');
    await tester.scrollUntilVisible(find.text('Message 1'), 600,
        scrollable: list);
    expect(find.text('Load earlier messages'), findsNothing,
        reason: 'a short page means that was the start');

    await tester.tap(find.descendant(
        of: find
            .ancestor(of: find.text('Message 1'), matching: find.byType(Row))
            .first,
        matching: find.byTooltip('Message options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove message'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this message?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(acts.single.$1, 'admin_hide_message');
    expect(acts.single.$2['id'], 'm1');
    expect(find.text('Message removed by the organiser'), findsOneWidget);
  });
}
