import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_screen.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'neon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const JarJarApp());
}

class JarJarApp extends StatefulWidget {
  const JarJarApp({super.key});

  @override
  State<JarJarApp> createState() => _JarJarAppState();
}

class _JarJarAppState extends State<JarJarApp> {
  bool isDarkMode = true;

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
