import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'reset_password_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _checkCode() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
        );
      });
    }
  }

  void _resendCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code resent!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'images/name.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 0),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35),
                      decoration: BoxDecoration(
                        color: AppColors.beige.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Reset Password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Email sent!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check your email and enter verification code',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.brown.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 30),
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
                              style: const TextStyle(color: AppColors.brown),
                              decoration: InputDecoration(
                                hintText: 'Enter your email',
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: AppColors.brown, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade700, size: 22),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Enter code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                letterSpacing: 8,
                                color: AppColors.brown,
                              ),
                              decoration: InputDecoration(
                                hintText: '0 0 0 0 0',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 24,
                                  letterSpacing: 8,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: AppColors.brown, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Code is required';
                                if (v.length < 5) return 'Enter 5-digit code';
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _checkCode,
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
                                      'Check code',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 15),
                            Center(
                              child: TextButton(
                                onPressed: _resendCode,
                                child: Text(
                                  "Didn't receive code? Resend",
                                  style: TextStyle(
                                    color: AppColors.brown,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
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
      ),
    );
  }
}