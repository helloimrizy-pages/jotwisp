# Jotwisp development guide

A small native macOS scratchpad for text, tables, code, and the useful bits you want to keep. Drafts save themselves, and search looks through the entire library.

## Run

Run these commands from the repository root. Requires macOS 14 or later and Xcode's Swift tools. The source script builds for the host architecture; the Xcode App Store target builds a universal app.

To rebuild from source with Xcode's Swift tools:

```sh
bash scripts/build.sh
open "build/Jotwisp.app"
```

The build script produces a locally signed app bundle. It has no third-party dependencies, browser runtime, account, or network services. The bundle is not notarized for public distribution.

## Everyday use

- **New draft:** `⌘N`. Start typing or paste text. The first nonempty line becomes the title.
- **Quick capture from any app:** hold **Command + C**, then tap **D** while still holding both. Jotwisp comes forward with the current clipboard text in a new, automatically saved draft. Jotwisp must be running (its window may be closed or minimized). Ordinary `⌘C` and `⌘D` retain their normal behavior.
- **Search everything:** `⌘⇧F`. Matches titles and contents, ignoring case. Click a result or press Return to select the first match in that draft. Clear the search to see your full library again.
- **Find in this draft:** `⌘F`. Use `⌘⌥F` for find/replace, `⌘G` for the next occurrence, and `⌘⇧G` for the previous one.
- **Rename:** click the editor title or right-click a sidebar row. An empty custom title returns to automatic naming.
- **Code:** choose a language at the bottom right. Plain Text is the default.
- **Wrap:** text wraps to the available editor width by default and reflows when you resize the window or sidebar. Existing drafts also switch to this default on their first load after the update. For wide tables or code, you can turn wrapping off for a draft with the top-right wrap button or `⌘⌥W`.
- **Import:** `⌘O`, including multiple files. UTF-8 text files become independent drafts; their extensions set the language.
- **Export:** `⌘⇧S`. This writes a copy to a location you choose.
- **Trash:** use the draft's `…` menu or its sidebar context menu. Restore deleted drafts from the Trash view. Permanent deletion requires confirmation.
- **Save now:** `⌘S` flushes the current state without a filename prompt. Normal edits save after a 350 ms pause, and closing or quitting flushes pending changes.

The sidebar width is adjustable by dragging its divider. The app follows macOS light/dark appearance and restores the window frame, selected draft, cursor/selection, and scroll position. Closing the window keeps the app running; click its Dock icon to reopen it.

### Enable quick capture once

The literal two-letter **⌘C+D** chord requires Accessibility access. Click **Set up…** in the app (or **File → Enable Quick Capture…**), then enable **Jotwisp** in **System Settings → Privacy & Security → Accessibility**. If it is not listed, add `build/Jotwisp.app` using the `+` button. Jotwisp checks every two seconds while waiting, even when Settings is frontmost, and removes the banner only once its keyboard shortcut is working. Polling stops once ready. No Accessibility access is needed for **File → New Draft from Clipboard**.

If the entry is already enabled but the banner remains, remove the old entry (which may still be named Text Dump) with `−` and add the current app again with `+`. **Set up… → Show App in Finder** locates the exact running copy. Quit and reopen Jotwisp if macOS still doesn’t recognize access. This does not affect drafts. Ad-hoc signing ties an app’s identity to that particular build, so rebuilding can leave a stale grant. See [Apple’s code signing requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

For builds that retain their signing identity across updates, use an existing valid signing certificate consistently: `TEXTDUMP_SIGNING_IDENTITY="Your signing identity" bash scripts/build.sh`. Without this setting, the build remains ad-hoc signed and warns about possible permission renewal. The script never changes system permissions or creates certificates.

Only an explicit capture reads clipboard text; the app does not keep clipboard history. Empty or non-text clipboards show a message and leave existing drafts intact. Rebuilding or moving a locally signed development app may require re-enabling its Accessibility entry.

## Your data

Jotwisp is the renamed Text Dump app. The existing `app.textdump.mac` bundle identifier, library folder, and window-state key are deliberately unchanged, so existing drafts and settings are reused without migration. Internal Swift module names and `TEXTDUMP_*` development options also remain compatible.

The library lives in:

```text
~/Library/Application Support/Text Dump/
```

Each draft has a UUID-named `.txt` content file and `.json` metadata file; `session.json` stores the workspace selection and sidebar width. Trash status is metadata, so trashed text remains recoverable until permanently deleted. Window geometry is stored in macOS app preferences.

Content and metadata files are individually replaced atomically. Missing first-save metadata can be recovered from an orphaned content file. Unreadable metadata is reported and preserved, rather than silently overwritten. If a write fails, the draft stays in memory and the app offers **Retry save**; you can also export it. Normal quitting warns if unsaved text remains.

Back up this folder along with your other files. Autosave is local storage, not cloud sync or version history. A power loss or crash can lose the most recent unsaved typing. Avoid modifying library files while the app is running; use import/export for external files.

## Branding

The approved folded-paper Jotwisp logo is in `Resources/Branding/jotwisp-logo-concept-v1.png`. The icon export script preserves the artwork and packages its tile into transparent macOS icon sizes from 16 to 1024 pixels. The same bundled icon is used in the sidebar and by macOS. `scripts/build.sh` regenerates it whenever the source artwork or exporter changes.

## Implementation

SwiftUI provides the workspace and AppKit/TextKit provides the plain-text editor, undo, find/replace, text layout, and line-number ruler. Disk writes use a serial queue. Global search and syntax tokenization run off the main thread with debouncing and stale-result checks.

Search returns one result per matching draft and jumps to its first content match. Use local find to navigate additional occurrences. It searches literal text, not regular expressions. Syntax highlighting is a lightweight lexical aid for Markdown, JSON, JavaScript, TypeScript, Python, Swift, HTML, CSS, and shell; it is not a language server. Highlighting pauses above 1 MB, while editing and search remain available. Only visible syntax colors are applied.

The editor preserves plain text and existing spacing; it does not render Markdown or reconstruct spacing that the source application omitted. Undo/redo is available while editing a draft; switching drafts clears the native undo history. Draft contents and editor positions persist across launches, but undo history does not.

## Verify

```sh
bash scripts/test.sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" swift scripts/verify-bundle.swift
```

Tests cover persistence, automatic and custom titles, Unicode and Windows line endings, search scope/ranges, Trash, corruption recovery, write failures and retry, asynchronous autosave, stale search cancellation, and a 1,001-draft benchmark.

See [VERIFICATION.md](../VERIFICATION.md) for verification status and first-version limits.

For an isolated manual test library, launch the executable directly:

```sh
TEXTDUMP_DATA_DIR="$PWD/build/my-test-library" \
TEXTDUMP_BENCHMARK=1 \
"build/Jotwisp.app/Contents/MacOS/Jotwisp"
```

`TEXTDUMP_BENCHMARK=1` prints the time from application initialization to the window being ready. To retain the performance fixture for launch testing, set `TEXTDUMP_BENCHMARK_DIR` to a new empty directory when running the tests. Use separate directories for test fixtures and everyday drafts.

With `TEXTDUMP_DATA_DIR` set, `TEXTDUMP_TEST_APPEARANCE=dark` or `light` provides an app-only appearance override for visual QA. Ordinary launches always follow macOS.
