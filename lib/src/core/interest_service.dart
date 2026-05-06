import 'package:supabase_flutter/supabase_flutter.dart';

class InterestService {
  const InterestService(this._supabase);

  final SupabaseClient _supabase;

  static const defaultInterestOptions = <String>[
    'Coffee',
    'Lunch',
    'Dinner',
  ];
  Future<List<String>> fetchInterestOptions() async {
    try {
      await _supabase
          .from('interest_options')
          .select('label')
          .eq('is_active', true)
          .order('sort_order')
          .order('label');
    } catch (_) {
      // Keep the product focused even if the remote options table is unavailable.
    }

    return defaultInterestOptions;
  }
}
