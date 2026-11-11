import AVFoundation
import Cocoa

// Renders a demo video of Avro Next typing. Every candidate list and every
// default choice comes from the real riti engine through AvroEngine and
// CandidateState, the same path the input method uses. The window and the
// candidate bar are drawn here to match the app's look; this is a rendering,
// not a screen recording.
//
// Build and run:
//   mkdir -p build/demo && cp Tools/demo_video.swift build/demo/main.swift
//   swiftc -O -import-objc-header Sources/Bridging-Header.h -Xcc -Iriti/include \
//     Sources/Engine.swift Sources/Settings.swift Sources/KeyMap.swift Sources/CandidateState.swift \
//     build/demo/main.swift riti/target/release/libriti.a -framework Cocoa -framework AVFoundation -o build/demo/demo_video
//   build/demo/demo_video riti/data media/avro-next-demo.mp4 [stills dir]

let W = 1280, H = 720
let FPS: Int32 = 30
let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: demo_video <dataDir> <out.mp4> [stillsDir]"); exit(2) }
let stillsDir = args.count > 3 ? args[3] : nil

// Fresh user dir so learned choices start empty, like a new install.
let userDir = NSTemporaryDirectory() + "avro-demo-\(getpid())"
try? FileManager.default.createDirectory(atPath: userDir, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(atPath: userDir) }
guard let engine = AvroEngine(databaseDir: args[1], userDir: userDir) else { print("engine init failed"); exit(1) }

// MARK: - Scene state

var lines: [String] = [""]
var state = CandidateState()
var keyLabel = ""
var keyAge = 999
var caption = ""
var card: (title: String, subtitle: String)?

// MARK: - Drawing

let accent = NSColor(srgbRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)

func bangla(_ size: CGFloat, bold: Bool = false) -> NSFont {
    let name = bold ? "KohinoorBangla-Semibold" : "KohinoorBangla-Regular"
    return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
}

func draw(_ s: String, font: NSFont, color: NSColor, at p: NSPoint, extra: [NSAttributedString.Key: Any] = [:]) -> CGFloat {
    var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    attrs.merge(extra) { $1 }
    let a = NSAttributedString(string: s, attributes: attrs)
    a.draw(at: p)
    return a.size().width
}

func size(_ s: String, font: NSFont) -> NSSize {
    NSAttributedString(string: s, attributes: [.font: font]).size()
}

func centered(_ s: String, font: NSFont, color: NSColor, y: CGFloat) {
    let w = size(s, font: font).width
    _ = draw(s, font: font, color: color, at: NSPoint(x: (CGFloat(W) - w) / 2, y: y))
}

func background() {
    NSGradient(starting: NSColor(srgbRed: 0.05, green: 0.55, blue: 0.42, alpha: 1),
               ending: NSColor(srgbRed: 0.02, green: 0.24, blue: 0.30, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -60)
}

func drawCard(_ c: (title: String, subtitle: String)) {
    // App icon: rounded square with অ, like the real icon.
    let icon = NSRect(x: CGFloat(W) / 2 - 70, y: 380, width: 140, height: 140)
    NSColor(white: 1, alpha: 0.16).setFill()
    NSBezierPath(roundedRect: icon, xRadius: 32, yRadius: 32).fill()
    let g = size("অ", font: bangla(96, bold: true))
    _ = draw("অ", font: bangla(96, bold: true), color: .white,
             at: NSPoint(x: icon.midX - g.width / 2, y: icon.midY - g.height / 2))
    centered(c.title, font: .systemFont(ofSize: 64, weight: .bold), color: .white, y: 270)
    centered(c.subtitle, font: .systemFont(ofSize: 28, weight: .medium), color: NSColor(white: 1, alpha: 0.85), y: 215)
}

func drawCandidateBar(items: [String], selected: Int, at origin: NSPoint) {
    let font = bangla(26), numFont = NSFont.systemFont(ofSize: 18)
    let pad: CGFloat = 5, gap: CGFloat = 3, cellH: CGFloat = 46
    var widths: [CGFloat] = []
    for (i, t) in items.enumerated() {
        widths.append(size("\(i + 1) ", font: numFont).width + size(t, font: font).width + 20)
    }
    let barW = widths.reduce(0, +) + gap * CGFloat(items.count - 1) + pad * 2
    let bar = NSRect(x: origin.x, y: origin.y - cellH - pad * 2, width: barW, height: cellH + pad * 2)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 14
    shadow.shadowOffset = NSSize(width: 0, height: -4)
    shadow.shadowColor = NSColor(white: 0, alpha: 0.28)
    shadow.set()
    NSColor(white: 0.97, alpha: 1).setFill()
    NSBezierPath(roundedRect: bar, xRadius: 10, yRadius: 10).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 0, alpha: 0.08).setStroke()
    NSBezierPath(roundedRect: bar, xRadius: 10, yRadius: 10).stroke()

    var x = bar.minX + pad
    for (i, t) in items.enumerated() {
        let cell = NSRect(x: x, y: bar.minY + pad, width: widths[i], height: cellH)
        let on = i == selected
        if on {
            accent.setFill()
            NSBezierPath(roundedRect: cell, xRadius: 7, yRadius: 7).fill()
        }
        let numColor = on ? NSColor(white: 1, alpha: 0.85) : NSColor(white: 0.45, alpha: 1)
        let tx = cell.minX + 10
        let nw = draw("\(i + 1) ", font: numFont, color: numColor, at: NSPoint(x: tx, y: cell.minY + 12))
        _ = draw(t, font: font, color: on ? .white : .black, at: NSPoint(x: tx + nw, y: cell.minY + 6))
        x += widths[i] + gap
    }
}

