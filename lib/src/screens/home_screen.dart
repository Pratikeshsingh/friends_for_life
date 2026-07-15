import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/calendar_service.dart';
import '../core/event_catalog.dart';
import '../core/responsive.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/continuous_immersive_scene.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenEvent,
    this.userEmail,
    this.firstName,
    this.city,
    required this.selectedEvent,
    required this.selectedEvents,
    required this.availableEvents,
    this.revealedLocationsByEventId = const <String, String>{},
    this.isMeetupLoading = false,
    required this.unreadNotificationCount,
    required this.onOpenNotifications,
  });

  final ValueChanged<MeetupEvent?> onOpenEvent;
  final String? userEmail;
  final String? firstName;
  final String? city;
  final MeetupEvent? selectedEvent;
  final List<MeetupEvent> selectedEvents;
  final List<MeetupEvent> availableEvents;
  final Map<String, String> revealedLocationsByEventId;
  final bool isMeetupLoading;
  final int unreadNotificationCount;
  final VoidCallback onOpenNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _timeOfDayGreeting();
    final greetingName = _displayName(
      (widget.firstName != null && widget.firstName!.trim().isNotEmpty)
          ? widget.firstName!.trim()
          : (widget.userEmail?.split('@').first ?? 'there'),
    );
    final allBrowseEvents = [...widget.availableEvents]
      ..removeWhere(
          (event) => widget.selectedEvents.any((saved) => saved.id == event.id))
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final cityLabel = widget.city?.trim();
    final preferredCity = widget.selectedEvent?.city.trim().isNotEmpty == true
        ? widget.selectedEvent!.city.trim()
        : cityLabel;
    final sameCityEvents = preferredCity == null || preferredCity.isEmpty
        ? allBrowseEvents
        : allBrowseEvents
            .where(
              (event) =>
                  event.city.toLowerCase() == preferredCity.toLowerCase(),
            )
            .toList();
    final browseEvents =
        sameCityEvents.isNotEmpty ? sameCityEvents : allBrowseEvents;
    final browseSummary = _browseSummary(
      events: browseEvents,
      allEvents: allBrowseEvents,
      preferredCity: preferredCity,
      isUsingOtherCities: preferredCity != null &&
          preferredCity.isNotEmpty &&
          allBrowseEvents.isNotEmpty &&
          sameCityEvents.isEmpty,
    );
    return ContinuousImmersiveScene(
      assetName: GeneratedImageAssets.homeContinuousScene,
      semanticLabel: 'A warm cafe prepared for people to meet',
      alignment: Alignment.topRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontal = responsiveHorizontalPadding(width);
          final maxWidth = responsiveContentMaxWidth(width);
          final wideHome =
              isWideContentWidth(width) && widget.selectedEvent != null;
          Widget buildPrimaryMeetup() {
            if (widget.selectedEvent != null) {
              final event = widget.selectedEvent!;
              final locationOverride =
                  widget.revealedLocationsByEventId[event.id]?.trim();
              final hasRevealedLocation =
                  (locationOverride?.isNotEmpty ?? false) ||
                      event.shouldRevealExactAddress;
              return _NextMeetupReminder(
                event: event,
                revealedLocationLabel: locationOverride,
                hasRevealedLocation: hasRevealedLocation,
                onOpenEvent: () => widget.onOpenEvent(null),
                motionIndex: 3,
              );
            }
            if (widget.isMeetupLoading) {
              return const _NextMeetupLoadingCard(motionIndex: 3);
            }
            return _FindMeetupPrompt(
              onOpenEvent: () => widget.onOpenEvent(null),
              availabilityLabel: browseSummary,
              motionIndex: 3,
            );
          }

          Widget buildMeetupGuidance() {
            final event = widget.selectedEvent!;
            final locationOverride =
                widget.revealedLocationsByEventId[event.id]?.trim();
            final hasRevealedLocation =
                (locationOverride?.isNotEmpty ?? false) ||
                    event.shouldRevealExactAddress;
            return _MeetupGuidanceCard(
              event: event,
              hasRevealedLocation: hasRevealedLocation,
              motionIndex: 4,
            );
          }

          return ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              0,
              MediaQuery.paddingOf(context).top + 12,
              0,
              112,
            ),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShellHeader(
                          unreadCount: widget.unreadNotificationCount,
                          onOpenNotifications: widget.onOpenNotifications,
                          logoSize: 42,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(height: 24),
                        MotionReveal(
                          index: 1,
                          child: Text(
                            '$greeting, $greetingName',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MotionReveal(
                          index: 2,
                          child: Text(
                            widget.selectedEvent == null
                                ? widget.isMeetupLoading
                                    ? 'Getting your next\nmeetup ready.'
                                    : 'A simple way to\nmeet new people.'
                                : _isSameCalendarDay(
                                    widget.selectedEvent!.startsAt,
                                    DateTime.now(),
                                  )
                                    ? 'Your meetup is today'
                                    : 'Your next meetup',
                            style: responsiveDisplayStyle(context),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (wideHome)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: buildPrimaryMeetup()),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 5,
                                child: buildMeetupGuidance(),
                              ),
                            ],
                          )
                        else ...[
                          buildPrimaryMeetup(),
                          if (widget.selectedEvent != null) ...[
                            const SizedBox(height: 18),
                            buildMeetupGuidance(),
                          ],
                        ],
                        if (widget.selectedEvent != null &&
                            browseEvents.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _BrowseMoreMeetupsCard(
                            summary: browseSummary,
                            onTap: () => widget.onOpenEvent(null),
                            motionIndex: 5,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  String _displayName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}

class _NextMeetupReminder extends StatelessWidget {
  const _NextMeetupReminder({
    required this.event,
    this.revealedLocationLabel,
    required this.hasRevealedLocation,
    required this.onOpenEvent,
    required this.motionIndex,
  });

  final MeetupEvent event;
  final String? revealedLocationLabel;
  final bool hasRevealedLocation;
  final VoidCallback onOpenEvent;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameCalendarDay(event.startsAt, DateTime.now());
    final locationLabel = hasRevealedLocation
        ? (revealedLocationLabel ?? event.locationDetailLabel)
        : '${event.areaLabel}, ${event.city}';

    return MotionReveal(
      index: motionIndex,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26150806),
              blurRadius: 26,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFFFFFCF7).withValues(alpha: 0.94),
                  const Color(0xFFFFFCF7).withValues(alpha: 0.76),
                  const Color(0xFFFFFCF7).withValues(alpha: 0.32),
                ],
                stops: const [0, 0.58, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InsightChip(
                    label: isToday
                        ? hasRevealedLocation
                            ? 'Today · Address ready'
                            : 'Today · Seat confirmed'
                        : hasRevealedLocation
                            ? 'Address ready'
                            : 'Seat confirmed',
                    dark: false,
                    onGradient: false,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    event.title,
                    style: responsiveHeadlineStyle(
                      context,
                      color: const Color(0xFF062B55),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HeroInfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: event.detailDateLabel,
                  ),
                  const SizedBox(height: 10),
                  _HeroInfoRow(
                    icon: Icons.schedule_outlined,
                    label: event.detailTimeLabel,
                  ),
                  const SizedBox(height: 10),
                  _HeroInfoRow(
                    icon: Icons.location_on_outlined,
                    label: locationLabel,
                  ),
                  const SizedBox(height: 10),
                  _HeroInfoRow(
                    icon: Icons.groups_2_outlined,
                    label: event.groupSizeLabel,
                  ),
                  if (!hasRevealedLocation) ...[
                    const SizedBox(height: 18),
                    _AddressReleaseNotice(event: event),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: hasRevealedLocation
                        ? () => _openDirections(context, locationLabel)
                        : onOpenEvent,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xF7FFFCF7),
                      foregroundColor: const Color(0xFF062B55),
                    ),
                    child: Text(
                      hasRevealedLocation ? 'Open directions' : 'View meetup',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openCalendar(context, event),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      foregroundColor: Colors.white,
                      backgroundColor:
                          const Color(0xFF062B55).withValues(alpha: 0.86),
                      side: const BorderSide(color: Color(0x33062B55)),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Add to calendar'),
                  ),
                  if (hasRevealedLocation) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onOpenEvent,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF062B55),
                        ),
                        child: const Text('View meetup details'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(
    BuildContext context,
    String locationLabel,
  ) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': '$locationLabel, ${event.city}',
      },
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maps did not open. Try again from meetup details.'),
        ),
      );
    }
  }

  Future<void> _openCalendar(
    BuildContext context,
    MeetupEvent event,
  ) async {
    final added = await addMeetupToCalendar(event);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Calendar opened for ${event.title}.'
              : 'Calendar did not open. Try again from your calendar app.',
        ),
      ),
    );
  }
}

