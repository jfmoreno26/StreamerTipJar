import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'neon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const JarJarApp());
}

String dollars(num amount) => '\$${amount.toStringAsFixed(2)}';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? 'J' : letters;
}

enum SupporterRank {
  none('New', Colors.grey, Icons.star_border),
  supporter('Supporter', Color(0xFFCD7F32), Icons.star_half_rounded),
  activeSupporter('Active Supporter', Color(0xFFC0C0C0), Icons.star_rounded),
  topSupporter('Top Supporter', Color(0xFFFFD700), Icons.workspace_premium_rounded);

  final String label;
  final Color color;
  final IconData icon;

  const SupporterRank(this.label, this.color, this.icon);

  static SupporterRank getRankForAmount(double totalAmount) {
    if (totalAmount >= 50.0) {
      return SupporterRank.topSupporter;
    } else if (totalAmount >= 20.0) {
      return SupporterRank.activeSupporter;
    } else if (totalAmount > 0.0) {
      return SupporterRank.supporter;
    }
    return SupporterRank.none;
  }
}

class Creator {
  final String name;
  final String username;
  final String category;
  final String description;
  final Color color;
  final String initials;
  final int supporters;
  final double totalTips;
  final bool isLive;
  final int viewers;
  final String streamTitle;

  const Creator({
    required this.name,
    required this.username,
    required this.category,
    required this.description,
    required this.color,
    required this.initials,
    required this.supporters,
    required this.totalTips,
    required this.isLive,
    required this.viewers,
    required this.streamTitle,
  });

  /// Illustrated profile picture generated from the creator's handle.
  String get avatarUrl {
    final background = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return 'https://api.dicebear.com/9.x/adventurer/png'
        '?seed=${Uri.encodeComponent(username)}&size=160&backgroundColor=$background';
  }
}

const List<Creator> creators = [
  Creator(
    name: 'Yhatch Junio',
    username: '@yhatchjunio',
    category: 'Gaming',
    description: 'Gaming streams, community challenges, and fun.',
    color: Color(0xFF6A4CFF),
    initials: 'YJ',
    supporters: 128,
    totalTips: 1240,
    isLive: true,
    viewers: 1284,
    streamTitle: 'Ranked grind until we hit Diamond 💎',
  ),
  Creator(
    name: 'Andre Arenas',
    username: '@sanera',
    category: 'Creative',
    description: 'Digital art, creative projects, and tutorials.',
    color: Color(0xFFB04CFF),
    initials: 'AR',
    supporters: 96,
    totalTips: 865,
    isLive: true,
    viewers: 642,
    streamTitle: 'Painting a space station from scratch',
  ),
  Creator(
    name: 'Gabee Morales',
    username: '@GabeePlayztzy',
    category: 'Gaming',
    description: 'Casual gaming and live community sessions.',
    color: Color(0xFF1BB3A0),
    initials: 'GM',
    supporters: 74,
    totalTips: 620,
    isLive: false,
    viewers: 0,
    streamTitle: 'Cozy co-op night with chat',
  ),
  Creator(
    name: 'Jomira Moreno',
    username: '@jomirafionnaTV',
    category: 'Music',
    description: 'Music sessions, covers, and creative experiments.',
    color: Color(0xFFFF5FA2),
    initials: 'JM',
    supporters: 63,
    totalTips: 510,
    isLive: true,
    viewers: 389,
    streamTitle: 'Acoustic requests — you pick the songs 🎶',
  ),
];

Creator? creatorNamed(String name) {
  for (final creator in creators) {
    if (creator.name == name) return creator;
  }
  return null;
}

// Tip statuses. Tips are written by the PaiFlow server when a payment is
// submitted (pending) and updated once it is verified (success/failed).
const String tipPending = 'Pending';
const String tipSuccess = 'Success';
const String tipFailed = 'Failed';

class TipActivity {
  final String creator;
  final double amount;
  final DateTime date;
  final String status;

  const TipActivity({
    required this.creator,
    required this.amount,
    required this.date,
    required this.status,
  });

  factory TipActivity.fromFirestore(Map<String, dynamic> data) {
    return TipActivity(
      creator: data['creator'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? tipPending,
    );
  }
}

class JarJarApp extends StatefulWidget {
  const JarJarApp({super.key});

