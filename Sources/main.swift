import Cocoa
import InputMethodKit

// The IMKServer must stay alive for the whole process lifetime.
let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "AvroNext_Connection"
let imkServer = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
SharedEngine.start()

// Opening the app directly (Finder/Spotlight) shows the settings, so users can find them.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.present()
        return true
    }
}
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
