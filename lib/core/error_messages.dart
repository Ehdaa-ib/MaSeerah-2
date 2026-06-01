import 'package:firebase_auth/firebase_auth.dart';

/// Converts exceptions (e.g. Firebase auth, generic) to short, user-friendly
/// messages without technical codes like [firebase_auth/invalid-email].
String toUserFriendlyMessage(dynamic e) {
  if (e == null) return 'Something went wrong. Please try again.';

  if (e is FirebaseAuthException) {
    final message = e.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    return _firebaseAuthMessageForCode(e.code);
  }

  final str = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
  if (_isFirestorePermissionDenied(str)) {
    return 'Payment could not be saved. Ask your admin to deploy the latest Firestore rules, then try again.';
  }
  if (_isNetworkError(str)) {
    return 'No internet connection. Please check your network and try again.';
  }
  // Strip "[code] " prefix so we don't show e.g. [firebase_auth/invalid-email]
  final bracketEnd = str.indexOf('] ');
  if (bracketEnd != -1 && bracketEnd < str.length - 2) {
    final rest = str.substring(bracketEnd + 2).trim();
    if (_isUnhelpfulFunctionsClientText(rest)) {
      return _cloudFunctionsGenericHint;
    }
    return rest;
  }
  final trimmed = str.trim();
  if (trimmed.isNotEmpty) {
    if (_isUnhelpfulFunctionsClientText(trimmed)) {
      return _cloudFunctionsGenericHint;
    }
    return trimmed;
  }
  return 'Something went wrong. Please try again.';
}

const String _cloudFunctionsGenericHint =
    'The app could not complete this action. Cloud Functions may be missing '
    'or need billing. Deploy to us-central1 (see functions/README.md).';

bool _isUnhelpfulFunctionsClientText(String s) {
  final m = s.toLowerCase();
  return m == 'internal' ||
      m == 'unknown' ||
      m == 'not_found' ||
      m == 'not-found' ||
      m == 'unavailable';
}

String _firebaseAuthMessageForCode(String code) {
  switch (code) {
    case 'invalid-email':
      return 'The email address is badly formatted.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
      return 'No account found with this email.';
    case 'wrong-password':
      return 'Incorrect password.';
    case 'email-already-in-use':
      return 'This email is already registered.';
    case 'weak-password':
      return 'Password is too weak. Please use at least 6 characters.';
    case 'invalid-credential':
      return 'Invalid email or password.';
    case 'invalid-verification-code':
      return 'Invalid verification code.';
    case 'invalid-verification-id':
      return 'Verification link expired. Please try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled.';
    case 'requires-recent-login':
      return 'Please sign in again to continue.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

bool _isFirestorePermissionDenied(String str) {
  final lower = str.toLowerCase();
  return lower.contains('permission_denied') ||
      lower.contains('permission-denied') ||
      lower.contains('missing or insufficient permissions');
}

/// Whether the exception looks like a network/connectivity error.
bool _isNetworkError(String str) {
  final lower = str.toLowerCase();
  return lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('socket') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('no internet') ||
      lower.contains('internet');
}
