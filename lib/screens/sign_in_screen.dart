// lib/screens/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './CoachDashboard.dart'; // Import the new CoachDashboard
import './AthleteDashboard.dart'; // Import the AthleteDashboardApp
import '../services/api_service.dart';
import '../services/auth_storage_service.dart';
import './register_screen.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
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

  // Future<void> _login() async {
  //   if (_formKey.currentState?.validate() ?? false) {
  //     setState(() {
  //       _isLoading = true;
  //       _errorMessage = null;
  //     });
  //
  //     try {
  //       await Future.delayed(const Duration(seconds: 1)); // Simulate network request
  //
  //       // Dummy credentials for Athlete
  //       const dummyAthleteEmail = 'asrar@gmail.com';
  //       const dummyAthletePassword = 'qwertyuiop';
  //
  //       if (_emailController.text == dummyCoachEmail && _passwordController.text == dummyCoachPassword) {
  //         if (!mounted) return;
  //         Navigator.of(context).pushReplacement(
  //           MaterialPageRoute(builder: (_) => const CoachDashboard()),
  //         );
  //       } else if (_emailController.text == dummyAthleteEmail && _passwordController.text == dummyAthletePassword) {
  //         if (!mounted) return;
  //         Navigator.of(context).pushReplacement(
  //           MaterialPageRoute(builder: (_) => const AthleteDashboardApp()), // Navigate to AthleteDashboardApp
  //         );
  //       } else {
  //         setState(() {
  //           _errorMessage = 'Invalid email or password.';
  //         });
  //       }
  //     } catch (e) {
  //       setState(() {
  //         _errorMessage = 'Login failed: ${e.toString()}';
  //       });
  //     } finally {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final api = ApiService();

        final response = await api.loginUser(
          _emailController.text,
          _passwordController.text,
        );

        final user = response["user"];
        final token = response["token"];

        await AuthStorageService.saveAuthData(
          user["id"],
          token,
        );

        print("User: $user");
        print("Token: $token");

        if (!mounted) return;

        // ✅ ROLE-BASED NAVIGATION
        if (user["role"] == "coach") {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CoachDashboard()),
          );
        } else if (user["role"] == "athlete") {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AthleteDashboardApp()),
          );
        } else {
          setState(() {
            _errorMessage = "Unknown user role";
          });
        }

      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sign In',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onBackground,
          ),
        ),
        backgroundColor: colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onBackground),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.background,
              colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_open_rounded,
                    size: 80,
                    color: const Color(0xFF4285F4),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Welcome!',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter your credentials to continue.',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'your.email@example.com',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.email, color: colorScheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: const Color(0xFF4285F4), width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.lock, color: colorScheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.3), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: const Color(0xFF4285F4), width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFF4285F4).withOpacity(0.4),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: colorScheme.onSecondary)
                          : Text(
                        'Login',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Forgot Password? Feature not implemented.')),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF4285F4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: textTheme.titleMedium?.copyWith(color: colorScheme.onBackground.withOpacity(0.8)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign Up',
                          style: textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF4285F4),
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}