class _AddressReleaseNotice extends StatelessWidget {
  const _AddressReleaseNotice({required this.event});

  final MeetupEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDCD7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            color: Color(0xFF138B8A),
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address available in VriendTime on '
                  '${event.addressReleaseDateTimeLabel}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF062B55),
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Open VriendTime after that time to see the exact public venue.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4F6671),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FindMeetupPrompt extends StatelessWidget {
  const _FindMeetupPrompt({
    required this.onOpenEvent,
    required this.availabilityLabel,
    required this.motionIndex,
  });

  final VoidCallback onOpenEvent;
  final String availabilityLabel;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F5),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.event_available_outlined,
              color: Color(0xFF138B8A),
              size: 23,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your first table starts here',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'VriendTime takes care of the plan, so you can simply show up and meet a small group.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF60727A),
            ),
          ),
          const SizedBox(height: 20),
          const _HowItWorksStep(
            number: '1',
            title: 'Choose a time',
            body: 'Pick a relaxed meetup that fits your day.',
          ),
          const SizedBox(height: 14),
          const _HowItWorksStep(
            number: '2',
            title: 'Reserve your place',
            body: 'Your seat is saved in a small group of 4 to 6 people.',
          ),
          const SizedBox(height: 14),
          const _HowItWorksStep(
            number: '3',
            title: 'Meet your table',
            body:
                'Your reservation shows the exact address-release date and time.',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.near_me_outlined,
                  color: Color(0xFFC4683C),
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    availabilityLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF5D4034),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenEvent,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Find a meetup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF062B55),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF60727A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextMeetupLoadingCard extends StatelessWidget {
  const _NextMeetupLoadingCard({required this.motionIndex});

  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    return MotionReveal(
      index: motionIndex,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFDDE7E3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F150806),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InsightChip(label: 'Loading your meetup'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loading your meetup',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We’re getting the latest details for your reservation.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF60727A),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FractionallySizedBox(
              widthFactor: 0.76,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: 0.56,
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: _LoadingLine()),
                SizedBox(width: 10),
                Expanded(child: _LoadingLine()),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: _LoadingLine()),
                SizedBox(width: 10),
                Expanded(child: _LoadingLine()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MeetupGuidanceCard extends StatelessWidget {
  const _MeetupGuidanceCard({
    required this.event,
    required this.hasRevealedLocation,
    required this.motionIndex,
  });

  final MeetupEvent event;
  final bool hasRevealedLocation;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _isSameCalendarDay(event.startsAt, DateTime.now());

    return SectionCard(
      motionIndex: motionIndex,
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasRevealedLocation
                ? isToday
                    ? 'For today'
                    : 'Before you go'
                : 'What happens next',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            hasRevealedLocation
                ? 'Everything you need for a relaxed arrival.'
                : 'Your reservation is confirmed. We’ll keep the rest simple.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF60727A),
            ),
          ),
          const SizedBox(height: 20),
          if (!hasRevealedLocation) ...[
            const _GuidanceStep(
              icon: Icons.check_rounded,
              title: 'Seat confirmed',
              body: 'Your place at the table is saved.',
              complete: true,
            ),
            const _GuidanceDivider(),
            _GuidanceStep(
              icon: Icons.lock_clock_outlined,
              title: 'Address available in VriendTime',
              body: event.addressReleaseDateTimeLabel,
            ),
            const _GuidanceDivider(),
            _GuidanceStep(
              icon: Icons.groups_2_outlined,
              title: 'Meet your table',
              body:
                  '${event.detailDateLabel} at ${_formatHomeTime(event.startsAt)}',
            ),
          ] else ...[
            _GuidanceStep(
              icon: Icons.route_outlined,
              title: 'Plan your journey',
              body: 'Use Open directions and check your travel time.',
              complete: true,
            ),
            const _GuidanceDivider(),
            _GuidanceStep(
              icon: Icons.schedule_outlined,
              title: 'Arrive a little early',
              body: 'Aim for ${_arrivalTimeLabel(event)} so you can settle in.',
            ),
            const _GuidanceDivider(),
            const _GuidanceStep(
              icon: Icons.phonelink_erase_outlined,
              title: 'Come as you are',
              body:
                  'We keep the table phone-free so conversation comes easier.',
            ),
          ],
        ],
      ),
    );
  }
}

