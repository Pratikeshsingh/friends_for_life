import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_application.dart';
import 'package:vriendtime/src/circles/circle_journey.dart';
import 'package:vriendtime/src/circles/circle_preferences.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';
import 'package:vriendtime/src/core/theme.dart';

void main() {
  test('age changes on birthday rather than staying fixed', () {
    expect(circleAge('2008-09-20', today: DateTime(2026, 9, 19)), 17);
    expect(circleAge('2008-09-20', today: DateTime(2026, 9, 20)), 18);
    expect(circleAge('2000-02-29', today: DateTime(2025, 2, 28)), 24);
    expect(circleAge('2000-02-29', today: DateTime(2025, 3, 1)), 25);
    expect(circleAge(null), isNull);
  });
  test('legacy day slots migrate without inventing new availability', () {
    final slots = circleSlots({
      'availability': ['Monday evening', 'Saturday afternoon']
    });
    expect(slots, {
      'mon': {'evening'},
      'sat': {'afternoon'}
    });
    expect(circleSlotLabels(slots), ['Monday evening', 'Saturday afternoon']);
    expect(
        circleSlots({
          'availability_slots': {
            'mon': ['morning'],
            'sun': ['evening']
          }
        }),
        {
          'mon': {'morning'},
          'sun': {'evening'}
        });
  });
  final initial = <String, dynamic>{
    'name': 'Asha',
    'date_of_birth': '1995-06-15',
    'languages': ['English'],
    'availability_slots': {
      'mon': ['morning'],
      'sat': ['afternoon']
    },
    'interests': ['Coffee'],
    'activities': ['A walk'],
    'goals': ['Local friends'],
    'life_context': [],
    'energy': 2,
    'commitment': true,
    'phone': '06 12345678'
  };
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('all matching steps fit at $width and persist exact choices',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Json? submitted;
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleApplication(
                      initial: initial,
                      busy: false,
                      onSave: (_) async {},
                      onSubmit: (d) async {
                        submitted = d;
                      })))));
      await tester.pumpAndSettle();
      // Day, month and year each show in their own dropdown.
      expect(find.text('15'), findsOneWidget);
      expect(find.textContaining('Jun'), findsOneWidget);
      expect(find.text('1995'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      expect(find.text('German'), findsNothing);
      expect(find.text('Dutch'), findsOneWidget);
      for (var step = 0; step < 3; step++) {
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(Slider), findsNothing);
      await tester.ensureVisible(find.text('Find my Circle'));
      await tester.tap(find.text('Find my Circle'));
      await tester.pumpAndSettle();
      expect(submitted!['availability_slots'], {
        'mon': ['morning'],
        'sat': ['afternoon']
      });
      expect(submitted!['date_of_birth'], '1995-06-15');
      expect(submitted!.containsKey('age'), isFalse);
      expect(submitted!['goals'], ['Local friends']);
      expect(submitted!['phone'], '+31612345678');
      // Home addresses are no longer collected.
      expect(submitted!.containsKey('address'), isFalse);
    });
  }
  test('WhatsApp numbers are stored in international form', () {
    expect(CircleApplicationTesting.normalise('06-1234 5678'), '+31612345678');
    expect(
        CircleApplicationTesting.normalise('0031 6 12345678'), '+31612345678');
    expect(
        CircleApplicationTesting.normalise('+44 7700 900123'), '+447700900123');
    expect(CircleApplicationTesting.isValid('0612'), isFalse);
    expect(CircleApplicationTesting.isValid('06 12345678'), isTrue);
  });
  testWidgets('a WhatsApp number is optional and no address is asked for',
      (tester) async {
    Future<void> openWith(Map<String, dynamic> data) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CircleApplication(
                      key: UniqueKey(),
                      initial: data,
                      busy: false,
                      onSave: (_) async {},
                      onSubmit: (_) async {})))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await openWith(Map<String, dynamic>.from(initial)..remove('phone'));
    expect(find.textContaining('Home address'), findsNothing);
    expect(find.text('Start with you.'), findsNothing,
        reason: 'no number still moves on');
    // A number that is given must still be valid.
    await openWith(Map<String, dynamic>.from(initial)..['phone'] = '0612');
    expect(find.textContaining('Check your WhatsApp number'), findsOneWidget);
    expect(find.text('Start with you.'), findsOneWidget);
  });
  testWidgets('photo is required before live application submission',
      (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: CircleApplication(
                    initial: initial,
                    busy: false,
                    onSave: (_) async {},
                    onSubmit: (_) async {
                      submitted = true;
                    },
                    onPhoto: () async => {'photo_path': 'own/profile.jpg'})))));
    await tester.pumpAndSettle();
    for (var step = 0; step < 3; step++) {
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Find my Circle'));
    await tester.tap(find.text('Find my Circle'));
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    expect(find.textContaining('Add a clear photo so'), findsOneWidget);
    await tester.ensureVisible(find.text('Add a clear photo'));
    await tester.tap(find.text('Add a clear photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Find my Circle'));
    await tester.tap(find.text('Find my Circle'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
  });
  testWidgets('the six-week plan shows every week and stays still',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
                body: SingleChildScrollView(child: CircleJourney())))));
    await tester.pumpAndSettle();
    for (final title in [
      'Dinner together',
      'Go beyond “what do you do?”',
      'Find out who’s secretly competitive.',
      'Choose something together',
      'A plan of your own',
      'One last get-together',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('WE PLAN WEEKS 1 TO 3'), findsOneWidget);
    expect(find.text('FROM WEEK 4, YOUR GROUP PLANS TOGETHER'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
