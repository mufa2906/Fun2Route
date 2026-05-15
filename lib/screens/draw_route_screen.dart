import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fun2route/theme.dart';

class DrawRouteScreen extends StatefulWidget {
  final LatLng initialPosition;
  const DrawRouteScreen({super.key, required this.initialPosition});

  @override
  State<DrawRouteScreen> createState() => _DrawRouteScreenState();
}

class _DrawRouteScreenState extends State<DrawRouteScreen> {
  final List<LatLng> _drawnPoints = [];
  RouteCandidate? _previewCandidate;
  bool _isLoading = false;
  bool _isLoop = true;

  Future<void> _updatePreview() async {
    if (_drawnPoints.length < 2) {
      setState(() => _previewCandidate = null);
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<RouteProvider>();
    
    // Generate through points
    final candidate = await provider.generateRouteThroughPoint(
      start: widget.initialPosition,
      waypoints: _drawnPoints,
      isLoop: _isLoop,
    );

    if (mounted) {
      setState(() {
        _previewCandidate = candidate;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Your Route'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_drawnPoints.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.undo),
              tooltip: 'Undo last point',
              onPressed: () => setState(() => _drawnPoints.removeLast()),
            ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: 'Clear all',
            onPressed: () => setState(() => _drawnPoints.clear()),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: widget.initialPosition, zoom: 15),
            onTap: (pos) {
              setState(() => _drawnPoints.add(pos));
              _updatePreview();
            },
            myLocationEnabled: true,
            markers: _buildMarkers(),
            polylines: {
              if (_previewCandidate != null)
                Polyline(
                  polylineId: const PolylineId('preview'),
                  points: _previewCandidate!.polyline,
                  color: KineticFlowTheme.primary,
                  width: 5,
                )
              else if (_drawnPoints.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('draw'),
                  points: _drawnPoints,
                  color: KineticFlowTheme.primary.withValues(alpha: 0.5),
                  width: 3,
                  patterns: [PatternItem.dash(10), PatternItem.gap(10)],
                )
            },
          ),
          
          // Hint Banner
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.info, color: KineticFlowTheme.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Tap on the map multiple times to draw your custom route path.'),
                  ),
                ],
              ),
            ),
          ),

          if (_drawnPoints.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Return to start', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: _isLoop, 
                          onChanged: (v) {
                            setState(() => _isLoop = v);
                            _updatePreview();
                          },
                          activeColor: KineticFlowTheme.primary,
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: LinearProgressIndicator(color: KineticFlowTheme.primary, backgroundColor: KineticFlowTheme.background),
                      )
                    else if (_previewCandidate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat('Distance', '${(_previewCandidate!.distanceM / 1000).toStringAsFixed(2)} km'),
                            _buildMiniStat('Est. Time', '${(_previewCandidate!.durationSec / 60).toStringAsFixed(0)} min'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_previewCandidate == null || _isLoading) ? null : () {
                              final provider = context.read<RouteProvider>();
                              provider.setActiveRoute(_previewCandidate!);
                              provider.startRun();
                              Navigator.pushReplacementNamed(context, '/navigation');
                            },
                            child: const Text('Start Now'),
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

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    Set<Marker> markers = {};
    
    markers.add(Marker(
      markerId: const MarkerId('origin'),
      position: widget.initialPosition,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'Start Location'),
    ));

    for (int i = 0; i < _drawnPoints.length; i++) {
       markers.add(Marker(
        markerId: MarkerId('point_$i'),
        position: _drawnPoints[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(
          title: 'Waypoint ${i + 1}',
          snippet: 'Tapped point on your path',
        ),
      ));
    }
    
    return markers;
  }
}
