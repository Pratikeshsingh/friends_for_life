import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePhotoService {
  static const bucketName = 'profile-photos';
  static const maxUploadBytes = 8 * 1024 * 1024;
  static const maxUploadLabel = '8 MB';
  static final Map<String, _SignedUrlCacheEntry> _signedUrlCache = {};

  static Future<String> uploadPhoto({
    required SupabaseClient supabase,
    required String userId,
    required Uint8List bytes,
    required String fileName,
    required String slot,
  }) async {
    final extension = _safeExtension(fileName);
    final path =
        '$userId/$slot-${DateTime.now().millisecondsSinceEpoch}$extension';

    await supabase.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
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

  static String _safeExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }

    final extension = fileName.substring(dotIndex).toLowerCase();
    final validPattern = RegExp(r'^\.[a-z0-9]+$');
    return validPattern.hasMatch(extension) ? extension : '';
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
    return 'That photo is ${fileSizeLabel(bytes)}. Choose a photo under $maxUploadLabel.';
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
