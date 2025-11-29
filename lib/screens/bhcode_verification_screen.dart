import 'package:flutter/material.dart';
import '../models/business_hub.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class BhCodeVerificationScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const BhCodeVerificationScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<BhCodeVerificationScreen> createState() => _BhCodeVerificationScreenState();
}

class _BhCodeVerificationScreenState extends State<BhCodeVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bhCodeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Ensure the field is empty and clear any potential autofill
    _bhCodeController.clear();
  }

  Future<void> _verifyBhCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Verify the entered BHCODE matches the one in business_hubs table
        final businessHub = await _authService.verifyBhCode(
          widget.userId,
          _bhCodeController.text.trim().toUpperCase(),
        );

        // Mark BHCODE as verified/seen
        await _authService.markBhCodeAsSeen(widget.userId);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardScreen(user: businessHub),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _bhCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 100,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Verify Your Business Hub Code',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please enter your BHCODE to confirm your account.\nThis is required on your first login.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextFormField(
                    controller: _bhCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Your BHCODE',
                      hintText: 'e.g., ABC123',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                    // Completely disable autofill
                    autofillHints: const [],
                    autocorrect: false,
                    enableSuggestions: false,
                    // Use visiblePassword keyboard type to disable suggestions
                    // while still showing the text (not obscured)
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    // Prevent any autofill from system
                    enableIMEPersonalizedLearning: false,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your BHCODE';
                      }
                      if (value.trim().length < 3) {
                        return 'BHCODE must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyBhCode,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Verify BHCODE',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      // Logout and go back to login
                      await _authService.logout();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(
                      'Back to Login',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

