import XCTest
@testable import TextDumpCore

final class CoreTests: XCTestCase {
    var root: URL!
    var repository: Repository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TextDumpTests-\(UUID())")
        repository = Repository(root: root)
        _ = try repository.load()
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    func testDraftRoundTripPreservesTextAndWorkspace() throws {
        var draft = Draft(text: "\n| Name  | Value |\r\n| ----- | ----- |\r\n| café  | 🦊    |\r\n\tlet x = 1\n", language: .markdown)
        draft.metadata.cursor = 18
        draft.metadata.selectionLength = 4
        draft.metadata.scrollY = 330
        draft.metadata.scrollX = 25
        draft.metadata.wraps = true
        try repository.save(draft)
        try repository.saveSession(Session(selectedID: draft.id, sidebarWidth: 290))
        let reopened = try Repository(root: root).load()
        XCTAssertEqual(reopened.drafts.count, 1)
        XCTAssertEqual(reopened.drafts[0].text, draft.text)
        XCTAssertEqual(reopened.drafts[0].metadata.language, .markdown)
        XCTAssertEqual(reopened.drafts[0].metadata.cursor, 18)
        XCTAssertEqual(reopened.drafts[0].metadata.selectionLength, 4)
        XCTAssertEqual(reopened.drafts[0].metadata.scrollY, 330)
        XCTAssertTrue(reopened.drafts[0].metadata.wraps)
        XCTAssertEqual(reopened.session.selectedID, draft.id)
        XCTAssertEqual(reopened.session.sidebarWidth, 290)
        XCTAssertTrue(reopened.warnings.isEmpty)
    }

    func testAutomaticAndManualTitles() throws {
        var draft = Draft(text: "\n  \n  A useful thought\nDetails")
        XCTAssertEqual(draft.title, "A useful thought")
        draft.metadata.customTitle = "My note"
        draft.text = "Different first line"
        XCTAssertEqual(draft.title, "My note")
        try repository.save(draft)
        XCTAssertEqual(try repository.load().drafts[0].title, "My note")
        draft.metadata.customTitle = nil
        XCTAssertEqual(draft.title, "Different first line")
        XCTAssertEqual(Draft().title, "Untitled")
    }

