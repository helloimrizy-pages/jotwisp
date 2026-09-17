// Native Higgsedit composition. Render in Higgsfield's media sandbox.
// This is a promotional motion-graphics cut, not the App Store footage preview.
export default async ({ project, text, rect, media, frame, path }) => {
  const p = await project({ dir: "commercial", size: "1920x1080", fps: 30, background: "#edeef2" });
  const logo = await p.add("logo.png");
  const ink = "#242630", violet = "#6070dd", muted = "#787d8b";
  const enter = (delay = 0) => ({
    enter: { from: { y: 32, opacity: 0 }, duration: 0.8, at: delay, easing: "house" },
    exit: { to: { y: -12, opacity: 0 }, duration: 0.45, anchor: "end", easing: "smooth" }
  });
  const title = (s, y, size = 108, color = ink) => text(s, {
    x: 160, y, width: 1600, height: size * 1.4, fontFamily: "Inter",
    fontSize: size, fontWeight: 600, letterSpacing: -3, align: "center", color
  });
  const small = (s, y) => text(s, { x: 200, y, width: 1520, height: 65,
    fontFamily: "Inter", fontSize: 30, fontWeight: 400, align: "center", color: muted });
  const scene = (name, at, dur, children) => p.compose(
    frame({ name, width: 1920, height: 1080, layout: "none", motion: enter() }, children),
    { name, at, dur });

  // 01 / The mark arrives quietly, then the name.
  scene("A quiet beginning", 0, 5.5, [
    media({ file: logo, x: 762, y: 150, width: 396, height: 396, fit: "contain",
      animate: [{ property: "scale", from: 0.92, to: 1, duration: 1.2, easing: "house" }] }),
    title("Jotwisp", 548, 102),
    small("A quiet home for your text.", 698),
    rect({ x: 932, y: 816, width: 56, height: 3, radius: 1.5, fill: violet })
  ]);

  // 02 / These are abstract paper notes, not a fabricated app interface.
  const paper = (x, y, heading, detail, delay) => frame({
    name: heading, x, y, width: 470, height: 280, layout: "none", radius: 24,
    background: "#fafbfe", shadow: { y: 14, blur: 36, color: "#272b5012" },
    motion: { enter: { from: { y: 60, opacity: 0, scale: 0.97 }, at: delay, duration: 0.85, easing: "house" } }
  }, [
    rect({ x: 38, y: 42, width: 30, height: 4, radius: 2, fill: violet }),
    text(heading, { x: 38, y: 85, width: 394, height: 65, fontFamily: "Inter", fontSize: 40, fontWeight: 600, color: ink }),
    text(detail, { x: 38, y: 167, width: 394, height: 76, fontFamily: "Inter", fontSize: 25, color: muted })
  ]);
  scene("Catch the useful bits", 5.5, 6, [
    title("Catch the useful bits.", 135, 98),
    small("Thoughts. Snippets. Answers worth keeping.", 278),
    paper(215, 455, "A thought.", "Make room for small ideas.", 0.10),
    paper(725, 405, "A snippet.", "A few lines worth saving.", 0.24),
    paper(1235, 455, "An answer.", "The part you want to keep.", 0.38)
  ]);

  // 03 / Type and highlight are authored vector motion, not generated lettering.
  scene("Find it again", 11.5, 5.5, [
    title("Less searching.", 208, 108),
    title("More finding.", 355, 108, violet),
    small("Search across every draft.", 572),
    path({ d: "M 0 0 L 580 0", x: 670, y: 718, width: 580, height: 2,
      stroke: { color: violet, width: 2, cap: "round" },
      animate: [{ property: "scaleX", from: 0.01, to: 1, at: 0.5, duration: 0.8, easing: "house" }] })
  ]);

  // 04 / No price or false availability claim; suitable for a pre-release launch kit.
  scene("Room for your thoughts", 17, 7, [
    media({ file: logo, x: 230, y: 295, width: 450, height: 450, fit: "contain" }),
    text("Jotwisp", { x: 805, y: 314, width: 900, height: 160, fontFamily: "Inter",
      fontSize: 112, fontWeight: 600, letterSpacing: -4, color: ink }),
    text("A little room to think.", { x: 813, y: 502, width: 920, height: 90,
      fontFamily: "Inter", fontSize: 43, color: muted }),
    text("NATIVE MAC APP   /   LOCAL DRAFTS   /   OPEN SOURCE", {
      x: 815, y: 667, width: 1000, height: 50, fontFamily: "Inter", fontSize: 19,
      fontWeight: 600, letterSpacing: 1.4, color: violet })
  ]);
  for (const [t, name] of [[2.5, "brand"], [8.5, "notes"], [14, "search"], [21, "end"]]) {
    await p.frame(t, `renders/${name}.png`);
  }
  await p.render("renders/commercial-silent.mp4", { depth: 8, concurrency: 2, bitrate: 11000000 });
};
