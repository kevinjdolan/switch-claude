// Renders the DMG window background (600x400 pt) at 1x and 2x.
// Usage: swift scripts/make-dmg-background.swift <output-dir>
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let W: CGFloat = 600
let H: CGFloat = 400

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let desc = base.fontDescriptor.withDesign(.rounded), let font = NSFont(descriptor: desc, size: size) {
        return font
    }
    return base
}

func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = text as NSString
    let size = str.size(withAttributes: attrs)
    str.draw(at: NSPoint(x: (W - size.width) / 2, y: y - size.height / 2), withAttributes: attrs)
}

func render(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(W) * scale, pixelsHigh: Int(H) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: W, height: H) // embeds 72/144 dpi so Finder draws at point size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(scale))
    transform.concat()

    // Warm cream gradient, light at the top.
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.949, green: 0.882, blue: 0.816, alpha: 1),
        ending: NSColor(calibratedRed: 0.984, green: 0.965, blue: 0.941, alpha: 1)
    )!
    gradient.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

    // Soft accent blobs for depth.
    NSColor(calibratedRed: 0.769, green: 0.396, blue: 0.247, alpha: 0.07).setFill()
    NSBezierPath(ovalIn: NSRect(x: -140, y: H - 180, width: 360, height: 360)).fill()
    NSColor(calibratedRed: 0.85, green: 0.6, blue: 0.3, alpha: 0.06).setFill()
    NSBezierPath(ovalIn: NSRect(x: W - 220, y: -160, width: 380, height: 380)).fill()

    // Title and subtitle (top of window; bottom-left origin here).
    drawCentered("Claude Swap Mac", y: H - 58,
                 font: rounded(30, .semibold),
                 color: NSColor(calibratedRed: 0.29, green: 0.196, blue: 0.133, alpha: 1))
    drawCentered("Drag to Applications to install", y: H - 92,
                 font: rounded(13, .medium),
                 color: NSColor(calibratedRed: 0.54, green: 0.459, blue: 0.388, alpha: 1))

    // Arrow between the icon slots (icon centers at x=150 and x=450, y=195 from bottom).
    let arrowColor = NSColor(calibratedRed: 0.769, green: 0.396, blue: 0.247, alpha: 0.9)
    let arrowY: CGFloat = 195
    arrowColor.setStroke()
    let shaft = NSBezierPath()
    shaft.lineWidth = 9
    shaft.lineCapStyle = .round
    shaft.move(to: NSPoint(x: 238, y: arrowY))
    shaft.line(to: NSPoint(x: 352, y: arrowY))
    shaft.stroke()
    arrowColor.setFill()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 374, y: arrowY))
    head.line(to: NSPoint(x: 348, y: arrowY + 14))
    head.line(to: NSPoint(x: 348, y: arrowY - 14))
    head.close()
    head.fill()

    // Hotkey hint along the bottom edge.
    drawCentered("Then press ⌃⌥S anywhere to switch accounts", y: 26,
                 font: rounded(11, .regular),
                 color: NSColor(calibratedRed: 0.54, green: 0.459, blue: 0.388, alpha: 0.75))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for scale in [1, 2] {
    let rep = render(scale: scale)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed at \(scale)x")
    }
    let name = scale == 2 ? "background@2x.png" : "background.png"
    try data.write(to: outDir.appendingPathComponent(name))
}
print("Wrote background PNGs to \(outDir.path)")
