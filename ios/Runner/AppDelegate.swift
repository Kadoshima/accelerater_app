import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ネイティブメトロノームプラグインを登録
    NativeMetronomePlugin.register(with: self.registrar(forPlugin: "NativeMetronomePlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
