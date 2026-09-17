import AppKit
import Combine
import TextDumpCore
import UniformTypeIdentifiers

struct EditorJump: Equatable {
    let token = UUID()
    let draftID: UUID
    let range: NSRange
}

enum ClipboardCaptureError: LocalizedError {
    case noText, storageUnavailable

    var errorDescription: String? {
        switch self {
        case .noText: return "Copy some text first, then use New Draft from Clipboard."
        case .storageUnavailable: return "The draft library is unavailable. Retry opening it before capturing text."
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var drafts: [Draft] = []
    @Published var selectedID: UUID?
    @Published var query = "" { didSet { scheduleSearch() } }
    @Published var results: [SearchHit] = []
    @Published var searching = false
    @Published var showingTrash = false
    @Published var saveState = "Saved locally"
    @Published var errorMessage: String?
    @Published var libraryWarning: String?
    @Published var jump: EditorJump?
    @Published var focusSearchToken = UUID()
    @Published var focusEditorToken = UUID()
    @Published var sidebarWidth: Double = 256
    @Published var quickCaptureNotice: String?
    var enableQuickCapture: (() -> Void)?
    var captureEditorPosition: (() -> Void)?

    let repository: Repository
    private let diskQueue = DispatchQueue(label: "app.textdump.persistence", qos: .userInitiated)
    private var dirty: [UUID: Int] = [:]
    private var contentDirty: Set<UUID> = []
    private var revision = 0
    private var saveTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var sessionDirty = false
    private var storageAvailable = true
    private var saveGeneration = 0

    var activeDrafts: [Draft] { drafts.filter { $0.metadata.deletedAt == nil } }
    var trashedDrafts: [Draft] { drafts.filter { $0.metadata.deletedAt != nil } }
    var selectedDraft: Draft? { drafts.first { $0.id == selectedID } }
    var session: Session { Session(selectedID: selectedID, sidebarWidth: sidebarWidth) }

    init(root suppliedRoot: URL? = nil) {
        let root: URL
        if let suppliedRoot { root = suppliedRoot }
        else if let override = ProcessInfo.processInfo.environment["TEXTDUMP_DATA_DIR"] {
            root = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            root = AppIdentity.libraryURL(in: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
        }
        repository = Repository(root: root)
        do {
            let loaded = try repository.load()
            drafts = loaded.drafts
            sidebarWidth = min(380, max(210, loaded.session.sidebarWidth))
            selectedID = activeDrafts.first(where: { $0.id == loaded.session.selectedID })?.id ?? activeDrafts.first?.id
            if !loaded.warnings.isEmpty { libraryWarning = loaded.warnings.joined(separator: "\n") }
            if drafts.isEmpty && loaded.warnings.isEmpty { newDraft() }
        } catch {
            storageAvailable = false
            errorMessage = "Your library could not be opened. \(error.localizedDescription)"
            saveState = "Storage unavailable"
        }
    }

    func newDraft() {
        guard storageAvailable else { return }
        createDraft(text: "")
    }

    func newDraftFromClipboard(_ pasteboard: NSPasteboard = .general) throws {
        guard storageAvailable else { throw ClipboardCaptureError.storageUnavailable }
        // Read only when explicitly invoked; preserve whitespace and the clipboard itself.
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            throw ClipboardCaptureError.noText
        }
        createDraft(text: text)
        if let id = selectedID {
            jump = EditorJump(draftID: id, range: NSRange(location: (text as NSString).length, length: 0))
        }
        saveNow()
    }

    private func createDraft(text: String) {
        captureEditorPosition?()
        saveNow()
        var draft = Draft(text: text)
        draft.metadata.cursor = (text as NSString).length
        drafts.insert(draft, at: 0)
        showingTrash = false
        query = ""
        selectedID = draft.id
        markDirty(draft.id, content: true)
        focusEditorToken = UUID()
    }

    func select(_ id: UUID) {
        guard selectedID != id else { return }
        captureEditorPosition?()
        saveNow()
        selectedID = id
        sessionDirty = true
        scheduleSave()
    }

    func openHit(_ hit: SearchHit) {
        select(hit.id)
        if let range = hit.range { jump = EditorJump(draftID: hit.id, range: range) }
        focusEditorToken = UUID()
    }

    func updateText(_ text: String, id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }), drafts[index].text != text else { return }
        drafts[index].text = text
        drafts[index].metadata.modifiedAt = Date()
        markDirty(id, content: true)
        if !query.isEmpty { scheduleSearch() }
    }

