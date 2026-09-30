import 'package:flutter/material.dart';
import 'brand_mark_painter.dart';

class BrandLogoMark extends StatelessWidget {
  const BrandLogoMark({
    super.key,
    this.size = 64,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'VriendTime',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: VriendTimeMarkPainter(small: size < 48),
        ),
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.logoSize = 62,
    this.foregroundColor = Colors.white,
  });

  final double logoSize;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: BrandLogoMark(size: logoSize)),
        const SizedBox(width: 14),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: 'Vriend',
                  style: TextStyle(
                      color: foregroundColor == Colors.white
                          ? Colors.white
                          : const Color(0xFF145247))),
              const TextSpan(
                  text: 'Time', style: TextStyle(color: Color(0xFFF56853))),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Manrope',
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ),
      ],
    );
  }
}
