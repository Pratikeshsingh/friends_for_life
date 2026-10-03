import 'dart:typed_data';
import 'photo_preparation_policy.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePhotoService {
  static const bucketName = 'profile-photos';
  static const maxUploadBytes = 8 * 1024 * 1024;
  static const maxUploadLabel = '8 MB';
  static const supportedFormatsLabel = 'JPG, PNG or WebP';
  static const genericUploadErrorMessage =
      "We couldn't upload your photo. Please try again. Your current photo has not changed.";
  static final Map<String, _SignedUrlCacheEntry> _signedUrlCache = {};

  static Future<String> uploadPhoto({
    required SupabaseClient supabase,
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String slot,
  }) async {
    if (isTooLarge(bytes) || !hasSupportedImageSignature(bytes)) {
      throw ArgumentError('Choose a JPG, PNG or WebP up to $maxUploadLabel.');
    }
    final isPng = bytes[0] == 0x89;
    final isJpeg = bytes[0] == 0xFF;
    final extension = isPng
        ? '.png'
        : isJpeg
            ? '.jpg'
            : '.webp';
    final contentType = isPng
        ? 'image/png'
        : isJpeg
            ? 'image/jpeg'
            : 'image/webp';
    final path =
        '$userId/$slot-${DateTime.now().millisecondsSinceEpoch}$extension';

    await supabase.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );

    return path;
  }

  static Future<Uint8List?> downloadPhoto({
    required SupabaseClient supabase,
    required String? path,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    return supabase.storage.from(bucketName).download(path);
  }

  static Future<String?> createSignedPhotoUrl({
    required SupabaseClient supabase,
    required String? path,
    int expiresInSeconds = 60 * 10,
    bool forceRefresh = false,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    final cached = _signedUrlCache[path];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.url;
    }

    final url = await supabase.storage
        .from(bucketName)
        .createSignedUrl(path, expiresInSeconds);
    final refreshSeconds =
        (expiresInSeconds - 30).clamp(1, expiresInSeconds).toInt();
    _signedUrlCache[path] = _SignedUrlCacheEntry(
      url: url,
      expiresAt: DateTime.now().add(
        Duration(seconds: refreshSeconds),
      ),
    );
    return url;
  }

  static void invalidateSignedPhotoUrl(String? path) {
    if (path == null || path.isEmpty) return;
    _signedUrlCache.remove(path);
  }

  static bool isBucketMissing(Object error) {
    if (error is! StorageException) {
      return false;
    }

    final message = error.message.toLowerCase();
    return message.contains('bucket not found') ||
        message.contains('not found');
  }

  static bool isTooLarge(Uint8List bytes) {
    return bytes.lengthInBytes > maxUploadBytes;
  }

  static bool hasSupportedImageSignature(Uint8List bytes) {
    if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
      return true;
    }

    if (_startsWith(
      bytes,
      const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    )) {
      return true;
    }

    return bytes.lengthInBytes >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.lengthInBytes < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }

  static String fileSizeLabel(int bytes) {
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    }

    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
  }

  static String tooLargeMessage(int bytes) {
    return 'That photo is ${fileSizeLabel(bytes)}. Choose a photo up to $maxUploadLabel.';
  }

  static bool isUploadTooLargeError(Object error) {
    if (error is! StorageException) {
      return false;
    }

    final message = error.message.toLowerCase();
    return message.contains('too large') ||
        message.contains('maximum') ||
        message.contains('exceeded') ||
        message.contains('payload') ||
        message.contains('entity too large') ||
        message.contains('413');
  }

  static String uploadErrorMessage(Object error) {
    if (error is PhotoPreparationException) return error.message;
    if (isBucketMissing(error)) {
      return 'Photo uploads are temporarily unavailable. Your current photo has not changed.';
    }

    if (isUploadTooLargeError(error)) {
      return 'We could not reduce this photo enough to upload it. Please choose another photo.';
    }

    if (error is! StorageException) {
      return genericUploadErrorMessage;
    }

    final statusCode = int.tryParse(error.statusCode ?? '');
    final details = '${error.message} ${error.error ?? ''}'.toLowerCase();

    if (statusCode == 401 ||
        statusCode == 403 ||
        details.contains('unauthorized') ||
        details.contains('jwt') ||
        details.contains('row-level security') ||
        details.contains('permission')) {
      return 'Your photo upload permission has expired. Sign in again, then retry; your current photo is unchanged.';
    }

    if (statusCode == 415 ||
        details.contains('mime') ||
        details.contains('content type') ||
        details.contains('unsupported')) {
      return 'Photo storage could not accept the prepared image. Please try again or contact support.';
    }

    if ((statusCode != null && statusCode >= 500) ||
        details.contains('service unavailable') ||
        details.contains('internal server')) {
      return 'Photo uploads are temporarily unavailable. Your current photo is unchanged; try again later.';
    }

    if (details.contains('network') ||
        details.contains('socket') ||
        details.contains('timeout') ||
        details.contains('connection')) {
      return 'The upload was interrupted. Check your connection and try again; your current photo is unchanged.';
    }

    return genericUploadErrorMessage;
  }
}

class _SignedUrlCacheEntry {
  const _SignedUrlCacheEntry({
    required this.url,
    required this.expiresAt,
  });

  final String url;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}
