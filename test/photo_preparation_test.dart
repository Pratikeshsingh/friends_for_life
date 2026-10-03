import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/core/photo_preparation.dart';
import 'package:vriendtime/src/core/profile_photo_service.dart';

Future<Uint8List> sourcePng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF138B8A));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('camera original over 8 MB is resized before storage validation',
      () async {
    final png = await sourcePng(2400, 1200);
    // Valid PNG with trailing bytes: tests the old original-size rejection.
    final original = Uint8List(9 * 1024 * 1024)..setRange(0, png.length, png);
    final prepared = await prepareProfilePhoto(original);
    expect(ProfilePhotoService.hasSupportedImageSignature(prepared), isTrue);
    expect(ProfilePhotoService.isTooLarge(prepared), isFalse);
    expect(prepared.length, lessThan(1024 * 1024));
    final codec = await ui.instantiateImageCodec(prepared);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1024);
    expect(frame.image.height, 512);
    frame.image.dispose();
    codec.dispose();
  });
  test('portrait stays portrait and a small photo is not enlarged', () async {
    final result = await prepareProfilePhoto(await sourcePng(60, 120));
    final codec = await ui.instantiateImageCodec(result);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 60);
    expect(frame.image.height, 120);
    frame.image.dispose();
    codec.dispose();
  });
  test('empty and excessive originals fail with specific guidance', () async {
    await expectLater(
        prepareProfilePhoto(Uint8List(0)),
        throwsA(isA<PhotoPreparationException>()
            .having((e) => e.message, 'message', contains('read'))));
    await expectLater(
        prepareProfilePhoto(
            Uint8List(PhotoPreparationPolicy.maxSourceBytes + 1)),
        throwsA(isA<PhotoPreparationException>()
            .having((e) => e.message, 'message', contains('40 MB'))));
  });
  test('HEIF container is recognised regardless of filename', () {
    final data = Uint8List.fromList([
      0,
      0,
      0,
      24,
      ...'ftyp'.codeUnits,
      ...'mif1'.codeUnits,
      0,
      0,
      0,
      0,
      ...'heic'.codeUnits,
      0,
      0,
      0,
      0
    ]);
    expect(PhotoPreparationPolicy.isHeif(data), isTrue);
    expect(
        PhotoPreparationPolicy.isHeif(
            Uint8List.fromList('not an image'.codeUnits)),
        isFalse);
    expect(
        ProfilePhotoService.uploadErrorMessage(
            PhotoPreparationPolicy.decodeError(data)),
        contains('iPhone'));
  });
  test('corrupt photo is not misleadingly reported as a size problem',
      () async {
    await expectLater(
        prepareProfilePhoto(Uint8List.fromList('not an image'.codeUnits)),
        throwsA(isA<PhotoPreparationException>()
            .having((e) => e.message, 'message', contains('could not open'))));
    expect(
        ProfilePhotoService.genericUploadErrorMessage, isNot(contains('8 MB')));
  });
  test('pixel limits allow 48 MP camera photos but reject excessive allocation',
      () {
    expect(PhotoPreparationPolicy.outputSize(8064, 6048), (1024, 768));
    expect(() => PhotoPreparationPolicy.outputSize(12000, 12000),
        throwsA(isA<PhotoPreparationException>()));
  });
}
