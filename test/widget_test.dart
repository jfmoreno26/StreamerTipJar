import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamertipjar/main.dart';
import 'package:streamertipjar/neon.dart';

// JarJarApp and HomeScreen need a live Firebase connection, so these tests
// cover the pure helpers and the auth screen, which only touches Firebase
// once a form is submitted with valid input.

Widget _authScreen() {
  return MaterialApp(
    theme: buildNeonTheme(Brightness.dark),
    home: AuthWrapperScreen(isDarkMode: true, onThemeChanged: (_) {}),
  );
}

// Forms can be taller than the test screen, so scroll before tapping.
Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
}

// The neon background animates forever, so pumpAndSettle would never return.
Future<void> _pumpTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('helpers', () {
    test('dollars formats to two decimals', () {
      expect(dollars(5), '\$5.00');
      expect(dollars(12.5), '\$12.50');
    });

    test('initialsOf takes up to two initials', () {
      expect(initialsOf('Yhatch Junio'), 'YJ');
      expect(initialsOf('gabee'), 'G');
      expect(initialsOf('a b c'), 'AB');
      expect(initialsOf('   '), 'J');
    });

    test('creatorNamed finds known creators only', () {
      expect(creatorNamed('Jomira Moreno')?.username, '@jomirafionnaTV');
      expect(creatorNamed('Nobody'), isNull);
    });
  });

  group('SupporterRank', () {
    test('maps tip totals to ranks', () {
      expect(SupporterRank.getRankForAmount(0), SupporterRank.none);
      expect(SupporterRank.getRankForAmount(0.01), SupporterRank.supporter);
      expect(SupporterRank.getRankForAmount(19.99), SupporterRank.supporter);
      expect(SupporterRank.getRankForAmount(20), SupporterRank.activeSupporter);
      expect(SupporterRank.getRankForAmount(50), SupporterRank.topSupporter);
    });
  });

  group('TipActivity.fromFirestore', () {
    test('reads a full document', () {
      final date = DateTime(2026, 10, 14, 12);
      final tip = TipActivity.fromFirestore({
        'creator': 'Yhatch Junio',
        'amount': 15,
        'date': Timestamp.fromDate(date),
        'status': tipSuccess,
      });

      expect(tip.creator, 'Yhatch Junio');
      expect(tip.amount, 15.0);
      expect(tip.date, date);
      expect(tip.status, tipSuccess);
    });

    test('falls back to defaults for missing fields', () {
      final tip = TipActivity.fromFirestore({});

      expect(tip.creator, '');
      expect(tip.amount, 0.0);
      expect(tip.status, tipPending);
    });
  });

  group('AuthWrapperScreen', () {
    testWidgets('shows the sign-in form first', (tester) async {
      await tester.pumpWidget(_authScreen());
      await _pumpTransition(tester);

      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('CREATE AN ACCOUNT'), findsOneWidget);
    });

    testWidgets('switches between sign-in, register and reset views', (
      tester,
    ) async {
      await tester.pumpWidget(_authScreen());
      await _pumpTransition(tester);

      await _tap(tester, 'CREATE AN ACCOUNT');
      await _pumpTransition(tester);
      expect(find.text('SIGN UP'), findsOneWidget);

      await _tap(tester, 'Sign In');
      await _pumpTransition(tester);
      expect(find.text('SIGN IN'), findsOneWidget);

      await _tap(tester, 'Forgot Password?');
      await _pumpTransition(tester);
      expect(find.text('SEND RESET LINK'), findsOneWidget);

      await _tap(tester, 'BACK TO SIGN IN');
      await _pumpTransition(tester);
      expect(find.text('SIGN IN'), findsOneWidget);
    });

    testWidgets('empty sign-in shows a validation message', (tester) async {
      await tester.pumpWidget(_authScreen());
      await _pumpTransition(tester);

      await _tap(tester, 'SIGN IN');
      await _pumpTransition(tester);

      expect(
        find.text('Please fill in both email and password.'),
        findsOneWidget,
      );
    });
  });
}
