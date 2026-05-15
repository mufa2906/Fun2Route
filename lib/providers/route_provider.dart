import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

enum RoutePersonality { smoothJog, stroll, explorer }

enum NavigationState {
  idle,
  starting,
  active,
  autoPaused,
  paused,
  resumed,
  finished,
}

class RouteProvider extends ChangeNotifier {
  static const double gpsAccuracyThresholdM = 25.0;
  static const double minMovementSpeedMs = 0.5;
  static const int autoPauseThresholdMs = 60000;

  static const double offRouteThresholdWalkM = 40.0;
  static const double offRouteThresholdJogM = 65.0;

  static const double defaultWeightKg = 70.0;
  static const double calorieFactorWalk = 0.9;
  static const double calorieFactorJog = 1.1;

  static const double arrivalDistanceThresholdM = 45.0;
  static const double arrivalProgressThreshold = 0.55;

  static const Map<String, double> defaultSpeedsKmh = {
    'walk_easy': 4.0,
    'walk_fast': 5.5,
    'jog': 8.0,
  };

  // --- State ---
  Position? _currentPosition;
  bool _isLoading = false;
  List<LatLng> _currentRoute = [];
  List<LatLng> _traveledRoute = [];
  List<RouteCandidate> _generatedRoutes = [];
  RouteCandidate? _activeRoute;
  String _lastOSRMError = '';

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  List<LatLng> get currentRoute => _currentRoute;
  List<LatLng> get traveledRoute => _traveledRoute;
  List<RouteCandidate> get generatedRoutes => _generatedRoutes;
  RouteCandidate? get activeRoute => _activeRoute;
  String get lastOSRMError => _lastOSRMError;

  // --- Running Session State ---
  bool _isRunning = false;
  int _secondsElapsed = 0;
  double _distanceTraveled = 0.0;
  Timer? _timer;
  final List<Map<String, dynamic>> _history = [];
  NavigationState _navigationState = NavigationState.idle;
  int _offRouteCount = 0;
  bool _arrivalAlerted = false;
  String _currentActivityType = 'walk_easy';
  double _calories = 0.0;
  int _pausedMs = 0;
  int? _pauseStartMs;

  // --- POI & Avoidance Zones ---
  final List<Map<String, dynamic>> _pois = [];
  final List<Map<String, dynamic>> _avoidanceZones = [];
  List<Map<String, dynamic>> get pois => _pois;
  List<Map<String, dynamic>> get avoidanceZones => _avoidanceZones;

  // --- Route Memory ---
  final List<RouteCandidate> _favoriteRoutes = [];
  List<RouteCandidate> get favoriteRoutes => _favoriteRoutes;

  bool get isRunning => _isRunning;
  int get secondsElapsed => _secondsElapsed;
  double get distanceTraveled => _distanceTraveled;
  List<Map<String, dynamic>> get history => _history;
  NavigationState get navigationState => _navigationState;
  int get offRouteCount => _offRouteCount;
  bool get arrivalAlerted => _arrivalAlerted;
  double get calories => _calories;
  int get pausedMs => _pausedMs;
  String get currentActivityType => _currentActivityType;

