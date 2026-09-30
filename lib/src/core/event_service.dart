import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_catalog.dart';

class EventService {
  const EventService(this._supabase);

  final SupabaseClient _supabase;
  // The postgrest query builder can, in rare cases, leave a request's Future
  // unresolved even after its underlying HTTP response has already arrived.
  // A hard timeout guarantees callers always land on the existing error/stale
  // -cache fallback instead of an activity feed stuck loading forever.
  static const _requestTimeout = Duration(seconds: 12);
  static const _eventCacheTtl = Duration(seconds: 45);
  static const _reservationCacheTtl = Duration(seconds: 12);
  static const _attendedCacheTtl = Duration(minutes: 2);
  static _ListCacheEntry<MeetupEvent>? _openEventsCache;
  static final Map<int, _ListCacheEntry<MeetupEvent>> _pastEventsCache = {};
  static final Map<String, _ListCacheEntry<String>> _reservedIdsCache = {};
  static final Map<String, _ValueCacheEntry<bool>> _attendedCache = {};
  static Future<List<MeetupEvent>>? _pendingOpenEvents;
  static final Map<int, Future<List<MeetupEvent>>> _pendingPastEvents = {};
  static final Map<String, Future<List<String>>> _pendingReservedIds = {};
  static final Map<String, Future<bool>> _pendingAttended = {};
  static String? _catalogRelationOverride;
  static bool _openEventsLoadFailed = false;
  static bool get openEventsLoadFailed => _openEventsLoadFailed;
  static const _catalogEventColumns = '''
id,
title,
subtitle,
description,
city,
venue_area,
starts_at,
ends_at,
status,
activity_type,
vibe,
minimum_attendees,
confirmed_count,
capacity,
image_url,
tags,
languages
''';

  static void invalidateEventCaches() {
    _openEventsCache = null;
    _pastEventsCache.clear();
    _pendingOpenEvents = null;
    _pendingPastEvents.clear();
  }

  static void invalidateReservationCache([String? profileId]) {
    if (profileId == null) {
      _reservedIdsCache.clear();
      _pendingReservedIds.clear();
      return;
    }

    _reservedIdsCache.remove(profileId);
    _pendingReservedIds.remove(profileId);
  }

  static void invalidateAttendedCache([String? profileId]) {
    if (profileId == null) {
      _attendedCache.clear();
      _pendingAttended.clear();
      return;
    }

    _attendedCache.remove(profileId);
    _pendingAttended.remove(profileId);
  }

