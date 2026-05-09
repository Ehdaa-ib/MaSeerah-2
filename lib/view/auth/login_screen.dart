import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/error_messages.dart';
import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../faq/faqs_page.dart';
import 'forget_password_page.dart';
import 'create_account_screen.dart';
import '../home/landing_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    /// When true, successful sign-in pops this route with `true` instead of navigating home
    /// (e.g. user opened login from journey purchase and should return there).
    this.returnToCallerOnSuccess = false,
    /// Guest flow from main bottom nav (Profile): hide app-bar back; use [authBottomNav] only.
    this.hideBackButton = false,
    /// Same bottom bar as landing (Home / Active Journeys / Profile). Omit for modal flows (e.g. purchase).
    this.authBottomNav,
  });

  final bool returnToCallerOnSuccess;
  final bool hideBackButton;
  final Widget? authBottomNav;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final TapGestureRecognizer _faqTapRecognizer;
  late final TapGestureRecognizer _contactTapRecognizer;

  static final Uri _supportMailto = Uri(
    scheme: 'mailto',
    path: 'MaSeerah.help@gmail.com',
  );

  @override
  void initState() {
    super.initState();
    _faqTapRecognizer = TapGestureRecognizer()..onTap = _onFaqTap;
    _contactTapRecognizer = TapGestureRecognizer()..onTap = _onContactUsTap;
  }

  @override
  void dispose() {
    _faqTapRecognizer.dispose();
    _contactTapRecognizer.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFaqTap() {
    if (_isLoading) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FaqsPage()),
    );
  }

  Future<void> _onContactUsTap() async {
    if (_isLoading) return;
    try {
      final launched = await launchUrl(
        _supportMailto,
        mode: LaunchMode.platformDefault,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app.')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final repo = AuthRepositoryFirebase(AuthDataSource());
      final user = await repo.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.returnToCallerOnSuccess) {
          Navigator.of(context).pop(true);
          return;
        }
        final role = user.role.trim().toLowerCase();
        if (role == 'admin') {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.of(context).pushReplacementNamed('/admin');
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingPage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = toUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _goToCreateAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateAccountScreen(
          hideBackButton: widget.hideBackButton,
          authBottomNav: widget.authBottomNav,
        ),
      ),
    );
  }

  void _handleBack() {
    if (_isLoading) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: widget.authBottomNav,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.hideBackButton)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.brown),
                    tooltip: 'Back',
                    onPressed: _handleBack,
                  ),
                )
              else
                const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Transform.translate(
                      offset: const Offset(0, -8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'images/name.png',
                            width: 128,
                            height: 128,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.95,
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height * 0.62,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            decoration: BoxDecoration(
                              color: AppColors.beige.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome Back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to start your walk',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.brown.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 40),
                            
                            Text(
                              'Email',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: AppColors.brown,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your email',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: AppColors.brown,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Colors.grey.shade700,
                                  size: 22,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: AppColors.brown,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade700,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: AppColors.brown,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey.shade700,
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey.shade700,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Password is required';
                                return null;
                              },
                            ),
                            
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () {Navigator.of(context).push( MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),);},
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.brown.withOpacity(0.8),
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.brown.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 30), 
                            
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brown,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 3,
                                shadowColor: AppColors.brown.withOpacity(0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                            
                            const SizedBox(height: 25),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.brown.withOpacity(0.7),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _isLoading ? null : _goToCreateAccount,
                                  child: Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.brown,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.brown.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: AppColors.brown.withOpacity(0.7),
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'Do you have questions? Check ',
                                  ),
                                  TextSpan(
                                    text: 'FAQs',
                                    style: TextStyle(
                                      color: AppColors.brown,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor:
                                          AppColors.brown.withOpacity(0.4),
                                    ),
                                    recognizer: _faqTapRecognizer,
                                  ),
                                  const TextSpan(text: ' or '),
                                  TextSpan(
                                    text: 'contact us',
                                    style: TextStyle(
                                      color: AppColors.brown,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor:
                                          AppColors.brown.withOpacity(0.4),
                                    ),
                                    recognizer: _contactTapRecognizer,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
            ],
          ),
        ),
      ),
    );
  }
}