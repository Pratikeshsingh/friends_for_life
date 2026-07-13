import 'package:flutter/material.dart';

import '../core/event_catalog.dart';
import '../widgets/brand_logo.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onStart,
    this.onSignIn,
    this.availableEvents = const <MeetupEvent>[],
    this.isLoadingMeetups = false,
    this.hasEventLoadError = false,
    this.onRetryMeetups,
  });

  final VoidCallback onStart;
  final VoidCallback? onSignIn;
  final List<MeetupEvent> availableEvents;
  final bool isLoadingMeetups;
  final bool hasEventLoadError;
  final VoidCallback? onRetryMeetups;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isNavigating = false;

  void _handleStart() {
    if (_isNavigating) return;
    _isNavigating = true;
    widget.onStart();
  }

  void _handleSignIn() {
    if (_isNavigating) return;
    _isNavigating = true;
    (widget.onSignIn ?? widget.onStart).call();
  }

  Future<void> _openExplorer([MeetupEvent? focusedEvent]) async {
    if (widget.availableEvents.isEmpty) {
      _handleStart();
      return;
    }

    final wantsToJoin = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PublicMeetupExplorer(
        events: widget.availableEvents,
        focusedEvent: focusedEvent,
        onSignIn: () {
          Navigator.of(context).pop();
          _handleSignIn();
        },
      ),
    );

    if (wantsToJoin == true && mounted) {
      _handleStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final heroHeight = compact
        ? 560.0 + ((textScale - 1).clamp(0, 1) * 150)
        : 610.0 + ((textScale - 1).clamp(0, 1) * 90);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFAF4), Color(0xFFF4EEE7)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _ImmersiveLaunchHero(
                height: heroHeight,
                compact: compact,
              ),
              Transform.translate(
                offset: Offset(0, compact ? -52 : -64),
                child: _MeetupProofPanel(
                  events: widget.availableEvents,
                  isLoading: widget.isLoadingMeetups,
                  hasLoadError: widget.hasEventLoadError,
                  onRetry: widget.onRetryMeetups,
                  onExplore: () => _openExplorer(),
                  onOpenEvent: _openExplorer,
                  onCreateAccount: _handleStart,
                  onSignIn: _handleSignIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImmersiveLaunchHero extends StatelessWidget {
  const _ImmersiveLaunchHero({
    required this.height,
    required this.compact,
  });

  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final imageAsset = compact
        ? GeneratedImageAssets.landingImmersiveMobile
        : GeneratedImageAssets.landingImmersiveDesktop;
    final contentWidth = compact ? width : 1180.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            alignment: compact ? Alignment.topCenter : Alignment.center,
            cacheWidth: compact ? 1000 : 1800,
            semanticLabel:
                'Four people sharing coffee and a meal around a cafe table',
            errorBuilder: (context, error, stackTrace) => Image.asset(
              GeneratedImageAssets.launchTableMeetup,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x18FFF9F1),
                    Color(0x00FFF9F1),
                    Color(0x10062B55),
                  ],
                  stops: [0, 0.62, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 20 : 40,
                    compact ? 14 : 24,
                    compact ? 20 : 40,
                    0,
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.35,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MotionReveal(
                          index: 0,
                          child: BrandLockup(
                            logoSize: compact ? 31 : 36,
                            foregroundColor: const Color(0xFF062B55),
                          ),
                        ),
                        SizedBox(height: compact ? 30 : 54),
                        MotionReveal(
                          index: 1,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compact ? 520 : 540,
                            ),
                            child: Text(
                              'Meet people\nover a real table.',
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontSize:
                                    compact ? (width < 350 ? 40 : 46) : 58,
                                height: 0.98,
                                letterSpacing: -1.4,
                                color: const Color(0xFF062B55),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        MotionReveal(
                          index: 2,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compact ? 430 : 480,
                            ),
                            child: Text(
                              'Small coffee, lunch, and dinner meetups near you.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: compact ? 16 : 18,
                                height: 1.45,
                                color: const Color(0xFF526771),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetupProofPanel extends StatelessWidget {
  const _MeetupProofPanel({
    required this.events,
    required this.isLoading,
    required this.hasLoadError,
    required this.onRetry,
    required this.onExplore,
    required this.onOpenEvent,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final List<MeetupEvent> events;
  final bool isLoading;
  final bool hasLoadError;
  final VoidCallback? onRetry;
  final VoidCallback onExplore;
  final ValueChanged<MeetupEvent> onOpenEvent;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final previewEvents = events.take(5).toList(growable: false);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: compact ? 0 : 28),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            compact ? 26 : 30,
            compact ? 16 : 28,
            22,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: compact
                ? const BorderRadius.vertical(top: Radius.circular(32))
                : BorderRadius.circular(34),
            border: compact ? null : Border.all(color: const Color(0xFFE5E8E2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22062B55),
                blurRadius: 36,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      previewEvents.isEmpty
                          ? 'The kinds of meetups you’ll find'
                          : 'Upcoming meetups',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF062B55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (previewEvents.length > 3)
                    TextButton(
                      onPressed: onExplore,
                      child: const Text('See all'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (isLoading && previewEvents.isEmpty)
                const _MeetupPreviewLoading()
              else if (hasLoadError && previewEvents.isEmpty)
                _MeetupPreviewFallback(
                  message: 'Meetup times are taking a moment to load.',
                  onRetry: onRetry,
                )
              else if (previewEvents.isEmpty)
                const _TypicalMeetupStrip()
              else
                SizedBox(
                  height: compact ? 190 : 226,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: previewEvents.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final event = previewEvents[index];
                      return _PublicMeetupCard(
                        event: event,
                        width: compact ? 170 : 210,
                        onTap: () => onOpenEvent(event),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCreateAccount,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    previewEvents.isEmpty
                        ? 'Create my account'
                        : 'Create an account',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    backgroundColor: const Color(0xFF138B8A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: onSignIn,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF138B8A),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('I already have an account'),
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 6,
                  children: const [
                    _TrustNote(
                      icon: Icons.groups_2_outlined,
                      label: 'Small groups',
                    ),
                    _TrustNote(
                      icon: Icons.storefront_outlined,
                      label: 'Public places',
                    ),
                    _TrustNote(
                      icon: Icons.swipe_left_outlined,
                      label: 'No swiping',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetupPreviewLoading extends StatelessWidget {
  const _MeetupPreviewLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212,
      child: Row(
        children: [
          for (var index = 0; index < 2; index++) ...[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3EF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
            if (index == 0) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _MeetupPreviewFallback extends StatelessWidget {
  const _MeetupPreviewFallback({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypicalMeetupStrip(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ],
    );
  }
}

class _TypicalMeetupStrip extends StatelessWidget {
  const _TypicalMeetupStrip();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    const meetups = <(String, String, String)>[
      ('Coffee', 'Casual & relaxed', GeneratedImageAssets.homeHeroCoffee),
      ('Lunch', 'Good food, good talk', GeneratedImageAssets.homeHeroLunch),
      ('Dinner', 'Evenings together', GeneratedImageAssets.homeHeroDinner),
    ];

    return SizedBox(
      height: compact ? 190 : 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: meetups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final meetup = meetups[index];
          return _TypicalMeetupCard(
            title: meetup.$1,
            subtitle: meetup.$2,
            assetName: meetup.$3,
            width: compact ? 150 : 190,
          );
        },
      ),
    );
  }
}

class _TypicalMeetupCard extends StatelessWidget {
  const _TypicalMeetupCard({
    required this.title,
    required this.subtitle,
    required this.assetName,
    required this.width,
  });

  final String title;
  final String subtitle;
  final String assetName;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Image.asset(
              assetName,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 500,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF65767C),
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

class _PublicMeetupCard extends StatelessWidget {
  const _PublicMeetupCard({
    required this.event,
    required this.width,
    required this.onTap,
  });

  final MeetupEvent event;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availability = _publicAvailabilityLabel(event);

    return Semantics(
      button: true,
      label:
          '${event.title}, ${event.dateLabel}, ${event.city}, $availability. Open meetup details.',
      child: MotionPressable(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: width,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE1E7E3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            GeneratedImageAssets.compactCardForEvent(event),
                            fit: BoxFit.cover,
                            cacheWidth: 600,
                          ),
                          Positioned(
                            top: 9,
                            left: 9,
                            child: _AvailabilityBadge(
                              label: availability,
                              unavailable: !event.isOpenForReservation,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                event.activityLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF062B55),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF60727A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Near ${event.areaLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF728187),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.label, required this.unavailable});

  final String label;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: unavailable ? const Color(0xFFF9E5E0) : const Color(0xFFF0FBF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              unavailable ? const Color(0xFFF0C8BE) : const Color(0xFFBFE6DE),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: unavailable
                    ? const Color(0xFFA44D3E)
                    : const Color(0xFF08736F),
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _TrustNote extends StatelessWidget {
  const _TrustNote({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF668087)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF668087),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _PublicMeetupExplorer extends StatelessWidget {
  const _PublicMeetupExplorer({
    required this.events,
    required this.onSignIn,
    this.focusedEvent,
  });

  final List<MeetupEvent> events;
  final VoidCallback onSignIn;
  final MeetupEvent? focusedEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedEvents = [
      if (focusedEvent != null) focusedEvent!,
      ...events.where((event) => event.id != focusedEvent?.id),
    ];

    return DraggableScrollableSheet(
      initialChildSize: focusedEvent == null ? 0.84 : 0.9,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D8D5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  focusedEvent == null
                                      ? 'Explore upcoming meetups'
                                      : 'Meetup details',
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Browse first. Create an account only when you’re ready to reserve.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF60727A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: onSignIn,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(44, 40),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Already have an account? Sign in',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList.separated(
                  itemCount: orderedEvents.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final event = orderedEvents[index];
                    return _PublicMeetupDetailCard(
                      event: event,
                      highlighted: event.id == focusedEvent?.id,
                      onJoin: event.isOpenForReservation
                          ? () => Navigator.of(context).pop(true)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PublicMeetupDetailCard extends StatelessWidget {
  const _PublicMeetupDetailCard({
    required this.event,
    required this.highlighted,
    required this.onJoin,
  });

  final MeetupEvent event;
  final bool highlighted;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availability = _publicAvailabilityLabel(event);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              highlighted ? const Color(0xFF54BDB2) : const Color(0xFFE0E6E2),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Image.asset(
              GeneratedImageAssets.compactCardForEvent(event),
              fit: BoxFit.cover,
              cacheWidth: 1000,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                          Text(event.title, style: theme.textTheme.titleLarge),
                    ),
                    const SizedBox(width: 10),
                    _AvailabilityBadge(
                      label: availability,
                      unavailable: !event.isOpenForReservation,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526771),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailPill(
                      icon: Icons.calendar_today_outlined,
                      label: event.detailDateLabel,
                    ),
                    _DetailPill(
                      icon: Icons.schedule_outlined,
                      label: event.detailTimeLabel,
                    ),
                    _DetailPill(
                      icon: Icons.location_on_outlined,
                      label: 'Near ${event.areaLabel}, ${event.city}',
                    ),
                    _DetailPill(
                      icon: Icons.groups_2_outlined,
                      label: event.groupSizeLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onJoin,
                    child: Text(
                      event.isOpenForReservation
                          ? 'Create an account to reserve'
                          : availability,
                    ),
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

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF138B8A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF355D64),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _publicAvailabilityLabel(MeetupEvent event) {
  if (event.status == 'cancelled') return 'Cancelled';
  if (event.status == 'closed' || event.hasStarted) return 'Closed';
  if (event.isFull) return 'Full';
  if (event.isAlmostFull) return 'Nearly full';
  return 'Available';
}
