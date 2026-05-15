import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/providers/route_provider.dart';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<RouteProvider>(
        builder: (context, provider, child) {
          final initialPosition = provider.currentPosition != null
              ? LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude)
              : const LatLng(-6.200000, 106.816666);

          return Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  if (provider.currentRoute.isNotEmpty) {
                    LatLngBounds bounds = LatLngBounds(
                      southwest: LatLng(
                        provider.currentRoute.map((e) => e.latitude).reduce((a, b) => a < b ? a : b),
                        provider.currentRoute.map((e) => e.longitude).reduce((a, b) => a < b ? a : b),
                      ),
                      northeast: LatLng(
                        provider.currentRoute.map((e) => e.latitude).reduce((a, b) => a > b ? a : b),
                        provider.currentRoute.map((e) => e.longitude).reduce((a, b) => a > b ? a : b),
                      ),
                    );
                    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
                  }
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                polylines: {
                  if (provider.currentRoute.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: provider.currentRoute,
                      color: KineticFlowTheme.primary,
                      width: 5,
                    ),
                },
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
                },
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
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 24),
                      Text('Select Route Option', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      
                      // Metrics
                      if (provider.activeRoute != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMetric(context, 'Distance', (provider.activeRoute!.distanceM / 1000).toStringAsFixed(2), 'km'),
                            _buildMetric(context, 'Est. Time', (provider.activeRoute!.durationSec / 60).toStringAsFixed(0), 'min'),
                            _buildMetric(context, 'Flow Score', provider.activeRoute!.score.toStringAsFixed(0), '/100'),
                          ],
                        ),
                      
                      const SizedBox(height: 24),

                      // Candidate Selection
                      if (provider.generatedRoutes.length > 1)
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.generatedRoutes.length,
                            itemBuilder: (context, index) {
                              bool isActive = provider.activeRoute == provider.generatedRoutes[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('Option ${index + 1} (${provider.generatedRoutes[index].score.toStringAsFixed(0)})', style: TextStyle(
                                    color: isActive ? Colors.white : KineticFlowTheme.onSurface,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  )),
                                  selected: isActive,
                                  selectedColor: KineticFlowTheme.primary,
                                  backgroundColor: KineticFlowTheme.surfaceContainerHigh,
                                  checkmarkColor: Colors.white,
                                  onSelected: (val) {
                                    if (val) provider.setActiveRoute(provider.generatedRoutes[index]);
                                  },
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                provider.startRun();
                                Navigator.pushNamed(context, '/navigation');
                              },
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
          );
        },
      ),
    );
  }

  // Removed _buildGradientPolylines as requested (simplified to single solid line)


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
            Text(value, style: KineticFlowTheme.statsXl.copyWith(fontSize: 32)),
            const SizedBox(width: 4),
            Text(unit, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
