import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/event_catalog.dart';
import '../core/event_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../screens/legal_document_screen.dart';
import 'circle_repository.dart' show circleDate;
import 'circle_widgets.dart';
import 'circle_journey.dart';

/// Public discovery. No sample members or preview state enters this screen.
class CircleLanding extends StatefulWidget {
  const CircleLanding(
      {super.key,
      required this.onApply,
      required this.onSignIn,
      this.loadActivities});
  final VoidCallback onApply, onSignIn;
  final Future<List<MeetupEvent>> Function()? loadActivities;
  @override
  State<CircleLanding> createState() => _CircleLandingState();
}

class _CircleLandingState extends State<CircleLanding> {
  final howKey = GlobalKey(), activitiesKey = GlobalKey();
  List<MeetupEvent> activities = [];
  bool loading = true, failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });

    if (widget.loadActivities != null) {
      try {
        final events = await widget.loadActivities!();
        if (mounted) setState(() => activities = _forAlkmaar(events));
      } catch (_) {
        if (mounted) setState(() => failed = true);
      } finally {
        if (mounted) setState(() => loading = false);
      }
      return;
    }

    // Upcoming events are the primary content and render as soon as they
    // arrive. Past events are only a best-effort top-up for a quiet week and
    // must never hold the section hostage if that second request is slow.
    final service = EventService(Supabase.instance.client);
    List<MeetupEvent> upcoming;
    try {
      upcoming = await service.fetchOpenEvents(forceRefresh: true);
      if (EventService.openEventsLoadFailed) {
        throw StateError('Activity feed unavailable');
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
      return;
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (!mounted) return;
    setState(() => activities = _forAlkmaar(upcoming));
    if (upcoming.length >= 3) return;

    final past = await service.fetchPastEvents(limit: 3, forceRefresh: true);
    if (mounted) {
      setState(() => activities = _forAlkmaar([...upcoming, ...past]));
    }
  }

  List<MeetupEvent> _forAlkmaar(List<MeetupEvent> events) {
    final byId = <String, MeetupEvent>{};
    for (final event in events) {
      if (event.city.toLowerCase() == 'alkmaar') byId[event.id] = event;
    }
    return byId.values.take(3).toList();
  }

  void scrollTo(GlobalKey key) {
    final c = key.currentContext;
    if (c != null) {
      Scrollable.ensureVisible(c,
          duration: prefersReducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
        backgroundColor: const Color(0xFFFFFAF4),
        body: SingleChildScrollView(
            child: Column(children: [
          _hero(context, compact),
          _section(
              context,
              howKey,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CircleHeading('One hello is nice.\nFamiliar is better.',
                    eyebrow: 'How friendship gets a chance'),
                LayoutBuilder(
                    builder: (context, c) => _columns(
                        [for (var i = 0; i < 3; i++) CircleStoryCard(index: i)],
                        c.maxWidth)),
                const SizedBox(height: 24),
                const CircleJourney(),
              ])),
          _section(context, activitiesKey, _liveActivities(context)),
          _section(
              context,
              null,
              CirclePanel(tint: true, children: [
                const CirclePill('THE ALKMAAR FOUNDING PILOT'),
                const SizedBox(height: 22),
                Text('Six weeks.\nA real shot at friends.',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: compact ? 27 : null, height: 1.08)),
                const SizedBox(height: 18),
                const Text('Founding Circle — €19',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: circleNavy)),
                const SizedBox(height: 10),
                const Text(
                    'One programme. No subscription. Food, drinks and activities extra.'),
                const SizedBox(height: 18),
                const Text(
                    'If the Circle doesn’t feel right after Meetup #1, request a refund within 48 hours.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: circleNavy)),
                const SizedBox(height: 24),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: ElevatedButton(
                        onPressed: widget.onApply,
                        child: const Text('Apply for a spot'))),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: widget.onSignIn,
                    child: const Text('Already a member? Sign in')),
              ])),
          _section(
              context,
              null,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('A few things worth knowing',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'Who are Circles for?',
                    answer:
                        'Adults 18+ around Alkmaar. Our first groups focus on ages 25–45 and meet in English or Dutch.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'How are people matched?',
                    answer:
                        'Our team starts with a shared language and time, then considers your interests and what you’re looking for.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'Is this a subscription?',
                    answer:
                        'No — €19 once for all six weeks. Food, drinks and activities are separate, and there’s nothing more to pay after that.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'Where do you meet?',
                    answer:
                        'Somewhere in Alkmaar we’ve booked for you. We share the exact place 24 hours before, so you come for the people rather than the venue. Week one is a two-hour dinner; you pay the restaurant for what you order, and leaving early is always fine.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'What happens after six weeks?',
                    answer:
                        'The Circle stays together — your group chat and meetup planning stay open, so you can keep making your own plans.'),
                const Divider(height: 1),
                const SizedBox(height: 28),
                Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const BrandLockup(
                          logoSize: 34, foregroundColor: circleNavy),
                      TextButton(
                          onPressed: () => _legal(LegalDocumentType.terms),
                          child: const Text('Terms')),
                      TextButton(
                          onPressed: () => _legal(LegalDocumentType.privacy),
                          child: const Text('Privacy')),
                      TextButton(
                          onPressed: widget.onSignIn,
                          child: const Text('Sign in'))
                    ]),
                const SizedBox(height: 18),
                const Text('VriendTime · Friendship Circles · Alkmaar',
                    style: TextStyle(fontSize: 12)),
              ])),
        ])));
  }

  Widget _hero(BuildContext context, bool compact) {
    final width = MediaQuery.sizeOf(context).width;
    final headlineSize = compact ? (width < 360 ? 20.0 : 27.0) : 52.0;
    return Container(
        decoration: const BoxDecoration(color: Color(0xFFFFFAF4)),
        child: Stack(children: [
          if (!compact)
            Positioned.fill(
                child: Image.asset(GeneratedImageAssets.landingImmersiveDesktop,
                    fit: BoxFit.cover, alignment: Alignment.centerRight)),
          if (!compact)
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
              const Color(0xFFFFFAF4),
              const Color(0xFFFFFAF4).withValues(alpha: .96),
              const Color(0xFFFFFAF4).withValues(alpha: 0)
            ], stops: const [
              0,
              .29,
              .78
            ])))),
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: compact ? 24 : 40),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 18),
                            SafeArea(
                                bottom: false,
                                child: Row(children: [
                                  const Expanded(
                                      child: BrandLockup(
                                          logoSize: 44,
                                          foregroundColor: circleNavy)),
                                  if (!compact)
                                    // The photo behind the hero shows through
                                    // fully by the right edge (the cream
                                    // gradient fades to transparent), so these
                                    // links need their own backdrop rather than
                                    // relying on whatever the photo shows
                                    // through at that point.
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: .78),
                                            borderRadius:
                                                BorderRadius.circular(30)),
                                        child: Row(children: [
                                          TextButton(
                                              onPressed: () => scrollTo(howKey),
                                              child:
                                                  const Text('How it works')),
                                          TextButton(
                                              onPressed: () =>
                                                  scrollTo(activitiesKey),
                                              child: const Text('Activities')),
                                          const SizedBox(width: 4),
                                          TextButton(
                                              onPressed: widget.onSignIn,
                                              child: const Text('Sign in'))
                                        ]))
                                  else
                                    TextButton(
                                        onPressed: widget.onSignIn,
                                        child: const Text('Sign in'))
                                ])),
                            SizedBox(height: compact ? 40 : 78),
                            ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 600),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CirclePill(
                                          'FRIENDSHIP CIRCLES · ALKMAAR',
                                          icon: Icons.place_outlined),
                                      const SizedBox(height: 24),
                                      Text(
                                          'Strangers on week one.\nFriends by week six.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .displayLarge
                                              ?.copyWith(
                                                  fontSize: headlineSize,
                                                  height: 1.08)),
                                      const SizedBox(height: 18),
                                      const Text(
                                          'Six people. Six weekly meetups. €19 total.',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              height: 1.5,
                                              color: circleTeal)),
                                      const SizedBox(height: 26),
                                      ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 340),
                                          child: ElevatedButton(
                                              onPressed: widget.onApply,
                                              child: const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                        child: Text(
                                                            'Apply for a spot',
                                                            textAlign: TextAlign
                                                                .center)),
                                                    SizedBox(width: 16),
                                                    Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 18)
                                                  ]))),
                                      if (compact) ...[
                                        const SizedBox(height: 8),
                                        TextButton(
                                            onPressed: () => scrollTo(howKey),
                                            child: const Text(
                                                'See how Circles work ↓')),
                                      ],
                                    ])),
                            if (compact)
                              Padding(
                                  padding: const EdgeInsets.only(top: 30),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Image.asset(
                                          GeneratedImageAssets
                                              .landingImmersiveMobile,
                                          height: 225,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.bottomCenter,
                                          semanticLabel:
                                              'A table set for company, with a view over an Alkmaar canal'))),
                            SizedBox(height: compact ? 30 : 84),
                          ])))),
        ]));
  }

  Widget _section(BuildContext context, Key? key, Widget child) => Center(
      key: key,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 760 ? 24 : 40,
                  vertical: 36),
              child: SizedBox(width: double.infinity, child: child))));
  Widget _columns(List<Widget> cards, double width) => width < 700
      ? Column(children: [
          for (final card in cards)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: card)
        ])
      : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < cards.length; i++)
            Expanded(
                child: Padding(
                    padding:
                        EdgeInsets.only(right: i == cards.length - 1 ? 0 : 18),
                    child: cards[i]))
        ]);
  Widget _liveActivities(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleHeading('Around the VriendTime table.',
            eyebrow: 'Meetups in Alkmaar',
            subtitle:
                'Public VriendTime meetups. Your Circle makes its own plans.'),
        if (loading)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LinearProgressIndicator(
                  minHeight: 3,
                  semanticsLabel: 'Finding meetups around Alkmaar'))
        else if (failed)
          CirclePanel(children: [
            const Text('Activities couldn’t be loaded right now.'),
            TextButton(onPressed: load, child: const Text('Try again'))
          ])
        else if (activities.isEmpty)
          const CirclePanel(children: [
            Icon(Icons.calendar_month_outlined, color: circleTeal, size: 32),
            SizedBox(height: 14),
            Text('The next introductions are taking shape.',
                style:
                    TextStyle(fontWeight: FontWeight.w700, color: circleNavy)),
            SizedBox(height: 8),
            Text(
                'Nothing public is listed right now — Circle plans are made separately, once your group is set.')
          ])
        else
          LayoutBuilder(
              builder: (context, c) => _columns(
                  [for (final e in activities) _event(context, e)],
                  c.maxWidth)),
      ]);
  Widget _event(BuildContext context, MeetupEvent e) {
    final past = e.startsAt.isBefore(DateTime.now());
    return CirclePanel(children: [
      MeetupArtwork(event: e, height: 170, radius: 16),
      const SizedBox(height: 16),
      CirclePill(past
          ? 'RECENT MEETUP'
          : e.status == 'full'
              ? 'FULL'
              : 'UPCOMING'),
      const SizedBox(height: 12),
      Text(e.title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('${circleDate(e.startsAt.toIso8601String())} · ${e.city}'),
      const SizedBox(height: 6),
      Text(e.activityLabel),
      const SizedBox(height: 10),
      TextButton(
          onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                      title: Text(e.title),
                      content: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                '${circleDate(e.startsAt.toIso8601String())} · ${e.city}'),
                            const SizedBox(height: 12),
                            Text(e.subtitle),
                            const SizedBox(height: 12),
                            Text(e.areaLabel),
                            const SizedBox(height: 18),
                            const Text(
                                'A public VriendTime meetup. Your Circle has its own separate schedule.')
                          ])),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Close'))
                      ])),
          child: const Text('About this activity'))
    ]);
  }

  void _legal(LegalDocumentType type) => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(type: type)));
}

/// A question/answer row styled to match the page's editorial voice, rather
/// than the boxed, default look of a bare [ExpansionTile].
class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question, answer;
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool open = false;
  @override
  Widget build(BuildContext context) =>
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(widget.question,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: circleNavy)),
          trailing: AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: prefersReducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child:
                  const Icon(Icons.add_rounded, color: circleTeal, size: 22)),
          onExpansionChanged: (value) => setState(() => open = value),
          children: [
            Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(widget.answer))
          ]);
}
