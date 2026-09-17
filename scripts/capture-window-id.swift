// Read only the approved Jotwisp process's window metadata for screencapture.
import Foundation
import CoreGraphics

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    fatalError("Usage: swift scripts/capture-window-id.swift JOTWISP_PID")
}
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where window[kCGWindowOwnerPID as String] as? Int32 == pid {
    guard window[kCGWindowLayer as String] as? Int == 0 else { continue }
    let summary: [String: Any] = [
        "windowID": window[kCGWindowNumber as String] ?? 0,
        "title": window[kCGWindowName as String] ?? "",
        "bounds": window[kCGWindowBounds as String] ?? [:]
    ]
    let data = try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
}
