import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _navigator => globalContext['navigator'] as JSObject?;

bool get canSystemShare => _navigator?.has('share') ?? false;

/// True when the menu opened (or the person closed it); false when the
/// browser refused, so the caller can offer copying instead.
Future<bool> systemShare(String text) async {
  final navigator = _navigator;
  if (navigator == null || !navigator.has('share')) return false;
  try {
    await navigator
        .callMethod<JSPromise<JSAny?>>('share'.toJS, {'text': text}.jsify())
        .toDart;
    return true;
  } catch (e) {
    // Closing the menu without choosing an app is fine, not a failure.
    return e.toString().contains('AbortError');
  }
}
