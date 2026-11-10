import Foundation

/// A suggestion list returned by riti. Frees the underlying C object on deinit.
final class RitiSuggestion {
    private let ptr: OpaquePointer

    init(_ ptr: OpaquePointer) { self.ptr = ptr }
    deinit { riti_suggestion_free(ptr) }

    var isEmpty: Bool { riti_suggestion_is_empty(ptr) }
    var isLonely: Bool { riti_suggestion_is_lonely(ptr) }
    var previouslySelectedIndex: Int { Int(riti_suggestion_previously_selected_index(ptr)) }

    /// All candidate strings. A "lonely" suggestion yields exactly one entry.
    var items: [String] {
        if isEmpty { return [] }
        if isLonely { return [take(riti_suggestion_get_lonely_suggestion(ptr))] }
        let count = Int(riti_suggestion_get_length(ptr))
        return (0..<count).map { take(riti_suggestion_get_suggestion(ptr, UInt($0))) }
    }

    private func take(_ cString: UnsafeMutablePointer<CChar>?) -> String {
        guard let cString else { return "" }
        defer { riti_string_free(cString) }
        return String(cString: cString)
    }
}

/// Thin Swift wrapper over the riti C API.
final class AvroEngine {
    private var context: OpaquePointer?
    private let databaseDir: String
    private let userDir: String

    /// - Parameters:
    ///   - databaseDir: directory holding dictionary.json, suffix.json, autocorrect.json, Probhat.json
    ///   - userDir: writable directory for learned candidate selections and user auto-correct
    init?(databaseDir: String, userDir: String, settings: Settings = Settings()) {
        self.databaseDir = databaseDir
        self.userDir = userDir
        guard let cfg = makeConfig(settings) else { return nil }
        defer { riti_config_free(cfg) }
        context = riti_context_new_with_config(cfg)
        if context == nil { return nil }
    }

    deinit {
        if let context { riti_context_free(context) }
    }

    /// Builds a riti Config for the settings. Caller frees it.
    private func makeConfig(_ s: Settings) -> OpaquePointer? {
        guard let cfg = riti_config_new() else { return nil }
        let layoutArg = s.layout == .probhat ? databaseDir + "/Probhat.json" : s.layout.rawValue
        guard riti_config_set_database_dir(cfg, databaseDir),
              riti_config_set_user_dir(cfg, userDir),
              riti_config_set_layout_file(cfg, layoutArg) else {
            riti_config_free(cfg)
            return nil
        }
        riti_config_set_phonetic_suggestion(cfg, s.dictionarySuggestions)
        riti_config_set_fixed_suggestion(cfg, s.dictionarySuggestions)
        riti_config_set_suggestion_include_english(cfg, s.includeEnglish)
        riti_config_set_smart_quote(cfg, s.smartQuotes)
        riti_config_set_ansi_encoding(cfg, false)
        riti_config_set_fixed_auto_vowel(cfg, s.fixedAutoVowel)
        riti_config_set_fixed_auto_chandra(cfg, s.fixedAutoChandra)
        riti_config_set_fixed_traditional_kar(cfg, s.fixedTraditionalKar)
        riti_config_set_fixed_old_reph(cfg, s.fixedOldReph)
        riti_config_set_fixed_numpad(cfg, s.fixedNumpad)
        riti_config_set_fixed_old_kar_order(cfg, s.fixedOldKarOrder)
        return cfg
    }

    /// Applies changed settings. A layout change swaps the underlying method; any
    /// composition in progress should be finished by the caller first.
    func apply(_ settings: Settings) {
        guard let cfg = makeConfig(settings) else { return }
        defer { riti_config_free(cfg) }
        riti_context_update_engine(context, cfg)
    }

    var hasSession: Bool { riti_context_ongoing_input_session(context) }

    func press(_ keyCode: UInt16, shift: Bool, selection: Int) -> RitiSuggestion? {
        let mod: UInt8 = shift ? 1 : 0
        guard let s = riti_get_suggestion_for_key(context, keyCode, mod, UInt8(clamping: selection)) else { return nil }
        return RitiSuggestion(s)
    }

    func backspace(whole: Bool) -> RitiSuggestion? {
        guard let s = riti_context_backspace_event(context, whole) else { return nil }
        return RitiSuggestion(s)
    }

    func commit(index: Int) { riti_context_candidate_committed(context, UInt(index)) }
    func finish() { riti_context_finish_input_session(context) }
}