class _GuidanceStep extends StatelessWidget {
  const _GuidanceStep({
    required this.icon,
    required this.title,
    required this.body,
    this.complete = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: complete ? const Color(0xFF138B8A) : const Color(0xFFEAF7F5),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 19,
            color: complete ? Colors.white : const Color(0xFF138B8A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF60727A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidanceDivider extends StatelessWidget {
  const _GuidanceDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
      color: const Color(0xFFD1E5E1),
    );
  }
}

class _BrowseMoreMeetupsCard extends StatelessWidget {
  const _BrowseMoreMeetupsCard({
    required this.summary,
    required this.onTap,
    required this.motionIndex,
  });

  final String summary;
  final VoidCallback onTap;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MotionReveal(
      index: motionIndex,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xF5FFFCF7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDDE7E3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F150806),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Semantics(
                  image: true,
                  label: 'An open cafe table ready for another meetup',
                  child: ExcludeSemantics(
                    child: Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6EA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD9BD)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          GeneratedImageAssets.browseMoreMeetups,
                          fit: BoxFit.cover,
                          cacheWidth: 180,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Browse more meetups',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF60727A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF138B8A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({
    required this.label,
    this.dark = false,
    this.onGradient = false,
  });

  final String label;
  final bool dark;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? (onGradient
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFF062B55))
            : (onGradient
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFEAF7F5)),
        borderRadius: BorderRadius.circular(999),
        border: onGradient
            ? Border.all(color: Colors.white.withValues(alpha: 0.16))
            : dark
                ? null
                : Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: onGradient
                  ? Colors.white
                  : dark
                      ? Colors.white
                      : const Color(0xFF138B8A),
            ),
      ),
    );
  }
}

