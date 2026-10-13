// The phone's own share menu (WhatsApp, Signal, Instagram, copy…), where the
// browser offers it: Safari on iPhone and Mac, Chrome on Android and Windows.
export 'system_share_stub.dart'
    if (dart.library.js_interop) 'system_share_web.dart';
