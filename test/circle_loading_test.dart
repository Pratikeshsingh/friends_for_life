import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/widgets/brand_mark_painter.dart';
import 'package:vriendtime/src/widgets/circle_loading.dart';

void main() {
  VriendTimeMarkPainter mark(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<VriendTimeMarkPainter>()
      .single;

  Widget loader({bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const Scaffold(body: Center(child: CircleLoading())),
        ),
      );

  testWidgets('people gather, hold, and reset without delaying disposal',
      (tester) async {
    await tester.pumpWidget(loader());
    expect(mark(tester).top, greaterThan(0));
    expect(mark(tester).left, greaterThan(0));
    expect(mark(tester).right, greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    expect(mark(tester).top, 0);
    expect(mark(tester).left, 0);
    expect(mark(tester).right, 0);
    expect(mark(tester).centerOpacity, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(mark(tester).top, 0);
    await tester.pump(const Duration(milliseconds: 1499));
    expect(mark(tester).top, closeTo(300, .01));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion shows assembled logo and stops the ticker',
      (tester) async {
    await tester.pumpWidget(loader());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(loader(reduced: true));
    await tester.pumpAndSettle();
    expect(mark(tester).top, 0);
    expect(mark(tester).left, 0);
    expect(mark(tester).right, 0);
    expect(mark(tester).centerOpacity, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
