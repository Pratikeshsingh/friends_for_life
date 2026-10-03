import 'dart:typed_data';
import 'photo_preparation_policy.dart';
import 'photo_preparation_native.dart'
    if (dart.library.js_interop) 'photo_preparation_web.dart' as platform;
export 'photo_preparation_policy.dart';

/// Rasterises a camera original, applies decoder orientation and removes
/// original metadata before uploading. Originals are never stored remotely.
Future<Uint8List> prepareProfilePhoto(Uint8List bytes) async {
  PhotoPreparationPolicy.validateSource(bytes);
  try {
    return await platform.preparePhoto(bytes);
  } on PhotoPreparationException {
    rethrow;
  } catch (_) {
    throw PhotoPreparationPolicy.decodeError(bytes);
  }
}
