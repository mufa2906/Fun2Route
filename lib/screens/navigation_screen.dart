import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.secondary, // Dark Slate as per designMd
      body: Stack(
        children: [
          // Navigation Map Placeholder
          Container(
            color: KineticFlowTheme.secondary,
            child: const Center(
              child: Icon(LucideIcons.navigation, size: 80, color: KineticFlowTheme.primary),
            ),
          ),

          // Header: Next Instruction
          Positioned(
            top: 64,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.undo2, size: 32, color: KineticFlowTheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Turn left in 200m',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'onto Green Valley Road',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Stats Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Pace', '5:24', 'min/km'),
                      _buildStat('Distance', '3.2', 'km'),
                      _buildStat('Time', '17:45', ''),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('End Run'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        onPressed: () {},
                        backgroundColor: KineticFlowTheme.primary,
                        child: const Icon(LucideIcons.pause, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: SizedBox(), // Spacer
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