  String get formattedTime {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void toggleFavoriteRoute(RouteCandidate route) {
    final exists = _favoriteRoutes.any((r) => r.id == route.id);
    if (exists) {
      _favoriteRoutes.removeWhere((r) => r.id == route.id);
      route.isFavorite = false;
    } else {
      route.isFavorite = true;
      _favoriteRoutes.add(route);
    }
    notifyListeners();
  }

  void setActiveRoute(RouteCandidate route) {
    _activeRoute = route;
    _currentRoute = route.polyline;
    notifyListeners();
  }

  // --- Location ---

  Future<void> updateCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Route Generation ---

  Future<void> generateRoutes({
    required double targetDistanceM,
    required String activityType,
    required bool isLoop,
    RoutePersonality personality = RoutePersonality.smoothJog,
    List<LatLng>? drawnWaypoints,
  }) async {
    _isLoading = true;
    _generatedRoutes = [];
    notifyListeners();

    if (_currentPosition == null) await updateCurrentLocation();
    if (_currentPosition == null) {
      debugPrint('Error: Could not obtain current location.');
      _isLoading = false;
      notifyListeners();
      return;
    }

    final start = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    try {
      if (drawnWaypoints != null && drawnWaypoints.isNotEmpty) {
        final candidate = await generateRouteThroughPoint(
          start: start,
          waypoints: drawnWaypoints,
          isLoop: isLoop,
        );
        if (candidate != null) _generatedRoutes.add(candidate);
      } else {
        final candidates = <RouteCandidate>[];
        for (final bearing in [0.0, 120.0, 240.0]) {
          final results = await _generateMultipleCandidates(
            start: start,
            targetDistanceM: targetDistanceM,
            bearing: bearing,
            isLoop: isLoop,
            personality: personality,
          );
          candidates.addAll(results);
        }
        candidates.sort((a, b) => b.score.compareTo(a.score));
        _generatedRoutes = candidates;
      }

      if (_generatedRoutes.isNotEmpty) {
        _activeRoute = _generatedRoutes.first;
        if (isLoop &&
            _activeRoute!.polyline.isNotEmpty &&
            _activeRoute!.polyline.last != start) {
          _activeRoute!.polyline.add(start);
        }
        _currentRoute = _activeRoute!.polyline;
      }
    } catch (e) {
      debugPrint('Error generating routes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RouteCandidate?> generateRouteThroughPoint({
    required LatLng start,
    required List<LatLng> waypoints,
    required bool isLoop,
  }) async {
    // Filter waypoints within 25 m of their predecessor to prevent OSRM
    // generating a tiny self-loop near the origin.
    final filtered = <LatLng>[];
    var prev = start;
    for (final wp in waypoints) {
      final d = Geolocator.distanceBetween(
        prev.latitude, prev.longitude, wp.latitude, wp.longitude,
      );
      if (d > 25) {
        filtered.add(wp);
        prev = wp;
      }
    }
    if (filtered.isEmpty) return null;

    final fullWaypoints = [start, ...filtered];
    if (isLoop && fullWaypoints.last != start) fullWaypoints.add(start);

    final data = await _fetchOSRMData(fullWaypoints);
    if (data == null || (data['routes'] as List).isEmpty) return null;

    final route = data['routes'][0];
    final polyline = _decodePolyline(route['geometry'] as Map<String, dynamic>);
    if (isLoop && polyline.isNotEmpty && polyline.last != start) {
      polyline.add(start);
    }

    return RouteCandidate(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      distanceM: (route['distance'] as num).toDouble(),
      durationSec: (route['duration'] as num).toDouble(),
      polyline: polyline,
      requestedWaypoints: fullWaypoints,
    );
  }

  Future<List<RouteCandidate>> _generateMultipleCandidates({
    required LatLng start,
    required double targetDistanceM,
    required double bearing,
    required bool isLoop,
    required RoutePersonality personality,
  }) async {
    final waypoints = await _buildWaypoints(
      start, targetDistanceM, bearing, isLoop, personality,
    );
    final data = await _fetchOSRMData(waypoints, alternatives: true);
    if (data == null) return [];

    final candidates = <RouteCandidate>[];
    for (final routeData in data['routes'] as List) {
      final polyline = _decodePolyline(routeData['geometry'] as Map<String, dynamic>);
      if (isLoop && polyline.isNotEmpty && polyline.last != start) {
        polyline.add(start);
      }

      final actualDist = (routeData['distance'] as num).toDouble();
      final score = _calculatePleasantnessScore(
        polyline, targetDistanceM, actualDist, personality,
      );

      candidates.add(RouteCandidate(
        id: '${DateTime.now().millisecondsSinceEpoch}_${bearing}_${candidates.length}',
        distanceM: actualDist,
        durationSec: (routeData['duration'] as num).toDouble(),
        polyline: polyline,
        requestedWaypoints: waypoints,
        score: score,
        personality: personality,
      ));
    }
    return candidates;
  }

  double _calculatePleasantnessScore(
    List<LatLng> polyline,
    double targetDist,
    double actualDist,
    RoutePersonality personality,
  ) {
    double score = 100.0;

    // 1. Distance penalty (max -30)
    final distError = (actualDist - targetDist).abs() / targetDist;
    score -= (distError * 150).clamp(0, 30);

    // 2. Sharp turn & complexity counts
    int sharpTurns = 0;
    for (int i = 1; i < polyline.length - 1; i++) {
      if (_calculateAngle(polyline[i - 1], polyline[i], polyline[i + 1]) > 80) {
        sharpTurns++;
      }
    }
    final turnsPerKm = sharpTurns / (actualDist / 1000);
    final pointsPerKm = polyline.length / (actualDist / 1000);

    // 3. Personality-weighted penalties
    switch (personality) {
      case RoutePersonality.smoothJog:
        score -= (turnsPerKm * 15).clamp(0, 50);
        if (pointsPerKm > 100) score -= 25;
        break;
      case RoutePersonality.stroll:
        score -= (turnsPerKm * 10).clamp(0, 40);
        if (pointsPerKm > 120) score -= 20;
        break;
      case RoutePersonality.explorer:
        score -= (turnsPerKm * 5).clamp(0, 20);
        if (pointsPerKm > 150) score -= 10;
        break;
    }

    // 4. Overlap penalty (max -60)
    score -= _calculateOverlapPenalty(polyline);

    return score;
  }

  double _calculateOverlapPenalty(List<LatLng> polyline) {
    if (polyline.length < 20) return 0;
    int overlapCount = 0;
    final len = polyline.length;

    for (int i = 0; i < len; i++) {
      for (int j = i + 20; j < len; j++) {
        final iNearEnds = i < 15 || i > len - 15;
        final jNearEnds = j < 15 || j > len - 15;
        if (iNearEnds && jNearEnds) continue;

        final dist = Geolocator.distanceBetween(
          polyline[i].latitude, polyline[i].longitude,
          polyline[j].latitude, polyline[j].longitude,
        );
        if (dist < 20.0) {
          overlapCount++;
          j += 10;
        }
      }
    }
    return (overlapCount * 3.0).clamp(0, 60.0);
  }

  double _calculateAngle(LatLng a, LatLng b, LatLng c) {
    double diff = (_bearingBetween(b, a) - _bearingBetween(b, c)).abs();
    if (diff > 180) diff = 360 - diff;
    return (180 - diff).abs();
  }

  double _bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lon2 = end.longitude * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x) * 180 / math.pi;
  }

