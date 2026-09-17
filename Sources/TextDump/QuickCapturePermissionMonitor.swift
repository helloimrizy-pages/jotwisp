import Foundation

/// Permission prompts complete asynchronously, often while Settings is frontmost.
/// Retry without prompting; stop polling as soon as the shortcut actually works.
@MainActor
final class QuickCapturePermissionMonitor {
    private let check: () -> QuickCaptureShortcut.Status
    private let didChange: (QuickCaptureShortcut.Status) -> Void
    private let interval: TimeInterval
    private var timer: Timer?
    private(set) var status: QuickCaptureShortcut.Status?
    var isPolling: Bool { timer != nil }

    init(interval: TimeInterval = 2,
         check: @escaping () -> QuickCaptureShortcut.Status,
         didChange: @escaping (QuickCaptureShortcut.Status) -> Void) {
        self.interval = interval
        self.check = check
        self.didChange = didChange
    }

    func refresh() {
        let next = check()
        if next != status {
            status = next
            didChange(next)
        }
        if next == .ready {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = interval / 4
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    deinit { timer?.invalidate() }
}
