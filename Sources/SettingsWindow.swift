import Cocoa

/// Preferences window. Every change is saved and applied immediately; the window
/// resizes to fit, so Probhat-only options appear only when they matter.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private static let contentWidth: CGFloat = 400

    private var settings = Settings.load()
    private let userDir: URL

    private let layoutPopup = NSPopUpButton()
    private let dictionaryCheck = NSButton(checkboxWithTitle: "Show dictionary suggestions", target: nil, action: nil)
    private let englishCheck = NSButton(checkboxWithTitle: "Include English words", target: nil, action: nil)
    private let quotesCheck = NSButton(checkboxWithTitle: "Use smart (curly) quotes", target: nil, action: nil)
    private var fixedChecks: [(NSButton, WritableKeyPath<Settings, Bool>)] = []
    private var fixedGroup = NSStackView()
    private let stylePopup = NSPopUpButton()
    private let fontStepper = NSStepper()
    private let fontLabel = NSTextField(labelWithString: "")
    private let updateCheck = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
    private let prereleaseCheck = NSButton(checkboxWithTitle: "Include pre-release (test) versions", target: nil, action: nil)
    private let updateStatus = NSTextField(labelWithString: "")
    private var updateObserver: NSObjectProtocol?
    private let root = NSStackView()

    init() {
        userDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AvroNext", isDirectory: true)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Self.contentWidth + 40, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Avro Next Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI(in: window)
        reflect(animated: false)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func present() {
        settings = Settings.load()
        reflect(animated: false)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI(in window: NSWindow) {
        layoutPopup.addItems(withTitles: LayoutChoice.allCases.map(\.title))
        stylePopup.addItems(withTitles: CandidateStyle.allCases.map(\.title))
        [layoutPopup, stylePopup].forEach { $0.target = self; $0.action = #selector(changed) }
        [dictionaryCheck, englishCheck, quotesCheck].forEach { $0.target = self; $0.action = #selector(changed) }
        fontStepper.minValue = 11; fontStepper.maxValue = 32; fontStepper.increment = 1
        fontStepper.target = self; fontStepper.action = #selector(changed)

        let fixedItems: [(String, WritableKeyPath<Settings, Bool>)] = [
            ("Automatic vowel forming", \.fixedAutoVowel),
            ("Automatic chandrabindu", \.fixedAutoChandra),
            ("Traditional kar joining", \.fixedTraditionalKar),
            ("Old-style reph", \.fixedOldReph),
            ("Bengali digits on the numpad", \.fixedNumpad),
            ("Old kar order", \.fixedOldKarOrder),
        ]
        fixedChecks = fixedItems.map { title, path in
            let b = NSButton(checkboxWithTitle: title, target: self, action: #selector(changed))
            b.controlSize = .small
            b.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            return (b, path)
        }
        fixedGroup = stack(fixedChecks.map(\.0), spacing: 4)
        fixedGroup.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)

        let fontControl = NSStackView(views: [fontLabel, fontStepper])
        fontControl.spacing = 6

        let buttons = NSStackView(views: [
            smallButton("Auto-Correct…", #selector(openAutoCorrect)),
            smallButton("Forget Learned…", #selector(forgetLearned)),
            smallButton("Restore Defaults", #selector(restoreDefaults)),
        ])
        buttons.spacing = 8

        let links = NSStackView(views: [
            linkButton("Project on GitHub", "https://github.com/Shamsulhaq/avro-next"),
            linkButton("Report a Problem", "https://github.com/Shamsulhaq/avro-next/issues/new/choose"),
            linkButton("Contribute", "https://github.com/Shamsulhaq/avro-next/blob/main/CONTRIBUTING.md"),
        ])
        links.spacing = 14

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let about = NSTextField(labelWithString: "Avro Next \(version) by Shamsul Haq Bhuyan  ·  Engine: OpenBangla riti (MPL-2.0)")
        about.font = .systemFont(ofSize: 11)
        about.textColor = .secondaryLabelColor

        let typing = stack([
            header("Typing"),
            formRow("Layout", layoutPopup),
            dictionaryCheck, englishCheck, quotesCheck, fixedGroup,
        ], spacing: 8)
        let candidates = stack([
            header("Candidate window"),
            formRow("Style", stylePopup),
            formRow("Font size", fontControl),
        ], spacing: 8)
        let data = stack([header("Data"), buttons], spacing: 8)

        [updateCheck, prereleaseCheck].forEach { $0.target = self; $0.action = #selector(changed) }
        updateStatus.font = .systemFont(ofSize: 11)
        updateStatus.textColor = .secondaryLabelColor
        updateStatus.lineBreakMode = .byTruncatingTail
        updateStatus.widthAnchor.constraint(lessThanOrEqualToConstant: Self.contentWidth - 130).isActive = true
        let checkNow = NSStackView(views: [smallButton("Check Now", #selector(checkUpdatesNow)), updateStatus])
        checkNow.spacing = 8
        let updates = stack([header("Updates"), updateCheck, prereleaseCheck, checkNow], spacing: 8)
        updateObserver = NotificationCenter.default.addObserver(
            forName: .avroUpdateStatusChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateStatus.stringValue = UpdateManager.shared.status }
        }

        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
        let footer = stack([links, about], spacing: 6)
        [typing, candidates, updates, data, footer].forEach(root.addArrangedSubview)
        root.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(root)
        window.contentView = content
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.widthAnchor.constraint(equalToConstant: Self.contentWidth + 40),
        ])
    }

    private func stack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = spacing
        return s
    }

    private func smallButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.controlSize = .small
        b.bezelStyle = .rounded
        return b
    }

    /// A borderless, link-coloured button that opens a URL in the browser.
    private func linkButton(_ title: String, _ url: String) -> NSButton {
        let b = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        b.isBordered = false
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.linkColor, .font: NSFont.systemFont(ofSize: 12)])
        b.toolTip = url
        b.identifier = NSUserInterfaceItemIdentifier(url)
        return b
    }

    @objc private func openLink(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }

    private func header(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .boldSystemFont(ofSize: 13)
        return l
    }

    private func formRow(_ title: String, _ control: NSView) -> NSStackView {
        let l = NSTextField(labelWithString: title)
        l.alignment = .right
        l.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let s = NSStackView(views: [l, control])
        s.spacing = 10
        s.alignment = .firstBaseline
        return s
    }

    // MARK: - State

    /// Pushes `settings` into the controls and resizes the window to fit.
    private func reflect(animated: Bool) {
        layoutPopup.selectItem(at: LayoutChoice.allCases.firstIndex(of: settings.layout) ?? 0)
        stylePopup.selectItem(at: CandidateStyle.allCases.firstIndex(of: settings.candidateStyle) ?? 0)
        dictionaryCheck.state = settings.dictionarySuggestions ? .on : .off
        englishCheck.state = settings.includeEnglish ? .on : .off
        quotesCheck.state = settings.smartQuotes ? .on : .off
        for (button, path) in fixedChecks { button.state = settings[keyPath: path] ? .on : .off }
        fixedGroup.isHidden = settings.layout != .probhat
        englishCheck.isHidden = settings.layout != .avroPhonetic
        fontStepper.doubleValue = settings.candidateFontSize
        fontLabel.stringValue = "\(Int(settings.candidateFontSize)) pt"
        updateCheck.state = settings.checkForUpdates ? .on : .off
        prereleaseCheck.state = settings.includePrereleases ? .on : .off
        updateStatus.stringValue = UpdateManager.shared.status
        fitWindow(animated: animated)
    }

    private func fitWindow(animated: Bool) {
        guard let window else { return }
        root.layoutSubtreeIfNeeded()
        let size = NSSize(width: Self.contentWidth + 40, height: root.fittingSize.height)
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin.x = window.frame.origin.x
        frame.origin.y = window.frame.maxY - frame.height          // keep the title bar in place
        window.setFrame(frame, display: true, animate: animated && window.isVisible)
    }

    @objc private func changed() {
        settings.layout = LayoutChoice.allCases[max(layoutPopup.indexOfSelectedItem, 0)]
        settings.candidateStyle = CandidateStyle.allCases[max(stylePopup.indexOfSelectedItem, 0)]
        settings.dictionarySuggestions = dictionaryCheck.state == .on
        settings.includeEnglish = englishCheck.state == .on
        settings.smartQuotes = quotesCheck.state == .on
        settings.candidateFontSize = fontStepper.doubleValue
        for (button, path) in fixedChecks { settings[keyPath: path] = button.state == .on }
        settings.checkForUpdates = updateCheck.state == .on
        settings.includePrereleases = prereleaseCheck.state == .on
        settings.save()
        reflect(animated: true)
    }

    @objc private func checkUpdatesNow() {
        UpdateManager.shared.check(userInitiated: true)
    }

    @objc private func restoreDefaults() {
        settings = Settings()
        settings.save()
        reflect(animated: true)
    }

    @objc private func forgetLearned() {
        let alert = NSAlert()
        alert.messageText = "Forget learned words?"
        alert.informativeText = "This clears the candidate choices Avro Next has remembered. Your auto-correct entries are kept."
        alert.addButton(withTitle: "Forget")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        try? FileManager.default.removeItem(at: userDir.appendingPathComponent("phonetic-candidate-selection.json"))
        // Rebuild the engine so in-memory choices are dropped too.
        NotificationCenter.default.post(name: Settings.didChange, object: "reload")
    }

    @objc private func openAutoCorrect() {
        let file = userDir.appendingPathComponent("autocorrect.json")
        if !FileManager.default.fileExists(atPath: file.path) {
            try? "{\n}\n".write(to: file, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(file)
    }
}
