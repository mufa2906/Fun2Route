import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:fun2route/screens/onboarding_screen.dart';
import 'package:fun2route/screens/home_screen.dart';
import 'package:fun2route/screens/route_selection_screen.dart';
import 'package:fun2route/screens/navigation_screen.dart';
import 'package:fun2route/screens/history_screen.dart';

void main() {
  runApp(const FunRouteApp());
}

class FunRouteApp extends StatelessWidget {
  const FunRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FunRoute',
      theme: KineticFlowTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/route_selection': (context) => const RouteSelectionScreen(),
        '/navigation': (context) => const NavigationScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
