/// Tracks the physical C and D keys without intercepting ordinary Copy or Command-D.
public struct CaptureChord {
    public enum Result: Equatable { case passThrough, capture, suppress }
    public static let cKey: Int64 = 8
    public static let dKey: Int64 = 2
    private var cIsDown = false
    private var capturedDIsDown = false

    public init() {}

    public mutating func keyDown(_ key: Int64, commandOnly: Bool, isRepeat: Bool) -> Result {
        if key == Self.cKey { cIsDown = true }
        guard key == Self.dKey else { return .passThrough }
        if capturedDIsDown { return .suppress }
        guard cIsDown, commandOnly, !isRepeat else { return .passThrough }
        capturedDIsDown = true
        return .capture
    }

    public mutating func keyUp(_ key: Int64) -> Result {
        if key == Self.cKey { cIsDown = false }
        if key == Self.dKey && capturedDIsDown {
            capturedDIsDown = false
            return .suppress
        }
        return .passThrough
    }

    public mutating func reset() { cIsDown = false; capturedDIsDown = false }
}