  Future<List<MeetupEvent>> fetchOpenEvents({
    bool forceRefresh = false,
  }) async {
    final cached = _openEventsCache;
    if (!forceRefresh && cached != null && !cached.isExpired(_eventCacheTtl)) {
      return cached.value;
    }

    final pending = _pendingOpenEvents;
    if (!forceRefresh && pending != null) {
      return pending;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final request = (() async {
      try {
        final events = await _fetchCatalogEvents(
          startsAtFilter: (query) => query.gte('starts_at', nowIso),
          ascending: true,
        ).timeout(_requestTimeout);
        _openEventsLoadFailed = false;
        _openEventsCache = _ListCacheEntry(events);
        return events;
      } catch (_) {
        final staleEvents = _openEventsCache?.value;
        _openEventsLoadFailed = staleEvents == null;
        return staleEvents ?? const <MeetupEvent>[];
      }
    })()
        .whenComplete(() => _pendingOpenEvents = null);

    _pendingOpenEvents = request;
    return request;
  }

  Future<List<MeetupEvent>> fetchPastEvents({
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    final cached = _pastEventsCache[limit];
    if (!forceRefresh && cached != null && !cached.isExpired(_eventCacheTtl)) {
      return cached.value;
    }

    final pending = _pendingPastEvents[limit];
    if (!forceRefresh && pending != null) {
      return pending;
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final request = (() async {
      try {
        final events = await _fetchCatalogEvents(
          startsAtFilter: (query) => query.lt('starts_at', nowIso),
          ascending: false,
          limit: limit,
        ).timeout(_requestTimeout);
        _pastEventsCache[limit] = _ListCacheEntry(events);
        return events;
      } catch (_) {
        return _pastEventsCache[limit]?.value ?? const <MeetupEvent>[];
      }
    })()
        .whenComplete(() => _pendingPastEvents.remove(limit));

    _pendingPastEvents[limit] = request;
    return request;
  }

  Future<List<String>> fetchReservedEventIds(
    String profileId, {
    bool forceRefresh = false,
  }) async {
    final cached = _reservedIdsCache[profileId];
    if (!forceRefresh &&
        cached != null &&
        !cached.isExpired(_reservationCacheTtl)) {
      return cached.value;
    }

    final pending = _pendingReservedIds[profileId];
    if (!forceRefresh && pending != null) {
      return pending;
    }

    final request = (() async {
      final rows = await _supabase
          .from('event_attendees')
          .select('event_id')
          .eq('profile_id', profileId)
          .eq('status', 'joined')
          .timeout(_requestTimeout);

      return (rows as List<dynamic>)
          .map((row) => row['event_id'].toString())
          .toList();
    })();

    _pendingReservedIds[profileId] = request;

    try {
      final ids = await request;
      _reservedIdsCache[profileId] = _ListCacheEntry(ids);
      return ids;
    } catch (_) {
      return _reservedIdsCache[profileId]?.value ?? const <String>[];
    } finally {
      _pendingReservedIds.remove(profileId);
    }
  }

  Future<bool> fetchHasAttendedMeetup(
    String profileId, {
    bool forceRefresh = false,
  }) async {
    final cached = _attendedCache[profileId];
    if (!forceRefresh &&
        cached != null &&
        !cached.isExpired(_attendedCacheTtl)) {
      return cached.value;
    }

    final pending = _pendingAttended[profileId];
    if (!forceRefresh && pending != null) {
      return pending;
    }

    final request = _fetchHasAttendedMeetup(profileId);
    _pendingAttended[profileId] = request;
    try {
      final hasAttended = await request;
      _attendedCache[profileId] = _ValueCacheEntry(hasAttended);
      return hasAttended;
    } finally {
      _pendingAttended.remove(profileId);
    }
  }

  Future<bool> _fetchHasAttendedMeetup(String profileId) async {
    try {
      final result = await _supabase.rpc<bool>('has_attended_meetup').timeout(
            _requestTimeout,
          );
      return result;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error, 'has_attended_meetup')) {
        return false;
      }
    } catch (_) {
      return false;
    }

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _supabase
          .from('events')
          .select('id, event_attendees!inner(profile_id, status)')
          .lt('starts_at', nowIso)
          .eq('event_attendees.profile_id', profileId)
          .eq('event_attendees.status', 'joined')
          .limit(1)
          .timeout(_requestTimeout);

      return (rows as List<dynamic>).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<EventReservationResult> reserveEvent({
    required String eventId,
    required String profileId,
  }) async {
    try {
      await _supabase.rpc('reserve_event', params: {
        'target_event_id': eventId,
      });
      _invalidateAfterReservationChange(profileId);
      return await _buildReservationResult(eventId);
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error, 'reserve_event')) {
        rethrow;
      }
    }

    await _supabase.from('event_attendees').upsert(
      {
        'event_id': eventId,
        'profile_id': profileId,
        'status': 'joined',
      },
      onConflict: 'event_id,profile_id',
    );
    _invalidateAfterReservationChange(profileId);
    return _buildReservationResult(eventId);
  }

  Future<List<RevealedMeetupVenue>> fetchRevealedVenues({
    String? eventId,
  }) async {
    final params =
        eventId == null ? null : <String, dynamic>{'target_event_id': eventId};
    final response = params == null
        ? await _supabase.rpc('get_revealed_event_venues')
        : await _supabase.rpc(
            'get_revealed_event_venues',
            params: params,
          );

    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(RevealedMeetupVenue.fromRow)
        .toList(growable: false);
  }

  Future<RevealedMeetupVenue?> fetchRevealedVenueForEvent(
    String eventId,
  ) async {
    final venues = await fetchRevealedVenues(eventId: eventId);
    return venues.isEmpty ? null : venues.first;
  }

