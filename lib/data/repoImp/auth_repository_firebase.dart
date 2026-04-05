import '../../core/email_validation.dart';
import '../../core/password_reset_link_parser.dart';
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
    final regDisposable = EmailValidation.validateNotDisposable(email);
    if (regDisposable != null) throw Exception(regDisposable);
    final regMx = await EmailValidation.validateDomainReceivesMail(
      email,
      strict: true,
    );
    if (regMx != null) throw Exception(regMx);

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

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final formatErr = EmailValidation.validateFormat(email);
    if (formatErr != null) throw Exception(formatErr);

    final disposableErr = EmailValidation.validateNotDisposable(email);
    if (disposableErr != null) throw Exception(disposableErr);

    final mxErr = await EmailValidation.validateDomainReceivesMail(
      email,
      strict: false,
    );
    if (mxErr != null) throw Exception(mxErr);

    await _dataSource.sendPasswordResetEmail(email.trim());
  }

  @override
  Future<({String email, String oobCode})> verifyPasswordResetLinkOrCode(
    String linkOrCode,
  ) async {
    final oob = extractOobCodeFromPasswordResetInput(linkOrCode);
    if (oob == null || oob.isEmpty) {
      throw Exception(
        'Paste the reset link from your email or the code from that link.',
      );
    }
    final email = await _dataSource.verifyPasswordResetOobCode(oob);
    return (email: email, oobCode: oob);
  }

  @override
  Future<AppUser> completePasswordResetAndSignIn({
    required String email,
    required String oobCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    final code = extractOobCodeFromPasswordResetInput(oobCode);
    if (code == null || code.isEmpty) {
      throw Exception('Invalid reset code.');
    }
    await _dataSource.confirmPasswordReset(
      oobCode: code,
      newPassword: newPassword,
    );
    return _dataSource.login(email: email.trim(), password: newPassword);
  }
}
