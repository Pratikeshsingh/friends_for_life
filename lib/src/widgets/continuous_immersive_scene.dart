import 'package:flutter/material.dart';

/// Places one edge-to-edge illustration behind the opening content of a page.
/// The scene fades into the normal surface before dense controls begin.
class ContinuousImmersiveScene extends StatelessWidget {
  const ContinuousImmersiveScene({
    super.key,
    required this.assetName,
    required this.child,
    this.semanticLabel,
    this.compactExtent = 720,
    this.regularExtent = 780,
    this.alignment = Alignment.topCenter,
  });

  final String assetName;
  final Widget child;
  final String? semanticLabel;
  final double compactExtent;
  final double regularExtent;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final extent = width < 700 ? compactExtent : regularExtent;

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFCF7),
                Color(0xFFEAF7F5),
                Color(0xFFF7ECE4),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: extent,
          child: Image.asset(
            assetName,
            fit: BoxFit.cover,
            alignment: alignment,
            cacheWidth: 1200,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: semanticLabel == null,
            semanticLabel: semanticLabel,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: extent,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x20FFFCF7),
                  Color(0x48FFFCF7),
                  Color(0xA8FFFCF7),
                  Color(0xFFFFFCF7),
                ],
                stops: [0, 0.38, 0.78, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
