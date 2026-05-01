import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _message;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    setState(() {
      _message = null;
      _errorMessage = null;
    });

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ProfileService().sendPasswordResetEmail(email);

      setState(() {
        _message = 'Password reset link sent. Check your email.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not send reset email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: const Color(0xFF1A6FD4),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your email and we will send you a password reset link.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),

              if (_message != null)
                Text(
                  _message!,
                  style: const TextStyle(color: Colors.green),
                ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6FD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SEND RESET LINK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}