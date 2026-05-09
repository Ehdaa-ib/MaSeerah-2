import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps (app or browser) with walking directions to a landmark.
class LandmarkMapsLaunchService {
  LandmarkMapsLaunchService._();

  static Future<bool> openWalkingDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking',
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
