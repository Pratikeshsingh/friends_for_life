import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/city_service.dart';
import '../core/event_catalog.dart';
import '../core/event_service.dart';
import '../core/interest_service.dart';
import '../core/notification_service.dart';
import '../core/profile_photo_service.dart';
import '../core/responsive.dart';
import '../widgets/motion.dart';
import 'auth_flow_screen.dart';
import 'event_detail_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';

enum _DeferredSetupKind { meetup }

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
  bool _loggedOutStartInSignIn = false;
  bool _isResendingVerification = false;
  bool _isRefreshingVerification = false;
  bool _isUpdatingMeetups = false;
  bool _isValidatingSession = false;
  bool _isSigningOut = false;
  bool _forceLoggedOut = false;
  bool _hasLoadedEvents = false;
  bool _hasEventLoadError = false;
  bool _hasLoadedReservations = false;
  String? _focusedEventId;
  int _eventsScrollToTopVersion = 0;
  String? _lastValidatedUserId;
  String? _lastLegacyReservationSyncUserId;
  String? _lastProfileWarmupUserId;
  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _eventAttendeesChannel;
  RealtimeChannel? _notificationsChannel;
  Timer? _eventsRefreshTimer;
  Timer? _reservationsRefreshTimer;
  Timer? _notificationsRefreshTimer;
  Timer? _profileWarmupTimer;
  bool _isLoadingEvents = false;
  bool _eventsRefreshQueued = false;
  bool _isLoadingPastEvents = false;
  bool _pastEventsRefreshQueued = false;
  bool _isLoadingReservations = false;
  bool _reservationsRefreshQueued = false;
  bool _isLoadingNotifications = false;
  bool _notificationsRefreshQueued = false;
  bool _isLoadingRevealedVenues = false;
  bool _isWarmingProfileData = false;
  String? _reservationStatusMessage;
  final Set<int> _visitedTabIndexes = <int>{0};
  List<MeetupEvent> _availableEvents = const <MeetupEvent>[];
  List<AppNotification> _notifications = const <AppNotification>[];
  List<MeetupEvent> _pastEvents = const <MeetupEvent>[];
  List<String> _reservedEventIds = const <String>[];
  Map<String, RevealedMeetupVenue> _revealedVenuesByEventId =
      const <String, RevealedMeetupVenue>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEvents();
    if (widget.session != null) {
      _loadPastEvents();
      _loadReservations();
      _loadNotifications();
      _loadRevealedVenues();
      _subscribeToRealtimeUpdates();
      _validateSessionIfNeeded(force: true);
      _scheduleProfileWarmup();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromRealtimeUpdates();
    _eventsRefreshTimer?.cancel();
    _reservationsRefreshTimer?.cancel();
    _notificationsRefreshTimer?.cancel();
    _profileWarmupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PrototypeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.user.id != widget.session?.user.id) {
      _selectedIndex = 0;
      _overrideUser = null;
      _forceLoggedOut = widget.session == null;
      _isSigningOut = false;
      _deferredSetupKind = null;
      _showLoggedOutAuthFlow = false;
      _loggedOutStartInSignIn = false;
      _hasLoadedReservations = false;
      _hasEventLoadError = false;
      _focusedEventId = null;
      _eventsScrollToTopVersion = 0;
      _lastValidatedUserId = null;
      _lastLegacyReservationSyncUserId = null;
      _lastProfileWarmupUserId = null;
      _visitedTabIndexes
        ..clear()
        ..add(0);
      _notifications = const <AppNotification>[];
      _reservedEventIds = const <String>[];
      _revealedVenuesByEventId = const <String, RevealedMeetupVenue>{};
      _unsubscribeFromRealtimeUpdates();
      _loadEvents(forceRefresh: true);
      if (widget.session != null) {
        _loadPastEvents();
        _loadReservations();
        _loadNotifications();
        _loadRevealedVenues();
        _subscribeToRealtimeUpdates();
        _validateSessionIfNeeded(force: true);
        _scheduleProfileWarmup();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadEvents(forceRefresh: true);
    }
    if (state == AppLifecycleState.resumed &&
        (_overrideUser ?? widget.session?.user) != null) {
      _loadPastEvents(forceRefresh: true);
      _loadReservations(forceRefresh: true);
      _loadNotifications(forceRefresh: true);
      _loadRevealedVenues();
      _validateSessionIfNeeded(force: true);
      _scheduleProfileWarmup(const Duration(seconds: 2));
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

    _notificationsChannel = client
        .channel('public:notifications-live:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_profile_id',
            value: userId,
          ),
          callback: (_) {
            if (!mounted) return;
            _scheduleNotificationsRefresh();
          },
        )
        .subscribe();
  }

  void _unsubscribeFromRealtimeUpdates() {
    final client = Supabase.instance.client;
    final eventsChannel = _eventsChannel;
    final attendeesChannel = _eventAttendeesChannel;
    final notificationsChannel = _notificationsChannel;
    _eventsChannel = null;
    _eventAttendeesChannel = null;
    _notificationsChannel = null;

    if (eventsChannel != null) {
      client.removeChannel(eventsChannel);
    }
    if (attendeesChannel != null) {
      client.removeChannel(attendeesChannel);
    }
    if (notificationsChannel != null) {
      client.removeChannel(notificationsChannel);
    }
  }

  void _scheduleEventsRefresh([
    Duration delay = const Duration(milliseconds: 180),
  ]) {
    _eventsRefreshTimer?.cancel();
    _eventsRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      _loadEvents(forceRefresh: true);
    });
  }

  void _scheduleReservationsRefresh([
    Duration delay = const Duration(milliseconds: 120),
  ]) {
    _reservationsRefreshTimer?.cancel();
    _reservationsRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      _loadReservations(forceRefresh: true);
      _loadRevealedVenues();
    });
  }

  void _scheduleNotificationsRefresh([
    Duration delay = const Duration(milliseconds: 120),
  ]) {
    _notificationsRefreshTimer?.cancel();
    _notificationsRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      _loadNotifications(forceRefresh: true);
      _loadRevealedVenues();
    });
  }

  void _scheduleProfileWarmup([
    Duration delay = const Duration(milliseconds: 1800),
  ]) {
    _profileWarmupTimer?.cancel();
    _profileWarmupTimer = Timer(delay, () {
      if (!mounted) return;
      unawaited(_warmProfileData());
    });
  }

  Future<void> _warmProfileData() async {
    if (_isWarmingProfileData) return;
    if (_visitedTabIndexes.contains(2)) return;

    final user = _overrideUser ?? widget.session?.user;
    if (user == null || _lastProfileWarmupUserId == user.id) return;

    _isWarmingProfileData = true;
    try {
      final client = Supabase.instance.client;
      await Future.wait<void>([
        CityService(client).fetchCityOptions().then((_) {}),
        InterestService(client).fetchInterestOptions().then((_) {}),
        _warmProfilePhotoUrl(client, user),
      ]);
      _lastProfileWarmupUserId = user.id;
    } catch (_) {
      // Warm-up is best-effort; visible screens should never wait on it.
    } finally {
      _isWarmingProfileData = false;
    }
  }

  Future<void> _warmProfilePhotoUrl(SupabaseClient client, User user) async {
    var photoPath = user.userMetadata?['profile_photo_path'] as String?;

    if ((photoPath == null || photoPath.isEmpty) && user.id.isNotEmpty) {
      try {
        final response = await client
            .from('profiles')
            .select('profile_photo_path')
            .eq('id', user.id)
            .maybeSingle();
        photoPath = response?['profile_photo_path'] as String?;
      } catch (_) {
        return;
      }
    }

    if (photoPath == null || photoPath.isEmpty) return;

    try {
      await ProfilePhotoService.createSignedPhotoUrl(
        supabase: client,
        path: photoPath,
      );
    } catch (_) {
      // Profile can still request the URL later if this background attempt fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        _forceLoggedOut ? null : (_overrideUser ?? widget.session?.user);
    final reduceMotion = prefersReducedMotion(context);

    if (currentUser == null) {
      return _showLoggedOutAuthFlow
          ? AuthFlowScreen(
              startInSignIn: _loggedOutStartInSignIn,
              onClose: () {
                if (!mounted) return;
                setState(() {
                  _showLoggedOutAuthFlow = false;
                  _loggedOutStartInSignIn = false;
                });
              },
            )
          : OnboardingScreen(
              availableEvents: _availableEvents,
              isLoadingMeetups: _isLoadingEvents && !_hasLoadedEvents,
              hasEventLoadError: _hasEventLoadError,
              onRetryMeetups: () => _loadEvents(forceRefresh: true),
              onStart: () {
                if (!mounted) return;
                setState(() {
                  _showLoggedOutAuthFlow = true;
                  _loggedOutStartInSignIn = false;
                });
              },
              onSignIn: () {
                if (!mounted) return;
                setState(() {
                  _showLoggedOutAuthFlow = true;
                  _loggedOutStartInSignIn = true;
                });
              },
            );
    }

    final needsMeetupSetup = _needsCoreOnboarding(currentUser);
    final deferredMeetupSetup = _deferredSetupKind == _DeferredSetupKind.meetup;
    final hasEverReservedMeetup =
        (currentUser.userMetadata?['has_ever_reserved_meetup'] as bool?) ==
            true;
    final reserveReminderTitle = hasEverReservedMeetup
        ? 'Choose your next meetup'
        : 'Choose your first meetup';
    if ((needsMeetupSetup && !deferredMeetupSetup) || _showDeferredSetupFlow) {
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
            _hasLoadedReservations = true;
            if (!_needsCoreOnboarding(updatedUser)) {
              _deferredSetupKind = null;
            }
          });
          _loadReservations(forceRefresh: true);
          _loadEvents(forceRefresh: true);
          _loadPastEvents(forceRefresh: true);
          _scheduleProfileWarmup();
        },
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
            _hasLoadedReservations = true;
          });
          _loadReservations(forceRefresh: true);
          _loadEvents(forceRefresh: true);
          _loadPastEvents(forceRefresh: true);
        },
      );
    }

    final notifications = _notifications;
    final displayEvents = _applyRevealedVenueAddresses(
      _applyNotificationAddresses(_availableEvents, notifications),
    );
    final revealedLocationsByEventId =
        _revealedLocationsByEventId(notifications);
    final selectedEvents = selectedMeetupEventsFromIds(
      _reservedEventIds,
      availableEvents: displayEvents,
    );
    final sortedSelectedEvents = [...selectedEvents]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final selectedEvent =
        sortedSelectedEvents.isEmpty ? null : sortedSelectedEvents.first;
    final isResolvingReservedMeetup = _reservedEventIds.isNotEmpty &&
        selectedEvents.isEmpty &&
        !_hasLoadedEvents;
    final unreadNotificationCount =
        notifications.where((notification) => !notification.isRead).length;

    final screenBuilders = <Widget Function()>[
      () => HomeScreen(
            onOpenEvent: (event) => setState(() {
              _focusedEventId = event?.id;
              _selectedIndex = 1;
              _visitedTabIndexes.add(1);
              if (event == null) {
                _eventsScrollToTopVersion++;
              }
            }),
            userEmail: currentUser.email,
            firstName: currentUser.userMetadata?['first_name'] as String?,
            city: currentUser.userMetadata?['city'] as String?,
            selectedEvent: selectedEvent,
            selectedEvents: selectedEvents,
            availableEvents: displayEvents,
            revealedLocationsByEventId: revealedLocationsByEventId,
            isMeetupLoading:
                (!_hasLoadedReservations && hasEverReservedMeetup) ||
                    isResolvingReservedMeetup,
            unreadNotificationCount: unreadNotificationCount,
            onOpenNotifications: () => _openNotificationsSheet(notifications),
          ),
      () => EventDetailScreen(
            event: selectedEvent,
            focusedEventId: _focusedEventId,
            scrollToTopVersion: _eventsScrollToTopVersion,
            allEvents: displayEvents,
            pastEvents: _pastEvents,
            selectedEventIds: selectedEvents.map((event) => event.id).toSet(),
            revealedLocationsByEventId: revealedLocationsByEventId,
            isUpdatingSelection: _isUpdatingMeetups,
            hasEventLoadError: _hasEventLoadError,
            onRetryEvents: () => _loadEvents(forceRefresh: true),
            onSelectEvent: _selectMeetup,
            onCancelEvent: _cancelMeetup,
            unreadNotificationCount: unreadNotificationCount,
            onOpenNotifications: () => _openNotificationsSheet(notifications),
            onFocusHandled: () {
              if (!mounted || _focusedEventId == null) return;
              setState(() => _focusedEventId = null);
            },
          ),
      () => ProfileScreen(
            user: currentUser,
            onUserUpdated: (updatedUser) {
              setState(() => _overrideUser = updatedUser);
              _scheduleProfileWarmup();
            },
            onSignOut: _signOut,
            isSigningOut: _isSigningOut,
            unreadNotificationCount: unreadNotificationCount,
            onOpenNotifications: () => _openNotificationsSheet(notifications),
          ),
    ];
    final activeIndex =
        _selectedIndex.clamp(0, screenBuilders.length - 1).toInt();
    final showSetupReminder = _deferredSetupKind == _DeferredSetupKind.meetup &&
        needsMeetupSetup &&
        _selectedIndex == 0;
    final hasTopBanner =
        currentUser.emailConfirmedAt == null || showSetupReminder;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      body: Column(
        children: [
          if (hasTopBanner)
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentUser.emailConfirmedAt == null)
                    _UnconfirmedBanner(
                      email: currentUser.email,
                      isResending: _isResendingVerification,
                      isRefreshing: _isRefreshingVerification,
                      onResend: _resendVerificationEmail,
                      onRefresh: _refreshVerificationStatus,
                    ),
                  if (showSetupReminder)
                    _SetupReminderBanner(
                      title: reserveReminderTitle,
                      body:
                          'Browse upcoming times and reserve when one feels right.',
                      actionLabel: 'Browse meetups',
                      onContinue: () {
                        setState(() {
                          _selectedIndex = 1;
                          _visitedTabIndexes.add(1);
                          _eventsScrollToTopVersion++;
                        });
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var index = 0; index < screenBuilders.length; index++)
                  _ShellScreenLayer(
                    isSelected: index == activeIndex,
                    reduceMotion: reduceMotion,
                    child: KeyedSubtree(
                      key: ValueKey('shell-screen-$index'),
                      child: _visitedTabIndexes.contains(index)
                          ? MediaQuery.removePadding(
                              context: context,
                              removeTop: hasTopBanner,
                              child: screenBuilders[index](),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                if (_reservationStatusMessage != null)
                  Positioned(
                    left: responsiveHorizontalPadding(
                      MediaQuery.sizeOf(context).width,
                    ),
                    right: responsiveHorizontalPadding(
                      MediaQuery.sizeOf(context).width,
                    ),
                    bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _ReservationStatusBanner(
                          message: _reservationStatusMessage!,
                          onDismiss: () {
                            setState(() => _reservationStatusMessage = null);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compactNavigation = width < 600;
          final horizontal =
              compactNavigation ? 0.0 : responsiveHorizontalPadding(width);
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          const navHeight = 76.0;
          const navTopBreathingRoom = 4.0;
          final navBottomGap = compactNavigation ? 0.0 : 12.0;
          final borderRadius = compactNavigation
              ? const BorderRadius.vertical(top: Radius.circular(22))
              : BorderRadius.circular(24);
          final navigationSurface =
              Theme.of(context).navigationBarTheme.backgroundColor ??
                  const Color(0xFFFFFCF7);

          return SizedBox(
            height:
                navHeight + navTopBreathingRoom + navBottomGap + bottomInset,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                0,
                horizontal,
                navBottomGap,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: ColoredBox(
                      color: navigationSurface,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: navTopBreathingRoom,
                          bottom: bottomInset,
                        ),
                        child: NavigationBar(
                          height: navHeight,
                          selectedIndex: activeIndex,
                          onDestinationSelected: (index) => setState(() {
                            _selectedIndex = index;
                            _visitedTabIndexes.add(index);
                            if (index == 1) {
                              _focusedEventId = null;
                              _eventsScrollToTopVersion++;
                            }
                          }),
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
                    ),
                  ),
                ),
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
      _scheduleProfileWarmup();
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

  Future<void> _openNotificationsSheet(
    List<AppNotification> notifications,
  ) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    final unreadIds = notifications
        .where((notification) => !notification.isRead)
        .map((notification) => notification.id)
        .toList();

    if (unreadIds.isNotEmpty) {
      final readAt = DateTime.now();
      setState(() {
        _notifications = [
          for (final notification in _notifications)
            unreadIds.contains(notification.id)
                ? notification.copyWith(readAt: readAt)
                : notification,
        ];
      });
      unawaited(
        NotificationService(Supabase.instance.client).markNotificationsRead(
          profileId: user.id,
          notificationIds: unreadIds,
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => _NotificationCenterSheet(
        notifications: notifications,
      ),
    );
  }

  bool _isMissingUserError(AuthException error) {
    final message = error.message.toLowerCase();
    return message.contains('user from sub claim in jwt does not exist') ||
        message.contains('user does not exist');
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _clearAuthenticatedState();
        _isSigningOut = false;
      });
    } on AuthException catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not sign you out. Try again.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not sign you out. Try again.'),
        ),
      );
    }
  }

  void _clearAuthenticatedState() {
    _unsubscribeFromRealtimeUpdates();
    _eventsRefreshTimer?.cancel();
    _reservationsRefreshTimer?.cancel();
    _notificationsRefreshTimer?.cancel();
    _profileWarmupTimer?.cancel();
    _selectedIndex = 0;
    _overrideUser = null;
    _forceLoggedOut = true;
    _deferredSetupKind = null;
    _showDeferredSetupFlow = false;
    _showLoggedOutAuthFlow = false;
    _loggedOutStartInSignIn = false;
    _hasLoadedReservations = false;
    _hasEventLoadError = false;
    _focusedEventId = null;
    _eventsScrollToTopVersion = 0;
    _lastValidatedUserId = null;
    _lastLegacyReservationSyncUserId = null;
    _lastProfileWarmupUserId = null;
    _reservationStatusMessage = null;
    _visitedTabIndexes
      ..clear()
      ..add(0);
    _notifications = const <AppNotification>[];
    _reservedEventIds = const <String>[];
  }

  Future<void> _handleInvalidSession() async {
    if (!mounted) return;

    setState(() {
      _clearAuthenticatedState();
    });

    if (!_isSigningOut) {
      try {
        _isSigningOut = true;
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // The session is already unusable; keep the local logged-out UI.
      } finally {
        _isSigningOut = false;
      }
    }

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
        const SnackBar(content: Text('Verification email sent.')),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'We could not send the email. Check the address and try again.')),
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
    final hasMeetupSelection =
        ((metadata['selected_event_ids'] as List?) ?? const []).isNotEmpty;
    final completedOnboarding =
        (metadata['completed_onboarding'] as bool?) == true;

    return !(hasDetails && (hasMeetupSelection || completedOnboarding));
  }

  _DeferredSetupKind? _incompleteSetupKindForUser(User user) {
    if (_needsCoreOnboarding(user)) {
      return _DeferredSetupKind.meetup;
    }
    return null;
  }

  Future<void> _refreshVerificationStatus() async {
    setState(() => _isRefreshingVerification = true);
    try {
      final response = await Supabase.instance.client.auth.getUser();
      if (!mounted) return;
      setState(() => _overrideUser = response.user);
      _loadReservations(forceRefresh: true);

      final confirmed = response.user?.emailConfirmedAt != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed
                ? 'Email verified. You are all set.'
                : 'We have not seen the verification yet. Check your inbox and spam folder.',
          ),
        ),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
          'We could not check your verification status. Try again.',
        )),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshingVerification = false);
      }
    }
  }

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    if (_isLoadingEvents) {
      _eventsRefreshQueued = _eventsRefreshQueued || forceRefresh;
      return;
    }

    _isLoadingEvents = true;
    try {
      final events = await EventService(
        Supabase.instance.client,
      ).fetchOpenEvents(forceRefresh: forceRefresh);
      final hasLoadError = EventService.openEventsLoadFailed;
      if (!mounted) return;
      if (sameMeetupEventLists(_availableEvents, events) &&
          _hasLoadedEvents &&
          _hasEventLoadError == hasLoadError) {
        return;
      }
      setState(() {
        _availableEvents = events;
        _hasLoadedEvents = true;
        _hasEventLoadError = hasLoadError;
      });
    } finally {
      _isLoadingEvents = false;
      if (!mounted) {
        _eventsRefreshQueued = false;
      } else if (_eventsRefreshQueued) {
        _eventsRefreshQueued = false;
        unawaited(_loadEvents(forceRefresh: true));
      }
    }
  }

  Future<void> _loadPastEvents({bool forceRefresh = false}) async {
    if (_isLoadingPastEvents) {
      _pastEventsRefreshQueued = _pastEventsRefreshQueued || forceRefresh;
      return;
    }

    _isLoadingPastEvents = true;
    try {
      final events = await EventService(
        Supabase.instance.client,
      ).fetchPastEvents(limit: 3, forceRefresh: forceRefresh);
      if (!mounted) return;

      if (sameMeetupEventLists(_pastEvents, events)) return;
      setState(() => _pastEvents = events);
    } finally {
      _isLoadingPastEvents = false;
      if (!mounted) {
        _pastEventsRefreshQueued = false;
      } else if (_pastEventsRefreshQueued) {
        _pastEventsRefreshQueued = false;
        unawaited(_loadPastEvents(forceRefresh: true));
      }
    }
  }

  Future<void> _loadReservations({bool forceRefresh = false}) async {
    if (_isLoadingReservations) {
      _reservationsRefreshQueued = _reservationsRefreshQueued || forceRefresh;
      return;
    }

    final user = _overrideUser ?? widget.session?.user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _reservedEventIds = const <String>[];
        _hasLoadedReservations = true;
      });
      return;
    }

    _isLoadingReservations = true;
    try {
      final eventService = EventService(Supabase.instance.client);
      var reservedIds = await eventService.fetchReservedEventIds(
        user.id,
        forceRefresh: forceRefresh,
      );
      final legacyIds =
          (user.userMetadata?['selected_event_ids'] as List<dynamic>? ??
                  const [])
              .whereType<String>()
              .toList();

      final canAttemptLegacySync =
          reservedIds.isEmpty && _lastLegacyReservationSyncUserId != user.id;

      if (canAttemptLegacySync) {
        if (legacyIds.isNotEmpty) {
          reservedIds = legacyIds;
          try {
            for (final eventId in legacyIds) {
              await eventService.reserveEvent(
                eventId: eventId,
                profileId: user.id,
              );
            }
            reservedIds = await eventService.fetchReservedEventIds(
              user.id,
              forceRefresh: true,
            );
            if (reservedIds.isEmpty) {
              reservedIds = legacyIds;
            }
          } catch (_) {
            reservedIds = legacyIds;
          }
        }

        _lastLegacyReservationSyncUserId = user.id;
      } else if (reservedIds.isEmpty && legacyIds.isNotEmpty) {
        reservedIds = legacyIds;
      }

      if (!mounted) return;
      if (listEquals(_reservedEventIds, reservedIds) &&
          _hasLoadedReservations) {
        return;
      }
      setState(() {
        _reservedEventIds = reservedIds;
        _hasLoadedReservations = true;
      });
    } finally {
      _isLoadingReservations = false;
      if (!mounted) {
        _reservationsRefreshQueued = false;
      } else if (_reservationsRefreshQueued) {
        _reservationsRefreshQueued = false;
        unawaited(_loadReservations(forceRefresh: true));
      }
    }
  }

  Future<void> _loadNotifications({bool forceRefresh = false}) async {
    if (_isLoadingNotifications) {
      _notificationsRefreshQueued = _notificationsRefreshQueued || forceRefresh;
      return;
    }

    final user = _overrideUser ?? widget.session?.user;
    if (user == null) {
      if (!mounted || _notifications.isEmpty) return;
      setState(() => _notifications = const <AppNotification>[]);
      return;
    }

    _isLoadingNotifications = true;
    try {
      final notifications = await NotificationService(Supabase.instance.client)
          .fetchNotifications(
        user.id,
        forceRefresh: forceRefresh,
      );

      if (!mounted || _sameNotifications(_notifications, notifications)) {
        return;
      }
      setState(() => _notifications = notifications);
    } finally {
      _isLoadingNotifications = false;
      if (!mounted) {
        _notificationsRefreshQueued = false;
      } else if (_notificationsRefreshQueued) {
        _notificationsRefreshQueued = false;
        unawaited(_loadNotifications(forceRefresh: true));
      }
    }
  }

  Future<void> _loadRevealedVenues() async {
    if (_isLoadingRevealedVenues) return;

    final user = _overrideUser ?? widget.session?.user;
    if (user == null) {
      if (!mounted || _revealedVenuesByEventId.isEmpty) return;
      setState(() {
        _revealedVenuesByEventId = const <String, RevealedMeetupVenue>{};
      });
      return;
    }

    _isLoadingRevealedVenues = true;
    try {
      final venues = await EventService(
        Supabase.instance.client,
      ).fetchRevealedVenues();
      if (!mounted) return;

      final next = <String, RevealedMeetupVenue>{
        for (final venue in venues) venue.eventId: venue,
      };
      if (_sameRevealedVenueMaps(_revealedVenuesByEventId, next)) return;
      setState(() => _revealedVenuesByEventId = next);
    } catch (_) {
      // The app remains usable while the release-hardening migration is being
      // deployed. A later refresh or the address notification will retry.
    } finally {
      _isLoadingRevealedVenues = false;
    }
  }

  bool _sameRevealedVenueMaps(
    Map<String, RevealedMeetupVenue> current,
    Map<String, RevealedMeetupVenue> next,
  ) {
    if (current.length != next.length) return false;
    for (final entry in current.entries) {
      final candidate = next[entry.key];
      if (candidate == null ||
          candidate.venueName != entry.value.venueName ||
          candidate.venueAddress != entry.value.venueAddress ||
          candidate.city != entry.value.city ||
          candidate.releasedAt != entry.value.releasedAt) {
        return false;
      }
    }
    return true;
  }

  bool _sameNotifications(
    List<AppNotification> previous,
    List<AppNotification> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;

    for (var index = 0; index < previous.length; index++) {
      final current = previous[index];
      final candidate = next[index];
      if (current.id != candidate.id ||
          current.readAt != candidate.readAt ||
          current.title != candidate.title ||
          current.body != candidate.body ||
          current.metadata.toString() != candidate.metadata.toString() ||
          current.kind != candidate.kind ||
          current.createdAt != candidate.createdAt) {
        return false;
      }
    }

    return true;
  }

  List<MeetupEvent> _applyNotificationAddresses(
    List<MeetupEvent> events,
    List<AppNotification> notifications,
  ) {
    if (events.isEmpty || notifications.isEmpty) return events;

    final overrides = <String, AppNotification>{};
    for (final notification in notifications) {
      if (notification.kind != AppNotificationKind.address) continue;
      final eventId = notification.eventId;
      if (eventId == null || eventId.isEmpty) continue;
      if (notification.revealedAddress == null) continue;
      overrides.putIfAbsent(eventId, () => notification);
    }

    if (overrides.isEmpty) return events;

    return [
      for (final event in events)
        if (overrides.containsKey(event.id))
          event.copyWith(
            venueName:
                overrides[event.id]!.revealedVenueName ?? event.venueName,
            venueAddress:
                overrides[event.id]!.revealedAddress ?? event.venueAddress,
          )
        else
          event,
    ];
  }

  List<MeetupEvent> _applyRevealedVenueAddresses(List<MeetupEvent> events) {
    if (events.isEmpty || _revealedVenuesByEventId.isEmpty) return events;
    return [
      for (final event in events)
        if (_revealedVenuesByEventId.containsKey(event.id))
          event.withRevealedVenue(_revealedVenuesByEventId[event.id]!)
        else
          event,
    ];
  }

  Map<String, String> _revealedLocationsByEventId(
    List<AppNotification> notifications,
  ) {
    final result = <String, String>{};
    for (final notification in notifications) {
      if (notification.kind != AppNotificationKind.address) continue;
      final eventId = notification.eventId;
      final location = notification.exactLocationLabel;
      if (eventId == null || eventId.isEmpty || location == null) continue;
      result.putIfAbsent(eventId, () => location);
    }
    for (final entry in _revealedVenuesByEventId.entries) {
      result[entry.key] = entry.value.locationLabel;
    }
    return result;
  }

  Future<void> _selectMeetup(MeetupEvent event) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    if (!event.isOpenForReservation) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Text(event.reservationUnavailableLabel)));
      return;
    }

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

    final updated = await _updateSelectedMeetups(
      nextIds,
      successMessage: 'Reservation confirmed for ${event.title}.',
      showSuccessSnackBar: false,
    );
    if (!mounted || !updated) return;

    setState(() => _focusedEventId = event.id);
    final revealedVenue = _revealedVenuesByEventId[event.id];
    final confirmedEvent =
        revealedVenue == null ? event : event.withRevealedVenue(revealedVenue);
    final undo = await _showReservationConfirmation(confirmedEvent);
    if (!mounted || undo != true) return;

    await _updateSelectedMeetups(
      currentIds,
      successMessage: 'Reservation undone.',
    );
    if (mounted && _focusedEventId == event.id) {
      setState(() {
        _focusedEventId = currentIds.isEmpty ? null : currentIds.first;
      });
    }
  }

  Future<bool?> _showReservationConfirmation(MeetupEvent event) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReservationConfirmationSheet(
        event: event,
        canUndo: canCancelMeetupReservation(event),
      ),
    );
  }

  Future<void> _cancelMeetup(MeetupEvent event) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return;

    if (!canCancelMeetupReservation(event)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancellations close 12 hours before the meetup starts.',
          ),
        ),
      );
      return;
    }

    final currentIds = [..._reservedEventIds];
    final nextIds =
        currentIds.where((selectedId) => selectedId != event.id).toList();

    await _updateSelectedMeetups(
      nextIds,
      successMessage: nextIds.isEmpty
          ? 'Your reservation has been cancelled.'
          : 'Reservation cancelled. Your other seats are still confirmed.',
    );
    if (mounted && _focusedEventId == event.id) {
      setState(() {
        _focusedEventId = nextIds.isEmpty ? null : nextIds.first;
      });
    }
  }

  Future<bool> _updateSelectedMeetups(
    List<String> eventIds, {
    required String successMessage,
    SnackBarAction? action,
    bool showSuccessSnackBar = true,
  }) async {
    final user = _overrideUser ?? widget.session?.user;
    if (user == null) return false;

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
    final newlyRevealedVenues = <String, RevealedMeetupVenue>{};
    var succeeded = false;

    setState(() => _isUpdatingMeetups = true);

    try {
      final eventService = EventService(Supabase.instance.client);
      if (addedIds.isNotEmpty) {
        for (final eventId in addedIds) {
          final result = await eventService.reserveEvent(
            eventId: eventId,
            profileId: user.id,
          );
          final venue = result.revealedVenue;
          if (venue != null) {
            newlyRevealedVenues[eventId] = venue;
          }
        }
      }

      for (final eventId in removedIds) {
        await eventService.cancelReservation(
          eventId: eventId,
          profileId: user.id,
        );
      }

      final refreshedReservedIds = await eventService.fetchReservedEventIds(
        user.id,
      );
      final refreshedMetadata = {
        ...mergedMetadata,
        'selected_event_ids': refreshedReservedIds,
      };
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: refreshedMetadata),
      );

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'first_name': refreshedMetadata['first_name'],
        'phone': refreshedMetadata['phone'],
        'address': refreshedMetadata['address'],
        'city': refreshedMetadata['city'],
        'date_of_birth': refreshedMetadata['date_of_birth'],
        'gender': refreshedMetadata['gender'],
        'language': refreshedMetadata['language'],
        'availability': refreshedMetadata['availability'],
        'energy': refreshedMetadata['energy'],
        'group_preference': refreshedMetadata['group_preference'],
        'conversation_goals': refreshedMetadata['conversation_goals'],
        'dietary_notes': refreshedMetadata['dietary_notes'],
        'interests': refreshedMetadata['interests'] ?? const <String>[],
        'selected_event_ids': refreshedReservedIds,
        'profile_photo_path': refreshedMetadata['profile_photo_path'],
        'profile_photo_name': refreshedMetadata['profile_photo_name'],
        'secondary_photo_path': refreshedMetadata['secondary_photo_path'],
        'secondary_photo_name': refreshedMetadata['secondary_photo_name'],
        'has_profile_photo': refreshedMetadata['has_profile_photo'] ?? false,
      }, onConflict: 'id');
      final locallyUpdatedUser = User.fromJson({
        ...user.toJson(),
        'user_metadata': refreshedMetadata,
      });
      final locallyUpdatedEvents = _applyReservationSeatDeltas(
        addedIds: addedIds,
        removedIds: removedIds,
      );

      if (!mounted) return false;

      setState(() {
        _overrideUser = locallyUpdatedUser ?? response.user ?? user;
        _reservedEventIds = refreshedReservedIds;
        _availableEvents = locallyUpdatedEvents;
        if (newlyRevealedVenues.isNotEmpty) {
          _revealedVenuesByEventId = {
            ..._revealedVenuesByEventId,
            ...newlyRevealedVenues,
          };
        }
        _reservationStatusMessage = null;
      });

      succeeded = true;
      if (showSuccessSnackBar) {
        final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            duration: const Duration(seconds: 4),
            action: action,
          ),
        );
        Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          snackBarController.close();
        });
      }
      unawaited(_loadNotifications(forceRefresh: true));
      unawaited(_loadRevealedVenues());
    } on AuthException catch (_) {
      _showReservationUpdateError();
    } on PostgrestException catch (_) {
      _showReservationUpdateError();
    } catch (_) {
      _showReservationUpdateError();
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMeetups = false);
      }
    }
    return succeeded;
  }

  void _showReservationUpdateError() {
    if (!mounted) return;
    setState(
      () => _reservationStatusMessage =
          'We could not update your reservation. Check your connection and try again.',
    );
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

class _ReservationConfirmationSheet extends StatelessWidget {
  const _ReservationConfirmationSheet({
    required this.event,
    required this.canUndo,
  });

  final MeetupEvent event;
  final bool canUndo;

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': event.locationDetailLabel,
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maps did not open. Copy the address and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAddress = event.shouldRevealExactAddress;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFCF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D8D5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFE5F7F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF087B76),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text('You’re in.', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Your seat for ${event.title} is confirmed.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF526771),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ConfirmationPill(
                  icon: Icons.calendar_today_outlined,
                  label: event.detailDateLabel,
                ),
                _ConfirmationPill(
                  icon: Icons.schedule_outlined,
                  label: event.detailTimeLabel,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasAddress
                    ? const Color(0xFFEAF7F5)
                    : const Color(0xFFFFF4E4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasAddress
                      ? const Color(0xFFC7E8E1)
                      : const Color(0xFFF1DAB4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasAddress
                        ? Icons.location_on_outlined
                        : Icons.notifications_active_outlined,
                    color: hasAddress
                        ? const Color(0xFF138B8A)
                        : const Color(0xFFAD6F17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasAddress
                              ? 'Address ready now'
                              : 'Address at 10:00 the day before',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF062B55),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          hasAddress
                              ? event.locationDetailLabel
                              : 'We’ll send the exact public venue in a notification. If 10:00 has already passed, it will appear as soon as the server confirms it.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF526771),
                            fontWeight:
                                hasAddress ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          hasAddress
                              ? 'It’s also saved in your VriendTime notifications.'
                              : 'You don’t need to check back manually.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF687A80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasAddress) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openMaps(context),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Open in Maps'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Done'),
              ),
            ),
            if (canUndo) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Undo reservation'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'This meetup is within the 12-hour cancellation window.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7A8589),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmationPill extends StatelessWidget {
  const _ConfirmationPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF138B8A)),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF355D64),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
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