  Future<List<LatLng>> _buildWaypoints(
    LatLng start,
    double targetDistanceM,
    double bearing,
    bool isLoop,
    RoutePersonality personality,
  ) async {
    if (!isLoop) {
      final endDist = targetDistanceM * 0.72;
      final midRaw = _offsetPoint(start, endDist * 0.42, bearing + 15);
      final endRaw = _offsetPoint(start, endDist, bearing);
      final midSnapped = await _snapToNearestRoad(midRaw);
      final endSnapped = await _snapToNearestRoad(endRaw);
      return [start, midSnapped ?? midRaw, endSnapped ?? endRaw];
    }

    // Loop mode: progressive relative-turn anchors so each OSRM leg uses
    // distinct street sets.
    late List<double> legFracs;
    late List<double> relativeTurns;

    switch (personality) {
      case RoutePersonality.smoothJog:
        legFracs = [0.38, 0.28];
        relativeTurns = [0.0, 115.0];
        break;
      case RoutePersonality.stroll:
        legFracs = [0.26, 0.24, 0.22];
        relativeTurns = [0.0, 90.0, 85.0];
        break;
      case RoutePersonality.explorer:
        legFracs = [0.22, 0.18, 0.17, 0.15];
        relativeTurns = [0.0, 65.0, 70.0, 75.0];
        break;
    }

    final anchors = <LatLng>[start];
    var currentAnchor = start;
    var currentBearing = bearing;
    final rng = math.Random();

    for (int i = 0; i < legFracs.length; i++) {
      currentBearing += relativeTurns[i];
      double legDist = targetDistanceM * legFracs[i];

      if (personality == RoutePersonality.explorer) {
        currentBearing += rng.nextDouble() * 30 - 15;
        legDist *= 0.8 + rng.nextDouble() * 0.4;
      } else if (personality == RoutePersonality.smoothJog) {
        currentBearing += rng.nextDouble() * 10 - 5;
      }

      final nextRaw = _offsetPoint(currentAnchor, legDist, currentBearing);
      final nextSnapped = await _snapToNearestRoad(nextRaw);
      currentAnchor = nextSnapped ?? nextRaw;
      anchors.add(currentAnchor);
    }

    anchors.add(start);
    return anchors;
  }

