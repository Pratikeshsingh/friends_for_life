import 'package:web/web.dart' as web;

/// Swaps the address without reloading, so a one-time code is not left in
/// the address bar or the browser history.
void replaceAddress(String path) =>
    web.window.history.replaceState(null, '', path);
