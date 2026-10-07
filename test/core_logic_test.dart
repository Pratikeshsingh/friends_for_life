import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vriendtime/src/core/app_diagnostics.dart';
import 'package:vriendtime/src/core/auth_redirects.dart';
import 'package:vriendtime/src/core/payment_config.dart';
import 'package:vriendtime/src/core/profile_photo_service.dart';

void main() {
  group('auth redirects', () {
    test('recognizes hash and path password reset routes', () {
      expect(
        AuthRedirects.isPasswordResetUri(
          Uri.parse('https://vriendtime.com/#/reset-password?type=recovery'),
        ),
        isTrue,
      );
      expect(
        AuthRedirects.isPasswordResetUri(
          Uri.parse('https://vriendtime.com/reset-password'),
        ),
        isTrue,
      );
      expect(
        AuthRedirects.isPasswordResetUri(Uri.parse('https://vriendtime.com/')),
        isFalse,
      );
    });
  });

  group('profile photo feedback', () {
    test('reports the actual file size and inclusive upload limit', () {
      expect(
        ProfilePhotoService.tooLargeMessage(9 * 1024 * 1024),
        'That photo is 9.00 MB. Choose a photo up to 8 MB.',
      );
    });

    test('turns permission and format failures into actionable guidance', () {
      // A storage-rule refusal comes with a valid session: no sign-in loop.
      expect(
        ProfilePhotoService.uploadErrorMessage(
          const StorageException(
            'new row violates row-level security policy',
            statusCode: '403',
            error: 'Unauthorized',
          ),
        ),
        allOf(contains('didn’t accept'), isNot(contains('Sign in'))),
      );
      expect(
        ProfilePhotoService.uploadErrorMessage(
          const StorageException('jwt expired', statusCode: '400'),
        ),
        contains('Sign in again'),
      );
      expect(
        ProfilePhotoService.uploadErrorMessage(
          const StorageException(
            'The mime type is not supported',
            statusCode: '415',
          ),
        ),
        contains('prepared image'),
      );
    });

    test('does not blame every unknown upload failure on connectivity', () {
      expect(
        ProfilePhotoService.uploadErrorMessage(Exception('unknown')),
        ProfilePhotoService.genericUploadErrorMessage,
      );
      expect(
        ProfilePhotoService.genericUploadErrorMessage,
        isNot(contains('connection')),
      );
    });
  });

  test('error reports name the failure and code, never the message', () {
    expect(
        AppDiagnostics.kindOf(
            const StorageException('private detail', statusCode: '403')),
        'storage:403');
    expect(
        AppDiagnostics.kindOf(
            const PostgrestException(message: 'secret', code: '42501')),
        'database:42501');
    expect(AppDiagnostics.kindOf(StateError('x')), 'state');
  });

  test('members pay with their own Circle\'s link, only over https', () {
    expect(PaymentConfig.linkFor({'payment_link': 'https://tikkie.me/pay/abc'}),
        'https://tikkie.me/pay/abc');
    // No Circle link and no build-time link: no Pay button.
    expect(PaymentConfig.linkFor({'payment_link': null}), isNull);
    expect(
        PaymentConfig.linkFor({'payment_link': 'javascript:alert(1)'}), isNull);
    expect(PaymentConfig.linkFor(null), isNull);
  });
}
