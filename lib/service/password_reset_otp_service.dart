import 'package:cloud_functions/cloud_functions.dart';

import '../core/error_messages.dart';

/// Callable Cloud Functions for email OTP password reset (region must match deployment).
///
/// Replaces Firebase Auth's password-reset **link** flow; OTP is sent via SMTP from Functions.
class PasswordResetOtpService {
  PasswordResetOtpService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> sendPasswordResetOtp(String email) async {
    final callable = _functions.httpsCallable('sendPasswordResetOtp');
    await callable.call(<String, dynamic>{'email': email.trim()});
  }

  Future<void> verifyPasswordResetOtp(String email, String code) async {
    final callable = _functions.httpsCallable('verifyPasswordResetOtp');
    await callable.call(<String, dynamic>{
      'email': email.trim(),
      'code': code.trim(),
    });
  }

  Future<void> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final callable = _functions.httpsCallable('resetPasswordWithOtp');
    await callable.call(<String, dynamic>{
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }

  static String mapFunctionsError(Object e) {
    if (e is FirebaseFunctionsException) {
      final code = _normalizeCallableCode(e.code);
      final msg = e.message?.trim() ?? '';
      switch (code) {
        case 'not-found':
          return msg.isNotEmpty
              ? msg
              : 'No account found with this email.';
        case 'permission-denied':
          return msg.isNotEmpty ? msg : 'Incorrect code.';
        case 'deadline-exceeded':
          return msg.isNotEmpty ? msg : 'This code has expired. Request a new one.';
        case 'resource-exhausted':
          return msg.isNotEmpty ? msg : 'Please wait before trying again.';
        case 'failed-precondition':
          return msg.isNotEmpty ? msg : 'Complete the previous step first.';
        case 'invalid-argument':
          return msg.isNotEmpty ? msg : 'Invalid input.';
        case 'unavailable':
        case 'internal':
          return _isPlausibleUserFacingMessage(msg)
              ? msg
              : 'Password reset service failed. Deploy Functions, set OTP_PEPPER and SMTP, '
                  'or try again later.';
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
