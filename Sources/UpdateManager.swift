import Cocoa
import Security
import UserNotifications

extension Notification.Name {
    static let avroUpdateStatusChanged = Notification.Name("AvroUpdateStatusChanged")
}

/// Checks GitHub for new releases, notifies the user, and installs on request.
///
/// Installing downloads the DMG, verifies its size and SHA-256 against the
/// release's update.json, and (for Developer ID builds) checks that the installer
/// is signed by the same team as this copy. Then it opens the normal macOS
/// Installer, which asks for the password as usual.
@MainActor
final class UpdateManager: NSObject {
    static let shared = UpdateManager()

    private(set) var available: UpdateInfo?
    private(set) var status = "Not checked yet"
    private(set) var busy = false

    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    private let repo = Bundle.main.infoDictionary?["AvroNextUpdateRepo"] as? String ?? "Shamsulhaq/avro-next"
    private let defaults = UserDefaults.standard
    private var timer: Timer?

    private static let lastCheckKey = "update.lastCheck"
    private static let skippedKey = "update.skippedVersion"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    func start() {
        UNUserNotificationCenter.current().delegate = self
        // First check shortly after login, then look again every few hours.
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.checkIfDue() }
        timer = Timer.scheduledTimer(withTimeInterval: 3 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in UpdateManager.shared.checkIfDue() }
        }
    }

    func checkIfDue() {
        guard Settings.load().checkForUpdates, !busy else { return }
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) >= Self.checkInterval { check(userInitiated: false) }
    }

    /// `userInitiated`: from the menu or Settings. Shows a result even when up to date.
    func check(userInitiated: Bool) {
        guard !busy else { return }
        busy = true
        setStatus("Checking…")
        let settings = Settings.load()
        Task {
            do {
                let info = try await UpdateCore.findUpdate(repo: repo, current: currentVersion,
                                                           includePrereleases: settings.includePrereleases)
                defaults.set(Date(), forKey: Self.lastCheckKey)
                busy = false
                handle(info, userInitiated: userInitiated)
            } catch {
                busy = false
                setStatus("Couldn't check for updates: \(error.localizedDescription)")
                if userInitiated { alert("Couldn't check for updates", error.localizedDescription) }
            }
        }
    }

    private func handle(_ info: UpdateInfo?, userInitiated: Bool) {
        guard let info else {
            available = nil
            setStatus("Avro Next \(currentVersion) is up to date.")
            if userInitiated { alert("You're up to date", "Avro Next \(currentVersion) is the newest version.") }
            return
        }
        available = info
        setStatus("Avro Next \(info.version) is available.")
        if userInitiated {
            promptInstall()
        } else if defaults.string(forKey: Self.skippedKey) != info.version {
            postNotification(for: info)
        }
    }

    // MARK: - Notification

    private func postNotification(for info: UpdateInfo) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }   // the menu still shows "Install Avro Next …"
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "Avro Next \(info.version) is available"
            content.body = "Click to install the update. You have \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")."
            center.add(UNNotificationRequest(identifier: "avro-update-\(info.version)", content: content, trigger: nil))
        }
    }

    // MARK: - Install

    func promptInstall() {
        guard let info = available, !busy else { return }
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Avro Next \(info.version) is available"
        a.informativeText = "You have \(currentVersion). The update downloads from GitHub and opens the installer."
            + (info.prerelease ? "\n\nThis is a pre-release (test) version." : "")
        a.addButton(withTitle: "Install")
        a.addButton(withTitle: "Later")
        a.addButton(withTitle: "Release Notes")
        a.addButton(withTitle: "Skip This Version")
        switch a.runModal() {
        case .alertFirstButtonReturn: Task { await install(info) }
        case .alertThirdButtonReturn: NSWorkspace.shared.open(info.notesURL)
        case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1):
            defaults.set(info.version, forKey: Self.skippedKey)
        default: break
        }
    }

    private func install(_ info: UpdateInfo) async {
        guard UpdateCore.isTrustedDownload(info.dmgURL, repo: repo) else {
            return fail(UpdateError.untrustedURL)
        }
        busy = true
        setStatus("Downloading Avro Next \(info.version)…")
        do {
            let (temp, response) = try await URLSession.shared.download(from: info.dmgURL)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { throw UpdateError.badResponse(code) }

            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let dmg = downloads.appendingPathComponent("Avro-Next-\(info.version).dmg")
            try? FileManager.default.removeItem(at: dmg)
            try FileManager.default.moveItem(at: temp, to: dmg)
            guard UpdateCore.verify(fileAt: dmg, sha256: info.sha256, size: info.size) else {
                try? FileManager.default.removeItem(at: dmg)
                throw UpdateError.checksumMismatch
            }

            let volume = try mount(dmg)
            let pkg = volume.appendingPathComponent("Install Avro Next.pkg")
            guard FileManager.default.fileExists(atPath: pkg.path) else { throw UpdateError.installerMissing }
            try checkInstallerSignature(pkg)

            busy = false
            setStatus("Installer opened for Avro Next \(info.version).")
            NSWorkspace.shared.open(pkg)
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        busy = false
        setStatus("Update failed: \(error.localizedDescription)")
        alert("The update couldn't be installed", error.localizedDescription)
    }

    /// Mounts the DMG read-only and returns its mount point.
    private func mount(_ dmg: URL) throws -> URL {
        let out = try run("/usr/bin/hdiutil", ["attach", "-readonly", "-plist", dmg.path])
        guard let plist = try? PropertyListSerialization.propertyList(from: out, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let point = entities.compactMap({ $0["mount-point"] as? String }).first
        else { throw UpdateError.mountFailed }
        return URL(fileURLWithPath: point)
    }

    /// For Developer ID builds, the installer must carry a Developer ID Installer
    /// signature from the same team. Self-built and ad-hoc copies skip this check;
    /// the checksum from the release still protects the download.
    private func checkInstallerSignature(_ pkg: URL) throws {
        guard let team = ownDeveloperIDTeam() else { return }
        let out = (try? run("/usr/sbin/pkgutil", ["--check-signature", pkg.path])) ?? Data()
        let text = String(data: out, encoding: .utf8) ?? ""
        guard text.contains("Developer ID Installer"), text.contains("(\(team))") else { throw UpdateError.badSignature }
    }

    private func ownDeveloperIDTeam() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any],
              let team = dict[kSecCodeInfoTeamIdentifier as String] as? String,
              let certs = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certs.first,
              let name = SecCertificateCopySubjectSummary(leaf) as String?,
              name.hasPrefix("Developer ID Application")
        else { return nil }
        return team
    }

    private func run(_ tool: String, _ args: [String]) throws -> Data {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError.mountFailed }
        return data
    }

    // MARK: - Helpers

    private func setStatus(_ text: String) {
        status = text
        NotificationCenter.default.post(name: .avroUpdateStatusChanged, object: nil)
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }
}

extension UpdateManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in UpdateManager.shared.promptInstall() }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
