import Cocoa

/// Avro Next's own compact candidate bar.
///
/// Replaces IMKCandidates, which took the arrow keys for itself while visible and
/// reset its highlight on every reload. This window never takes keyboard focus and
/// never decides the selection: it only draws `CandidateState` and reports clicks.
final class CandidateWindow {
    var onClick: ((Int) -> Void)?
    var vertical = false
    var fontSize: CGFloat = 13

    private let panel: NSPanel
    private let stack = NSStackView()
    private var cells: [CandidateCell] = []

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.masksToBounds = true

        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the candidates under `anchor` (a screen rect of the text line).
    func show(_ items: [String], selected: Int, anchor: NSRect) {
        rebuild(items)
        highlight(selected)
        position(below: anchor)
        panel.orderFrontRegardless()
    }

    /// Moves the highlight without rebuilding or moving the window.
    func highlight(_ selected: Int) {
        for (i, cell) in cells.enumerated() { cell.isSelected = i == selected }
    }

    func hide() { panel.orderOut(nil) }

    // MARK: - Layout

    private func rebuild(_ items: [String]) {
        stack.orientation = vertical ? .vertical : .horizontal
        stack.alignment = vertical ? .leading : .centerY
        cells.forEach { $0.removeFromSuperview() }
        cells = items.enumerated().map { i, text in
            let cell = CandidateCell(number: i + 1, text: text, fontSize: fontSize)
            cell.onClick = { [weak self] in self?.onClick?(i) }
            return cell
        }
        cells.forEach { stack.addArrangedSubview($0) }
        if vertical {
            // Equal-width rows so the highlight spans the list.
            let width = cells.map(\.fittingSize.width).max() ?? 0
            cells.forEach { $0.widthAnchor.constraint(equalToConstant: width).isActive = true }
        }
        stack.layoutSubtreeIfNeeded()
        panel.setContentSize(stack.fittingSize)
    }

    private func position(below anchor: NSRect) {
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10_000, height: 10_000)
        var origin = NSPoint(x: anchor.minX, y: anchor.minY - size.height - 4)
        if origin.y < visible.minY { origin.y = anchor.maxY + 4 }          // no room below: go above
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        panel.setFrameOrigin(origin)
    }
}

/// One numbered candidate. Draws its own highlight and reports mouse clicks.
private final class CandidateCell: NSView {
    var onClick: (() -> Void)?
    var isSelected = false { didSet { if oldValue != isSelected { updateColors() } } }

    private let label: NSTextField

    init(number: Int, text: String, fontSize: CGFloat) {
        let attributed = NSMutableAttributedString(
            string: "\(number) ", attributes: [.font: NSFont.systemFont(ofSize: fontSize * 0.75)])
        attributed.append(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: fontSize)]))
        label = NSTextField(labelWithAttributedString: attributed)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 4
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func updateColors() {
        layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        label.textColor = isSelected ? .white : .labelColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }
}
