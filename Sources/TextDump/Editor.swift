import AppKit
import SwiftUI
import TextDumpCore

final class DraftTextView: NSTextView {
    var appearanceChanged: (() -> Void)?
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        insertionPointColor = .labelColor
        appearanceChanged?()
    }
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
}

final class DraftScrollView: NSScrollView {
    private var fittingWidth = false

    override func tile() {
        super.tile()
        fitWrappedTextToViewport()
    }

    override func layout() {
        super.layout()
        fitWrappedTextToViewport()
    }

    func fitWrappedTextToViewport() {
        guard !fittingWidth, let text = documentView as? NSTextView,
              text.textContainer?.widthTracksTextView == true, contentSize.width > 0 else { return }
        fittingWidth = true
        defer { fittingWidth = false }
        let gutter = rulersVisible && hasVerticalRuler ? (verticalRulerView?.ruleThickness ?? 0) : 0
        let width = max(1, contentSize.width - gutter)
        text.minSize.width = width
        if abs(text.frame.width - width) > 0.5 {
            text.setFrameSize(NSSize(width: width, height: text.frame.height))
        }
        // A wrapped draft always starts at the left edge, even after a window shrink.
        var proposed = contentView.bounds
        proposed.origin.x = -10_000_000
        let leftEdge = contentView.constrainBoundsRect(proposed).origin.x
        if abs(contentView.bounds.origin.x - leftEdge) > 0.5 {
            contentView.scroll(to: NSPoint(x: leftEdge, y: contentView.bounds.origin.y))
            reflectScrolledClipView(contentView)
        }
        verticalRulerView?.needsDisplay = true
    }
}

