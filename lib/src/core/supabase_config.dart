class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sageyiqyvzgoayehahyq.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_4ADgyaHzPLbi6Uzw-C3m2w_FW65kKLh',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
