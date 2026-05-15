import 'package:flutter/material.dart';
import 'package:fun2route/theme.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:fun2route/providers/route_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fun2route/screens/draw_route_screen.dart';
import 'package:fun2route/screens/destination_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedActivity = 'walk_easy';
  bool _isLoop = true;
  bool _isDistanceTarget = true;
  final TextEditingController _targetCtrl = TextEditingController(text: '3.0');
  List<LatLng>? _drawnWaypoints;
  LatLng? _destination;
  RoutePersonality _selectedPersonality = RoutePersonality.smoothJog;

  static const List<double> _distancePresets = [1, 2, 3, 5, 7, 10];
  static const List<int> _durationPresets = [15, 20, 30, 45, 60, 90];
  double? _selectedPreset;

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

  double _targetDistanceM() {
    final val = double.tryParse(_targetCtrl.text) ??
        (_isDistanceTarget ? 3.0 : 30.0);
    if (_isDistanceTarget) return val * 1000;
    final speedKmh =
        RouteProvider.defaultSpeedsKmh[_selectedActivity] ?? 5.0;
    return (speedKmh * val / 60) * 1000;
  }

  Future<void> _openDrawRoute() async {
    final pos = context.read<RouteProvider>().currentPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for location...')),
      );
      return;
    }
    final result = await Navigator.push<List<LatLng>>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawRouteScreen(
          initialPosition: LatLng(pos.latitude, pos.longitude),
          activityType: _selectedActivity,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _drawnWaypoints = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KineticFlowTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fun2Route',
                        style: KineticFlowTheme.lightTheme.textTheme.headlineLarge,
                      ),
                      Text(
                        'Ready for a session?',
                        style: TextStyle(color: KineticFlowTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor:
                        KineticFlowTheme.primary.withValues(alpha: 0.1),
                    child: const Icon(LucideIcons.user,
                        color: KineticFlowTheme.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Text(
                    'Activity Type',
                    style: KineticFlowTheme.lightTheme.textTheme.titleMedium,
                  ),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Target Based On',
                          style: KineticFlowTheme.lightTheme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ToggleButtons(
                        isSelected: [_isDistanceTarget, !_isDistanceTarget],
                        onPressed: (index) {
                          setState(() {
                            _isDistanceTarget = index == 0;
                            _selectedPreset = null;
                            _targetCtrl.text = _isDistanceTarget ? '3.0' : '30';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: KineticFlowTheme.primary,
                        color: KineticFlowTheme.outline,
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Distance'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Duration'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _isDistanceTarget
                          ? _distancePresets.length
                          : _durationPresets.length,
                      itemBuilder: (context, index) {
                        final value = _isDistanceTarget
                            ? _distancePresets[index]
                            : _durationPresets[index].toDouble();
                        final label = _isDistanceTarget
                            ? '${value.toInt()} km'
                            : '${value.toInt()} min';
                        final isSelected = _selectedPreset == value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            selectedColor: KineticFlowTheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : KineticFlowTheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            checkmarkColor: Colors.white,
                            backgroundColor:
                                KineticFlowTheme.surfaceContainerHigh,
                            onSelected: (val) {
                              setState(() {
                                _selectedPreset = val ? value : null;
                                if (val) {
                                  _targetCtrl.text = _isDistanceTarget
                                      ? value.toString()
                                      : value.toInt().toString();
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _targetCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _isDistanceTarget
                          ? 'Target Distance (km)'
                          : 'Target Duration (min)',
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: KineticFlowTheme.primary),
                      ),
                      suffixText: _isDistanceTarget ? 'km' : 'min',
                    ),
                    onChanged: (_) => setState(() => _selectedPreset = null),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Return to start (Loop)'),
                    value: _isLoop,
                    activeThumbColor: KineticFlowTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isLoop = val;
                        if (val) _destination = null;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Route Feel',
                    style: KineticFlowTheme.lightTheme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPersonalityChip(
                        'Smooth',
                        RoutePersonality.smoothJog,
                        LucideIcons.arrowRight,
                        'Long straights, few turns',
                      ),
                      const SizedBox(width: 10),
                      _buildPersonalityChip(
                        'Stroll',
                        RoutePersonality.stroll,
                        LucideIcons.coffee,
                        'Calmer roads, shorter blocks',
                      ),
                      const SizedBox(width: 10),
                      _buildPersonalityChip(
                        'Explorer',
                        RoutePersonality.explorer,
                        LucideIcons.compass,
                        'More variety, novel streets',
                      ),
                    ],
                  ),

                  if (!_isLoop) ...[
                    const SizedBox(height: 8),
                    _buildDestinationTile(),
                  ],

                  const SizedBox(height: 16),
                  _buildDrawRouteTile(),
                  if (_drawnWaypoints != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _drawnWaypoints = null),
                        child: const Text(
                          'Clear Route',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  Consumer<RouteProvider>(
                    builder: (context, provider, _) => ElevatedButton(
                      onPressed:
                          provider.isLoading ? null : () => _onGenerate(provider),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Generate Route'),
                    ),
                  ),
                  const SizedBox(height: 48),

                  Text(
                    'Quick Actions',
                    style: KineticFlowTheme.lightTheme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildActionCard(
                        'History',
                        LucideIcons.history,
                        () => Navigator.pushNamed(context, '/history'),
                      ),
                      const SizedBox(width: 16),
                      _buildActionCard(
                        'Draw Route',
                        LucideIcons.pencil,
                        _openDrawRoute,
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

  Future<void> _onGenerate(RouteProvider provider) async {
    final distanceM = _targetDistanceM();
    final effectiveWaypoints = _drawnWaypoints ??
        (_destination != null ? [_destination!] : null);

    await provider.generateRoutes(
      targetDistanceM: distanceM,
      activityType: _selectedActivity,
      isLoop: _isLoop,
      personality: _selectedPersonality,
      drawnWaypoints: effectiveWaypoints,
    );

    if (!mounted) return;
    if (provider.generatedRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No routes found. Try a different distance or direction.'),
        ),
      );
    } else {
      Navigator.pushNamed(
        context,
        '/route_selection',
        arguments: {
          'targetDistanceM': distanceM,
          'activityType': _selectedActivity,
          'isLoop': _isLoop,
        },
      );
    }
  }

  Widget _buildDestinationTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _destination != null
              ? KineticFlowTheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          LucideIcons.mapPin,
          color: _destination != null
              ? KineticFlowTheme.primary
              : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        _destination != null ? 'Destination set' : 'Pick a destination (optional)',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: _destination != null
              ? KineticFlowTheme.primary
              : KineticFlowTheme.onSurface,
        ),
      ),
      subtitle: _destination != null
          ? Text(
              '${_destination!.latitude.toStringAsFixed(4)}, '
              '${_destination!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_destination != null)
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18, color: Colors.red),
              onPressed: () => setState(() => _destination = null),
            ),
          TextButton(
            onPressed: _pickDestination,
            child: Text(
              _destination != null ? 'Change' : 'Select',
              style: const TextStyle(color: KineticFlowTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDestination() async {
    final pos = context.read<RouteProvider>().currentPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for location...')),
      );
      return;
    }
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationSelectionScreen(
          initialPosition: LatLng(pos.latitude, pos.longitude),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) setState(() => _destination = result);
  }

  Widget _buildDrawRouteTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Custom Drawn Route (Optional)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _drawnWaypoints != null
            ? '${_drawnWaypoints!.length} points drawn'
            : 'Draw your own route map',
      ),
      trailing: TextButton(
        onPressed: _openDrawRoute,
        child: Text(
          _drawnWaypoints != null ? 'Edit' : 'Draw Route',
          style: const TextStyle(color: KineticFlowTheme.primary),
        ),
      ),
    );
  }

  Widget _buildActivityChip(String label, String id, IconData icon) {
    final isSelected = _selectedActivity == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedActivity = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? KineticFlowTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? KineticFlowTheme.primary
                  : KineticFlowTheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : KineticFlowTheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : KineticFlowTheme.onSurface,
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalityChip(
    String label,
    RoutePersonality personality,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = _selectedPersonality == personality;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () => setState(() => _selectedPersonality = personality),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? KineticFlowTheme.primary.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? KineticFlowTheme.primary
                    : KineticFlowTheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? KineticFlowTheme.primary
                      : KineticFlowTheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? KineticFlowTheme.primary
                        : KineticFlowTheme.onSurface,
                  ),
                ),
              ],
            ),
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
            border: Border.all(
              color: KineticFlowTheme.outline.withValues(alpha: 0.1),
            ),
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