class _ReservationStatusBanner extends StatelessWidget {
  const _ReservationStatusBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8C273)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26150806),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5A8),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.sync_problem_outlined,
                color: Color(0xFF8A5A00),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reservation not saved',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF062B55),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4F6671),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Dismiss',
              child: IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                color: const Color(0xFF062B55),
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
              ),
            ),
          ],
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
            'Confirm ${email ?? 'your email'} so we can protect your account and send important meetup updates.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final resendButton = ElevatedButton(
                onPressed: isResending ? null : onResend,
                child: Text(isResending ? 'Sending...' : 'Send again'),
              );
              final refreshButton = OutlinedButton(
                onPressed: isRefreshing ? null : onRefresh,
                child: Text(isRefreshing ? 'Checking...' : 'Check again'),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    resendButton,
                    const SizedBox(height: 10),
                    refreshButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: resendButton),
                  const SizedBox(width: 12),
                  Expanded(child: refreshButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationCenterSheet extends StatelessWidget {
  const _NotificationCenterSheet({
    required this.notifications,
  });

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = constraints.maxWidth > 760
            ? (constraints.maxWidth - 720) / 2
            : 12.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sideInset),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.76,
            minChildSize: 0.48,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFCF7),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 52,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD3DBD8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notifications',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Meetup updates in one place',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF60727A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Close notifications',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: notifications.isEmpty
                              ? SingleChildScrollView(
                                  controller: scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 8, 20, 28),
                                  child: const Center(
                                    child: _NotificationsEmptyState(),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 8, 20, 28),
                                  itemCount: notifications.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _NotificationTile(
                                      notification: notifications[index],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFDDE7E3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1406294A),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 24,
                compact ? 22 : 28,
                compact ? 18 : 24,
                compact ? 22 : 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NotificationsEmptyIllustration(compact: compact),
                  SizedBox(height: compact ? 14 : 18),
                  Text(
                    'No notifications yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: compact ? 23 : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Address details, meetup updates, and support replies will show up here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF60727A),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationsEmptyIllustration extends StatelessWidget {
  const _NotificationsEmptyIllustration({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 140.0 : 180.0;
    final height = compact ? 110.0 : 140.0;
    final circleSize = compact ? 58.0 : 70.0;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: compact ? 14 : 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEAF7F5),
                    Color(0xFFF7ECE4),
                  ],
                ),
                borderRadius: BorderRadius.circular(compact ? 24 : 28),
              ),
              child: SizedBox(
                width: compact ? 108 : 132,
                height: compact ? 72 : 88,
              ),
            ),
          ),
          Positioned(
            left: compact ? 14 : 18,
            top: compact ? 42 : 54,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: compact ? 54 : 62,
                height: compact ? 40 : 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDDE7E3)),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: const Color(0xFF60727A),
                  size: compact ? 22 : 24,
                ),
              ),
            ),
          ),
          Positioned(
            right: compact ? 12 : 16,
            top: compact ? 38 : 48,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF138B8A),
                    Color(0xFF69C9BD),
                  ],
                ),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: compact ? 30 : 34,
              ),
            ),
          ),
          Positioned(
            right: compact ? 24 : 32,
            top: compact ? 24 : 32,
            child: const _SparkDot(size: 10, color: Color(0xFFFFC36E)),
          ),
          Positioned(
            left: compact ? 32 : 42,
            top: compact ? 22 : 30,
            child: const _SparkDot(size: 8, color: Color(0xFF9CD8CF)),
          ),
          Positioned(
            left: compact ? 44 : 58,
            bottom: compact ? 12 : 16,
            child: const _SparkDot(size: 6, color: Color(0xFFFFD9C9)),
          ),
          Positioned(
            right: compact ? 42 : 52,
            bottom: compact ? 16 : 20,
            child: const _SparkDot(size: 7, color: Color(0xFFB9E3DC)),
          ),
        ],
      ),
    );
  }
}

