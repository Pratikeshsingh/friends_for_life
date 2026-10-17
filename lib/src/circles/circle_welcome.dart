import 'package:flutter/material.dart' hide Text;

import '../core/i18n.dart';
import '../core/image_assets.dart';
import '../widgets/brand_logo.dart';
import 'circle_landing.dart';
import 'circle_widgets.dart';

/// The installed app's first screen. Whoever opens it already chose to
/// download VriendTime, so: one picture, one line, and the way in. The full
/// story (the website's landing page) is one tap away.
class CircleWelcome extends StatelessWidget {
  const CircleWelcome(
      {super.key, required this.onApply, required this.onSignIn});
  final VoidCallback onApply, onSignIn;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
        backgroundColor: const Color(0xFFFFFAF4),
        body: SafeArea(child: LayoutBuilder(builder: (context, box) {
          // Short screen or large text: scroll, with a fixed picture.
          final tight = box.maxHeight < 640 ||
              MediaQuery.textScalerOf(context).scale(10) > 11.5;
          Widget sized(Widget picture) => tight
              ? SizedBox(height: 220, child: picture)
              : Expanded(child: picture);
          final page = Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                            child: Row(children: const [
                              Expanded(
                                  child: BrandLockup(
                                      logoSize: 36,
                                      foregroundColor: circleNavy)),
                              LanguageToggle(compact: true),
                            ])),
                        sized(ShaderMask(
                            // Soft top edge into the cream.
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (r) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                                stops: [0, .14]).createShader(r),
                            child: Image.asset(
                                GeneratedImageAssets.landingImmersiveMobile,
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, .6),
                                semanticLabel: t(
                                    'Friends around a café table by a canal, one arriving with a wave')))),
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
                                  const SizedBox(height: 10),
                                  const Text(
                                      '5–6 people · 6 weekly meetups · Alkmaar',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: circleTealText)),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                      onPressed: onApply,
                                      child: const Text('Create an account')),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(52)),
                                      onPressed: onSignIn,
                                      child: const Text('Sign in')),
                                  const SizedBox(height: 4),
                                  Center(
                                      child: TextButton(
                                          onPressed: () => Navigator.of(context)
                                              .push(MaterialPageRoute(
                                                  builder: (_) => CircleLanding(
                                                          onApply: () {
                                                        Navigator.pop(context);
                                                        onApply();
                                                      }, onSignIn: () {
                                                        Navigator.pop(context);
                                                        onSignIn();
                                                      }))),
                                          child:
                                              const Text('How Circles work'))),
                                  const SizedBox(height: 8),
                                ])),
                      ])));
          return tight ? SingleChildScrollView(child: page) : page;
        })));
  }
}
