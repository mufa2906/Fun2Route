import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: KineticFlowTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    LucideIcons.mapPin,
                    size: 120,
                    color: KineticFlowTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Explore your world with FunRoute',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Automated route generator for high-performance fitness. Energy, precision, and motivation.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: KineticFlowTheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
