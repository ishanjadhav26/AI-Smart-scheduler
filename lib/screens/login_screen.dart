import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF030008), // pure space black
      body: Stack(
        children: [
          // Background Glow Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA78BFA).withOpacity(0.08), // soft purple
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.05), // soft blue
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0714).withOpacity(0.7), // glass fill
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withOpacity(0.12), // purple border glow
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA78BFA).withOpacity(0.05),
                      blurRadius: 30,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon Glow
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFA78BFA).withOpacity(0.08),
                        border: Border.all(
                          color: const Color(0xFFA78BFA).withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.alarm_on_rounded,
                        color: Color(0xFFA78BFA),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AI Smart Scheduler',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Google Calendar Sync + High-Precision Reminders',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // "Sign In with Google" Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          setState(() => _isLoading = true);
                          
                          final error = await provider.loginWithGoogle();
                          
                          if (mounted) {
                            setState(() => _isLoading = false);
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('⚠️ Google Sign-In failed: $error')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Google colorful logo representation or clean icon
                                  const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.black.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Secured securely via Firebase & Google Authentication.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
