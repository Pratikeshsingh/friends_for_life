import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_nl.dart';

/// English and Dutch for the whole Circles app.
///
/// The English text stays in the code. [t] looks it up in the Dutch table
/// ([nlStrings]) when Dutch is on. Anything missing falls back to English,
/// so an untranslated line reads in English rather than breaking.
///
/// Most screens need no changes: they import this file's [Text] instead of
/// Flutter's, and it translates whatever it is given. Only text that never
/// reaches a Text widget (field labels, hints, tooltips) calls [t] directly.

const supportedLanguages = ['en', 'nl'];
const _prefsKey = 'app_language';

/// The current language, 'en' or 'nl'. Starts from the device language.
final appLanguage = ValueNotifier<String>(_deviceLanguage());

String _deviceLanguage() =>
    PlatformDispatcher.instance.locale.languageCode == 'nl' ? 'nl' : 'en';

bool get isDutch => appLanguage.value == 'nl';

/// Loads a language the person picked earlier, if any.
Future<void> loadSavedLanguage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && supportedLanguages.contains(saved)) {
      appLanguage.value = saved;
    }
  } catch (_) {}
}

Future<void> setLanguage(String code) async {
  if (!supportedLanguages.contains(code)) return;
  appLanguage.value = code;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  } catch (_) {}
}

final _cache = <String, String>{};
List<(RegExp, String, int)>? _patterns;

/// Keys with {1}, {2}… become patterns, so "Waiting {1} weeks" also
/// translates "Waiting 3 weeks". Longer keys are tried first.
List<(RegExp, String, int)> _compiledPatterns() {
  if (_patterns != null) return _patterns!;
  final list = <(RegExp, String, int)>[];
  for (final e in nlStrings.entries) {
    if (!e.key.contains(RegExp(r'\{\d\}'))) continue;
    final parts = e.key.split(RegExp(r'\{\d\}'));
    final order = RegExp(r'\{(\d)\}')
        .allMatches(e.key)
        .map((m) => int.parse(m.group(1)!))
        .toList();
    final source = '^${parts.map(RegExp.escape).join('(.+?)')}\$';
    list.add((RegExp(source, dotAll: true), e.value, order.length));
    // Remember which capture is which placeholder.
    _order[source] = order;
  }
  list.sort((a, b) => b.$1.pattern.length.compareTo(a.$1.pattern.length));
  return _patterns = list;
}

final _order = <String, List<int>>{};

final _dayOrPeriod = RegExp(
    r'^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|morning|afternoon|evening)');

/// Translates [en] into the current language.
String t(String en) {
  if (!isDutch || en.isEmpty) return en;
  final cached = _cache[en];
  if (cached != null) return cached;
  return _cache[en] = _translate(en);
}

String _translate(String en) {
  final exact = nlStrings[en];
  if (exact != null) return exact;
  final trimmed = en.trim();
  if (trimmed != en && nlStrings[trimmed] != null) {
    return en.replaceFirst(trimmed, nlStrings[trimmed]!);
  }
  for (final (pattern, nl, count) in _compiledPatterns()) {
    final match = pattern.firstMatch(en);
    if (match == null || match.groupCount != count) continue;
    final order = _order[pattern.pattern]!;
    var out = nl;
    for (var i = 0; i < order.length; i++) {
      final token = '{${order[i]}}';
      final captured = match.group(i + 1)!;
      var value = t(captured);
      // Dutch writes days and times of day in lowercase mid-sentence:
      // "Vrij op donderdagavond", but "Donderdagavond" on its own.
      if (out.indexOf(token) > 0 && _dayOrPeriod.hasMatch(captured)) {
        value = value[0].toLowerCase() + value.substring(1);
      }
      out = out.replaceAll(token, value);
    }
    return out;
  }
  // Composite lines: translate each part on its own.
  for (final sep in ['\n', ' · ', ' — ', ': ', ' / ', ', ']) {
    if (en.contains(sep)) {
      final parts = en.split(sep);
      final translated = parts.map(t).toList();
      if (!_same(parts, translated)) return translated.join(sep);
    }
  }
  return en;
}

bool _same(List<String> a, List<String> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Rebuilds everything below it when the language changes.
class LanguageScope extends InheritedNotifier<ValueNotifier<String>> {
  LanguageScope({super.key, required super.child})
      : super(notifier: appLanguage);

  static String of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    return appLanguage.value;
  }
}

/// Drop-in for Flutter's Text that translates its string. Files import
/// `package:flutter/material.dart` with `hide Text` and this file instead.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    LanguageScope.of(context);
    final label = semanticsLabel == null ? null : t(semanticsLabel!);
    if (textSpan != null) {
      return m.Text.rich(textSpan!,
          style: style,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          textScaler: textScaler,
          maxLines: maxLines,
          semanticsLabel: label,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor);
    }
    return m.Text(t(data!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: label,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor);
  }
}

/// A small EN | NL switch.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageScope.of(context);
    if (compact) {
      // One small button that switches to the other language, so it fits
      // next to "Sign in" on a 320px phone.
      final other = lang == 'nl' ? 'en' : 'nl';
      return m.TextButton(
          style: m.TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8)),
          onPressed: () => setLanguage(other),
          child: m.Text(other.toUpperCase(),
              semanticsLabel: other == 'nl' ? 'Nederlands' : 'English',
              style: const TextStyle(fontWeight: FontWeight.w800)));
    }
    return m.SegmentedButton<String>(
        showSelectedIcon: false,
        style: m.SegmentedButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w800)),
        segments: const [
          m.ButtonSegment(
              value: 'en',
              label: m.Text('EN', semanticsLabel: 'English'),
              tooltip: 'English'),
          m.ButtonSegment(
              value: 'nl',
              label: m.Text('NL', semanticsLabel: 'Nederlands'),
              tooltip: 'Nederlands'),
        ],
        selected: {lang},
        onSelectionChanged: (s) => setLanguage(s.first));
  }
}
