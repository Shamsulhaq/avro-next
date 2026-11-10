import Cocoa
import InputMethodKit

/// One engine per process; riti keeps the composition buffer inside it.
/// Rebuilt when settings change or learned words are cleared.
enum SharedEngine {
    private(set) static var engine: AvroEngine? = make(Settings.load())
    private static var observer: NSObjectProtocol? = {
        NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { note in
            let settings = Settings.load()
            if (note.object as? String) == "reload" {
                engine = make(settings)           // drops in-memory learned selections
            } else {
                engine?.finish()
                engine?.apply(settings)
            }
        }
    }()

    static func start() { _ = engine; _ = observer }

    private static func make(_ settings: Settings) -> AvroEngine? {
        let fm = FileManager.default
        guard let resources = Bundle.main.resourcePath else { return nil }
        let userDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AvroNext", isDirectory: true)
        try? fm.createDirectory(at: userDir, withIntermediateDirectories: true)
        return AvroEngine(databaseDir: resources + "/data", userDir: userDir.path, settings: settings)
    }
}

@objc(AvroController)
final class AvroController: IMKInputController {
    private let notFound = NSRange(location: NSNotFound, length: NSNotFound)
    private let candidateWindow = CandidateWindow()
    private var settings = Settings.load()
    /// Source of truth for the candidates and the chosen one (see CandidateState).
    private var state = CandidateState()
    private var observer: NSObjectProtocol?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        configurePanel()
        // A click commits that candidate.
        candidateWindow.onClick = { [weak self] index in
            guard let self, self.state.select(index: index),
                  let engine = SharedEngine.engine, let client = self.client() else { return }
            self.commit(engine: engine, client: client)
        }
        observer = NotificationCenter.default.addObserver(forName: Settings.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.settingsChanged()
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    // MARK: - Settings

    private func settingsChanged() {
        settings = Settings.load()
        if !state.isEmpty, let client = client() { reset(client: client) }   // engine already finished its session
        configurePanel()
    }

    private func configurePanel() {
        candidateWindow.vertical = settings.candidateStyle == .list
        candidateWindow.fontSize = CGFloat(settings.candidateFontSize)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let prefs = NSMenuItem(title: "Avro Next Settings…", action: #selector(showSettings(_:)), keyEquivalent: "")
        prefs.target = self
        menu.addItem(prefs)
        return menu
    }

    @objc private func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.present()
    }

    // MARK: - Key handling

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, let engine = SharedEngine.engine,
              let client = sender as? IMKTextInput else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let composing = engine.hasSession

        // Backspace (Ctrl/Option+Backspace deletes the whole composition).
        if event.keyCode == 51 {
            guard composing else { return false }
            let whole = flags.contains(.control) || flags.contains(.option)
            update(engine.backspace(whole: whole), engine: engine, client: client)
            return true
        }

        // Shortcuts and Option-combos are not ours: finish the word and pass through.
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            if composing { commit(engine: engine, client: client) }
            return false
        }

        switch event.keyCode {
        case 53 where composing:                       // Escape
            engine.finish()
            reset(client: client)
            return true
        case 49 where composing:                       // Space
            commit(engine: engine, client: client)
            client.insertText(" ", replacementRange: notFound)
            return true
        case 36, 76, 48:                               // Return, Enter, Tab
            if composing { commit(engine: engine, client: client) }
            return false
        // Candidate navigation is handled here, not by the candidate window, so the
        // chosen index can't drift from what the window happens to highlight.
        case 125, 126, 116, 121:                       // Down, Up, PageDown, PageUp
            guard composing, state.items.count > 1 else { return false }
            let page = 9
            let delta = [125: 1, 126: -1, 121: page, 116: -page][Int(event.keyCode)] ?? 0
            moveSelection(by: delta, client: client)
            return true
        case 123, 124:                                 // Left, Right
            if composing, state.items.count > 1, settings.candidateStyle != .list {
                moveSelection(by: event.keyCode == 124 ? 1 : -1, client: client)
                return true
            }
            if composing { commit(engine: engine, client: client) }
            return false
        case 115, 119:                                 // Home, End
            if composing { commit(engine: engine, client: client) }
            return false
        default:
            break
        }

        guard let ch = event.charactersIgnoringModifiers?.first,
              let code = KeyMap.code(for: ch) else {
            if composing { commit(engine: engine, client: client) }
            return false
        }

        let suggestion = engine.press(code, shift: flags.contains(.shift), selection: state.selected)
        // Layouts such as Probhat ignore some keys; let those through untouched.
        if !engine.hasSession && (suggestion?.isEmpty ?? true) { return false }
        update(suggestion, engine: engine, client: client)
        return true
    }

    // MARK: - Composition state

    private func update(_ suggestion: RitiSuggestion?, engine: AvroEngine, client: IMKTextInput) {
        guard let suggestion, !suggestion.isEmpty else {
            reset(client: client)
            return
        }
        // The engine's preferred index already includes learned choices.
        state.load(suggestion.items, preferred: suggestion.previouslySelectedIndex)
        showMarked(client: client)

        if state.items.count > 1 {
            candidateWindow.show(state.items, selected: state.selected, anchor: caretRect(client: client))
        } else {
            candidateWindow.hide()
        }
    }

    private func moveSelection(by delta: Int, client: IMKTextInput) {
        guard state.move(by: delta) else { return }
        showMarked(client: client)
        candidateWindow.highlight(state.selected)
    }

    /// Screen rect of the line holding the composition, used to place the bar.
    private func caretRect(client: IMKTextInput) -> NSRect {
        var rect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        if rect == .zero { rect = NSRect(origin: NSEvent.mouseLocation, size: NSSize(width: 1, height: 16)) }
        return rect
    }

    private func showMarked(client: IMKTextInput) {
        guard let text = state.current else { return }
        let attrs = mark(forStyle: kTSMHiliteConvertedText, at: notFound) as? [NSAttributedString.Key: Any] ?? [:]
        client.setMarkedText(NSAttributedString(string: text, attributes: attrs),
                             selectionRange: NSRange(location: text.utf16.count, length: 0),
                             replacementRange: notFound)
    }

    private func commit(engine: AvroEngine, client: IMKTextInput) {
        guard let text = state.current else { engine.finish(); reset(client: client); return }
        let index = state.selected
        reset(client: client)
        client.insertText(text, replacementRange: notFound)
        engine.commit(index: index)
    }

    private func reset(client: IMKTextInput) {
        state.clear()
        candidateWindow.hide()
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: notFound)
    }

    // MARK: - Lifecycle

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        settings = Settings.load()
        configurePanel()
    }

    override func commitComposition(_ sender: Any!) {
        guard let engine = SharedEngine.engine, engine.hasSession,
              let client = sender as? IMKTextInput else { return }
        commit(engine: engine, client: client)
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        candidateWindow.hide()
        super.deactivateServer(sender)
    }
}
