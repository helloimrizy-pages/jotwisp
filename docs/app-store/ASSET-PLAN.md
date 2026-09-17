# Release media plan

## Visual direction

Quiet, precise, Mac-native. Warm white, ink, and Jotwisp periwinkle. Large restrained
typography, soft movement, generous space. No people, device mockups, fictional UI,
AI-generated app screens, ratings, awards, or specific prices in the video.

## Deliverables

1. Mac screenshots at 2560 × 1600, PNG: drafts/table, global search, code, capture.
   Use only the real app with fictional demo content. Preserve legible UI and
   include the actual app interface in each composition.
2. App Store preview: 1920 × 1080, 30 fps, 15–30 seconds, H.264 High ≤4.0,
   target 10–12 Mbps. Real app recordings with readable explanatory overlays,
   straightforward cuts/dissolves, no simulated features. No voiceover required.
3. A separate 24-second commercial: logo-led native Higgsfield motion graphics,
   precise type, real screenshots where appropriate, and an original ambient bed.
   This more expressive cut is for launch promotion, not a substitute for the
   footage-first App Store preview.

## Story

- Catch a thought: paste plain text into a draft.
- Keep the useful bits: a table retains its plain-text columns and line numbers.
- Find it again: search across the demo library.
- Pick up where you left off: restored drafts and a quiet, local workspace.
- End: Jotwisp — A quiet home for your text.

## Release gates

- Inspect every screenshot and representative frames, including transitions.
- Verify dimensions, duration, frame rate, codec, audio and file size with ffprobe.
- Keep raw captures, edit source, output masters and a provenance manifest.
- Do not upload screenshots containing personal drafts, other apps, account pages,
  desktop notifications, or private information.
- App Store preview acceptance is decided by Apple; a successful render is not approval.

References checked September 17, 2026:

- https://developer.apple.com/app-store/app-previews/
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
