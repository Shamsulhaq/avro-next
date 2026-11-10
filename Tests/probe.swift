import Foundation

// Dev probe: prints riti's candidates and default index for each word.
// Usage: probe <databaseDir> <userDir> word...
let a = CommandLine.arguments
let engine = AvroEngine(databaseDir: a[1], userDir: a[2])!
for word in a.dropFirst(3) {
    var last: RitiSuggestion?
    var sel = 0
    for ch in word {
        last = engine.press(KeyMap.code(for: ch)!, shift: ch.isUppercase, selection: sel)
        sel = last?.previouslySelectedIndex ?? 0
    }
    print(word, "default:", last?.previouslySelectedIndex ?? -1, last?.items ?? [])
    engine.finish()
}
