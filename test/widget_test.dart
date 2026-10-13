import 'package:flutter_test/flutter_test.dart';
import 'package:streamertipjar/main.dart';

void main() {
  testWidgets('StreamerTipJar app loads successfully', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StreamerTipJarApp());

    expect(find.text('StreamerTipJar'), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Bottom navigation changes pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StreamerTipJarApp());

    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();

    expect(find.text('Find your favorite creators'), findsOneWidget);

    await tester.tap(find.text('Wallet').last);
    await tester.pumpAndSettle();

    expect(find.text('Wallet overview'), findsOneWidget);

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    expect(find.text('Recent transactions'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    expect(find.text('Profile settings'), findsOneWidget);
  });

  testWidgets('Creator cards show support buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StreamerTipJarApp());

    expect(find.text('Yhatch Junio'), findsWidgets);
    expect(find.text('Jomira Moreno'), findsWidgets);
    expect(find.text('Gabee Morales'), findsWidgets);
    expect(find.text('Support creator'), findsWidgets);
  });
}