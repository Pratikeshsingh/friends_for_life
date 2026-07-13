import 'package:supabase_flutter/supabase_flutter.dart';

enum AppNotificationKind { address, reminder, update, support }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.eventId,
    this.metadata = const <String, dynamic>{},
    this.readAt,
  });

  final String id;
  final AppNotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? eventId;
  final Map<String, dynamic> metadata;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  List<String> get _bodyLines => body
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  String? get revealedAddress {
    final value = metadata['address']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;

    final lines = _bodyLines;
    if (lines.length >= 2) {
      return lines.last;
    }
    return null;
  }

  String? get revealedVenueName {
    final value = metadata['venue_name']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;

    final lines = _bodyLines;
    if (lines.length >= 3) {
      return lines[1];
    }
    return null;
  }

  String? get exactLocationLabel {
    final address = revealedAddress;
    if (address == null) return null;
    final venueName = revealedVenueName;
    if (venueName != null) {
      return '$venueName, $address';
    }
    return address;
  }

  String? get cityLabel {
    final value = metadata['city']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Uri? get mapsUri {
    final address = revealedAddress;
    if (address == null) return null;
    final query = [exactLocationLabel ?? address, cityLabel]
        .whereType<String>()
        .join(', ');
    if (query.trim().isEmpty) return null;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  AppNotification copyWith({
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      eventId: eventId,
      metadata: metadata,
      readAt: readAt ?? this.readAt,
    );
  }

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final metadata = row['metadata'];
    return AppNotification(
      id: row['id']?.toString() ?? '',
      kind: _kindFromValue(row['kind']?.toString()),
      title: row['title']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      eventId: row['event_id']?.toString(),
      metadata: metadata is Map<String, dynamic>
          ? metadata
          : metadata is Map
              ? metadata.map(
                  (key, value) => MapEntry(key.toString(), value),
                )
              : const <String, dynamic>{},
      readAt: DateTime.tryParse(row['read_at']?.toString() ?? '')?.toLocal(),
    );
  }

  static AppNotificationKind _kindFromValue(String? value) {
    switch (value) {
      case 'address':
        return AppNotificationKind.address;
      case 'reminder':
        return AppNotificationKind.reminder;
      case 'update':
        return AppNotificationKind.update;
      case 'support':
      default:
        return AppNotificationKind.support;
    }
  }
}

class NotificationService {
  const NotificationService(this._supabase);

  final SupabaseClient _supabase;
  static const _cacheTtl = Duration(seconds: 15);
  static final Map<String, _NotificationCacheEntry> _cache = {};
  static final Map<String, Future<List<AppNotification>>> _pendingRequests = {};

  static void invalidateCache([String? profileId]) {
    if (profileId == null) {
      _cache.clear();
      _pendingRequests.clear();
      return;
    }

    _cache.removeWhere((key, _) => key.startsWith('$profileId:'));
    _pendingRequests.removeWhere((key, _) => key.startsWith('$profileId:'));
  }

  Future<List<AppNotification>> fetchNotifications(
    String profileId, {
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$profileId:$limit';
    final cached = _cache[cacheKey];
    if (!forceRefresh && cached != null && !cached.isExpired(_cacheTtl)) {
      return cached.value;
    }

    final pending = _pendingRequests[cacheKey];
    if (!forceRefresh && pending != null) {
      return pending;
    }

    final request = _fetchNotifications(profileId, limit: limit);
    _pendingRequests[cacheKey] = request;
    try {
      final notifications = await request;
      _cache[cacheKey] = _NotificationCacheEntry(notifications);
      return notifications;
    } catch (_) {
      return _cache[cacheKey]?.value ?? const <AppNotification>[];
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  Future<List<AppNotification>> _fetchNotifications(
    String profileId, {
    required int limit,
  }) async {
    final rows = await _supabase
        .from('notifications')
        .select(
            'id, event_id, kind, title, body, metadata, created_at, read_at')
        .eq('recipient_profile_id', profileId)
        .order('created_at', ascending: false)
        .limit(limit);

    final notifications = (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromRow)
        .where((notification) => notification.id.isNotEmpty)
        .toList();

    return _mergeRelatedNotifications(notifications);
  }

  Future<void> markNotificationsRead({
    required String profileId,
    required List<String> notificationIds,
  }) async {
    if (notificationIds.isEmpty) return;

    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_profile_id', profileId)
        .inFilter('id', notificationIds);
    invalidateCache(profileId);
  }

  List<AppNotification> _mergeRelatedNotifications(
    List<AppNotification> notifications,
  ) {
    final eventIdsWithAddress = notifications
        .where(
          (notification) =>
              notification.kind == AppNotificationKind.address &&
              (notification.eventId?.isNotEmpty ?? false),
        )
        .map((notification) => notification.eventId!)
        .toSet();

    if (eventIdsWithAddress.isEmpty) return notifications;

    return notifications
        .where(
          (notification) =>
              notification.kind != AppNotificationKind.reminder ||
              notification.eventId == null ||
              !eventIdsWithAddress.contains(notification.eventId),
        )
        .toList();
  }
}

class _NotificationCacheEntry {
  _NotificationCacheEntry(List<AppNotification> value)
      : value = List<AppNotification>.unmodifiable(value),
        createdAt = DateTime.now();

  final List<AppNotification> value;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}
