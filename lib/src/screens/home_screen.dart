import 'package:flutter/material.dart';

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
    final showingOtherCities = widget.selectedEvent == null &&
        cityLabel != null &&
        cityLabel.isNotEmpty &&
        allBrowseEvents.isNotEmpty &&
        sameCityEvents.isEmpty;
    final upcomingTitle = widget.selectedEvent == null
        ? showingOtherCities
            ? 'Meetups in other cities'
            : cityLabel != null && cityLabel.isNotEmpty
                ? 'Coming up in $cityLabel'
                : 'Coming up near you'
        : 'More meetups you might like';
    return ContinuousImmersiveScene(
      assetName: GeneratedImageAssets.homeContinuousScene,
      semanticLabel: 'A warm cafe prepared for people to meet',
      alignment: Alignment.topRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontal = responsiveHorizontalPadding(width);
          final maxWidth = responsiveContentMaxWidth(width);
          final wideHome = isWideContentWidth(width) && browseEvents.isNotEmpty;
          Widget buildPrimaryMeetup() {
            if (widget.selectedEvent != null) {
              return _NextMeetupReminder(
                event: widget.selectedEvent!,
                revealedLocationLabel:
                    widget.revealedLocationsByEventId[widget.selectedEvent!.id],
                onOpenEvent: () => widget.onOpenEvent(null),
                motionIndex: 3,
              );
            }
            if (widget.isMeetupLoading) {
              return const _NextMeetupLoadingCard(motionIndex: 3);
            }
            return _FindMeetupPrompt(
              onOpenEvent: () => widget.onOpenEvent(null),
              motionIndex: 3,
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
                            widget.selectedEvent == null &&
                                    !widget.isMeetupLoading
                                ? 'Find a meetup\nthat fits your day.'
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
                                child: _UpcomingMeetupsCard(
                                  motionIndex: 4,
                                  title: upcomingTitle,
                                  events: browseEvents,
                                  onOpenAll: () => widget.onOpenEvent(null),
                                  onOpenEvent: widget.onOpenEvent,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          buildPrimaryMeetup(),
                          if (browseEvents.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _UpcomingMeetupsCard(
                              motionIndex: 4,
                              title: upcomingTitle,
                              events: browseEvents,
                              onOpenAll: () => widget.onOpenEvent(null),
                              onOpenEvent: widget.onOpenEvent,
                            ),
                          ],
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
    required this.onOpenEvent,
    required this.motionIndex,
  });

  final MeetupEvent event;
  final String? revealedLocationLabel;
  final VoidCallback onOpenEvent;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
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
                  const _InsightChip(
                    label: 'Upcoming',
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
                    label: revealedLocationLabel ?? event.locationDetailLabel,
                  ),
                  const SizedBox(height: 10),
                  _HeroInfoRow(
                    icon: Icons.groups_2_outlined,
                    label: event.groupSizeLabel,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onOpenEvent,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xF7FFFCF7),
                      foregroundColor: const Color(0xFF062B55),
                    ),
                    child: const Text('View meetup'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

class _FindMeetupPrompt extends StatelessWidget {
  const _FindMeetupPrompt({
    required this.onOpenEvent,
    required this.motionIndex,
  });

  final VoidCallback onOpenEvent;
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
            'Small groups, real plans',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Browse relaxed meetups in welcoming public places near you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF60727A),
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

class _UpcomingMeetupsCard extends StatelessWidget {
  const _UpcomingMeetupsCard({
    required this.motionIndex,
    required this.title,
    required this.events,
    required this.onOpenAll,
    required this.onOpenEvent,
  });

  final int motionIndex;
  final String title;
  final List<MeetupEvent> events;
  final VoidCallback onOpenAll;
  final ValueChanged<MeetupEvent?> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF138B8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final event in events) ...[
            _SavedMeetupRow(
              event: event,
              onTap: () => onOpenEvent(event),
            ),
            if (event != events.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SavedMeetupRow extends StatelessWidget {
  const _SavedMeetupRow({
    required this.event,
    required this.onTap,
  });

  final MeetupEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final leading = ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: compact ? 56 : 62,
            height: compact ? 56 : 62,
            child: MeetupArtwork(
              event: event,
              height: compact ? 56 : 62,
              radius: 18,
              preferFullBleed: true,
            ),
          ),
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              event.subtitle,
              maxLines: compact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        );
        final dateCopy = Text(
          '${_shortDateLabel(event)} | ${_startTimeLabel(event)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: const Color(0xFF4F6671),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: EdgeInsets.all(compact ? 14 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDDE7E3)),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(child: copy),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        color: const Color(0xFFDDE7E3),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: Color(0xFF60727A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: dateCopy),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF60727A),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(child: copy),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 56,
                        color: const Color(0xFFDDE7E3),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 132),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: dateCopy,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
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

String _shortDateLabel(MeetupEvent event) {
  return '${event.startsAt.day} ${_monthShortLabel(event.startsAt.month)}';
}

String _startTimeLabel(MeetupEvent event) {
  return _formatHomeTime(event.startsAt);
}

String _monthShortLabel(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[(month - 1).clamp(0, 11)];
}

String _formatHomeTime(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}