func drawFrame(_ f: Int) {
    background()
    if let c = card { drawCard(c); return }

    // Menu bar with the Avro Next input-source indicator.
    NSColor(white: 1, alpha: 0.82).setFill()
    NSRect(x: 0, y: CGFloat(H) - 30, width: CGFloat(W), height: 30).fill()
    _ = draw("", font: .systemFont(ofSize: 18), color: .black, at: NSPoint(x: 20, y: CGFloat(H) - 27))
    _ = draw("Notes", font: .systemFont(ofSize: 15, weight: .semibold), color: .black, at: NSPoint(x: 52, y: CGFloat(H) - 25))
    let ind = NSRect(x: CGFloat(W) - 118, y: CGFloat(H) - 25, width: 26, height: 20)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: ind, xRadius: 5, yRadius: 5).fill()
    _ = draw("অ", font: bangla(15, bold: true), color: .white, at: NSPoint(x: ind.minX + 6, y: ind.minY - 1))
    _ = draw("Avro Next", font: .systemFont(ofSize: 14), color: .black, at: NSPoint(x: CGFloat(W) - 86, y: CGFloat(H) - 24))

    // Editor window.
    let win = NSRect(x: 140, y: 150, width: 1000, height: 460)
    let winPath = NSBezierPath(roundedRect: win, xRadius: 14, yRadius: 14)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
    shadow.set()
    NSColor.white.setFill()
    winPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    winPath.addClip()
    let titleBar = NSRect(x: win.minX, y: win.maxY - 46, width: win.width, height: 46)
    NSColor(white: 0.955, alpha: 1).setFill()
    titleBar.fill()
    NSColor(white: 0.86, alpha: 1).setFill()
    NSRect(x: win.minX, y: titleBar.minY, width: win.width, height: 1).fill()
    NSGraphicsContext.restoreGraphicsState()
    for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        c.setFill()
        NSBezierPath(ovalIn: NSRect(x: win.minX + 20 + CGFloat(i) * 22, y: titleBar.midY - 7, width: 14, height: 14)).fill()
    }
    let title = "আমার নোট"
    let tw = size(title, font: bangla(16, bold: true)).width
    _ = draw(title, font: bangla(16, bold: true), color: NSColor(white: 0.25, alpha: 1),
             at: NSPoint(x: win.midX - tw / 2, y: titleBar.minY + 11))

    // Text lines, the composition (underlined) and the candidate bar.
    let font = bangla(38)
    var y = titleBar.minY - 80
    for (i, line) in lines.enumerated() {
        let left = win.minX + 44
        var x = left + draw(line, font: font, color: .black, at: NSPoint(x: left, y: y))
        if i == lines.count - 1 {
            let markX = x
            if let current = state.current {
                x += draw(current, font: font, color: .black, at: NSPoint(x: x, y: y),
                          extra: [.underlineStyle: NSUnderlineStyle.single.rawValue, .underlineColor: accent])
            }
            if (f / 16) % 2 == 0 || state.current != nil {
                NSColor.black.setFill()
                NSRect(x: x + 2, y: y + 6, width: 2.5, height: 44).fill()
            }
            if state.items.count > 1 {
                drawCandidateBar(items: state.items, selected: state.selected, at: NSPoint(x: markX - 6, y: y - 4))
            }
        }
        y -= 66
    }

    // Caption and the key being pressed.
    if !caption.isEmpty {
        centered(caption, font: .systemFont(ofSize: 32, weight: .semibold), color: .white, y: 82)
    }
    if keyAge < 22 && !keyLabel.isEmpty {
        let alpha = keyAge < 14 ? 1.0 : 1.0 - Double(keyAge - 14) / 8
        let kf = NSFont.monospacedSystemFont(ofSize: 24, weight: .semibold)
        let ks = size(keyLabel, font: kf)
        let pill = NSRect(x: (CGFloat(W) - ks.width) / 2 - 18, y: 22, width: ks.width + 36, height: 42)
        NSColor(white: 0, alpha: 0.55 * alpha).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 10, yRadius: 10).fill()
        _ = draw(keyLabel, font: kf, color: NSColor(white: 1, alpha: alpha), at: NSPoint(x: pill.minX + 18, y: pill.minY + 8))
    }
}

