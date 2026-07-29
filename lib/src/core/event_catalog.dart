enum EventSlot { daytime, evening }

const Duration meetupCancellationCutoff = Duration(hours: 12);

/// Universal cost policy shown anywhere someone is deciding whether to join.
/// Keep the compact label short enough for narrow meetup cards, and use the
/// full explanation where there is room to remove any ambiguity about fees.
const String meetupCostLabel = 'Pay only for what you order';
const String meetupCostSemantics =
    'No VriendTime fee. You pay only for what you order at the venue.';
const String meetupCostExplanation =
    'VriendTime is currently free to use. There is no membership, booking, '
    'or meetup fee. At the venue, you only pay for the food and drinks you '
    'choose to order.';

/// The exact venue is released at 10:00 Europe/Amsterdam on the calendar day
/// before a meetup. These helpers mirror that server-side rule without using
/// the device timezone, so the label stays stable for people travelling.
DateTime meetupAddressReleaseAt(DateTime eventStartsAt) {
  final eventDateInAmsterdam = _amsterdamWallClock(eventStartsAt);
  final releaseWallClock = DateTime.utc(
    eventDateInAmsterdam.year,
    eventDateInAmsterdam.month,
    eventDateInAmsterdam.day - 1,
    10,
  );
  final offsetHours = _isAmsterdamSummerTimeAtTen(releaseWallClock) ? 2 : 1;
  return releaseWallClock.subtract(Duration(hours: offsetHours));
}

String formatMeetupAddressReleaseDateTime(DateTime eventStartsAt) {
  final releaseAt = meetupAddressReleaseAt(eventStartsAt);
  final releaseInAmsterdam = _amsterdamWallClock(releaseAt);
  return '${releaseInAmsterdam.day} ${_monthLabel(releaseInAmsterdam.month)} '
      'at 10:00';
}

String buildMeetupAddressReleaseSentence(DateTime eventStartsAt) {
  return 'The exact address will be available in VriendTime on '
      '${formatMeetupAddressReleaseDateTime(eventStartsAt)}.';
}

/// Describes the meetup day from Amsterdam's calendar, rather than from the
/// device timezone or by rounding a duration to 24-hour blocks.
String formatMeetupRelativeDay(DateTime eventStartsAt, {DateTime? now}) {
  final eventInAmsterdam = _amsterdamWallClock(eventStartsAt);
  final nowInAmsterdam = _amsterdamWallClock(now ?? DateTime.now());
  final eventDay = DateTime.utc(
    eventInAmsterdam.year,
    eventInAmsterdam.month,
    eventInAmsterdam.day,
  );
  final today = DateTime.utc(
    nowInAmsterdam.year,
    nowInAmsterdam.month,
    nowInAmsterdam.day,
  );
  final dayDifference = eventDay.difference(today).inDays;

  if (dayDifference == 0) return 'Today';
  if (dayDifference == 1) return 'Tomorrow';
  if (dayDifference == -1) return 'Yesterday';
  if (dayDifference > 1) return 'In $dayDifference days';
  return '${dayDifference.abs()} days ago';
}

class MeetupEvent {
  const MeetupEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.slot,
    required this.city,
    required this.areaLabel,
    required this.startsAt,
    required this.endsAt,
    required this.activityLabel,
    required this.vibeLabel,
    required this.policyLabel,
    required this.seatsFilled,
    required this.seatsTotal,
    required this.tags,
    required this.languages,
    this.status = 'open',
    this.venueName,
    this.venueAddress,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final EventSlot slot;
  final String city;
  final String areaLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final String activityLabel;
  final String vibeLabel;
  final String policyLabel;
  final int seatsFilled;
  final int seatsTotal;
  final List<String> tags;
  final List<String> languages;
  final String status;
  final String? venueName;
  final String? venueAddress;
  final String? imageUrl;

