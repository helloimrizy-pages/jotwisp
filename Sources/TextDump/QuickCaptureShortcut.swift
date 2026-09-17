#if !APP_STORE
import AppKit
import ApplicationServices
import TextDumpCore

/// A two-letter chord cannot be registered as a standard macOS modifier+key hotkey.
/// This event tap passes all input through except D while Command and C are held.
@MainActor
final class QuickCaptureShortcut {
    enum Status: Equatable { case ready, needsPermission, unavailable }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var chord = CaptureChord()
    private let action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    func start() -> Status {
        guard AXIsProcessTrusted() else {
            stop()
            return .needsPermission
        }
        if let tap, CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) { return .ready }
        }
        stop()
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let shortcut = Unmanaged<QuickCaptureShortcut>.fromOpaque(context).takeUnretainedValue()
                return shortcut.handle(type: type, event: event)
            }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return .unavailable }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            stop()
            return .unavailable
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            stop()
            return .unavailable
        }
        return .ready
    }

    private func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        chord.reset()
    }

    func requestPermission() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if !AXIsProcessTrusted(), let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            chord.reset()
            if let tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let result: CaptureChord.Result
        switch type {
        case .keyDown:
            let modifiers = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            result = chord.keyDown(key, commandOnly: modifiers == .maskCommand,
                                   isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .keyUp:
            result = chord.keyUp(key)
        case .flagsChanged:
            if !event.flags.contains(.maskCommand) { chord.reset() }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
        switch result {
        case .capture:
            // Clipboard work and activation happen outside the event-tap callback.
            // Give the source app a moment to finish the normal Command-C copy.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in self?.action() }
            return nil
        case .suppress: return nil
        case .passThrough: return Unmanaged.passUnretained(event)
        }
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
    }
}
#endif
