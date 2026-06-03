import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/error_messages.dart';

/// Sends admin feedback replies by email via Cloud Functions (Nodemailer SMTP).
///
/// Tries [sendFeedbackReply] first; if that callable is not deployed yet, falls back to
/// [sendPasswordResetOtp] with `mode: feedbackReply` (same Cloud Run service as password reset).
class FeedbackReplyEmailService {
  FeedbackReplyEmailService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> sendFeedbackReply({
    required String feedbackId,
    required String subject,
    required String messageBody,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send replies.');
    }

    final adminEmail = user.email?.trim() ?? '';
    if (adminEmail.isEmpty) {
      throw StateError(
        'Your admin account has no email on file. Sign out and sign in again.',
      );
    }

    await user.getIdToken(true);

    final payload = <String, dynamic>{
      'feedbackId': feedbackId.trim(),
      'subject': subject.trim(),
      'messageBody': messageBody.trim(),
    };

    _log('sendFeedbackReply start', {
      'feedbackId': payload['feedbackId'],
      'subject': payload['subject'],
      'bodyLength': (payload['messageBody'] as String).length,
      'adminEmail': adminEmail,
    });

    try {
      await _invoke('sendFeedbackReply', payload);
      _log('sendFeedbackReply success via sendFeedbackReply', null);
      return;
    } catch (e) {
      if (!_shouldFallbackToOtpService(e)) {
        _log('sendFeedbackReply failed (no fallback)', e);
        rethrow;
      }
      _log('sendFeedbackReply not available, trying sendPasswordResetOtp fallback', e);
    }

    await _invoke('sendPasswordResetOtp', {
      'mode': 'feedbackReply',
      ...payload,
    });
    _log('sendFeedbackReply success via sendPasswordResetOtp fallback', null);
  }

  Future<void> _invoke(String name, Map<String, dynamic> data) async {
    _log('callable invoke', {'name': name, 'keys': data.keys.toList()});
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final result = await callable.call(data);
    _log('callable response', {
      'name': name,
      'data': result.data,
    });
  }

  /// True when [sendFeedbackReply] is missing or unreachable (deploy / CORS / region).
  static bool _shouldFallbackToOtpService(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = _normalizeCallableCode(e.code);
      final msg = (e.message ?? '').toLowerCase();
      if (code == 'not-found' || code == 'unavailable') return true;
      if (msg.contains('not found') && msg.contains('function')) return true;
      if (msg.contains('not_found')) return true;
    }
    final s = e.toString().toLowerCase();
    return s.contains('not_found') ||
        s.contains('not-found') ||
        s.contains('unavailable') ||
        (s.contains('function') && s.contains('not found'));
  }

  static String mapFunctionsError(Object e) {
    _log('mapFunctionsError', e);

    if (e is FirebaseFunctionsException) {
      final code = _normalizeCallableCode(e.code);
      final msg = e.message?.trim() ?? '';
      final details = e.details;

      if (kDebugMode && details != null) {
        debugPrint('[FeedbackReply] details: $details');
      }

      if (msg.isNotEmpty) {
        return _messageForCode(code, msg);
      }

      switch (code) {
        case 'unauthenticated':
          return 'You must be signed in as an admin to send replies.';
        case 'permission-denied':
          return 'Only admins can send feedback replies.';
        case 'not-found':
          return 'Feedback not found, or Cloud Function sendFeedbackReply is not deployed. '
              'Run: firebase deploy --only functions';
        case 'failed-precondition':
          return 'Email is not configured or the customer has no valid email. '
              'Set SMTP_* and deploy functions (see functions/README.md).';
        case 'invalid-argument':
          return 'Please check the reply form (subject and message are required).';
        case 'unavailable':
          return 'Email service is unavailable. Deploy Cloud Functions to us-central1 '
              'and check your network connection.';
        case 'internal':
          return 'The server could not send the email. Check SMTP settings in Cloud Functions '
              'logs (functions/README.md).';
        default:
          return 'Email error ($code). Deploy functions and configure SMTP.';
      }
    }

    if (e is StateError) {
      return e.message;
    }

    return toUserFriendlyMessage(e);
  }

  static String _messageForCode(String code, String msg) {
    final lower = msg.toLowerCase();
    if (code == 'not-found' &&
        (lower.contains('function') || lower.contains('not_found'))) {
      return 'Cloud Function sendFeedbackReply is not deployed. '
          'From the project root run: firebase deploy --only functions';
    }
    return msg;
  }

  static String _normalizeCallableCode(String code) {
    final lower = code.toLowerCase();
    final i = lower.lastIndexOf('/');
    if (i != -1 && i < lower.length - 1) {
      return lower.substring(i + 1);
    }
    return lower;
  }

  static void _log(String label, Object? data) {
    if (kDebugMode) {
      debugPrint('[FeedbackReply] $label: $data');
    }
  }
}
