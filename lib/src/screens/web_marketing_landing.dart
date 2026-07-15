import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/event_catalog.dart';
import '../widgets/brand_logo.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';

const _navy = Color(0xFF062B55);
const _teal = Color(0xFF138B8A);
const _canvas = Color(0xFFFFFAF4);
const _surface = Color(0xFFFFFCF8);
const _muted = Color(0xFF5D7078);
const _outline = Color(0xFFDDE7E3);

// Release builds can provide real store destinations with --dart-define.
// Empty values deliberately render as non-clickable "Coming soon" cards.
const _appStoreUrl = String.fromEnvironment('APP_STORE_URL');
const _playStoreUrl = String.fromEnvironment('PLAY_STORE_URL');

class WebMarketingLandingPage extends StatefulWidget {
  const WebMarketingLandingPage({
    super.key,
    required this.availableEvents,
    required this.isLoadingMeetups,
    required this.hasEventLoadError,
    required this.onCreateAccount,
    required this.onSignIn,
    required this.onBrowseMeetups,
    required this.onOpenEvent,
    this.onRetryMeetups,
  });

  final List<MeetupEvent> availableEvents;
  final bool isLoadingMeetups;
  final bool hasEventLoadError;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;
  final VoidCallback onBrowseMeetups;
  final ValueChanged<MeetupEvent> onOpenEvent;
  final VoidCallback? onRetryMeetups;

  @override
  State<WebMarketingLandingPage> createState() =>
      _WebMarketingLandingPageState();
}

class _WebMarketingLandingPageState extends State<WebMarketingLandingPage> {
  final _howItWorksKey = GlobalKey();
  final _safetyKey = GlobalKey();
  final _meetupsKey = GlobalKey();
  final _getAppKey = GlobalKey();

