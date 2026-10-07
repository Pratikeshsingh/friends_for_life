import 'package:supabase_flutter/supabase_flutter.dart';

import 'address_bar_native.dart'
    if (dart.library.js_interop) 'address_bar_web.dart' as address_bar;

/// What happened when the app was opened from an email link. [failed] is a
/// reset link that did not work (the reset screen explains it); [expired] is
/// any other link that did not work (the app shows a short notice).
enum EmailLinkOutcome { none, passwordReset, confirmed, failed, expired }

/// Links in VriendTime's account emails point at our own domain, for example
///   https://vriendtime.com/auth/confirm?token_hash=…&type=recovery
/// rather than at the backend's address, so they look like they come from
/// VriendTime and work on any device. The app checks the one-time code
/// itself here, then removes it from the address bar.
class EmailLinks {
  static const path = '/auth/confirm';
  static EmailLinkOutcome outcome = EmailLinkOutcome.none;

  static OtpType? typeFor(String? value) => switch (value) {
        'recovery' => OtpType.recovery,
        'signup' => OtpType.signup,
        'email' => OtpType.email,
        'email_change' => OtpType.emailChange,
        'invite' => OtpType.invite,
        'magiclink' => OtpType.magiclink,
        _ => null,
      };

  /// True when [uri] is one of our email links.
  static bool isEmailLink(Uri uri) =>
      uri.path == path && (uri.queryParameters['token_hash'] ?? '').isNotEmpty;

  /// True when the backend sent the person back with an error, for example
  /// an expired or already used link. The error can be in the query or in
  /// the part after #.
  static bool hasBackendError(Uri uri) {
    bool inParams(Map<String, String> p) =>
        p.containsKey('error_code') || p.containsKey('error_description');
    final fragment = uri.fragment;
    final fragmentQuery = fragment.contains('?')
        ? fragment.substring(fragment.indexOf('?') + 1)
        : fragment;
    Map<String, String> fragmentParams;
    try {
      fragmentParams = Uri.splitQueryString(fragmentQuery);
    } catch (_) {
      fragmentParams = const {};
    }
    return inParams(uri.queryParameters) || inParams(fragmentParams);
  }

  static Future<EmailLinkOutcome> handle(SupabaseClient client, Uri uri) async {
    if (!isEmailLink(uri)) {
      if (!hasBackendError(uri)) return outcome = EmailLinkOutcome.none;
      address_bar.replaceAddress('/');
      return outcome = EmailLinkOutcome.expired;
    }
    final type = typeFor(uri.queryParameters['type']);
    final recovery = type == OtpType.recovery;
    try {
      if (type == null) throw const FormatException('Unknown link type');
      await client.auth
          .verifyOTP(tokenHash: uri.queryParameters['token_hash']!, type: type);
      outcome = recovery
          ? EmailLinkOutcome.passwordReset
          : EmailLinkOutcome.confirmed;
    } catch (_) {
      outcome = recovery ? EmailLinkOutcome.failed : EmailLinkOutcome.expired;
    }
    // Never leave the code in the address bar: a reload must not reuse it.
    address_bar.replaceAddress(recovery ? '/#/reset-password' : '/');
    return outcome;
  }
}
