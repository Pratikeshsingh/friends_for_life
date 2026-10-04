import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vriendtime/src/core/auth_redirects.dart';
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
      expect(
        ProfilePhotoService.uploadErrorMessage(
          const StorageException('Unauthorized', statusCode: '403'),
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
}
