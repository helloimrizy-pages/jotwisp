import SwiftUI
import TextDumpCore

private enum Palette {
    static let paper = Color(nsColor: .textBackgroundColor)
    static let sidebar = Color(nsColor: .windowBackgroundColor)
    static let accent = Color(red: 0.34, green: 0.43, blue: 0.85)
}

private enum WorkspaceLayout {
    static let footerHeight: CGFloat = 34
}

struct WorkspaceView: View {
    @ObservedObject var store: AppStore
    @FocusState private var searchFocused: Bool
    @State private var renameID: UUID?
    @State private var renameText = ""
    @State private var deleteID: UUID?
    @State private var dragStart: Double?

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: store.sidebarWidth)
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1)
                .overlay {
                    Color.clear.frame(width: 8).contentShape(Rectangle())
                        .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                        .gesture(DragGesture().onChanged { value in
                            if dragStart == nil { dragStart = store.sidebarWidth }
                            store.setSidebarWidth((dragStart ?? 256) + value.translation.width)
                        }.onEnded { _ in dragStart = nil })
                }
            editorPane.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.paper)
        .tint(Palette.accent)
        .frame(minWidth: 740, minHeight: 480)
        .onChange(of: store.focusSearchToken) { _, _ in searchFocused = true }
        .onChange(of: store.focusEditorToken) { _, _ in searchFocused = false }
        .sheet(isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Name this draft").font(.title3.weight(.semibold))
                TextField("Use the first line automatically", text: $renameText)
                    .textFieldStyle(.roundedBorder).onSubmit { finishRename() }
                Text("Leave it empty to use the first line of your text.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { renameID = nil }.keyboardShortcut(.cancelAction)
                    Button("Rename", action: finishRename).keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 380)
        }
        .alert("Permanently delete this draft?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
            Button("Cancel", role: .cancel) { deleteID = nil }
            Button("Delete permanently", role: .destructive) {
                if let id = deleteID { store.permanentlyDelete(id) }
                deleteID = nil
            }
        } message: { Text("This removes the draft from this Mac and cannot be undone.") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 30, height: 30).accessibilityHidden(true)
                Text(AppIdentity.displayName).font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: store.newDraft) { Image(systemName: "square.and.pencil").font(.system(size: 16)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("New draft · ⌘N")
                    .accessibilityLabel("New draft")
            }.padding(.horizontal, 20).padding(.top, 52).padding(.bottom, 24)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                TextField("Search all drafts", text: $store.query)
                    .textFieldStyle(.plain).font(.system(size: 12)).focused($searchFocused)
                    .onChange(of: store.query) { _, query in
                        if !query.isEmpty && store.showingTrash { store.showingTrash = false }
                    }
                    .onSubmit { if let first = store.results.first { store.openHit(first) } }
                    .onExitCommand { store.query = ""; searchFocused = false }
                if store.query.isEmpty {
                    Text("⌘⇧F").font(.system(size: 10)).foregroundStyle(.tertiary)
                } else {
                    Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }.padding(10).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(0.045)))
                .padding(.horizontal, 14)

            HStack {
                Text(store.showingTrash ? "TRASH" : store.query.isEmpty ? "YOUR DRAFTS" : "SEARCH RESULTS")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.1)
                Spacer()
                if store.searching { ProgressView().controlSize(.mini) }
                else { Text("\(store.query.isEmpty ? (store.showingTrash ? store.trashedDrafts.count : store.activeDrafts.count) : store.results.count)")
                    .font(.system(size: 11, design: .monospaced)) }
            }.foregroundStyle(.secondary).padding(.horizontal, 22).padding(.top, 25).padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 3) {
                    if !store.query.isEmpty {
                        ForEach(store.results) { hit in
                            Button { store.openHit(hit) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(hit.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                    Text(hit.snippet.isEmpty ? "Title match" : hit.snippet)
                                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading)
                                    if let line = hit.line {
                                        Text("Line \(line)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.accent)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    .background(store.selectedID == hit.id ? Palette.accent.opacity(0.09) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain)
                        }.id("search-results")
                        if store.results.isEmpty && !store.searching {
                            Text("No drafts contain “\(store.query)”.")
                                .font(.system(size: 12)).foregroundStyle(.secondary).padding(16)
                        }
                    } else {
                        ForEach(store.showingTrash ? store.trashedDrafts : store.activeDrafts) { draft in draftRow(draft) }
                            .id(store.showingTrash ? "trash-drafts" : "active-drafts")
                        if store.showingTrash && store.trashedDrafts.isEmpty {
                            Text("Nothing in the trash.").font(.system(size: 12)).foregroundStyle(.secondary).padding(16)
                        }
                    }
                }.padding(.horizontal, 10).padding(.bottom, 16)
            }.id(store.query.isEmpty ? "library-scroll" : "search-scroll")
            Spacer(minLength: 0)
            Divider().opacity(0.5)
            HStack {
                Button(action: store.toggleTrash) {
                    Label(store.showingTrash ? "Back to drafts" : "Trash", systemImage: store.showingTrash ? "arrow.left" : "trash")
                        .font(.system(size: 12))
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text("ON THIS MAC").font(.system(size: 8, weight: .medium)).tracking(1.1).foregroundStyle(.tertiary)
            }.padding(.horizontal, 20).frame(height: WorkspaceLayout.footerHeight)
        }.background(Palette.sidebar)
    }

    private func draftRow(_ draft: Draft) -> some View {
        Button { store.select(draft.id) } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: draft.metadata.language == .plain || draft.metadata.language == .markdown ? "doc.text" : "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 14, weight: .regular)).foregroundStyle(store.selectedID == draft.id ? Palette.accent : Color.secondary)
                    .frame(width: 19).padding(.top, 2)
                VStack(alignment: .leading, spacing: 5) {
                    Text(draft.title).font(.system(size: 13, weight: store.selectedID == draft.id ? .medium : .regular)).lineLimit(1)
                    Text(draft.text.isEmpty ? "A fresh start" : preview(draft))
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 12).padding(.vertical, 11).frame(maxWidth: .infinity, alignment: .leading)
                .background(store.selectedID == draft.id ? Palette.accent.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .contextMenu {
                if draft.metadata.deletedAt != nil {
                    Button("Restore draft") { store.restore(draft.id) }
                    Button("Delete permanently…", role: .destructive) { deleteID = draft.id }
                } else {
                    Button("Rename…") { beginRename(draft) }
                    Button("Export…") { store.select(draft.id); store.exportSelected() }
                    Divider()
                    Button("Move to Trash", role: .destructive) { store.trash(draft.id) }
                }
            }
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            if let draft = store.selectedDraft {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.metadata.deletedAt != nil ? "TRASH" : "DRAFT")
                            .font(.system(size: 9, weight: .medium)).tracking(1.4).foregroundStyle(.tertiary)
                        Button { beginRename(draft) } label: {
                            Text(draft.title).font(.system(size: 19, weight: .semibold)).lineLimit(1)
                        }.buttonStyle(.plain).help("Rename draft").disabled(draft.metadata.deletedAt != nil)
                    }
                    Spacer(minLength: 12)
                    if draft.metadata.deletedAt != nil {
                        Button("Restore") { store.restore(draft.id) }.buttonStyle(.bordered)
                    } else {
                        Button { store.toggleWrap(draft.id) } label: {
                            Image(systemName: "text.word.spacing").font(.system(size: 15))
                                .foregroundStyle(draft.metadata.wraps ? Palette.accent : Color.secondary)
                                .padding(7).background(draft.metadata.wraps ? Palette.accent.opacity(0.08) : Color.clear,
                                                      in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain).help(draft.metadata.wraps ? "Turn word wrap off" : "Turn word wrap on")
                            .accessibilityLabel("Toggle word wrap")
                    }
                    Menu {
                        Button("Rename…") { beginRename(draft) }.disabled(draft.metadata.deletedAt != nil)
                        Button("Export…", action: store.exportSelected)
                        Divider()
                        if draft.metadata.deletedAt == nil {
                            Button("Move to Trash", role: .destructive) { store.trash(draft.id) }
                        } else {
                            Button("Delete permanently…", role: .destructive) { deleteID = draft.id }
                        }
                    } label: { Image(systemName: "ellipsis").font(.system(size: 18)).foregroundStyle(.secondary) }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Draft actions")
                }.padding(.horizontal, 30).padding(.top, 37).padding(.bottom, 23)
                Divider().opacity(0.5)
                notice
                ZStack(alignment: .topLeading) {
                    DraftEditor(store: store, draft: draft)
                    if draft.text.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Start typing, or paste something here.")
                                .font(.system(size: 14, design: .monospaced)).foregroundStyle(.tertiary)
                            Text("A thought, a table, a snippet. It’s saved as you go.")
                                .font(.system(size: 12)).foregroundStyle(.quaternary)
                        }.padding(.leading, 77).padding(.top, 25).allowsHitTesting(false)
                    }
                }.clipped()
                Divider().opacity(0.5)
                HStack(spacing: 7) {
                    Circle().fill(store.saveState == "Saved locally" ? Color.green.opacity(0.65) : Color.orange).frame(width: 5, height: 5)
                    Text(store.saveState).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    if draft.text.utf8.count > Highlighter.limit && draft.metadata.language != .plain {
                        Text("Highlighting paused · large draft").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Menu {
                        ForEach(Language.allCases, id: \.self) { language in
                            Button { store.language(language, id: draft.id) } label: {
                                if language == draft.metadata.language { Label(language.rawValue, systemImage: "checkmark") }
                                else { Text(language.rawValue) }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(draft.metadata.language.rawValue)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                    }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().disabled(draft.metadata.deletedAt != nil)
                        .accessibilityLabel("Language: \(draft.metadata.language.rawValue)")
                    Text("UTF-8").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.leading, 12)
                }.padding(.horizontal, 22).frame(height: WorkspaceLayout.footerHeight)
            } else {
                notice
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: store.showingTrash ? "trash" : "square.and.pencil")
                        .font(.system(size: 34, weight: .ultraLight)).foregroundStyle(.tertiary)
                    Text(store.showingTrash ? "A clean slate." : "Room for your next thought.")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                    Text(store.showingTrash ? "Deleted drafts stay here until you remove them." : "Keep the useful bits. Find them when you need them.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    if !store.showingTrash {
                        Button("Create a draft", action: store.newDraft).buttonStyle(.bordered).padding(.top, 6)
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder private var notice: some View {
        if let message = store.quickCaptureNotice {
            HStack(spacing: 10) {
                Image(systemName: "keyboard").foregroundStyle(.secondary)
                Text(message).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Set up…") { store.enableQuickCapture?() }
                    .help(Distribution.isAppStore ? "Retry the Control–Option–V shortcut" : "Allow \(AppIdentity.displayName) in System Settings → Privacy & Security → Accessibility")
            }.padding(12).background(Palette.accent.opacity(0.05))
        }
        if let message = store.errorMessage ?? store.libraryWarning {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(message).font(.system(size: 12)).textSelection(.enabled)
                Spacer()
                if store.errorMessage != nil { Button("Retry save", action: store.retrySave) }
                Button { store.errorMessage = nil; store.libraryWarning = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Dismiss notice")
            }.padding(12).background(Color.orange.opacity(0.08))
        }
    }

    private func preview(_ draft: Draft) -> String {
        let lines = draft.text.prefix(300).split(whereSeparator: \.isNewline)
        return lines.count > 1 ? String(lines[1]) : draft.metadata.language.rawValue
    }
    private func beginRename(_ draft: Draft) { renameText = draft.metadata.customTitle ?? draft.title; renameID = draft.id }
    private func finishRename() { if let id = renameID { store.rename(id, title: renameText) }; renameID = nil }
}