class _SparkDot extends StatelessWidget {
  const _SparkDot({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
  });

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _backgroundColorForNotification(notification.kind),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconForNotification(notification.kind),
              color: _iconColorForNotification(notification.kind),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _timeLabel(notification.createdAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF60727A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notification.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4F6671),
                  ),
                ),
                if (notification.kind == AppNotificationKind.address &&
                    notification.exactLocationLabel != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: Color(0xFF138B8A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.exactLocationLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF062B55),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notification.mapsUri != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await launchUrl(
                            notification.mapsUri!,
                            mode: LaunchMode.platformDefault,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF138B8A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Open in Maps'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';

    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  IconData _iconForNotification(AppNotificationKind kind) {
    switch (kind) {
      case AppNotificationKind.address:
        return Icons.location_on_outlined;
      case AppNotificationKind.reminder:
        return Icons.notifications_active_outlined;
      case AppNotificationKind.update:
        return Icons.event_busy_outlined;
      case AppNotificationKind.support:
        return Icons.support_agent_outlined;
    }
  }

  Color _backgroundColorForNotification(AppNotificationKind kind) {
    switch (kind) {
      case AppNotificationKind.address:
        return const Color(0xFFEAF7F5);
      case AppNotificationKind.reminder:
        return const Color(0xFFFFF1EB);
      case AppNotificationKind.update:
        return const Color(0xFFFFF5DB);
      case AppNotificationKind.support:
        return const Color(0xFFEDF2FF);
    }
  }

  Color _iconColorForNotification(AppNotificationKind kind) {
    switch (kind) {
      case AppNotificationKind.address:
        return const Color(0xFF138B8A);
      case AppNotificationKind.reminder:
        return const Color(0xFFD85F4D);
      case AppNotificationKind.update:
        return const Color(0xFF9B6A0E);
      case AppNotificationKind.support:
        return const Color(0xFF3159A8);
    }
  }
}
