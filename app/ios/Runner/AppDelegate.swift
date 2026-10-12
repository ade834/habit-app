import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "com.deshiru.habitapp/shared_database", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "containerPath" else { result(FlutterMethodNotImplemented); return }
      guard let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.deshiru.habitapp") else {
        result(FlutterError(code: "APP_GROUP_UNAVAILABLE", message: "App Group container is unavailable", details: nil)); return
      }
      let sharedDB = shared.appendingPathComponent("habit_app.sqlite")
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let oldDB = documents.appendingPathComponent("habit_app.sqlite")
      if !FileManager.default.fileExists(atPath: sharedDB.path), FileManager.default.fileExists(atPath: oldDB.path) {
        do {
          try FileManager.default.copyItem(at: oldDB, to: sharedDB)
          for suffix in ["-wal", "-shm"] {
            let source = URL(fileURLWithPath: oldDB.path + suffix)
            if FileManager.default.fileExists(atPath: source.path) {
              try FileManager.default.copyItem(at: source, to: URL(fileURLWithPath: sharedDB.path + suffix))
            }
          }
        } catch {
          result(FlutterError(code: "DATABASE_MIGRATION_FAILED", message: error.localizedDescription, details: nil)); return
        }
      }
      result(shared.path)
    }
  }
}
