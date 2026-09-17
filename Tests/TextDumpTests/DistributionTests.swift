import XCTest
@testable import TextDump

final class DistributionTests: XCTestCase {
    func testEditionShortcut() {
        #if APP_STORE
        XCTAssertTrue(Distribution.isAppStore)
        XCTAssertEqual(Distribution.shortcutLabel, "⌃⌥V")
        #else
        XCTAssertFalse(Distribution.isAppStore)
        XCTAssertEqual(Distribution.shortcutLabel, "⌘C+D")
        #endif
    }

    func testPublicContactConfiguration() {
        XCTAssertEqual(Distribution.sourceURL.absoluteString,
                       "https://github.com/helloimrizy-pages/jotwisp")
        XCTAssertEqual(Distribution.privacyURL.lastPathComponent, "PRIVACY.md")
        XCTAssertEqual(Distribution.supportURL.scheme, "mailto")
        XCTAssertTrue(Distribution.supportURL.absoluteString.contains("rizy.izy15@gmail.com"))
    }
}
