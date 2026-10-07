import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vriendtime/src/core/email_links.dart';

void main() {
  test('only our own confirmation links are treated as email links', () {
    expect(
        EmailLinks.isEmailLink(Uri.parse(
            'https://vriendtime.com/auth/confirm?token_hash=abc&type=recovery')),
        isTrue);
    expect(
        EmailLinks.isEmailLink(Uri.parse('https://vriendtime.com/')), isFalse);
    expect(
        EmailLinks.isEmailLink(
            Uri.parse('https://vriendtime.com/auth/confirm?type=recovery')),
        isFalse);
  });

  test('link types map to the right one-time code type', () {
    expect(EmailLinks.typeFor('recovery'), OtpType.recovery);
    expect(EmailLinks.typeFor('signup'), OtpType.signup);
    expect(EmailLinks.typeFor('email_change'), OtpType.emailChange);
    expect(EmailLinks.typeFor('something-else'), isNull);
  });

  test('a link that cannot be verified is reported, never thrown', () async {
    final client = SupabaseClient('http://127.0.0.1:9', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    expect(
        await EmailLinks.handle(
            client,
            Uri.parse(
                'https://vriendtime.com/auth/confirm?token_hash=abc&type=recovery')),
        EmailLinkOutcome.failed);
    expect(
        await EmailLinks.handle(client, Uri.parse('https://vriendtime.com/')),
        EmailLinkOutcome.none);
  });

  test('an expired link sent back by the backend is noticed', () async {
    expect(
        EmailLinks.hasBackendError(Uri.parse(
            'https://vriendtime.com/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired')),
        isTrue);
    expect(
        EmailLinks.hasBackendError(Uri.parse(
            'https://vriendtime.com/?error=access_denied&error_code=otp_expired#/reset-password')),
        isTrue);
    expect(
        EmailLinks.hasBackendError(
            Uri.parse('https://vriendtime.com/#/reset-password')),
        isFalse);
    final client = SupabaseClient('http://127.0.0.1:9', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    expect(
        await EmailLinks.handle(
            client,
            Uri.parse(
                'https://vriendtime.com/#error=access_denied&error_code=otp_expired')),
        EmailLinkOutcome.expired);
    expect(
        await EmailLinks.handle(
            client,
            Uri.parse(
                'https://vriendtime.com/auth/confirm?token_hash=abc&type=email')),
        EmailLinkOutcome.expired);
  });
}
