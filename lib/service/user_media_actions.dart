import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Download, share, and save user photos (FR-35).
class UserMediaActions {
  UserMediaActions._();

  static Future<Uint8List?> fetchImageBytes(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return null;
    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  }

  static String fileExtensionForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'png';
    if (lower.contains('.webp')) return 'webp';
    if (lower.contains('.gif')) return 'gif';
    return 'jpg';
  }

  static Future<File> writeTempImageFile(
    Uint8List bytes, {
    required String url,
    String prefix = 'maseerah',
  }) async {
    final dir = await getTemporaryDirectory();
    final ext = fileExtensionForUrl(url);
    final path =
        '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the system share sheet (image file on mobile, URL on web).
  static Future<void> shareImage({required String url, String? caption}) async {
    if (kIsWeb) {
      await Share.share(url, subject: caption);
      return;
    }
    final bytes = await fetchImageBytes(url);
    if (bytes == null) throw const UserMediaActionException('download');
    final file = await writeTempImageFile(bytes, url: url);
    await Share.shareXFiles([XFile(file.path)], text: caption);
  }

  /// Saves image to the device photo gallery (mobile/desktop via gal).
  static Future<void> saveToGallery(String url) async {
    if (kIsWeb) {
      throw const UserMediaActionException('unsupported');
    }
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    if (!await Gal.hasAccess()) {
      throw const UserMediaActionException('permission');
    }
    final bytes = await fetchImageBytes(url);
    if (bytes == null) throw const UserMediaActionException('download');
    final file = await writeTempImageFile(bytes, url: url);
    await Gal.putImage(file.path);
  }
}

class UserMediaActionException implements Exception {
  const UserMediaActionException(this.code);
  final String code;
}
