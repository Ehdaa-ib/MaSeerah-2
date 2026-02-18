import '../../core/validators.dart';
import '../../model/app_user.dart';
import '../../repository/auth_repo.dart';
import '../firebase/auth_data_source.dart';

class AuthRepositoryFirebase implements AuthRepository {
  final AuthDataSource _dataSource;

  AuthRepositoryFirebase(this._dataSource);

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    String role = "user",
  }) async {
    // validateEmail()
    if (!Validators.validateEmail(email)) {
      throw Exception("Invalid email format");
    }

    // basic password rule (Firebase requires at least 6)
    if (password.length < 6) {
      throw Exception("Password must be at least 6 characters");
    }

    if (name.trim().isEmpty) {
      throw Exception("Name is required");
    }

    // call Firebase datasource register()
    return _dataSource.register(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }
}
