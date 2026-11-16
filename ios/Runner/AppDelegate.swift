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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AmapIosPlugin") {
      AmapIosPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DisplayPreferencesPlugin") {
      DisplayPreferencesPlugin.register(with: registrar)
    }
  }
}

/// AMap iOS surface. The Flutter side owns consent and failure policy; this
/// view only maps a GCJ-02 scene onto MAMapKit overlays and camera.
public final class AmapIosPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let configuration = FlutterMethodChannel(name: "mileaf/map_configuration", binaryMessenger: registrar.messenger())
    configuration.setMethodCallHandler { call, result in
      if call.method == "getProcessKey" {
        result(AmapIosPlatformView.processKey)
        return
      }
      guard call.method == "getBinding" else { result(FlutterMethodNotImplemented); return }
      guard let identifier = Bundle.main.bundleIdentifier else {
        result(FlutterError(code: "binding_unavailable", message: "Application identity unavailable", details: nil))
        return
      }
      result(["Bundle ID": identifier])
    }
    let factory = AmapIosViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "app.mileaf/amap_ios")
  }
}

final class AmapIosViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AmapIosPlatformView(
      frame: frame,
      viewId: viewId,
      messenger: messenger,
      args: args as? [String: Any] ?? [:]
    )
  }
}

final class AmapIosPlatformView: NSObject, FlutterPlatformView, MAMapViewDelegate {
  fileprivate static var processKey: String?
  private let channel: FlutterMethodChannel
  private var mapView: MAMapView?
  private var placeholder: UIView?
  private var loaded = false
  private var failed = false
  private var points: [CLLocationCoordinate2D] = []
  private var selectedAnnotation: MAPointAnnotation?
  private var edgePadding: CGFloat = 36

