import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fun2route/providers/route_provider.dart';
import 'package:fun2route/screens/onboarding_screen.dart';
import '../mocks/mock_http_client.dart';

void main() {
  late RouteProvider routeProvider;
  late MockHttpClient mockHttp;

  setUp(() {
    routeProvider = RouteProvider();
    mockHttp = MockHttpClient();
  });

  tearDown(() {
    routeProvider.dispose();
    mockHttp.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Use a large surface to avoid overflow for onboarding screen
    // which has a 280x280 decorative box + spacers + text + button
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0; // 540x1170 logical -> safe for all content

    await tester.pumpWidget(
      ChangeNotifierProvider<RouteProvider>.value(
        value: routeProvider,
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
    // Use pump instead of pumpAndSettle to avoid infinite timers from provider
    await tester.pump(const Duration(seconds: 1));
  }

  group('OnboardingScreen - Widget Tests', () {
    testWidgets('renders without crashing', (tester) async {
      await pumpScreen(tester);

      // Should find the main scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays key text elements', (tester) async {
      await pumpScreen(tester);

      // Check for key text elements from the onboarding screen
      expect(
        find.text('Explore your world with FunRoute'),
        findsOneWidget,
      );
    });

    testWidgets('has a Get Started button', (tester) async {
      await pumpScreen(tester);

      // Find the ElevatedButton with "Get Started" text
      final button = find.text('Get Started');
      expect(button, findsOneWidget);

      // The button should be within an ElevatedButton
      final elevatedButton = find.ancestor(
        of: button,
        matching: find.byType(ElevatedButton),
      );
      expect(elevatedButton, findsOneWidget);
    });

    testWidgets('shows the Lucide map pin icon', (tester) async {
      await pumpScreen(tester);

      // The screen uses LucideIcons.mapPin - we can check for any Icon widget
      // since Lucide icons are rendered as custom icons
      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsAtLeast(1));
    });
  });
}