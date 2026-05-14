import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.background,
      appBar: AppBar(
        backgroundColor: KineticFlowTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: KineticFlowTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Activity History', style: TextStyle(color: KineticFlowTheme.onSurface)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 5,
        itemBuilder: (context, index) {
          return _buildHistoryItem(
            context,
            'Morning Run #${5 - index}',
            'May ${14 - index}, 2026',
            '${8.4 + index}.2 km',
            '${45 + index} min',
            index,
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, String title, String date, String distance, String time, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KineticFlowTheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 4),
          Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetric('Distance', distance),
              const SizedBox(width: 32),
              _buildMetric('Duration', time),
              const SizedBox(width: 32),
              _buildMetric('Pace', '5:${20 + index % 10}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
