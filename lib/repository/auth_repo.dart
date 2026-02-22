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
}
