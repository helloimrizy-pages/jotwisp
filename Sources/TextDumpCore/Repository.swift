import Foundation

public struct LibrarySnapshot: Sendable {
    public var drafts: [Draft]
    public var session: Session
    public var warnings: [String]
}

public enum RepositoryError: LocalizedError {
    case unsupportedVersion, invalidText(String)
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This library was written by a newer version of \(AppIdentity.displayName)."
        case .invalidText(let name): return "\(name) could not be read as UTF-8 text."
        }
    }
}

/// Call from a single serial queue. Every individual file replacement is atomic.
public final class Repository: @unchecked Sendable {
    public let root: URL
    private let fm = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(root: URL) { self.root = root }

    public func load() throws -> LibrarySnapshot {
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        var drafts: [Draft] = []
        var warnings: [String] = []
        let files = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        for url in files where url.pathExtension == "json" && url.lastPathComponent != "session.json" {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            do {
                var metadata = try decoder.decode(DraftMetadata.self, from: Data(contentsOf: url))
                guard metadata.version == 1 else { throw RepositoryError.unsupportedVersion }
                guard metadata.id == id else { throw CocoaError(.fileReadCorruptFile) }
                if metadata.wrapPreferenceVersion == nil {
                    metadata.wraps = true
                    metadata.scrollX = 0
                    metadata.wrapPreferenceVersion = 1
                }
                let text = try String(contentsOf: textURL(id), encoding: .utf8)
                drafts.append(Draft(metadata: metadata, text: text))
            } catch { warnings.append("Could not load \(url.lastPathComponent): \(error.localizedDescription)") }
        }
        // Recover content if interruption happened between the first content write and metadata write.
        for url in files where url.pathExtension == "txt" {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !fm.fileExists(atPath: metadataURL(id).path) else { continue }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                drafts.append(Draft(id: id, text: text))
                warnings.append("Recovered a draft whose metadata was missing.")
            } catch { warnings.append("Could not recover \(url.lastPathComponent): \(error.localizedDescription)") }
        }
        var session = Session()
        let sessionURL = root.appendingPathComponent("session.json")
        if fm.fileExists(atPath: sessionURL.path) {
            do {
                session = try decoder.decode(Session.self, from: Data(contentsOf: sessionURL))
                guard session.version == 1 else { throw RepositoryError.unsupportedVersion }
            } catch { warnings.append("Could not restore the workspace: \(error.localizedDescription)"); session = Session() }
        }
        return LibrarySnapshot(drafts: drafts.sorted { $0.metadata.createdAt > $1.metadata.createdAt },
                               session: session, warnings: warnings)
    }

    public func save(_ draft: Draft, contentChanged: Bool = true) throws {
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        if contentChanged || !fm.fileExists(atPath: textURL(draft.id).path) {
            try Data(draft.text.utf8).write(to: textURL(draft.id), options: .atomic)
        }
        try encoder.encode(draft.metadata).write(to: metadataURL(draft.id), options: .atomic)
    }

    public func saveSession(_ session: Session) throws {
        try encoder.encode(session).write(to: root.appendingPathComponent("session.json"), options: .atomic)
    }

    public func permanentlyDelete(_ id: UUID) throws {
        // Remove content first, so interruption cannot recover a deliberately deleted draft.
        for url in [textURL(id), metadataURL(id)] where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    private func textURL(_ id: UUID) -> URL { root.appendingPathComponent("\(id.uuidString).txt") }
    private func metadataURL(_ id: UUID) -> URL { root.appendingPathComponent("\(id.uuidString).json") }
}
