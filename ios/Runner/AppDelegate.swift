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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PdfPages") {
      PdfPages.register(messenger: registrar.messenger())
    }
  }
}

/// Draws the pages of a PDF as PNGs for the AI resume builder's live preview
/// (same channel as Android's MainActivity). Core Graphics only, no package.
enum PdfPages {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "superkarigar/pdf_pages", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "render",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      let width = CGFloat(args["width"] as? Int ?? 1080)
      let maxPages = args["maxPages"] as? Int ?? 3
      DispatchQueue.global(qos: .userInitiated).async {
        let pages = render(path: path, width: width, maxPages: maxPages)
        DispatchQueue.main.async {
          if let pages = pages {
            result(pages)
          } else {
            result(FlutterError(code: "render_failed", message: "Could not read the PDF", details: nil))
          }
        }
      }
    }
  }

  private static func render(path: String, width: CGFloat, maxPages: Int) -> [FlutterStandardTypedData]? {
    guard let document = CGPDFDocument(URL(fileURLWithPath: path) as CFURL) else { return nil }
    var pages: [FlutterStandardTypedData] = []
    let count = min(document.numberOfPages, maxPages)
    guard count > 0 else { return pages }
    for index in 1...count {
      guard let page = document.page(at: index) else { continue }
      let box = page.getBoxRect(.mediaBox)
      let scale = width / box.width
      let size = CGSize(width: width, height: box.height * scale)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let cg = context.cgContext
        // PDF space starts bottom-left; UIKit's starts top-left.
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: scale, y: -scale)
        cg.drawPDFPage(page)
      }
      if let png = image.pngData() {
        pages.append(FlutterStandardTypedData(bytes: png))
      }
    }
    return pages
  }
}
