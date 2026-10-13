import 'address_bar_native.dart'
    if (dart.library.js_interop) 'address_bar_web.dart' as address_bar;

/// Where an email link asked the app to go, e.g. `?open=checkin:<meetup id>`.
/// Read once at start-up, then used after the member's Circle has loaded
/// (after signing in, if they weren't).
class OpenLinks {
  static String? pending;

  static void capture(Uri uri) {
    final open = uri.queryParameters['open'];
    if (open == null || open.isEmpty) {
      if (uri.queryParameters.containsKey('lang') && uri.path == '/') {
        address_bar
            .replaceAddress('/${uri.hasFragment ? '#${uri.fragment}' : ''}');
      }
      return;
    }
    pending = open;
    // Keep the address clean; a reload must not repeat the jump.
    address_bar.replaceAddress('/');
  }

  /// The pending destination, once.
  static String? take() {
    final value = pending;
    pending = null;
    return value;
  }
}
