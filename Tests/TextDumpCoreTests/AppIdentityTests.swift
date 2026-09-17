import XCTest
@testable import TextDumpCore

final class AppIdentityTests: XCTestCase {
    func testRebrandKeepsPersistentIdentities() {
        XCTAssertEqual(AppIdentity.displayName, "Jotwisp")
        XCTAssertEqual(AppIdentity.bundleIdentifier, "app.textdump.mac")
        XCTAssertEqual(AppIdentity.windowFrameName, "TextDumpWorkspace")
        let support = URL(fileURLWithPath: "/tmp/Example/Application Support", isDirectory: true)
        XCTAssertEqual(AppIdentity.libraryURL(in: support).lastPathComponent, "Text Dump")
        XCTAssertEqual(AppIdentity.libraryURL(in: support).deletingLastPathComponent(), support)
    }

    func testExistingLibraryIsReusedAfterRebrand() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("JotwispIdentity-\(UUID())")
        defer { try? FileManager.default.removeItem(at: support) }
        let legacy = Repository(root: support.appendingPathComponent("Text Dump", isDirectory: true))
        _ = try legacy.load()
        let draft = Draft(text: "Existing draft\nKeep my text 🦊")
        try legacy.save(draft)
        try legacy.saveSession(Session(selectedID: draft.id, sidebarWidth: 287))

        let renamed = try Repository(root: AppIdentity.libraryURL(in: support)).load()
        XCTAssertEqual(renamed.drafts.map(\.id), [draft.id])
        XCTAssertEqual(renamed.drafts.first?.text, draft.text)
        XCTAssertEqual(renamed.session.selectedID, draft.id)
        XCTAssertEqual(renamed.session.sidebarWidth, 287)
        XCTAssertFalse(FileManager.default.fileExists(atPath: support.appendingPathComponent("Jotwisp").path))
    }
}
