import '../../core/email_validation.dart';
import '../../core/validators.dart';
import '../../model/app_user.dart';
import '../../repository/auth_repo.dart';
import '../../service/password_reset_otp_service.dart';
import '../firebase/auth_data_source.dart';

class AuthRepositoryFirebase implements AuthRepository {
  final AuthDataSource _dataSource;
  final PasswordResetOtpService _passwordResetOtp;

  AuthRepositoryFirebase(
    this._dataSource, {
    PasswordResetOtpService? passwordResetOtpService,
  }) : _passwordResetOtp = passwordResetOtpService ?? PasswordResetOtpService();

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

    try {
      await _passwordResetOtp.sendPasswordResetOtp(email.trim());
    } catch (e) {
      throw Exception(PasswordResetOtpService.mapFunctionsError(e));
    }
  }

  @override
  Future<void> verifyPasswordResetCode(String email, String code) async {
    final formatErr = EmailValidation.validateFormat(email);
    if (formatErr != null) throw Exception(formatErr);
    final c = code.trim();
    if (c.length != 6 || int.tryParse(c) == null) {
      throw Exception('Enter the 6-digit code from your email.');
    }
    try {
      await _passwordResetOtp.verifyPasswordResetOtp(email, c);
    } catch (e) {
      throw Exception(PasswordResetOtpService.mapFunctionsError(e));
    }
  }

  @override
  Future<AppUser> completePasswordResetAndSignIn({
    required String email,
    required String verificationCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    final c = verificationCode.trim();
    if (c.length != 6) {
      throw Exception('Enter the 6-digit verification code.');
    }
    try {
      await _passwordResetOtp.resetPasswordWithOtp(
        email: email.trim(),
        code: c,
        newPassword: newPassword,
      );
    } catch (e) {
      throw Exception(PasswordResetOtpService.mapFunctionsError(e));
    }
    return _dataSource.login(email: email.trim(), password: newPassword);
  }
}
