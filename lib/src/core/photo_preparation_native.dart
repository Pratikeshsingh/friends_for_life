import 'dart:typed_data';
import 'dart:ui' as ui;
import 'photo_preparation_policy.dart';

Future<Uint8List> preparePhoto(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final (width, height) =
        PhotoPreparationPolicy.outputSize(descriptor.width, descriptor.height);
    codec = await descriptor.instantiateCodec(
        targetWidth: width, targetHeight: height);
    image = (await codec.getNextFrame()).image;
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) {
      throw const PhotoPreparationException(
          'We could not prepare this photo. Please try another photo.');
    }
    return encoded.buffer
        .asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
