import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/i18n.dart' show loadSavedLanguage;
import 'src/core/supabase_config.dart';
import 'src/startup_error_app.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.current,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        Zone.current.handleUncaughtError(error, stack);
        return true;
      };

      await _startApp();
    },
    _reportUnhandledError,
  );
}

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedLanguage();

  final configurationError = SupabaseConfig.configurationErrorMessage;
  if (configurationError != null) {
    runApp(VriendTimeStartupErrorApp(message: configurationError));
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
  } catch (error, stackTrace) {
    _reportUnhandledError(error, stackTrace);
    runApp(
      const VriendTimeStartupErrorApp(
        message:
            'We could not connect to VriendTime services. Check your connection and try again.',
      ),
    );
    return;
  }

  runApp(const VriendTimeApp());
}

void _reportUnhandledError(Object error, StackTrace stackTrace) {
  if (kReleaseMode) return;
  debugPrint('Unhandled app error: $error');
  debugPrintStack(stackTrace: stackTrace);
}
