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
  GoogleMapController? _mapController;
  RouteCandidate? _lastActiveRoute;

  void _fitRouteBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            lats.reduce((a, b) => a < b ? a : b),
            lngs.reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            lats.reduce((a, b) => a > b ? a : b),
            lngs.reduce((a, b) => a > b ? a : b),
          ),
        ),
        60,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final targetDistanceM = args?['targetDistanceM'] as double? ?? 3000.0;
    final activityType = args?['activityType'] as String? ?? 'walk_easy';
    final isLoop = args?['isLoop'] as bool? ?? true;

    return Scaffold(
      body: Consumer<RouteProvider>(
        builder: (context, provider, child) {
          final initialPosition = provider.currentPosition != null
              ? LatLng(
                  provider.currentPosition!.latitude,
                  provider.currentPosition!.longitude,
                )
              : const LatLng(-6.200000, 106.816666);

          // Distance mismatch check (from flows.md §5 & prd.md §3)
          double mismatchPercent = provider.getDistanceMismatchPercent(
            targetDistanceM,
          );
          bool showMismatchBanner = mismatchPercent > 20;

          // Re-fit camera whenever the selected route changes
          if (provider.activeRoute != null &&
              provider.activeRoute != _lastActiveRoute) {
            _lastActiveRoute = provider.activeRoute;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitRouteBounds(provider.activeRoute!.polyline);
            });
          }

          return Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (provider.currentRoute.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fitRouteBounds(provider.currentRoute);
                    });
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
                  if (provider.activeRoute != null &&
                      provider.activeRoute!.requestedWaypoints.isNotEmpty) ...[
                    Marker(
                      markerId: const MarkerId('start'),
                      position: provider.activeRoute!.requestedWaypoints.first,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(title: 'Start'),
                      zIndexInt: 2,
                    ),
                    if (provider.activeRoute!.requestedWaypoints.length >= 3)
                      Marker(
                        markerId: const MarkerId('turnaround'),
                        position:
                            provider.activeRoute!.requestedWaypoints[provider
                                    .activeRoute!
                                    .requestedWaypoints
                                    .length ~/
                                2],
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                        infoWindow: const InfoWindow(title: 'Turnaround (50%)'),
                        zIndexInt: 1,
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

              // Distance Mismatch Banner (from flows.md §5)
              if (showMismatchBanner)
                Positioned(
                  top: 100,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.alertTriangle,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Route available ≈ ${(provider.activeRoute!.distanceM / 1000).toStringAsFixed(1)} km, '
                            'you requested ${(targetDistanceM / 1000).toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Route Details Drawer
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                      Text(
                        'Select Route Option',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),

                      // Metrics
                      if (provider.activeRoute != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMetric(
                              context,
                              'Distance',
                              (provider.activeRoute!.distanceM / 1000)
                                  .toStringAsFixed(2),
                              'km',
                            ),
                            _buildMetric(
                              context,
                              'Est. Time',
                              (provider.activeRoute!.durationSec / 60)
                                  .toStringAsFixed(0),
                              'min',
                            ),
                            _buildMetric(
                              context,
                              'Flow Score',
                              provider.activeRoute!.score.toStringAsFixed(0),
                              '/100',
                            ),
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
                              bool isActive =
                                  provider.activeRoute ==
                                  provider.generatedRoutes[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    'Option ${index + 1} (${provider.generatedRoutes[index].score.toStringAsFixed(0)})',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : KineticFlowTheme.onSurface,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  selected: isActive,
                                  selectedColor: KineticFlowTheme.primary,
                                  backgroundColor:
                                      KineticFlowTheme.surfaceContainerHigh,
                                  checkmarkColor: Colors.white,
                                  onSelected: (val) {
                                    if (val) {
                                      provider.setActiveRoute(
                                        provider.generatedRoutes[index],
                                      );
                                    }
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
                                provider.startRun(activityType: activityType);
                                Navigator.pushNamed(
                                  context,
                                  '/navigation',
                                  arguments: {
                                    'activityType': activityType,
                                    'isLoop': isLoop,
                                  },
                                );
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

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: KineticFlowTheme.onSurfaceVariant,
          ),
        ),
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
