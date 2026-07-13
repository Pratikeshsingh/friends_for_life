import 'package:supabase_flutter/supabase_flutter.dart';

class InterestService {
  const InterestService(this._supabase);

  final SupabaseClient _supabase;

  static const defaultInterestOptions = <String>[
    'Coffee',
    'Lunch',
    'Dinner',
  ];
  static List<String>? _cachedOptions;
  static Future<List<String>>? _pendingRequest;

  Future<List<String>> fetchInterestOptions({bool forceRefresh = false}) async {
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
    final request = _fetchInterestOptions();
    _pendingRequest = request;
    final options = await request;
    if (identical(_pendingRequest, request)) {
      _pendingRequest = null;
    }
    final nextOptions = _isDefaultOptions(options) && previousOptions != null
        ? previousOptions
        : options;
    _cachedOptions = nextOptions;
    return nextOptions;
  }

  Future<List<String>> _fetchInterestOptions() async {
    try {
      final rows = await _supabase
          .from('interest_options')
          .select('label')
          .eq('is_active', true)
          .order('sort_order')
          .order('label');

      final options = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => row['label']?.toString() ?? '')
          .where((label) => label.isNotEmpty)
          .toList();
      if (options.isNotEmpty) return options;
    } catch (_) {
      // Keep the product focused even if the remote options table is unavailable.
    }

    return defaultInterestOptions;
  }

  bool _isDefaultOptions(List<String> options) {
    if (options.length != defaultInterestOptions.length) return false;
    for (var index = 0; index < options.length; index++) {
      if (options[index] != defaultInterestOptions[index]) return false;
    }
    return true;
  }
}
