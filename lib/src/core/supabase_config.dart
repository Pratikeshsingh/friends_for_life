import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const _defaultUrl = 'https://sageyiqyvzgoayehahyq.supabase.co';
  static const _defaultPublishableKey =
      'sb_publishable_4ADgyaHzPLbi6Uzw-C3m2w_FW65kKLh';
  static const _hasExplicitUrl = bool.hasEnvironment('SUPABASE_URL');
  static const _hasExplicitPublishableKey =
      bool.hasEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: _defaultPublishableKey,
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool get requiresExplicitConfig => kReleaseMode || kProfileMode;

  static bool get hasExplicitConfig =>
      _hasExplicitUrl && _hasExplicitPublishableKey;

  static bool get isValidForCurrentBuild =>
      isConfigured && (!requiresExplicitConfig || hasExplicitConfig);

  static String? get configurationErrorMessage {
    if (!isConfigured) {
      return 'Supabase is not configured. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.';
    }

    if (requiresExplicitConfig && !hasExplicitConfig) {
      return 'Production builds must pass SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with --dart-define.';
    }

    return null;
  }
}
