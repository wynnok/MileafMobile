import Flutter
import MapKit
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MapKitPlugin") {
      MapKitPlugin.register(with: registrar)
    }
  }
}



/// Interim iOS map surface. It uses MapKit (Apple Maps) until an AMap iOS key
/// is configured; the Dart scene contract is identical to the Android surface.
public final class MapKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = MapKitViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "app.mileaf/mapkit")
  }
}

final class MapKitViewFactory: NSObject, FlutterPlatformViewFactory {
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
    MapKitPlatformView(
      frame: frame,
      viewId: viewId,
      messenger: messenger,
      args: args as? [String: Any] ?? [:]
    )
  }
}

final class MapKitPlatformView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let mapView: MKMapView
  private let channel: FlutterMethodChannel
  private var loaded = false
  private var failed = false
  private var points: [CLLocationCoordinate2D] = []
  private var selected: MKPointAnnotation?
  private var edgePadding: CGFloat = 36

  init(
    frame: CGRect,
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    args: [String: Any]
  ) {
    mapView = MKMapView(frame: frame)
    channel = FlutterMethodChannel(
      name: "mileaf/mapkit_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    mapView.delegate = self
    mapView.showsCompass = false
    mapView.showsScale = false
    mapView.showsUserLocation = false
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    mapView.pointOfInterestFilter = .excludingAll
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    if let scene = args["scene"] as? [String: Any] {
      apply(scene)
    }
  }

  func view() -> UIView { mapView }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      result([
        "status": loaded ? "loaded" : (failed ? "failed" : "loading"),
      ])
    case "setScene":
      if let scene = call.arguments as? [String: Any] { apply(scene) }
      result(nil)
    case "setSelected":
      setSelected(call.arguments as? [Double])
      result(nil)
    case "setNight":
      if let night = call.arguments as? Bool {
        mapView.overrideUserInterfaceStyle = night ? .dark : .light
      }
      result(nil)
    case "setInteractive":
      let enabled = (call.arguments as? Bool) ?? false
      mapView.isScrollEnabled = enabled
      mapView.isZoomEnabled = enabled
      result(nil)
    case "fitBounds":
      fit()
      result(nil)
    case "zoomIn":
      zoom(by: 0.5)
      result(nil)
    case "zoomOut":
      zoom(by: 2.0)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(_ scene: [String: Any]) {
    mapView.removeOverlays(mapView.overlays)
    mapView.removeAnnotations(mapView.annotations)
    selected = nil
    points = []

    let colors = scene["colors"] as? [String: Any] ?? [:]
    let lineColor = uiColor(colors["line"], fallback: UIColor(red: 0.184, green: 0.490, blue: 0.345, alpha: 1))
    let startColor = uiColor(colors["start"], fallback: lineColor)
    let endColor = uiColor(colors["end"], fallback: UIColor(red: 0.078, green: 0.125, blue: 0.098, alpha: 1))
    let selectedColor = uiColor(colors["selected"], fallback: UIColor(red: 0.725, green: 0.506, blue: 0.239, alpha: 1))

    if let segments = scene["segments"] as? [[[Double]]] {
      for segment in segments {
        let coords = segment.compactMap { pair -> CLLocationCoordinate2D? in
          guard pair.count >= 2 else { return nil }
          return valid(pair[0], pair[1])
        }
        if coords.count > 1 {
          let line = MKPolyline(coordinates: coords, count: coords.count)
          line.title = encode(color: lineColor)
          mapView.addOverlay(line)
        }
        points.append(contentsOf: coords)
      }
    }
    if let pair = scene["start"] as? [Double], pair.count >= 2, let coord = valid(pair[0], pair[1]) {
      add(point: coord, color: startColor, title: "起点")
      points.append(coord)
    }
    if let pair = scene["end"] as? [Double], pair.count >= 2, let coord = valid(pair[0], pair[1]) {
      add(point: coord, color: endColor, title: "终点")
      points.append(coord)
    }
    if let pair = scene["selected"] as? [Double], pair.count >= 2, let coord = valid(pair[0], pair[1]) {
      let annotation = MKPointAnnotation()
      annotation.coordinate = coord
      annotation.title = "选中"
      annotation.subtitle = encode(color: selectedColor)
      mapView.addAnnotation(annotation)
      selected = annotation
    }
    if let padding = scene["padding"] as? NSNumber {
      edgePadding = CGFloat(padding.doubleValue)
    }
    if let night = scene["night"] as? Bool {
      mapView.overrideUserInterfaceStyle = night ? .dark : .light
    }
    if let interactive = scene["interactive"] as? Bool {
      mapView.isScrollEnabled = interactive
      mapView.isZoomEnabled = interactive
    }
    fit()
  }

  private func add(point: CLLocationCoordinate2D, color: UIColor, title: String) {
    let annotation = MKPointAnnotation()
    annotation.coordinate = point
    annotation.title = title
    annotation.subtitle = encode(color: color)
    mapView.addAnnotation(annotation)
  }

  private func setSelected(_ pair: [Double]?) {
    if let selected { mapView.removeAnnotation(selected) }
    selected = nil
    guard let pair, pair.count >= 2, let coord = valid(pair[0], pair[1]) else { return }
    let annotation = MKPointAnnotation()
    annotation.coordinate = coord
    annotation.title = "选中"
    annotation.subtitle = encode(color: UIColor(red: 0.725, green: 0.506, blue: 0.239, alpha: 1))
    mapView.addAnnotation(annotation)
    selected = annotation
    mapView.setCenter(coord, animated: true)
  }

  private func fit() {
    guard !points.isEmpty else { return }
    if points.count == 1 {
      mapView.setRegion(
        MKCoordinateRegion(center: points[0], latitudinalMeters: 1800, longitudinalMeters: 1800),
        animated: false
      )
      return
    }
    var rect = MKMapRect.null
    for point in points {
      let mapPoint = MKMapPoint(point)
      rect = rect.union(MKMapRect(x: mapPoint.x, y: mapPoint.y, width: 0, height: 0))
    }
    mapView.setVisibleMapRect(
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

  private func zoom(by factor: Double) {
    var region = mapView.region
    region.span.latitudeDelta *= factor
    region.span.longitudeDelta *= factor
    mapView.setRegion(region, animated: true)
  }

  private func valid(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D? {
    guard lat.isFinite, lon.isFinite, lat >= -90, lat <= 90, lon >= -180, lon <= 180 else {
      return nil
    }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
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

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
    let renderer = MKPolylineRenderer(polyline: line)
    renderer.strokeColor = color(from: line.title, fallback: UIColor(red: 0.184, green: 0.490, blue: 0.345, alpha: 0.8))
    renderer.lineWidth = 4
    return renderer
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard !(annotation is MKUserLocation) else { return nil }
    let identifier = "mileaf-pin"
    let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
      ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
    view.annotation = annotation
    view.canShowCallout = false
    view.markerTintColor = color(
      from: (annotation as? MKPointAnnotation)?.subtitle,
      fallback: UIColor(red: 0.184, green: 0.490, blue: 0.345, alpha: 1)
    )
    return view
  }

  func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
    loaded = true
    channel.invokeMethod("onMapLoaded", arguments: nil)
  }

  func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
    if fullyRendered {
      loaded = true
      channel.invokeMethod("onMapLoaded", arguments: nil)
    }
  }

  func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
    failed = true
    channel.invokeMethod("onMapFailed", arguments: ["code": "init_failed"])
  }
}
