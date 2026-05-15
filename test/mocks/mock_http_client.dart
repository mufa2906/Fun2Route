import 'dart:convert';

import 'package:http/http.dart' as http;

/// A mock HTTP client that simulates OSRM API responses.
///
/// Use this in tests to avoid real network calls to the OSRM server.
/// The mock returns realistic GeoJSON route geometries for testing
/// route generation, scoring, and navigation logic.
class MockHttpClient extends http.BaseClient {
  final _responseQueue = <http.Response>[];
  final _requestHistory = <http.Request>[];

  /// Get the history of all requests made
  List<http.Request> get requestHistory => List.unmodifiable(_requestHistory);

  /// Queue a response to be returned on the next request (FIFO).
  void queueResponse(http.Response response) {
    _responseQueue.add(response);
  }

  /// Queue a successful OSRM route response with a simple polyline.
  /// [coordinates] are the waypoints in [lng, lat] format.
  void queueOSRMSuccess({
    required List<List<double>> coordinates,
    double distance = 5000.0,
    double duration = 600.0,
  }) {
    final body = json.encode({
      'code': 'Ok',
      'routes': [
        {
          'distance': distance,
          'duration': duration,
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
        },
      ],
      'waypoints': coordinates.map((coord) {
        return {'location': coord, 'name': ''};
      }).toList(),
    });
    queueResponse(http.Response(body, 200));
  }

  /// Queue a successful OSRM response with multiple alternative routes.
  void queueOSRMAlternatives({
    required List<List<List<double>>> alternativeCoordinates,
    List<double>? distances,
    List<double>? durations,
  }) {
    final routes = alternativeCoordinates.asMap().entries.map((entry) {
      final idx = entry.key;
      final coords = entry.value;
      return {
        'distance': distances?[idx] ?? 5000.0,
        'duration': durations?[idx] ?? 600.0,
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        },
      };
    }).toList();

    final body = json.encode({
      'code': 'Ok',
      'routes': routes,
      'waypoints': alternativeCoordinates.first.map((coord) {
        return {'location': coord, 'name': ''};
      }).toList(),
    });
    queueResponse(http.Response(body, 200));
  }

  /// Queue a successful OSRM nearest-road snap response.
  void queueOSRMSnapSuccess({
    required List<double> location, // [lng, lat]
  }) {
    final body = json.encode({
      'code': 'Ok',
      'waypoints': [
        {'location': location, 'name': ''},
      ],
    });
    queueResponse(http.Response(body, 200));
  }

  /// Queue an OSRM error response.
  void queueOSRMError(String errorCode) {
    final body = json.encode({'code': errorCode, 'message': 'Mock error'});
    queueResponse(http.Response(body, 200));
  }

  /// Queue an HTTP-level error (e.g., 500).
  void queueHttpError(int statusCode) {
    queueResponse(http.Response('Server Error', statusCode));
  }

  /// Queue a network timeout simulation (empty response that will be handled).
  void queueTimeout() {
    queueResponse(http.Response('', 200));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _requestHistory.add(request as http.Request);
    if (_responseQueue.isEmpty) {
      // Default: return a minimal valid OSRM response
      final body = json.encode({
        'code': 'Ok',
        'routes': [
          {
            'distance': 5000.0,
            'duration': 600.0,
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [106.8, -6.2],
                [106.81, -6.21],
                [106.82, -6.22],
              ],
            },
          },
        ],
        'waypoints': [
          {'location': [106.8, -6.2], 'name': ''},
          {'location': [106.82, -6.22], 'name': ''},
        ],
      });
      _responseQueue.add(http.Response(body, 200));
    }
    final response = _responseQueue.removeAt(0);
    return Future.value(
      http.StreamedResponse(
        Stream.value(utf8.encode(response.body)),
        response.statusCode,
        headers: response.headers,
      ),
    );
  }

  /// Clear all queued responses and request history.
  void reset() {
    _responseQueue.clear();
    _requestHistory.clear();
  }
}