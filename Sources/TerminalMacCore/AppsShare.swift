import Foundation

/// The optional read-only "apps" share: one host folder the user drops builds into, mounted in
/// the guest as `/Volumes/My Shared Files/apps` next to `tools`.
///
/// Only a dedicated folder is attached. The home folder, any folder that contains it, and any
/// folder that looks like a project (a git work tree) are refused, so a typo in
/// `TERMINAL_MAC_APPS` cannot expose the user's files to the guest.
public enum AppsShare {
    public static let name = "apps"
    public static let environmentKey = "TERMINAL_MAC_APPS"
    public static let defaultRelativePath = "Developer/terminal-mac-apps"

    /// The folder to share, or nil when it does not exist (the share is then simply not attached).
    /// Throws when the folder exists but must not be shared.
    public static func resolve(environment: [String: String], home: URL) throws -> URL? {
        let raw = environment[environmentKey].flatMap { $0.isEmpty ? nil : $0 }
        let requested = raw.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? home.appendingPathComponent(defaultRelativePath)
        let url = requested.standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        guard isDirectory.boolValue else { throw Failure("The apps share must be a folder: \(url.path)") }
        let homePath = home.standardizedFileURL.resolvingSymlinksInPath().path
        let path = url.path
        if path == "/" || path == homePath || homePath.hasPrefix(path.hasSuffix("/") ? path : path + "/") {
            throw Failure("Refusing to share \(path) with the guest: it is or contains your home folder. Use a dedicated folder such as ~/\(defaultRelativePath).")
        }
        if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
            throw Failure("Refusing to share \(path) with the guest: it is a project folder (git work tree). Copy builds into a dedicated folder such as ~/\(defaultRelativePath).")
        }
        return url
    }
}
