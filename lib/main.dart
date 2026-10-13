import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const StreamerTipJarApp());
}

const Color primaryBlue = Color(0xFF2457D6);
const Color accentYellow = Color(0xFFFFD54F);
const Color pageBackground = Color(0xFFF5F7FC);

String dollars(num amount) => '\$${amount.toStringAsFixed(2)}';

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

  const Creator({
    required this.name,
    required this.username,
    required this.category,
    required this.description,
    required this.color,
    required this.initials,
    required this.supporters,
    required this.totalTips,
  });
}

const List<Creator> creators = [
  Creator(
    name: 'Yhatch Junio',
    username: '@yhatchjunio',
    category: 'Gaming',
    description: 'Gaming streams, community challenges, and fun.',
    color: Color(0xFF2457D6),
    initials: 'YJ',
    supporters: 128,
    totalTips: 1240,
  ),
  Creator(
    name: 'Andre Arenas',
    username: '@sanera',
    category: 'Creative',
    description: 'Digital art, creative projects, and tutorials.',
    color: Color(0xFF7B61C9),
    initials: 'AR',
    supporters: 96,
    totalTips: 865,
  ),
  Creator(
    name: 'Gabee Morales',
    username: '@GabeePlayztzy',
    category: 'Gaming',
    description: 'Casual gaming and live community sessions.',
    color: Color(0xFF178C75),
    initials: 'GM',
    supporters: 74,
    totalTips: 620,
  ),
  Creator(
    name: 'Jomira Moreno',
    username: '@jomirafionnaTV',
    category: 'Music',
    description: 'Music sessions, covers, and creative experiments.',
    color: Color(0xFFD97745),
    initials: 'JM',
    supporters: 63,
    totalTips: 510,
  ),
];

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
      status: data['status'] ?? 'Success',
    );
  }
}

class StreamerTipJarApp extends StatefulWidget {
  const StreamerTipJarApp({super.key});

  @override
  State<StreamerTipJarApp> createState() => _StreamerTipJarAppState();
}

class _StreamerTipJarAppState extends State<StreamerTipJarApp> {
  bool isDarkMode = false;

