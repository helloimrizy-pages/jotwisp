import AppKit
import ImageIO

let appURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/Jotwisp.app")
guard let bundle = Bundle(url: appURL) else { fatalError("App bundle is missing") }
precondition(bundle.bundleIdentifier == "app.textdump.mac", "Persistent app identity changed")
for key in ["CFBundleName", "CFBundleDisplayName", "CFBundleExecutable"] {
    precondition(bundle.object(forInfoDictionaryKey: key) as? String == "Jotwisp", "Incorrect \(key)")
}
precondition(FileManager.default.isExecutableFile(atPath: bundle.executableURL!.path), "Executable missing")
for name in ["PRIVACY", "SUPPORT"] {
    precondition(bundle.url(forResource: name, withExtension: "md") != nil, "Missing bundled \(name)")
}
precondition(bundle.url(forResource: "LICENSE", withExtension: "md") != nil ||
             bundle.url(forResource: "LICENSE", withExtension: nil) != nil, "Missing license")
precondition(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil, "Missing privacy manifest")
let iconURL = bundle.url(forResource: "AppIcon", withExtension: "icns")!
guard let source = CGImageSourceCreateWithURL(iconURL as CFURL, nil) else { fatalError("Icon cannot be decoded") }
var sizes = Set<Int>()
for index in 0..<CGImageSourceGetCount(source) {
    guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { fatalError("Icon representation failed") }
    precondition(image.width == image.height)
    sizes.insert(image.width)
    let bitmap = NSBitmapImageRep(cgImage: image)
    precondition(bitmap.hasAlpha, "Icon needs alpha")
    precondition(bitmap.colorAt(x: 0, y: 0)!.alphaComponent == 0, "Icon corner must be transparent")
    precondition(bitmap.colorAt(x: image.width / 2, y: image.height / 2)!.alphaComponent > 0.99)
}
precondition(sizes == Set([16, 32, 64, 128, 256, 512, 1024]), "Missing icon sizes: \(sizes)")
print("Jotwisp bundle verified: identity, executable, privacy/support/license, and 7 transparent icon sizes.")
