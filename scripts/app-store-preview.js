// Real, window-only footage of the signed sandbox build. Render with Higgsedit.
// Sources are cropped only to remove macOS recording chrome and window shadows.
export default async ({ project, text, rect }) => {
  const p = await project({ dir: "preview", size: "1920x1080", fps: 30, background: "#f4f4f7" });
  const scenes = [
    { file: "drafts-source.mp4", at: 0, dur: 6,
      heading: "Keep the useful bits.", detail: "Plain-text tables. Line numbers. Local autosave." },
    { file: "search-source.mp4", at: 6, dur: 12,
      heading: "Find it across every draft.", detail: "Search titles and text from one simple sidebar." },
    { file: "code-source.mp4", at: 18, dur: 6,
      heading: "A little room to think.", detail: "Notes, tables, and code — together in Jotwisp." }
  ];
  for (const scene of scenes) {
    const footage = await p.add(scene.file);
    p.cut(footage, { from: 0, at: scene.at, dur: scene.dur, fit: "contain" });
    // Explanatory overlay lies in unused editor space, not over app controls.
    p.compose([
      rect({ x: 506, y: 830, width: 1220, height: 158, radius: 18, fill: "#f5f5fb" }),
      rect({ x: 536, y: 863, width: 4, height: 90, radius: 2, fill: "#6670dc" }),
      text(scene.heading, { x: 570, y: 853, width: 1110, height: 64,
        fontFamily: "Inter", fontSize: 43, fontWeight: 600, color: "#252630" }),
      text(scene.detail, { x: 571, y: 922, width: 1110, height: 45,
        fontFamily: "Inter", fontSize: 25, color: "#747888" })
    ], { at: scene.at, dur: scene.dur, name: scene.heading });
  }
  for (const time of [2, 7, 12, 17.9, 18, 22]) {
    await p.frame(time, `renders/check-${time}.png`);
  }
  await p.render("renders/app-preview-silent.mp4", { depth: 8, bitrate: 11000000, concurrency: 2 });
};
