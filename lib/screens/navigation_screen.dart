import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/providers/route_provider.dart';
import 'package:fun2route/screens/poi_marking_dialog.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool _isLoop = true;
  String _activityType = 'walk_easy';
  bool _argsParsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsParsed) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _activityType = args['activityType'] ?? 'walk_easy';
        _isLoop = args['isLoop'] ?? true;
        _argsParsed = true;
      }
    }

    // Attach arrival listener once provider is available
    final provider = context.read<RouteProvider>();
    provider.removeListener(_onProviderUpdate);
    provider.addListener(_onProviderUpdate);
  }

  @override
  void dispose() {
    context.read<RouteProvider>().removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = context.read<RouteProvider>();
    if (_isLoop && provider.isRunning && provider.checkLoopArrival()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showArrivalDialog(provider);
      });
    }
  }

  void _handleFinish(RouteProvider provider) {
    provider.stopRun();
    Navigator.pushReplacementNamed(
      context,
      '/summary',
      arguments: {
        'activityType': _activityType,
        'distanceM': provider.distanceTraveled * 1000,
        'elapsedMs': provider.secondsElapsed * 1000,
        'pausedMs': provider.pausedMs,
        'calories': provider.calories,
        'offRouteCount': provider.offRouteCount,
      },
    );
  }

  void _showArrivalDialog(RouteProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Almost There! 🎉'),
        content: const Text(
          'You are close to the starting point. Finish the activity?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Going'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleFinish(provider);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.secondary,
      body: Stack(
        children: [
          // Google Map with dashed planned route and solid traveled route
          Consumer<RouteProvider>(
            builder: (context, provider, child) {
              final initialPosition = provider.currentPosition != null
                  ? LatLng(
                      provider.currentPosition!.latitude,
                      provider.currentPosition!.longitude,
                    )
                  : const LatLng(-6.200000, 106.816666);

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 18,
                  tilt: 45,
                ),
                markers: {
                  // Start/Finish pin (green) for loop — from technical.md MapView
                  if (_isLoop &&
                      provider.activeRoute != null &&
                      provider.activeRoute!.requestedWaypoints.isNotEmpty)
                    Marker(
                      markerId: const MarkerId('start_finish'),
                      position: provider.activeRoute!.requestedWaypoints.first,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(title: 'Start / Finish'),
                      zIndexInt: 2,
                    ),
                  // Turnaround marker for non-loop
                  if (!_isLoop &&
                      provider.activeRoute != null &&
                      provider.activeRoute!.requestedWaypoints.length >= 2)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: provider.activeRoute!.requestedWaypoints.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: const InfoWindow(title: 'Destination'),
                      zIndexInt: 1,
                    ),
                },
                onMapCreated: (controller) {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                polylines: {
                  // Planned route — dashed gray (#94A3B8) from technical.md
                  if (provider.currentRoute.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('planned_route'),
                      points: provider.currentRoute,
                      color: const Color(0xFF94A3B8),
                      width: 4,
                      patterns: [PatternItem.dash(15), PatternItem.gap(10)],
                    ),
                  // Traveled route — solid orange (#FF5C35) from technical.md
                  if (provider.traveledRoute.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('traveled_route'),
                      points: provider.traveledRoute,
                      color: const Color(0xFFFF5C35),
                      width: 6,
                    ),
                },
              );
            },
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.navigation,
                    size: 28,
                    color: KineticFlowTheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<RouteProvider>(
                      builder: (context, provider, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.navigationState ==
                                      NavigationState.autoPaused
                                  ? 'Auto-Paused'
                                  : provider.navigationState ==
                                        NavigationState.paused
                                  ? 'Paused'
                                  : 'Navigation Active',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Following planned route',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Auto-Pause Badge
                  Consumer<RouteProvider>(
                    builder: (context, provider, _) {
                      if (provider.navigationState ==
                          NavigationState.autoPaused) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'AUTO',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Loop Arrival Detection Banner — from flows.md §7
          Consumer<RouteProvider>(
            builder: (context, provider, child) {
              if (!_isLoop) return const SizedBox.shrink();
              if (!provider.shouldShowArrivalBanner) {
                return const SizedBox.shrink();
              }

              double distToStartM = provider.distanceToStart();
              String distText = distToStartM.isFinite
                  ? '${distToStartM.toStringAsFixed(0)}m'
                  : '...';

              return Positioned(
                top: 140,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: KineticFlowTheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: KineticFlowTheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.flag,
                        color: KineticFlowTheme.tertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🏁 $distText to start point',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: KineticFlowTheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Off-Route Warning
          Consumer<RouteProvider>(
            builder: (context, provider, child) {
              if (provider.offRouteCount > 0 && provider.isRunning) {
                return Positioned(
                  top: _isLoop && provider.shouldShowArrivalBanner ? 200 : 140,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.alertCircle,
                          color: Colors.red.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Off-route ${provider.offRouteCount}x — get back on track',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
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
              child: Consumer<RouteProvider>(
                builder: (context, provider, child) {
                  // Calculate pace
                  double distKm = provider.distanceTraveled;
                  double paceMin = distKm > 0
                      ? (provider.secondsElapsed / 60.0) / distKm
                      : 0;
                  int paceMinWhole = paceMin.floor();
                  int paceSec = ((paceMin - paceMinWhole) * 60).round();
                  String paceStr =
                      '$paceMinWhole:${paceSec.toString().padLeft(2, '0')}';

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Pace', paceStr, 'min/km'),
                          _buildStat(
                            'Distance',
                            provider.distanceTraveled.toStringAsFixed(2),
                            'km',
                          ),
                          _buildStat('Time', provider.formattedTime, ''),
                          _buildStat(
                            'Cal',
                            provider.calories.toStringAsFixed(0),
                            'kcal',
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          // End Run → Summary
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleFinish(provider),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('End Run'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Pause/Resume
                          FloatingActionButton(
                            onPressed: () => provider.togglePauseRun(),
                            backgroundColor: KineticFlowTheme.primary,
                            elevation: 0,
                            child: Icon(
                              (provider.navigationState ==
                                          NavigationState.active ||
                                      provider.navigationState ==
                                          NavigationState.resumed)
                                  ? LucideIcons.pause
                                  : LucideIcons.play,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Mark POI — from flows.md §10
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await showDialog<PoiResult>(
                                  context: context,
                                  builder: (_) => const PoiMarkingDialog(),
                                );
                                if (result != null &&
                                    provider.currentPosition != null) {
                                  if (result.isAvoidance) {
                                    provider.addAvoidanceZone(
                                      provider.currentPosition!.latitude,
                                      provider.currentPosition!.longitude,
                                      result.note,
                                    );
                                  } else {
                                    provider.addPoi(
                                      provider.currentPosition!.latitude,
                                      provider.currentPosition!.longitude,
                                      result.note,
                                    );
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result.isAvoidance
                                              ? 'Avoidance zone saved'
                                              : 'Location marked!',
                                        ),
                                        backgroundColor: result.isAvoidance
                                            ? Colors.red.shade400
                                            : KineticFlowTheme.tertiary,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: KineticFlowTheme.secondary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: const Icon(LucideIcons.mapPin, size: 16),
                              label: const Text('Mark'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
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
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        if (unit.isNotEmpty)
          Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