class _HeroInfoRow extends StatelessWidget {
  const _HeroInfoRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF062B55)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF062B55),
                  height: 1.2,
                ),
          ),
        ),
      ],
    );
  }
}

String _browseSummary({
  required List<MeetupEvent> events,
  required List<MeetupEvent> allEvents,
  required String? preferredCity,
  required bool isUsingOtherCities,
}) {
  if (events.isEmpty) return 'New meetups are added regularly';
  if (isUsingOtherCities) return 'Meetups in other cities';

  final count = events.length;
  final meetupLabel = count == 1 ? 'meetup' : 'meetups';
  final city = preferredCity?.trim();
  if (city != null && city.isNotEmpty) {
    return '$count $meetupLabel available in $city';
  }

  if (allEvents.isNotEmpty) {
    return '$count $meetupLabel ready to explore';
  }
  return 'New meetups are added regularly';
}

String _arrivalTimeLabel(MeetupEvent event) {
  return _formatHomeTime(
    event.startsAt.subtract(const Duration(minutes: 10)),
  );
}

bool _isSameCalendarDay(DateTime first, DateTime second) {
  final localFirst = first.toLocal();
  final localSecond = second.toLocal();
  return localFirst.year == localSecond.year &&
      localFirst.month == localSecond.month &&
      localFirst.day == localSecond.day;
}

String _formatHomeTime(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}
