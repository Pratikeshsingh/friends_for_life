import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/theme.dart';
import 'package:vriendtime/src/widgets/app_shell_header.dart';
import 'package:vriendtime/src/widgets/floating_glass_navigation.dart';

void main() {
  for (final width in <double>[320, 375, 768]) {
    testWidgets(
      'floating glass navigation stays readable at ${width.toInt()}px',
      (tester) async {
        tester.view
          ..physicalSize = Size(width, 900)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });

        var selectedIndex = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: const TextScaler.linear(1.3),
              ),
              child: Scaffold(
                extendBody: true,
                body: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFDCCB), Color(0xFFBDEBE4)],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                bottomNavigationBar: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return FloatingGlassNavigation(
                        height: 72,
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() => selectedIndex = index);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(
          find.byKey(const ValueKey('floating-glass-navigation')),
          findsOneWidget,
        );
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Meetups'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);

        final navRect = tester.getRect(
          find.byKey(const ValueKey('floating-glass-navigation')),
        );
        for (final label in <String>['Home', 'Meetups', 'Profile']) {
          final labelRect = tester.getRect(find.text(label));
          expect(labelRect.top, greaterThanOrEqualTo(navRect.top));
          expect(labelRect.bottom, lessThanOrEqualTo(navRect.bottom));
        }

        await tester.tap(find.text('Meetups'));
        await tester.pump();
        expect(selectedIndex, 1);
      },
    );
  }

  testWidgets('notification bell uses the matching glass treatment', (
    tester,
  ) async {
    var openCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: AppShellHeader(
              onOpenNotifications: () => openCount++,
              unreadCount: 3,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final bell = find.bySemanticsLabel('Open notifications, 3 unread');
    expect(bell, findsOneWidget);
    expect(tester.getSize(bell), const Size(48, 48));

    await tester.tap(bell);
    expect(openCount, 1);
  });
}
