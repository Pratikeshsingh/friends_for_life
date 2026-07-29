import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/screens/profile_screen.dart';

void main() {
  testWidgets('account deletion requires explicit permanent confirmation', (
    tester,
  ) async {
    var deletionCount = 0;
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    tester.view
      ..physicalSize = const Size(375, 900)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ProfileScreen(
            user: _user(),
            supabaseClient: client,
            onSignOut: () {},
            onDeleteAccount: () async => deletionCount++,
            isSigningOut: false,
            unreadNotificationCount: 0,
            onOpenNotifications: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final deleteAccount = find.byKey(const ValueKey('delete-account'));
    await tester.ensureVisible(deleteAccount);
    await tester.pump();
    await tester.tap(deleteAccount);
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(
      find.text(
        'This permanently deletes your profile, photos, meetup reservations, messages, and notifications. This cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep account'));
    await tester.pumpAndSettle();
    expect(deletionCount, 0);

    await tester.tap(deleteAccount);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-account')));
    await tester.pumpAndSettle();

    expect(deletionCount, 1);
    expect(find.text('Delete your account?'), findsNothing);
  });

  testWidgets('FAQs explain meetup costs and the current VriendTime fee', (
    tester,
  ) async {
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    tester.view
      ..physicalSize = const Size(375, 900)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ProfileScreen(
            user: _user(),
            supabaseClient: client,
            onSignOut: () {},
            onDeleteAccount: () async {},
            isSigningOut: false,
            unreadNotificationCount: 0,
            onOpenNotifications: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final faqLink = find.text('FAQs');
    await tester.ensureVisible(faqLink);
    await tester.pump();
    await tester.tap(faqLink);
    await tester.pumpAndSettle();

    expect(find.text('Does a meetup cost anything?'), findsOneWidget);
    expect(find.text(meetupCostExplanation), findsOneWidget);
  });
}

User _user() {
  return User(
    id: 'test-user',
    appMetadata: const {},
    userMetadata: const {'first_name': 'Alex'},
    aud: 'authenticated',
    email: 'alex@example.com',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}
