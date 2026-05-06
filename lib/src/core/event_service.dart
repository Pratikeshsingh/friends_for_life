import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_catalog.dart';

class EventService {
  const EventService(this._supabase);

  final SupabaseClient _supabase;
  static const _openEventColumns = '''
id,
title,
subtitle,
description,
city,
venue_area,
starts_at,
ends_at,
activity_type,
vibe,
minimum_attendees,
confirmed_count,
capacity,
image_url,
tags,
languages
''';

  Future<List<MeetupEvent>> fetchOpenEvents() async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _supabase
          .from('events')
          .select(_openEventColumns)
          .inFilter('status', ['open', 'full', 'closed'])
          .gte('starts_at', nowIso)
          .order('starts_at');

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MeetupEvent.fromRow)
          .toList();
    } catch (_) {
      return const <MeetupEvent>[];
    }
  }

  Future<List<MeetupEvent>> fetchPastEvents({int limit = 3}) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _supabase
          .from('events')
          .select(_openEventColumns)
          .inFilter('status', ['open', 'full', 'closed'])
          .lt('starts_at', nowIso)
          .order('starts_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MeetupEvent.fromRow)
          .toList();
    } catch (_) {
      return const <MeetupEvent>[];
    }
  }

  Future<List<String>> fetchReservedEventIds(String profileId) async {
    try {
      final rows = await _supabase
          .from('event_attendees')
          .select('event_id')
          .eq('profile_id', profileId)
          .eq('status', 'joined');

      return (rows as List<dynamic>)
          .map((row) => row['event_id'].toString())
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<bool> fetchHasAttendedMeetup(String profileId) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await _supabase
          .from('events')
          .select('id, event_attendees!inner(profile_id, status)')
          .lt('starts_at', nowIso)
          .eq('event_attendees.profile_id', profileId)
          .eq('event_attendees.status', 'joined')
          .limit(1);

      return (rows as List<dynamic>).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
