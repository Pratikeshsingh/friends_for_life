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
  static List<String>? _cachedOptions;
  static Future<List<String>>? _pendingRequest;

  Future<List<String>> fetchCityOptions({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedOptions = _cachedOptions;
      if (cachedOptions != null) {
        return cachedOptions;
      }

      final pendingRequest = _pendingRequest;
      if (pendingRequest != null) {
        return pendingRequest;
      }
    }

    final previousOptions = _cachedOptions;
    final request = _fetchCityOptions();
    _pendingRequest = request;
    final options = await request;
    if (identical(_pendingRequest, request)) {
      _pendingRequest = null;
    }
    final nextOptions = ((options.isEmpty || _isDefaultOptions(options)) &&
            previousOptions != null &&
            previousOptions.isNotEmpty)
        ? previousOptions
        : options;
    _cachedOptions = nextOptions;
    return nextOptions;
  }

  Future<List<String>> _fetchCityOptions() async {
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

      return options;
    } catch (_) {
      return defaultCityOptions;
    }
  }

  bool _isDefaultOptions(List<String> options) {
    if (options.length != defaultCityOptions.length) return false;
    for (var index = 0; index < options.length; index++) {
      if (options[index] != defaultCityOptions[index]) return false;
    }
    return true;
  }
}
