import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/auth_flow_screen.dart';
import 'package:vriendtime/src/screens/legal_document_screen.dart';

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
      ),
    );

    expect(find.text('Create your account'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-access-scene-window')),
      findsNothing,
    );
    final introBottom = tester
        .getBottomLeft(
          find.textContaining('Takes a minute.'),
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
    expect(find.text('Effective 4 October 2026'), findsOneWidget);

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
}

SupabaseClient _testClient() {
  return SupabaseClient(
    'http://127.0.0.1:54321',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
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
