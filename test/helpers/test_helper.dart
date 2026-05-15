import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:fun2route/providers/route_provider.dart';
import '../../test/mocks/mock_http_client.dart';

// ---------------------------------------------------------------------------
// Test fixture helpers
// ---------------------------------------------------------------------------

/// Default test location (Jakarta area).
const testLatitude = -6.2;
const testLongitude = 106.8;

/// Create a [LatLng] with test coordinates.
LatLng testLatLng({double lat = testLatitude, double lng = testLongitude}) =>
    LatLng(lat, lng);

/// Create a simple test polyline (3 points).
List<LatLng> createTestPolyline({
  double startLat = testLatitude,
  double startLng = testLongitude,
  int count = 3,
  double stepLat = 0.001,
  double stepLng = 0.001,
}) {
  return List.generate(count, (i) {
    return LatLng(startLat + i * stepLat, startLng + i * stepLng);
  });
}

/// Build a [RouteCandidate] with sensible defaults for testing.
RouteCandidate createTestRouteCandidate({
  String? id,
  double distanceM = 5000.0,
  double durationSec = 600.0,
  List<LatLng>? polyline,
  double score = 100.0,
  RoutePersonality personality = RoutePersonality.smoothJog,
}) {
  return RouteCandidate(
    id: id ?? 'test_route_${DateTime.now().millisecondsSinceEpoch}',
    distanceM: distanceM,
    durationSec: durationSec,
    polyline: polyline ?? createTestPolyline(),
    requestedWaypoints: polyline ?? createTestPolyline(),
    score: score,
    personality: personality,
  );
}

/// OSRM coordinate in [lng, lat] format (as returned by OSRM API).
List<List<double>> makeOSRMCoords({
  double startLat = testLatitude,
  double startLng = testLongitude,
  int count = 5,
}) {
  return List.generate(count, (i) {
    return [startLng + i * 0.001, startLat + i * 0.001];
  });
}

// ---------------------------------------------------------------------------
// Provider test harness
// ---------------------------------------------------------------------------

/// Sets up a [RouteProvider] with a [MockHttpClient] injected via
/// [http.Client] sharing (the provider uses its own http.get calls).
///
/// Returns the provider so you can make assertions and trigger methods.
class ProviderTestHarness {
  late final RouteProvider provider;
  late final MockHttpClient mockHttp;

  ProviderTestHarness() {
    provider = RouteProvider();
    mockHttp = MockHttpClient();
  }

  /// Queue default OSRM responses needed for route generation.
  /// Call this before calling [provider.generateRoutes].
  void queueDefaultRouteResponses() {
    // Waypoint snapping responses (one per waypoint, usually 3-5)
    mockHttp.queueOSRMSnapSuccess(location: [testLongitude, testLatitude]);
    mockHttp.queueOSRMSnapSuccess(
      location: [testLongitude + 0.005, testLatitude + 0.003],
    );
    mockHttp.queueOSRMSnapSuccess(
      location: [testLongitude + 0.01, testLatitude + 0.005],
    );

    // Main OSRM route response
    mockHttp.queueOSRMSuccess(
      coordinates: makeOSRMCoords(count: 5),
      distance: 5000.0,
      duration: 600.0,
    );
  }

  /// Dispose resources
  void dispose() {
    provider.dispose();
    mockHttp.reset();
  }
}

// ---------------------------------------------------------------------------
// Widget test helpers
// ---------------------------------------------------------------------------

/// Wrap a widget with the providers needed by the app.
MaterialApp wrapWithProviders(
  Widget child, {
  RouteProvider? routeProvider,
}) {
  return MaterialApp(
    home: ChangeNotifierProvider<RouteProvider>.value(
      value: routeProvider ?? RouteProvider(),
      child: child,
    ),
  );
}

/// Convenience extension for finding widgets in test.
extension PumpExtensions on WidgetTester {
  /// Pump the given widget wrapped in the app's providers.
  Future<void> pumpApp(
    Widget widget, {
    RouteProvider? routeProvider,
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await pumpWidget(wrapWithProviders(widget, routeProvider: routeProvider));
    await pump(duration);
  }
}

// ---------------------------------------------------------------------------
// Assertion helpers
// ---------------------------------------------------------------------------

/// Asserts that two [LatLng] values are within [tolerance] degrees.
void expectLatLngClose(LatLng actual, LatLng expected,
    {double tolerance = 0.0001, String? reason}) {
  expect(
    (actual.latitude - expected.latitude).abs(),
    lessThan(tolerance),
    reason: reason ?? 'Latitude mismatch',
  );
  expect(
    (actual.longitude - expected.longitude).abs(),
    lessThan(tolerance),
    reason: reason ?? 'Longitude mismatch',
  );
}