struct DraftEditor: NSViewRepresentable {
    @ObservedObject var store: AppStore
    let draft: Draft

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = DraftScrollView()
        scroll.borderType = .noBorder
        // Constrain the native ruler's separator to the editor, below the title.
        scroll.clipsToBounds = true
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        layout.allowsNonContiguousLayout = true
        let container = NSTextContainer(containerSize: NSSize(width: 10_000_000, height: 10_000_000))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let text = DraftTextView(frame: NSRect(x: 0, y: 0, width: 700, height: 500), textContainer: container)
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: 10_000_000, height: 10_000_000)
        text.isVerticallyResizable = true
        text.isRichText = false
        text.importsGraphics = false
        text.allowsUndo = true
        text.usesFindBar = true
        text.isIncrementalSearchingEnabled = true
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.isAutomaticLinkDetectionEnabled = false
        text.isAutomaticDataDetectionEnabled = false
        text.isAutomaticTextCompletionEnabled = false
        text.isContinuousSpellCheckingEnabled = false
        text.smartInsertDeleteEnabled = false
        text.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        text.textColor = .labelColor
        text.insertionPointColor = .labelColor
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 20, height: 24)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.tabStops = []
        paragraph.defaultTabInterval = (" " as NSString).size(withAttributes: [.font: text.font!]).width * 4
        text.defaultParagraphStyle = paragraph
        text.typingAttributes = [.font: text.font!, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        text.setAccessibilityLabel("Draft text editor")
        scroll.documentView = text
        let ruler = LineNumberRuler(scrollView: scroll, textView: text)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.attach(text: text, scroll: scroll, ruler: ruler)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(draft: draft, jump: store.jump, focus: store.focusEditorToken)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) { coordinator.detach() }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        let store: AppStore
        weak var text: DraftTextView?
        weak var scroll: NSScrollView?
        weak var ruler: LineNumberRuler?
        var draftID: UUID?
        var language: Language = .plain
        var wraps: Bool?
        var changing = false
        var lastJump: UUID?
        var lastFocus: UUID?
        var highlightTask: Task<Void, Never>?
        var positionTask: Task<Void, Never>?
        var tokens: [SyntaxToken] = []
        var observer: NSObjectProtocol?

        init(store: AppStore) { self.store = store }

        func attach(text: DraftTextView, scroll: NSScrollView, ruler: LineNumberRuler) {
            self.text = text; self.scroll = scroll; self.ruler = ruler
            store.captureEditorPosition = { [weak self] in self?.capturePosition() }
            text.delegate = self
            text.appearanceChanged = { [weak self] in self?.applyColors() }
            scroll.contentView.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                              object: scroll.contentView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.ruler?.needsDisplay = true
                    self?.schedulePosition()
                    self?.applyColors()
                }
            }
        }

        func detach() {
            capturePosition()
            store.captureEditorPosition = nil
            if let observer { NotificationCenter.default.removeObserver(observer) }
            highlightTask?.cancel(); positionTask?.cancel()
        }

        func update(draft: Draft, jump: EditorJump?, focus: UUID) {
            guard let text, let scroll else { return }
            let switched = draftID != draft.id
            if switched {
                changing = true
                positionTask?.cancel()
                draftID = draft.id
                text.undoManager?.removeAllActions()
                text.string = draft.text
                text.didChangeText()
                text.isEditable = draft.metadata.deletedAt == nil
                tokens = []
                ruler?.rebuild()
                wraps = nil
            }
            text.isEditable = draft.metadata.deletedAt == nil
            if wraps != draft.metadata.wraps {
                changing = true
                wraps = draft.metadata.wraps
                let editorWidth = max(100, scroll.contentSize.width - (ruler?.ruleThickness ?? 0))
                text.minSize.width = 0
                text.isHorizontallyResizable = !draft.metadata.wraps
                text.autoresizingMask = []
                text.textContainer?.widthTracksTextView = draft.metadata.wraps
                text.textContainer?.containerSize = NSSize(width: draft.metadata.wraps ? editorWidth : 10_000_000,
                                                         height: 10_000_000)
                text.setFrameSize(NSSize(width: editorWidth, height: max(text.frame.height, scroll.contentSize.height)))
                scroll.hasHorizontalScroller = !draft.metadata.wraps
                (scroll as? DraftScrollView)?.fitWrappedTextToViewport()
                let y = scroll.contentView.bounds.origin.y
                scroll.contentView.scroll(to: NSPoint(x: minimumScrollOrigin().x, y: y))
                scroll.reflectScrolledClipView(scroll.contentView)
                ruler?.needsDisplay = true
                changing = false
            }
            if switched || language != draft.metadata.language {
                language = draft.metadata.language
                scheduleHighlight()
            }
            if switched {
                changing = true
                let count = (text.string as NSString).length
                let location = min(draft.metadata.cursor, count)
                text.setSelectedRange(NSRange(location: location, length: min(draft.metadata.selectionLength, count - location)))
                let expectedID = draft.id
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.draftID == expectedID else { return }
                    self.changing = true
                    text.layoutManager?.ensureLayout(forBoundingRect: NSRect(x: draft.metadata.scrollX, y: draft.metadata.scrollY,
                                                                            width: scroll.contentSize.width, height: scroll.contentSize.height),
                                                     in: text.textContainer!)
                    let minimum = self.minimumScrollOrigin()
                    scroll.contentView.scroll(to: NSPoint(x: minimum.x + (draft.metadata.wraps ? 0 : max(0, draft.metadata.scrollX)),
                                                         y: minimum.y + max(0, draft.metadata.scrollY)))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    self.changing = false
                    self.ruler?.needsDisplay = true
                }
                changing = false
            }
            if let jump, jump.draftID == draft.id, lastJump != jump.token {
                lastJump = jump.token
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.draftID == jump.draftID else { return }
                    let count = (text.string as NSString).length
                    guard NSMaxRange(jump.range) <= count else { return }
                    text.setSelectedRange(jump.range)
                    text.scrollRangeToVisible(jump.range)
                    text.showFindIndicator(for: jump.range)
                    text.window?.makeFirstResponder(text)
                }
            }
            if lastFocus != focus {
                lastFocus = focus
                DispatchQueue.main.async { text.window?.makeFirstResponder(text) }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !changing, let text, let draftID else { return }
            store.updateText(text.string, id: draftID)
            ruler?.rebuild()
            capturePosition()
            scheduleHighlight()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !changing else { return }
            ruler?.needsDisplay = true
            schedulePosition()
        }

        func schedulePosition() {
            guard !changing else { return }
            positionTask?.cancel()
            positionTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                self?.capturePosition()
            }
        }

        func capturePosition() {
            guard !changing, let text, let scroll, let draftID else { return }
            let minimum = minimumScrollOrigin()
            let origin = scroll.contentView.bounds.origin
            store.updatePosition(id: draftID, range: text.selectedRange(),
                                 origin: NSPoint(x: max(0, origin.x - minimum.x), y: max(0, origin.y - minimum.y)))
        }

        func minimumScrollOrigin() -> NSPoint {
            guard let clip = scroll?.contentView else { return .zero }
            var proposed = clip.bounds
            proposed.origin = NSPoint(x: -10_000_000, y: -10_000_000)
            return clip.constrainBoundsRect(proposed).origin
        }

        func scheduleHighlight() {
            highlightTask?.cancel()
            guard let text else { return }
            let snapshot = text.string
            let selectedLanguage = language
            let id = draftID
            tokens = []
            text.layoutManager?.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: (snapshot as NSString).length))
            guard selectedLanguage != .plain, snapshot.utf8.count <= Highlighter.limit else { return }
            highlightTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                let result = await Task.detached(priority: .utility) { Highlighter.tokens(in: snapshot, language: selectedLanguage) }.value
                guard !Task.isCancelled, let self, self.draftID == id else { return }
                self.tokens = result
                self.applyColors()
            }
        }

        func applyColors() {
            guard let text, let layout = text.layoutManager, let container = text.textContainer,
                  !tokens.isEmpty else { return }
            let glyphs = layout.glyphRange(forBoundingRect: text.visibleRect, in: container)
            let visible = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            let count = (text.string as NSString).length
            for token in tokens where NSMaxRange(token.range) <= count && NSIntersectionRange(visible, token.range).length > 0 {
                let color: NSColor
                switch token.kind {
                case .keyword: color = .systemPurple
                case .string: color = .systemGreen
                case .comment: color = .secondaryLabelColor
                case .number: color = .systemOrange
                case .heading: color = .systemBlue
                case .tag: color = .systemTeal
                }
                layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: token.range)
            }
        }
    }
}

