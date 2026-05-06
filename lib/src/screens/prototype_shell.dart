import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/event_catalog.dart';
import '../core/event_service.dart';
import '../core/responsive.dart';
import '../widgets/motion.dart';
import 'auth_flow_screen.dart';
import 'event_detail_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';

enum _DeferredSetupKind { meetup, photo }

class PrototypeShell extends StatefulWidget {
  const PrototypeShell({super.key, required this.session});

  final Session? session;

  @override
  State<PrototypeShell> createState() => _PrototypeShellState();
}

class _PrototypeShellState extends State<PrototypeShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  User? _overrideUser;
  _DeferredSetupKind? _deferredSetupKind;
  bool _showDeferredSetupFlow = false;
  bool _showLoggedOutAuthFlow = false;
  bool _isResendingVerification = false;
  bool _isRefreshingVerification = false;
  bool _isUpdatingMeetups = false;
  bool _isValidatingSession = false;
  bool? _hasAttendedMeetup;
  String? _focusedEventId;
  String? _lastValidatedUserId;
  String? _lastLegacyReservationSyncUserId;
  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _eventAttendeesChannel;
  Timer? _eventsRefreshTimer;
  Timer? _reservationsRefreshTimer;
  List<MeetupEvent> _availableEvents = allMeetupEvents;
  List<MeetupEvent> _pastEvents = recentPastMeetupEvents;
  List<String> _reservedEventIds = const <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEvents();
    _loadPastEvents();
    _loadReservations();
    _loadAttendedMeetupStatus();
    _subscribeToRealtimeUpdates();
    _validateSessionIfNeeded(force: true);
  }

  @override
  void dispose() {
    _unsubscribeFromRealtimeUpdates();
    _eventsRefreshTimer?.cancel();
    _reservationsRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PrototypeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.user.id != widget.session?.user.id) {
      _selectedIndex = 0;
      _overrideUser = null;
      _deferredSetupKind = null;
      _showLoggedOutAuthFlow = false;
      _hasAttendedMeetup = null;
      _focusedEventId = null;
      _lastValidatedUserId = null;
      _lastLegacyReservationSyncUserId = null;
      _reservedEventIds = const <String>[];
      _unsubscribeFromRealtimeUpdates();
      _loadEvents();
      _loadPastEvents();
      _loadReservations();
      _loadAttendedMeetupStatus();
      _subscribeToRealtimeUpdates();
      _validateSessionIfNeeded(force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadEvents();
      _loadPastEvents();
      _loadReservations();
      _loadAttendedMeetupStatus();
      _validateSessionIfNeeded(force: true);
    }
  }

  void _subscribeToRealtimeUpdates() {
    final client = Supabase.instance.client;
    final userId = (_overrideUser ?? widget.session?.user)?.id;

    if (userId == null) {
      return;
    }

    _eventsChannel = client
        .channel('public:events-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) {
            if (!mounted) return;
            _scheduleEventsRefresh();
          },
        )
        .subscribe();

    _eventAttendeesChannel = client
        .channel('public:event-attendees-live:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_attendees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: userId,
          ),
          callback: (_) {
            if (!mounted) return;
            _scheduleReservationsRefresh();
          },
        )
        .subscribe();
  }

  void _unsubscribeFromRealtimeUpdates() {
    final client = Supabase.instance.client;
    final eventsChannel = _eventsChannel;
    final attendeesChannel = _eventAttendeesChannel;
    _eventsChannel = null;
    _eventAttendeesChannel = null;

    if (eventsChannel != null) {
      client.removeChannel(eventsChannel);
    }
    if (attendeesChannel != null) {
      client.removeChannel(attendeesChannel);
    }
  }

  void _scheduleEventsRefresh([
    Duration delay = const Duration(milliseconds: 180),
  ]) {
    _eventsRefreshTimer?.cancel();
    _eventsRefreshTimer = Timer(delay, () {
      _loadEvents();
    });
  }

  void _scheduleReservationsRefresh([
    Duration delay = const Duration(milliseconds: 120),
  ]) {
    _reservationsRefreshTimer?.cancel();
    _reservationsRefreshTimer = Timer(delay, () {
      _loadReservations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _overrideUser ?? widget.session?.user;
    final reduceMotion = prefersReducedMotion(context);

    if (currentUser == null) {
      return _showLoggedOutAuthFlow
          ? AuthFlowScreen(
              onClose: () {
                if (!mounted) return;
                setState(() => _showLoggedOutAuthFlow = false);
              },
            )
          : OnboardingScreen(
              onStart: () {
                if (!mounted) return;
                setState(() => _showLoggedOutAuthFlow = true);
              },
            );
    }

    if (_isValidatingSession && _lastValidatedUserId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final needsMeetupSetup = _needsCoreOnboarding(currentUser);
    final needsPhotoSetup = _needsPhotoSetup(currentUser);
    final deferredMeetupSetup = _deferredSetupKind == _DeferredSetupKind.meetup;
    final deferredPhotoSetup = _deferredSetupKind == _DeferredSetupKind.photo;
    final hasAttendedMeetup = _hasAttendedMeetup == true;
    final shouldShowReserveReminder =
        (_selectedIndex == 0 || _selectedIndex == 1) &&
            !needsMeetupSetup &&
            _reservedEventIds.isEmpty &&
            !hasAttendedMeetup &&
            !_showDeferredSetupFlow &&
            _deferredSetupKind != _DeferredSetupKind.meetup;

    if ((needsMeetupSetup && !deferredMeetupSetup) ||
        (!needsMeetupSetup && needsPhotoSetup && !deferredPhotoSetup) ||
        _showDeferredSetupFlow) {
      return AuthFlowScreen(
        existingUser: currentUser,
        onUserUpdated: (updatedUser) {
          final immediateReservedIds = (updatedUser
                      .userMetadata?['selected_event_ids'] as List<dynamic>? ??
                  const [])
              .whereType<String>()
              .toList();
          setState(() {
            _overrideUser = updatedUser;
            _reservedEventIds = immediateReservedIds;
            if (!_needsCoreOnboarding(updatedUser) &&
                !_needsPhotoSetup(updatedUser)) {
              _deferredSetupKind = null;
            }
          });
          _loadReservations();
          _loadEvents();
          _loadPastEvents();
          _loadAttendedMeetupStatus();
        },
        photoOnlyMode: _showDeferredSetupFlow,
        onClose: () {
          if (!mounted) return;
          final latestUser =
              _overrideUser ?? widget.session?.user ?? currentUser;
          final immediateReservedIds = (latestUser
                      .userMetadata?['selected_event_ids'] as List<dynamic>? ??
                  const [])
              .whereType<String>()
              .toList();
          setState(() {
            _deferredSetupKind = _incompleteSetupKindForUser(latestUser);
            _showDeferredSetupFlow = false;
            _reservedEventIds = immediateReservedIds;
          });
          _loadReservations();
          _loadEvents();
          _loadPastEvents();
          _loadAttendedMeetupStatus();
        },
      );
    }

    final selectedEvents = selectedMeetupEventsFromIds(
      _reservedEventIds,
      availableEvents: _availableEvents,
    );
    final sortedSelectedEvents = [...selectedEvents]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final selectedEvent =
        sortedSelectedEvents.isEmpty ? null : sortedSelectedEvents.first;

    final screens = [
      HomeScreen(
        onOpenEvent: (event) => setState(() {
          _focusedEventId = event?.id;
          _selectedIndex = 1;
        }),
        userEmail: currentUser.email,
        firstName: currentUser.userMetadata?['first_name'] as String?,
        selectedEvent: selectedEvent,
        selectedEvents: selectedEvents,
        availableEvents: _availableEvents,
      ),
      EventDetailScreen(
        event: selectedEvent,
        focusedEventId: _focusedEventId,
        allEvents: _availableEvents,
        pastEvents: _pastEvents,
        selectedEventIds: selectedEvents.map((event) => event.id).toSet(),
        isUpdatingSelection: _isUpdatingMeetups,
        onSelectEvent: _selectMeetup,
        onCancelEvent: _cancelMeetup,
      ),
      ProfileScreen(
        user: currentUser,
        onUserUpdated: (updatedUser) {
          setState(() => _overrideUser = updatedUser);
        },
      ),
    ];
    final activeIndex = _selectedIndex.clamp(0, screens.length - 1).toInt();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (currentUser.emailConfirmedAt == null && activeIndex == 2)
              _UnconfirmedBanner(
                email: currentUser.email,
                isResending: _isResendingVerification,
                isRefreshing: _isRefreshingVerification,
                onResend: _resendVerificationEmail,
                onRefresh: _refreshVerificationStatus,
              ),
            if (_deferredSetupKind == _DeferredSetupKind.meetup &&
                needsMeetupSetup &&
                _selectedIndex == 0)
              _SetupReminderBanner(
                title: 'Choose your first meetup',
                body: 'Choose a coffee, lunch, or dinner when you are ready.',
                actionLabel: 'See meetups',
                onContinue: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              ),
            if (shouldShowReserveReminder)
              _SetupReminderBanner(
                title: 'Choose your first meetup',
                body: 'Pick a coffee, lunch, or dinner when you are ready.',
                actionLabel: _selectedIndex == 0 ? 'See meetups' : null,
                onContinue: _selectedIndex == 0
                    ? () {
                        setState(() {
                          _selectedIndex = 1;
                          _focusedEventId = null;
                        });
                      }
                    : null,
              ),
            if (_deferredSetupKind == _DeferredSetupKind.photo &&
                !needsMeetupSetup &&
                needsPhotoSetup &&
                activeIndex == 2)
              _SetupReminderBanner(
                title: 'Add your profile photo',
                body: 'A photo helps people recognize you when you arrive.',
                actionLabel: 'Finish setup',
                onContinue: () {
                  setState(() {
                    _showDeferredSetupFlow = true;
                    _deferredSetupKind = null;
                  });
                },
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var index = 0; index < screens.length; index++)
                    _ShellScreenLayer(
                      isSelected: index == activeIndex,
                      reduceMotion: reduceMotion,
                      child: KeyedSubtree(
                        key: ValueKey('shell-screen-$index'),
                        child: screens[index],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontal = responsiveHorizontalPadding(width);

          return Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                height: 72,
                selectedIndex: activeIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.event_outlined),
                      selectedIcon: Icon(Icons.event),
                      label: 'Meetups'),
                  NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _validateSessionIfNeeded({bool force = false}) async {
    final session = widget.session;
    final userId = session?.user.id;
    if (session == null || userId == null) return;
    if (_isValidatingSession) return;
    if (!force && _lastValidatedUserId == userId) return;

    setState(() => _isValidatingSession = true);

    try {
      final response = await Supabase.instance.client.auth.getUser();
      if (!mounted) return;

      final validatedUser = response.user;
      if (validatedUser == null) {
        await _handleInvalidSession();
        return;
      }

      setState(() {
        _overrideUser = validatedUser;
        _lastValidatedUserId = validatedUser.id;
      });
    } on AuthException catch (error) {
      if (_isMissingUserError(error)) {
        await _handleInvalidSession();
      }
    } finally {
      if (mounted) {
        setState(() => _isValidatingSession = false);
      }
    }
  }

  bool _isMissingUserError(AuthException error) {
    final message = error.message.toLowerCase();
    return message.contains('user from sub claim in jwt does not exist') ||
        message.contains('user does not exist');
  }

  Future<void> _handleInvalidSession() async {
    if (!mounted) return;

    setState(() {
      _overrideUser = null;
      _lastValidatedUserId = null;
    });

    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session expired. Sign in again.'),
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    final email = (_overrideUser ?? widget.session?.user)?.email;
    if (email == null) return;

    setState(() => _isResendingVerification = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmation email sent again.')),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not send the email. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResendingVerification = false);
      }
    }
  }

  bool _needsCoreOnboarding(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final hasDetails = (metadata['city'] as String?)?.isNotEmpty == true &&
        (metadata['date_of_birth'] as String?)?.isNotEmpty == true &&
        (metadata['gender'] as String?)?.isNotEmpty == true;

    return !hasDetails;
  }

  bool _needsPhotoSetup(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return !((metadata['has_profile_photo'] as bool?) == true ||
        (metadata['profile_photo_path'] as String?)?.isNotEmpty == true);
  }

  _DeferredSetupKind? _incompleteSetupKindForUser(User user) {
    if (_needsCoreOnboarding(user)) {
      return _DeferredSetupKind.meetup;
    }
    if (_needsPhotoSetup(user)) {
      return _DeferredSetupKind.photo;
    }
    return null;
  }

  Future<void> _refreshVerificationStatus() async {
    setState(() => _isRefreshingVerification = true);
    try {
      final response = await Supabase.instance.client.auth.getUser();
      if (!mounted) return;
      setState(() => _overrideUser = response.user);
      _loadReservations();

      final confirmed = response.user?.emailConfirmedAt != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed
                ? 'Email confirmed. You are all set.'
                : 'Still waiting for confirmation. Check your inbox and spam folder.',
          ),
        ),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not check your email yet. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshingVerification = false);
      }
    }
  }

  Future<void> _loadEvents() async {
    final events =
        await EventService(Supabase.instance.client).fetchOpenEvents();
    if (!mounted) return;
    if (sameMeetupEventLists(_availableEvents, events)) return;
    setState(() => _availableEvents = events);
  }

  Future<void> _loadPastEvents() async {
    final events =
        await EventService(Supabase.instance.client).fetchPastEvents(limit: 3);
    if (!mounted) return;

    final nextEvents = events.isEmpty ? recentPastMeetupEvents : events;
    if (sameMeetupEventLists(_pastEvents, nextEvents)) return;
    setState(() => _pastEvents = nextEvents);
  }

  Future<void> _loadReservations() async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    var reservedIds =
        await EventService(Supabase.instance.client).fetchReservedEventIds(
      user.id,
    );

    final canAttemptLegacySync =
        reservedIds.isEmpty && _lastLegacyReservationSyncUserId != user.id;

    if (canAttemptLegacySync) {
      final legacyIds =
          (user.userMetadata?['selected_event_ids'] as List<dynamic>? ??
                  const [])
              .whereType<String>()
              .toList();
      if (legacyIds.isNotEmpty) {
        try {
          await Supabase.instance.client.from('event_attendees').upsert(
            [
              for (final eventId in legacyIds)
                {
                  'event_id': eventId,
                  'profile_id': user.id,
                  'status': 'joined',
                },
            ],
            onConflict: 'event_id,profile_id',
          );
          reservedIds = await EventService(Supabase.instance.client)
              .fetchReservedEventIds(
            user.id,
          );
        } catch (_) {
          reservedIds = legacyIds;
        }
      }

      _lastLegacyReservationSyncUserId = user.id;
    }

    if (!mounted) return;
    if (listEquals(_reservedEventIds, reservedIds)) return;
    setState(() => _reservedEventIds = reservedIds);
  }

  Future<void> _loadAttendedMeetupStatus() async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) {
      if (!mounted || _hasAttendedMeetup == null) return;
      setState(() => _hasAttendedMeetup = null);
      return;
    }

    final hasAttended =
        await EventService(Supabase.instance.client).fetchHasAttendedMeetup(
      user.id,
    );

    if (!mounted || _hasAttendedMeetup == hasAttended) return;
    setState(() => _hasAttendedMeetup = hasAttended);
  }

  Future<void> _selectMeetup(MeetupEvent event) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    final currentIds = [..._reservedEventIds];
    final currentEvents = selectedMeetupEventsFromIds(
      currentIds,
      availableEvents: _availableEvents,
    );
    final conflictMessage = reservationConflictMessage(
      currentEvents: currentEvents,
      candidate: event,
    );

    if (conflictMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(conflictMessage)));
      return;
    }

    final nextIds = [...currentIds]..remove(event.id);
    nextIds.insert(0, event.id);

    await _updateSelectedMeetups(
      nextIds,
      successMessage: '${event.title} reserved.',
    );
    if (mounted) {
      setState(() => _focusedEventId = event.id);
    }
  }

  Future<void> _cancelMeetup(MeetupEvent event) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    final currentIds = [..._reservedEventIds];
    final nextIds =
        currentIds.where((selectedId) => selectedId != event.id).toList();

    await _updateSelectedMeetups(
      nextIds,
      successMessage: nextIds.isEmpty
          ? 'Reservation cancelled. You can reserve another meetup any time.'
          : 'Reservation cancelled. Your other meetup is still reserved.',
    );
    if (mounted && _focusedEventId == event.id) {
      setState(() {
        _focusedEventId = nextIds.isEmpty ? null : nextIds.first;
      });
    }
  }

  Future<void> _cancelReservationsInDatabase({
    required String userId,
    required List<String> removedIds,
  }) async {
    if (removedIds.isEmpty) return;

    await Supabase.instance.client
        .from('event_attendees')
        .update({'status': 'cancelled'})
        .eq('profile_id', userId)
        .inFilter('event_id', removedIds);

    final remainingRows = await Supabase.instance.client
        .from('event_attendees')
        .select('event_id,status')
        .eq('profile_id', userId)
        .inFilter('event_id', removedIds);

    final stillJoinedIds = (remainingRows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((row) => row['status'] == 'joined')
        .map((row) => row['event_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (stillJoinedIds.isNotEmpty) {
      throw const PostgrestException(
        message: 'We could not cancel that reservation. Try again.',
      );
    }
  }

  Future<void> _updateSelectedMeetups(
    List<String> eventIds, {
    required String successMessage,
  }) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    final mergedMetadata = {
      ...?user.userMetadata,
      'selected_event_ids': eventIds,
      'has_ever_reserved_meetup':
          (user.userMetadata?['has_ever_reserved_meetup'] as bool?) == true ||
              eventIds.isNotEmpty,
    };
    final previousIds = _reservedEventIds.toSet();
    final nextIds = eventIds.toSet();
    final addedIds = nextIds.difference(previousIds).toList();
    final removedIds = previousIds.difference(nextIds).toList();

    setState(() => _isUpdatingMeetups = true);

    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: mergedMetadata),
      );

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'first_name': mergedMetadata['first_name'],
        'phone': mergedMetadata['phone'],
        'address': mergedMetadata['address'],
        'city': mergedMetadata['city'],
        'date_of_birth': mergedMetadata['date_of_birth'],
        'gender': mergedMetadata['gender'],
        'language': mergedMetadata['language'],
        'availability': mergedMetadata['availability'],
        'energy': mergedMetadata['energy'],
        'group_preference': mergedMetadata['group_preference'],
        'conversation_goals': mergedMetadata['conversation_goals'],
        'dietary_notes': mergedMetadata['dietary_notes'],
        'interests': mergedMetadata['interests'] ?? const <String>[],
        'selected_event_ids': eventIds,
        'profile_photo_path': mergedMetadata['profile_photo_path'],
        'profile_photo_name': mergedMetadata['profile_photo_name'],
        'secondary_photo_path': mergedMetadata['secondary_photo_path'],
        'secondary_photo_name': mergedMetadata['secondary_photo_name'],
        'has_profile_photo': mergedMetadata['has_profile_photo'] ?? false,
      }, onConflict: 'id');

      if (addedIds.isNotEmpty) {
        final insertedRows =
            await Supabase.instance.client.from('event_attendees').upsert(
          [
            for (final eventId in addedIds)
              {
                'event_id': eventId,
                'profile_id': user.id,
                'status': 'joined',
              },
          ],
          onConflict: 'event_id,profile_id',
        ).select('event_id');

        if ((insertedRows as List<dynamic>).length != addedIds.length) {
          throw const PostgrestException(
            message: 'We could not confirm that reservation. Try again.',
          );
        }
      }

      await _cancelReservationsInDatabase(
        userId: user.id,
        removedIds: removedIds,
      );

      final refreshedReservedIds =
          await EventService(Supabase.instance.client).fetchReservedEventIds(
        user.id,
      );
      final locallyUpdatedUser = User.fromJson({
        ...user.toJson(),
        'user_metadata': mergedMetadata,
      });
      final locallyUpdatedEvents = _applyReservationSeatDeltas(
        addedIds: addedIds,
        removedIds: removedIds,
      );

      if (!mounted) return;

      setState(() {
        _overrideUser = locallyUpdatedUser ?? response.user ?? user;
        _reservedEventIds = refreshedReservedIds;
        _availableEvents = locallyUpdatedEvents;
      });
      _loadAttendedMeetupStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not update your meetup. Try again.')),
      );
    } on PostgrestException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not update your meetup. Try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not update your meetup. Try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMeetups = false);
      }
    }
  }

  List<MeetupEvent> _applyReservationSeatDeltas({
    required List<String> addedIds,
    required List<String> removedIds,
  }) {
    if (addedIds.isEmpty && removedIds.isEmpty) {
      return _availableEvents;
    }

    final seatDeltaByEventId = <String, int>{};
    for (final eventId in addedIds) {
      seatDeltaByEventId.update(eventId, (count) => count + 1,
          ifAbsent: () => 1);
    }
    for (final eventId in removedIds) {
      seatDeltaByEventId.update(eventId, (count) => count - 1,
          ifAbsent: () => -1);
    }

    return [
      for (final event in _availableEvents)
        if (seatDeltaByEventId.containsKey(event.id))
          event.copyWith(
            seatsFilled: (event.seatsFilled + seatDeltaByEventId[event.id]!)
                .clamp(0, event.seatsTotal)
                .toInt(),
          )
        else
          event,
    ];
  }
}

