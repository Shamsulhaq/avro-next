import Carbon
import Foundation

// Dev helper: reports how macOS's Text Input Sources (TIS) see Avro Next.
//   tis_check            status
//   tis_check enable     enable it (needs a normal, unsandboxed shell to persist)
//   tis_check select     switch to it
let bundleID = "org.avronext.inputmethod.AvroNext"

func str(_ s: TISInputSource, _ k: CFString) -> String {
    guard let p = TISGetInputSourceProperty(s, k) else { return "nil" }
    return "\(Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue())".replacingOccurrences(of: "\n", with: "")
}

func flag(_ s: TISInputSource, _ k: CFString) -> Bool {
    guard let p = TISGetInputSourceProperty(s, k) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(p).takeUnretainedValue())
}

let sources = TISCreateInputSourceList([kTISPropertyBundleID as String: bundleID] as CFDictionary, true)?
    .takeRetainedValue() as? [TISInputSource] ?? []

if sources.isEmpty { print("NOT REGISTERED with Text Input Sources") }

switch CommandLine.arguments.dropFirst().first {
case "enable": sources.forEach { print("enable:", TISEnableInputSource($0)) }
case "select": sources.forEach { print("select:", TISSelectInputSource($0)) }
default: break
}

for s in sources {
    print(str(s, kTISPropertyInputSourceID),
          "| name:", str(s, kTISPropertyLocalizedName),
          "| langs:", str(s, kTISPropertyInputSourceLanguages),
          "| enabled:", flag(s, kTISPropertyInputSourceIsEnabled),
          "| selectable:", flag(s, kTISPropertyInputSourceIsSelectCapable),
          "| selected:", flag(s, kTISPropertyInputSourceIsSelected))
}
