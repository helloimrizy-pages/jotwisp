import Foundation

enum Distribution {
    #if APP_STORE
    static let isAppStore = true
    static let shortcutLabel = "⌃⌥V"
    #else
    static let isAppStore = false
    static let shortcutLabel = "⌘C+D"
    #endif
    static let sourceURL = URL(string: "https://github.com/helloimrizy-pages/jotwisp")!
    static let privacyURL = URL(string: "https://github.com/helloimrizy-pages/jotwisp/blob/main/docs/PRIVACY.md")!
    static let supportURL = URL(string: "mailto:rizy.izy15@gmail.com?subject=Jotwisp%20support")!
}
