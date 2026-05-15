import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fun2route/providers/route_provider.dart';
import 'package:fun2route/screens/home_screen.dart';

void main() {
  late RouteProvider routeProvider;

  setUp(() {
    routeProvider = RouteProvider();
  });

  tearDown(() {
    routeProvider.dispose();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<RouteProvider>.value(
        value: routeProvider,
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    // Use pump instead of pumpAndSettle to avoid infinite timers
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('HomeScreen - Widget Tests', () {
    testWidgets('renders main headline text', (tester) async {
      await pumpHome(tester);

      expect(find.text('Fun2Route'), findsOneWidget);
      expect(find.text('Ready for a session?'), findsOneWidget);
    });

    testWidgets('shows activity type chips', (tester) async {
      await pumpHome(tester);

      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Fast Walk'), findsOneWidget);
      expect(find.text('Jog'), findsOneWidget);
    });

    testWidgets('shows target mode toggle', (tester) async {
      await pumpHome(tester);

      expect(find.text('Target Based On'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
    });

    testWidgets('shows distance presets', (tester) async {
      await pumpHome(tester);

      // Default is distance mode, so show km presets
      expect(find.text('1 km'), findsOneWidget);
      expect(find.text('3 km'), findsOneWidget);
      expect(find.text('5 km'), findsOneWidget);
    });

    testWidgets('shows loop toggle', (tester) async {
      await pumpHome(tester);

      expect(find.text('Return to start (Loop)'), findsOneWidget);
    });

    testWidgets('shows route feel personality chips', (tester) async {
      await pumpHome(tester);

      expect(find.text('Route Feel'), findsOneWidget);
      expect(find.text('Smooth'), findsOneWidget);
      expect(find.text('Stroll'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
    });

    testWidgets('renders target distance input field', (tester) async {
      await pumpHome(tester);

      // The TextField with target distance
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
    });
  });
}