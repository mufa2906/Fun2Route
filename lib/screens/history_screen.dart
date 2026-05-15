import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fun2route/providers/route_provider.dart';

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
        title: const Text(
          'Activity History',
          style: TextStyle(color: KineticFlowTheme.onSurface),
        ),
      ),
      body: Consumer<RouteProvider>(
        builder: (context, provider, child) {
          if (provider.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: KineticFlowTheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.footprints,
                        size: 36, color: KineticFlowTheme.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No activities yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your first session!',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final weekItems = _thisWeekHistory(provider.history);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        KineticFlowTheme.primary,
                        KineticFlowTheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This Week',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      weekItems.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No activities this week yet',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildWeeklyStat(
                                    'Sessions', '${weekItems.length}', LucideIcons.activity),
                                _buildWeeklyStat(
                                    'Distance', _totalDistance(weekItems), LucideIcons.ruler),
                                _buildWeeklyStat(
                                    'Calories', _totalCalories(weekItems), LucideIcons.flame),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: provider.history.length,
                  itemBuilder: (context, index) => _buildHistoryItem(
                    context, provider.history[index], index, provider,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static List<Map<String, dynamic>> _thisWeekHistory(
    List<Map<String, dynamic>> history,
  ) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month,
        now.day - (now.weekday - 1)); // ISO Monday
    return history.where((item) {
      final tsStr = item['timestamp'] as String?;
      if (tsStr == null) return true;
      final ts = DateTime.tryParse(tsStr);
      return ts != null && !ts.isBefore(weekStart);
    }).toList();
  }

  static double _parseKm(String raw) =>
      double.tryParse(raw.replaceAll(' km', '')) ?? 0;

  static double _parseKcal(String raw) =>
      double.tryParse(raw.replaceAll(' kcal', '')) ?? 0;

  static String _totalDistance(List<Map<String, dynamic>> history) {
    final total = history.fold<double>(
      0,
      (sum, item) => sum + _parseKm(item['distance'] as String? ?? '0'),
    );
    return '${total.toStringAsFixed(1)} km';
  }

  static String _totalCalories(List<Map<String, dynamic>> history) {
    final total = history.fold<double>(
      0,
      (sum, item) => sum + _parseKcal(item['calories'] as String? ?? '0'),
    );
    return total.toStringAsFixed(0);
  }

  static IconData _activityIcon(String type) {
    switch (type) {
      case 'walk_fast':
        return LucideIcons.wind;
      case 'jog':
        return LucideIcons.activity;
      default:
        return LucideIcons.footprints;
    }
  }

  Widget _buildWeeklyStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
    RouteProvider provider,
  ) {
    final activityType = item['activityType'] as String? ?? 'walk_easy';
    final icon = _activityIcon(activityType);

    return InkWell(
      onTap: () {
        final polylineData = item['polyline'] as List?;
        final polyline =
            polylineData?.map((e) => e as LatLng).toList() ?? <LatLng>[];
        provider.setActiveRoute(RouteCandidate(
          id: 'history_$index',
          distanceM: 0,
          durationSec: 0,
          polyline: polyline,
          requestedWaypoints:
              polyline.isNotEmpty ? [polyline.first, polyline.last] : [],
        ));
        Navigator.pushNamed(context, '/route_selection');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: KineticFlowTheme.outline.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: KineticFlowTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          color: KineticFlowTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String? ?? 'Activity',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          item['date'] as String? ?? '',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(LucideIcons.chevronRight,
                    size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetric('Distance', item['distance'] as String? ?? '-'),
                const SizedBox(width: 32),
                _buildMetric('Duration', item['time'] as String? ?? '-'),
                const SizedBox(width: 32),
                _buildMetric('Calories', item['calories'] as String? ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
