import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'features/business/business_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const KhataFlowApp());
}

class KhataFlowApp extends StatelessWidget {
  const KhataFlowApp({super.key});

  static const Color brandColor = Color(0xFF176B5B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhataFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brandColor),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brandColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// Routes users according to their Firebase authentication state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authChanges;

  @override
  void initState() {
    super.initState();
    _authChanges = FirebaseAuth.instance.authStateChanges();
  }

  void _retryAuthStream() {
    setState(() {
      _authChanges = FirebaseAuth.instance.authStateChanges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return _StartupErrorScreen(onRetry: _retryAuthStream);
        }

        final user = snapshot.data;

        if (user != null) {
          return HomeScreen(user: user);
        }

        return const AuthScreen();
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to check your session',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Login, registration and password reset.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegistering = false;
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.red.shade700
              : KhataFlowApp.brandColor,
        ),
      );
  }

  String _authErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
      case 'missing-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again before performing this action.';
      default:
        return exception.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegistering) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Save the user's display name in their Firebase Auth profile.
        final name = _nameController.text.trim();
        final user = credential.user;

        if (user != null && name.isNotEmpty) {
          try {
            await user.updateDisplayName(name);
          } on FirebaseAuthException {
            // Account creation succeeded; the name can be updated later.
          }
        }
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }

      // AuthGate listens to authStateChanges and opens HomeScreen.
    } on FirebaseAuthException catch (exception) {
      _showMessage(_authErrorMessage(exception), isError: true);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset your password'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'you@example.com',
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(dialogContext, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('Send reset link'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showMessage(
        'If an account exists for this email, a reset link has been sent.',
      );
    } on FirebaseAuthException catch (exception) {
      _showMessage(_authErrorMessage(exception), isError: true);
    } catch (_) {
      _showMessage(
        'Unable to send the reset email. Please try again.',
        isError: true,
      );
    }
  }

  InputDecoration _decoration(
    String label, {
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  Image.asset(
                    'lib/assets/images/app_logo.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    semanticLabel: 'Khata Flow logo',
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _isRegistering
                        ? 'Create your account to get started.'
                        : 'Your business finances, kept clear.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                  ),

                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE9EDF2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isRegistering ? 'Create account' : 'Welcome back',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _isRegistering
                                ? 'Enter your details below.'
                                : 'Sign in to continue to KhataFlow.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_isRegistering) ...[
                            TextFormField(
                              controller: _nameController,
                              enabled: !_isLoading,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: _decoration(
                                'Full name',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (value) {
                                if (_isRegistering &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Please enter your name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          TextFormField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: _decoration(
                              'Email address',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Please enter your email.';
                              }

                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                                return 'Enter a valid email address.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            textInputAction: _isRegistering
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: [
                              _isRegistering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) {
                              if (!_isRegistering) _submit();
                            },
                            decoration: _decoration(
                              'Password',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password.';
                              }

                              if (value.length < 6) {
                                return 'Password must have at least 6 characters.';
                              }

                              return null;
                            },
                          ),

                          if (_isRegistering) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              enabled: !_isLoading,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              decoration: _decoration(
                                'Confirm password',
                                icon: Icons.verified_user_outlined,
                                suffixIcon: IconButton(
                                  tooltip: _obscureConfirmPassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password.';
                                }

                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }

                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],

                          if (!_isRegistering)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _showPasswordResetDialog,
                                child: const Text('Forgot password?'),
                              ),
                            )
                          else
                            const SizedBox(height: 20),

                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isRegistering
                                        ? 'Create account'
                                        : 'Sign in',
                                  ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _isRegistering
                                      ? 'Already have an account?'
                                      : "Don't have an account?",
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _isRegistering = !_isRegistering;
                                          _formKey.currentState?.reset();
                                        });
                                      },
                                child: Text(
                                  _isRegistering ? 'Sign in' : 'Register',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 15, color: Colors.grey),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Secure authentication powered by Firebase',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return BusinessHomeScreen(user: user);
  }
}
