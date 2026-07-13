import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/auth_redirects.dart';
import 'package:vriendtime/src/core/calendar_service.dart';
import 'package:vriendtime/src/core/event_catalog.dart';
import 'package:vriendtime/src/core/notification_service.dart';

void main() {
  group('meetup availability', () {
    test('only open, future, non-full events can be reserved', () {
      final futureStart = DateTime.now().add(const Duration(days: 2));

      expect(_meetup(startsAt: futureStart).isOpenForReservation, isTrue);
      expect(
        _meetup(startsAt: futureStart, seatsFilled: 6).isOpenForReservation,
        isFalse,
      );
      expect(
        _meetup(startsAt: futureStart, status: 'closed').isOpenForReservation,
        isFalse,
      );
      expect(
        _meetup(
          startsAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ).isOpenForReservation,
        isFalse,
      );
    });

    test('cancellation closes inside the 12 hour cutoff', () {
      final now = DateTime(2026, 7, 6, 10);

      expect(
        canCancelMeetupReservation(
          _meetup(startsAt: now.add(const Duration(hours: 13))),
          now: now,
        ),
        isTrue,
      );
      expect(
        canCancelMeetupReservation(
          _meetup(startsAt: now.add(meetupCancellationCutoff)),
          now: now,
        ),
        isFalse,
      );
      expect(
        canCancelMeetupReservation(
          _meetup(startsAt: now.add(const Duration(hours: 2))),
          now: now,
        ),
        isFalse,
      );
    });

    test('copyWith keeps remote image URLs during local event updates', () {
      final event = _meetup(
        startsAt: DateTime.now().add(const Duration(days: 2)),
        imageUrl: 'https://example.com/meetup.jpg',
      );

      expect(event.copyWith(seatsFilled: 2).imageUrl, event.imageUrl);
      expect(
        event.copyWith(imageUrl: 'https://example.com/new.jpg').imageUrl,
        'https://example.com/new.jpg',
      );
    });

    test('exact venue presence is the server-authorized reveal signal', () {
      final venue = RevealedMeetupVenue.fromRow({
        'event_id': 'test-meetup',
        'venue_name': '  Cafe Noord  ',
        'venue_address': ' Laat 1 ',
        'city': 'Alkmaar',
        'released_at': '2026-07-10T08:00:00Z',
      });
      final event = _meetup(
        startsAt: DateTime.now().add(const Duration(days: 30)),
      ).withRevealedVenue(venue);

      expect(venue.venueName, 'Cafe Noord');
      expect(venue.venueAddress, 'Laat 1');
      expect(venue.releasedAt.toUtc(), DateTime.utc(2026, 7, 10, 8));
      expect(event.shouldRevealExactAddress, isTrue);
      expect(event.locationDetailLabel, 'Cafe Noord, Laat 1');
    });
  });

  group('calendar invite', () {
    test('brands the title and includes an eligible exact venue', () {
      final event = _meetup(
        startsAt: DateTime.utc(2026, 7, 11, 17),
        venueName: 'Cafe Noord',
        venueAddress: 'Laat 1',
      );
      final uri = buildGoogleCalendarUri(event);
      final details = uri.queryParameters['details']!;

      expect(uri.queryParameters['text'], 'VriendTime · Test meetup');
      expect(uri.queryParameters['location'], 'Cafe Noord, Laat 1');
      expect(details, contains('Hosted by VriendTime'));
      expect(details, contains('Venue: Cafe Noord, Laat 1'));
      expect(details, isNot(contains('shared at 10:00')));
    });

    test('uses area and states the 10:00 rule before venue release', () {
      final event = _meetup(startsAt: DateTime.utc(2026, 7, 11, 17));
      final uri = buildGoogleCalendarUri(event);
      final details = uri.queryParameters['details']!;

      expect(uri.queryParameters['location'], 'centre, Alkmaar');
      expect(details, contains('Area: centre, Alkmaar'));
      expect(
        details,
        contains('shared at 10:00 the day before the meetup'),
      );
    });
  });

  group('notifications', () {
    test('prefers structured address metadata for location labels', () {
      final notification = AppNotification.fromRow({
        'id': 'notification-1',
        'kind': 'address',
        'title': 'Address revealed',
        'body': 'Your meetup address is ready.',
        'created_at': '2026-07-06T10:00:00Z',
        'metadata': {
          'venue_name': 'Cafe Noord',
          'address': 'Laat 1',
          'city': 'Alkmaar',
        },
      });

      expect(notification.kind, AppNotificationKind.address);
      expect(notification.exactLocationLabel, 'Cafe Noord, Laat 1');
      expect(notification.mapsUri?.query, contains('Cafe+Noord'));
      expect(notification.mapsUri?.query, contains('Alkmaar'));
    });

    test('falls back to body lines when metadata is missing', () {
      final notification = AppNotification.fromRow({
        'id': 'notification-2',
        'kind': 'address',
        'title': 'Address revealed',
        'body': 'Your table is ready\nCafe Zuid\nHouttil 2',
        'created_at': '2026-07-06T10:00:00Z',
        'metadata': const <String, dynamic>{},
      });

      expect(notification.revealedVenueName, 'Cafe Zuid');
      expect(notification.revealedAddress, 'Houttil 2');
      expect(notification.exactLocationLabel, 'Cafe Zuid, Houttil 2');
    });
  });

  group('auth redirects', () {
    test('recognizes hash and path password reset routes', () {
      expect(
        AuthRedirects.isPasswordResetUri(
          Uri.parse('https://vriendtime.com/#/reset-password?type=recovery'),
        ),
        isTrue,
      );
      expect(
        AuthRedirects.isPasswordResetUri(
          Uri.parse('https://vriendtime.com/reset-password'),
        ),
        isTrue,
      );
      expect(
        AuthRedirects.isPasswordResetUri(Uri.parse('https://vriendtime.com/')),
        isFalse,
      );
    });
  });
}

MeetupEvent _meetup({
  required DateTime startsAt,
  String status = 'open',
  int seatsFilled = 0,
  int seatsTotal = 6,
  String? imageUrl,
  String? venueName,
  String? venueAddress,
}) {
  return MeetupEvent(
    id: 'test-meetup',
    title: 'Test meetup',
    subtitle: 'A test meetup.',
    badge: 'Daytime',
    slot: EventSlot.daytime,
    city: 'Alkmaar',
    areaLabel: 'centre',
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 2)),
    activityLabel: 'Coffee',
    vibeLabel: 'Relaxed',
    policyLabel: '4+ to go',
    seatsFilled: seatsFilled,
    seatsTotal: seatsTotal,
    tags: const ['Coffee'],
    languages: const ['English'],
    status: status,
    imageUrl: imageUrl,
    venueName: venueName,
    venueAddress: venueAddress,
  );
}
