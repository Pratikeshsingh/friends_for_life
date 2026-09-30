class SupabaseConfig {
  static const _defaultUrl = 'https://sageyiqyvzgoayehahyq.supabase.co';
  static const _defaultPublishableKey =
      'sb_publishable_4ADgyaHzPLbi6Uzw-C3m2w_FW65kKLh';
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: _defaultPublishableKey,
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool get isValidForCurrentBuild => isConfigured;

  static String? get configurationErrorMessage {
    if (!isConfigured) {
      return 'Supabase is not configured. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.';
    }

    return null;
  }
}
