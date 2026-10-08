import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vriendtime/src/circles/circle_home.dart';
import 'package:vriendtime/src/circles/circle_profile.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoCircleRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = DemoCircleRepository(await SharedPreferences.getInstance());
  });

  group('leaving a Circle', () {
    test('releases the place and returns the member to applying', () async {
      await repository.act('preview', {'stage': 'active'});
      await repository.act('leave_circle', {'reason': 'Work has changed.'});
      final state = await repository.load();
      expect(state['stage'], 'apply');
      expect(state['circle'], isNull);
      expect(state['payment'], 'unpaid');
    });

    test('is refused when there is no Circle to leave', () async {
      await repository.act('apply', {'name': 'Asha'});
      expect(() => repository.act('leave_circle'), throwsStateError);
    });

    test('survives a reload, because it is a real departure', () async {
      await repository.act('preview', {'stage': 'active'});
      await repository.act('leave_circle');
      final reopened =
          DemoCircleRepository(await SharedPreferences.getInstance());
      expect((await reopened.load())['stage'], 'apply');
    });
  });

  group('not matching two people again', () {
    test('records and clears an exclusion', () async {
      await repository.act('exclude', {'target': 'noor'});
      expect(strings((await repository.load())['exclusions']), ['noor']);
      await repository.act('exclude', {'target': 'noor', 'active': false});
      expect(strings((await repository.load())['exclusions']), isEmpty);
    });

    test('asking twice does not record the same person twice', () async {
      await repository.act('exclude', {'target': 'noor'});
      await repository.act('exclude', {'target': 'noor'});
      expect(strings((await repository.load())['exclusions']), ['noor']);
    });

    testWidgets('a member card is about the person, never about matching',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleHome(
                      state: const {
                'stage': 'active',
                'profile_id': 'me',
                'exclusions': <String>[],
                'application': {
                  'interests': ['Films', 'Coffee']
                },
                'circle': {'name': 'The Thursday Circle'},
                'members': [
                  {'id': 'me', 'name': 'You'},
                  {
                    'id': 'noor',
                    'name': 'Noor',
                    'bio': 'Looking forward to meeting the Circle.',
                    'interests': ['Films', 'Walking']
                  }
                ],
                'meetups': [],
              },
                      demo: true,
                      busy: false,
                      act: (_, [__ = const {}]) async {},
                      onEdit: (_) {},
                      onMessages: () {})))));
      await tester.tap(find.text('Noor').last);
      await tester.pumpAndSettle();
      // The server's stand-in sentence is not presented as Noor's words.
      expect(find.textContaining('Looking forward'), findsNothing);
      expect(find.text('Noor hasn’t written an introduction yet.'),
          findsOneWidget);
      expect(find.text('INTERESTS'), findsOneWidget);
      expect(find.text('You both like Films.'), findsOneWidget);
      expect(find.text('Private matching preferences'), findsNothing);
      expect(find.text('Don’t match us again'), findsNothing);
    });

    Widget profile(List<Json> meetups, List<String> calls) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleProfile(
                    state: {
              'stage': 'active',
              'profile_id': 'me',
              'exclusions': const <String>[],
              'circle': {'name': 'The Thursday Circle'},
              'members': [
                {'id': 'me', 'name': 'You'},
                {'id': 'noor', 'name': 'Noor'}
              ],
              'meetups': meetups,
            },
                    busy: false,
                    act: (a, [d = const {}]) async =>
                        calls.add('$a:${d['target']}:${d['active']}'),
                    onEdit: (_) {},
                    onPhoto: null,
                    onAccount: null,
                    onReport: null,
                    onExport: null,
                    onBookings: null,
                    onSignOut: null))));

    testWidgets('Profile offers it only after the Circle has met',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(profile([
        {'id': 'w1', 'week': 1, 'completed': false, 'date': '2099-01-01'}
      ], calls));
      expect(find.text('Future Circles'), findsNothing);

      await tester.pumpWidget(profile([
        {'id': 'w1', 'week': 1, 'completed': true}
      ], calls));
      await tester.ensureVisible(find.text('Future Circles'));
      await tester.tap(find.text('Future Circles'));
      await tester.pumpAndSettle();
      expect(find.text('Happy to meet again'), findsOneWidget);
      expect(find.text('You'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls, ['exclude:noor:true']);
      expect(find.text('Not in my next Circle'), findsOneWidget);
    });

    testWidgets('you are never offered the option against yourself',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleHome(
                      state: const {
                'stage': 'active',
                'profile_id': 'me',
                'members': [
                  {'id': 'me', 'name': 'You'}
                ],
                'meetups': [],
              },
                      demo: true,
                      busy: false,
                      act: (_, [__ = const {}]) async {},
                      onEdit: (_) {},
                      onMessages: () {})))));
      await tester.tap(find.text('You').last);
      await tester.pumpAndSettle();
      expect(find.text('Don’t match us again'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('leaving on a small phone', () {
    Future<void> pumpProfile(
        WidgetTester tester, Json state, void Function(String, Json) onAct,
        {Size size = const Size(375, 667)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleProfile(
                      state: state,
                      busy: false,
                      act: (a, [d = const {}]) async => onAct(a, d),
                      onEdit: (_) {},
                      onPhoto: null,
                      onAccount: null,
                      onReport: null,
                      onExport: null,
                      onBookings: null,
                      onSignOut: null)))));
      await tester.ensureVisible(find.text('Programme settings'));
      await tester.tap(find.text('Programme settings'));
      await tester.pumpAndSettle();
      final leave = find.text('Switch group or leave');
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      await tester.tap(leave);
      await tester.pumpAndSettle();
    }

    testWidgets('asks why first, fits, and backing out keeps the place',
        (tester) async {
      final calls = <String>[];
      await pumpProfile(
          tester,
          const {
            'stage': 'active',
            'payment_agreement': {'can_cancel': true},
            'profile_id': 'me',
            'circle': {'name': 'The Thursday Circle'},
            'members': [
              {'id': 'me', 'name': 'You'}
            ],
            'meetups': [],
          },
          (a, d) => calls.add(a));
      expect(tester.takeException(), isNull);
      expect(find.text('What isn’t working?'), findsOneWidget);
      await tester.tap(find.text('Something came up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Give up my place'));
      await tester.pumpAndSettle();
      expect(find.text('Give up your place?'), findsOneWidget);
      // Backing out must not release the place.
      await tester.tap(find.text('Keep my place'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('a switch is offered before a refund, and the reason is sent',
        (tester) async {
      Json? sent;
      await pumpProfile(
          tester,
          const {
            'stage': 'active',
            'payment': 'paid',
            'payment_agreement': {'can_cancel': true},
            'switch': {'available': true},
            'profile_id': 'me',
            'circle': {'name': 'The Thursday Circle'},
            'members': [
              {'id': 'me', 'name': 'You'}
            ],
            'meetups': [],
          },
          (a, d) => sent = {'action': a, ...d},
          size: const Size(375, 900));
      await tester.tap(find.text('The day or time doesn’t work'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mondays suit me better.');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Switch to another group'), findsOneWidget);
      expect(find.text('I’d rather ask for my €19 back'), findsOneWidget);
      await tester.tap(find.text('Switch to another group'));
      await tester.pumpAndSettle();
      expect(sent, {
        'action': 'switch_group',
        'reason': 'The day or time doesn’t work',
        'note': 'Mondays suit me better.'
      });
    });
  });

  group('email preference', () {
    test('defaults to on and can be turned off', () async {
      expect((await repository.load())['email_notifications'], isTrue);
      await repository.act('email_notifications', {'enabled': false});
      expect((await repository.load())['email_notifications'], isFalse);
    });

    testWidgets('the profile shows a switch that reflects the saved value',
        (tester) async {
      bool? changedTo;
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleProfile(
                      state: const {
                'stage': 'waiting',
                'application': {'name': 'Asha'},
                'email_notifications': false,
              },
                      onEdit: null,
                      onPhoto: null,
                      onAccount: null,
                      onReport: null,
                      onExport: null,
                      onBookings: null,
                      onSignOut: null,
                      onEmailNotifications: (v) => changedTo = v)))));
      final toggle = find.byType(SwitchListTile);
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      // The profile is long, so the row has to be scrolled into view before a
      // tap lands on it.
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      expect(changedTo, isTrue);
    });

    testWidgets('the preview hides it, having nowhere to send mail',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleProfile(
                      state: const {
                'stage': 'waiting',
                'application': {'name': 'Asha'}
              },
                      onEdit: null,
                      onPhoto: null,
                      onAccount: null,
                      onReport: null,
                      onExport: null,
                      onBookings: null,
                      onSignOut: null)))));
      expect(find.byType(SwitchListTile), findsNothing);
    });
  });
}
