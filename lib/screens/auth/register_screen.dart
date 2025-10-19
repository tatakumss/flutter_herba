// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_text_field.dart';
import '../../utils/snackbar_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await _authService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          displayName: _nameController.text.trim(),
        );
        if (success) {
          if (!mounted) return;
          // Navigate back to login
          Navigator.pop(context);
          if (!context.mounted) return;
          // Inform the user on the previous screen
          SnackBarUtils.showSuccess(context, 'Account created successfully! Please log in with your credentials.');
        }
      } on String catch (errorMessage) {
        if (!context.mounted) return;
          SnackBarUtils.showError(context, errorMessage);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
              
                // Modern Header
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppConfig.primaryColor,
                        AppConfig.primaryColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppConfig.primaryColor.withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppConfig.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  "Join our plant discovery community",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                
                const SizedBox(height: 50),
              
                // Modern Registration Form
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900]!.withOpacity(0.3) : Colors.white,
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
                      ? Border.all(color: Colors.grey[800]!, width: 1)
                      : null,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Name Field
                        AppTextField.auth(
                          controller: _nameController,
                          label: "Full Name",
                          prefixIcon: Icons.person_rounded,
                          keyboardType: TextInputType.name,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            if (value.length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                          isRequired: true,
                        ),
                        
                        const SizedBox(height: 24),
                        
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
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          isRequired: true,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Confirm Password Field
                        AppTextField.auth(
                          controller: _confirmPasswordController,
                          label: "Confirm Password",
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              color: AppConfig.primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          isRequired: true,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Modern Sign Up Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppConfig.primaryColor, AppConfig.primaryColor.withOpacity(0.8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppConfig.primaryColor.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
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
                                : const Text(
                                    "Create Account",
                                    style: TextStyle(
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
                
                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                          "Sign In",
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
