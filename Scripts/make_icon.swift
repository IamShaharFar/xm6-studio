import AppKit
import Foundation

let target = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 44, y: 44, width: 936, height: 936)
let path = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
NSGradient(starting: NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.97, alpha: 1), ending: NSColor(calibratedRed: 0.67, green: 0.84, blue: 0.81, alpha: 1))!.draw(in: path, angle: -55)
NSGraphicsContext.saveGraphicsState()
path.addClip()
let product = NSImage(contentsOfFile: CommandLine.arguments[2])!
let height: CGFloat = 936
let width = height * product.size.width / product.size.height
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
shadow.shadowBlurRadius = 16
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
product.draw(in: NSRect(x: (1024 - width) / 2, y: 44, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.6).setStroke()
path.lineWidth = 2; path.stroke()
image.unlockFocus()
let folder = URL(fileURLWithPath: target).deletingLastPathComponent().appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let n = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: n, height: n))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
// ICNS supports PNG-backed elements directly; this also works on build hosts
// where iconutil cannot reach the system image-conversion service.
func bigEndian(_ value: UInt32) -> Data {
    var n = value.bigEndian
    return withUnsafeBytes(of: &n) { Data($0) }
}
var elements = Data()
for (type, name) in [("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"), ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"), ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"), ("ic10", "icon_512x512@2x.png")] {
    let png = try Data(contentsOf: folder.appendingPathComponent(name))
    elements.append(Data(type.utf8)); elements.append(bigEndian(UInt32(png.count + 8))); elements.append(png)
}
var icns = Data("icns".utf8); icns.append(bigEndian(UInt32(elements.count + 8))); icns.append(elements)
try icns.write(to: URL(fileURLWithPath: target))
if CommandLine.arguments.count > 3 {
    let preview = try Data(contentsOf: folder.appendingPathComponent("icon_512x512@2x.png"))
    try preview.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
}
try FileManager.default.removeItem(at: folder)
