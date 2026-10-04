import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import '../widgets/brand_logo.dart';
import '../core/image_assets.dart';
import '../widgets/motion.dart';
import '../screens/legal_document_screen.dart';
import 'circle_widgets.dart';
import 'circle_journey.dart';

/// Public discovery. No sample members or preview state enters this screen.
class CircleLanding extends StatefulWidget {
  const CircleLanding(
      {super.key, required this.onApply, required this.onSignIn});
  final VoidCallback onApply, onSignIn;
  @override
  State<CircleLanding> createState() => _CircleLandingState();
}

class _CircleLandingState extends State<CircleLanding> {
  final howKey = GlobalKey(), faqKey = GlobalKey();

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
          _section(context, null, _nextSteps(context, compact)),
          _section(
              context,
              null,
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: CirclePanel(tint: true, children: [
                        const CirclePill('THE ALKMAAR FOUNDING PILOT'),
                        const SizedBox(height: 22),
                        Text('Six weeks.\nA real shot at friends.',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                    fontSize: compact ? 27 : null,
                                    height: 1.08)),
                        const SizedBox(height: 18),
                        const Text('Founding Circle · €19',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: circleNavy)),
                        const SizedBox(height: 10),
                        const Text(
                            'One payment for all six weeks. No subscription. You pay the venue for what you eat and drink.'),
                        const SizedBox(height: 18),
                        const Text(
                            'Cancel up to 48 hours before your first meetup for a full refund. Not the right group after the first meetup? Move to another one once, free of charge.',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: circleNavy)),
                        const SizedBox(height: 24),
                        ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: ElevatedButton(
                                onPressed: widget.onApply,
                                child: const Text('Apply for a spot'))),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: widget.onSignIn,
                            child: const Text('Already applied? Sign in')),
                      ])))),
          _section(
              context,
              faqKey,
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
                    question: 'How big is a Circle?',
                    answer:
                        'Five or six people. Everyone shares a language and has the same regular time free, so the same faces come back every week.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'How are people matched?',
                    answer:
                        'Our team starts with a shared language and time, then considers your interests and what you’re looking for.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'Is this a subscription?',
                    answer:
                        'No. You pay €19 once for all six weeks, and nothing more after that. Food, drinks and activity tickets are paid at the venue.'),
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
                const BrandLockup(logoSize: 34, foregroundColor: circleNavy),
                const SizedBox(height: 12),
                Wrap(spacing: 24, runSpacing: 4, children: [
                  _footerLink('Terms', () => _legal(LegalDocumentType.terms)),
                  _footerLink(
                      'Privacy', () => _legal(LegalDocumentType.privacy)),
                  _footerLink('Sign in', widget.onSignIn),
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
                                              onPressed: () => scrollTo(faqKey),
                                              child: const Text('Questions')),
                                          const SizedBox(width: 4),
                                          TextButton(
                                              onPressed: widget.onSignIn,
                                              child: const Text('Sign in')),
                                          const SizedBox(width: 6),
                                          const LanguageToggle(compact: true)
                                        ]))
                                  else
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                              onPressed: widget.onSignIn,
                                              child: const Text('Sign in')),
                                          const LanguageToggle(compact: true),
                                        ])
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
                                          'Five or six people. Six weekly meetups. €19 for all six weeks.',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              height: 1.5,
                                              color: circleTealText)),
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
                                          semanticLabel: t(
                                              'A table set for company, with a view over an Alkmaar canal')))),
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

  /// What happens after "Apply", so nobody wonders whether they just paid
  /// for something or when they will hear back.
  Widget _nextSteps(BuildContext context, bool compact) {
    const steps = [
      (
        Icons.edit_note_rounded,
        'Apply',
        'Four short steps, about three minutes. No payment yet.'
      ),
      (
        Icons.diversity_3_rounded,
        'We find your group',
        'Five or six people who share a language and a regular free time. This usually takes one to three weeks.'
      ),
      (
        Icons.celebration_rounded,
        'Say yes',
        'See your group and all six dates first. Only then accept for €19.'
      ),
    ];
    Widget step(int i) {
      final (icon, title, body) = steps[i];
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: circleTeal)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. $title',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: circleNavy)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(height: 1.5)),
        ])),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleHeading('What happens after you apply.',
          eyebrow: 'Three steps'),
      LayoutBuilder(
          builder: (context, c) =>
              _columns([for (var i = 0; i < 3; i++) step(i)], c.maxWidth)),
    ]);
  }

  Widget _footerLink(String label, VoidCallback onTap) => TextButton(
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      onPressed: onTap,
      child: Text(label));

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
