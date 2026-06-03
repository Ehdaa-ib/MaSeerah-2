import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Extracts a user-visible message from a [FirebaseFunctionsException].
/// Callable errors often return message `"internal"` while the real text is in [FirebaseFunctionsException.details].
String messageFromCallableException(FirebaseFunctionsException e) {
  final code = _normalizeCallableCode(e.code);
  final rawMsg = e.message?.trim() ?? '';
  final fromDetails = _messageFromDetails(e.details);

  if (kDebugMode) {
    debugPrint(
      '[CallableError] code=$code message=$rawMsg details=${e.details} '
      'plugin=${e.plugin}',
    );
  }

  String msg = rawMsg;
  if (_isGenericCallableText(msg)) {
    msg = fromDetails;
  }
  if (_isGenericCallableText(msg) && fromDetails.isNotEmpty && fromDetails != msg) {
    msg = fromDetails;
  }

  if (msg.isNotEmpty && !_isGenericCallableText(msg)) {
    return msg;
  }

  if (fromDetails.isNotEmpty && !_isGenericCallableText(fromDetails)) {
    return fromDetails;
  }

  return _defaultForCode(code);
}

bool _isGenericCallableText(String s) {
  final m = s.trim().toLowerCase();
  if (m.isEmpty) return true;
  return m == 'internal' ||
      m == 'unknown' ||
      m == 'unavailable' ||
      m == 'not_found' ||
      m == 'not-found' ||
      m == 'deadline-exceeded' ||
      m == 'permission-denied' ||
      m == 'unauthenticated' ||
      m == 'failed-precondition' ||
      m == 'invalid-argument' ||
      m == 'resource-exhausted';
}

String _messageFromDetails(Object? details) {
  if (details == null) return '';
  if (details is String) return details.trim();
  if (details is Map) {
    final message = details['message'] ?? details['error'] ?? details['status'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  final s = details.toString().trim();
  if (s.startsWith('{') && s.length > 80) return '';
  return s;
}

String _normalizeCallableCode(String code) {
  final lower = code.toLowerCase();
  final i = lower.lastIndexOf('/');
  if (i != -1 && i < lower.length - 1) {
    return lower.substring(i + 1);
  }
  return lower;
}

String _defaultForCode(String code) {
  switch (code) {
    case 'unauthenticated':
      return 'You must be signed in.';
    case 'permission-denied':
      return 'You do not have permission for this action.';
    case 'not-found':
      return 'The requested resource was not found.';
    case 'failed-precondition':
      return 'This action cannot be completed yet. Check configuration and try again.';
    case 'invalid-argument':
      return 'Invalid input. Please check the form and try again.';
    case 'unavailable':
      return 'Service is temporarily unavailable. Try again later.';
    case 'internal':
      return 'A server error occurred. Check Cloud Functions logs and SMTP configuration.';
    default:
      return 'Something went wrong ($code). Please try again.';
  }
}
