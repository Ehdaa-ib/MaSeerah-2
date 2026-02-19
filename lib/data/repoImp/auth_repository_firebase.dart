import '../../core/validators.dart';
import '../../model/app_user.dart';
import '../../repository/auth_repo.dart';
import '../firebase/auth_data_source.dart';

class AuthRepositoryFirebase implements AuthRepository {
  final AuthDataSource _dataSource;

  AuthRepositoryFirebase(this._dataSource);

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (!Validators.validateEmail(email)) {
      throw Exception("Invalid email format");
    }
    if (password.isEmpty) {
      throw Exception("Password is required");
    }
    return _dataSource.login(email: email, password: password);
  }

  @override
  Future<void> logout() async {
    await _dataSource.logout();
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception("Name is required");
    }
    if (!Validators.validateEmail(email)) {
      throw Exception("Invalid email format");
    }
    if (password.length < 6) {
      throw Exception("Password must be at least 6 characters");
    }
    if (password != confirmPassword) {
      throw Exception("Password and confirm password do not match");
    }

    final role = Validators.roleFromEmail(email);

    return _dataSource.register(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }
}