final class LineNumberRuler: NSRulerView {
    weak var textView: NSTextView?
    var starts = [0]
    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 52
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func rebuild() {
        guard let textView else { return }
        starts = LineMap.starts(in: textView.string)
        ruleThickness = max(52, CGFloat(String(starts.count).count * 8 + 24))
        needsDisplay = true
    }

    func lineIndex(at offset: Int) -> Int {
        LineMap.index(at: offset, starts: starts)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let text = textView, let layout = text.layoutManager, let container = text.textContainer else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let glyphRange = layout.glyphRange(forBoundingRect: text.visibleRect, in: container)
        let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let first = lineIndex(at: charRange.location)
        let last = min(starts.count - 1, lineIndex(at: NSMaxRange(charRange)) + 1)
        let current = lineIndex(at: text.selectedRange().location)
        let length = (text.string as NSString).length
        for index in first...max(first, last) {
            let offset = starts[index]
            let lineRect: NSRect
            if offset == length {
                lineRect = layout.extraLineFragmentRect
            } else {
                let glyph = layout.glyphIndexForCharacter(at: offset)
                lineRect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            }
            let y = convert(NSPoint(x: 0, y: lineRect.minY + text.textContainerOrigin.y), from: text).y + 3
            let label = String(index + 1) as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: font,
                .foregroundColor: index == current ? NSColor.labelColor : NSColor.tertiaryLabelColor]
            label.draw(at: NSPoint(x: ruleThickness - label.size(withAttributes: attrs).width - 12, y: y), withAttributes: attrs)
        }
    }
}
