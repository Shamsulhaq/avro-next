import Foundation

enum LayoutChoice: String, CaseIterable {
    case avroPhonetic = "avro_phonetic"
    case khipro
    case probhat

    var title: String {
        switch self {
        case .avroPhonetic: return "Avro Phonetic"
        case .khipro: return "Khipro"
        case .probhat: return "Probhat (Fixed)"
        }
    }
}

enum CandidateStyle: String, CaseIterable {
    // A saved "grid" from older versions falls back to the default (row) on load.
    case row, list

    var title: String {
        switch self {
        case .row: return "Compact row"
        case .list: return "List"
        }
    }
}

/// User preferences. Stored in UserDefaults; applied live by the engine and controllers.
struct Settings: Equatable {
    var layout: LayoutChoice = .avroPhonetic
    var dictionarySuggestions = true
    var includeEnglish = false
    var smartQuotes = false

    // Probhat (fixed layout) options, same defaults as riti.
    var fixedAutoVowel = true
    var fixedAutoChandra = true
    var fixedTraditionalKar = true
    var fixedOldReph = true
    var fixedNumpad = true
    var fixedOldKarOrder = false

    var checkForUpdates = true
    // Releases are pre-releases until Developer ID signing is set up, so include them by default.
    var includePrereleases = true

    var candidateStyle: CandidateStyle = .row
    var candidateFontSize = 13.0

    static let didChange = Notification.Name("AvroSettingsDidChange")
    private static let key = "settings.v1"

    static func load(_ defaults: UserDefaults = .standard) -> Settings {
        var s = Settings()
        guard let d = defaults.dictionary(forKey: key) else { return s }
        if let v = d["layout"] as? String, let l = LayoutChoice(rawValue: v) { s.layout = l }
        if let v = d["candidateStyle"] as? String, let c = CandidateStyle(rawValue: v) { s.candidateStyle = c }
        if let v = d["dictionarySuggestions"] as? Bool { s.dictionarySuggestions = v }
        if let v = d["includeEnglish"] as? Bool { s.includeEnglish = v }
        if let v = d["smartQuotes"] as? Bool { s.smartQuotes = v }
        if let v = d["fixedAutoVowel"] as? Bool { s.fixedAutoVowel = v }
        if let v = d["fixedAutoChandra"] as? Bool { s.fixedAutoChandra = v }
        if let v = d["fixedTraditionalKar"] as? Bool { s.fixedTraditionalKar = v }
        if let v = d["fixedOldReph"] as? Bool { s.fixedOldReph = v }
        if let v = d["fixedNumpad"] as? Bool { s.fixedNumpad = v }
        if let v = d["fixedOldKarOrder"] as? Bool { s.fixedOldKarOrder = v }
        if let v = d["checkForUpdates"] as? Bool { s.checkForUpdates = v }
        if let v = d["includePrereleases"] as? Bool { s.includePrereleases = v }
        if let v = d["candidateFontSize"] as? Double { s.candidateFontSize = min(max(v, 11), 32) }
        return s
    }

    func save(_ defaults: UserDefaults = .standard) {
        defaults.set([
            "layout": layout.rawValue,
            "candidateStyle": candidateStyle.rawValue,
            "dictionarySuggestions": dictionarySuggestions,
            "includeEnglish": includeEnglish,
            "smartQuotes": smartQuotes,
            "fixedAutoVowel": fixedAutoVowel,
            "fixedAutoChandra": fixedAutoChandra,
            "fixedTraditionalKar": fixedTraditionalKar,
            "fixedOldReph": fixedOldReph,
            "fixedNumpad": fixedNumpad,
            "fixedOldKarOrder": fixedOldKarOrder,
            "candidateFontSize": candidateFontSize,
            "checkForUpdates": checkForUpdates,
            "includePrereleases": includePrereleases,
        ] as [String: Any], forKey: Settings.key)
        NotificationCenter.default.post(name: Settings.didChange, object: nil)
    }
}