  Future<EventReservationResult> _buildReservationResult(
    String eventId,
  ) async {
    try {
      final venue = await fetchRevealedVenueForEvent(eventId);
      return EventReservationResult(
        eventId: eventId,
        revealedVenue: venue,
      );
    } catch (_) {
      // The reservation has already succeeded. Keep that success distinct from
      // a transient follow-up venue lookup failure so callers never encourage a
      // duplicate reservation attempt.
      return EventReservationResult(
        eventId: eventId,
        venueLookupFailed: true,
      );
    }
  }

  Future<void> cancelReservation({
    required String eventId,
    required String profileId,
  }) async {
    try {
      await _supabase.rpc('cancel_event_reservation', params: {
        'target_event_id': eventId,
      });
      _invalidateAfterReservationChange(profileId);
      return;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error, 'cancel_event_reservation')) {
        rethrow;
      }
    }

    await _supabase
        .from('event_attendees')
        .update({'status': 'cancelled'})
        .eq('profile_id', profileId)
        .eq('event_id', eventId);
    _invalidateAfterReservationChange(profileId);
  }

  void _invalidateAfterReservationChange(String profileId) {
    invalidateReservationCache(profileId);
    invalidateAttendedCache(profileId);
    invalidateEventCaches();
  }

  Future<List<MeetupEvent>> _fetchCatalogEvents({
    required dynamic Function(dynamic query) startsAtFilter,
    required bool ascending,
    int? limit,
  }) async {
    Future<List<MeetupEvent>> runQuery(String relation) async {
      dynamic query = _supabase
          .from(relation)
          .select(_catalogEventColumns)
          .inFilter('status', ['open', 'full', 'closed']);
      query = startsAtFilter(query);
      query = query.order('starts_at', ascending: ascending);
      if (limit != null) {
        query = query.limit(limit);
      }

      final rows = await query;
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MeetupEvent.fromRow)
          .toList();
    }

    final preferredRelation = _catalogRelationOverride;
    if (preferredRelation != null) {
      try {
        return await runQuery(preferredRelation);
      } on PostgrestException catch (error) {
        _catalogRelationOverride = null;
        if (preferredRelation == 'event_catalog' &&
            _isMissingRelation(error, 'event_catalog')) {
          _catalogRelationOverride = 'events';
          return await runQuery('events');
        }
        if (preferredRelation == 'events') {
          // The hardened catalog view may have been deployed after app start.
          // Try it once before falling back to stale UI data.
        } else {
          rethrow;
        }
      } catch (_) {
        _catalogRelationOverride = null;
        rethrow;
      }
    }

    try {
      final events = await runQuery('event_catalog');
      _catalogRelationOverride = 'event_catalog';
      return events;
    } on PostgrestException catch (error) {
      if (!_isMissingRelation(error, 'event_catalog')) {
        rethrow;
      }
      _catalogRelationOverride = 'events';
    }

    return runQuery('events');
  }

  bool _isMissingRelation(PostgrestException error, String relation) {
    final message = error.message.toLowerCase();
    final code = error.code?.toUpperCase();
    return code == 'PGRST205' ||
        message.contains('could not find the table') ||
        message.contains('relation "$relation" does not exist') ||
        message.contains("relation '$relation' does not exist");
  }

  bool _isMissingRpc(PostgrestException error, String functionName) {
    final message = error.message.toLowerCase();
    final code = error.code?.toUpperCase();
    return code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('function public.$functionName');
  }
}

class EventReservationResult {
  const EventReservationResult({
    required this.eventId,
    this.revealedVenue,
    this.venueLookupFailed = false,
  });

  final String eventId;
  final RevealedMeetupVenue? revealedVenue;
  final bool venueLookupFailed;

  bool get hasRevealedVenue => revealedVenue != null;
}

class _ListCacheEntry<T> {
  _ListCacheEntry(List<T> value)
      : value = List<T>.unmodifiable(value),
        createdAt = DateTime.now();

  final List<T> value;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}

class _ValueCacheEntry<T> {
  _ValueCacheEntry(this.value) : createdAt = DateTime.now();

  final T value;
  final DateTime createdAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}