  void toggleTheme(bool value) {
    setState(() => isDarkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamerTipJar',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: accentYellow,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: pageBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: pageBackground,
          foregroundColor: Color(0xFF17233D),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE6EAF2)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F7FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E6F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFE8EEFF),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.dark,
          secondary: accentYellow,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
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

class TipJarLogo extends StatelessWidget {
  final double size;
  const TipJarLogo({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.savings_rounded,
          color: Colors.white,
          size: size * 0.6,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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

    if (password != confirmPass) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(username);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'username': username,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
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
      _showSnackBar('Password reset link sent to $email!');
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
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.wb_sunny_rounded,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAuthContent(),
            ),
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

  Widget _buildSignInView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: TipJarLogo(size: 64)),
        const SizedBox(height: 20),
        const Text(
          'Welcome to StreamerTipJar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to support your favorite creators',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _signInEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _signInPasswordController,
          obscureText: _obscureSignInPass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignInPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() => _obscureSignInPass = !_obscureSignInPass);
              },
            ),
          ),
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
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _handleSignIn,
          child: const Text(
            'SIGN IN →',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            setState(() => _currentView = AuthView.register);
          },
          child: const Text(
            'CREATE AN ACCOUNT',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: TipJarLogo(size: 56)),
        const SizedBox(height: 16),
        const Text(
          'Create your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Join the community and support digital creators',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 28),
        TextFormField(
          controller: _regUsernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person_outline_rounded),
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
        TextFormField(
          controller: _regPasswordController,
          obscureText: _obscureRegPass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() => _obscureRegPass = !_obscureRegPass);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _regConfirmPasswordController,
          obscureText: _obscureRegConfirmPass,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureRegConfirmPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() =>
                    _obscureRegConfirmPass = !_obscureRegConfirmPass);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _handleSignUp,
          child: const Text(
            'SIGN UP →',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: primaryBlue,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email address associated with your StreamerTipJar account. '
          'We will send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        TextFormField(
          controller: _resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: accentYellow,
            foregroundColor: const Color(0xFF18243B),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _handleResetPassword,
          child: const Text(
            'SEND RESET LINK →',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
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

  final TextEditingController searchController = TextEditingController();

  static const List<Map<String, dynamic>> tabs = [
    {'label': 'Home', 'icon': Icons.home_outlined, 'selectedIcon': Icons.home_rounded},
    {'label': 'Discover', 'icon': Icons.explore_outlined, 'selectedIcon': Icons.explore_rounded},
    {'label': 'Wallet', 'icon': Icons.account_balance_wallet_outlined, 'selectedIcon': Icons.account_balance_wallet_rounded},
    {'label': 'Activity', 'icon': Icons.history_outlined, 'selectedIcon': Icons.history_rounded},
    {'label': 'Profile', 'icon': Icons.person_outline_rounded, 'selectedIcon': Icons.person_rounded},
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void navigateTo(int index) {
    setState(() => selectedTab = index);
  }

  Future<void> addTipRecord(String creatorName, double amount) async {
    try {
      await FirebaseFirestore.instance.collection('tips').add({
        'userId': widget.user.uid,
        'creator': creatorName,
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'status': 'Success',
      });
    } catch (e) {
      showMessage('Saved locally. Firestore error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tips')
          .where('userId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final List<TipActivity> activities = [];
        final Map<String, double> userTipsByCreator = {};

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final activity = TipActivity.fromFirestore(data);
            activities.add(activity);
            userTipsByCreator[activity.creator] =
                (userTipsByCreator[activity.creator] ?? 0.0) + activity.amount;
          }
        }

        final pages = [
          dashboard(activities, userTipsByCreator),
          discover(userTipsByCreator),
          wallet(),
          activity(activities, userTipsByCreator),
          profile(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => navigateTo(0),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TipJarLogo(),
                  SizedBox(width: 10),
                  Text(
                    'StreamerTipJar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.wb_sunny_rounded,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  widget.onThemeChanged(!widget.isDarkMode);
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Notifications',
                onPressed: () => showMessage('No new notifications'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: GestureDetector(
                  onTap: () => navigateTo(4),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(
                      Icons.person,
                      size: 22,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: IndexedStack(
                  index: selectedTab,
                  children: pages,
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedTab,
            onDestinationSelected: navigateTo,
            destinations: [
              for (final tab in tabs)
                NavigationDestination(
                  icon: Icon(tab['icon'] as IconData),
                  selectedIcon: Icon(tab['selectedIcon'] as IconData,
                      color: primaryBlue),
                  label: tab['label'] as String,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget dashboard(
      List<TipActivity> activities, Map<String, double> userTipsByCreator) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'CREATOR SUPPORT PLATFORM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Support the creators you love.',
                style: TextStyle(
                  fontSize: 29,
                  height: 1.2,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Discover creators, send tips, and unlock supporter rank badges.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentYellow,
                  foregroundColor: const Color(0xFF18243B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 15,
                  ),
                ),
                onPressed: () => navigateTo(1),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text(
                  'Explore creators',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeading(
          title: 'Your overview',
          subtitle: 'A quick look at your support activity and unlocked ranks',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final cards = [
              StatCard(
                label: 'Tips recorded',
                value: '${activities.length}',
                detail: 'Total tips sent',
              ),
              StatCard(
                label: 'Successful tips',
                value:
                    '${activities.where((a) => a.status == 'Success').length}',
                detail: 'Verified payments',
              ),
            ];

            if (compact) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 12),
                  cards[1],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
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
        ...creators.take(3).map(
              (creator) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CreatorCard(
                  creator: creator,
                  userTotalTip: userTipsByCreator[creator.name] ?? 0.0,
                  onSupport: () =>
                      showTipDialog(creator.name, userTipsByCreator),
                ),
              ),
            ),
      ],
    );
  }

  Widget discover(Map<String, double> userTipsByCreator) {
    final filteredCreators = creators.where((creator) {
      final matchesSearch =
          creator.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          creator.username.toLowerCase().contains(searchQuery.toLowerCase()) ||
          creator.category.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesCategory =
          selectedCategory == 'All' || creator.category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
          children: ['All', 'Gaming', 'Creative', 'Music'].map((category) {
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
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (filteredCreators.isEmpty)
          const EmptyState(
            title: 'No creators found',
            description: 'Try another name or category.',
          )
        else
          ...filteredCreators.map(
            (creator) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CreatorCard(
                creator: creator,
                userTotalTip: userTipsByCreator[creator.name] ?? 0.0,
                onSupport: () => showTipDialog(creator.name, userTipsByCreator),
              ),
            ),
          ),
      ],
    );
  }

  Widget wallet() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeading(
          title: 'Wallet',
          subtitle: 'Manage your wallet connection and payments',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAYMENT CURRENCY',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1,
                  fontSize: 11,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'USD / USDC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Tip amounts are displayed in US dollars. '
                'The payment page currently accepts USDC.',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Freighter wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect and approve transactions using Freighter '
                  'on its supported browser interface.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: openPaiFlowPage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open wallet payment page'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget activity(
      List<TipActivity> activities, Map<String, double> userTipsByCreator) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeading(
          title: 'Activity',
          subtitle: 'Review your tip activity and earned supporter ranks',
        ),
        const SizedBox(height: 20),
        if (activities.isEmpty)
          const EmptyState(
            title: 'No activity yet',
            description: 'Your verified tip activity will appear here.',
          )
        else
          ...activities.reversed.map(
            (item) {
              final currentTotal = userTipsByCreator[item.creator] ?? 0.0;
              final rank = SupporterRank.getRankForAmount(currentTotal);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE8EEFF),
                        child: Text(
                          '\$',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.creator,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.date.toLocal()}'.split('.').first,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            dollars(item.amount),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: rank.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(rank.icon, size: 12, color: rank.color),
                                const SizedBox(width: 4),
                                Text(
                                  rank.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: rank.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget profile() {
    final displayName = widget.user.displayName ?? 'StreamerTipJar User';
    final userEmail = widget.user.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeading(
          title: 'Profile',
          subtitle: 'Application preferences and account details',
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryBlue,
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('$userEmail • Creator Support Account'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supporter Tier Thresholds',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildTierRow(SupporterRank.supporter, '\$1.00 – \$19.99'),
                const Divider(height: 16),
                _buildTierRow(
                    SupporterRank.activeSupporter, '\$20.00 – \$49.99'),
                const Divider(height: 16),
                _buildTierRow(SupporterRank.topSupporter, '\$50.00+'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Change the application appearance'),
            value: widget.isDarkMode,
            onChanged: (val) {
              widget.onThemeChanged(val);
            },
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'Log out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Sign out of StreamerTipJar'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTierRow(SupporterRank rank, String range) {
    return Row(
      children: [
        Icon(rank.icon, color: rank.color, size: 20),
        const SizedBox(width: 10),
        Text(
          rank.label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: rank.color,
          ),
        ),
        const Spacer(),
        Text(
          range,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> openPaiFlowPage() async {
    final uri = Uri.parse('http://localhost:3000/send');

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (opened) {
        showMessage('Browser launch requested. Continue on the PaiFlow page.');
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
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const presets = [1, 5, 20, 50];
    int? selectedAmount;

    final currentTotal = userTipsByCreator[creatorName] ?? 0.0;
    final currentRank = SupporterRank.getRankForAmount(currentTotal);

    try {
      final amount = await showDialog<double>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text('Support $creatorName'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 380,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Current Rank: '),
                              Icon(currentRank.icon,
                                  size: 16, color: currentRank.color),
                              const SizedBox(width: 4),
                              Text(
                                currentRank.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: currentRank.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Choose your tip amount in USD.'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: presets.map((value) {
                              return ChoiceChip(
                                label: Text('\$$value.00'),
                                selected: selectedAmount == value,
                                onSelected: (_) {
                                  setDialogState(() {
                                    selectedAmount = value;
                                    amountController.text = '$value';
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tip amount',
                              prefixText: '\$ ',
                              hintText: 'e.g. 5.00',
                            ),
                            onChanged: (_) {
                              setDialogState(() {
                                selectedAmount = null;
                              });
                            },
                            validator: (value) {
                              final input = value?.trim() ?? '';
                              final parsed = double.tryParse(input);

                              if (parsed == null ||
                                  !parsed.isFinite ||
                                  parsed <= 0) {
                                return 'Enter an amount greater than zero.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(
                          dialogContext,
                          double.parse(amountController.text.trim()),
                        );
                      }
                    },
                    child: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || amount == null) return;

      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Continue to Freighter'),
          content: Text(
            'You selected ${dollars(amount)} for $creatorName.\n\n'
            'This transaction will update your Supporter Rank to: '
            '${SupporterRank.getRankForAmount(currentTotal + amount).label}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open payment page'),
            ),
          ],
        ),
      );

      if (!mounted || shouldContinue != true) return;

      await addTipRecord(creatorName, amount);
      await openPaiFlowPage();
    } catch (error) {
      if (mounted) {
        showMessage('Could not continue: $error');
      }
    } finally {
      amountController.dispose();
    }
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final rank = SupporterRank.getRankForAmount(userTotalTip);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: creator.color,
                  child: Text(
                    creator.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              creator.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (rank != SupporterRank.none)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: rank.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(rank.icon,
                                      size: 13, color: rank.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    rank.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: rank.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        creator.username,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          creator.category,
                          style: const TextStyle(
                            color: primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              creator.description,
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  '${creator.supporters} supporters',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '${dollars(creator.totalTips)} community tips',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: onSupport,
                icon: const Icon(Icons.favorite_rounded, size: 18),
                label: const Text('Support Creator'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String description;

  const EmptyState({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 36,
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}