import UIKit
import Flutter
import MapKit
import Vision
import ImageIO
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene lifecycle 下，plugin 註冊必須放在這裡，不能放在 didFinishLaunchingWithOptions
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "townpass/card_ocr", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    let storesChannel = FlutterMethodChannel(name: "townpass/store_search", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    let placesChannel = FlutterMethodChannel(name: "townpass/place_search", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    placesChannel.setMethodCallHandler { call, result in
      guard call.method == "search", let args = call.arguments as? [String: Any],
            let query = args["query"] as? String, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
        result(FlutterMethodNotImplemented); return
      }
      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = query
      request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 25.0375, longitude: 121.5645), latitudinalMeters: 50000, longitudinalMeters: 50000)
      MKLocalSearch(request: request).start { response, error in
        guard let response = response, error == nil else {
          result(FlutterError(code: "search_failed", message: "無法搜尋位置", details: nil)); return
        }
        result(response.mapItems.compactMap { item -> [String: Any]? in
          let c = item.placemark.coordinate
          guard CLLocationCoordinate2DIsValid(c), let name = item.name else { return nil }
          let address = [item.placemark.locality, item.placemark.subLocality, item.placemark.thoroughfare, item.placemark.subThoroughfare].compactMap { $0 }.joined()
          return ["name": name, "address": address, "latitude": c.latitude, "longitude": c.longitude]
        })
      }
    }
    storesChannel.setMethodCallHandler { call, result in
      guard call.method == "search", let args = call.arguments as? [String: Any],
            let lat = args["latitude"] as? Double, let lon = args["longitude"] as? Double else {
        result(FlutterMethodNotImplemented); return
      }
      let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), latitudinalMeters: 4500, longitudinalMeters: 4500)
      let names = ["7-ELEVEN", "全家便利商店", "OK超商", "全聯福利中心", "美廉社", "樂家康超市", "萊爾富"]
      let group = DispatchGroup()
      var found: [[String: Any]] = []
      var successes = 0
      let lock = NSLock()
      for name in names {
        group.enter()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region = region
        MKLocalSearch(request: request).start { response, error in
          defer { group.leave() }
          guard let response = response, error == nil else { return }
          lock.lock()
          defer { lock.unlock() }
          successes += 1
          for item in response.mapItems {
            let c = item.placemark.coordinate
            guard CLLocationCoordinate2DIsValid(c), let title = item.name else { continue }
            let address = [item.placemark.locality, item.placemark.subLocality, item.placemark.thoroughfare, item.placemark.subThoroughfare].compactMap { $0 }.joined()
            found.append(["name": title, "address": address, "latitude": c.latitude, "longitude": c.longitude])
          }
        }
      }
      group.notify(queue: .main) {
        if successes == 0 { result(FlutterError(code: "search_failed", message: "無法搜尋門市", details: nil)); return }
        result(found)
      }
    }
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize", let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else { result(FlutterMethodNotImplemented); return }
      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        do {
          let url = URL(fileURLWithPath: path)
          let source = CGImageSourceCreateWithURL(url as CFURL, nil)
          let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
          let orientationValue = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
          let orientation = CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
          let handler = VNImageRequestHandler(url: url, orientation: orientation, options: [:])
          try handler.perform([request])
          let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
          DispatchQueue.main.async { result(lines) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "ocr_failed", message: "無法辨識照片", details: nil)) }
        }
      }
    }
  }
}
