import XCTest
import AppKit
import TextDumpCore
@testable import TextDump

final class AppStoreTests: XCTestCase {
    @MainActor func testClipboardCaptureCreatesAndSavesSeparateDraftWithoutChangingClipboard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpClipboard-\(UUID())")
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally(); try? FileManager.default.removeItem(at: root) }
        let store = AppStore(root: root)
        let originalID = try XCTUnwrap(store.selectedID)
        store.updateText("Keep this draft", id: originalID)
        store.query = "does not match"
        store.showingTrash = true
        let copiedText = "Clipboard note\n\n| café | 🦊 |\r\n\tKeep spacing.\n"
        clipboard.clearContents()
        XCTAssertTrue(clipboard.setString(copiedText, forType: .string))
        let clipboardVersion = clipboard.changeCount

        try store.newDraftFromClipboard(clipboard)

        XCTAssertEqual(store.drafts.count, 2)
        XCTAssertNotEqual(store.selectedID, originalID)
        XCTAssertEqual(store.selectedDraft?.text, copiedText)
        XCTAssertEqual(store.selectedDraft?.title, "Clipboard note")
        XCTAssertEqual(store.selectedDraft?.metadata.cursor, (copiedText as NSString).length)
        XCTAssertEqual(store.drafts.first(where: { $0.id == originalID })?.text, "Keep this draft")
        XCTAssertEqual(store.query, "")
        XCTAssertFalse(store.showingTrash)
        XCTAssertEqual(clipboard.changeCount, clipboardVersion)
        XCTAssertEqual(clipboard.string(forType: .string), copiedText)
        XCTAssertTrue(store.flush())
        XCTAssertEqual(try Repository(root: root).load().drafts.first?.text, copiedText)
    }

    @MainActor func testEmptyOrNonTextClipboardDoesNotCreateDraft() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpClipboard-\(UUID())")
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally(); try? FileManager.default.removeItem(at: root) }
        let store = AppStore(root: root)
        let selected = store.selectedID
        XCTAssertThrowsError(try store.newDraftFromClipboard(clipboard))
        clipboard.setString("", forType: .string)
        XCTAssertThrowsError(try store.newDraftFromClipboard(clipboard))
        clipboard.clearContents()
        clipboard.setData(Data([0, 1, 2]), forType: .png)
        XCTAssertThrowsError(try store.newDraftFromClipboard(clipboard))
        XCTAssertEqual(store.drafts.count, 1)
        XCTAssertEqual(store.selectedID, selected)
        XCTAssertTrue(store.flush())
    }

    @MainActor func testAutosaveWithoutExplicitSaveAndLatestEditWins() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpStore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStore(root: root)
        let id = try XCTUnwrap(store.selectedID)
        store.updateText("first revision", id: id)
        store.saveNow()
        store.updateText("latest revision 🦊", id: id)
        try await Task.sleep(nanoseconds: 850_000_000)
        XCTAssertEqual(try Repository(root: root).load().drafts.first?.text, "latest revision 🦊")
        XCTAssertEqual(store.saveState, "Saved locally")
        XCTAssertTrue(store.flush())
    }

    @MainActor func testSwitchAndFlushRestoresSelectionAndDrafts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpStore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStore(root: root)
        let first = try XCTUnwrap(store.selectedID)
        store.updateText("first draft", id: first)
        store.newDraft()
        let second = try XCTUnwrap(store.selectedID)
        store.updateText("second draft", id: second)
        store.select(first)
        store.updatePosition(id: first, range: NSRange(location: 3, length: 2), origin: NSPoint(x: 0, y: 100))
        XCTAssertTrue(store.flush())
        let reopened = AppStore(root: root)
        XCTAssertEqual(reopened.selectedID, first)
        XCTAssertEqual(reopened.drafts.count, 2)
        XCTAssertEqual(reopened.selectedDraft?.metadata.cursor, 3)
        XCTAssertEqual(reopened.selectedDraft?.metadata.selectionLength, 2)
        XCTAssertEqual(reopened.selectedDraft?.metadata.scrollY, 100)
        XCTAssertTrue(reopened.flush())
    }

    @MainActor func testSearchDiscardsOldQueryAndTrashUpdatesResults() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpStore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStore(root: root)
        let first = try XCTUnwrap(store.selectedID)
        store.updateText("alpha", id: first)
        store.newDraft()
        let second = try XCTUnwrap(store.selectedID)
        store.updateText("beta", id: second)
        store.query = "alpha"
        store.query = "beta"
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(store.results.map(\.id), [second])
        store.trash(second)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertTrue(store.results.isEmpty)
        store.restore(second)
        XCTAssertEqual(store.selectedID, second)
        XCTAssertFalse(store.showingTrash)
        XCTAssertTrue(store.flush())
    }

    @MainActor func testSaveFailureRetainsMemoryAndRetryRecovers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpStore-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStore(root: root)
        let id = try XCTUnwrap(store.selectedID)
        store.updateText("saved version", id: id)
        XCTAssertTrue(store.flush())
        let original = root.appendingPathComponent("\(id).txt")
        let backup = root.appendingPathComponent("backup.txt")
        try FileManager.default.moveItem(at: original, to: backup)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
        store.updateText("unsaved version", id: id)
        XCTAssertFalse(store.flush())
        XCTAssertEqual(store.selectedDraft?.text, "unsaved version")
        XCTAssertNotNil(store.errorMessage)
        try FileManager.default.removeItem(at: original)
        try FileManager.default.moveItem(at: backup, to: original)
        store.retrySave()
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(try Repository(root: root).load().drafts.first?.text, "unsaved version")
        XCTAssertTrue(store.flush())
    }
}