    func updatePosition(id: UUID, range: NSRange, origin: NSPoint) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let old = drafts[index].metadata
        guard old.cursor != range.location || old.selectionLength != range.length ||
                old.scrollX != origin.x || old.scrollY != origin.y else { return }
        drafts[index].metadata.cursor = range.location
        drafts[index].metadata.selectionLength = range.length
        drafts[index].metadata.scrollX = origin.x
        drafts[index].metadata.scrollY = origin.y
        markDirty(id)
    }

    func rename(_ id: UUID, title: String) {
        modify(id) { $0.customTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines) }
        scheduleSearch()
    }

    func language(_ language: Language, id: UUID) { modify(id) { $0.language = language } }
    func toggleWrap(_ id: UUID) { modify(id) { $0.wraps.toggle() } }

    func trash(_ id: UUID) {
        captureEditorPosition?()
        modify(id) { $0.deletedAt = Date() }
        if selectedID == id { selectedID = activeDrafts.first?.id }
        sessionDirty = true
        saveNow()
        scheduleSearch()
    }

    func restore(_ id: UUID) {
        modify(id) { $0.deletedAt = nil }
        showingTrash = false
        query = ""
        selectedID = id
        saveNow()
    }

    func permanentlyDelete(_ id: UUID) {
        guard drafts.first(where: { $0.id == id })?.metadata.deletedAt != nil else { return }
        saveTask?.cancel()
        do {
            try diskQueue.sync { try repository.permanentlyDelete(id) }
            dirty.removeValue(forKey: id)
            contentDirty.remove(id)
            drafts.removeAll { $0.id == id }
            if selectedID == id { selectedID = nil }
            saveNow()
        } catch { errorMessage = "Could not delete the draft. \(error.localizedDescription)" }
    }

    func setSidebarWidth(_ width: Double) {
        sidebarWidth = min(380, max(210, width))
        sessionDirty = true
        scheduleSave()
    }

    func toggleTrash() {
        captureEditorPosition?()
        saveNow()
        showingTrash.toggle()
        query = ""
        selectedID = showingTrash ? trashedDrafts.first?.id : activeDrafts.first?.id
    }

    func focusSearch() {
        showingTrash = false
        if selectedDraft?.metadata.deletedAt != nil { selectedID = activeDrafts.first?.id }
        focusSearchToken = UUID()
    }

    func importFiles() {
        let panel = NSOpenPanel()
        panel.title = "Import text as drafts"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        var failures: [String] = []
        var firstID: UUID?
        for url in panel.urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
                    throw RepositoryError.invalidText(url.lastPathComponent)
                }
                let draft = Draft(text: text, title: url.deletingPathExtension().lastPathComponent,
                                  language: Language.infer(extension: url.pathExtension))
                drafts.insert(draft, at: 0)
                markDirty(draft.id, content: true)
                if firstID == nil { firstID = draft.id }
            } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        if let firstID { showingTrash = false; query = ""; select(firstID); focusEditorToken = UUID() }
        saveNow()
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
    }

    func exportSelected() {
        guard let draft = selectedDraft else { return }
        let panel = NSSavePanel()
        panel.title = "Export draft"
        panel.nameFieldStringValue = draft.title.replacingOccurrences(of: "/", with: "-") + "." + draft.metadata.language.fileExtension
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do { try Data(draft.text.utf8).write(to: url, options: .atomic) }
        catch { errorMessage = "Could not export this draft. \(error.localizedDescription)" }
    }

    func saveNow() {
        saveTask?.cancel()
        persist()
    }

    func retrySave() {
        if !storageAvailable {
            do {
                let loaded = try repository.load()
                drafts = loaded.drafts
                selectedID = activeDrafts.first(where: { $0.id == loaded.session.selectedID })?.id ?? activeDrafts.first?.id
                storageAvailable = true
                errorMessage = nil
                libraryWarning = loaded.warnings.isEmpty ? nil : loaded.warnings.joined(separator: "\n")
                if drafts.isEmpty && loaded.warnings.isEmpty { newDraft() }
            } catch { errorMessage = "Your library could not be opened. \(error.localizedDescription)"; return }
        }
        if flush() { errorMessage = nil }
    }

    /// Drains earlier writes before writing the latest state; called before closing/quitting.
    @discardableResult func flush() -> Bool {
        saveTask?.cancel()
        guard storageAvailable else { return dirty.isEmpty }
        saveGeneration += 1
        let pending = drafts.filter { dirty[$0.id] != nil }
        let content = contentDirty
        let currentSession = session
        do {
            try diskQueue.sync {
                for draft in pending { try repository.save(draft, contentChanged: content.contains(draft.id)) }
                try repository.saveSession(currentSession)
            }
            dirty.removeAll(); contentDirty.removeAll(); sessionDirty = false
            saveState = "Saved locally"
            return true
        } catch {
            saveState = "Couldn’t save"
            errorMessage = "Your latest changes are still in memory. \(error.localizedDescription)"
            return false
        }
    }

    private func modify(_ id: UUID, change: (inout DraftMetadata) -> Void) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        change(&drafts[index].metadata)
        markDirty(id)
    }

    private func markDirty(_ id: UUID, content: Bool = false) {
        revision += 1
        dirty[id] = revision
        if content { contentDirty.insert(id) }
        sessionDirty = true
        saveState = "Saving…"
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        guard storageAvailable, !dirty.isEmpty || sessionDirty else { return }
        let pending = drafts.filter { dirty[$0.id] != nil }
        let versions = dirty
        let content = contentDirty
        let currentSession = session
        let generation = saveGeneration
        sessionDirty = false
        diskQueue.async { [weak self, repository] in
            let result: Result<Void, Error> = Result {
                for draft in pending { try repository.save(draft, contentChanged: content.contains(draft.id)) }
                try repository.saveSession(currentSession)
            }
            DispatchQueue.main.async {
                guard let self, self.saveGeneration == generation else { return }
                switch result {
                case .success:
                    for (id, version) in versions where self.dirty[id] == version {
                        self.dirty.removeValue(forKey: id)
                        self.contentDirty.remove(id)
                    }
                    if self.dirty.isEmpty { self.saveState = "Saved locally" }
                case .failure(let error):
                    self.sessionDirty = true
                    self.saveState = "Couldn’t save"
                    self.errorMessage = "Your latest changes are still in memory. \(error.localizedDescription)"
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let search = query
        guard !search.isEmpty else { results = []; searching = false; return }
        searching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, let self else { return }
            let snapshot = self.drafts
            let hits = await Task.detached(priority: .userInitiated) { SearchEngine.search(search, in: snapshot) }.value
            guard !Task.isCancelled, self.query == search else { return }
            self.results = hits
            self.searching = false
        }
    }
}
