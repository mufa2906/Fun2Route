import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/theme.dart';
import 'package:fun2route/screens/onboarding_screen.dart';
import 'package:fun2route/screens/home_screen.dart';
import 'package:fun2route/screens/route_selection_screen.dart';
import 'package:fun2route/screens/navigation_screen.dart';
import 'package:fun2route/screens/history_screen.dart';
import 'package:fun2route/screens/summary_screen.dart';
import 'package:fun2route/providers/route_provider.dart';

const String googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Pass API key to iOS native layer via method channel
  _setupPlatformChannels();

  runApp(
    ChangeNotifierProvider(
      create: (_) => RouteProvider(),
      child: const FunRouteApp(),
    ),
  );
}

void _setupPlatformChannels() {
  if (googleMapsApiKey.isNotEmpty) {
    const platform = MethodChannel('com.fun2route/maps');
    platform.invokeMethod('setApiKey', googleMapsApiKey);
  }
}

class FunRouteApp extends StatelessWidget {
  const FunRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fun2Route',
      debugShowCheckedModeBanner: false,
      theme: KineticFlowTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
        '/route_selection': (context) => const RouteSelectionScreen(),
        '/navigation': (context) => const NavigationScreen(),
        '/summary': (context) => const SummaryScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
