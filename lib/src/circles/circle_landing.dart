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
                    builder: (context, c) => _columns([
                          for (var i = 0; i < 3; i++)
                            CircleStoryCard(index: i, compact: c.maxWidth < 700)
                        ], c.maxWidth)),
                const SizedBox(height: 24),
                const CircleJourney(),
              ])),
          _section(context, null, _nextSteps(context, compact)),
          _section(context, null, _priceCard(context, compact)),
          _section(
              context,
              faqKey,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('A few things worth knowing',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'Who will I meet?',
                    answer:
                        'Five or six adults around Alkmaar, mostly 25–45. Everyone shares a language (English or Dutch) and a regular free time; then we look at interests and what you’re looking for. The same faces come back every week.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'What does it cost?',
                    answer:
                        '€39 once, for all six weeks. Two activities are included: we book and pay for them. Food and drinks you pay at the venue. No subscription, and no further fee after six weeks.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'Where do you meet?',
                    answer:
                        'In the centre of Alkmaar, at places we’ve picked for you. You see what each week costs as soon as we’ve found your people, and the places once your group is booked; in week five your group picks its own. Week one is a relaxed first drink, or coffee for daytime Circles, and leaving early is always fine.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'What about food and allergies?',
                    answer:
                        'The meal in week three is at a restaurant with plenty of choice, and you pay for your own: an evening dinner is about €38 per person (€43 from Friday to Sunday), drinks included, and lunch or brunch costs less. The other weeks are cafés and activities where you order what suits you. Please check ingredients and allergens with the venue yourself. If a place won’t work for you, message us on WhatsApp and we’ll help.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'What are the one-to-ones?',
                    answer:
                        'Between the group meetups we suggest meeting one person from your Circle: a coffee by day, or a drink in the evening (whatever you like to drink), at a place and time that suit you both. Optional, but recommended: it’s the quickest way to feel at home in the group. Saying no is always fine, and you pay for your own order.'),
                const Divider(height: 1),
                const _FaqTile(
                    question: 'What happens after six weeks?',
                    answer:
                        'Your Circle stays together: the group chat and meetup planning stay open, so you can keep making plans at no extra cost. Want to meet new people too? You can join a new Circle for €39.'),
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
    if (compact) return _phoneHero(context);
    final width = MediaQuery.sizeOf(context).width;
    final headlineSize = compact ? (width < 360 ? 20.0 : 27.0) : 52.0;
    return Container(
        decoration: const BoxDecoration(color: Color(0xFFFFFAF4)),
        child: Stack(children: [
          // Starts a fifth of the way in, so the person arriving on the
          // left of the picture stands clear of the headline.
          if (!compact)
            Positioned(
                left: width * .2,
                top: 0,
                right: 0,
                bottom: 0,
                // Its left edge fades in, so no line shows where it starts.
                child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(
                        colors: [Colors.transparent, Colors.black],
                        stops: [0, .3]).createShader(r),
                    child: Image.asset(
                        GeneratedImageAssets.landingImmersiveDesktop,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft))),
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
                                      const CircleBadge(
                                          'Two activities included',
                                          icon: Icons.redeem_outlined),
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
                                      ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 480),
                                          child: const Text(
                                              'Five or six people. Six weekly meetups in Alkmaar.',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.5,
                                                  color: circleTealText))),
                                      const SizedBox(height: 6),
                                      // What sets it apart, said once up
                                      // front; optional, so said quietly.
                                      ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 480),
                                          child: const Text(
                                              'Plus a coffee or a drink with one person from your Circle between meetups: optional, but recommended.',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.45,
                                                  color: Color(0xFF4F5D66)))),
                                      const SizedBox(height: 22),
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
                                      const SizedBox(height: 10),
                                      const Text(_priceLine,
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              color: Color(0xFF4F5D66))),
                                      const SizedBox(height: 14),
                                      // What people worry about, answered
                                      // right where they decide.
                                      Wrap(
                                          spacing: 18,
                                          runSpacing: 8,
                                          children: [
                                            for (final line in const [
                                              'No subscription',
                                              'In English or Dutch',
                                            ])
                                              Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        size: 17,
                                                        color: circleTeal),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                        child: Text(line,
                                                            style: const TextStyle(
                                                                fontSize: 13.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    circleNavy))),
                                                  ]),
                                          ]),
                                      if (compact) ...[
                                        const SizedBox(height: 10),
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
                                          height: 250,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          semanticLabel: t(
                                              'Friends around a café table by a canal, one arriving with a wave')))),
                            SizedBox(height: compact ? 30 : 84),
                          ])))),
        ]));
  }

  static const _priceLine =
      '€39 for six weeks · You pay only once your group is ready';

  /// A phone: one headline, one line of facts, the picture, one button.
  /// The rest of the story waits below, so the first screen stays light.
  /// Everything down to the price fits on the first screen: the picture
  /// takes what room is left (up to its own size), giving up sky first.
  /// With larger text, or on a very small screen, the page simply scrolls
  /// and the picture keeps its size.
  Widget _phoneHero(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final natural = size.width * 1250 / 1500;
    final screen = size.height - MediaQuery.paddingOf(context).top;
    // Too little room to fit it all (larger text, a very narrow or short
    // screen): the page simply scrolls.
    final large = MediaQuery.textScalerOf(context).scale(10) > 11.5 ||
        size.width < 340 ||
        screen < 500;
    // The top edge fades into the cream, so a short screen that trims the
    // picture never shows a straight cut through the leaves.
    Widget picture(double height) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0, .16]).createShader(r),
        child: Image.asset(GeneratedImageAssets.landingImmersiveMobile,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            alignment: const Alignment(0, .7),
            semanticLabel: t(
                'Friends around a café table by a canal, one arriving with a wave')));
    return ColoredBox(
        color: const Color(0xFFFFFAF4),
        child: SafeArea(
            bottom: false,
            child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: large ? double.infinity : screen),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                          child: Row(children: [
                            const Expanded(
                                child: BrandLockup(
                                    logoSize: 36, foregroundColor: circleNavy)),
                            TextButton(
                                onPressed: widget.onSignIn,
                                child: const Text('Sign in')),
                            const LanguageToggle(compact: true),
                          ])),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Strangers on week one.\nFriends by week six.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(
                                            fontSize:
                                                size.width < 380 ? 28 : 32,
                                            height: 1.08)),
                                const SizedBox(height: 14),
                                const CircleBadge('Two activities included',
                                    icon: Icons.redeem_outlined),
                                const SizedBox(height: 10),
                                const Text(
                                    '5–6 people · 6 weekly meetups · Alkmaar',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: circleTealText)),
                              ])),
                      if (large)
                        picture(natural)
                      else
                        Flexible(
                            child: LayoutBuilder(
                                builder: (context, box) => picture(
                                    box.maxHeight.clamp(0.0, natural)))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                          child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  onPressed: widget.onApply,
                                  child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                            child: Text('Apply for a spot',
                                                textAlign: TextAlign.center)),
                                        SizedBox(width: 16),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 18)
                                      ])))),
                      const Padding(
                          padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: Center(
                              child: Text(_priceLine,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF4F5D66))))),
                      const SizedBox(height: 18),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Divider(height: 1, color: Color(0x1F062B55))),
                    ]))));
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

  /// The offer as a price card: the price large, what it includes as a
  /// checklist, and the button. Side by side when there's room.
  Widget _priceCard(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    final price =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('THE ALKMAAR FOUNDING PILOT',
          style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: circleTealText)),
      const SizedBox(height: 14),
      Text('Six weeks.\nA real shot at friends.',
          style: theme.textTheme.displayMedium
              ?.copyWith(fontSize: compact ? 27 : 36, height: 1.08)),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('€39',
            style: theme.textTheme.displayLarge
                ?.copyWith(fontSize: compact ? 46 : 56, height: 1)),
        const SizedBox(width: 10),
        const Flexible(
            child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('once, for all six weeks',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F5D66))))),
      ]),
    ]);
    final list =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final line in const [
        'Six meetups, the same five or six people',
        'Two activities included, booked by us',
        'Pay only once we’ve found your people',
        'No subscription; food and drinks at the venue',
        'Not the right group? We’ll help',
      ])
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.check_circle_rounded,
                      size: 20, color: circleTeal)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(line,
                      style: const TextStyle(color: circleNavy, height: 1.4))),
            ])),
    ]);
    final action = Column(children: [
      SizedBox(
          width: double.infinity,
          child: ElevatedButton(
              onPressed: widget.onApply,
              child: const Text('Apply for a spot'))),
      const SizedBox(height: 6),
      Center(
          child: TextButton(
              onPressed: widget.onSignIn,
              child: const Text('Already applied? Sign in'))),
    ]);
    // Wide: the offer and its button on the left, what's in it on the
    // right, both about the same height, so the card reads as one closing
    // offer rather than a heading floating above an empty corner.
    return CirclePanel(tint: true, children: [
      LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 640
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        price,
                        const SizedBox(height: 26),
                        ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: action),
                      ])),
                  const SizedBox(width: 40),
                  Expanded(child: list),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  price,
                  const SizedBox(height: 22),
                  list,
                  const SizedBox(height: 14),
                  action
                ])),
    ]);
  }

  /// What happens after "Apply", so nobody wonders whether they just paid
  /// for something or when they will hear back.
  Widget _nextSteps(BuildContext context, bool compact) {
    const steps = [
      (
        Icons.edit_note_rounded,
        'Apply',
        'About three minutes. No payment yet.'
      ),
      (
        Icons.diversity_3_rounded,
        'We find your people',
        'People who share your language and a free time. We email you.'
      ),
      (
        Icons.celebration_rounded,
        'Pay and meet',
        'Pay €39 within 7 days. Then come the dates, places and the chat.'
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
