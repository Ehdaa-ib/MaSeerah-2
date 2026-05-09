import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchRecommendationLocationUrl(
  BuildContext context,
  String locationUrl, {
  bool showErrors = true,
}) async {
  final t = locationUrl.trim();
  if (t.isEmpty) {
    if (showErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location link is available for this place.')),
      );
    }
    return false;
  }
  final uri = Uri.tryParse(t);
  final ok = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  if (!ok) {
    if (showErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The location link is not valid.')),
      );
    }
    return false;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && showErrors && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps / browser.')),
      );
    }
    return launched;
  } catch (_) {
    if (showErrors && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps / browser.')),
      );
    }
    return false;
  }
}
