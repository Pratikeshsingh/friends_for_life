import 'package:flutter/material.dart';

import '../core/event_catalog.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/editorial_sections.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/section_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isStarting = false;

  void _handleStart() {
    if (_isStarting) return;
    _isStarting = true;
    widget.onStart();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFCF7),
              Color(0xFFEAF7F5),
              Color(0xFFF7ECE4),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontal = responsiveHorizontalPadding(width);
              final maxWidth = responsiveContentMaxWidth(width);

              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: MotionReveal(
                        index: 0,
                        child: MotionParallax(
                          scrollController: _scrollController,
                          speed: 0.16,
                          maxShift: 34,
                          child: SizedBox(
                            width: double.infinity,
                            child: _WelcomeHero(theme: theme),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontal),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MotionReveal(
                                  index: 1,
                                  child: Text(
                                    'Make friends the old-fashioned way.',
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      color: const Color(0xFF062B55),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const MotionReveal(
                                  index: 2,
                                  child: Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _InfoChip(
                                        icon: Icons.groups_2_outlined,
                                        label: '4 to 8 people',
                                      ),
                                      _InfoChip(
                                        icon: Icons.table_restaurant_outlined,
                                        label: 'One cozy table',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                MotionReveal(
                                  index: 3,
                                  child: EditorialResponsiveWrap(
                                    minChildWidth: 180,
                                    maxColumns: 3,
                                    children: [
                                      _OnboardingSceneCard(
                                        event: recommendedMeetupEvents.first,
                                        eyebrow: 'Noon',
                                        title: 'Weekend lunch',
                                        onTap: _handleStart,
                                      ),
                                      _OnboardingSceneCard(
                                        event: recommendedMeetupEvents.last,
                                        eyebrow: 'Evening',
                                        title: 'Gezellig dinner',
                                        onTap: _handleStart,
                                      ),
                                      _OnboardingSceneCard(
                                        event: moreMeetupEvents.first,
                                        eyebrow: 'Morning',
                                        title: 'No rush coffee',
                                        onTap: _handleStart,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                MotionReveal(
                                  index: 4,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _handleStart,
                                      child: const Text('Get started'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SectionCard(
                                  highlight: true,
                                  motionIndex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      EditorialSectionHeader(
                                        eyebrow: '',
                                        title: "Here's exactly what happens.",
                                      ),
                                      SizedBox(height: 18),
                                      EditorialTimelineStep(
                                        step: 1,
                                        icon: Icons.person_outline,
                                        title: 'Create your profile',
                                        body:
                                            'Add your name, photo, and a few basics.',
                                      ),
                                      SizedBox(height: 14),
                                      EditorialTimelineStep(
                                        step: 2,
                                        icon: Icons.event_available_outlined,
                                        title: 'Choose a meetup',
                                        body:
                                            "Pick a meetup that fits your schedule. You'll see the time and area before committing.",
                                      ),
                                      SizedBox(height: 14),
                                      EditorialTimelineStep(
                                        step: 3,
                                        icon: Icons.phone_disabled_outlined,
                                        title: 'Be present',
                                        body:
                                            "Phones stay in your pocket. That's the one ask. It helps everyone settle in.",
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = isCompactWidth(constraints.maxWidth);

        return compact
            ? _buildCompactHero(context, constraints.maxWidth)
            : _buildWideHero(context, constraints.maxWidth);
      },
    );
  }

  Widget _buildWideHero(BuildContext context, double width) {
    return Container(
      width: double.infinity,
      height: 360,
      decoration: _heroDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            const Positioned.fill(child: _HeroImageLayer()),
            Positioned(
              top: 26,
              left: 24,
              child: const _HeroTag(
                label: 'Small groups',
                backgroundColor: Color(0xFFEAF7F5),
                foregroundColor: Color(0xFF062B55),
              ),
            ),
            Positioned(
              top: 26,
              right: 24,
              child: const _HeroTag(
                label: 'No swiping',
                backgroundColor: Color(0xFFEAF7F5),
                foregroundColor: Color(0xFF062B55),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: _HeroBody(theme: theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHero(BuildContext context, double width) {
    final isVeryCompact = isVeryCompactWidth(width);

    return Container(
      width: double.infinity,
      decoration: _heroDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            const Positioned.fill(child: _HeroImageLayer()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isVeryCompact ? 18 : 20,
                20,
                isVeryCompact ? 18 : 20,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      const _HeroTag(
                        label: 'Small groups',
                        backgroundColor: Color(0xFFEAF7F5),
                        foregroundColor: Color(0xFF062B55),
                      ),
                      const _HeroTag(
                        label: 'No swiping',
                        backgroundColor: Color(0xFFEAF7F5),
                        foregroundColor: Color(0xFF062B55),
                      ),
                    ],
                  ),
                  const SizedBox(height: 58),
                  _HeroBody(theme: theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _heroDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF062B55),
          Color(0xFF138B8A),
          Color(0xFFFF7759),
        ],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26150806),
          blurRadius: 28,
          offset: Offset(0, 18),
        ),
      ],
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return const BrandLockup();
  }
}

class _OnboardingSceneCard extends StatelessWidget {
  const _OnboardingSceneCard({
    required this.event,
    required this.eyebrow,
    required this.title,
    required this.onTap,
  });

  final MeetupEvent event;
  final String eyebrow;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE7E3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 136,
                  child: MeetupArtwork(
                    event: event,
                    height: 136,
                    radius: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              eyebrow,
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF138B8A),
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _HeroImageLayer extends StatelessWidget {
  const _HeroImageLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          GeneratedImageAssets.onboardingHero,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF062B55),
                    Color(0xFF138B8A),
                    Color(0xFFFF7759),
                  ],
                ),
              ),
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x30000000),
                Color(0x18000000),
                Color(0x960F0907),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDDE7E3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF062B55)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF062B55),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
