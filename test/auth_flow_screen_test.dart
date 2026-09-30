import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/auth_flow_screen.dart';
import 'package:vriendtime/src/screens/legal_document_screen.dart';
import 'package:vriendtime/src/widgets/meetup_explorer_tile.dart';

void main() {
  testWidgets('sign-in artwork remains a full-viewport background', (
    tester,
  ) async {
    final client = _testClient();

    await _pumpAuthFlow(
      tester,
      width: 320,
      child: AuthFlowScreen(
        startInSignIn: true,
        supabaseClient: client,
        initialEvents: const [],
        initialCityOptions: const ['Alkmaar'],
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    final backgroundSize =
        tester.getSize(find.byKey(const ValueKey('auth-access-background')));
    expect(backgroundSize.width, 320);
    expect(backgroundSize.height, greaterThanOrEqualTo(850));
    expect(
      find.byKey(const ValueKey('auth-access-scene-window')),
      findsNothing,
    );
    final introBottom =
        tester.getBottomLeft(find.text('Sign in to see what’s next.')).dy;
    final formTop =
        tester.getTopLeft(find.byKey(const ValueKey('auth-access-form'))).dy;
    expect(formTop - introBottom, inInclusiveRange(17, 19));
    expect(
      tester.getBottomLeft(find.widgetWithText(ElevatedButton, 'Sign in')).dy,
      lessThan(700),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('auth-access-background'))),
      backgroundSize,
    );
  });

  testWidgets('sign-up form follows its introduction without a scene gap', (
    tester,
  ) async {
    final client = _testClient();

    await _pumpAuthFlow(
      tester,
      width: 320,
      child: AuthFlowScreen(
        supabaseClient: client,
        initialEvents: const [],
        initialCityOptions: const ['Alkmaar'],
      ),
    );

    expect(find.text('Create your account'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-access-scene-window')),
      findsNothing,
    );
    final introBottom = tester
        .getBottomLeft(
          find.text(
            'A few details. A new beginning with VriendTime.',
          ),
        )
        .dy;
    final formTop =
        tester.getTopLeft(find.byKey(const ValueKey('auth-access-form'))).dy;
    expect(formTop - introBottom, inInclusiveRange(17, 19));
  });

  testWidgets('sign-up requires legal acknowledgement and opens both documents',
      (tester) async {
    final client = _testClient();

    await _pumpAuthFlow(
      tester,
      width: 375,
      child: AuthFlowScreen(
        supabaseClient: client,
        initialEvents: const [],
        initialCityOptions: const ['Alkmaar'],
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Alex',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'alex@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret12',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'secret12',
    );
    await tester.pump();

    var createAccount = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Create account'),
    );
    expect(createAccount.onPressed, isNull);
    expect(
        find.byKey(const ValueKey('legal-consent-checkbox')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('open-terms')));
    await tester.tap(find.byKey(const ValueKey('open-terms')));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsWidgets);
    expect(find.text('Effective 18 September 2026'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('open-privacy-policy')),
    );
    await tester.tap(find.byKey(const ValueKey('open-privacy-policy')));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Privacy Policy'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('legal-consent-checkbox')),
    );
    await tester.tap(find.byKey(const ValueKey('legal-consent-checkbox')));
    await tester.pump();

    createAccount = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Create account'),
    );
    expect(createAccount.onPressed, isNotNull);
  });

  testWidgets('details show all fields with a clear required-field convention',
      (
    tester,
  ) async {
    final client = _testClient();

    await _pumpAuthFlow(
      tester,
      width: 320,
      child: AuthFlowScreen(
        existingUser: _user(
          userMetadata: const {
            'first_name': 'Alex',
            'gender': 'Woman',
            'phone': '+31 6 12345678',
          },
        ),
        supabaseClient: client,
        initialEvents: const [],
        initialCityOptions: const ['Alkmaar'],
      ),
    );

    expect(find.text('* Required'), findsOneWidget);
    expect(find.text('Date of birth *'), findsOneWidget);
    expect(find.text('City *'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Woman'), findsOneWidget);
    expect(find.text('Add optional details'), findsNothing);
    expect(find.text('Hide optional details'), findsNothing);
    expect(
      find.byKey(const ValueKey('optional-details-toggle')),
      findsNothing,
    );

    final birthDate = find.byKey(
      const ValueKey('details-birth-date-field'),
    );
    final city = find.byKey(const ValueKey('city-selection-field'));
    final gender = find.byKey(const ValueKey('details-gender-field'));
    final phone = find.byKey(const ValueKey('details-phone-field'));
    final whyWeAsk = find.byKey(const ValueKey('why-we-ask'));
    final continueButton = find.widgetWithText(
      ElevatedButton,
      'Continue to meetups',
    );

    expect(
      birthDate,
      findsOneWidget,
    );
    expect(city, findsOneWidget);
    expect(gender, findsOneWidget);
    expect(phone, findsOneWidget);
    expect(tester.widget<TextField>(phone).controller?.text, '+31 6 12345678');
    expect(whyWeAsk, findsOneWidget);
    expect(continueButton, findsOneWidget);
    expect(find.text('Choose your city'), findsOneWidget);

    expect(
      tester.getTopLeft(birthDate).dy,
      lessThan(tester.getTopLeft(city).dy),
    );
    expect(
      tester.getTopLeft(city).dy,
      lessThan(tester.getTopLeft(gender).dy),
    );
    expect(
      tester.getTopLeft(gender).dy,
      lessThan(tester.getTopLeft(phone).dy),
    );
    expect(
      tester.getTopLeft(phone).dy,
      lessThan(tester.getTopLeft(whyWeAsk).dy),
    );
    expect(
      tester.getTopLeft(whyWeAsk).dy,
      lessThan(tester.getTopLeft(continueButton).dy),
    );

    expect(find.text('Your details stay private.'), findsOneWidget);
    await tester.ensureVisible(whyWeAsk);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(whyWeAsk);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Each detail has a clear purpose. Nothing here appears on your public profile.',
      ),
      findsOneWidget,
    );
    expect(find.text('Date of birth'), findsWidgets);
    expect(find.text('Gender'), findsNWidgets(2));
    expect(find.text('Phone number'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('close-why-we-ask')));
    await tester.pumpAndSettle();
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.byKey(const ValueKey('details-phone-field')), findsOneWidget);
  });

  testWidgets('city is chosen explicitly and picker explains coverage', (
    tester,
  ) async {
    final client = _testClient();

    await _pumpAuthFlow(
      tester,
      width: 320,
      child: AuthFlowScreen(
        existingUser: _user(
          userMetadata: const {
            'first_name': 'Alex',
            'date_of_birth': '1990-01-01',
          },
        ),
        supabaseClient: client,
        initialEvents: const [],
        initialCityOptions: const ['Alkmaar'],
      ),
    );

    expect(find.text('Choose your city'), findsOneWidget);
    expect(find.text('Alkmaar'), findsNothing);
    var continueButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to meetups'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('city-selection-field')));
    await tester.pumpAndSettle();

    expect(find.text('Choose your city'), findsWidgets);
    expect(
      find.text(
        'VriendTime is currently available in 1 city. More cities are coming soon.',
      ),
      findsOneWidget,
    );
    expect(find.text('Alkmaar'), findsOneWidget);

    await tester.tap(find.text('Alkmaar'));
    await tester.pumpAndSettle();

    expect(find.text('Alkmaar'), findsOneWidget);
    continueButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to meetups'),
    );
    expect(continueButton.onPressed, isNotNull);
  });

  testWidgets('narrow meetup cards show complete date and time with clear skip',
      (
    tester,
  ) async {
    final client = _testClient();
    final event = MeetupEvent(
      id: 'phone-width-meetup',
      title: 'Sunday dinner',
      subtitle: 'A relaxed table in the city centre.',
      badge: 'Evening',
      slot: EventSlot.evening,
      city: 'Alkmaar',
      areaLabel: 'centre',
      startsAt: DateTime(2035, 7, 26, 18),
      endsAt: DateTime(2035, 7, 26, 20, 30),
      activityLabel: 'Dinner',
      vibeLabel: 'Relaxed',
      policyLabel: '4+ to go',
      seatsFilled: 4,
      seatsTotal: 6,
      tags: const ['Dinner'],
      languages: const ['English'],
    );

    await _pumpAuthFlow(
      tester,
      width: 320,
      child: AuthFlowScreen(
        existingUser: _user(
          userMetadata: const {
            'first_name': 'Alex',
            'city': 'Alkmaar',
            'date_of_birth': '1990-01-01',
          },
        ),
        supabaseClient: client,
        initialEvents: [event],
        initialCityOptions: const ['Alkmaar'],
      ),
    );

    expect(find.text('26 July'), findsOneWidget);
    expect(find.text(event.detailTimeLabel), findsOneWidget);
    expect(find.text(meetupCostLabel), findsNothing);
    final costMarker =
        find.byKey(ValueKey('onboarding-meetup-cost-${event.id}'));
    expect(costMarker, findsOneWidget);
    expect(tester.getSize(costMarker), const Size(28, 28));
    expect(find.byType(MeetupExplorerTile), findsOneWidget);
    expect(
      find.byKey(ValueKey('onboarding-meetup-date-${event.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('onboarding-meetup-time-${event.id}')),
      findsOneWidget,
    );
    final summary = tester.widget<Text>(
      find.byKey(ValueKey('onboarding-meetup-summary-${event.id}')),
    );
    expect(summary.textSpan!.toPlainText(), contains('2 spots left'));
    expect(summary.textSpan!.toPlainText(), startsWith('In '));
    expect(find.text('Choose meetup'), findsNothing);

    final skip = find.byKey(const ValueKey('skip-onboarding'));
    expect(skip, findsOneWidget);
    expect(tester.getSize(skip).height, greaterThanOrEqualTo(44));

    await tester.tap(
      find.byKey(ValueKey('onboarding-meetup-${event.id}')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reserve meetup'), findsOneWidget);
    expect(find.text('Cost'), findsOneWidget);
    expect(find.text(meetupCostLabel), findsOneWidget);
  });
}

SupabaseClient _testClient() {
  return SupabaseClient(
    'http://127.0.0.1:54321',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

User _user({required Map<String, dynamic> userMetadata}) {
  return User(
    id: 'test-user',
    appMetadata: const {},
    userMetadata: userMetadata,
    aud: 'authenticated',
    email: 'alex@example.com',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

Future<void> _pumpAuthFlow(
  WidgetTester tester, {
  required double width,
  required Widget child,
}) async {
  final previousOnError = FlutterError.onError;
  final flutterErrors = <FlutterErrorDetails>[];

  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  FlutterError.onError = flutterErrors.add;
  try {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            disableAnimations: true,
          ),
          child: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  } finally {
    FlutterError.onError = previousOnError;
  }

  final layoutErrors = flutterErrors.where((details) {
    final message = details.exceptionAsString();
    return message.contains('A RenderFlex overflowed') ||
        message.contains('was not laid out') ||
        message.contains('BoxConstraints forces an infinite');
  });
  expect(
    layoutErrors,
    isEmpty,
    reason: layoutErrors.map((details) => details.exceptionAsString()).join(
          '\n\n',
        ),
  );
}
