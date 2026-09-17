import AppKit
import SwiftUI
import TextDumpCore

@main
enum TextDumpApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var store: AppStore!
    var window: NSWindow!
    private var quickCaptureShortcut: QuickCaptureShortcut?
    private var quickCaptureMonitor: QuickCapturePermissionMonitor?
    private let publicInformation = PublicInformation()
    let launchStart = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // An isolated QA launch can check both appearances without changing system settings.
        if ProcessInfo.processInfo.environment["TEXTDUMP_DATA_DIR"] != nil,
           let appearance = ProcessInfo.processInfo.environment["TEXTDUMP_TEST_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        store = AppStore()
        quickCaptureShortcut = QuickCaptureShortcut { [weak self] in self?.captureClipboard() }
        quickCaptureMonitor = QuickCapturePermissionMonitor(check: { [weak self] in
            self?.quickCaptureShortcut?.start() ?? .unavailable
        }, didChange: { [weak self] status in
            guard let self else { return }
            switch status {
            case .ready: self.store.quickCaptureNotice = nil
            case .needsPermission:
                self.store.quickCaptureNotice = "macOS hasn’t granted this copy of \(AppIdentity.displayName) Accessibility access."
            case .unavailable:
                self.store.quickCaptureNotice = Distribution.isAppStore
                    ? "Quick capture (⌃⌥V) is unavailable. Another app may be using this shortcut."
                    : "Quick capture couldn’t start. Check Accessibility access or restart \(AppIdentity.displayName)."
            }
        })
        store.enableQuickCapture = { [weak self] in self?.enableQuickCapture() }
        configureMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = AppIdentity.displayName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 740, height: 480)
        window.delegate = self
        window.contentView = NSHostingView(rootView: WorkspaceView(store: store))
        window.center()
        window.setFrameAutosaveName(AppIdentity.windowFrameName)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateQuickCaptureStatus()
        if ProcessInfo.processInfo.environment["TEXTDUMP_BENCHMARK"] == "1" {
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(self.launchStart) * 1000
                print(String(format: "Window ready: %.1f ms; drafts: %d", elapsed, self.store.drafts.count))
                fflush(stdout)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return true
    }

    func applicationWillResignActive(_ notification: Notification) { capturePosition(); store.saveNow() }

    func applicationDidBecomeActive(_ notification: Notification) {
        if store != nil { updateQuickCaptureStatus() }
    }

    private func updateQuickCaptureStatus() {
        quickCaptureMonitor?.refresh()
    }

    @objc func enableQuickCapture() {
        updateQuickCaptureStatus()
        guard quickCaptureMonitor?.status != .ready, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Set up \(Distribution.shortcutLabel) quick capture"
        if Distribution.isAppStore {
            alert.informativeText = "Copy text, then press Control–Option–V to create a draft. If another app is using this shortcut, change that app’s shortcut or quit it, then retry. You can always use File → New Draft from Clipboard. No Accessibility permission is needed."
            alert.addButton(withTitle: "Retry")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn { self?.updateQuickCaptureStatus() }
            }
            return
        }
        alert.informativeText = "In System Settings → Privacy & Security → Accessibility, enable \(AppIdentity.displayName).\n\nAlready enabled? macOS may still recognize an older build, possibly listed as Text Dump. Remove the old entry with −, then use + to add this copy again. Show App in Finder locates the exact copy you’re running. If access still isn’t recognized, quit and reopen \(AppIdentity.displayName).\n\nYour drafts won’t be affected. The banner disappears automatically when the shortcut is ready."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Show App in Finder")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.quickCaptureShortcut?.requestPermission()
            } else if response == .alertSecondButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            }
            self?.updateQuickCaptureStatus()
        }
    }

    @objc func captureClipboard() {
        guard NSApp.modalWindow == nil, window.attachedSheet == nil else { NSSound.beep(); return }
        do {
            try store.newDraftFromClipboard()
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Couldn’t create a draft from the clipboard"
            alert.informativeText = error.localizedDescription
            alert.beginSheetModal(for: window)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { capturePosition(); return store.flush() }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        capturePosition()
        guard !store.flush() else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Some changes haven’t been saved"
        alert.informativeText = "Keep \(AppIdentity.displayName) open to retry saving or export your drafts. Quitting now will lose unsaved changes."
        alert.addButton(withTitle: "Keep Open")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    private func capturePosition() {
        store.captureEditorPosition?()
    }

    private func findEditor(in view: NSView?) -> DraftTextView? {
        if let editor = view as? DraftTextView { return editor }
        for child in view?.subviews ?? [] { if let found = findEditor(in: child) { return found } }
        return nil
    }

    @objc func newDraft() { store.newDraft(); window.makeKeyAndOrderFront(nil) }
    @objc func importFiles() { store.importFiles() }
    @objc func exportFile() { store.exportSelected() }
    @objc func save() { capturePosition(); store.saveNow() }
    @objc func globalSearch() { window.makeKeyAndOrderFront(nil); store.focusSearch() }
    @objc func showFind(_ sender: NSMenuItem) {
        guard let text = findEditor(in: window.contentView) else { return }
        window.makeFirstResponder(text)
        text.performFindPanelAction(sender)
    }
    @objc func toggleWrap() { if let id = store.selectedID { store.toggleWrap(id) } }
    @objc func showPrivacy() { publicInformation.show(title: "Jotwisp Privacy Policy", resource: "PRIVACY", parent: window) }
    @objc func showSupport() { publicInformation.show(title: "Jotwisp Help", resource: "SUPPORT", parent: window) }
    @objc func showLicense() { publicInformation.show(title: "Jotwisp Open Source License", resource: "LICENSE", parent: window) }
    @objc func openPrivacyWebsite() { NSWorkspace.shared.open(Distribution.privacyURL) }
    @objc func openSource() { NSWorkspace.shared.open(Distribution.sourceURL) }
    @objc func contactSupport() { NSWorkspace.shared.open(Distribution.supportURL) }

    private func configureMenu() {
        let menu = NSMenu()
        NSApp.mainMenu = menu
        let appMenu = submenu(AppIdentity.displayName, in: menu)
        item("About \(AppIdentity.displayName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), in: appMenu)
        appMenu.addItem(.separator())
        item("Hide \(AppIdentity.displayName)", #selector(NSApplication.hide(_:)), key: "h", in: appMenu)
        item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option], in: appMenu)
        item("Show All", #selector(NSApplication.unhideAllApplications(_:)), in: appMenu)
        appMenu.addItem(.separator())
        item("Quit \(AppIdentity.displayName)", #selector(NSApplication.terminate(_:)), key: "q", in: appMenu)
        let file = submenu("File", in: menu)
        item("New Draft", #selector(newDraft), key: "n", target: self, in: file)
        item("New Draft from Clipboard (\(Distribution.shortcutLabel))", #selector(captureClipboard), target: self, in: file)
        item("Enable Quick Capture…", #selector(enableQuickCapture), target: self, in: file)
        item("Import…", #selector(importFiles), key: "o", target: self, in: file)
        item("Export Draft…", #selector(exportFile), key: "s", modifiers: [.command, .shift], target: self, in: file)
        item("Save Now", #selector(save), key: "s", target: self, in: file)
        file.addItem(.separator())
        item("Close Window", #selector(NSWindow.performClose(_:)), key: "w", in: file)
        let edit = submenu("Edit", in: menu)
        item("Undo", Selector(("undo:")), key: "z", in: edit)
        item("Redo", Selector(("redo:")), key: "z", modifiers: [.command, .shift], in: edit)
        edit.addItem(.separator())
        item("Cut", #selector(NSText.cut(_:)), key: "x", in: edit)
        item("Copy", #selector(NSText.copy(_:)), key: "c", in: edit)
        item("Paste", #selector(NSText.paste(_:)), key: "v", in: edit)
        item("Select All", #selector(NSText.selectAll(_:)), key: "a", in: edit)
        let find = submenu("Find", in: menu)
        item("Search All Drafts", #selector(globalSearch), key: "f", modifiers: [.command, .shift], target: self, in: find)
        find.addItem(.separator())
        item("Find in Draft…", #selector(showFind(_:)), key: "f", target: self, tag: NSTextFinder.Action.showFindInterface.rawValue, in: find)
        item("Find and Replace…", #selector(showFind(_:)), key: "f", modifiers: [.command, .option], target: self, tag: NSTextFinder.Action.showReplaceInterface.rawValue, in: find)
        item("Find Next", #selector(showFind(_:)), key: "g", target: self, tag: NSTextFinder.Action.nextMatch.rawValue, in: find)
        item("Find Previous", #selector(showFind(_:)), key: "g", modifiers: [.command, .shift], target: self, tag: NSTextFinder.Action.previousMatch.rawValue, in: find)
        let view = submenu("View", in: menu)
        item("Toggle Word Wrap", #selector(toggleWrap), key: "w", modifiers: [.command, .option], target: self, in: view)
        let windowMenu = submenu("Window", in: menu)
        NSApp.windowsMenu = windowMenu
        item("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m", in: windowMenu)
        item("Zoom", #selector(NSWindow.performZoom(_:)), in: windowMenu)
        let help = submenu("Help", in: menu)
        NSApp.helpMenu = help
        item("Jotwisp Help", #selector(showSupport), target: self, in: help)
        item("Contact Support…", #selector(contactSupport), target: self, in: help)
        help.addItem(.separator())
        item("Privacy Policy", #selector(showPrivacy), target: self, in: help)
        item("Privacy Policy Online…", #selector(openPrivacyWebsite), target: self, in: help)
        item("Open Source License", #selector(showLicense), target: self, in: help)
        item("Source Code on GitHub…", #selector(openSource), target: self, in: help)
    }

    private func submenu(_ title: String, in parent: NSMenu) -> NSMenu {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        item.submenu = menu; parent.addItem(item)
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = .command,
                      target: AnyObject? = nil, tag: Int = 0, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        item.tag = tag
        menu.addItem(item)
    }
}
