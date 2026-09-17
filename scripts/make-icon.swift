import AppKit

guard CommandLine.arguments.count == 3,
      let artwork = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: swift scripts/make-icon.swift <approved-logo.png> <destination.iconset>")
}
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
// Export the approved icon tile, not the surrounding presentation-board margin.
// These normalized bounds are specific to jotwisp-logo-concept-v1.png.
let artworkTile = NSRect(x: artwork.size.width * 0.115, y: artwork.size.height * 0.115,
                         width: artwork.size.width * 0.77, height: artwork.size.height * 0.77)
var iconChunks = Data()
let chunkTypes = ["icon_16x16": "icp4", "icon_32x32": "icp5", "icon_32x32@2x": "icp6",
                  "icon_128x128": "ic07", "icon_256x256": "ic08", "icon_512x512": "ic09", "icon_512x512@2x": "ic10"]
func uint32(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
for (name, pixels) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                       ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
                       ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let iconRect = NSRect(x: 70, y: 70, width: 884, height: 884)
    // Standard icon export mask gives the Dock transparent corners without
    // changing the approved mark, its colors, or its dimensional shading.
    NSBezierPath(roundedRect: iconRect, xRadius: 218, yRadius: 218).addClip()
    NSGraphicsContext.current?.imageInterpolation = .high
    artwork.draw(in: iconRect, from: artworkTile, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: destination.appendingPathComponent(name + ".png"))
    if let type = chunkTypes[name] {
        iconChunks.append(Data(type.utf8))
        iconChunks.append(uint32(png.count + 8))
        iconChunks.append(png)
    }
}
var icon = Data("icns".utf8)
icon.append(uint32(iconChunks.count + 8))
icon.append(iconChunks)
try icon.write(to: destination.deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))