  @override
  State<JarJarApp> createState() => _JarJarAppState();
}

class _JarJarAppState extends State<JarJarApp> {
  bool isDarkMode = true;

  // Created once: a new stream on every rebuild (e.g. a theme toggle) makes
  // the StreamBuilder resubscribe, which recreates HomeScreen on the Home tab.
  final Stream<User?> _authStream = FirebaseAuth.instance.userChanges();

  void toggleTheme(bool value) {
    setState(() => isDarkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JarJar',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NeonScrollBehavior(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: const Duration(milliseconds: 400),
      theme: buildNeonTheme(Brightness.light),
      darkTheme: buildNeonTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: NeonBackground(
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(
              user: snapshot.data!,
              isDarkMode: isDarkMode,
              onThemeChanged: toggleTheme,
            );
          }

          return AuthWrapperScreen(
            isDarkMode: isDarkMode,
            onThemeChanged: toggleTheme,
          );
        },
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const ThemeToggleButton({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => onThemeChanged(!isDarkMode),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.75, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(isDarkMode),
        ),
      ),
    );
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
    final password = _signInPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in both email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Authentication failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    final username = _regUsernameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text.trim();
    final confirmPass = _regConfirmPasswordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please complete all registration fields.');
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9_.]{3,20}$').hasMatch(username)) {
      _showSnackBar(
          'Username must be 3–20 characters: letters, numbers, _ or .');
      return;
    }

    if (password != confirmPass) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    final db = FirebaseFirestore.instance;
    // Usernames are unique regardless of case.
    final usernameRef = db.collection('usernames').doc(username.toLowerCase());

    setState(() => _isLoading = true);
    try {
      if ((await usernameRef.get()).exists) {
        _showSnackBar('The username "$username" is already taken.');
        return;
      }

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return;

      try {
        // Claim the username and create the profile in one transaction, so
        // two people registering the same name at once can't both get it.
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
        // Don't leave an account behind without a username.
        await user.delete();
        _showSnackBar(e is StateError
            ? 'The username "$username" is already taken.'
            : 'Could not save your account: $e');
        return;
      }

      await user.updateDisplayName(username);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Registration failed.');
    } on FirebaseException catch (e) {
      _showSnackBar(e.message ?? 'Registration failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      // Same message whether or not the account exists, so the form can't be
      // used to discover which emails are registered.
      _showSnackBar(
          'If a JarJar account exists for $email, a reset link is on its way. '
          'Check your inbox and spam folder.');
      setState(() => _currentView = AuthView.signIn);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Error sending reset email.');
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
                                      child: CircularProgressIndicator()),
                                )
                              : KeyedSubtree(
                                  key: ValueKey(_currentView),
                                  child: _buildAuthContent(),
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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
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
        _authHeader('Welcome to JarJar', 'Sign in to support your favorite creators'),
        TextFormField(
          controller: _signInEmailController,
          keyboardType: TextInputType.emailAddress,
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
            'Create your account', 'Join the community and support digital creators'),
        TextFormField(
          controller: _regUsernameController,
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
          onToggle: () => setState(() => _obscureRegPass = !_obscureRegPass),
        ),
        const SizedBox(height: 14),
        _passwordField(
          controller: _regConfirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_reset_rounded,
          obscure: _obscureRegConfirmPass,
          onToggle: () => setState(
              () => _obscureRegConfirmPass = !_obscureRegConfirmPass),
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

class HomeScreen extends StatefulWidget {
  final User user;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.user,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;
  String searchQuery = '';
  String selectedCategory = 'All';
  bool _uploadingPhoto = false;

  final TextEditingController searchController = TextEditingController();

  static const List<(String, IconData, IconData)> tabs = [
    ('Home', Icons.home_outlined, Icons.home_rounded),
    ('Discover', Icons.explore_outlined, Icons.explore_rounded),
    ('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
    ('Activity', Icons.history_outlined, Icons.history_rounded),
    ('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  // Created once so rebuilds (theme toggle, tab changes) keep the same
  // subscriptions instead of resetting them.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tipsStream =
      FirebaseFirestore.instance
          .collection('tips')
          .where('userId', isEqualTo: widget.user.uid)
          .snapshots();

  late final DocumentReference<Map<String, dynamic>> _userDoc =
      FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream =
      _userDoc.snapshots();

  // Decoded profile photo, cached so it isn't decoded on every rebuild.
  String? _photoBase64;
  Uint8List? _photoBytes;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void navigateTo(int index) {
    setState(() => selectedTab = index);
  }

  Uint8List? _decodePhoto(String? base64Photo) {
    if (base64Photo != _photoBase64) {
      _photoBase64 = base64Photo;
      try {
        _photoBytes = base64Photo == null ? null : base64Decode(base64Photo);
      } on FormatException {
        _photoBytes = null;
      }
    }
    return _photoBytes;
  }

  /// Lets the user pick a picture, shrinks it, and stores it on their profile.
  Future<void> changeProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final png = await _shrinkToPng(await picked.readAsBytes(), 192);
      // Firestore documents are capped at 1 MB; keep the photo well under it.
      if (png.lengthInBytes > 600 * 1024) {
        showMessage('That picture is too large. Try a smaller one.');
        return;
      }
      await _userDoc.set({'photo': base64Encode(png)}, SetOptions(merge: true));
      showMessage('Profile picture updated.');
    } catch (e) {
      showMessage('Could not update your picture: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> removeProfilePhoto() async {
    try {
      await _userDoc.set({'photo': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e) {
      showMessage('Could not remove your picture: $e');
    }
  }

  static Future<Uint8List> _shrinkToPng(Uint8List bytes, int width) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final profile = userSnapshot.data?.data();
        final photo = _decodePhoto(profile?['photo'] as String?);

        final authName = widget.user.displayName?.trim() ?? '';
        final storedName = (profile?['username'] as String?)?.trim() ?? '';
        final emailName = (widget.user.email ?? '').split('@').first;
        final displayName = authName.isNotEmpty
            ? authName
            : storedName.isNotEmpty
                ? storedName
                : emailName.isNotEmpty
                    ? emailName
                    : 'JarJar User';

        final me = _Me(name: displayName, email: widget.user.email ?? '', photo: photo);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _tipsStream,
          builder: (context, snapshot) {
            final List<TipActivity> activities = [];
            // Only verified payments count towards supporter ranks.
            final Map<String, double> userTipsByCreator = {};

            if (snapshot.hasData) {
              for (final doc in snapshot.data!.docs) {
                final activity = TipActivity.fromFirestore(doc.data());
                activities.add(activity);
                if (activity.status == tipSuccess) {
                  userTipsByCreator[activity.creator] =
                      (userTipsByCreator[activity.creator] ?? 0.0) +
                          activity.amount;
                }
              }
              activities.sort((a, b) => a.date.compareTo(b.date));
            }

            final pages = [
              dashboard(me, activities, userTipsByCreator),
              discover(userTipsByCreator),
              wallet(),
              activity(activities, userTipsByCreator),
              profileTab(me),
            ];

            return Scaffold(
              body: NeonBackground(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _topBar(me),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: FadeIndexedStack(
                              index: selectedTab,
                              children: pages,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: _bottomBar(),
            );
          },
        );
      },
    );
  }

  Widget _topBar(_Me me) {
    final c = NeonColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => navigateTo(0),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JarJarLogo(),
                  SizedBox(width: 10),
                  GradientText(
                    'JarJar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ThemeToggleButton(
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () => showMessage('No new notifications'),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Profile',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => navigateTo(4),
              child: NeonAvatar(
                initials: initialsOf(me.name),
                color: Neon.purple,
                imageBytes: me.photo,
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final c = NeonColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: Neon.purple.withValues(alpha: 0.18 * c.glow),
            blurRadius: 24,
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: navigateTo,
        animationDuration: const Duration(milliseconds: 400),
        destinations: [
          for (final (label, icon, selectedIcon) in tabs)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }

  ListView _page(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: children,
    );
  }

  Widget dashboard(
    _Me me,
    List<TipActivity> activities,
    Map<String, double> userTipsByCreator,
  ) {
    final liveCreators = creators.where((c) => c.isLive).toList();
    final totalGiven = userTipsByCreator.values.fold(0.0, (a, b) => a + b);

    return _page([
      _HeroBanner(
        userName: me.name,
        onExplore: () => navigateTo(1),
      ),
      const SizedBox(height: 28),
      SectionHeading(
        title: 'Live now',
        subtitle: '${liveCreators.length} creators streaming — swipe to browse',
        actionLabel: 'See all',
        onAction: () => navigateTo(1),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 292,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: liveCreators.length,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, i) => StreamCard(
            creator: liveCreators[i],
            onTap: () => showTipDialog(liveCreators[i].name, userTipsByCreator),
          ),
        ),
      ),
      const SizedBox(height: 28),
      const SectionHeading(
        title: 'Your overview',
        subtitle: 'Your support activity at a glance',
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            StatCard(
              label: 'Tips recorded',
              value: '${activities.length}',
              detail: 'Tips processed by PaiFlow',
              icon: Icons.receipt_long_rounded,
              accent: Neon.purple,
            ),
            StatCard(
              label: 'Successful tips',
              value: '${activities.where((a) => a.status == tipSuccess).length}',
              detail: 'Verified payments',
              icon: Icons.verified_rounded,
              accent: Neon.cyan,
            ),
            StatCard(
              label: 'Total given',
              value: dollars(totalGiven),
              detail: 'Across all creators',
              icon: Icons.savings_rounded,
              accent: Neon.pink,
            ),
          ];

          if (constraints.maxWidth < 620) {
            return Column(
              children: [
                for (final card in cards) ...[card, const SizedBox(height: 12)],
              ],
            );
          }

          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 28),
      SectionHeading(
        title: 'Featured creators',
        subtitle: 'Find someone whose content you enjoy',
        actionLabel: 'View all',
        onAction: () => navigateTo(1),
      ),
      const SizedBox(height: 14),
      _creatorGrid(creators.take(3).toList(), userTipsByCreator),
    ]);
  }

  Widget _creatorGrid(List<Creator> list, Map<String, double> userTipsByCreator) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final creator in list)
              SizedBox(
                width: width,
                child: CreatorCard(
                  creator: creator,
                  userTotalTip: userTipsByCreator[creator.name] ?? 0.0,
                  onSupport: () => showTipDialog(creator.name, userTipsByCreator),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget discover(Map<String, double> userTipsByCreator) {
    final query = searchQuery.toLowerCase();
    final categories = ['All', ...{for (final c in creators) c.category}];
    final filteredCreators = creators.where((creator) {
      final matchesSearch = creator.name.toLowerCase().contains(query) ||
          creator.username.toLowerCase().contains(query) ||
          creator.category.toLowerCase().contains(query);

      final matchesCategory =
          selectedCategory == 'All' || creator.category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList()
      // Live creators first.
      ..sort((a, b) => (b.isLive ? 1 : 0) - (a.isLive ? 1 : 0));

    return _page([
      const SectionHeading(
        title: 'Discover creators',
        subtitle: 'Explore creators and support their work',
      ),
      const SizedBox(height: 18),
      TextField(
        controller: searchController,
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: const InputDecoration(
          hintText: 'Search by creator or category',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          return ChoiceChip(
            label: Text(category),
            selected: selectedCategory == category,
            onSelected: (_) {
              setState(() => selectedCategory = category);
            },
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      Text(
        '${filteredCreators.length} creators found',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: NeonColors.of(context).muted,
        ),
      ),
      const SizedBox(height: 12),
      if (filteredCreators.isEmpty)
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No creators found',
          description: 'Try another name or category.',
        )
      else
        _creatorGrid(filteredCreators, userTipsByCreator),
    ]);
  }

  Widget wallet() {
    final c = NeonColors.of(context);
    return _page([
      const SectionHeading(
        title: 'Wallet',
        subtitle: 'Manage your wallet connection and payments',
      ),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 190,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2A1468), Neon.purple, Neon.pink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -40,
                top: -30,
                width: 230,
                height: 230,
                child: CustomPaint(painter: PlanetPainter()),
              ),
              const Positioned.fill(
                child: TwinkleField(points: [
                  Offset(0.08, 0.2),
                  Offset(0.45, 0.12),
                  Offset(0.55, 0.8),
                  Offset(0.3, 0.6),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'PAYMENT CURRENCY',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 2,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'USD / USDC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 300,
                      child: Text(
                        'Tip amounts are shown in US dollars. '
                        'PaiFlow settles them in USDC on Stellar.',
                        style: TextStyle(color: Colors.white, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Neon.violet),
                const SizedBox(width: 10),
                Text(
                  'Freighter wallet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Connect and approve transactions using Freighter '
              'on its supported browser interface.',
              style: TextStyle(height: 1.5, color: c.muted),
            ),
            const SizedBox(height: 16),
            GlowButton(
              label: 'Open wallet payment page',
              icon: Icons.open_in_new_rounded,
              expand: true,
              onPressed: openPaiFlowPage,
            ),
          ],
        ),
      ),
    ]);
  }

  Widget activity(
      List<TipActivity> activities, Map<String, double> userTipsByCreator) {
    final c = NeonColors.of(context);
    return _page([
      const SectionHeading(
        title: 'Activity',
        subtitle: 'Your tips and the supporter ranks you earned',
      ),
      const SizedBox(height: 20),
      if (activities.isEmpty)
        const EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'No activity yet',
          description: 'Tips you send through PaiFlow will appear here.',
        )
      else
        for (final item in activities.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Builder(builder: (context) {
              final creator = creatorNamed(item.creator);
              final rank = SupporterRank.getRankForAmount(
                userTipsByCreator[item.creator] ?? 0.0,
              );
              final statusColor = switch (item.status) {
                tipSuccess => Neon.cyan,
                tipFailed => Neon.live,
                _ => Neon.gold,
              };

              return NeonCard(
                padding: const EdgeInsets.all(14),
                accent: statusColor,
                child: Row(
                  children: [
                    NeonAvatar(
                      initials: creator?.initials ?? initialsOf(item.creator),
                      color: creator?.color ?? Neon.purple,
                      imageUrl: creator?.avatarUrl,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.creator,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              NeonPill(label: item.status, color: statusColor),
                              Text(
                                '${item.date.toLocal()}'.split('.').first,
                                style: TextStyle(fontSize: 12, color: c.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          dollars(item.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RankBadge(rank: rank),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
    ]);
  }

  Widget profileTab(_Me me) {
    final c = NeonColors.of(context);

    return _page([
      const SectionHeading(
        title: 'Profile',
        subtitle: 'Your account, picture and preferences',
      ),
      const SizedBox(height: 20),
      NeonCard(
        padding: EdgeInsets.zero,
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 110,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2A1468), Neon.purple, Neon.pink],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 20,
                            top: -30,
                            width: 170,
                            height: 170,
                            child: CustomPaint(painter: PlanetPainter()),
                          ),
                          Positioned.fill(
                            child: TwinkleField(points: [
                              Offset(0.1, 0.3),
                              Offset(0.35, 0.65),
                              Offset(0.6, 0.25),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 58,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NeonAvatar(
                          initials: initialsOf(me.name),
                          color: Neon.purple,
                          imageBytes: me.photo,
                          size: 92,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                            color: Neon.pink,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _uploadingPhoto ? null : changeProfilePhoto,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(me.email, style: TextStyle(color: c.muted)),
                  const SizedBox(height: 10),
                  const NeonPill(
                    label: 'Creator Support Account',
                    icon: Icons.favorite_rounded,
                    color: Neon.pink,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploadingPhoto ? null : changeProfilePhoto,
                        icon: const Icon(Icons.image_rounded, size: 18),
                        label: Text(me.photo == null ? 'Add photo' : 'Change photo'),
                      ),
                      if (me.photo != null)
                        TextButton.icon(
                          onPressed: removeProfilePhoto,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supporter Tier Thresholds',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: c.text,
              ),
            ),
            const SizedBox(height: 12),
            _buildTierRow(SupporterRank.supporter, '\$1.00 – \$19.99'),
            const Divider(height: 20),
            _buildTierRow(SupporterRank.activeSupporter, '\$20.00 – \$49.99'),
            const Divider(height: 20),
            _buildTierRow(SupporterRank.topSupporter, '\$50.00+'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      NeonCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SwitchListTile(
          secondary: Icon(
            widget.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: Neon.violet,
          ),
          title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Neon night or soft lavender'),
          value: widget.isDarkMode,
          onChanged: widget.onThemeChanged,
        ),
      ),
      const SizedBox(height: 14),
      NeonCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        accent: Neon.live,
        onTap: () => FirebaseAuth.instance.signOut(),
        child: const ListTile(
          leading: Icon(Icons.logout_rounded, color: Neon.live),
          title: Text(
            'Log out',
            style: TextStyle(color: Neon.live, fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Sign out of JarJar'),
        ),
      ),
    ]);
  }

  Widget _buildTierRow(SupporterRank rank, String range) {
    return Row(
      children: [
        Icon(rank.icon, color: rank.color, size: 20),
        const SizedBox(width: 10),
        Text(
          rank.label,
          style: TextStyle(fontWeight: FontWeight.w800, color: rank.color),
        ),
        const Spacer(),
        Text(
          range,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: NeonColors.of(context).muted,
          ),
        ),
      ],
    );
  }

  /// Opens the PaiFlow payment page. With [creatorName], the page shows that
  /// creator and records the payment result for this user's tips.
  Future<void> openPaiFlowPage({String? creatorName}) async {
    final uri = Uri.http('localhost:3000', '/send', {
      if (creatorName != null) ...{
        'creator': creatorName,
        'userId': widget.user.uid,
        'handle': ?creatorNamed(creatorName)?.username,
      },
    });

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (opened) {
        showMessage('Continue on the PaiFlow page to choose your amount and pay.');
      } else {
        showMessage('Could not open page. Ensure local server is running.');
      }
    } catch (error) {
      if (mounted) {
        showMessage('Could not open payment page: $error');
      }
    }
  }

  Future<void> showTipDialog(
      String creatorName, Map<String, double> userTipsByCreator) async {
    final creator = creatorNamed(creatorName);
    final currentRank = SupporterRank.getRankForAmount(
      userTipsByCreator[creatorName] ?? 0.0,
    );

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final c = NeonColors.of(dialogContext);
        return AlertDialog(
          title: Row(
            children: [
              NeonAvatar(
                initials: creator?.initials ?? initialsOf(creatorName),
                color: creator?.color ?? Neon.purple,
                imageUrl: creator?.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Support $creatorName?')),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Current rank: ', style: TextStyle(color: c.muted)),
                    RankBadge(rank: currentRank),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'You will be taken to the PaiFlow payment page to choose '
                  'your tip amount and approve the payment in Freighter. '
                  'Your tip appears here once PaiFlow processes it.',
                  style: TextStyle(height: 1.5, color: c.text),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            GlowButton(
              label: 'Continue to PaiFlow',
              icon: Icons.arrow_forward_rounded,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldContinue != true) return;

    await openPaiFlowPage(creatorName: creatorName);
  }
}

/// The signed-in user's display details.
class _Me {
  final String name;
  final String email;
  final Uint8List? photo;

  const _Me({required this.name, required this.email, required this.photo});
}

class _HeroBanner extends StatelessWidget {
  final String userName;
  final VoidCallback onExplore;

  const _HeroBanner({required this.userName, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final glow = NeonColors.of(context).glow;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Neon.purple.withValues(alpha: 0.4 * glow),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final planetSize = narrow ? 200.0 : 320.0;
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C0B4A), Color(0xFF5B21B6), Neon.pink],
                  stops: [0, 0.55, 1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: narrow ? -70 : -30,
                    bottom: narrow ? -80 : -90,
                    width: planetSize,
                    height: planetSize,
                    child: const CustomPaint(painter: PlanetPainter()),
                  ),
                  const Positioned.fill(
                    child: TwinkleField(points: [
                      Offset(0.06, 0.16),
                      Offset(0.42, 0.1),
                      Offset(0.62, 0.32),
                      Offset(0.88, 0.14),
                      Offset(0.5, 0.88),
                      Offset(0.28, 0.72),
                    ]),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(26, 26, narrow ? 26 : 260, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '✦  WELCOME BACK, ${userName.toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Fuel the streams\nyou love.',
                          style: TextStyle(
                            fontSize: narrow ? 30 : 40,
                            height: 1.08,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            shadows: [
                              Shadow(
                                color: Neon.pink.withValues(alpha: 0.8),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Discover creators, send tips through PaiFlow, '
                          'and unlock supporter rank badges.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 22),
                        GlowButton(
                          label: 'Explore creators',
                          icon: Icons.explore_rounded,
                          gradient: const LinearGradient(colors: [Neon.gold, Neon.peach]),
                          foreground: const Color(0xFF2A1468),
                          onPressed: onExplore,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Twitch-style live stream tile for the horizontal "Live now" row.
class StreamCard extends StatelessWidget {
  final Creator creator;
  final VoidCallback onTap;

  const StreamCard({super.key, required this.creator, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return SizedBox(
      width: 280,
      child: NeonCard(
        padding: EdgeInsets.zero,
        accent: creator.color,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF140A33),
                      creator.color,
                      Color.lerp(creator.color, Neon.pink, 0.6)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -36,
                      width: 140,
                      height: 140,
                      child: CustomPaint(
                        painter: PlanetPainter(
                          body: Color.lerp(creator.color, Neon.peach, 0.7)!,
                          bodyShade: creator.color,
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: TwinkleField(points: [
                        Offset(0.12, 0.25),
                        Offset(0.4, 0.6),
                        Offset(0.7, 0.18),
                      ]),
                    ),
                    const Positioned(top: 10, left: 10, child: LiveBadge()),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '● ${creator.viewers} viewers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 44,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeonAvatar(
                    initials: creator.initials,
                    color: creator.color,
                    imageUrl: creator.avatarUrl,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creator.streamTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          creator.name,
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                        const SizedBox(height: 8),
                        NeonPill(label: creator.category, color: creator.color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      accent: accent,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.35 * c.glow), blurRadius: 14),
              ],
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  key: ValueKey(value),
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, alignment: Alignment.centerLeft, child: child),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: c.text,
                    ),
                  ),
                ),
                Text(detail, style: TextStyle(color: c.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RankBadge extends StatelessWidget {
  final SupporterRank rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    return NeonPill(label: rank.label, color: rank.color, icon: rank.icon);
  }
}

/// Channel card with a banner, overlapping profile picture and support button.
class CreatorCard extends StatelessWidget {
  final Creator creator;
  final double userTotalTip;
  final VoidCallback onSupport;

  const CreatorCard({
    super.key,
    required this.creator,
    required this.userTotalTip,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    final rank = SupporterRank.getRankForAmount(userTotalTip);

    return NeonCard(
      padding: EdgeInsets.zero,
      accent: creator.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 76,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          creator.color,
                          Color.lerp(creator.color, Neon.pink, 0.55)!,
                        ],
                      ),
                    ),
                    child: const TwinkleField(points: [
                      Offset(0.55, 0.3),
                      Offset(0.75, 0.7),
                      Offset(0.92, 0.25),
                    ]),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 34,
                  child: NeonAvatar(
                    initials: creator.initials,
                    color: creator.color,
                    imageUrl: creator.avatarUrl,
                    size: 72,
                    live: creator.isLive,
                  ),
                ),
                if (rank != SupporterRank.none)
                  Positioned(right: 14, top: 86, child: RankBadge(rank: rank)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(creator.username, style: TextStyle(fontSize: 12, color: c.muted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    NeonPill(label: creator.category, color: creator.color),
                    if (creator.isLive)
                      NeonPill(
                        label: '${creator.viewers} watching',
                        color: Neon.live,
                        icon: Icons.sensors_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  creator.description,
                  style: TextStyle(height: 1.5, color: c.text),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _stat(Icons.people_alt_rounded, '${creator.supporters} supporters', c),
                    _stat(Icons.toll_rounded, '${dollars(creator.totalTips)} tipped', c),
                  ],
                ),
                const SizedBox(height: 16),
                GlowButton(
                  label: 'Support Creator',
                  icon: Icons.favorite_rounded,
                  expand: true,
                  onPressed: onSupport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text, NeonColors c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.muted),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final c = NeonColors.of(context);
    return NeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: Neon.violet),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