class _ShellScreenLayer extends StatelessWidget {
  const _ShellScreenLayer({
    required this.isSelected,
    required this.reduceMotion,
    required this.child,
  });

  final bool isSelected;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset =
        reduceMotion || isSelected ? Offset.zero : const Offset(0.02, 0.02);
    final scale = reduceMotion || isSelected ? 1.0 : 0.985;

    return IgnorePointer(
      ignoring: !isSelected,
      child: ExcludeSemantics(
        excluding: !isSelected,
        child: AnimatedSlide(
          offset: offset,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: Duration(milliseconds: reduceMotion ? 0 : 260),
              curve: Curves.easeOutCubic,
              child: TickerMode(
                enabled: isSelected,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupReminderBanner extends StatelessWidget {
  const _SetupReminderBanner({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onContinue,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFB9E3DC)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );

            final hasAction = actionLabel != null &&
                actionLabel!.isNotEmpty &&
                onContinue != null;
            final action = hasAction
                ? TextButton(
                    onPressed: onContinue,
                    child: Text(actionLabel!),
                  )
                : null;

            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      if (action != null) ...[
                        const SizedBox(height: 10),
                        action,
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: copy),
                      if (action != null) ...[
                        const SizedBox(width: 12),
                        action,
                      ],
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _UnconfirmedBanner extends StatelessWidget {
  const _UnconfirmedBanner({
    required this.email,
    required this.isResending,
    required this.isRefreshing,
    required this.onResend,
    required this.onRefresh,
  });

  final String? email;
  final bool isResending;
  final bool isRefreshing;
  final Future<void> Function() onResend;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB9E3DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm your email',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm ${email ?? 'your email'} to keep access to your account.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isResending ? null : onResend,
                  child: Text(isResending ? 'Sending...' : 'Resend email'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isRefreshing ? null : onRefresh,
                  child: Text(isRefreshing ? 'Checking...' : 'I confirmed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
