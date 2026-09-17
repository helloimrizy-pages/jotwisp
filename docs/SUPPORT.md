# Jotwisp support

Email [rizy.izy15@gmail.com](mailto:rizy.izy15@gmail.com).
Include your Jotwisp version, macOS version, Mac model, and the steps that
reproduce the issue. Use made-up text in screenshots and bug reports.
Never send passwords, payment information, or your full draft library.

## Getting started

- New draft: Command-N. Drafts save automatically after a short pause.
- Search all drafts: Command-Shift-F. Search this draft: Command-F.
- Capture copied text: File → New Draft from Clipboard.
- Word wrap: the toolbar wrap button, or Command-Option-W.
- Export a copy: File → Export Draft. Imported UTF-8 files become local drafts.
- Restore a deleted draft from Trash. Permanent deletion requires confirmation.

Plain-text spacing is preserved. Jotwisp does not render rich-text or Markdown
tables, attachments, or images. Wrapped visual rows share a logical line number.
Undo history resets when switching drafts and is not restored after quitting.

## Saving problems

If the status says “Couldn't save”, keep the app open, export important text,
check available disk space and permissions, then choose Retry save. Do not
force-quit before saving or exporting. Back up your Mac regularly; local autosave
is not a version-history or cloud-backup service.

## Switching from a source build to the App Store edition

The App Store edition keeps its library inside the macOS sandbox. A source
build normally uses `~/Library/Application Support/Text Dump/` (the original
folder name is retained for compatibility). The libraries are separate.
Export drafts from the old edition and import them into the new one. Keep
the original library until you have verified the imported copies. Never
move or edit library files while either app is running.

## Shortcut problems

In the Mac App Store edition, copy text, then press **Control–Option–V** from
any app while Jotwisp is running. It creates a new draft from the clipboard.

If another app owns the capture shortcut, quit that app or change its shortcut
and retry. File → New Draft from Clipboard always provides a manual alternative.
Copy text first; images or an empty clipboard cannot create a text draft.

Source builds using Command+C+D need Accessibility access. After a local
rebuild, macOS may still recognize the old build: remove the stale entry in
System Settings → Privacy & Security → Accessibility and add the current copy.
The sandboxed Mac App Store edition does not need this permission.

## Purchases

The planned Mac App Store edition is a US$9.99 one-time purchase, with regional
pricing set by Apple. It is not yet available for purchase. No subscription or
in-app purchases are planned for this release. Once available, Apple manages
downloads, updates, billing, and refund requests through the purchasing Apple
Account. Source code is available under the MIT license; building it yourself
does not require an App Store purchase.
