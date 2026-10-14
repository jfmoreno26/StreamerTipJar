import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'neon.dart';
import 'widgets.dart';

String friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-login-credentials':
      return 'That email and password don\'t match. Try again or reset your password.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Try signing in instead.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'weak-password':
      return 'That password is too weak. Use at least 8 characters with a mix of letters and numbers.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support for help.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'No connection. Check your internet and try again.';
    default:
      return e.message ?? 'Something went wrong. Please try again.';
  }
}

class AuthWrapperScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const AuthWrapperScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<AuthWrapperScreen> createState() => _AuthWrapperScreenState();
}

enum AuthView { signIn, register, forgotPassword }

class _AuthWrapperScreenState extends State<AuthWrapperScreen> {
  AuthView _currentView = AuthView.signIn;
  bool _isLoading = false;

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _resetEmailController = TextEditingController();

  bool _obscureSignInPass = true;
  bool _obscureRegPass = true;
  bool _obscureRegConfirmPass = true;

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleSignIn() async {
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in both email and password.');
      return;
    }
    if (!emailPattern.hasMatch(email)) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showSnackBar(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    final confirmPass = _regConfirmPasswordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please complete all registration fields.');
      return;
    }

    if (!usernamePattern.hasMatch(username)) {
      _showSnackBar(
        'Username must be 3–20 characters: letters, numbers, _ or .',
      );
      return;
    }

    if (!emailPattern.hasMatch(email)) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    if (!passwordMeetsRules(password)) {
      _showSnackBar(
        'Your password needs at least 8 characters, an uppercase letter and a symbol.',
      );
      return;
    }

    if (password != confirmPass) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    final db = FirebaseFirestore.instance;
    final usernameRef = db.collection('usernames').doc(username.toLowerCase());

    setState(() => _isLoading = true);
    try {
      if ((await usernameRef.get()).exists) {
        _showSnackBar('The username "$username" is already taken.');
        return;
      }

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) return;

      try {
        await db.runTransaction((tx) async {
          if ((await tx.get(usernameRef)).exists) {
            throw StateError('username-taken');
          }
          tx.set(usernameRef, {'uid': user.uid});
          tx.set(db.collection('users').doc(user.uid), {
            'username': username,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
      } catch (e) {
        await user.delete();
        _showSnackBar(
          e is StateError
              ? 'The username "$username" is already taken.'
              : 'Could not save your account: $e',
        );
        return;
      }

      await user.updateDisplayName(username);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(friendlyAuthError(e));
    } on FirebaseException {
      _showSnackBar(
        'We couldn\x27t reach JarJar. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _resetEmailController.text.trim();
    if (!emailPattern.hasMatch(email)) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar(
        'If a JarJar account exists for $email, a reset link is on its way. '
        'Check your inbox and spam folder.',
      );
      setState(() => _currentView = AuthView.signIn);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                right: -60,
                bottom: -40,
                width: 320,
                height: 320,
                child: IgnorePointer(
                  child: CustomPaint(painter: PlanetPainter()),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: NeonCard(
                      padding: const EdgeInsets.all(28),
                      radius: 28,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : KeyedSubtree(
                                  key: ValueKey(_currentView),
                                  child: AutofillGroup(
                                    child: _buildAuthContent(),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: ThemeToggleButton(
                  isDarkMode: widget.isDarkMode,
                  onThemeChanged: widget.onThemeChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthContent() {
    switch (_currentView) {
      case AuthView.signIn:
        return _buildSignInView();
      case AuthView.register:
        return _buildRegisterView();
      case AuthView.forgotPassword:
        return _buildForgotPasswordView();
    }
  }

  Widget _authHeader(String title, String subtitle) {
    final c = NeonColors.of(context);
    return Column(
      children: [
        const JarJarLogo(size: 64),
        const SizedBox(height: 20),
        GradientText(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    IconData icon = Icons.lock_outline_rounded,
    String autofillHint = AutofillHints.password,
    VoidCallback? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autofillHints: [autofillHint],
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildSignInView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _authHeader(
          'Welcome to JarJar',
          'Sign in to support your favorite creators',
        ),
        TextFormField(
          controller: _signInEmailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        _passwordField(
          controller: _signInPasswordController,
          label: 'Password',
          obscure: _obscureSignInPass,
          onToggle: () =>
              setState(() => _obscureSignInPass = !_obscureSignInPass),
          onSubmitted: _handleSignIn,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() => _currentView = AuthView.forgotPassword);
            },
            child: const Text('Forgot Password?'),
          ),
        ),
        const SizedBox(height: 12),
        GlowButton(
          label: 'SIGN IN',
          icon: Icons.arrow_forward_rounded,
          expand: true,
          onPressed: _handleSignIn,
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () {
            setState(() => _currentView = AuthView.register);
          },
          child: const Text('CREATE AN ACCOUNT'),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    final c = NeonColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _authHeader(
          'Create your account',
          'Join the community and support digital creators',
        ),
        TextFormField(
          controller: _regUsernameController,
          autofillHints: const [AutofillHints.newUsername],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Username',
            helperText: '3–20 characters: letters, numbers, _ or .',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),
        _passwordField(
          controller: _regPasswordController,
          label: 'Password',
          obscure: _obscureRegPass,
          autofillHint: AutofillHints.newPassword,
          onToggle: () => setState(() => _obscureRegPass = !_obscureRegPass),
        ),
        PasswordStrengthMeter(controller: _regPasswordController),
        const SizedBox(height: 14),
        _passwordField(
          controller: _regConfirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_reset_rounded,
          obscure: _obscureRegConfirmPass,
          autofillHint: AutofillHints.newPassword,
          onToggle: () =>
              setState(() => _obscureRegConfirmPass = !_obscureRegConfirmPass),
          onSubmitted: _handleSignUp,
        ),
        const SizedBox(height: 24),
        GlowButton(
          label: 'SIGN UP',
          icon: Icons.rocket_launch_rounded,
          expand: true,
          onPressed: _handleSignUp,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Already have an account?', style: TextStyle(color: c.muted)),
            TextButton(
              onPressed: () {
                setState(() => _currentView = AuthView.signIn);
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForgotPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _authHeader(
          'Forgot your password?',
          'Enter the email address associated with your JarJar account. '
              'We will send you a link to reset your password.',
        ),
        TextFormField(
          controller: _resetEmailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          onFieldSubmitted: (_) => _handleResetPassword(),
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 20),
        GlowButton(
          label: 'SEND RESET LINK',
          icon: Icons.send_rounded,
          expand: true,
          gradient: const LinearGradient(colors: [Neon.pink, Neon.peach]),
          onPressed: _handleResetPassword,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            setState(() => _currentView = AuthView.signIn);
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('BACK TO SIGN IN'),
        ),
      ],
    );
  }
}
