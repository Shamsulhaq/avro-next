import Cocoa

// Usage: make_icon <menu-icon.tiff> <AppIcon.iconset dir>
// Renders the menu-bar glyph (black "অ" on transparent, used as a template image)
// and the full-colour app icon set.

func bitmap(_ px: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

func draw(_ rep: NSBitmapImageRep, _ body: (CGFloat) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    body(CGFloat(rep.pixelsWide))
    NSGraphicsContext.restoreGraphicsState()
}

func glyph(_ size: CGFloat, color: NSColor, weight: NSFont.Weight) {
    let str = NSAttributedString(string: "অ", attributes: [
        .font: NSFont.systemFont(ofSize: size * 0.8, weight: weight), .foregroundColor: color])
    let s = str.size()
    str.draw(at: NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2 - size * 0.02))
}

func write(_ rep: NSBitmapImageRep, _ path: String) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

// Menu icon: 16 pt, with a 2x variant, so macOS draws it at normal menu-bar size.
let menuImage = NSImage(size: NSSize(width: 16, height: 16))
for px in [16, 32] {
    let rep = bitmap(px)
    draw(rep) { s in glyph(s, color: .black, weight: .semibold) }
    rep.size = NSSize(width: 16, height: 16)
    menuImage.addRepresentation(rep)
}
try menuImage.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

let setDir = CommandLine.arguments[2]
try FileManager.default.createDirectory(atPath: setDir, withIntermediateDirectories: true)
let sizes: [(Int, String)] = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
                              (128, "128x128"), (256, "128x128@2x"), (256, "256x256"),
                              (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")]
for (px, name) in sizes {
    let rep = bitmap(px)
    draw(rep) { s in
        let inset = s * 0.06
        let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)
        NSGradient(starting: NSColor(red: 0.05, green: 0.55, blue: 0.42, alpha: 1),
                   ending: NSColor(red: 0.02, green: 0.30, blue: 0.30, alpha: 1))!.draw(in: path, angle: -90)
        glyph(s, color: .white, weight: .bold)
    }
    try write(rep, "\(setDir)/icon_\(name).png")
}