  init(
    frame: CGRect,
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    args: [String: Any]
  ) {
    channel = FlutterMethodChannel(
      name: "mileaf/amap_ios_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    let placeholder = UIView(frame: frame)
    placeholder.backgroundColor = .clear
    placeholder.isUserInteractionEnabled = false
    self.placeholder = placeholder

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }

    guard args["consent"] as? Bool == true else {
      fail(code: "consent_required")
      return
    }
    let apiKey = (args["apiKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !apiKey.isEmpty else {
      fail(code: "api_key_missing")
      return
    }

    guard Self.processKey == nil || Self.processKey == apiKey else {
      fail(code: "restart_required")
      return
    }
    MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
    MAMapView.updatePrivacyAgree(.didAgree)
    let services = AMapServices.shared()
    guard let services else {
      fail(code: "amap_services_unavailable")
      return
    }
    services.enableHTTPS = true
    if Self.processKey == nil {
      services.apiKey = apiKey
      Self.processKey = apiKey
    }

    let map = MAMapView(frame: frame)
    map.delegate = self
    map.mapType = .standard
    map.showsCompass = false
    map.showsScale = false
    map.showsUserLocation = false
    map.isRotateEnabled = false
    map.isScrollEnabled = false
    map.isZoomEnabled = false
    self.mapView = map
    if let scene = args["scene"] as? [String: Any] {
      apply(scene)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
    mapView?.delegate = nil
    mapView?.removeFromSuperview()
  }

  func view() -> UIView {
    mapView ?? placeholder ?? UIView()
  }

  private func fail(code: String) {
    failed = true
    channel.invokeMethod("onMapFailed", arguments: ["code": code])
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      result([
        "status": loaded ? "loaded" : (failed ? "failed" : "loading"),
        "approvalNumber": approvalNumber(),
      ])
    case "setScene":
      if let scene = call.arguments as? [String: Any] { apply(scene) }
      result(nil)
    case "setSelected":
      setSelected(call.arguments)
      result(nil)
    case "fitBounds":
      fit()
      result(nil)
    case "zoomIn":
      zoom(by: 1)
      result(nil)
    case "zoomOut":
      zoom(by: -1)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(_ scene: [String: Any]) {
    guard let map = mapView else { return }
    map.removeOverlays(map.overlays)
    map.removeAnnotations(map.annotations)
    selectedAnnotation = nil
    points = []

    let colors = scene["colors"] as? [String: Any] ?? [:]
    let lineColor = uiColor(
      colors["line"],
      fallback: UIColor(red: 0.184, green: 0.490, blue: 0.345, alpha: 1)
    )
    let startColor = uiColor(colors["start"], fallback: lineColor)
    let endColor = uiColor(
      colors["end"],
      fallback: UIColor(red: 0.078, green: 0.125, blue: 0.098, alpha: 1)
    )
    let selectedColor = uiColor(
      colors["selected"],
      fallback: UIColor(red: 0.725, green: 0.506, blue: 0.239, alpha: 1)
    )

    if let segments = scene["segments"] as? [Any] {
      for segment in segments {
        guard let rawPoints = segment as? [Any] else { continue }
        var coords = rawPoints.compactMap { valid(pair: $0) }
        if coords.count > 1 {
          coords.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress,
              let line = MAPolyline(
                coordinates: base,
                count: UInt(buffer.count)
              )
            else { return }
            line.title = encode(color: lineColor)
            map.add(line)
          }
        }
        points.append(contentsOf: coords)
      }
    }
    if let coord = valid(pair: scene["start"]) {
      add(point: coord, color: startColor, title: "起点")
      points.append(coord)
    }
    if let coord = valid(pair: scene["end"]) {
      add(point: coord, color: endColor, title: "终点")
      points.append(coord)
    }
    if let coord = valid(pair: scene["selected"]) {
      let annotation = MAPointAnnotation()
      annotation.coordinate = coord
      annotation.title = "选中"
      annotation.subtitle = encode(color: selectedColor)
      map.addAnnotation(annotation)
      selectedAnnotation = annotation
    }
    if let padding = scene["padding"] as? NSNumber {
      edgePadding = CGFloat(padding.doubleValue)
    }
    map.mapType = (scene["night"] as? Bool) == true ? .standardNight : .standard
    let interactive = (scene["interactive"] as? Bool) == true
    map.isScrollEnabled = interactive
    map.isZoomEnabled = interactive
    fit()
  }

  private func add(point: CLLocationCoordinate2D, color: UIColor, title: String) {
    let annotation = MAPointAnnotation()
    annotation.coordinate = point
    annotation.title = title
    annotation.subtitle = encode(color: color)
    mapView?.addAnnotation(annotation)
  }

  private func setSelected(_ raw: Any?) {
    guard let map = mapView else { return }
    if let selectedAnnotation {
      map.removeAnnotation(selectedAnnotation)
    }
    selectedAnnotation = nil
    guard let coord = valid(pair: raw) else { return }
    let annotation = MAPointAnnotation()
    annotation.coordinate = coord
    annotation.title = "选中"
    annotation.subtitle = encode(
      color: UIColor(red: 0.725, green: 0.506, blue: 0.239, alpha: 1)
    )
    map.addAnnotation(annotation)
    selectedAnnotation = annotation
    map.setCenter(coord, animated: true)
  }

  private func fit() {
    guard let map = mapView, !points.isEmpty else { return }
    if points.count == 1 {
      map.setCenter(points[0], animated: false)
      map.setZoomLevel(15, animated: false)
      return
    }
    var rect = MAMapRectNull
    for point in points {
      let mapPoint = MAMapPointForCoordinate(point)
      rect = MAMapRectUnion(
        rect,
        MAMapRectMake(mapPoint.x, mapPoint.y, 0, 0)
      )
    }
    map.setVisibleMapRect(
      rect,
      edgePadding: UIEdgeInsets(
        top: edgePadding,
        left: edgePadding,
        bottom: edgePadding,
        right: edgePadding
      ),
      animated: false
    )
  }

  private func zoom(by delta: CGFloat) {
    guard let map = mapView else { return }
    let next = min(max(map.zoomLevel + delta, map.minZoomLevel), map.maxZoomLevel)
    map.setZoomLevel(next, animated: true)
  }

  private func valid(pair: Any?) -> CLLocationCoordinate2D? {
    guard let pair = pair as? [Any], pair.count >= 2,
      let lat = (pair[0] as? NSNumber)?.doubleValue,
      let lon = (pair[1] as? NSNumber)?.doubleValue
    else { return nil }
    guard lat.isFinite, lon.isFinite, lat >= -90, lat <= 90, lon >= -180, lon <= 180 else {
      return nil
    }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
  }

  private func approvalNumber() -> String? {
    guard let map = mapView else { return nil }
    let value = map.mapContentApprovalNumber()
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  private func encode(color: UIColor) -> String {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    _ = color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return "\(Int(red * 255)),\(Int(green * 255)),\(Int(blue * 255))"
  }

  private func uiColor(_ value: Any?, fallback: UIColor) -> UIColor {
    guard let number = value as? NSNumber else { return fallback }
    let argb = number.uint32Value
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }

  private func color(from encoded: String?, fallback: UIColor) -> UIColor {
    guard let encoded else { return fallback }
    let parts = encoded.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 3 else { return fallback }
    return UIColor(
      red: parts[0] / 255,
      green: parts[1] / 255,
      blue: parts[2] / 255,
      alpha: 1
    )
  }

  private func dot(_ color: UIColor, radius: CGFloat) -> UIImage {
    let size = CGSize(width: radius * 2, height: radius * 2)
    return UIGraphicsImageRenderer(size: size).image { context in
      color.setFill()
      context.cgContext.fillEllipse(
        in: CGRect(origin: .zero, size: size)
      )
    }
  }

  func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
    guard !(annotation is MAUserLocation) else { return nil }
    let identifier = "mileaf-amap-dot"
    guard let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
      ?? MAAnnotationView(annotation: annotation, reuseIdentifier: identifier)
    else { return nil }
    view.annotation = annotation
    view.image = dot(
      color(
        from: annotation.subtitle,
        fallback: UIColor(red: 0.184, green: 0.490, blue: 0.345, alpha: 1)
      ),
      radius: 7
    )
    view.centerOffset = .zero
    view.canShowCallout = false
    view.isEnabled = false
    return view
  }

  func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
    guard let line = overlay as? MAPolyline else {
      return MAOverlayRenderer(overlay: overlay)
    }
    guard let renderer = MAPolylineRenderer(polyline: line) else {
      return MAOverlayRenderer(overlay: overlay)
    }
    renderer.strokeColor = color(
      from: line.title,
      fallback: UIColor(red: 0.184, green: 0.490, blue: 0.345, alpha: 0.8)
    )
    renderer.lineWidth = 4
    return renderer
  }

  func mapViewDidFinishLoadingMap(_ mapView: MAMapView!) {
    loaded = true
    channel.invokeMethod(
      "onMapLoaded",
      arguments: ["approvalNumber": approvalNumber()]
    )
  }

  @objc(mapViewDidFailLoadingMap:withError:)
  func mapViewDidFailLoadingMap(_ mapView: MAMapView!, withError error: Error!) {
    failed = true
    channel.invokeMethod("onMapFailed", arguments: ["code": "init_failed"])
  }
}
