// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_text_field.dart';
import '../../utils/snackbar_utils.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _credentialsValidated = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final isValid = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (isValid) {
          // Store validated state and show success message
          setState(() {
            _credentialsValidated = true;
          });
          
          // Credentials validated - button will change to "Log In"
        }
      } catch (e) {
        if (!context.mounted) return;
        SnackBarUtils.showError(context, e.toString());
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginUser() async {
    if (_credentialsValidated) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // Navigation will be handled by AuthWrapper automatically
      } catch (e) {
        if (!context.mounted) return;
        SnackBarUtils.showError(context, 'Login failed: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    // Navigate to dedicated forgot password screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF2D2D2D),
                ]
              : [
                  const Color(0xFFF8FFF8),
                  const Color(0xFFE8F5E8),
                ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Modern Logo Design
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.primaryColor,
                        AppConfig.primaryColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppConfig.primaryColor.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Welcome Text
                Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppConfig.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  "Continue your plant discovery journey",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConfig.getTextSecondary(isDark),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                
                const SizedBox(height: 60),
              
                // Modern Login Form
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppConfig.getCardColor(isDark),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: isDark 
                      ? Border.all(color: AppConfig.getTextSecondary(isDark), width: 1)
                      : null,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        AppTextField.auth(
                          controller: _emailController,
                          label: "Email Address",
                          prefixIcon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          isRequired: true,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Password Field
                        AppTextField.auth(
                          controller: _passwordController,
                          label: "Password",
                          prefixIcon: Icons.lock_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: AppConfig.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                          isRequired: true,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Forgot Password Link
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _forgotPassword,
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: AppConfig.primaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Modern Sign In Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _credentialsValidated 
                                ? [AppConfig.successColor, AppConfig.successColor]
                                : [AppConfig.primaryColor, AppConfig.primaryColor.withOpacity(0.8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (_credentialsValidated ? AppConfig.successColor : AppConfig.primaryColor).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : (_credentialsValidated ? _loginUser : _signIn),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    _credentialsValidated ? "Log In" : "Sign In",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: AppConfig.getTextSecondary(isDark),
                        fontSize: 16,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppConfig.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: AppConfig.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
