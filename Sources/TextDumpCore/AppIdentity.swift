import Foundation

public enum AppIdentity {
    public static let displayName = "Jotwisp"

    // These are persistence identities, not branding. Keep them stable across renames.
    public static let bundleIdentifier = "app.textdump.mac"
    public static let libraryDirectoryName = "Text Dump"
    public static let windowFrameName = "TextDumpWorkspace"

    public static func libraryURL(in applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent(libraryDirectoryName, isDirectory: true)
    }
}
