import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/i18n.dart';
import 'package:vriendtime/src/circles/circle_repository.dart' show circleDate;

void main() {
  tearDown(() => appLanguage.value = 'en');

  test('the first preferred language the app speaks wins', () {
    expect(pickLanguage(['de', 'nl', 'en']), 'nl');
    expect(pickLanguage(['fr', 'en', 'nl']), 'en');
    expect(pickLanguage(['nl-NL'.split('-').first]), 'nl');
    expect(pickLanguage(['de', 'fr']), 'en');
    expect(pickLanguage([]), 'en');
  });

  test('English is returned unchanged', () {
    appLanguage.value = 'en';
    expect(t('Apply for a spot'), 'Apply for a spot');
  });

  test('Dutch covers exact text, numbers and composite lines', () {
    appLanguage.value = 'nl';
    expect(t('Apply for a spot'), 'Meld je aan');
    expect(t('Waiting 3 weeks'), 'Wacht al 3 weken');
    expect(t('3 of 5 people ready for Thursday evenings'),
        '3 van de 5 mensen klaar voor donderdagavonden');
    expect(t('Free Thursday evening'), 'Vrij op donderdagavond');
    expect(t('Thursday evening'), 'Donderdagavond');
    expect(t('Dinner together · Week 1 of 6'), 'Samen eten · Week 1 van 6');
    expect(t('Starts Thu 8 Oct'), 'Start Thu 8 Oct');
    // Unknown text stays English rather than breaking.
    expect(t('Something nobody translated'), 'Something nobody translated');
    // Names pass through.
    expect(t('Asha'), 'Asha');
  });

  test('dates follow the language', () {
    appLanguage.value = 'nl';
    expect(circleDate('2026-10-08'), 'do 8 okt');
    appLanguage.value = 'en';
    expect(circleDate('2026-10-08'), 'Thu 8 Oct');
  });

  testWidgets('the Text widget translates and switches live', (tester) async {
    appLanguage.value = 'en';
    await tester.pumpWidget(LanguageScope(
        child:
            const MaterialApp(home: Scaffold(body: Text('Apply for a spot')))));
    expect(find.text('Apply for a spot'), findsOneWidget);
    appLanguage.value = 'nl';
    await tester.pump();
    expect(find.text('Meld je aan'), findsOneWidget);
  });

  test('payment messages from the server translate with the Circle name', () {
    appLanguage.value = 'nl';
    expect(
        t('Your place in The Monday Circle is confirmed once your €19 arrives. Pay by the end of tomorrow to keep it.'),
        'Je plek in De maandag-Circle is bevestigd zodra je €19 binnen is. Betaal uiterlijk morgen om je plek te houden.');
    expect(t('Your place was released: payment not received'),
        'Je plek is vrijgegeven: betaling niet ontvangen');
  });
}