  Future<void> _scrollTo(GlobalKey key) async {
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;
    await Scrollable.ensureVisible(
      sectionContext,
      duration: prefersReducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  Future<void> _openStore(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That store page could not be opened.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _MarketingHero(
                onCreateAccount: widget.onCreateAccount,
                onSignIn: widget.onSignIn,
                onBrowseMeetups: () => _scrollTo(_meetupsKey),
                onHowItWorks: () => _scrollTo(_howItWorksKey),
                onSafety: () => _scrollTo(_safetyKey),
                onGetApp: () => _scrollTo(_getAppKey),
              ),
              _HowItWorksSection(key: _howItWorksKey),
              _SafetySection(key: _safetyKey),
              _MeetupPreviewSection(
                key: _meetupsKey,
                events: widget.availableEvents,
                isLoading: widget.isLoadingMeetups,
                hasLoadError: widget.hasEventLoadError,
                onRetry: widget.onRetryMeetups,
                onBrowseAll: widget.availableEvents.isEmpty
                    ? null
                    : widget.onBrowseMeetups,
                onOpenEvent: widget.onOpenEvent,
                onCreateAccount: widget.onCreateAccount,
              ),
              _DownloadSection(
                key: _getAppKey,
                appStoreUrl: _appStoreUrl,
                playStoreUrl: _playStoreUrl,
                onOpenStore: _openStore,
                onBrowseWeb: widget.availableEvents.isEmpty
                    ? () => _scrollTo(_meetupsKey)
                    : widget.onBrowseMeetups,
              ),
              _ClosingSection(
                onCreateAccount: widget.onCreateAccount,
                onSignIn: widget.onSignIn,
              ),
              const _MarketingFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketingHero extends StatelessWidget {
  const _MarketingHero({
    required this.onCreateAccount,
    required this.onSignIn,
    required this.onBrowseMeetups,
    required this.onHowItWorks,
    required this.onSafety,
    required this.onGetApp,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;
  final VoidCallback onBrowseMeetups;
  final VoidCallback onHowItWorks;
  final VoidCallback onSafety;
  final VoidCallback onGetApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    final showNavigation = width >= 1180;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final heroHeight = compact
        ? 870.0 + ((textScale - 1).clamp(0, 1) * 240)
        : 730.0 + ((textScale - 1).clamp(0, 1) * 150);

    return Container(
      constraints: BoxConstraints(minHeight: heroHeight),
      width: double.infinity,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: Image.asset(
              compact
                  ? GeneratedImageAssets.landingImmersiveMobile
                  : GeneratedImageAssets.landingImmersiveDesktop,
              fit: compact ? BoxFit.fitWidth : BoxFit.cover,
              alignment: compact ? Alignment.bottomCenter : Alignment.center,
              cacheWidth: compact ? 1000 : 2000,
              semanticLabel:
                  'An inviting cafe table with an open coral chair waiting for a guest',
              errorBuilder: (context, error, stackTrace) => Image.asset(
                GeneratedImageAssets.launchTableMeetup,
                fit: compact ? BoxFit.fitWidth : BoxFit.cover,
                alignment: compact ? Alignment.bottomCenter : Alignment.center,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: compact
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xF7FFFAF4),
                          Color(0xF2FFFAF4),
                          Color(0xCFFFFAF4),
                          Color(0x3DFFFAF4),
                          Color(0x2E062B55),
                        ],
                        stops: [0, 0.25, 0.44, 0.66, 1],
                      )
                    : const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFFFAF4),
                          Color(0xF7FFFAF4),
                          Color(0xD9FFFAF4),
                          Color(0x52FFFAF4),
                          Color(0x00FFFAF4),
                        ],
                        stops: [0, 0.24, 0.43, 0.62, 0.78],
                      ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x08FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x26062B55),
                  ],
                  stops: [0, 0.76, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: _PageWidth(
              horizontalPadding: compact ? 18 : 32,
              child: Padding(
                padding: EdgeInsets.only(bottom: compact ? 42 : 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: compact ? 12 : 18),
                    Row(
                      children: [
                        SizedBox(
                          width: compact ? 168 : 188,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: compact ? 178 : 188,
                              child: BrandLockup(
                                logoSize: compact ? 28 : 35,
                                foregroundColor: _navy,
                              ),
                            ),
                          ),
                        ),
                        if (showNavigation) ...[
                          const Spacer(),
                          _HeaderLink(
                            label: 'How it works',
                            onPressed: onHowItWorks,
                          ),
                          _HeaderLink(
                            label: 'Safety',
                            onPressed: onSafety,
                          ),
                          _HeaderLink(
                            label: 'Meetups',
                            onPressed: onBrowseMeetups,
                          ),
                          _HeaderLink(
                            label: 'Get the app',
                            onPressed: onGetApp,
                          ),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: onSignIn,
                          style: TextButton.styleFrom(
                            foregroundColor: _navy,
                            minimumSize: const Size(0, 44),
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 4 : 8,
                            ),
                          ),
                          child: const Text('Sign in'),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onCreateAccount,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 13,
                              ),
                            ),
                            child: const Text('Create account'),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: compact ? 54 : 104),
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.45,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 540 : 610,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MotionReveal(
                              index: 0,
                              child: const _Eyebrow(
                                icon: Icons.table_restaurant_outlined,
                                label: 'Small-group meetups in real life',
                              ),
                            ),
                            const SizedBox(height: 18),
                            MotionReveal(
                              index: 1,
                              child: Semantics(
                                header: true,
                                child: Text(
                                  compact
                                      ? 'Real people.\nOne table.\nNo swiping.'
                                      : 'Real people.\nOne table. No swiping.',
                                  style: theme.textTheme.displayLarge?.copyWith(
                                    fontFamily: 'Newsreader',
                                    fontSize:
                                        compact ? (width < 370 ? 45 : 51) : 72,
                                    height: 0.96,
                                    letterSpacing: -1.6,
                                    color: _navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            MotionReveal(
                              index: 2,
                              child: Text(
                                'VriendTime brings 4–6 people together for coffee, lunch, or dinner in a public venue. Pick a time; we take care of the group and the place.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: compact ? 16 : 18,
                                  height: 1.55,
                                  color: const Color(0xFF3E5B64),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            MotionReveal(
                              index: 3,
                              child: compact
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: onCreateAccount,
                                          iconAlignment: IconAlignment.end,
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                          ),
                                          label:
                                              const Text('Create an account'),
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: onBrowseMeetups,
                                          icon: const Icon(
                                            Icons.calendar_month_outlined,
                                          ),
                                          label: const Text(
                                            'Browse upcoming meetups',
                                          ),
                                        ),
                                      ],
                                    )
                                  : Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: onCreateAccount,
                                          iconAlignment: IconAlignment.end,
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                          ),
                                          label:
                                              const Text('Create an account'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: onBrowseMeetups,
                                          icon: const Icon(
                                            Icons.calendar_month_outlined,
                                          ),
                                          label: const Text('Browse meetups'),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 22),
                            MotionReveal(
                              index: 4,
                              child: const Wrap(
                                spacing: 8,
                                runSpacing: 9,
                                children: [
                                  _HeroTrustNote(
                                    icon: Icons.groups_2_outlined,
                                    label: 'Groups of 4–6',
                                  ),
                                  _HeroTrustNote(
                                    icon: Icons.storefront_outlined,
                                    label: 'Public venues',
                                  ),
                                  _HeroTrustNote(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: 'No group chat needed',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF355762),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDAE8E2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _teal),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTrustNote extends StatelessWidget {
  const _HeroTrustNote({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xBFD7E5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _teal),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF294D58),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      backgroundColor: _canvas,
      child: Column(
        children: [
          const _SectionHeading(
            overline: 'HOW VRIENDTIME WORKS',
            title: 'From “maybe someday” to a real plan.',
            body:
                'There is no matching game and no group chat to manage. Choose the meetup that fits your week and arrive as yourself.',
          ),
          const SizedBox(height: 42),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cardWidth = width >= 900
                  ? (width - 48) / 3
                  : width >= 600
                      ? (width - 24) / 2
                      : width;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: const _StepCard(
                      number: '01',
                      icon: Icons.event_available_outlined,
                      title: 'Choose a time',
                      body:
                          'Browse coffee, lunch, and dinner meetups near you. The group size and neighbourhood are clear upfront.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _StepCard(
                      number: '02',
                      icon: Icons.chair_alt_outlined,
                      title: 'Save your seat',
                      body:
                          'Reserve a place at a table of 4–6 people. We organise the group, so there is nothing else to coordinate.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _StepCard(
                      number: '03',
                      icon: Icons.restaurant_outlined,
                      title: 'Meet at the table',
                      body:
                          'Confirmed guests can find the exact venue in VriendTime before the meetup. Show up, order what you like, and start talking.',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.overline,
    required this.title,
    required this.body,
    this.alignLeft = false,
    this.onDark = false,
  });

  final String overline;
  final String title;
  final String body;
  final bool alignLeft;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment:
              alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              overline,
              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: onDark ? const Color(0xFF81DDD0) : _teal,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: alignLeft ? TextAlign.left : TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFamily: 'Newsreader',
                  fontSize: 45,
                  height: 1.03,
                  letterSpacing: -0.8,
                  color: onDark ? Colors.white : _navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: onDark ? const Color(0xFFD7E6E8) : _muted,
                height: 1.6,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String number;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MotionPressable(
      hoverScale: 1.012,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D062B55),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: _teal, size: 25),
                ),
                const Spacer(),
                Text(
                  number,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFB7C8C6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: _navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _muted,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetySection extends StatelessWidget {
  const _SafetySection({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      backgroundColor: _navy,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 850;
          final image = ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              height: stacked ? 300 : 465,
              width: double.infinity,
              child: Image.asset(
                GeneratedImageAssets.launchTableMeetup,
                fit: BoxFit.cover,
                cacheWidth: 1200,
                semanticLabel:
                    'A small group talking together at a bright public cafe',
              ),
            ),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                overline: 'A COMFORTABLE WAY TO SHOW UP',
                title: 'Enough structure to make meeting feel easy.',
                body:
                    'VriendTime removes the uncertain parts without scripting the conversation. You know the plan, the group size, and what happens next.',
                alignLeft: true,
                onDark: true,
              ),
              const SizedBox(height: 30),
              const _SafetyPoint(
                icon: Icons.storefront_outlined,
                title: 'Public places',
                body: 'Meetups take place at cafes and restaurants.',
              ),
              const SizedBox(height: 18),
              const _SafetyPoint(
                icon: Icons.groups_2_outlined,
                title: 'Small by design',
                body: 'Groups stay small enough for everyone to take part.',
              ),
              const SizedBox(height: 18),
              const _SafetyPoint(
                icon: Icons.location_on_outlined,
                title: 'Details shared thoughtfully',
                body:
                    'The neighbourhood is visible while browsing; the exact venue is for confirmed attendees.',
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 38), image],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: content),
              const SizedBox(width: 64),
              Expanded(child: image),
            ],
          );
        },
      ),
    );
  }
}

