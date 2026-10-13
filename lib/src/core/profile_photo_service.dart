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

  /// Links being fetched right now, so a second ask waits for the first
  /// instead of sending another request.
  static final Map<String, Future<String?>> _inFlight = {};

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

  /// Photo links last an hour: long enough that the browser can reuse a
  /// downloaded photo across screens and refreshes (a new link means a new
  /// download), short enough that a shared link soon stops working.
  static const signedUrlSeconds = 60 * 60;

  /// Links for many photos in one request instead of one request each.
  /// Fills the same cache [createSignedPhotoUrl] reads; returns path → link.
  static Future<Map<String, String>> createSignedPhotoUrls({
    required SupabaseClient supabase,
    required Iterable<String?> paths,
  }) async {
    final wanted = {
      for (final p in paths)
        if (p != null && p.isNotEmpty) p
    };
    final result = <String, String>{};
    final missing = <String>[];
    final waiting = <String, Future<String?>>{};
    for (final p in wanted) {
      final cached = _signedUrlCache[p];
      if (cached != null && !cached.isExpired) {
        result[p] = cached.url;
      } else if (_inFlight[p] != null) {
        waiting[p] = _inFlight[p]!;
      } else {
        missing.add(p);
      }
    }
    if (missing.isNotEmpty) {
      final batch = supabase.storage
          .from(bucketName)
          .createSignedUrls(missing, signedUrlSeconds)
          .then((signed) {
        final expiresAt =
            DateTime.now().add(const Duration(seconds: signedUrlSeconds - 300));
        final urls = <String, String>{};
        for (final s in signed) {
          if (s.signedUrl.isEmpty) continue;
          urls[s.path] = s.signedUrl;
          _signedUrlCache[s.path] =
              _SignedUrlCacheEntry(url: s.signedUrl, expiresAt: expiresAt);
        }
        return urls;
      });
      for (final p in missing) {
        final one = batch.then<String?>((urls) => urls[p]);
        _inFlight[p] = one;
        waiting[p] = one;
      }
      batch.whenComplete(() => missing.forEach(_inFlight.remove)).ignore();
    }
    for (final e in waiting.entries) {
      final url = await e.value;
      if (url != null) result[e.key] = url;
    }
    return result;
  }

  static Future<String?> createSignedPhotoUrl({
    required SupabaseClient supabase,
    required String? path,
    int expiresInSeconds = signedUrlSeconds,
    bool forceRefresh = false,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    final cached = _signedUrlCache[path];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.url;
    }
    final pending = _inFlight[path];
    if (!forceRefresh && pending != null) {
      final url = await pending;
      if (url != null) return url;
    }

    final url = await supabase.storage
        .from(bucketName)
        .createSignedUrl(path, expiresInSeconds);
    final refreshSeconds =
        (expiresInSeconds - 300).clamp(1, expiresInSeconds).toInt();
    _signedUrlCache[path] = _SignedUrlCacheEntry(
      url: url,
      expiresAt: DateTime.now().add(
        Duration(seconds: refreshSeconds),
      ),
    );
    return url;
  }

  /// A link already fetched and still valid, without any request.
  static String? cachedSignedPhotoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final cached = _signedUrlCache[path];
    return cached == null || cached.isExpired ? null : cached.url;
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

    // A refusal by the storage rules (row-level security) arrives with a
    // perfectly good session, so it must not tell people to sign in again;
    // that sent them in a loop. Only an expired or invalid session does.
    if (details.contains('row-level security') || details.contains('policy')) {
      return 'Photo storage didn’t accept this upload. Your current photo is unchanged. If it keeps happening, contact us through Help & contact.';
    }

    if (statusCode == 401 ||
        details.contains('jwt') ||
        details.contains('expired') ||
        details.contains('invalid token')) {
      return 'Your session has expired. Sign in again, then retry; your current photo is unchanged.';
    }

    if (statusCode == 403 ||
        details.contains('unauthorized') ||
        details.contains('permission')) {
      return 'Photo storage didn’t accept this upload. Your current photo is unchanged. If it keeps happening, contact us through Help & contact.';
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
