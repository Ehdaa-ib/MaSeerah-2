import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads profile pictures to `profilePhotos/{userId}/{fileName}`.
class ProfilePhotoDataSource {
  ProfilePhotoDataSource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return '.jpg';
    return path.substring(dot).toLowerCase();
  }

  static String _contentTypeForPath(String path) {
    switch (_extensionFromPath(path)) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// Returns download URL after upload.
  Future<String> uploadProfilePhoto({
    required String userId,
    required XFile file,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) throw Exception('Not signed in');

    final bytes = await file.readAsBytes();
    final ext = _extensionFromPath(file.path);
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';

    final ref = _storage.ref().child('profilePhotos').child(uid).child(name);

    try {
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentTypeForPath(file.path)),
      );
      final url = await snapshot.ref.getDownloadURL();
      if (kDebugMode) debugPrint('[ProfilePhoto] upload ok uid=$uid');
      return url;
    } on FirebaseException catch (e) {
      final code = e.code;
      if (code == 'unauthorized' || code == 'permission-denied') {
        throw Exception(
          'Photo upload blocked by Storage rules. Deploy updated `storage.rules` and try again.',
        );
      }
      throw Exception('Photo upload failed ($code): ${e.message ?? ''}'.trim());
    }
  }
}
