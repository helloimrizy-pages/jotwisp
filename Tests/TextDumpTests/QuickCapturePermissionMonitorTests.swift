import XCTest
@testable import TextDump

final class QuickCapturePermissionMonitorTests: XCTestCase {
    @MainActor func testGrantWhileSettingsIsActiveRetriesAndStopsPolling() async {
        var permission: QuickCaptureShortcut.Status = .needsPermission
        var states: [QuickCaptureShortcut.Status] = []
        let ready = expectation(description: "Grant recognized without app activation")
        let monitor = QuickCapturePermissionMonitor(interval: 0.02, check: { permission }) {
            states.append($0)
            if $0 == .ready { ready.fulfill() }
        }
        monitor.refresh()
        XCTAssertTrue(monitor.isPolling)
        monitor.refresh()
        XCTAssertEqual(states, [.needsPermission])
        permission = .ready
        await fulfillment(of: [ready], timeout: 2)
        XCTAssertEqual(states, [.needsPermission, .ready])
        XCTAssertFalse(monitor.isPolling)
    }

    @MainActor func testTapFailureKeepsRetryingAndRevocationRestartsPolling() {
        var current: QuickCaptureShortcut.Status = .unavailable
        var states: [QuickCaptureShortcut.Status] = []
        let monitor = QuickCapturePermissionMonitor(check: { current }) { states.append($0) }
        monitor.refresh()
        XCTAssertTrue(monitor.isPolling)
        current = .ready
        monitor.refresh()
        XCTAssertFalse(monitor.isPolling)
        current = .needsPermission
        monitor.refresh()
        XCTAssertTrue(monitor.isPolling)
        XCTAssertEqual(states, [.unavailable, .ready, .needsPermission])
    }
}
