import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/auth_redirects.dart';

void main() {
  test('password recovery accepts both supported routing styles', () {
    expect(
        AuthRedirects.isPasswordResetUri(
            Uri.parse('https://vriendtime.com/#/reset-password?type=recovery')),
        isTrue);
    expect(
        AuthRedirects.isPasswordResetUri(
            Uri.parse('https://vriendtime.com/reset-password')),
        isTrue);
    expect(
        AuthRedirects.isPasswordResetUri(Uri.parse('https://vriendtime.com/')),
        isFalse);
  });
}
