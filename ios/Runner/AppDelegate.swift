import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register method channel to receive Google Maps API Key from Dart
    let controller = window.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.fun2route/maps",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      if call.method == "setApiKey" {
        if let key = call.arguments as? String, !key.isEmpty {
          GMSServices.provideAPIKey(key)
        }
        result(nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
