import 'package:supabase_flutter/supabase_flutter.dart';

class CityService {
  const CityService(this._supabase);

  final SupabaseClient _supabase;

  static const defaultCityOptions = <String>[
    'Alkmaar',
    'Amsterdam',
    'Haarlem',
    'Utrecht',
  ];

  Future<List<String>> fetchCityOptions() async {
    try {
      final rows = await _supabase
          .from('city_options')
          .select('label, sort_order')
          .eq('is_active', true)
          .order('sort_order')
          .order('label');

      final options = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => row['label']?.toString() ?? '')
          .where((label) => label.isNotEmpty)
          .toList();

      return options.isNotEmpty ? options : defaultCityOptions;
    } catch (_) {
      return defaultCityOptions;
    }
  }
}