// MARK: - Video writer

let outURL = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: outURL)
let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 5_000_000,
                                      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
guard writer.startWriting() else { print("writer failed: \(String(describing: writer.error))"); exit(1) }
writer.startSession(atSourceTime: .zero)

var frame: Int64 = 0
var stillCount = 0

func emit(_ n: Int) {
    for _ in 0..<n {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        guard let pb = buffer else { print("no pixel buffer"); exit(1) }
        CVPixelBufferLockBaseAddress(pb, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
                            bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        drawFrame(Int(frame))
        NSGraphicsContext.restoreGraphicsState()
        CVPixelBufferUnlockBaseAddress(pb, [])
        adaptor.append(pb, withPresentationTime: CMTime(value: frame, timescale: FPS))
        frame += 1
        keyAge += 1
    }
}

/// Saves the current scene as a PNG, for checking the result.
func still(_ name: String) {
    guard let dir = stillsDir else { return }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawFrame(0)
    NSGraphicsContext.restoreGraphicsState()
    stillCount += 1
    try? rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(dir)/\(String(format: "%02d", stillCount))-\(name).png"))
}

// MARK: - Script

func key(_ label: String) { keyLabel = label; keyAge = 0 }

func type(_ word: String, perKey: Int = 6) {
    for ch in word {
        key(String(ch))
        let s = engine.press(KeyMap.code(for: ch)!, shift: ch.isUppercase, selection: state.selected)
        if let s { state.load(s.items, preferred: s.previouslySelectedIndex) }
        emit(perKey)
    }
}

func down(_ n: Int = 1) {
    for _ in 0..<n {
        key("↓")
        state.move(by: 1)
        emit(14)
    }
}

func commit(_ label: String = "Space", suffix: String = " ") {
    key(label)
    if let text = state.current {
        engine.commit(index: state.selected)
        lines[lines.count - 1] += text + suffix
    }
    state.clear()
    emit(10)
}

func newLine() {
    key("Return")
    lines.append("")
    emit(12)
}

// Title
card = ("Avro Next", "Avro Phonetic Bangla typing for Apple Silicon Macs")
emit(75)
still("title")
card = nil

// 1. Phonetic typing
caption = "Type Bangla phonetically, just like Avro"
emit(20)
type("ami"); emit(8); still("typing-ami"); commit()
type("amar"); emit(6); commit()
type("sonar"); emit(6); commit()
type("bangla"); emit(10); commit()
emit(30)

// 2. Choosing a different word
newLine()
caption = "Pick another word with the arrow keys"
emit(15)
type("ami"); commit()
type("tomay"); emit(16); down(); emit(18); still("choose-tomay"); commit()
type("valobasi"); emit(16); down(); emit(22); still("choose-valobasi"); commit()
emit(30)

// 3. Learned choices
newLine()
caption = "Next time, it remembers your choice"
emit(15)
type("tomay"); emit(40); still("remembered-tomay"); commit()
type("valobasi"); emit(40); still("remembered-valobasi"); commit()
emit(40)

// End card
caption = ""
card = ("Free and open source", "github.com/Shamsulhaq/avro-next")
emit(90)
still("end")

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { print("writer error: \(String(describing: writer.error))"); exit(1) }
print(String(format: "wrote %@: %d frames, %.1f s", outURL.path, frame, Double(frame) / Double(FPS)))
