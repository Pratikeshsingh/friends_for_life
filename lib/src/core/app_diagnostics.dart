import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Never transmits error text, stack locals, user text, or account details.
class AppDiagnostics {
  static const build =
      String.fromEnvironment('APP_BUILD', defaultValue: '1.0.0+2');
  static String? lastReference;
  static DateTime? _lastSent;
  static void record(Object error, {required String area}) {
    final now = DateTime.now().toUtc();
    lastReference = now.microsecondsSinceEpoch.toRadixString(36);
    if (!kReleaseMode) debugPrint('[$area/$lastReference] $error');
    if (_lastSent != null &&
        now.difference(_lastSent!) < const Duration(seconds: 30)) {
      return;
    }
    _lastSent = now;
    unawaited(_send(area, error.runtimeType.toString(), lastReference!));
  }

  static Future<void> _send(String area, String kind, String ref) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.rpc('record_app_error', params: {
        'area': area,
        'kind': kind,
        'build': build,
        'reference': ref
      }).timeout(const Duration(seconds: 5));
    } catch (_) {/* Diagnostics must never interrupt the app. */}
  }

  static Widget fallback(FlutterErrorDetails details) => Material(
      color: const Color(0xFFFFFAF4),
      child: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh, size: 32),
                const Text(
                    'This screen couldn’t load. Reopen the app to try again.'),
                SelectableText(
                    'Support reference: ${lastReference ?? 'unavailable'} · $build'),
              ]))));
}
