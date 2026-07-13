import 'package:flutter/material.dart';

import '../core/responsive.dart';

/// A short, full-viewport visual band whose live controls stay aligned with
/// the page content below it. It is deliberately compact so artwork adds
/// atmosphere without competing with the screen's actual task.
class CompactImmersiveHeader extends StatelessWidget {
  const CompactImmersiveHeader({
    super.key,
    required this.assetName,
    this.child,
    this.compactHeight = 96,
    this.regularHeight = 116,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.showContentScrim = true,
  });

  final String assetName;
  final Widget? child;
  final double compactHeight;
  final double regularHeight;
  final Alignment alignment;
  final String? semanticLabel;
  final bool showContentScrim;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compact = viewportWidth < 700;
    final height = compact ? compactHeight : regularHeight;
    final contentMaxWidth = responsiveContentMaxWidth(viewportWidth);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            assetName,
            fit: BoxFit.cover,
            alignment: alignment,
            cacheWidth: 1400,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: semanticLabel == null,
            semanticLabel: semanticLabel,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEAF7F5), Color(0xFFF7ECE4)],
                ),
              ),
            ),
          ),
          if (showContentScrim)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF2FFF9F1),
                      Color(0xCFFFF9F1),
                      Color(0x70FFF9F1),
                    ],
                    stops: [0, 0.52, 1],
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
                  colors: [Color(0x00FFFCF7), Color(0xB8FFFCF7)],
                  stops: [0.5, 1],
                ),
              ),
            ),
          ),
          if (child != null)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: child,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
