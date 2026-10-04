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
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontFamily: 'Manrope',
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        );
    final name = TextSpan(style: style, children: [
      TextSpan(
          text: 'Vriend',
          style: TextStyle(
              color: foregroundColor == Colors.white
                  ? Colors.white
                  : const Color(0xFF145247))),
      const TextSpan(text: 'Time', style: TextStyle(color: Color(0xFFF56853))),
    ]);
    // When the full name does not fit next to the header's actions, show
    // the mark on its own instead of a clipped "VriendT…".
    return LayoutBuilder(builder: (context, box) {
      final painter = TextPainter(
          text: name,
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context))
        ..layout();
      final fits = box.maxWidth >= logoSize + 14 + painter.width;
      painter.dispose();
      if (!fits) {
        // Keep the mark square even when the header hands over its full
        // width.
        return Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: BrandLogoMark(size: logoSize));
      }
      return Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: BrandLogoMark(size: logoSize)),
        const SizedBox(width: 14),
        Text.rich(name, maxLines: 1),
      ]);
    });
  }
}
