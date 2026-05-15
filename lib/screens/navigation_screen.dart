import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/providers/route_provider.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.secondary,
      body: Stack(
        children: [
          // Google Map
          Consumer<RouteProvider>(
            builder: (context, provider, child) {
              final initialPosition = provider.currentPosition != null
                  ? LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude)
                  : const LatLng(-6.200000, 106.816666);

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 18,
                  tilt: 45,
                ),
                markers: {
                  if (provider.activeRoute != null && provider.activeRoute!.requestedWaypoints.isNotEmpty) ...[
                    Marker(
                      markerId: const MarkerId('start'),
                      position: provider.activeRoute!.requestedWaypoints.first,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      infoWindow: const InfoWindow(title: 'Start'),
                      zIndex: 2,
                    ),
                    if (provider.activeRoute!.requestedWaypoints.length >= 3)
                      Marker(
                        markerId: const MarkerId('turnaround'),
                        position: provider.activeRoute!.requestedWaypoints[provider.activeRoute!.requestedWaypoints.length ~/ 2],
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                        infoWindow: const InfoWindow(title: 'Turnaround (50%)'),
                        zIndex: 1,
                      ),
                  ],
                  if (provider.currentPosition != null)
                    Marker(
                      markerId: const MarkerId('current'),
                      position: LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                },
                onMapCreated: (controller) {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                polylines: {
                  if (provider.currentRoute.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('active_route'),
                      points: provider.currentRoute,
                      color: KineticFlowTheme.primary,
                      width: 5,
                    ),
                  if (provider.traveledRoute.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('traveled_route'),
                      points: provider.traveledRoute,
                      color: const Color(0xFFFF5C35),
                      width: 8,
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
                ],
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

          // Arrival Detection Banner
          Consumer<RouteProvider>(
            builder: (context, provider, child) {
              if (!provider.isRunning) return const SizedBox.shrink();
              
              // Simple arrival logic: if > 50% distance and close to start (if loop)
              bool showArrival = provider.distanceTraveled > 0.5 && provider.currentRoute.isNotEmpty;
              if (!showArrival) return const SizedBox.shrink();

              return Positioned(
                top: 80,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.flag, color: KineticFlowTheme.tertiary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🏁 150m ke titik start', // Placeholder distance
                          style: KineticFlowTheme.lightTheme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
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
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Pace', '5:24', 'min/km'),
                          _buildStat('Distance', provider.distanceTraveled.toStringAsFixed(2), 'km'),
                          _buildStat('Time', provider.formattedTime, ''),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                provider.stopRun();
                                Navigator.pop(context);
                              },
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
                            onPressed: () => provider.togglePauseRun(),
                            backgroundColor: KineticFlowTheme.primary,
                            elevation: 0,
                            child: Icon(
                              provider.isRunning ? LucideIcons.pause : LucideIcons.play,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Location marked!'))
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: KineticFlowTheme.secondary,
                              ),
                              child: const Text('Mark'),
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

  // Removed _buildGradientPolylines helper


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