  MeetupEvent copyWith({
    int? seatsFilled,
    int? seatsTotal,
    String? status,
    String? venueName,
    String? venueAddress,
    String? imageUrl,
  }) {
    return MeetupEvent(
      id: id,
      title: title,
      subtitle: subtitle,
      badge: badge,
      slot: slot,
      city: city,
      areaLabel: areaLabel,
      startsAt: startsAt,
      endsAt: endsAt,
      activityLabel: activityLabel,
      vibeLabel: vibeLabel,
      policyLabel: policyLabel,
      seatsFilled: seatsFilled ?? this.seatsFilled,
      seatsTotal: seatsTotal ?? this.seatsTotal,
      tags: tags,
      languages: languages,
      status: status ?? this.status,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory MeetupEvent.fromRow(Map<String, dynamic> row) {
    final startsAt = DateTime.parse(row['starts_at'] as String).toLocal();
    final endsAt = row['ends_at'] != null
        ? DateTime.parse(row['ends_at'] as String).toLocal()
        : startsAt.add(const Duration(hours: 2));

    final slot = startsAt.hour < 17 ? EventSlot.daytime : EventSlot.evening;
    final minimumAttendees = (row['minimum_attendees'] as num?)?.toInt() ?? 4;
    final confirmedCount = (row['confirmed_count'] as num?)?.toInt() ?? 0;
    final tags = (row['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final languages = (row['languages'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    return MeetupEvent(
      id: row['id'].toString(),
      title: (row['title'] as String?) ?? 'Untitled meetup',
      subtitle: (row['subtitle'] as String?) ??
          (row['description'] as String?) ??
          'A small-group meetup.',
      badge: slot == EventSlot.daytime ? 'Daytime' : 'Evening',
      slot: slot,
      city: (row['city'] as String?) ?? 'Unknown city',
      areaLabel: (row['venue_area'] as String?) ?? 'the city centre',
      startsAt: startsAt,
      endsAt: endsAt,
      activityLabel: (row['activity_type'] as String?) ?? 'Meetup',
      vibeLabel: (row['vibe'] as String?) ??
          (slot == EventSlot.daytime ? 'Daytime' : 'Evening'),
      policyLabel: '$minimumAttendees+ to go',
      seatsFilled: confirmedCount,
      seatsTotal: (row['capacity'] as num?)?.toInt() ?? 6,
      tags: tags,
      languages: languages,
      status: ((row['status'] as String?) ?? 'open').toLowerCase(),
      venueName: (row['venue_name'] as String?)?.trim(),
      venueAddress: (row['venue_address'] as String?)?.trim(),
      imageUrl: (row['image_url'] as String?)?.trim(),
    );
  }

  String get dateLabel {
    return '${_weekdayLabel(startsAt.weekday)}, ${startsAt.day} ${_monthLabel(startsAt.month)} • ${_formatTime(startsAt)}';
  }

  String get detailDateLabel {
    return '${_weekdayLabel(startsAt.weekday)}, ${startsAt.day} ${_monthLabel(startsAt.month)}';
  }

  String get detailTimeLabel {
    return '${_formatTime(startsAt)}–${_formatTime(endsAt)}';
  }

  DateTime get addressReleaseAt => meetupAddressReleaseAt(startsAt);

  String get addressReleaseDateTimeLabel =>
      formatMeetupAddressReleaseDateTime(startsAt);

  String get addressReleaseSentence =>
      buildMeetupAddressReleaseSentence(startsAt);

  String get statusLabel {
    return browseAvailabilityLabel;
  }

  String get relativeDayLabel => formatMeetupRelativeDay(startsAt);

  String get locationSummary => 'Near $areaLabel, $city';

  bool get hasExactAddress => (venueAddress ?? '').isNotEmpty;

  // Exact venue fields only come from the authenticated attendee RPC after the
  // server-calculated Amsterdam release time. Their presence is therefore the
  // source of truth; client clock and device timezone are not used as a gate.
  bool get shouldRevealExactAddress => hasExactAddress;

  MeetupEvent withRevealedVenue(RevealedMeetupVenue venue) {
    if (venue.eventId != id) return this;
    return copyWith(
      venueName: venue.venueName,
      venueAddress: venue.venueAddress,
    );
  }

  String get locationDetailLabel {
    if (!shouldRevealExactAddress) {
      return '$areaLabel, $city';
    }

    final trimmedVenueName = venueName?.trim();
    if (trimmedVenueName != null && trimmedVenueName.isNotEmpty) {
      return '$trimmedVenueName, ${venueAddress!.trim()}';
    }

    return venueAddress!.trim();
  }

  String get groupSizeLabel {
    if (seatsTotal <= 6) return '4 to 6 people';
    if (seatsTotal <= 8) return '4 to 8 people';
    return 'Up to $seatsTotal people';
  }

  String get timeOfDayLabel {
    if (startsAt.hour < 12) return 'Morning';
    if (startsAt.hour < 17) return 'Afternoon';
    return 'Evening';
  }

  String get languageLabel {
    if (languages.isEmpty) return 'English';
    if (languages.contains('English')) return 'English';
    return languages.first;
  }

  int get spotsLeft => seatsTotal - seatsFilled;

  bool get hasStarted => !startsAt.isAfter(DateTime.now().toLocal());

  bool get isFull => status == 'full' || spotsLeft <= 0;

  bool get isAlmostFull => isFull || spotsLeft <= 2;

  bool get isOpenForReservation => status == 'open' && !isFull && !hasStarted;

  /// A deliberately reassuring capacity label for browse surfaces. Exact
  /// numbers only appear when scarcity is useful, never when a meetup is
  /// mostly empty.
  String get browseAvailabilityLabel {
    if (status == 'cancelled') return 'Cancelled';
    if (status == 'closed' || hasStarted) return 'Reservations closed';
    if (isFull) return 'Full';
    if (spotsLeft == 1) return '1 spot left';
    if (spotsLeft == 2) return '2 spots left';
    return 'Spots available';
  }

  String get reservationUnavailableLabel {
    if (status == 'cancelled') return 'This meetup has been cancelled.';
    if (status == 'closed') return 'Reservations are closed for this meetup.';
    if (hasStarted) return 'This meetup has already started.';
    if (isFull) return 'This meetup is currently full.';
    return 'This meetup cannot be reserved right now.';
  }

  String get availabilityLabel => statusLabel;
}

final recommendedMeetupEvents = <MeetupEvent>[
  MeetupEvent(
    id: 'day-brunch',
    title: 'Saturday lunch in the old town',
    subtitle: 'A proper sit-down lunch with people you have not met yet.',
    badge: 'Daytime',
    slot: EventSlot.daytime,
    city: 'Alkmaar',
    areaLabel: 'the old town',
    startsAt: DateTime(2026, 3, 29, 12, 30),
    endsAt: DateTime(2026, 3, 29, 14),
    activityLabel: 'Lunch',
    vibeLabel: 'Relaxed',
    policyLabel: '4+ to go',
    seatsFilled: 4,
    seatsTotal: 6,
    tags: ['Lunch'],
    languages: ['English', 'Both'],
  ),
  MeetupEvent(
    id: 'eve-social',
    title: 'Friday social dinner',
    subtitle:
        'A full evening around the table - the kind you do not plan, you just show up for.',
    badge: 'Evening',
    slot: EventSlot.evening,
    city: 'Alkmaar',
    areaLabel: 'Waagplein / old town',
    startsAt: DateTime(2026, 3, 28, 19),
    endsAt: DateTime(2026, 3, 28, 21),
    activityLabel: 'Dinner',
    vibeLabel: 'Evening',
    policyLabel: '4+ to go',
    seatsFilled: 6,
    seatsTotal: 8,
    tags: ['Dinner'],
    languages: ['English', 'Dutch', 'Both'],
  ),
];

final moreMeetupEvents = <MeetupEvent>[
  MeetupEvent(
    id: 'day-coffee',
    title: 'Sunday canal coffee',
    subtitle:
        'A relaxed hour and a half with a small group - good conversation, no agenda.',
    badge: 'Daytime',
    slot: EventSlot.daytime,
    city: 'Alkmaar',
    areaLabel: 'the canals',
    startsAt: DateTime(2026, 3, 30, 14),
    endsAt: DateTime(2026, 3, 30, 15, 30),
    activityLabel: 'Coffee',
    vibeLabel: 'Easygoing',
    policyLabel: '3+ to go',
    seatsFilled: 3,
    seatsTotal: 6,
    tags: ['Coffee'],
    languages: ['English', 'Both'],
  ),
];

final recentPastMeetupEvents = <MeetupEvent>[
  MeetupEvent(
    id: 'past-spring-table',
    title: 'Spring table for six',
    subtitle: 'A relaxed dinner where the group stayed small.',
    badge: 'Completed',
    slot: EventSlot.evening,
    city: 'Alkmaar',
    areaLabel: 'the old town',
    startsAt: DateTime(2026, 4, 24, 19),
    endsAt: DateTime(2026, 4, 24, 21),
    activityLabel: 'Dinner',
    vibeLabel: 'Warm',
    policyLabel: 'Completed',
    seatsFilled: 6,
    seatsTotal: 6,
    tags: ['Dinner'],
    languages: ['English', 'Dutch'],
  ),
  MeetupEvent(
    id: 'past-canal-walk',
    title: 'Canal coffee walk',
    subtitle: 'Coffee, then an easy walk through the city centre.',
    badge: 'Completed',
    slot: EventSlot.daytime,
    city: 'Alkmaar',
    areaLabel: 'the canals',
    startsAt: DateTime(2026, 4, 20, 14),
    endsAt: DateTime(2026, 4, 20, 15, 30),
    activityLabel: 'Coffee',
    vibeLabel: 'Easygoing',
    policyLabel: 'Completed',
    seatsFilled: 5,
    seatsTotal: 6,
    tags: ['Coffee'],
    languages: ['English', 'Both'],
  ),
  MeetupEvent(
    id: 'past-games-evening',
    title: 'Neighborhood lunch table',
    subtitle: 'A small lunch table with relaxed conversation.',
    badge: 'Completed',
    slot: EventSlot.evening,
    city: 'Alkmaar',
    areaLabel: 'the city centre',
    startsAt: DateTime(2026, 4, 12, 12, 30),
    endsAt: DateTime(2026, 4, 12, 14),
    activityLabel: 'Lunch',
    vibeLabel: 'Relaxed',
    policyLabel: 'Completed',
    seatsFilled: 7,
    seatsTotal: 8,
    tags: ['Lunch'],
    languages: ['English', 'Dutch'],
  ),
];

final allMeetupEvents = <MeetupEvent>[
  ...recommendedMeetupEvents,
  ...moreMeetupEvents,
];

List<MeetupEvent> selectedMeetupEventsFromIds(
  List<dynamic>? ids, {
  List<MeetupEvent>? availableEvents,
}) {
  final sourceEvents = availableEvents ?? allMeetupEvents;
  final selected = <MeetupEvent>[];
  final seenIds = <String>{};

  if (ids == null) {
    return selected;
  }

  for (final id in ids) {
    if (id is! String || !seenIds.add(id)) {
      continue;
    }

    final event = meetupEventById(id, availableEvents: sourceEvents);
    if (event != null) {
      selected.add(event);
    }
  }

  return selected;
}

const int maxActiveReservations = 3;

String? reservationConflictMessage({
  required List<MeetupEvent> currentEvents,
  required MeetupEvent candidate,
}) {
  for (final event in currentEvents) {
    if (event.id == candidate.id) {
      continue;
    }

    if (_isSameCalendarDay(event.startsAt, candidate.startsAt)) {
      return 'You already have a meetup on ${_weekdayLabel(event.startsAt.weekday)}. Choose a different day.';
    }
  }

  for (final event in currentEvents) {
    if (event.id == candidate.id) {
      continue;
    }

    if (_eventsOverlap(event, candidate)) {
      return 'This meetup overlaps with one you already chose.';
    }
  }

  if (currentEvents.where((event) => event.id != candidate.id).length >=
      maxActiveReservations) {
    return 'You can choose up to three upcoming meetups. Remove one to choose another.';
  }

  return null;
}

MeetupEvent? meetupEventById(
  String id, {
  List<MeetupEvent>? availableEvents,
}) {
  for (final event in availableEvents ?? allMeetupEvents) {
    if (event.id == id) {
      return event;
    }
  }
  return null;
}

bool _isSameCalendarDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool _eventsOverlap(MeetupEvent first, MeetupEvent second) {
  return first.startsAt.isBefore(second.endsAt) &&
      second.startsAt.isBefore(first.endsAt);
}

bool canCancelMeetupReservation(
  MeetupEvent event, {
  DateTime? now,
}) {
  final referenceTime = (now ?? DateTime.now()).toLocal();
  return event.startsAt.isAfter(referenceTime.add(meetupCancellationCutoff));
}

bool sameMeetupEventLists(List<MeetupEvent> first, List<MeetupEvent> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;

  for (var index = 0; index < first.length; index++) {
    final current = first[index];
    final next = second[index];
    if (current.id != next.id ||
        current.title != next.title ||
        current.subtitle != next.subtitle ||
        current.badge != next.badge ||
        current.slot != next.slot ||
        current.city != next.city ||
        current.areaLabel != next.areaLabel ||
        current.venueName != next.venueName ||
        current.venueAddress != next.venueAddress ||
        current.startsAt != next.startsAt ||
        current.endsAt != next.endsAt ||
        current.activityLabel != next.activityLabel ||
        current.vibeLabel != next.vibeLabel ||
        current.policyLabel != next.policyLabel ||
        current.seatsFilled != next.seatsFilled ||
        current.seatsTotal != next.seatsTotal ||
        current.status != next.status ||
        current.imageUrl != next.imageUrl ||
        !_sameStringList(current.tags, next.tags) ||
        !_sameStringList(current.languages, next.languages)) {
      return false;
    }
  }

  return true;
}

class RevealedMeetupVenue {
  const RevealedMeetupVenue({
    required this.eventId,
    required this.venueAddress,
    required this.city,
    required this.releasedAt,
    this.venueName,
  });

  factory RevealedMeetupVenue.fromRow(Map<String, dynamic> row) {
    return RevealedMeetupVenue(
      eventId: row['event_id'].toString(),
      venueName: _trimmedOrNull(row['venue_name']),
      venueAddress: (row['venue_address'] as String).trim(),
      city: (row['city'] as String).trim(),
      releasedAt: DateTime.parse(row['released_at'] as String).toLocal(),
    );
  }

  final String eventId;
  final String? venueName;
  final String venueAddress;
  final String city;
  final DateTime releasedAt;

  String get locationLabel {
    if (venueName == null) return venueAddress;
    return '$venueName, $venueAddress';
  }
}

String? _trimmedOrNull(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _sameStringList(List<String> first, List<String> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;

  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }

  return true;
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Monday';
    case DateTime.tuesday:
      return 'Tuesday';
    case DateTime.wednesday:
      return 'Wednesday';
    case DateTime.thursday:
      return 'Thursday';
    case DateTime.friday:
      return 'Friday';
    case DateTime.saturday:
      return 'Saturday';
    case DateTime.sunday:
      return 'Sunday';
  }

  return '';
}

String _monthLabel(int month) {
  switch (month) {
    case 1:
      return 'January';
    case 2:
      return 'February';
    case 3:
      return 'March';
    case 4:
      return 'April';
    case 5:
      return 'May';
    case 6:
      return 'June';
    case 7:
      return 'July';
    case 8:
      return 'August';
    case 9:
      return 'September';
    case 10:
      return 'October';
    case 11:
      return 'November';
    case 12:
      return 'December';
  }

  return '';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime _amsterdamWallClock(DateTime value) {
  final utc = value.toUtc();
  final offset = _isAmsterdamSummerTimeAtUtc(utc)
      ? const Duration(hours: 2)
      : const Duration(hours: 1);
  return utc.add(offset);
}

bool _isAmsterdamSummerTimeAtUtc(DateTime utcValue) {
  final utc = utcValue.toUtc();
  final year = utc.year;
  final startsAt = DateTime.utc(year, 3, _lastSundayOfMonth(year, 3), 1);
  final endsAt = DateTime.utc(year, 10, _lastSundayOfMonth(year, 10), 1);
  return !utc.isBefore(startsAt) && utc.isBefore(endsAt);
}

bool _isAmsterdamSummerTimeAtTen(DateTime wallClock) {
  final month = wallClock.month;
  if (month > DateTime.march && month < DateTime.october) return true;
  if (month < DateTime.march || month > DateTime.october) return false;

  final transitionDay = _lastSundayOfMonth(wallClock.year, month);
  if (month == DateTime.march) return wallClock.day >= transitionDay;
  return wallClock.day < transitionDay;
}

int _lastSundayOfMonth(int year, int month) {
  final lastDay = DateTime.utc(year, month + 1, 0);
  return lastDay.day - (lastDay.weekday % DateTime.daysPerWeek);
}
