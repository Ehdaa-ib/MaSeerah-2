import '../model/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    String role = "user",
  });
}