  Future<LatLng?> _snapToNearestRoad(LatLng point) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/nearest/v1/bike/${point.longitude},${point.latitude}?number=1',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && (data['waypoints'] as List).isNotEmpty) {
          final location = data['waypoints'][0]['location'] as List;
          return LatLng(location[1] as double, location[0] as double);
        }
      }
    } catch (e) {
      debugPrint('Snap error: $e');
    }
    return null;
  }

  LatLng _offsetPoint(LatLng from, double distanceM, double bearingDegree) {
    const earthRadius = 6371000.0;
    final lat1 = from.latitude * math.pi / 180;
    final lng1 = from.longitude * math.pi / 180;
    final brng = bearingDegree * math.pi / 180;
    final dR = distanceM / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(dR) +
          math.cos(lat1) * math.sin(dR) * math.cos(brng),
    );
    final lng2 = lng1 +
        math.atan2(
          math.sin(brng) * math.sin(dR) * math.cos(lat1),
          math.cos(dR) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  Future<Map<String, dynamic>?> _fetchOSRMData(
    List<LatLng> waypoints, {
    bool alternatives = false,
  }) async {
    final coords = waypoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');
    var urlStr =
        'https://router.project-osrm.org/route/v1/bike/$coords?overview=full&geometries=geojson';
    if (alternatives) urlStr += '&alternatives=true';

    debugPrint('OSRM Request: $urlStr');

    try {
      final response = await http
          .get(Uri.parse(urlStr))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok') return data;
        _lastOSRMError = 'OSRM Error: ${data['code']}';
      } else {
        _lastOSRMError = 'HTTP Error: ${response.statusCode}';
      }
      debugPrint(_lastOSRMError);
    } catch (e) {
      _lastOSRMError = 'Exception: $e';
      debugPrint(_lastOSRMError);
    }
    return null;
  }

  List<LatLng> _decodePolyline(Map<String, dynamic> geometry) {
    return (geometry['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  // --- Calorie Calculation ---

  double calculateCalories(double distanceM, String activityType) {
    final factor =
        activityType == 'jog' ? calorieFactorJog : calorieFactorWalk;
    return factor * defaultWeightKg * (distanceM / 1000);
  }

  // --- Off-Route Detection ---

  double getOffRouteThreshold() =>
      _currentActivityType == 'jog'
          ? offRouteThresholdJogM
          : offRouteThresholdWalkM;

  bool checkOffRoute(LatLng currentPos) {
    if (_activeRoute == null || _activeRoute!.polyline.isEmpty) return false;
    var minDist = double.infinity;
    for (final point in _activeRoute!.polyline) {
      final dist = Geolocator.distanceBetween(
        currentPos.latitude, currentPos.longitude,
        point.latitude, point.longitude,
      );
      if (dist < minDist) minDist = dist;
    }
    return minDist > getOffRouteThreshold();
  }

  void incrementOffRoute() {
    _offRouteCount++;
    notifyListeners();
  }

  // --- Loop Arrival Detection ---

  double distanceToStart() {
    if (_currentPosition == null ||
        _activeRoute == null ||
        _activeRoute!.polyline.isEmpty) {
      return double.infinity;
    }
    final start = _activeRoute!.polyline.first;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude,
      start.latitude, start.longitude,
    );
  }

  double get _progressRatio {
    if (_activeRoute == null || _activeRoute!.distanceM <= 0) return 0;
    return (_distanceTraveled * 1000) / _activeRoute!.distanceM;
  }

  bool get shouldShowArrivalBanner =>
      _activeRoute != null && _progressRatio > 0.50;

  bool checkLoopArrival() {
    if (_activeRoute == null || _arrivalAlerted) return false;
    if (_progressRatio >= arrivalProgressThreshold &&
        distanceToStart() < arrivalDistanceThresholdM) {
      _arrivalAlerted = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- POI & Avoidance ---

  void addPoi(double lat, double lng, String note) {
    _pois.add({
      'latitude': lat,
      'longitude': lng,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  void addAvoidanceZone(double lat, double lng, String note) {
    _avoidanceZones.add({
      'latitude': lat,
      'longitude': lng,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  // --- Distance Mismatch ---

  double getDistanceMismatchPercent(double targetDistanceM) {
    if (_activeRoute == null || targetDistanceM <= 0) return 0;
    return ((_activeRoute!.distanceM - targetDistanceM).abs() /
            targetDistanceM) *
        100;
  }

  // --- Session Control ---

  void startRun({String activityType = 'walk_easy'}) {
    _resetSessionFields(activityType: activityType);
    _navigationState = NavigationState.active;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_navigationState == NavigationState.active ||
          _navigationState == NavigationState.resumed) {
        _secondsElapsed++;
        final speedMs = _currentActivityType == 'jog' ? 2.2 : 1.3;
        _distanceTraveled += speedMs / 1000;
        _calories = calculateCalories(
          _distanceTraveled * 1000,
          _currentActivityType,
        );
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void stopRun() {
    _timer?.cancel();
    _isRunning = false;
    _navigationState = NavigationState.finished;
    _calories = calculateCalories(_distanceTraveled * 1000, _currentActivityType);

    _history.insert(0, {
      'title': _activityLabel(_currentActivityType),
      'date': _formatDate(DateTime.now()),
      'timestamp': DateTime.now().toIso8601String(),
      'distance': '${_distanceTraveled.toStringAsFixed(2)} km',
      'time': formattedTime,
      'calories': '${_calories.toStringAsFixed(0)} kcal',
      'polyline': List<LatLng>.from(_activeRoute?.polyline ?? []),
      'activityType': _currentActivityType,
    });
    notifyListeners();
  }

  void togglePauseRun() {
    if (_navigationState == NavigationState.active ||
        _navigationState == NavigationState.resumed) {
      _enterPause(NavigationState.paused);
    } else if (_navigationState == NavigationState.paused ||
        _navigationState == NavigationState.autoPaused) {
      _exitPause();
    }
    notifyListeners();
  }

  void autoPause() {
    if (_navigationState == NavigationState.active ||
        _navigationState == NavigationState.resumed) {
      _enterPause(NavigationState.autoPaused);
      notifyListeners();
    }
  }

  void resetSession() {
    _timer?.cancel();
    _resetSessionFields(running: false);
    _navigationState = NavigationState.idle;
    _activeRoute = null;
    _generatedRoutes = [];
    _currentRoute = [];
    notifyListeners();
  }

  // --- Private helpers ---

  void _resetSessionFields({String activityType = 'walk_easy', bool running = true}) {
    _isRunning = running;
    _secondsElapsed = 0;
    _distanceTraveled = 0.0;
    _traveledRoute = [];
    _offRouteCount = 0;
    _arrivalAlerted = false;
    _currentActivityType = activityType;
    _calories = 0.0;
    _pausedMs = 0;
    _pauseStartMs = null;
  }

  void _enterPause(NavigationState state) {
    _navigationState = state;
    _isRunning = false;
    _pauseStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _exitPause() {
    if (_pauseStartMs != null) {
      _pausedMs += DateTime.now().millisecondsSinceEpoch - _pauseStartMs!;
      _pauseStartMs = null;
    }
    _navigationState = NavigationState.resumed;
    _isRunning = true;
  }

  static String _activityLabel(String type) {
    switch (type) {
      case 'walk_fast':
        return 'Fast Walk';
      case 'jog':
        return 'Jog';
      default:
        return 'Walk';
    }
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class RouteCandidate {
  final String id;
  final double distanceM;
  final double durationSec;
  final List<LatLng> polyline;
  final List<LatLng> requestedWaypoints;
  final double score;
  final RoutePersonality personality;
  bool isFavorite;

  RouteCandidate({
    required this.id,
    required this.distanceM,
    required this.durationSec,
    required this.polyline,
    required this.requestedWaypoints,
    this.score = 0.0,
    this.personality = RoutePersonality.smoothJog,
    this.isFavorite = false,
  });
}
