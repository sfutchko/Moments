import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import 'register_screen.dart'; // Import RegisterScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = context.read<AuthService>();
      try {
        final userCredential = await authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        // Check if login was successful (userCredential is not null and widget is still mounted)
        if (userCredential != null && mounted) {
           // Navigation will be handled by AuthWrapper automatically
           print('Login Successful: ${userCredential.user?.email}');
        } else if (mounted) {
          // Handle login failure (e.g., wrong password, user not found)
          setState(() {
            _errorMessage = 'Login failed. Please check your credentials.'; // Generic error
          });
        }
      } catch (e) {
        // Handle unexpected errors
        if (mounted) {
          setState(() {
             _errorMessage = 'An unexpected error occurred. Please try again.';
          });
        }
        print('Login Error: $e');
      }

      if (mounted) {
         setState(() {
            _isLoading = false;
         });
      }
    }
  }

  // Add method for Google Sign In
  Future<void> _googleSignIn() async {
     setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final authService = context.read<AuthService>();
      try {
        final userCredential = await authService.signInWithGoogle();
        if (userCredential == null && mounted) {
           // Handle cancellation or failure
           setState(() {
            _errorMessage = 'Google Sign-In failed or cancelled.';
          });
        }
        // Success is handled by AuthWrapper
      } catch (e) {
         if (mounted) {
          setState(() {
             _errorMessage = 'An error occurred during Google Sign-In.';
          });
        }
        print('Google Sign In Error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
  }

  void _navigateToRegister() {
     // Remove placeholder
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const RegisterScreen()),
     );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme

    // Style for social login buttons (to avoid repetition)
    final socialButtonStyle = ElevatedButton.styleFrom(
       foregroundColor: theme.colorScheme.onSurface, // Use theme colors
       backgroundColor: theme.colorScheme.surface, // Use theme surface color
       padding: const EdgeInsets.symmetric(vertical: 12),
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // Slightly less rounded than main buttons
       ),
    );

    return Scaffold(
      // No AppBar
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Text - Adjusted styling
                  Text(
                    'Welcome Back!',
                    style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                   const SizedBox(height: 8),
                   Text(
                    'Log in to manage your Moments',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Email Field - Uses theme InputDecoration
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field - Uses theme InputDecoration
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Loading Indicator or Buttons
                  _isLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        ))
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Login Button - Uses theme ElevatedButton style
                          ElevatedButton(
                            onPressed: _login,
                            child: const Text('Login'),
                          ),
                          const SizedBox(height: 16),

                          // Divider
                          Row(
                            children: <Widget>[
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text("OR", style: theme.textTheme.bodySmall),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Google Sign-In Button
                          ElevatedButton.icon(
                            icon: Image.asset('assets/images/google_logo.png', height: 20.0), // Slightly smaller logo
                            label: const Text('Continue with Google'),
                            onPressed: _googleSignIn,
                            style: socialButtonStyle, // Apply specific style
                          ),
                          const SizedBox(height: 12),

                          // Apple Sign-In Button (Placeholder)
                          ElevatedButton.icon(
                             icon: Icon(Icons.apple, color: theme.colorScheme.onSurface), // Use theme color
                             label: const Text('Continue with Apple'),
                             onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Apple Sign-In requires macOS setup.')),
                                );
                             },
                             style: socialButtonStyle, // Apply specific style
                          ),
                           const SizedBox(height: 32),

                           // Navigate to Register Text Button
                           TextButton(
                              onPressed: _isLoading ? null : _navigateToRegister, // Disable when loading
                              child: const Text('Don\'t have an account? Register'),
                           ),
                        ],
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