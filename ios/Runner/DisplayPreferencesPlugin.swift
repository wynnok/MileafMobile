import Flutter
import UIKit

/// Read-only bridge for the iOS accessibility preference Flutter does not
/// currently surface through MediaQuery.
final class DisplayPreferencesPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mileaf/display_preferences",
      binaryMessenger: registrar.messenger()
    )
    let instance = DisplayPreferencesPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.publish()
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "getDisplayPreferences" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result([
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled
    ])
  }

  private func publish() {
    channel.invokeMethod(
      "displayPreferencesChanged",
      arguments: [
        "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled
      ]
    )
  }
}
