import 'package:flutter/foundation.dart';

class AuthRedirects {
  static String get emailRedirectTo => kIsWeb
      ? Uri.base.replace(path: '/', query: '', fragment: '').toString()
      : 'vriendtime://auth/callback';
  static String get passwordResetRedirectTo => kIsWeb
      ? Uri.base
          .replace(path: '/', query: '', fragment: '/reset-password')
          .toString()
      : 'https://vriendtime.com/#/reset-password';
  static const passwordResetRoute = '/reset-password';
  static const webAppUrl = 'https://vriendtime.com/';

  const AuthRedirects._();

  static bool isPasswordResetUri(Uri uri) {
    final fragmentPath = uri.fragment.split('?').first;
    return fragmentPath == passwordResetRoute || uri.path == passwordResetRoute;
  }
}
