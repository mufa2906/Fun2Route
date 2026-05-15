import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/providers/route_provider.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final distanceKm = ((args?['distanceM'] as num?) ?? 0.0) / 1000;
    final elapsedMs = (args?['elapsedMs'] as num?)?.toInt() ?? 0;
    final pausedMs = (args?['pausedMs'] as num?)?.toInt() ?? 0;
    final calories = (args?['calories'] as num?)?.toDouble() ?? 0.0;
    final offRouteCount = (args?['offRouteCount'] as num?)?.toInt() ?? 0;
    final activityType = args?['activityType'] as String? ?? 'walk_easy';

    final duration = Duration(milliseconds: elapsedMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final paceMin =
        distanceKm > 0 ? (duration.inSeconds / 60 / distanceKm) : 0.0;
    final paceMinWhole = paceMin.floor();
    final paceSec = ((paceMin - paceMinWhole) * 60).round();

    final (activityLabel, activityIcon) = _activityInfo(activityType);

    return Scaffold(
      backgroundColor: KineticFlowTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KineticFlowTheme.tertiary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.trophy,
                    size: 40, color: KineticFlowTheme.tertiary),
              ),
              const SizedBox(height: 20),
              Text('Great Job! 🎉',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Activity Complete',
                style: TextStyle(
                  color: KineticFlowTheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: KineticFlowTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(activityIcon, size: 16, color: KineticFlowTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      activityLabel,
                      style: const TextStyle(
                        color: KineticFlowTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            icon: LucideIcons.ruler,
                            label: 'Distance',
                            value: distanceKm.toStringAsFixed(2),
                            unit: 'km',
                            color: KineticFlowTheme.primary,
                          ),
                        ),
                        Container(width: 1, height: 60, color: Colors.grey.shade200),
                        Expanded(
                          child: _buildStatTile(
                            icon: LucideIcons.clock,
                            label: 'Duration',
                            value:
                                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            unit: '',
                            color: KineticFlowTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            icon: LucideIcons.gauge,
                            label: 'Avg Pace',
                            value:
                                '$paceMinWhole:${paceSec.toString().padLeft(2, '0')}',
                            unit: 'min/km',
                            color: Colors.blue,
                          ),
                        ),
                        Container(width: 1, height: 60, color: Colors.grey.shade200),
                        Expanded(
                          child: _buildStatTile(
                            icon: LucideIcons.flame,
                            label: 'Calories',
                            value: calories.toStringAsFixed(0),
                            unit: 'kcal',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (pausedMs > 0) _buildInfoBanner(
                icon: LucideIcons.pauseCircle,
                text: _formatPausedDuration(pausedMs),
                iconColor: Colors.blue.shade500,
                textColor: Colors.blue.shade700,
                bgColor: Colors.blue.shade50,
                borderColor: Colors.blue.shade100,
                margin: const EdgeInsets.only(bottom: 12),
              ),

              if (offRouteCount > 0) _buildInfoBanner(
                icon: LucideIcons.alertTriangle,
                text: 'Off-route $offRouteCount times',
                iconColor: Colors.amber.shade700,
                textColor: Colors.amber.shade800,
                bgColor: Colors.amber.shade50,
                borderColor: Colors.amber.shade200,
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.read<RouteProvider>().resetSession();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                },
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static (String label, IconData icon) _activityInfo(String type) {
    switch (type) {
      case 'walk_fast':
        return ('Fast Walk', LucideIcons.wind);
      case 'jog':
        return ('Jog', LucideIcons.activity);
      default:
        return ('Walk', LucideIcons.footprints);
    }
  }

  static String _formatPausedDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return 'Paused for ${d.inMinutes}m ${sec}s';
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        if (unit.isNotEmpty)
          Text(unit, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
