import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

Widget _home(Json state, List<String> calls) => MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
        body: SingleChildScrollView(
            child: CircleHome(
                state: state,
                demo: false,
                busy: false,
                act: (a, [d = const {}]) async => calls.add(a),
                onEdit: (_) {},
                onMessages: () {}))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('after the first meetup the Circle offers a move, not a refund',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_home({
      'stage': 'active',
      'profile_id': 'me',
      'circle': {'name': 'The Thursday Circle'},
      'members': [
        {'id': 'me', 'name': 'You'}
      ],
      'meetups': [],
      'move': {'available': true, 'used': false},
    }, calls));
    expect(find.textContaining('Request a refund'), findsNothing);
    final move = find.text('Circle not feeling right? Move to another group');
    await tester.ensureVisible(move);
    await tester.tap(move);
    await tester.pumpAndSettle();
    expect(find.textContaining('Your €19 carries over'), findsOneWidget);
    await tester.tap(find.text('Move me'));
    await tester.pumpAndSettle();
    expect(calls, ['request_move']);
  });

  testWidgets('no move is offered when it is not available', (tester) async {
    await tester.pumpWidget(_home({
      'stage': 'active',
      'profile_id': 'me',
      'circle': {'name': 'The Thursday Circle'},
      'members': [],
      'meetups': [],
      'move': {'available': false, 'used': true},
    }, []));
    expect(find.text('Circle not feeling right? Move to another group'),
        findsNothing);
  });

  testWidgets('a mover accepts the next invitation without paying again',
      (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_home({
      'stage': 'invited',
      'profile_id': 'me',
      'move_credit': true,
      'circle': {'name': 'The Monday Circle', 'start_date': '2099-01-05'},
      'members': [],
      'meetups': [],
    }, calls));
    final accept = find.text('Accept invitation — already paid');
    expect(accept, findsNWidgets(2));
    await tester.tap(accept.first);
    await tester.pumpAndSettle();
    expect(calls, ['join']);
    expect(find.textContaining('No online checkout'), findsNothing);
  });

  test('the preview closes the move once the second meetup has happened',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': 'active'});
    final meetups = rows((await repo.load())['meetups']);
    await repo.act('complete_meetup', {'id': meetups[0]['id']});
    await repo.act('complete_meetup', {'id': meetups[1]['id']});
    expect(((await repo.load())['move'] as Map)['available'], isFalse);
    await expectLater(repo.act('request_move'), throwsStateError);
  });

  test('the preview moves a member once, and the next Circle is free',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = DemoCircleRepository(await SharedPreferences.getInstance());
    await repo.act('preview', {'stage': 'active'});
    await expectLater(repo.act('request_move'), throwsStateError);
    final first = rows((await repo.load())['meetups']).first;
    await repo.act('complete_meetup', {'id': first['id']});
    expect(((await repo.load())['move'] as Map)['available'], isTrue);
    await repo.act('request_move');
    final state = await repo.load();
    expect(state['move'], isNull);
    expect(state['stage'], 'waiting');
    expect(state['move_credit'], isTrue);
  });
}
