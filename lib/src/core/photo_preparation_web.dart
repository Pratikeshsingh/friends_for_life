import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'photo_preparation_policy.dart';

/// Use the browser's image decoder, rather than CanvasKit's narrower codecs.
/// WebKit supports iPhone HEIC/HEIF; canvas exports a standard JPEG for everyone.
Future<Uint8List> preparePhoto(Uint8List bytes) async {
  final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(
          type: PhotoPreparationPolicy.isHeif(bytes) ? 'image/heic' : ''));
  final url = web.URL.createObjectURL(blob);
  final image = web.HTMLImageElement();
  final canvas = web.HTMLCanvasElement();
  try {
    image.src = url;
    await image.decode().toDart.timeout(const Duration(seconds: 30));
    final (width, height) = PhotoPreparationPolicy.outputSize(
        image.naturalWidth, image.naturalHeight);
    canvas.width = width;
    canvas.height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.fillStyle = '#ffffff'.toJS;
    context.fillRect(0, 0, width.toDouble(), height.toDouble());
    context.drawImage(image, 0, 0, width.toDouble(), height.toDouble());
    final encoded = Completer<web.Blob>();
    canvas.toBlob(
        ((web.Blob? value) {
          if (value == null) {
            encoded.completeError(const PhotoPreparationException(
                'We could not prepare this photo. Please try another photo.'));
          } else {
            encoded.complete(value);
          }
        }).toJS,
        'image/jpeg',
        0.85.toJS);
    final output = await encoded.future.timeout(const Duration(seconds: 30));
    return (await output.arrayBuffer().toDart).toDart.asUint8List();
  } finally {
    image.src = '';
    web.URL.revokeObjectURL(url);
    canvas.width = 0;
    canvas.height = 0;
  }
}
