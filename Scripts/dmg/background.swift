import AppKit

// Draws the background of the installer window, at 1x and 2x, as TIFFs.
// Run by `Scripts/make-dmg.sh`. Usage: background <outputDirectory> <version>
//
// The picture is 660 pt wide and taller than the 400 pt window, so a taller title bar can't
// expose an unpainted strip. Everything that matters sits in the top 340 pt.
let width: CGFloat = 660
let height: CGFloat = 460
let outputDirectory = CommandLine.arguments[1]
let version = CommandLine.arguments[2]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// Spindle's palette (see Theme.swift).
let accent = color(0x637545)
let accentLight = color(0xB7C98F)
let text = color(0xEEEEEE)
let muted = color(0xA0A4AB)

/// The icons sit at these points of the window (see settings.py); the arrow runs between them.
let iconCentreY: CGFloat = 178

/// A y measured down from the top of the image, as AppKit wants it (up from the bottom).
func flipped(_ top: CGFloat) -> CGFloat { height - top }

func drawCentered(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat = 0, top: CGFloat) {
    let attributed = NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: kern,
    ])
    let measured = attributed.size()
    attributed.draw(at: NSPoint(x: width / 2 - measured.width / 2, y: flipped(top) - measured.height))
}

func draw() {
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)

    // Backdrop: the app's dark slate, a little lighter at the top.
    NSGradient(colors: [color(0x2C3440), color(0x171B21)])!.draw(in: bounds, angle: -90)

    // A soft olive glow behind the two icons.
    let centre = NSPoint(x: width / 2, y: flipped(iconCentreY))
    NSGradient(colors: [accent.withAlphaComponent(0.34), accent.withAlphaComponent(0)])!
        .draw(fromCenter: centre, radius: 0, toCenter: centre, radius: 330, options: [])

    // Faint record grooves, echoing the vinyl in the app icon.
    for radius in stride(from: CGFloat(96), through: 330, by: 34) {
        let ring = NSBezierPath(ovalIn: NSRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        ring.lineWidth = 1
        NSColor.white.withAlphaComponent(radius.truncatingRemainder(dividingBy: 68) == 0 ? 0.055 : 0.03).setStroke()
        ring.stroke()
    }

    // Title.
    drawCentered("Spindle", size: 30, weight: .bold, color: text, kern: -0.6, top: 30)
    drawCentered("Version \(version)  \u{00B7}  a minimal music player for your own files",
                 size: 12.5, weight: .regular, color: muted, top: 72)

    // The arrow from the app to Applications: a dotted line ending in a chevron.
    let arrowY = flipped(iconCentreY)
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 252, y: arrowY))
    line.line(to: NSPoint(x: 384, y: arrowY))
    line.lineWidth = 4
    line.lineCapStyle = .round
    line.setLineDash([0.01, 10], count: 2, phase: 0)
    accentLight.withAlphaComponent(0.6).setStroke()
    line.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: 394, y: arrowY + 15))
    head.line(to: NSPoint(x: 412, y: arrowY))
    head.line(to: NSPoint(x: 394, y: arrowY - 15))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    accentLight.setStroke()
    head.stroke()

    // Instructions. The first-launch note matters: the app isn't notarized.
    drawCentered("Drag Spindle into Applications to install", size: 14.5, weight: .medium,
                 color: text.withAlphaComponent(0.9), top: 288)
    drawCentered("First launch: right-click Spindle and choose Open (the app isn\u{2019}t notarized).",
                 size: 11.5, weight: .regular, color: muted, top: 314)
}

func render(scale: Int, name: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width) * scale, pixelsHigh: Int(height) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    // Size in points: 2x pixels over the same points gives the file 144 dpi.
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .tiff, properties: [.compressionMethod: NSBitmapImageRep.TIFFCompression.lzw])!
    try! data.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent(name))
}

render(scale: 1, name: "background.tiff")
render(scale: 2, name: "background@2x.tiff")
