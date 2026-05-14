import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.background,
      appBar: AppBar(
        backgroundColor: KineticFlowTheme.background,
        elevation: 0,
        title: Text(
          'FunRoute',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: KineticFlowTheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.user, color: KineticFlowTheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Where to today?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: KineticFlowTheme.outline.withValues(alpha: 0.2)),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search destination...',
                  border: InputBorder.none,
                  icon: Icon(LucideIcons.search, color: KineticFlowTheme.outline),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Recent Routes', () {}),
            const SizedBox(height: 16),
            _buildRouteCard(context, 'Sunset Boulevard', '5.2 km • 45 min', LucideIcons.sunset),
            _buildRouteCard(context, 'Riverside Trail', '12.8 km • 1h 20m', LucideIcons.waves),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Quick Actions', () {}),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(context, 'Draw Route', LucideIcons.pencil, KineticFlowTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(context, 'History', LucideIcons.history, KineticFlowTheme.secondary),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/route_selection'),
        backgroundColor: KineticFlowTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.zap),
        label: const Text('Generate Route'),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(
          onPressed: onTap,
          child: const Text('See All', style: TextStyle(color: KineticFlowTheme.primary)),
        ),
      ],
    );
  }

  Widget _buildRouteCard(BuildContext context, String title, String subtitle, IconData icon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: KineticFlowTheme.outline.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: KineticFlowTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: KineticFlowTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(LucideIcons.chevronRight, size: 16),
        onTap: () {},
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        if (title == 'History') {
          Navigator.pushNamed(context, '/history');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
