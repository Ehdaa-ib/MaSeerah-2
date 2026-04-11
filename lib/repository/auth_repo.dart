import '../model/app_user.dart';

abstract class AuthRepository {
  /// Signs in with email and password. Returns user profile (role from Firestore).
  Future<AppUser> login({
    required String email,
    required String password,
  });

  /// Signs out the current user.
  Future<void> logout();

  /// Registers a new account. Role is derived from email:
  /// Whitelisted admin emails → admin (routed to admin dashboard), otherwise → user (routed to user page).
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  });

  /// Sends a 6-digit password-reset OTP by email (Cloud Functions + SMTP).
  Future<void> sendPasswordResetEmail(String email);

  /// Verifies the OTP for [email] (does not change password yet).
  Future<void> verifyPasswordResetCode(String email, String code);

  /// Confirms OTP, sets [newPassword] in Firebase Auth, then signs in and returns profile.
  Future<AppUser> completePasswordResetAndSignIn({
    required String email,
    required String verificationCode,
    required String newPassword,
  });
}