    func testSearchAcrossDraftsExcludesTrashAndUsesUTF16Ranges() {
        let draft = Draft(text: "🦊 hello\nCafé NEEDLE in a table")
        var deleted = Draft(text: "needle")
        deleted.metadata.deletedAt = Date()
        let titleOnly = Draft(text: "unrelated", title: "Needle notes")
        let hits = SearchEngine.search("needle", in: [draft, deleted, titleOnly, Draft(text: "nothing")])
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0].line, 2)
        XCTAssertEqual((draft.text as NSString).substring(with: hits[0].range!), "NEEDLE")
        XCTAssertEqual(hits[0].range?.location, 14)
        XCTAssertNil(hits[1].range)
        XCTAssertTrue(SearchEngine.search("", in: [draft]).isEmpty)
        XCTAssertTrue(SearchEngine.search("[.*]", in: [draft]).isEmpty)
    }

    func testSearchSnippetDoesNotSplitEmoji() {
        let draft = Draft(text: String(repeating: "🧑🏽‍💻", count: 40) + "target" + String(repeating: "🦊", count: 100))
        let hit = SearchEngine.search("target", in: [draft])[0]
        XCTAssertTrue(hit.snippet.contains("target"))
        XCTAssertFalse(hit.snippet.contains("�"))
    }

    func testLineNumbersHandleWindowsAndUnicodeNewlines() {
        let text = "🦊\r\none\rtwo\nthree\u{2028}four\u{2029}target"
        let starts = LineMap.starts(in: text)
        XCTAssertEqual(starts.count, 6)
        XCTAssertEqual(starts[1], 4)
        XCTAssertEqual(LineMap.index(at: 4, starts: starts), 1)
        XCTAssertEqual(SearchEngine.search("target", in: [Draft(text: text)]).first?.line, 6)
    }

    func testTrashRestoreAndPermanentDeletion() throws {
        var draft = Draft(text: "Keep me")
        try repository.save(draft)
        draft.metadata.deletedAt = Date()
        try repository.save(draft, contentChanged: false)
        XCTAssertNotNil(try repository.load().drafts[0].metadata.deletedAt)
        XCTAssertTrue(SearchEngine.search("Keep", in: try repository.load().drafts).isEmpty)
        draft.metadata.deletedAt = nil
        try repository.save(draft, contentChanged: false)
        XCTAssertEqual(SearchEngine.search("Keep", in: try repository.load().drafts).count, 1)
        try repository.permanentlyDelete(draft.id)
        XCTAssertTrue(try repository.load().drafts.isEmpty)
    }

    func testMetadataSaveDoesNotRewriteContent() throws {
        var draft = Draft(text: "original")
        try repository.save(draft)
        draft.text = "must not be written"
        draft.metadata.customTitle = "Renamed"
        try repository.save(draft, contentChanged: false)
        let loaded = try repository.load().drafts[0]
        XCTAssertEqual(loaded.text, "original")
        XCTAssertEqual(loaded.title, "Renamed")
    }

    func testOlderDraftsAdoptWrappingAndLaterOptOutPersists() throws {
        let original = Draft(text: "A long line\twith its original spacing and no added breaks.")
        XCTAssertTrue(original.metadata.wraps)
        try repository.save(original)
        let metadataURL = root.appendingPathComponent("\(original.id).json")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any])
        legacy.removeValue(forKey: "wrapPreferenceVersion")
        legacy["wraps"] = false
        legacy["scrollX"] = 250
        try JSONSerialization.data(withJSONObject: legacy).write(to: metadataURL)

        var migrated = try XCTUnwrap(repository.load().drafts.first)
        XCTAssertTrue(migrated.metadata.wraps)
        XCTAssertEqual(migrated.metadata.scrollX, 0)
        XCTAssertEqual(migrated.text, original.text)
        migrated.metadata.wraps = false
        try repository.save(migrated, contentChanged: false)
        XCTAssertFalse(try XCTUnwrap(repository.load().drafts.first).metadata.wraps)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("\(original.id).txt")), original.text)
    }

    func testCorruptMetadataIsPreservedAndReported() throws {
        let draft = Draft(text: "Never discard this text")
        try repository.save(draft)
        let url = root.appendingPathComponent("\(draft.id).json")
        let invalid = Data("broken metadata".utf8)
        try invalid.write(to: url)
        let loaded = try repository.load()
        XCTAssertTrue(loaded.drafts.isEmpty)
        XCTAssertEqual(loaded.warnings.count, 1)
        XCTAssertEqual(try Data(contentsOf: url), invalid)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("\(draft.id).txt")), draft.text)
    }

    func testOrphanedTextRecoveredAfterInterruptedFirstSave() throws {
        let id = UUID()
        try Data("recover me".utf8).write(to: root.appendingPathComponent("\(id).txt"))
        let loaded = try repository.load()
        XCTAssertEqual(loaded.drafts.first?.id, id)
        XCTAssertEqual(loaded.drafts.first?.text, "recover me")
        XCTAssertEqual(loaded.warnings.count, 1)
    }

    func testFailedSaveReportsErrorWithoutChangingEarlierDraft() throws {
        let draft = Draft(text: "safe on disk")
        try repository.save(draft)
        let obstructed = root.appendingPathComponent("blocked")
        try Data("a file, not a folder".utf8).write(to: obstructed)
        XCTAssertThrowsError(try Repository(root: obstructed).save(Draft(text: "unsaved")))
        XCTAssertEqual(try repository.load().drafts[0].text, "safe on disk")
    }

    func testStableCreationOrderAndLanguages() throws {
        let older = Draft(text: "older", createdAt: Date(timeIntervalSince1970: 100))
        let newer = Draft(text: "newer", createdAt: Date(timeIntervalSince1970: 200))
        try repository.save(newer); try repository.save(older)
        XCTAssertEqual(try repository.load().drafts.map(\.id), [newer.id, older.id])
        XCTAssertEqual(Language.infer(extension: "TSX"), .typescript)
        XCTAssertEqual(Language.infer(extension: "md"), .markdown)
        XCTAssertEqual(Language.infer(extension: "unknown"), .plain)
    }

    func testHighlightingLimitsAndBounds() {
        let source = "// 🦊 comment\nlet greeting = \"hello\"\nlet n = 42"
        let tokens = Highlighter.tokens(in: source, language: .swift)
        XCTAssertFalse(tokens.isEmpty)
        for token in tokens { XCTAssertLessThanOrEqual(NSMaxRange(token.range), (source as NSString).length) }
        XCTAssertTrue(Highlighter.tokens(in: source, language: .plain).isEmpty)
        XCTAssertTrue(Highlighter.tokens(in: String(repeating: "a", count: Highlighter.limit + 1), language: .swift).isEmpty)
        for language in Language.allCases where language != .plain {
            _ = Highlighter.tokens(in: "# Hello\nconst x = 42; /* a */ \"string\" <div> **text**", language: language)
        }
    }

    func testThousandDraftPerformance() throws {
        let fixtureRoot = ProcessInfo.processInfo.environment["TEXTDUMP_BENCHMARK_DIR"].map { URL(fileURLWithPath: $0) } ?? root!
        let fixture = Repository(root: fixtureRoot)
        _ = try fixture.load()
        let body = String(repeating: "A useful line of text with enough detail to search later.\n", count: 180)
        var firstID: UUID?
        for index in 0..<1000 {
            let draft = Draft(text: "Draft \(index)\n" + body + (index == 432 ? "unique benchmark needle" : ""))
            try fixture.save(draft)
            firstID = draft.id
        }
        let large = Draft(text: String(repeating: "A long draft with tables | column | value |\n", count: 120_000), title: "5 MB draft")
        try fixture.save(large)
        try fixture.saveSession(Session(selectedID: firstID))
        let start = ProcessInfo.processInfo.systemUptime
        let loaded = try fixture.load()
        let loadMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let searchStart = ProcessInfo.processInfo.systemUptime
        let hits = SearchEngine.search("unique benchmark needle", in: loaded.drafts)
        let searchMS = (ProcessInfo.processInfo.systemUptime - searchStart) * 1000
        let byteCount = loaded.drafts.reduce(0) { $0 + $1.text.utf8.count }
        print(String(format: "BENCHMARK %d drafts, %d bytes: load %.1f ms, search %.1f ms", loaded.drafts.count, byteCount, loadMS, searchMS))
        XCTAssertEqual(hits.count, 1)
        XCTAssertLessThan(searchMS, 2000, "Broad regression guard; interactive target is 200 ms in release.")
    }
}
