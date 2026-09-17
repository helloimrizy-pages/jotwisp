# Release media status — September 17, 2026

## Launch commercial

Rendered in Higgsfield with native Higgsedit motion graphics, using the approved
Jotwisp logo, authored text and abstract paper cards. No people or simulated app UI.
This is a promotional film, **not the footage-based App Store preview**.

- Master: `build/release-media/video/jotwisp-launch-commercial.mp4`
- Editable archive: `build/release-media/video/commercial-project.zip`
- Composition source: `scripts/launch-commercial.js`
- Contact sheet: `build/release-media/video/commercial-contact-sheet.png`
- Transition checks: `build/release-media/video/commercial-transitions.png`
- 24.000 seconds; 1920 × 1080; 30 fps; H.264 High level 4.0; AAC stereo 48 kHz.
- File size: 3,136,009 bytes. Encoding target is not actual average bitrate:
  ffprobe reports about 897 kb/s video and 138 kb/s audio for this sparse animation.
- Original synthesized ambient bed; no third-party music or voice.
- Main scenes and twelve transition/end frames visually inspected: no cropped
  text, overlapping elements or personal content observed.
- Audio measured: mean −34.8 dBFS, peak −26.8 dBFS; no clipping detected.
  Listening review remains advisable before publishing.

SHA-256 master: `7f0bd3fcce70f866080ca050516b21287247707cb5b782bd5da69fa83a4e4bcc`

SHA-256 project archive: `abd7403e0d2790b97b0fc9f6026447c5b4fc6217452452391e8594f65a8f1094`

## Actual app media

The signed sandbox build is running with fictional demo drafts, separate
from the everyday app's existing library. Table alignment, local autosave,
cross-draft search and Swift highlighting have been visually checked. The owner
verified that a physical Control–Option–V from Finder creates a new draft from
the fictional clipboard text. Automated app-targeted keypress did not trigger
the global shortcut; this was not treated as a successful test.

Window-only capture is now working after the owner enabled Screen Recording for
Visual Studio Code (the command host). Initial black video tests were rejected;
bringing Jotwisp onto the current desktop fixed video capture. No desktop, other
apps or audio were recorded. Three native 2560 × 1600 screenshots and three usable
footage excerpts are in `docs/media/release/`. Raw captures remain local.
The App Store preview is being assembled with `scripts/app-store-preview.js`.
Full release QA is still pending.

## Store preparation

App Store Connect record: `6813066064`, version `1.1.0`.
Listing copy, review notes, owner-approved private review contact and manual
release choice were saved. Subtitle and Productivity category were saved.
The public GitHub privacy policy was verified accessible and saved as the policy URL.
US$9.99 base pricing was confirmed with Apple's regional equivalents.
The owner approved keeping Apple's education volume-purchase discount enabled;
the enabled setting was verified in App Store Connect. Availability still needs
an owner choice.
Private review contact details belong only in App Store Connect, not this repo.

Store media upload, footage preview rendering, build upload, final QA and owner compliance
declarations remain pending. Nothing has been submitted for review or released.
