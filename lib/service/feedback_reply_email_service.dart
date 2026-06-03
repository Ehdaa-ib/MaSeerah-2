import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/error_messages.dart';

/// Sends admin feedback replies by email via Cloud Functions (SMTP on server).
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
    await user.getIdToken(true);

    final callable = _functions.httpsCallable('sendFeedbackReply');
    await callable.call(<String, dynamic>{
      'feedbackId': feedbackId.trim(),
      'subject': subject.trim(),
      'messageBody': messageBody.trim(),
    });
  }

  static String mapFunctionsError(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = _normalizeCallableCode(e.code);
      final msg = e.message?.trim() ?? '';
      switch (code) {
        case 'unauthenticated':
          return msg.isNotEmpty
              ? msg
              : 'You must be signed in as an admin to send replies.';
        case 'permission-denied':
          return msg.isNotEmpty ? msg : 'Only admins can send feedback replies.';
        case 'not-found':
          return msg.isNotEmpty ? msg : 'Feedback not found.';
        case 'failed-precondition':
          return msg.isNotEmpty
              ? msg
              : 'Could not find a valid email for this customer.';
        case 'invalid-argument':
          return msg.isNotEmpty ? msg : 'Please check the reply form.';
        case 'unavailable':
        case 'internal':
          return _isPlausibleUserFacingMessage(msg)
              ? msg
              : 'Could not send the email. Deploy Functions, configure SMTP, or try again.';
        default:
          return msg.isNotEmpty ? msg : toUserFriendlyMessage(e);
      }
    }
    return toUserFriendlyMessage(e);
  }

  static String _normalizeCallableCode(String code) {
    final lower = code.toLowerCase();
    final i = lower.lastIndexOf('/');
    if (i != -1 && i < lower.length - 1) {
      return lower.substring(i + 1);
    }
    return lower;
  }

  static bool _isPlausibleUserFacingMessage(String msg) {
    final t = msg.trim();
    if (t.length < 12) return false;
    if (!t.contains(' ') && !t.contains('.')) return false;
    return true;
  }
}
