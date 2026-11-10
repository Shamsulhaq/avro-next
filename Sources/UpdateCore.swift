import CryptoKit
import Foundation

/// The `update.json` file attached to every GitHub Release by the release workflow.
struct UpdateInfo: Codable, Equatable {
    let version: String
    let prerelease: Bool
    let dmgURL: URL
    let sha256: String
    let size: Int
    let notesURL: URL

    enum CodingKeys: String, CodingKey {
        case version, prerelease, sha256, size
        case dmgURL = "dmg_url"
        case notesURL = "notes_url"
    }
}

enum UpdateError: LocalizedError {
    case badResponse(Int)
    case untrustedURL
    case checksumMismatch
    case mountFailed
    case installerMissing
    case badSignature

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "GitHub answered with status \(code)."
        case .untrustedURL: return "The update isn't hosted in the Avro Next GitHub repository."
        case .checksumMismatch: return "The downloaded file is damaged or was changed (checksum mismatch)."
        case .mountFailed: return "The update disk image couldn't be opened."
        case .installerMissing: return "The update disk image doesn't contain the installer."
        case .badSignature: return "The installer isn't signed by the same developer as this copy of Avro Next."
        }
    }
}

/// Network-free update logic, kept separate so it can be tested headless.
///
/// Releases are discovered through the public `releases.atom` feed and each
/// release's `update.json` download. Neither counts against GitHub's
/// 60-requests-per-hour limit for unauthenticated API calls.
enum UpdateCore {
    /// Compares dotted numeric versions ("0.1.10" > "0.1.9"). A leading "v" is ignored.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            v.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Release tags from the feed, newest first, without duplicates.
    static func releaseTags(fromAtom data: Data, repo: String) -> [String] {
        guard let text = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(
                  pattern: "/" + NSRegularExpression.escapedPattern(for: repo) + "/releases/tag/([A-Za-z0-9._-]+)")
        else { return [] }
        var seen = Set<String>(), tags: [String] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let tag = String(text[r])
            if seen.insert(tag).inserted { tags.append(tag) }
        }
        return tags
    }

    static func feedURL(repo: String) -> URL {
        URL(string: "https://github.com/\(repo)/releases.atom")!
    }

    static func manifestURL(repo: String, tag: String) -> URL {
        URL(string: "https://github.com/\(repo)/releases/download/\(tag)/update.json")!
    }

    /// Only HTTPS downloads from this repository's releases are accepted.
    static func isTrustedDownload(_ url: URL, repo: String) -> Bool {
        url.scheme == "https" && url.host == "github.com"
            && url.path.hasPrefix("/\(repo)/releases/download/")
    }

    static func verify(fileAt url: URL, sha256: String, size: Int) -> Bool {
        guard let data = try? Data(contentsOf: url), data.count == size else { return false }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return digest == sha256.lowercased()
    }

    /// Returns the newest acceptable release if it is newer than `current`.
    static func findUpdate(repo: String, current: String, includePrereleases: Bool,
                           session: URLSession = .shared) async throws -> UpdateInfo? {
        let (feed, response) = try await session.data(from: feedURL(repo: repo))
        try check(response)
        for tag in releaseTags(fromAtom: feed, repo: repo).prefix(5) {
            let (data, response) = try await session.data(from: manifestURL(repo: repo, tag: tag))
            if (response as? HTTPURLResponse)?.statusCode == 404 { continue }   // release without a manifest
            try check(response)
            let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
            guard isTrustedDownload(info.dmgURL, repo: repo) else { throw UpdateError.untrustedURL }
            if info.prerelease && !includePrereleases { continue }
            return isNewer(info.version, than: current) ? info : nil
        }
        return nil
    }

    private static func check(_ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw UpdateError.badResponse(code) }
    }
}
