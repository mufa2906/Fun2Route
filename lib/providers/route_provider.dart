import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

enum RoutePersonality {
  smoothJog,
  stroll,
  explorer,
}

class RouteProvider extends ChangeNotifier {
  // --- Constants (from docs/technical.md) ---
  static const double GPS_ACCURACY_THRESHOLD_M = 25.0;
  static const double MIN_MOVEMENT_SPEED_MS = 0.5;
  static const int AUTO_PAUSE_THRESHOLD_MS = 60000;
  
  static const double OFF_ROUTE_THRESHOLD_WALK_M = 40.0;
  static const double OFF_ROUTE_THRESHOLD_JOG_M = 65.0;

  static const Map<String, double> DEFAULT_SPEEDS_KMH = {
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
  List<Map<String, dynamic>> _history = [];
  
  // --- Phase 4: Route Memory ---
  List<RouteCandidate> _favoriteRoutes = [];
  List<RouteCandidate> get favoriteRoutes => _favoriteRoutes;

  void toggleFavoriteRoute(RouteCandidate route) {
    if (_favoriteRoutes.any((r) => r.id == route.id)) {
      _favoriteRoutes.removeWhere((r) => r.id == route.id);
      route.isFavorite = false;
    } else {
      route.isFavorite = true;
      _favoriteRoutes.add(route);
    }
    notifyListeners();
  }

  bool get isRunning => _isRunning;
  int get secondsElapsed => _secondsElapsed;
  double get distanceTraveled => _distanceTraveled;
  List<Map<String, dynamic>> get history => _history;

  String get formattedTime {
    int minutes = _secondsElapsed ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void setActiveRoute(RouteCandidate route) {
    _activeRoute = route;
    _currentRoute = route.polyline;
    notifyListeners();
  }

  // --- Location Methods ---

  Future<void> updateCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permissions are denied';
      }
      
      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Route Engine (OSRM Logic from docs) ---

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
    final start = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    try {
      if (drawnWaypoints != null && drawnWaypoints.isNotEmpty) {
        // Generate Route Through Points
        final candidate = await _generateRouteThroughPoint(
          start: start,
          waypoints: drawnWaypoints,
          isLoop: isLoop,
        );
        if (candidate != null) _generatedRoutes.add(candidate);
      } else {
        // Regular generation
        List<double> bearings = [0.0, 120.0, 240.0];
        List<RouteCandidate> candidates = [];

        for (double bearing in bearings) {
          final results = await _generateMultipleCandidates(
            start: start,
            targetDistanceM: targetDistanceM,
            bearing: bearing,
            isLoop: isLoop,
            personality: personality,
          );
          candidates.addAll(results);
        }

        // Environment-First Scoring: Sort by Score (Pleasantness), not just distance
        candidates.sort((a, b) => b.score.compareTo(a.score));

        _generatedRoutes = candidates;
      }

      if (_generatedRoutes.isNotEmpty) {
        _activeRoute = _generatedRoutes.first;
        
        // Force loop closure if requested
        if (isLoop && _activeRoute!.polyline.isNotEmpty) {
           if (_activeRoute!.polyline.last != start) {
             _activeRoute!.polyline.add(start);
           }
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

  Future<RouteCandidate?> _generateRouteThroughPoint({
    required LatLng start,
    required List<LatLng> waypoints,
    required bool isLoop,
  }) async {
    List<LatLng> fullWaypoints = [start, ...waypoints];
    if (isLoop && fullWaypoints.last != start) {
      fullWaypoints.add(start);
    }
    
    var data = await _fetchOSRMData(fullWaypoints);
    if (data == null || data['routes'].isEmpty) return null;
    var route = data['routes'][0];

    final List<LatLng> polyline = _decodePolyline(route['geometry']);
    
    // Force loop closure
    if (isLoop && polyline.isNotEmpty && polyline.last != start) {
      polyline.add(start);
    }

    return RouteCandidate(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      distanceM: route['distance'],
      durationSec: route['duration'],
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
    List<LatLng> waypoints = await _buildWaypoints(start, targetDistanceM, bearing, isLoop, personality);
    var data = await _fetchOSRMData(waypoints, alternatives: true);
    if (data == null) return [];

    List<RouteCandidate> candidates = [];
    final List<dynamic> routes = data['routes'];

    for (var routeData in routes) {
      final List<LatLng> polyline = _decodePolyline(routeData['geometry']);
      
      // Force loop closure
      if (isLoop && polyline.isNotEmpty && polyline.last != start) {
        polyline.add(start);
      }

      double score = _calculatePleasantnessScore(polyline, targetDistanceM, routeData['distance'].toDouble(), personality);
      
      candidates.add(RouteCandidate(
        id: '${DateTime.now().millisecondsSinceEpoch}_${bearing}_${candidates.length}',
        distanceM: routeData['distance'].toDouble(),
        durationSec: routeData['duration'].toDouble(),
        polyline: polyline,
        requestedWaypoints: waypoints,
        score: score,
        personality: personality,
      ));
    }
    return candidates;
  }

  double _calculatePleasantnessScore(List<LatLng> polyline, double targetDist, double actualDist, RoutePersonality personality) {
    double score = 100.0;
    
    // 1. Distance Penalty (Max -30)
    double distError = (actualDist - targetDist).abs() / targetDist;
    score -= (distError * 150).clamp(0, 30);

    // 2. Sharp Turn Penalty
    int sharpTurns = 0;
    for (int i = 1; i < polyline.length - 1; i++) {
      double angle = _calculateAngle(polyline[i - 1], polyline[i], polyline[i + 1]);
      if (angle > 80) sharpTurns++; // Sharp turn (>80 degrees)
    }
    double turnsPerKm = sharpTurns / (actualDist / 1000);

    // 3. Complexity Penalty
    double pointsPerKm = polyline.length / (actualDist / 1000);

    // --- Phase 3: Route Personality System ---
    switch (personality) {
      case RoutePersonality.smoothJog:
        score -= (turnsPerKm * 15).clamp(0, 50); // Heavy penalty for stops/turns
        if (pointsPerKm > 100) score -= 25; // Needs straight, continuous roads
        break;
      case RoutePersonality.stroll:
        score -= (turnsPerKm * 10).clamp(0, 40); // Moderate penalty
        if (pointsPerKm > 120) score -= 20;
        break;
      case RoutePersonality.explorer:
        score -= (turnsPerKm * 5).clamp(0, 20); // Low penalty, expects turns
        if (pointsPerKm > 150) score -= 10; // Fine with dense urban layouts
        break;
    }

    // 4. Overlap Penalty (Max -40)
    // Penalize psychologically frustrating self-intersections
    double overlapPenalty = _calculateOverlapPenalty(polyline);
    score -= overlapPenalty;

    return score;
  }

  double _calculateOverlapPenalty(List<LatLng> polyline) {
    if (polyline.length < 20) return 0;
    int overlapCount = 0;
    
    for (int i = 0; i < polyline.length; i++) {
      for (int j = i + 20; j < polyline.length; j++) {
        // Skip comparing if both are near start or end (to allow loop closure)
        bool iNearEnds = i < 15 || i > polyline.length - 15;
        bool jNearEnds = j < 15 || j > polyline.length - 15;
        if (iNearEnds && jNearEnds) continue;

        double dist = Geolocator.distanceBetween(
            polyline[i].latitude, polyline[i].longitude, 
            polyline[j].latitude, polyline[j].longitude);
            
        if (dist < 20.0) {
          overlapCount++;
          // Skip ahead to avoid counting the same overlapping segment repeatedly
          j += 10; 
        }
      }
    }
    return (overlapCount * 2.0).clamp(0, 40.0);
  }

  double _calculateAngle(LatLng a, LatLng b, LatLng c) {
    // Basic angle calculation between three points
    double b1 = _bearingBetween(b, a);
    double b2 = _bearingBetween(b, c);
    double diff = (b1 - b2).abs();
    if (diff > 180) diff = 360 - diff;
    // We want the deviation from straight (0 deg = straight, 180 deg = U-turn)
    return (180 - diff).abs(); 
  }

  double _bearingBetween(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lon1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lon2 = end.longitude * math.pi / 180;
    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x) * 180 / math.pi;
  }

  Future<List<LatLng>> _buildWaypoints(LatLng start, double targetDistanceM, double bearing, bool isLoop, RoutePersonality personality) async {
    if (!isLoop) {
      LatLng endRaw = _offsetPoint(start, targetDistanceM, bearing);
      LatLng? endSnapped = await _snapToNearestRoad(endRaw);
      return [start, endSnapped ?? endRaw];
    } else {
      // --- Phase 2: Anchor-Based Flow Generation ---
      // Replacing pure triangle logic with personality-based anchors
      List<LatLng> anchors = [start];
      int anchorCount = 3; 
      
      if (personality == RoutePersonality.smoothJog) {
        anchorCount = 3; // Simpler shapes, longer straights
      } else if (personality == RoutePersonality.stroll) {
        anchorCount = 4; // Blocky, shorter segments
      } else if (personality == RoutePersonality.explorer) {
        anchorCount = 5; // Irregular, more novelty
      }
      
      double currentBearing = bearing;
      LatLng currentAnchor = start;
      
      for (int i = 0; i < anchorCount - 1; i++) {
         double turnAngle = 360.0 / anchorCount;
         double segmentDist = targetDistanceM / anchorCount;
         
         if (personality == RoutePersonality.explorer) {
           // Organic variance for explorer (jitter angle and distance)
           turnAngle += (math.Random().nextDouble() * 40 - 20);
           segmentDist *= (0.8 + math.Random().nextDouble() * 0.4);
         } else if (personality == RoutePersonality.smoothJog) {
           // Smoother curves
           turnAngle += (math.Random().nextDouble() * 10 - 5);
         }
         
         LatLng nextRaw = _offsetPoint(currentAnchor, segmentDist, currentBearing);
         LatLng? nextSnapped = await _snapToNearestRoad(nextRaw);
         
         currentAnchor = nextSnapped ?? nextRaw;
         anchors.add(currentAnchor);
         
         currentBearing += turnAngle;
      }
      
      anchors.add(start);
      return anchors;
    }
  }

  Future<LatLng?> _snapToNearestRoad(LatLng point) async {
    final url = Uri.parse('https://router.project-osrm.org/nearest/v1/bike/${point.longitude},${point.latitude}?number=1');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['waypoints'].isNotEmpty) {
          final location = data['waypoints'][0]['location'];
          return LatLng(location[1], location[0]);
        }
      }
    } catch (e) {
      debugPrint('Snap error: $e');
    }
    return null;
  }

  LatLng _offsetPoint(LatLng from, double distanceM, double bearingDegree) {
    const double earthRadius = 6371000;
    double lat1 = from.latitude * math.pi / 180;
    double lng1 = from.longitude * math.pi / 180;
    double brng = bearingDegree * math.pi / 180;
    double dR = distanceM / earthRadius;

    double lat2 = math.asin(math.sin(lat1) * math.cos(dR) +
        math.cos(lat1) * math.sin(dR) * math.cos(brng));
    double lng2 = lng1 +
        math.atan2(math.sin(brng) * math.sin(dR) * math.cos(lat1),
            math.cos(dR) - math.sin(lat1) * math.sin(lat2));

    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  Future<Map<String, dynamic>?> _fetchOSRMData(List<LatLng> waypoints, {bool alternatives = false}) async {
    final coords = waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    String urlStr = 'https://router.project-osrm.org/route/v1/bike/$coords?overview=full&geometries=geojson';
    if (alternatives) urlStr += '&alternatives=true';
    
    final url = Uri.parse(urlStr);
    debugPrint('OSRM Request: $url');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          return data;
        } else {
          _lastOSRMError = 'OSRM Error: ${data['code']}';
          debugPrint(_lastOSRMError);
        }
      } else {
        _lastOSRMError = 'HTTP Error: ${response.statusCode}';
        debugPrint(_lastOSRMError);
      }
    } catch (e) {
      _lastOSRMError = 'Exception: $e';
      debugPrint(_lastOSRMError);
    }
    return null;
  }

  List<LatLng> _decodePolyline(Map<String, dynamic> geometry) {
    List<dynamic> coords = geometry['coordinates'];
    return coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
  }

  // --- Session Control ---

  void startRun() {
    _isRunning = true;
    _secondsElapsed = 0;
    _distanceTraveled = 0.0;
    _traveledRoute = [];
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsElapsed++;
      // Simplified distance tracking (should be GPS based ideally)
      _distanceTraveled += 0.002;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopRun() {
    _timer?.cancel();
    _isRunning = false;
    _history.insert(0, {
      'title': 'Activity',
      'date': 'Today',
      'distance': '${_distanceTraveled.toStringAsFixed(2)} km',
      'time': formattedTime,
      'polyline': List<LatLng>.from(_activeRoute?.polyline ?? []),
    });
    notifyListeners();
  }

  void togglePauseRun() {
    _isRunning = !_isRunning;
    if (_isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _secondsElapsed++;
        _distanceTraveled += 0.002;
        notifyListeners();
      });
    } else {
      _timer?.cancel();
    }
    notifyListeners();
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
