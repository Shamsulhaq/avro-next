import Foundation

// Headless check of the riti wrapper: types Avro Phonetic and asserts the output.
// Usage: engine_test <databaseDir>
let args = CommandLine.arguments
guard args.count == 2 else { print("usage: engine_test <databaseDir>"); exit(2) }

let tmp = NSTemporaryDirectory() + "avronext-test-\(getpid())"
try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(atPath: tmp) }

guard let engine = AvroEngine(databaseDir: args[1], userDir: tmp) else {
    print("FAIL: engine init"); exit(1)
}

var failures = 0
func check(_ typed: String, expect: String, anywhere: Bool = false) {
    var last: RitiSuggestion?
    for ch in typed {
        guard let code = KeyMap.code(for: ch) else { print("FAIL: unmapped \(ch)"); failures += 1; return }
        last = engine.press(code, shift: ch.isUppercase, selection: 0)
    }
    let items = last?.items ?? []
    let top = items.indices.contains(last?.previouslySelectedIndex ?? 0) ? items[last?.previouslySelectedIndex ?? 0] : ""
    engine.commit(index: last?.previouslySelectedIndex ?? 0)
    if top == expect || (anywhere && items.contains(expect)) { print("ok   \(typed) -> \(top)  (\(items.count) candidates)") }
    else { print("FAIL \(typed): got '\(top)' expected '\(expect)' all=\(items)"); failures += 1 }
}

check("ami", expect: "আমি")
check("bangla", expect: "বাংলা")
check("amar", expect: "আমার")
check("tumi", expect: "তুমি")
check("bhalobasi", expect: "ভালোবাসি", anywhere: true)

// Backspace shrinks the composition.
_ = engine.press(KeyMap.code(for: "k")!, shift: false, selection: 0)
_ = engine.press(KeyMap.code(for: "h")!, shift: false, selection: 0)
let afterBS = engine.backspace(whole: false)?.items.first ?? ""
if afterBS == "ক" { print("ok   backspace -> ক") } else { print("FAIL backspace: '\(afterBS)'"); failures += 1 }
engine.finish()
if engine.hasSession { print("FAIL: session still open"); failures += 1 }

// Learning: picking a non-default candidate makes it the default next time,
// in this session and after a restart (new engine reading the same user dir).
func typeWord(_ e: AvroEngine, _ text: String) -> RitiSuggestion? {
    // Pass the current selection on each key, exactly like AvroController does.
    var last: RitiSuggestion?
    var selected = 0
    for ch in text {
        last = e.press(KeyMap.code(for: ch)!, shift: ch.isUppercase, selection: selected)
        selected = last?.previouslySelectedIndex ?? 0
    }
    return last
}
func defaultPick(_ e: AvroEngine, _ text: String) -> String {
    guard let s = typeWord(e, text) else { return "" }
    let items = s.items, i = s.previouslySelectedIndex
    e.commit(index: i)
    return items.indices.contains(i) ? items[i] : ""
}
do {
    let target = "ভালোবাসি"
    let s = typeWord(engine, "bhalobasi")!
    let items = s.items
    if let idx = items.firstIndex(of: target), idx != s.previouslySelectedIndex {
        engine.commit(index: idx)                       // user picks the second candidate
        let again = defaultPick(engine, "bhalobasi")
        if again == target { print("ok   learned in session -> \(again)") }
        else { print("FAIL learned in session: '\(again)'"); failures += 1 }

        let restarted = AvroEngine(databaseDir: args[1], userDir: tmp)!
        let after = defaultPick(restarted, "bhalobasi")
        if after == target { print("ok   learned after restart -> \(after)") }
        else { print("FAIL learned after restart: '\(after)'"); failures += 1 }

        let withComma = defaultPick(restarted, "bhalobasi,")
        if withComma.hasPrefix(target) { print("ok   learned with punctuation -> \(withComma)") }
        else { print("FAIL learned with punctuation: '\(withComma)'"); failures += 1 }
    } else {
        print("FAIL learning setup: candidates \(items)"); failures += 1
        engine.finish()
    }
}

// Regression: the user's real flow, driven through CandidateState like AvroController.
// Before the fix, the candidate window reset the highlight to row 1 on reload, so
// committing the second time saved the wrong word over the learned one.
do {
    let dir = tmp + "/flow"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let e = AvroEngine(databaseDir: args[1], userDir: dir)!
    var state = CandidateState()

    func type(_ word: String) {
        var last: RitiSuggestion?
        for ch in word {
            last = e.press(KeyMap.code(for: ch)!, shift: false, selection: state.selected)
            if let last { state.load(last.items, preferred: last.previouslySelectedIndex) }
        }
    }
    func commit() -> String {
        let text = state.current ?? ""
        e.commit(index: state.selected)
        state.clear()
        return text
    }

    type("valobasi")                       // default: ভালবাসি
    state.move(by: 1)                      // Down arrow -> ভালোবাসি
    let first = commit()
    type("valobasi")                       // should now default to the learned word
    let second = commit()                  // plain Space, no arrows
    type("valobasi")
    let third = commit()
    let saved = (try? String(contentsOfFile: dir + "/phonetic-candidate-selection.json", encoding: .utf8)) ?? ""

    if first == "ভালোবাসি", second == "ভালোবাসি", third == "ভালোবাসি", saved.contains("ভালোবাসি") {
        print("ok   learned choice sticks across repeated commits")
    } else {
        print("FAIL learned flow: \(first) / \(second) / \(third), saved=\(saved)"); failures += 1
    }

    var s = CandidateState()
    s.load(["a", "b", "c"], preferred: 5)
    let clamped = s.current == "c"
    s.move(by: -10)
    let top = s.current == "a"
    let notFound = !s.select(text: "z") && s.current == "a"
    if clamped && top && notFound { print("ok   candidate state clamps and selects") }
    else { print("FAIL candidate state"); failures += 1 }
}

// Live settings: switch layout without recreating the engine.
func typed(_ text: String) -> String {
    var last: RitiSuggestion?
    for ch in text { last = engine.press(KeyMap.code(for: ch)!, shift: ch.isUppercase, selection: 0) }
    let top = last?.items.first ?? ""
    engine.commit(index: 0)
    return top
}
var s = Settings(); s.layout = .khipro; engine.apply(s)
let kh = typed("amar")
if kh == "আমার" { print("ok   khipro amar -> আমার") } else { print("FAIL khipro: '\(kh)'"); failures += 1 }
s.layout = .probhat; engine.apply(s)
let pb = typed("hl")
if !pb.isEmpty { print("ok   probhat hl -> \(pb)") } else { print("FAIL probhat empty"); failures += 1 }
s.layout = .avroPhonetic; s.dictionarySuggestions = false; engine.apply(s)
let nd = engine.press(KeyMap.code(for: "a")!, shift: false, selection: 0)
if nd?.isLonely == true { print("ok   dictionary off -> single suggestion") } else { print("FAIL dictionary off"); failures += 1 }
engine.finish()

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
