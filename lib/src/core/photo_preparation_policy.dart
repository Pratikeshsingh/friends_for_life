import 'dart:typed_data';

/// Limits originals separately from the small, re-encoded storage upload.
class PhotoPreparationPolicy {
  static const maxSourceBytes = 40 * 1024 * 1024;
  static const maxPixels = 64 * 1000 * 1000;
  static const maxDimension = 12000;
  static const outputDimension = 1024;

  static void validateSource(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const PhotoPreparationException(
          'We could not read this photo. Please choose it again.');
    }
    if (bytes.length > maxSourceBytes) {
      throw const PhotoPreparationException(
          'This original photo is over 40 MB. Choose a smaller photo or a standard camera photo instead of RAW.');
    }
  }

  static (int, int) outputSize(int width, int height) {
    if (width < 1 ||
        height < 1 ||
        width > maxDimension ||
        height > maxDimension ||
        width * height > maxPixels) {
      throw const PhotoPreparationException(
          'This photo has unusually large dimensions. Please choose a standard camera photo.');
    }
    final longest = width > height ? width : height;
    if (longest <= outputDimension) return (width, height);
    final scale = outputDimension / longest;
    return (
      (width * scale).round().clamp(1, outputDimension),
      (height * scale).round().clamp(1, outputDimension)
    );
  }

  static bool isHeif(Uint8List bytes) {
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
      return false;
    }
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand == 'avif' || brand == 'avis') {
      return false;
    }
    final boxLength = ByteData.sublistView(bytes).getUint32(0);
    final end = boxLength.clamp(16, bytes.length < 256 ? bytes.length : 256);
    for (var offset = 8; offset + 4 <= end; offset += 4) {
      if (offset == 12) continue; // minor version, not a brand
      if (const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}
          .contains(String.fromCharCodes(bytes.sublist(offset, offset + 4)))) {
        return true;
      }
    }
    return false;
  }

  static PhotoPreparationException decodeError(Uint8List bytes) =>
      PhotoPreparationException(isHeif(bytes)
          ? 'This browser could not open the iPhone photo. Try opening VriendTime in Safari, or choose a JPEG copy.'
          : 'We could not open this photo. It may be incomplete or unsupported. Please choose another photo.');
}

class PhotoPreparationException implements Exception {
  const PhotoPreparationException(this.message);
  final String message;
  @override
  String toString() => message;
}
