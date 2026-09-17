import AppKit

/// Readable bundled policies remain available even when the user is offline.
@MainActor
final class PublicInformation {
    private var window: NSWindow?

    func show(title: String, resource: String, parent: NSWindow) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "md")
                ?? Bundle.main.url(forResource: resource, withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            let alert = NSAlert()
            alert.messageText = "This document is not available in this build"
            alert.informativeText = "Contact rizy.izy15@gmail.com for help."
            alert.beginSheetModal(for: parent)
            return
        }
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 580),
                             styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.title = title
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 400, height: 300)
        let scroll = NSScrollView(frame: panel.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        let view = NSTextView(frame: scroll.bounds)
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.font = .systemFont(ofSize: 14)
        view.textColor = .textColor
        view.textContainerInset = NSSize(width: 24, height: 24)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.string = text
        scroll.documentView = view
        panel.contentView = scroll
        window?.close()
        window = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}
