# Fun2Route AI Agent Testing Guide

This guide enables AI agents (Cline, Copilot, etc.) to autonomously test the Fun2Route Flutter application. It covers the test architecture, how to run tests, and how to extend test coverage.

## Table of Contents

1. [Test Architecture](#test-architecture)
2. [Running Tests](#running-tests)
3. [Test Structure](#test-structure)
4. [Mock System](#mock-system)
5. [Writing Tests as an AI Agent](#writing-tests-as-an-ai-agent)
6. [Test Coverage Areas](#test-coverage-areas)
7. [Common Testing Patterns](#common-testing-patterns)
8. [Debugging Failed Tests](#debugging-failed-tests)

---

## Test Architecture

```
test/
├── README.md                          # This file
├── mocks/
│   └── mock_http_client.dart           # Mock HTTP client for OSRM API
├── helpers/
│   └── test_helper.dart                # Shared fixtures, harnesses, assertions
├── unit/
│   └── route_provider_test.dart        # Unit tests for RouteProvider logic
├── widget/
│   ├── onboarding_screen_test.dart     # Widget tests for screens
│   ├── home_screen_test.dart
│   ├── navigation_screen_test.dart
│   └── route_selection_screen_test.dart
└── integration/
    └── navigation_flow_test.dart       # Full app flow tests
```

### Principles

- **Unit tests** test pure business logic in `RouteProvider` without platform APIs.
- **Widget tests** verify screen rendering and user interactions using mock data.
- **Integration tests** test complete navigation flows across multiple screens.
- **Mock HTTP client** replaces real OSRM API calls with controllable responses.
- **Test helpers** provide reusable fixtures, harnesses, and assertion utilities.

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/unit/route_provider_test.dart
flutter test test/widget/onboarding_screen_test.dart
```

### Run Tests by Name Pattern

```bash
flutter test --name "Off-Route Detection"
flutter test --name "Session Control"
```

### Run with Coverage

```bash
flutter test --coverage
# Then view with:
genhtml coverage/lcov.info -o coverage/html
# Open coverage/html/index.html
```

## Test Structure

### Unit Tests (test/unit/)

Test `RouteProvider` business logic directly by instantiating the provider and calling methods. No platform APIs needed for most tests:

```dart
group('RouteProvider - Session Control', () {
  test('startRun initializes session state', () {
    final provider = RouteProvider();
    provider.startRun(activityType: 'walk_easy');
    
    expect(provider.isRunning, true);
    expect(provider.navigationState, NavigationState.active);
    expect(provider.currentActivityType, 'walk_easy');
    
    provider.dispose();
  });
});
```

### Widget Tests (test/widget/)

Test screen rendering with mocked provider:

```dart
testWidgets('screen renders correctly', (tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<RouteProvider>.value(
      value: routeProvider,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  
  expect(find.text('Fun2Route'), findsOneWidget);
});
```

### Integration Tests (test/integration/)

Test complete user flows across screens:

```dart
testWidgets('complete navigation flow', (tester) async {
  await tester.pumpWidget(createApp());
  await tester.pumpAndSettle();
  
  // Navigate through screens
  await tester.tap(find.text('Get Started'));
  await tester.pumpAndSettle();
  
  // Continue flow assertions...
});
```

## Mock System

### MockHttpClient

The `MockHttpClient` extends `http.BaseClient` to simulate OSRM API responses without real network calls.

```dart
final mockHttp = MockHttpClient();

// Queue responses in FIFO order
mockHttp.queueOSRMSuccess(
  coordinates: [
    [106.8, -6.2],  // [lng, lat] format
    [106.81, -6.21],
    [106.82, -6.22],
  ],
  distance: 5000.0,
  duration: 600.0,
);
```

**Available mock queue methods:**

| Method | Purpose |
|--------|---------|
| `queueOSRMSuccess()` | Valid OSRM route response with polyline |
| `queueOSRMAlternatives()` | Multiple route alternatives |
| `queueOSRMSnapSuccess()` | Nearest road snap response |
| `queueOSRMError(code)` | OSRM API error (e.g., 'NoRoute') |
| `queueHttpError(statusCode)` | HTTP-level error (500, 404) |
| `queueTimeout()` | Simulate network timeout |
| `reset()` | Clear queue and request history |

### ProviderTestHarness

Simplifies setting up a test-ready `RouteProvider`:

```dart
final harness = ProviderTestHarness();
harness.queueDefaultRouteResponses();
// Now call provider methods...
harness.provider.generateRoutes(...);
// Make assertions...
harness.dispose();
```

### Test Fixtures (test_helper.dart)

```dart
// Create test data
final route = createTestRouteCandidate(
  distanceM: 5000,
  score: 95.0,
  personality: RoutePersonality.smoothJog,
);

// Create test polylines
final polyline = createTestPolyline(count: 10);

// Create OSRM coordinates
final coords = makeOSRMCoords(count: 5);

// Assert LatLng proximity
expectLatLngClose(point1, point2);

// Wrap widget with provider
wrapWithProviders(myWidget, routeProvider: myProvider);
```

## Writing Tests as an AI Agent

### Standard Workflow for Writing Tests

1. **Read the source file** to understand the class/method being tested.
2. **Use the test helper fixtures** to create test data.
3. **Write the test** following the patterns in this guide.
4. **Run the test** with `flutter test path/to/test.dart`.
5. **Fix failures** by reading error output and adjusting.

### Testing Pattern: Business Logic (Unit Tests)

```dart
test('describe the behavior', () {
  // 1. Arrange
  final provider = RouteProvider();
  
  // 2. Act
  provider.doSomething();
  
  // 3. Assert
  expect(result, expectedValue);
  
  provider.dispose();
});
```

### Testing Pattern: UI Rendering (Widget Tests)

```dart
testWidgets('describe the UI behavior', (tester) async {
  // 1. Arrange - set up provider with known state
  final provider = RouteProvider();
  
  // 2. Act - render the widget
  await tester.pumpWidget(
    wrapWithProviders(MyScreen(), routeProvider: provider),
  );
  await tester.pumpAndSettle();
  
  // 3. Assert - verify UI elements
  expect(find.text('Expected Label'), findsOneWidget);
  
  provider.dispose();
});
```

### Testing Pattern: Simulate User Interaction

```dart
testWidgets('button tap triggers action', (tester) async {
  await tester.pumpWidget(wrapWithProviders(MyScreen()));
  await tester.pumpAndSettle();
  
  // Find and tap a button
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
  
  // Assert the result
  expect(find.text('Running...'), findsOneWidget);
});
```

## Test Coverage Areas

### Business Logic (Unit Tests)

| Area | Test File | Key Tests |
|------|-----------|-----------|
| Initial State | `route_provider_test.dart` | All default values correct |
| Session Control | `route_provider_test.dart` | startRun, stopRun, resetSession |
| Pause/Resume | `route_provider_test.dart` | togglePauseRun, autoPause |
| Calorie Calculation | `route_provider_test.dart` | walk, jog, scaling |
| Off-Route Detection | `route_provider_test.dart` | onRoute, offRoute, threshold |
| Navigation State | `route_provider_test.dart` | State transitions (idle → finished) |
| POI Management | `route_provider_test.dart` | addPoi, avoidance zones |
| Favorites | `route_provider_test.dart` | add, remove, multiple |
| History | `route_provider_test.dart` | Entry creation, field validation |
| Route Management | `route_provider_test.dart` | setActiveRoute, distance mismatch |
| Timer Behavior | `route_provider_test.dart` | Seconds increment, pause halts |
| Edge Cases | `route_provider_test.dart` | Null safety, double operations |

### UI Rendering (Widget Tests)

| Screen | Test File | Key Tests |
|--------|-----------|-----------|
| Onboarding | `onboarding_screen_test.dart` | Render, text, button presence |
| Home | `home_screen_test.dart` | Run button, history, stats |
| Navigation | `navigation_screen_test.dart` | Active route display, controls |
| Route Selection | `route_selection_screen_test.dart` | Route cards, selection |

### Integration Flows

| Flow | Test File | Key Tests |
|------|-----------|-----------|
| Onboarding → Home | `navigation_flow_test.dart` | Full nav sequence |
| Home → Route Gen → Nav | `navigation_flow_test.dart` | Route lifecycle |

## Common Testing Patterns

### Pattern 1: Test a Provider Method

```dart
group('Feature Name', () {
  test('describes expected behavior', () {
    final provider = RouteProvider();
    
    // Call the method
    provider.methodName();
    
    // Assert the state change
    expect(provider.someProperty, expectedValue);
    
    provider.dispose();
  });
});
```

### Pattern 2: Test with Async Timer (Session Simulation)

```dart
test('timer increments seconds', () async {
  final provider = RouteProvider();
  
  provider.startRun(activityType: 'walk_easy');
  
  // Wait for timer to fire
  await Future.delayed(const Duration(milliseconds: 1100));
  
  expect(provider.secondsElapsed, greaterThanOrEqualTo(1));
  
  provider.stopRun();
  provider.dispose();
});
```

### Pattern 3: Test Widget with Provider State

```dart
testWidgets('widget displays provider data', (tester) async {
  final provider = RouteProvider();
  provider.startRun(activityType: 'jog');
  
  await tester.pumpWidget(
    wrapWithProviders(MyScreen(), routeProvider: provider),
  );
  await tester.pumpAndSettle();
  
  // Verify the UI reflects provider state
  expect(find.textContaining('Jog'), findsOneWidget);
  
  provider.dispose();
});
```

## Debugging Failed Tests

### Common Failures and Fixes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `No provider found` | Missing `ChangeNotifierProvider` wrapper | Wrap widget with `wrapWithProviders()` |
| `Timer still active` | Provider not disposed in `tearDown` | Call `provider.dispose()` in `tearDown` |
| `setState() called after dispose` | Timer firing after test ends | Cancel timer in `tearDown` before dispose |
| `PlatformException` | Geolocator platform channel not mocked | Use `TestDefaultBinaryMessengerBinding` |
| `OSRM Error` | Mock requests not queued FIFO | Call `queueDefaultRouteResponses()` first |
| Widget not found | Screen structure changed | Read the screen source file and update test |
| `pumpAndSettle` timeout | Infinite animation or timer | Use `pump(Duration)` instead |

### Debug Tips

1. **Print widget tree:** `tester.binding.findRenderObject(find.byType(X))`
2. **Slow-motion tests:** `flutter test --reporter expanded`
3. **See all finders:** Use `find.byType`, `find.text`, `find.byIcon`, `find.byKey`
4. **Check test order:** Tests run in declaration order within a group

---

## Quick Start for AI Agents

To write a new test:

```dart
// 1. Import test utilities
import 'package:flutter_test/flutter_test.dart';
import 'package:fun2route/providers/route_provider.dart';

// 2. Import helpers
import '../helpers/test_helper.dart';

void main() {
  // 3. Set up test
  test('my test', () {
    final provider = RouteProvider();
    // ... test logic
    provider.dispose();
  });
}
```

Then run:

```bash
flutter test test/unit/my_new_test.dart