class _SafetyPoint extends StatelessWidget {
  const _SafetyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF123F65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF81DDD0)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFC9DADD),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeetupPreviewSection extends StatelessWidget {
  const _MeetupPreviewSection({
    super.key,
    required this.events,
    required this.isLoading,
    required this.hasLoadError,
    required this.onOpenEvent,
    required this.onCreateAccount,
    this.onRetry,
    this.onBrowseAll,
  });

  final List<MeetupEvent> events;
  final bool isLoading;
  final bool hasLoadError;
  final VoidCallback? onRetry;
  final VoidCallback? onBrowseAll;
  final ValueChanged<MeetupEvent> onOpenEvent;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final previewEvents = events.take(3).toList(growable: false);
    return _SectionShell(
      backgroundColor: const Color(0xFFF3EEE6),
      child: Column(
        children: [
          _SectionHeading(
            overline: 'UPCOMING MEETUPS',
            title: 'A plan you can actually put in your calendar.',
            body: previewEvents.isEmpty
                ? 'Coffee, lunch, and dinner meetups are added as tables become available.'
                : 'See the date, time, neighbourhood, and group size before you create an account.',
          ),
          const SizedBox(height: 38),
          if (isLoading && previewEvents.isEmpty)
            const _MeetupLoadingPanel()
          else if (hasLoadError && previewEvents.isEmpty)
            _MeetupStatusPanel(
              icon: Icons.cloud_off_outlined,
              title: 'Meetup times are taking a moment to load',
              body:
                  'You can still learn how VriendTime works or try loading the schedule again.',
              actionLabel: onRetry == null ? null : 'Try again',
              onAction: onRetry,
            )
          else if (previewEvents.isEmpty)
            const _TypicalWebMeetups()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth = width >= 980
                    ? (width - 48) / 3
                    : width >= 620
                        ? (width - 22) / 2
                        : width;
                return Wrap(
                  spacing: width >= 980 ? 24 : 22,
                  runSpacing: 22,
                  children: [
                    for (final event in previewEvents)
                      SizedBox(
                        width: cardWidth,
                        child: _WebMeetupCard(
                          event: event,
                          onTap: () => onOpenEvent(event),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              if (onBrowseAll != null)
                OutlinedButton.icon(
                  onPressed: onBrowseAll,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('See all meetups'),
                ),
              ElevatedButton.icon(
                onPressed: onCreateAccount,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Create an account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeetupLoadingPanel extends StatelessWidget {
  const _MeetupLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading upcoming meetups',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 72),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _outline),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MeetupStatusPanel extends StatelessWidget {
  const _MeetupStatusPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: _teal),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: _navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _muted,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _TypicalWebMeetups extends StatelessWidget {
  const _TypicalWebMeetups();

  @override
  Widget build(BuildContext context) {
    const meetups = <(String, String, String)>[
      (
        'Coffee',
        'An easy hour around a small table',
        GeneratedImageAssets.homeHeroCoffee
      ),
      (
        'Lunch',
        'A proper pause with new people',
        GeneratedImageAssets.homeHeroLunch
      ),
      (
        'Dinner',
        'A relaxed evening, already planned',
        GeneratedImageAssets.homeHeroDinner
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width >= 900
            ? (width - 48) / 3
            : width >= 600
                ? (width - 22) / 2
                : width;
        return Wrap(
          spacing: width >= 900 ? 24 : 22,
          runSpacing: 22,
          children: [
            for (final meetup in meetups)
              SizedBox(
                width: cardWidth,
                child: _TypicalWebMeetupCard(
                  title: meetup.$1,
                  body: meetup.$2,
                  assetName: meetup.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TypicalWebMeetupCard extends StatelessWidget {
  const _TypicalWebMeetupCard({
    required this.title,
    required this.body,
    required this.assetName,
  });

  final String title;
  final String body;
  final String assetName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 184,
            width: double.infinity,
            child: Image.asset(assetName, fit: BoxFit.cover, cacheWidth: 800),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: _muted),
                ),
                const SizedBox(height: 14),
                Text(
                  'New dates coming soon',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _teal,
                    fontWeight: FontWeight.w800,
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

class _WebMeetupCard extends StatelessWidget {
  const _WebMeetupCard({required this.event, required this.onTap});

  final MeetupEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availability = _availabilityLabel(event);
    return Semantics(
      button: true,
      label:
          '${event.title}, ${event.dateLabel}, ${event.city}, $availability. Open details.',
      child: MotionPressable(
        hoverScale: 1.01,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _outline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: 190,
                          width: double.infinity,
                          child: Image.asset(
                            GeneratedImageAssets.compactCardForEvent(event),
                            fit: BoxFit.cover,
                            cacheWidth: 900,
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 14,
                          child: _AvailabilityPill(
                            label: availability,
                            unavailable: !event.isOpenForReservation,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MeetupMeta(
                            icon: Icons.calendar_today_outlined,
                            label: event.dateLabel,
                          ),
                          const SizedBox(height: 8),
                          _MeetupMeta(
                            icon: Icons.location_on_outlined,
                            label: 'Near ${event.areaLabel}, ${event.city}',
                          ),
                          const SizedBox(height: 8),
                          _MeetupMeta(
                            icon: Icons.groups_2_outlined,
                            label: event.groupSizeLabel,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                'View meetup',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _teal,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: _teal,
                              ),
                            ],
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

class _MeetupMeta extends StatelessWidget {
  const _MeetupMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: _teal),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _muted,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.label,
    required this.unavailable,
  });

  final String label;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: unavailable ? const Color(0xFFF9E5E0) : const Color(0xFFF0FBF8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              unavailable ? const Color(0xFFF0C8BE) : const Color(0xFFBFE6DE),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: unavailable
                  ? const Color(0xFFA44D3E)
                  : const Color(0xFF08736F),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DownloadSection extends StatelessWidget {
  const _DownloadSection({
    super.key,
    required this.appStoreUrl,
    required this.playStoreUrl,
    required this.onOpenStore,
    required this.onBrowseWeb,
  });

  final String appStoreUrl;
  final String playStoreUrl;
  final ValueChanged<String> onOpenStore;
  final VoidCallback onBrowseWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAppStore = appStoreUrl.trim().isNotEmpty;
    final hasPlayStore = playStoreUrl.trim().isNotEmpty;
    return _SectionShell(
      backgroundColor: _canvas,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFA486), Color(0xFF59C7BA)],
          ),
          borderRadius: BorderRadius.circular(34),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 52),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6EB),
            borderRadius: BorderRadius.circular(33),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 800;
              final art = const _DownloadArtwork();
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VRIENDTIME, WHEREVER YOU ARE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _teal,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      hasAppStore || hasPlayStore
                          ? 'Take your next meetup with you.'
                          : 'The apps are on the way.',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontFamily: 'Newsreader',
                        color: _navy,
                        fontSize: 44,
                        height: 1.03,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasAppStore || hasPlayStore
                        ? 'Keep your meetup details close and get timely updates from VriendTime.'
                        : 'We are preparing VriendTime for iPhone and Android. Until then, you can browse meetups and create your account on the web.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: _muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StoreAvailabilityCard(
                        icon: Icons.apple,
                        storeName: 'App Store',
                        available: hasAppStore,
                        onTap:
                            hasAppStore ? () => onOpenStore(appStoreUrl) : null,
                      ),
                      _StoreAvailabilityCard(
                        icon: Icons.play_arrow_rounded,
                        storeName: 'Google Play',
                        available: hasPlayStore,
                        onTap: hasPlayStore
                            ? () => onOpenStore(playStoreUrl)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextButton.icon(
                    onPressed: onBrowseWeb,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Browse on the web'),
                  ),
                ],
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content, const SizedBox(height: 30), art],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 6, child: content),
                  const SizedBox(width: 54),
                  Expanded(flex: 4, child: art),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoreAvailabilityCard extends StatelessWidget {
  const _StoreAvailabilityCard({
    required this.icon,
    required this.storeName,
    required this.available,
    this.onTap,
  });

  final IconData icon;
  final String storeName;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      constraints: const BoxConstraints(minWidth: 184),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: available ? _navy : const Color(0xFFF1EAE0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available ? _navy : const Color(0xFFD8D0C5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 27,
            color: available ? Colors.white : const Color(0xFF65747A),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available ? 'Download on the' : 'Coming soon on',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: available ? Colors.white70 : _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  storeName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: available ? Colors.white : _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: available,
      enabled: available,
      label: available
          ? 'Download VriendTime on the $storeName'
          : 'VriendTime on the $storeName, coming soon',
      child: onTap == null
          ? content
          : MotionPressable(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _DownloadArtwork extends StatelessWidget {
  const _DownloadArtwork();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'VriendTime app symbol',
      child: AspectRatio(
        aspectRatio: 1.15,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDDCC),
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(46, -30),
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8F2EB),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 170,
              height: 190,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22062B55),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: const BrandLogoMark(size: 112),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingSection extends StatelessWidget {
  const _ClosingSection({
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionShell(
      backgroundColor: _teal,
      verticalPadding: 76,
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              'Your next table is closer than you think.',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontFamily: 'Newsreader',
                color: Colors.white,
                fontSize: 46,
                height: 1.04,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Choose a meetup that fits your week. We will make the rest clear.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFE7FBF8),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onCreateAccount,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Create an account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _navy,
                ),
              ),
              TextButton(
                onPressed: onSignIn,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x99FFFFFF)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                ),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketingFooter extends StatelessWidget {
  const _MarketingFooter();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return ColoredBox(
      color: const Color(0xFF041F3C),
      child: _PageWidth(
        horizontalPadding: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: compact
              ? Column(
                  children: [
                    const BrandLockup(
                      logoSize: 30,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    _footerText(context),
                  ],
                )
              : Row(
                  children: [
                    const SizedBox(
                      width: 180,
                      child: BrandLockup(
                        logoSize: 30,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: _footerText(context)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _footerText(BuildContext context) {
    return Text(
      '© ${DateTime.now().year} VriendTime · Made for real-world connection',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFBFD1D6),
          ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.backgroundColor,
    required this.child,
    this.verticalPadding = 104,
  });

  final Color backgroundColor;
  final Widget child;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    return ColoredBox(
      color: backgroundColor,
      child: _PageWidth(
        horizontalPadding: compact ? 18 : 32,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? verticalPadding * 0.68 : verticalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({
    required this.child,
    required this.horizontalPadding,
  });

  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

String _availabilityLabel(MeetupEvent event) {
  if (event.status == 'cancelled') return 'Cancelled';
  if (event.status == 'closed' || event.hasStarted) return 'Closed';
  if (event.isFull) return 'Full';
  if (event.isAlmostFull) return 'Nearly full';
  return 'Available';
}
