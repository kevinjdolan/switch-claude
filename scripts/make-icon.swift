// Generates AppIcon.iconset PNGs: a rounded-square gradient tile with a swap glyph.
// Usage: swift scripts/make-icon.swift <output-iconset-dir>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(pixels)
    let inset = s * 0.05
    let tile = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.21, yRadius: s * 0.21)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.87, green: 0.47, blue: 0.28, alpha: 1),
        ending: NSColor(calibratedRed: 0.62, green: 0.28, blue: 0.14, alpha: 1)
    )!
    gradient.draw(in: path, angle: -90)

    let glyph = "⇄" as NSString
    let font = NSFont.systemFont(ofSize: s * 0.52, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let size = glyph.size(withAttributes: attrs)
    glyph.draw(
        at: NSPoint(x: (s - size.width) / 2, y: (s - size.height) / 2),
        withAttributes: attrs
    )

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(points: Int, scale: Int) throws {
    let pixels = points * scale
    let rep = render(pixels: pixels)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed for \(pixels)px")
    }
    let suffix = scale == 2 ? "@2x" : ""
    try data.write(to: outDir.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}

for points in [16, 32, 128, 256, 512] {
    try write(points: points, scale: 1)
    try write(points: points, scale: 2)
}
print("Wrote iconset to \(outDir.path)")
