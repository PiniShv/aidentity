# Dashboard components

The dashboard adapts retrieved 21st.dev component source to dependency-free vanilla JavaScript and CSS. The CLI remains the source of profile data and operations. React, Radix, Base UI, Tailwind, Motion, and Lucide runtime dependencies were replaced with native elements, inline SVG, a 2D canvas, CSS, and Web Animations.

| UI category | Retrieved component | Adaptation |
| --- | --- | --- |
| Navigation | [Animated Sidebar by starc007](https://21st.dev/@starc007/components/animated-sidebar), demo 29334 | Desktop collapsed rail, animated labels, keyboard shortcut, mobile sheet, focus trap, Escape and focus restoration. |
| Dialogs | [Animated Dialog by rmahammad](https://21st.dev/@rmahammad/components/animated-dialog), demo 26905 | Native modal dialog with scale/slide animation, fixed header/footer, scrollable body, mobile bottom sheet and reduced motion. |
| Profile cards | [Animated Profile Card by ravikatiyar162](https://21st.dev/@ravikatiyar162/components/animated-profile-card), demo 8206 | App tile with the profile badge at its corner, name/app line, state, configuration metadata, a hover border in the app's hue (no lift) and full-width action. Human profile data and photographs replaced by actual launcher identities. |
| Tabs | [Animated Tabs by educalvolpz](https://21st.dev/@educalvolpz/components/animated-tabs), demo 24930 | Sliding underline measured from the active tab, Arrow/Home/End navigation and roving keyboard focus. |
| Inputs/search | [Input by Origin UI](https://21st.dev/@originui/components/input), demo 159 | Leading search icon, trailing clear action, focus ring, input sizing and accessible labels. |
| Buttons | [Button by Origin UI](https://21st.dev/@originui/components/button), demo 146 | Primary, outline, secondary and destructive variants with a loading overlay that preserves button size. |
| Loading | [Button Spinner by uiable](https://21st.dev/@uiable/components/uiable-spinner-button), demo 19975 | CSS border spinner inside pending actions with visible text and `aria-busy`. |
| Notifications | [Toast by cnippet-dev](https://21st.dev/@cnippet-dev/components/toast), demo 24297 | Stacked status notifications, entrance/exit transitions, hover pause, timed dismissal, dismiss and activity actions. |
| Background | [Background ASCII Dither by nikolas-sapa](https://21st.dev/@nikolas-sapa/components/background-ascii-dither), demo 32067 | One fixed canvas under the whole dashboard in the component's ascii mode: its noise, glyph ramp and pointer boost at 14px cells and a 140px radius. The noise picks only the glyph, without the original's gamma or per-glyph alpha: every glyph is Bone at a flat 12%, so brightness is glyph density and the pointer shows as denser glyphs. The loop runs at 30fps at most and pauses while the tab is hidden. Reduced motion draws one still frame; increased contrast and forced colors hide the canvas. Added for aidentity: an `aidentity:ripple` event from app.js (a profile opened from the dashboard, added, restored or imported, and a reconnect) lifts the glyph density in one ring that spreads from that control and fades, inside the same loop; it is ignored whenever the loop is not running. The image source, the dither and dot modes and the theme observer were dropped. |
| Application folders | [Glassmorphism Folder Cards by kedhareswer](https://21st.dev/@kedhareswer/components/glass-folder-cards), demo 37625 | Each app on Applications is a folder: the component's back panel, files and frosted front panel (its clip paths, corners brought to 20px), the hover lean on a bottom hinge, the open fan, the + and ··· keys, its keyboard-driven menu and the drop-in for a new file. The files are the app's profiles, each a button that opens the profile on Profiles; their name strips are measured so whole names show, and the folder reserves its open fan's height. Dropped: the generated canvas artwork and its shared painter (the back is translucent graphite), the milk-glass tone, the scroll-in assembly, the label placements and the paper lines. The springs are critically damped, so the drop and the pocket's give lose their rebound; the pointer lean needs a fine pointer; the menu holds the app's own actions; the glass turns solid under reduced transparency, increased contrast and forced colors and without `backdrop-filter`; a closed folder's files show no badge, running mark or name, since nothing colored (and no name cut by the glass) sits under it, and the running count sits on the glass beside "N profiles" instead. |
| Explore preview | None; written for this dashboard | The focus panel shows the selected app's profiles side by side as keys (badge, status, Original mark, Open or Bring to front), and a list beside it picks the app. The app identity crossfades in 160ms, with a static swap under reduced motion. Nothing switches apps on scroll. |
| Icons | [Hugeicons](https://21st.dev/community/icons/hugeicons) free set: `@hugeicons/core-free-icons` 4.4.0 ([hugeicons/hugeicons](https://github.com/hugeicons/hugeicons), MIT) | Every UI icon in `iconPaths` (app.js) is a stroke-rounded Hugeicons path copied inline: 24px grid, 1.5 stroke, `currentColor`, coordinates rounded to two decimals. App tiles use its Claude, ChatGPT, Chrome, Slack, Notion, Visual Studio Code and Arc marks; Cursor, Edge and Brave have none in the free set and keep the dashboard's own marks. Only path data was copied: the package is not a dependency and nothing loads at runtime. |

The workspace uses near-black surfaces (`#060606`, `#0c0c0c`), warm-white text
(`#f3f2ee`), muted gray (`#8d8b84`) and mint/cyan/blue accents. These color values
are bundled; no external board or configuration file is read at runtime.
Each app that has profiles gets one color, used in its navigation marker, card
highlights, preview and contextual controls. Apps with no profiles stay gray. Each section of the dashboard also has its own deep
tile color, on its sidebar row, beside its page title and on its operation cards.
Actual account badge colors remain user-controlled.
Placement, sizing and motion were refined using the
[Apple design skill](https://github.com/dickwu/apple-design-skill), particularly
Apple's [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
and [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
guidance. That skill is a design reference, not a build or runtime dependency.

Every spring is critically damped (damping 1.0, a `linear()` curve sampled from
the spring), so nothing overshoots: controls settle in 340ms (a 0.25s response),
dialogs in 420ms and panels in 480ms (0.35s). The press is the only movement on a
control; hover changes fill and border (the Applications folders lean and lift). The activity panel leaves along the path it
entered by, and a click mid-flight reverses it from where it is. A re-targeted tab
underline or sidebar slide starts from its on-screen position. Explore changes app
with a 160ms crossfade. The fixed activity bar and panel and the phone top bar are a
translucent layer that turns solid under reduced transparency and increased
contrast. Reduced motion replaces springs and the crossfade with static,
keyboard-accessible content, and a press dims instead of scaling. These parameters
follow Emil Kowalski's apple-design motion skill and Apple's HIG Motion page; they
are aidentity's choices, not platform timings.

## Third-party notices

The icon path data in `dashboard/app.js` comes from `@hugeicons/core-free-icons` 4.4.0, under this license:

```text
MIT License

Copyright (c) 2025 Hugeicons

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
