import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/providers/route_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fun2route/screens/draw_route_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedActivity = 'walk_easy';
  bool _isLoop = true;
  bool _isDistanceTarget = true; // true: distance, false: duration
  final TextEditingController _targetCtrl = TextEditingController(text: '3.0');
  List<LatLng>? _drawnWaypoints;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteProvider>().updateCurrentLocation();
    });
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fun2Route', style: KineticFlowTheme.lightTheme.textTheme.headlineLarge),
                      Text('Ready for a session?', style: TextStyle(color: KineticFlowTheme.onSurfaceVariant)),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: KineticFlowTheme.primary.withValues(alpha: 0.1),
                    child: const Icon(LucideIcons.user, color: KineticFlowTheme.primary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Activity Type
                  Text('Activity Type', style: KineticFlowTheme.lightTheme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildActivityChip('Walk', 'walk_easy', LucideIcons.footprints),
                      const SizedBox(width: 12),
                      _buildActivityChip('Fast Walk', 'walk_fast', LucideIcons.wind),
                      const SizedBox(width: 12),
                      _buildActivityChip('Jog', 'jog', LucideIcons.activity),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Target Mode Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target Based On', style: KineticFlowTheme.lightTheme.textTheme.titleMedium),
                      ToggleButtons(
                        isSelected: [_isDistanceTarget, !_isDistanceTarget],
                        onPressed: (index) {
                          setState(() {
                            _isDistanceTarget = index == 0;
                            _targetCtrl.text = _isDistanceTarget ? '3.0' : '30';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: KineticFlowTheme.primary,
                        color: KineticFlowTheme.outline,
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Distance')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Duration')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Target Input
                  TextField(
                    controller: _targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isDistanceTarget ? 'Target Distance (km)' : 'Target Duration (min)',
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: KineticFlowTheme.primary)),
                      suffixText: _isDistanceTarget ? 'km' : 'min',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Draw Route Section
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Custom Drawn Route (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_drawnWaypoints != null ? '${_drawnWaypoints!.length} points drawn' : 'Draw your own route map'),
                    trailing: TextButton(
                      onPressed: () async {
                        final pos = context.read<RouteProvider>().currentPosition;
                        if (pos == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wait for location...')));
                          return;
                        }
                        final initialPos = LatLng(pos.latitude, pos.longitude);
                        final result = await Navigator.push(context, MaterialPageRoute(
                          builder: (context) => DrawRouteScreen(initialPosition: initialPos),
                        ));
                        if (result != null && result is List<LatLng>) {
                          setState(() => _drawnWaypoints = result);
                        }
                      },
                      child: Text(_drawnWaypoints != null ? 'Edit' : 'Draw Route', style: const TextStyle(color: KineticFlowTheme.primary)),
                    ),
                  ),
                  if (_drawnWaypoints != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _drawnWaypoints = null),
                        child: const Text('Clear Route', style: TextStyle(color: Colors.red)),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Loop Toggle
                  SwitchListTile(
                    title: const Text('Return to start (Loop)'),
                    value: _isLoop,
                    activeColor: KineticFlowTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _isLoop = val),
                  ),
                  const SizedBox(height: 32),

                  // Generate Button
                  Consumer<RouteProvider>(
                    builder: (context, provider, child) {
                      return ElevatedButton(
                        onPressed: provider.isLoading 
                          ? null 
                          : () async {
                              double val = double.tryParse(_targetCtrl.text) ?? (_isDistanceTarget ? 3.0 : 30.0);
                              double distanceM = 0;
                              if (_isDistanceTarget) {
                                distanceM = val * 1000;
                              } else {
                                // duration in minutes to distance
                                double speedKmh = RouteProvider.DEFAULT_SPEEDS_KMH[_selectedActivity] ?? 5.0;
                                distanceM = (speedKmh * val / 60) * 1000;
                              }

                              await provider.generateRoutes(
                                targetDistanceM: distanceM,
                                activityType: _selectedActivity,
                                isLoop: _isLoop,
                                drawnWaypoints: _drawnWaypoints,
                              );
                              
                              if (mounted) {
                                if (provider.generatedRoutes.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No routes found. Try a different distance or direction.'))
                                  );
                                } else {
                                  Navigator.pushNamed(context, '/route_selection');
                                }
                              }
                            },
                        child: provider.isLoading 
                          ? const SizedBox(
                              height: 24, 
                              width: 24, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : const Text('Generate Route'),
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // Quick Actions
                  Text('Quick Actions', style: KineticFlowTheme.lightTheme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionCard(
                        'History', 
                        LucideIcons.history, 
                        () => Navigator.pushNamed(context, '/history')
                      ),
                      const SizedBox(width: 16),
                      _buildActionCard(
                        'Draw Route', 
                        LucideIcons.pencil, 
                        () {
                          final pos = context.read<RouteProvider>().currentPosition;
                          if (pos == null) return;
                          final initialPos = LatLng(pos.latitude, pos.longitude);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => DrawRouteScreen(initialPosition: initialPos),
                          )).then((result) {
                            if (result != null && result is List<LatLng>) {
                               setState(() => _drawnWaypoints = result);
                            }
                          });
                        }
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChip(String label, String id, IconData icon) {
    bool isSelected = _selectedActivity == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedActivity = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? KineticFlowTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? KineticFlowTheme.primary : KineticFlowTheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : KineticFlowTheme.primary),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: isSelected ? Colors.white : KineticFlowTheme.onSurface,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KineticFlowTheme.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: KineticFlowTheme.primary, size: 28),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
