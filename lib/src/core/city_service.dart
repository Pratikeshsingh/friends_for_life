import 'package:supabase_flutter/supabase_flutter.dart';

class CityService {
  const CityService(this._supabase);

  final SupabaseClient _supabase;
  static const defaultCityOptions = <String>['Alkmaar'];
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
    final request = _fetchCityOptions(fallbackOptions: previousOptions);
    _pendingRequest = request;
    final options = await request;
    if (identical(_pendingRequest, request)) {
      _pendingRequest = null;
    }
    _cachedOptions = options;
    return options;
  }

  Future<List<String>> _fetchCityOptions({
    List<String>? fallbackOptions,
  }) async {
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
      if (fallbackOptions != null && fallbackOptions.isNotEmpty) {
        return fallbackOptions;
      }
      return defaultCityOptions;
    }
  }
}
