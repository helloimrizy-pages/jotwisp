import XCTest
import TextDumpCore

final class CaptureChordTests: XCTestCase {
    func testCopyPassesThroughAndHeldCommandCThenDTriggersOnce() {
        var chord = CaptureChord()
        XCTAssertEqual(chord.keyDown(CaptureChord.cKey, commandOnly: true, isRepeat: false), .passThrough)
        XCTAssertEqual(chord.keyDown(CaptureChord.dKey, commandOnly: true, isRepeat: false), .capture)
        XCTAssertEqual(chord.keyDown(CaptureChord.dKey, commandOnly: true, isRepeat: true), .suppress)
        XCTAssertEqual(chord.keyUp(CaptureChord.dKey), .suppress)
        XCTAssertEqual(chord.keyUp(CaptureChord.cKey), .passThrough)
    }

    func testOrdinaryCommandDAndSequentialCopyThenCommandDRemainUnchanged() {
        var chord = CaptureChord()
        XCTAssertEqual(chord.keyDown(CaptureChord.dKey, commandOnly: true, isRepeat: false), .passThrough)
        _ = chord.keyDown(CaptureChord.cKey, commandOnly: true, isRepeat: false)
        _ = chord.keyUp(CaptureChord.cKey)
        XCTAssertEqual(chord.keyDown(CaptureChord.dKey, commandOnly: true, isRepeat: false), .passThrough)
    }

    func testTypingCDAndOtherModifierCombinationsDoNotCapture() {
        var chord = CaptureChord()
        _ = chord.keyDown(CaptureChord.cKey, commandOnly: false, isRepeat: false)
        XCTAssertEqual(chord.keyDown(CaptureChord.dKey, commandOnly: false, isRepeat: false), .passThrough)
        chord.reset()
        XCTAssertEqual(chord.keyDown(CaptureChord.dKey, commandOnly: true, isRepeat: false), .passThrough)
    }
}
