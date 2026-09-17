#if APP_STORE
import AppKit
import Carbon

/// Registers only the chosen shortcut; does not observe other keyboard events.
/// No Accessibility or Input Monitoring permission is required.
@MainActor
final class QuickCaptureShortcut {
    enum Status: Equatable { case ready, needsPermission, unavailable }
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static let signature: OSType = 0x4A575350 // JWSP

    init(action: @escaping () -> Void) { self.action = action }

    func start() -> Status {
        if hotKey != nil { return .ready }
        if handler == nil {
            // A release event captures once per press, avoiding key-repeat drafts.
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyReleased))
            let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard result == noErr, identifier.signature == 0x4A575350, identifier.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                MainActor.assumeIsolated {
                    let shortcut = Unmanaged<QuickCaptureShortcut>.fromOpaque(context).takeUnretainedValue()
                    // Keep clipboard work out of the Carbon event callback.
                    DispatchQueue.main.async { [weak shortcut] in shortcut?.action() }
                }
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard result == noErr else { return .unavailable }
        }
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey),
                                        identifier, GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            hotKey = nil
            return .unavailable
        }
        return .ready
    }

    func requestPermission() { _ = start() }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
#endif
