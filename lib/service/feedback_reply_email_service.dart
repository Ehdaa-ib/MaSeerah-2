import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/error_messages.dart';
import '../util/callable_error_message.dart';

/// Sends admin feedback replies by email via Cloud Functions (Nodemailer SMTP).
///
/// Prefers [sendPasswordResetOtp] with `mode: feedbackReply` — that Cloud Run service
/// usually already has SMTP env vars. Falls back to [sendFeedbackReply].
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
    if (!_looksLikeEmail(adminEmail)) {
      throw StateError('Your admin account email is not valid: $adminEmail');
    }

    final fid = feedbackId.trim();
    final subj = subject.trim();
    final body = messageBody.trim();
    if (fid.isEmpty) throw StateError('Feedback id is missing.');
    if (subj.isEmpty) throw StateError('Subject is required.');
    if (body.isEmpty) throw StateError('Message body is required.');

    await user.getIdToken(true);

    final payload = <String, dynamic>{
      'feedbackId': fid,
      'subject': subj,
      'messageBody': body,
    };

    _log('sendFeedbackReply start', {
      'feedbackId': fid,
      'subject': subj,
      'bodyLength': body.length,
      'adminEmail': adminEmail,
    });

    Object? primaryError;
    try {
      await _invoke(
        'sendPasswordResetOtp',
        {'mode': 'feedbackReply', ...payload},
      );
      _log('success via sendPasswordResetOtp (feedbackReply mode)', null);
      return;
    } catch (e, st) {
      primaryError = e;
      _log('sendPasswordResetOtp feedbackReply failed', e);
      if (kDebugMode) debugPrint('[FeedbackReply] stack: $st');
      if (!_shouldTryDedicatedCallable(e)) {
        rethrow;
      }
    }

    try {
      await _invoke('sendFeedbackReply', payload);
      _log('success via sendFeedbackReply', null);
    } catch (e, st) {
      _log('sendFeedbackReply failed', e);
      if (kDebugMode) {
        debugPrint('[FeedbackReply] primary error: $primaryError');
        debugPrint('[FeedbackReply] stack: $st');
      }
      rethrow;
    }
  }

  Future<void> _invoke(String name, Map<String, dynamic> data) async {
    _log('callable invoke', {'name': name, 'keys': data.keys.toList()});
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final result = await callable.call(data);
    _log('callable response', {'name': name, 'data': result.data});
  }

  /// When to try [sendFeedbackReply] after [sendPasswordResetOtp] failed.
  static bool _shouldTryDedicatedCallable(Object e) {
    if (e is! FirebaseFunctionsException) return true;
    final code = _normalizeCode(e.code);
    final msg = messageFromCallableException(e).toLowerCase();

    if (code == 'permission-denied' || code == 'unauthenticated') {
      return false;
    }
    // Legacy OTP handler without feedbackReply mode.
    if (code == 'invalid-argument' && msg.contains('valid email')) {
      return true;
    }
    if (code == 'not-found' || code == 'unavailable') return true;
    // Same SMTP missing on both services — retry won't help.
    if (msg.contains('not configured') || msg.contains('smtp')) {
      return false;
    }
    return true;
  }

  static String mapFunctionsError(Object e, {bool includeDebugDetail = true}) {
    _log('mapFunctionsError', e);

    if (e is FirebaseFunctionsException) {
      final resolved = messageFromCallableException(e);
      if (kDebugMode && includeDebugDetail) {
        return '$resolved\n(code: ${_normalizeCode(e.code)})';
      }
      return resolved;
    }

    if (e is StateError) {
      return e.message;
    }

    return toUserFriendlyMessage(e);
  }

  static bool _looksLikeEmail(String s) =>
      s.contains('@') && s.contains('.') && s.length > 5;

  static String _normalizeCode(String code) {
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
