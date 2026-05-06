import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePhotoService {
  static const bucketName = 'profile-photos';
  static const maxUploadBytes = 8 * 1024 * 1024;
  static const maxUploadLabel = '8 MB';

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
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    return supabase.storage
        .from(bucketName)
        .createSignedUrl(path, expiresInSeconds);
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
