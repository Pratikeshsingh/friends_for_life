class AuthRedirects {
  static const emailRedirectTo = 'vriendtime://auth/callback';
  static const passwordResetRedirectTo =
      'https://vriendtime.com/#/reset-password';
  static const passwordResetRoute = '/reset-password';
  static const webAppUrl = 'https://vriendtime.com/';

  const AuthRedirects._();

  static bool isPasswordResetUri(Uri uri) {
    final fragmentPath = uri.fragment.split('?').first;
    return fragmentPath == passwordResetRoute || uri.path == passwordResetRoute;
  }
}
