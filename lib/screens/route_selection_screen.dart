import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RouteSelectionScreen extends StatelessWidget {
  const RouteSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Placeholder
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.map, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Map View Placeholder', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 48,
            left: 24,
            child: FloatingActionButton.small(
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.white,
              foregroundColor: KineticFlowTheme.onSurface,
              child: const Icon(LucideIcons.arrowLeft),
            ),
          ),

          // Route Details Drawer
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Optimal Route Found', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(context, 'Distance', '8.4', 'km'),
                      _buildMetric(context, 'Est. Time', '52', 'min'),
                      _buildMetric(context, 'Elev. Gain', '120', 'm'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Options'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/navigation'),
                          child: const Text('Start Navigation'),
                        ),
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

  Widget _buildMetric(BuildContext context, String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: KineticFlowTheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: KineticFlowTheme.statsXl),
            const SizedBox(width: 4),
            Text(unit, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
