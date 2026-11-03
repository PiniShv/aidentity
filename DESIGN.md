---
name: aidentity dashboard
description: Your account workspace, a local dark console over the aidentity CLI.
colors:
  lampblack: "#060606"
  surface: "#0c0c0c"
  raised: "#141413"
  active: "#1f1f1d"
  border: "#1c1c1b"
  control: "#262624"
  button-edge: "#4d4c48"
  field-border: "#6f6d66"
  card-top: "#0f0f0f"
  card-bottom: "#090909"
  tip: "#050505"
  material-bar: "#060606e0"
  material-panel: "#0c0c0ceb"
  scrim: "#00000099"
  glass-sheen: "#f3f2ee12"
  glass-rim: "#f3f2ee29"
  folder-shadow: "#000000a6"
  bone: "#f3f2ee"
  muted: "#8d8b84"
  mint: "#5fe08a"
  periwinkle: "#7c8cff"
  teal: "#2fd4c0"
  orange: "#ff8a3d"
  pink: "#ff6fb5"
  gold: "#ffd166"
  sky: "#4cc3ff"
  violet: "#b26bff"
  negative: "#ff6b5b"
  negative-bg: "#2a1210"
  danger-edge: "#8a2f26"
  warning: "#f7c15f"
  warning-bg: "#2a2412"
  tile-explore: "#5a56c7"
  tile-profiles: "#9c3b96"
  tile-apps: "#116bb5"
  tile-recovery: "#047879"
  tile-maintenance: "#aa5212"
  tile-transfer: "#137d41"
  tile-help: "#566577"
  tile-danger: "#b63132"
typography:
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "28px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.035em"
  headline-compact:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.035em"
  card:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "22px"
    fontWeight: 550
    lineHeight: 1.2
    letterSpacing: "-0.03em"
  card-compact:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "19px"
    fontWeight: 550
    lineHeight: 1.2
    letterSpacing: "-0.03em"
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "17px"
    fontWeight: 550
    lineHeight: 1.35
    letterSpacing: "-0.015em"
  title-compact:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "15px"
    fontWeight: 550
    lineHeight: 1.3
    letterSpacing: "-0.015em"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.55
  secondary:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "13px"
    fontWeight: 500
  meta:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "12px"
    fontWeight: 400
  mono:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "12px"
    lineHeight: 1.7
rounded:
  badge: "6px"
  control: "8px"
  section-tile-nav: "7px"
  section-tile-phone: "9px"
  section-tile: "10px"
  toast: "12px"
  tile: "12px"
  explore-panel: "14px"
  card: "16px"
  dialog: "20px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  gutter: "32px"
components:
  button:
    textColor: "{colors.bone}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: "36px"
    padding: "0 14px"
  button-primary:
    backgroundColor: "{colors.bone}"
    textColor: "{colors.lampblack}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    height: "36px"
    padding: "0 14px"
  button-primary-app:
    backgroundColor: "{colors.periwinkle}"
    textColor: "{colors.lampblack}"
    rounded: "{rounded.control}"
    height: "36px"
  button-secondary:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.bone}"
    rounded: "{rounded.control}"
    height: "36px"
  button-danger:
    textColor: "{colors.negative}"
    rounded: "{rounded.control}"
    height: "36px"
  button-small:
    typography: "{typography.label}"
    height: "36px"
    padding: "0 10px"
  input:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.bone}"
    rounded: "{rounded.control}"
    height: "40px"
    padding: "9px 12px"
  nav-item:
    textColor: "{colors.muted}"
    rounded: "{rounded.control}"
    height: "40px"
    padding: "0 12px"
  nav-item-active:
    textColor: "{colors.bone}"
  tab:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    height: "44px"
  tab-selected:
    textColor: "{colors.bone}"
  card:
    backgroundColor: "{colors.card-top}"
    rounded: "{rounded.card}"
    padding: "24px"
  profile-card:
    backgroundColor: "{colors.card-top}"
    rounded: "{rounded.card}"
    padding: "20px"
  detail-panel:
    backgroundColor: "{colors.card-top}"
    rounded: "{rounded.card}"
    padding: "24px"
    width: "320px"
  app-art:
    backgroundColor: "{colors.active}"
    rounded: "{rounded.tile}"
    size: "44px"
  section-tile:
    backgroundColor: "{colors.tile-maintenance}"
    textColor: "{colors.bone}"
    rounded: "{rounded.section-tile}"
    size: "36px"
  section-tile-nav:
    backgroundColor: "{colors.tile-maintenance}"
    textColor: "{colors.bone}"
    rounded: "{rounded.section-tile-nav}"
    size: "24px"
  badge:
    textColor: "{colors.lampblack}"
    rounded: "{rounded.control}"
    size: "34px"
  badge-tile:
    textColor: "{colors.lampblack}"
    rounded: "{rounded.badge}"
    size: "20px"
  explore-panel:
    backgroundColor: "{colors.card-top}"
    rounded: "{rounded.explore-panel}"
    padding: "18px"
  explore-key:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.tile}"
    padding: "12px"
  navigator-row:
    textColor: "{colors.bone}"
    rounded: "{rounded.tile}"
    height: "60px"
    padding: "10px 12px"
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.bone}"
    rounded: "{rounded.dialog}"
    width: "560px"
  toast:
    backgroundColor: "{colors.tip}"
    rounded: "{rounded.toast}"
    padding: "15px"
    width: "340px"
  folder:
    backgroundColor: "{colors.raised}"
    rounded: "{rounded.dialog}"
    width: "340px"
  folder-file:
    backgroundColor: "{colors.active}"
    textColor: "{colors.bone}"
    typography: "{typography.title-compact}"
    rounded: "{rounded.tile}"
    width: "272px"
  folder-key:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.bone}"
    rounded: "{rounded.tile}"
    size: "44px"
---

# Design System: aidentity dashboard

## Overview

**Creative North Star: "The Keyring"**

The dashboard is one dark ring that holds every profile. The ground is Lampblack, a warm near-black, under a slow ambient field of glyphs in Bone at 12%, and text is Bone. Color comes in two layers that never share a form. Apps: an app that has profiles gets one bright hue from a fixed seven-hue palette, and that app's primary action, dots, borders and focus rings carry it, as does its app tile when the app has no installed icon. Sections: each part of the dashboard owns one deep tile color, a rounded square with a Bone glyph, as in macOS System Settings. Apart from those two layers and status, nothing on screen is colored. There is no second hue for an app, no gradient in a hue and no glow. The one exception is the official aidentity logo, which keeps its own blue gradients and glow (The Upstream Logo Rule).

Density is a desktop tool's: a 14px base, 13px labels, a 216px sidebar and 32px gutters. The CLI stays visible: every dialog shows the command it will run, and every Activity entry the command that ran. Surfaces are tonal steps of graphite with 1px borders between them. Depth comes from tone; only things that float (dialogs and toasts) cast a shadow, and the folders on Applications, the one glass object (The Folder Glass Rule).

Motion is brief and springy, and it never overshoots: every surface opens on a click, not a flick, so every spring is critically damped. Controls press to 0.97 on pointer-down and spring back, dialogs rise and scale in from 0.96, panels leave the way they came, pages crossfade, and the sidebar highlight slides to the new page. Hover moves nothing; it changes fill and border (the folders on Applications lean and lift, The Folder Glass Rule). When you open a profile, add one or bring one back, the ground answers once: a ring of denser glyphs spreads from it through the ambient field. With reduced motion on, the springs and both crossfades become static swaps, the ambient field holds one still frame and sends no ring, and every action stays keyboard-reachable. The dashboard is dark-only. The project site (`site/`) is a separate visual world owned upstream, and this file does not describe it.

**Key Characteristics:**
- Warm black ground under a faint drifting glyph field, warm off-white text, graphite steps in between.
- One flat hue per app with profiles, assigned once and kept for that app everywhere; apps without profiles stay neutral.
- One deep tile color per section, on its sidebar row, its page title and its operation cards.
- Flat tonal cards; shadow only on floating layers.
- Spring motion with a full reduced-motion path.
- Platform UI font only; nothing loads from the network.
- The exact `aidentity` command behind every action, shown before and after it runs.

## Colors

A warm graphite ramp from Lampblack to Bone, lit only by seven app hues, eight section tiles, the status colors and the official logo.

### Primary
The seven app hues, defined once in CSS as `--hue-periwinkle` … `--hue-violet`. `app.js` and `experience.js` read them from those tokens (with a frozen fallback and a console warning if one is missing). Only apps that have at least one profile get a hue: `app.js` gives an app whose installed icon has a color of its own the palette hue nearest it (the chroma-weighted mean hue of the icon's pixels), hashes any other app name into the palette (an app without an icon, or with a neutral one such as ChatGPT's black and white), resolves collisions so no two such apps share a hue while one is free, and keeps the hue an app got first. An app with no profiles has no hue and renders in graphite with Bone ink. Every hue clears 6.2:1 against Lampblack, so app-colored fills always take Lampblack text.

- **Periwinkle**, **Teal**, **Orange**, **Pink**, **Gold**, **Sky**, **Violet** (`periwinkle` … `violet`): app hues, with no role outside app identity.
- **Mint** (`mint`): not an app hue. It is the positive status color, the connection dot and the default accent.

`--accent` is Mint globally and the app's hue inside an app-toned scope (`.app-tone{--accent:var(--app-color)}`); focus rings, the focused-field border and the caret follow it. `--app-color` is set only on an app-toned element, never on `:root`.

Hue appears in exactly five forms: a solid fill with Lampblack ink (the primary button of an app scope, the app tile of an app without an installed icon), a plain dot, a 1px border (hover, running, the chosen navigator row), a focus ring, and the 15% ring on a focused field. The header Add button is always Bone. A selected profile card is marked on the neutral ramp instead: a 2px Bone outline at a 2px offset.

Saved profile badges are a separate, user-chosen set of ten swatches: Mint, the seven app hues, Gray (#8d8b84) and Graphite. A badge keeps its saved color; it never follows the app hue. A new profile's default badge is the first swatch, in that order, that is neither its app's hue nor worn by another profile of that app.

### Secondary
The section tiles, defined once in CSS as `--tile-*` and applied through a `.section-<view>` class that sets `--section`. Each is a deep fill that carries a Bone glyph at 4.6:1 or more, so a section tile never reads as an app tile (bright fill, Lampblack ink).

- **Indigo** (`tile-explore`): Explore.
- **Plum** (`tile-profiles`): Profiles.
- **Cobalt** (`tile-apps`): Applications.
- **Deep Teal** (`tile-recovery`): Recovery.
- **Rust** (`tile-maintenance`): Maintenance.
- **Forest** (`tile-transfer`): Import & export.
- **Slate** (`tile-help`): Help.
- **Brick** (`tile-danger`): the tile of a destructive operation, on any page.

A section color appears in four places only: its sidebar tile, its current-page highlight (the section color mixed 28% into Raised), the tile beside its page title and the tile on each of its operation cards.

### Neutral
- **Lampblack** (`lampblack`): page ground, and the ink on any app-colored fill.
- **Surface** (`surface`): empty states, health results and output blocks, dialogs, Explore keys, sidebar hover.
- **Card gradient** (`card-top` to `card-bottom`): the resting fill of profile and operation cards, Recovery's and Help's panels, the detail panel and the Explore panel; neutral, never tinted.
- **Raised** (`raised`): secondary buttons (with a Field border edge), the base the current nav item's section color mixes into (28%), field fill, notices.
- **Active** (`active`): the app tile of an app with no hue on cards, the detail panel and Applications (Explore's panel and navigator use Raised).
- **Border** (`border`): hairlines between regions and around cards.
- **Button edge** (`button-edge`): the 1px edge of default (outlined) buttons and key caps, at least 2.1:1 on Lampblack, Surface, the card gradient and Raised.
- **Control** (`control`): borders of dialogs, toasts, Explore buttons and dashed empty states.
- **Field border** (`field-border`): text fields, selects and file inputs (3.6–3.9:1 on every surface), the edge of the secondary (Open) button, and the ring that makes the Graphite swatch visible.
- **Tip** (`tip`): toast ground.
- **Material bar** and **Material panel** (`material-bar`, `material-panel`): Lampblack and Surface made translucent for the floating chrome (see Material).
- **Scrim** (`scrim`): black at 60%, behind the phone drawer and every modal dialog.
- **Glass sheen** and **Glass rim** (`glass-sheen`, `glass-rim`): Bone at 7% and 16%, the pointer sheen on a folder's glass and the hairline on its rims and on each file's top (The Folder Glass Rule).
- **Folder shadow** (`folder-shadow`): black at 65%, the soft shadow under a folder and its files, and nowhere else.
- **Bone** (`bone`): primary text, the default primary button fill, the tab indicator, and the ambient field's glyphs at 12%.
- **Muted** (`muted`): secondary text, idle nav items, idle tabs, placeholders.

### Status
- **Positive**: Mint (the running mark, success toasts).
- **Negative** (`negative`): errors and destructive buttons, on `negative-bg`.
- **Danger edge** (`danger-edge`): the 1px edge of a destructive button at rest, at least 2.2:1 on the same surfaces as the Button edge.
- **Warning** (`warning`, Amber): the icon and level of a warning finding, the warning toast icon, the alert icon that leads every callout, and the Needs repair count while it is above zero. Callouts use `warning-bg` with Bone text. Amber clears 9.3:1 on every surface it sits on.
- The Running tab count turns Mint while it is above zero; a finding marked ok has a Mint check. In the Workspace health summary, the OK, warning and error numbers take Mint, Amber and Negative while above zero; their words stay Muted.

### Increased contrast
Under `prefers-contrast: more`, Muted becomes #b4b2aa (7.3:1 on Warning bg, 8.7:1 on Raised, 9.5:1 on Lampblack), Border takes the Button edge, Control the Field border, the Button edge becomes Muted, the Field border #9a988f, the Danger edge Negative, the glass rim the new Button edge (#8d8b84), and every material turns solid. The ambient field is gone, here and under forced colors, so the ground is solid Lampblack. Hues and Bone stay as they are.

### Named Rules
**The Two Layers Rule.** A bright hue means an app that has profiles; a deep tile color means a section of the dashboard; Mint, Amber and Negative mean status. Everything else stays on the Lampblack-to-Bone ramp: card surfaces, text, apps without profiles and the counts that are not status. The official logo is the one exception (The Upstream Logo Rule).

**The Section Rule.** A page's tiles take its section's color, except a destructive operation's tile, which is Brick. A section color is only ever a tile fill or the current-page highlight, never text, a border or a card surface.

**The One Running Mark Rule.** Running is an 8px Mint dot plus "Running" in Mint, on cards, the detail panel, Explore keys and the navigator alike, and the running card or key also keeps its 1px hue border. A closed folder on Applications carries the same mark with its count ("2 running") beside "N profiles". A profile that is not running shows no dot. Under forced colors the dot is drawn in CanvasText.

**The Flat Hue Rule.** A hue is a solid fill, a plain dot, a 1px border or a focus ring. Never a gradient, glow, tinted text, tinted background, tinted secondary button or accent stripe, and never a second hue for the same app. The logo's own gradients and glow are its art, not a hue (The Upstream Logo Rule).

**The Upstream Logo Rule.** The official aidentity logo is the one sanctioned exception to the Two Layers, Flat Hue and no-site-blue rules. The mark (`assets/logo.svg`) leads the sidebar lockup and the app icon (`assets/icon.svg`) is the favicon, both inline in `index.html` with their own paths, gradients, colors and glow, cropped to the art and scaled, never recolored or redrawn. The logo belongs to the upstream maintainer, and any change to it is a proposal to them.

**The Own Icon Rule.** An app is drawn with its own installed icon, read from the app on this Mac, never with artwork shipped in the repo; like the logo, it keeps its own colors, never recolored. The app's hue follows the icon instead: it is the palette hue nearest the icon's own color, so icon and hue read as one, and a neutral icon leaves the pick to the name's hash.

**The Ink Rule.** Text on an app-colored fill is Lampblack. A badge picks whichever of Lampblack (#060606) and white (#ffffff) contrasts more with its saved color; every preset clears 5.9:1.

## Typography

**Display Font:** the platform UI font (`-apple-system`, BlinkMacSystemFont, "Segoe UI", sans-serif)
**Body Font:** the same stack
**Label/Mono Font:** `ui-monospace`, SFMono-Regular, Menlo, monospace, for command lines, command output and key caps only

**Character:** San Francisco on a Mac, set tight at the top and plain below. Headings close up their tracking; labels stay at normal tracking and a 500 weight.

### Hierarchy
- **Headline** (600, 28px, 1.2, -0.035em): page titles on every view. Below 768px every page title is **Headline compact** (24px).
- **Card** (550, 22px, 1.2, -0.03em): dialog titles, empty-state titles, the Explore panel's app name.
- **Card compact** (550, 19px, 1.2, -0.03em): below 768px, every Card heading inside the page (the Explore panel's app name, empty-state titles, the detail title), so it reads under the 24px page title and not beside it. Dialog titles stay at Card.
- **Title** (550, 17px, 1.35, -0.015em): card and section headings, profile names, app names, profile names on Explore keys, Recovery's profile rows.
- **Title compact** (550, 15px, 1.3, -0.015em): the Explore navigator's app names, the names on one-row Explore keys, the profile names on folder files and the phone top bar's page name.
- **Body** (400, 14px, 1.55): the base size, and the text of an empty state.
- **Secondary** (400, 13px, 1.55, Muted): card, panel and dialog descriptions, Terms definitions. A page title has no subtitle.
- **Label** (500, 13px): buttons (Explore's included), tabs, form labels, the Terms and Local storage headings, toast titles and Activity entry titles. Label text that can wrap (toast and Activity titles, name lists in dialogs) sets at 1.4.
- **Meta** (400, 12px): profile metadata, state rows, counts, times, help text, the Explore "N of M" position.
- **Mono** (12px, 1.7): command lines ("Runs:", Activity) and command output blocks, wrapped, never truncated.

Nothing is smaller than 12px. Exempt from the ramp: the sidebar wordmark (19px, part of the logo lockup) and glyphs sized inside icon boxes (the app-tile initial 20px, 21px in the detail panel; Explore navigator initial 16px and panel initial 20px; Explore arrows 18px; rail initials 12px; the badge character 13px on an Explore key and 12px on a profile tile).

### Rhythm and line breaks
A card heading sits 8px over its own description; blocks inside a card are 12px apart. A page's title row sits 24px above its body (20px below 768px), on every view, Explore included. The title row is the section tile and the `h1` alone, on every view and in every state (first run, a filter, Help): the cards say what each part does, and Help's Terms define the words, launcher and profile among them. Headings balance their lines and prose wraps `pretty`. A name joined by underscores, such as `Northwind_Research_Quarterly_Review_Team`, breaks after an underscore (a `<wbr>` in a copy hidden from assistive tech, which reads the plain name), never mid-word; only a segment wider than its line breaks inside. A profile name is never cut off: cards, the detail panel, Explore keys, dialogs, toasts and Activity entries show it whole, wrapping. The one-line activity bar is the exception: its summary cuts a long title with an ellipsis and keeps "· View details". A command line keeps its own rule (see Command line).

### Named Rules
**The System Voice Rule.** One family: the platform UI font. The dashboard loads no webfonts.

**The Tabular Count Rule.** Counts (tab totals, "N profiles" lines, the health summary), the Explore position and every time use tabular numerals.

## Layout

A fixed sidebar beside a fluid canvas. The sidebar is 216px, collapses to a 72px icon rail on request, narrows to 190px at 1150px, and becomes a 248px slide-over drawer with a scrim below 768px. The sidebar scrolls when it runs out of height, and the "Your apps" list is capped at 40% of the viewport, so Help and Collapse stay reachable at 200% zoom and on a landscape phone. The top bar is 68px (64px on mobile, where it names the page once half of the page title is under it; see Navigation).

Workspace gutters are 32px; the canvas drops to 24px at 1200px and below (the top bar at 1150px), and to 18px below 768px. Gaps are mostly 8, 12, 16, 20 and 24px. The Profiles grid starts 20px below the tab strip (16px below 768px), also when no toolbar sits between them. Profile cards fill the grid by width (210px minimum, 20px gap; one or two cards stop at 360px) and never by selection. At 901px and up the grid always has a 320px detail column beside it while the status tab shows at least one card, or while the app filter and search still include the chosen profile, so choosing a card never reflows the grid and a status tab, an action or a poll never drops a choice; an empty state with no chosen profile spans the full width. Nothing is selected for the user: until they choose, the column holds a dashed prompt, "Select a profile to see its settings and actions." Only an explicit choice returns on a later visit, or when the filter or search shows its card again. Between 768px and 900px the detail panel follows the grid in reading order and the prompt is hidden; below 768px the panel replaces the grid behind a Back button. Selecting a card moves focus to the panel's heading, and the panel fades in over 140ms without sliding: selection is frequent, so it gets no travel.

Explore is a focus panel on the left (the remaining width) and a navigator of apps on the right (a 240px to 300px column, 28px gap; 220px to 260px and a 20px gap from 768px to 1100px). The panel's height follows its content and it sticks 24px from the top only while it fits above the activity bar; a taller panel scrolls with the page. Below 768px the columns stack. Applications fills columns of 340px folders, as many as fit 32px apart and one where two do not, each folder bottom-aligned in its row and never wider than 340px; Maintenance is two columns of operation cards, with Workspace health spanning both and splitting in two from 768px; Help is a 270px control column beside the output, below a three-column Terms block (two at 900px, one on mobile).

The fixed activity bar is 40px tall and absent until the first action runs; its panel opens above it up to 45% of the viewport (50% on mobile). Focusable content inside `#main` keeps a scroll margin so the bar never covers a focused control, also while the panel is open.

Breakpoints in use: 390px, 767/768px, 900/901px, 1100px (Explore gap), 1150px and 1200px.

## Elevation & Depth

Tonal, with shadows only when floating. Under everything lies the ambient field: the sidebar, the top bar and the open canvas show it, and every filled surface covers it. Cards, panels, Explore keys and the sidebar sit flat: depth comes from the step between Lampblack, Surface and Raised and from 1px borders. Hover draws a card's border in the app hue (Muted on a neutral card) and does not move it. A running profile card draws a full 1px hue border, and so does the chosen navigator row (Muted for an app with no hue). A selected profile card adds a 2px Bone outline at a 2px offset, so a card that is selected and running shows both. A running Explore key draws a plain 1px hue edge. When a profile starts running, its card and its Explore key draw that edge once, from Border, over 900ms, and the running dot arrives from nothing on the control spring; under reduced motion both are simply there.

### Shadow Vocabulary
- **Dialog** (`--shadow-dialog`): modal dialogs and the mobile bottom sheet.
- **Toast** (`--shadow-toast`): the stacked toast column and the folders' ··· menu.
- **Folder** (`folder-shadow`, blurred): the pool under each Applications folder and the drop under each of its files, the one shadow in the content layer (The Folder Glass Rule).
- **Focus ring** (`box-shadow: 0 0 0 3px` accent at 15%, `--ring-accent` outside app context): focused fields, with the border in the accent.

### Material
The fixed chrome that content passes under is a translucent layer, not a shadow: the activity bar and the phone top bar are `--material-bar` (Lampblack at 88%), the activity panel and the folders' ··· menu `--material-panel` (Surface at 92%), all with `blur(20px) saturate(140%)`. Muted text on the bar stays at 4.6:1 or more even over a solid Bone area. It turns solid where `backdrop-filter` is unsupported, under `prefers-reduced-transparency` and under `prefers-contrast: more`. Nothing else in the content layer is translucent: the folders on Applications are the one exception (The Folder Glass Rule).

### Named Rules
**The Floating-Only Shadow Rule.** A shadow means the layer floats above the page (dialogs, toasts). Resting cards and keys never get one, and no hue ever glows; identity and running state are a border or a dot, never height or light. The folders on Applications are the one exception (The Folder Glass Rule).

**The Folder Glass Rule.** The folders on Applications are the one glass object in the content layer and the one exception to the shadow rule above and to "hover moves nothing". Each is three layers of in-world material: a back panel of translucent graphite (Raised to Surface at 62–72%), the app's profiles as files (Active to Raised, a Bone hairline on top), and a front panel of smoked glass (Surface to Lampblack, from 8% at the top to 94% at the foot, `blur(16px)`), so the files and the ambient field frost through it, with a soft shadow under the folder and under each file and a neutral Bone sheen at 7% that follows a fine pointer. Nothing is painted for it: no artwork, no second canvas, no color outside the palette; only what is behind the glass shows through. The app's hue keeps its allowed forms: the fallback app tile on the glass (an app without an installed icon), the folder's 1px rim on hover and while open, a file's 1px edge on hover and while it runs in an open folder, and the focus ring. Nothing colored sits under the glass: a closed folder's files, on hover too, show no badge, no running mark and no name (a lifted file is blank paper, never a name cut by the glass's tab); all three appear once it opens and the files clear the glass. What runs still shows while it is closed: the running mark and its count sit on the glass, beside "N profiles", not under it. The label sits where the glass is at least 80% opaque: Muted keeps 5.7:1 there and 4.9:1 under the sheen at its brightest, so neither the glass nor the sheen may get lighter. Under `prefers-reduced-transparency`, `prefers-contrast: more` and forced colors, and without `backdrop-filter`, the glass and the back are solid (the card gradient, Raised to Surface) and the sheen is gone.

**The Ambient Ground Rule.** The glyph field is the only thing that moves at rest. It is neutral, every glyph Bone at a flat 12% and never a hue, and it lies under every layer; brightness is glyph density, not ink. It drifts at no more than 30 frames a second, grows denser near the pointer and pauses while the tab is hidden; under reduced motion it holds one still frame, and under increased contrast and forced colors it is gone. It answers four moments, and only these, with one ring of denser glyphs that spreads from where the profile shows and fades as it goes: a profile that starts running (from its Open; 640px over 1.4s), a profile added (from its new card, or its new file on Applications; for the very first profile the ring is wider and crosses to the farthest corner over 3.2s), a profile restored or imported (from the toast that says so), and the dashboard reconnecting (from the connection dot; from Refresh below 768px, where the sidebar is a drawer; the same 640px ring as a profile that starts, since the page coming back is the one recovery nobody pressed a button for). The ring is density only, in the same loop and the same Bone at 12%; Bring to front, Quit and every other action send none. Under reduced motion, increased contrast and forced colors, and in a hidden tab, there is no ring: the running mark, the new card and the toast are the whole feedback. At 12% Muted text keeps 4.6:1 over any glyph; 13% would leave 4.5:1 with no margin, so 12% is the ceiling.

## Shapes

Soft rectangles, nested by size. Controls, nav items, icon buttons, Explore key badges and navigator tiles, and the file-picker button are 8px; Explore keys, navigator rows and toasts 12px; the fallback app tile 12px (10px in the Explore panel); the Explore panel 14px (12px below 768px); section tiles 10px at 36px (9px at 32px on phones) and 7px at 24px in the sidebar; cards and panels 16px; dialogs 20px, and 20px on the top corners only as a mobile sheet. The badge on a profile tile and the rail initial are 6px. Status and app dots and the color swatches are full circles (8px running dot, 8px app dot, 6px connection dot, 32px swatch, 44px on mobile). An installed app icon brings its own squircle and shows whole, on nothing: no fill, border, clip or tint behind it. Its squircle fills the box it replaces, so the image is 1.24× that box (macOS draws an icon's body on 824 of 1024px), from a 128px PNG that stays crisp at 2x.

A badge is always a filled rounded square in its saved color, with no stripe or shadow: 34px on an Explore key, 20px at the corner of a profile tile, where it overlaps the tile by 6px. A badge on a tile carries a 2px ring in the surface it sits on (the card gradient's top, Raised in the Add dialog's preview strip, Surface in Settings, where the tile sits on the dialog), so even a badge in the tile's own color reads as a separate chip. A profile set to use the original app icon has no badge: its tiles show the app's icon alone, and its Explore key fills the 34px badge slot with the app's installed icon (without one, its glyph at 20px on the app hue with Lampblack ink, or Raised with Bone ink for an app with no hue).

## Components

### Buttons
Every button presses to 0.97 in 85ms on pointer-down and springs back on release (340ms, critically damped). Hover changes fill and border only. Under reduced motion the press dims to 78% opacity instead of scaling.
- **Shape:** gently rounded (8px), 36px tall, 14px side padding, 13px label at 500. Below 768px touch targets reach 44px.
- **Default:** transparent with a Button edge border. Hover fills Raised and lightens the border to Muted.
- **Primary:** Bone fill, Lampblack text. In an app-toned scope (a profile card, the detail panel, a dialog opened for an app) the fill is the app hue with Lampblack text; hover mixes in 10% Bone. The header Add button is outside any app scope and stays Bone.
- **Secondary:** Raised fill with a 1px Field border edge. This is Open, when a profile is not running, on cards, the detail panel and Explore keys alike.
- **Bring to front:** the Primary fill: the app hue with Lampblack ink. It replaces Open while a profile runs.
- **Danger:** Negative text and a Danger edge border; hover fills `negative-bg` and borders in Negative.
- **Small:** also 36px tall, with 10px side padding; used for Quit, Repair, Settings, Rename, Remove and Rebuild launcher.
- **Link button:** underlined 13px text, 36px tall (44px on mobile); "Custom color…".
- **Explore buttons:** the same 36px shape on a Surface fill with a Control border. A key's Open is the Secondary and its Bring to front the hue fill, as everywhere. Add profile is a plain Explore button while the app has profiles and takes the Bone fill while it has none: the first profile's action is the one primary in an empty panel. Bone also fills Refresh apps in the state with no apps at all. Neither has an app hue.
- **Busy:** a spinner replaces the label; under reduced motion the spinner pulses in opacity instead of turning.

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** the card gradient (#0f0f0f to #090909).
- **Shadow Strategy:** none at rest; see Elevation & Depth.
- **Border:** 1px Border; on app cards hover draws the app hue (Muted on a neutral card), and a running profile card draws it in full. Selection never takes the hue: a selected profile card adds a 2px Bone outline at a 2px offset. Operation card surfaces stay neutral; each card, and Recovery's restore panel, leads with a 36px section tile.
- **Internal Padding:** 24px for panels and operation cards (below 768px, 22px for operation cards and 20px for panels), 20px for profile cards at every width.
- **Recovery:** each restorable profile is a row of its name and its own Restore; Restore all joins them only from two profiles. The panel's description says once that the launchers were removed and their data is still on this Mac, so the rows do not repeat it; Help's Terms define "launcher".

### Section tile
A flat rounded square in its section's deep color with a Bone glyph, no border, shadow or gradient. 36px with a 20px glyph beside every page title (32px with an 18px glyph below 768px), centered on the title's capitals; 36px above the heading of an operation card; 24px with a 15px glyph in the sidebar. Profiles filtered to one app leads with that app's installed icon at the title tile's size instead. It is decorative (`aria-hidden`); the label beside it names the section. Under forced colors it gains a 1px CanvasText border.

### Icons
Every UI icon is a Hugeicons stroke-rounded glyph from the MIT free set, its path data inline in `app.js`: a 24px grid, a 1.5 stroke in `currentColor`, round caps and joins, never filled, never a Unicode or emoji stand-in. 20px in a 36px section tile (18px in a 32px tile), 15px in the 24px sidebar tile, 18px in an icon button and for the Explore arrows, 16px beside a button label, in the search field, a callout and a finding (15px on Explore buttons, 14px in the phone top bar), 17px in a toast, and in the activity bar 16px for the terminal, so it holds up in Muted at 1x, and 14px for the chevron. An app is drawn with its own installed icon (The Own Icon Rule); only an app without one falls back to a mark on its tile: the app's Hugeicons brand mark where the free set has one (Claude, ChatGPT, Chrome, Slack, Notion, Visual Studio Code, Arc), on the same stroke; Cursor, Edge and Brave keep the dashboard's own drawn marks, and any other app shows its initial. The official logo and the favicon are not icons (The Upstream Logo Rule).

### Inputs / Fields
- **Style:** 40px, Raised fill, 1px Field border, 8px radius, 9px × 12px padding. The search field has a 16px leading icon and a 36px clear button. Search appears on Profiles from seven profiles. Applications lists two apps at most and has no search.
- **Focus:** the border turns to the accent (the app hue in app context) with a 3px ring at 15%. Under forced colors, a 2px Highlight outline.
- **Error:** a `negative-bg` form-error block above the actions, and `aria-invalid` on the field the server rejected. A long CLI error keeps its line breaks and scrolls inside the block from 160px; an inventory error notice scrolls from 200px. Both take Tab focus, so the keyboard can scroll them, and a failure that names no field brings the form error into view. A rule the browser can check first (the profile-name `pattern`) stops the submit with the browser's own message and the rule in its `title`.

### Navigation
- **Sidebar:** a `<nav aria-label="Main">` landmark. 40px items, 8px radius, Muted text, each led by its 24px section tile. Hover shows Bone on Surface; the current page shows Bone on its section color mixed 28% into Raised. On a page change that fill slides from the item it left, or from where it is mid-slide, over 340ms on the control spring; under reduced motion it jumps. Under the nav, "Your apps" lists only apps that have profiles, each led by its installed icon at 16px, or an 8px dot in its hue for an app without one (36px rows, 12px text); "No profiles yet" shows only once data has loaded and there are none. Help and Collapse sit at the foot. At the top, the logo lockup: the official mark at 16 × 32px, centered over the section tiles, beside the "aidentity" wordmark and the tagline "One app. Every account." on the nav labels' line (from 768 to 1150px the tagline sits under the mark, from its left edge, so it does not wrap). The mark is decorative (`aria-hidden`); the link's own text names it. Above the nav, one compact status row: a 6px Mint dot (Negative when offline) and "Connected · this Mac".
- **Collapsed rail:** 72px; labels hide, the logo mark and the section tiles stay centered, the status row shows only its dot, and each app shows its installed icon at 24px (without one, its initial as a 24px rounded tile in its hue with Lampblack ink), named by a tooltip that appears beside the rail for keyboard focus, with a divider where "Your apps" was. As a mobile drawer the full labels return.
- **Tabs:** 13px labels in Muted, Bone when selected, 44px tall, with a 2px Bone underline that springs between tabs. Profiles tabs are All, Running, Not running and Needs repair, with the counts on the tabs only (Needs repair shows a muted dash until a check has run). Arrow, Home and End move between tabs. The strip appears with the first profile: with none at all it is absent, since the tabs would filter nothing, and the first-run empty state follows the title directly. When the strip overflows on a narrow phone, its right edge fades and the selected tab scrolls into view.
- **Mobile:** the top bar names the page once half the letters of its `h1` are under the bar (a switch on the `h1`'s own view timeline, inset by the bar, so it follows the title wherever it sits, below a banner or wrapped; on at once and never half faded, so it is the same under reduced motion; a page that scrolls less keeps the bar blank and its `h1` readable, and a browser without scroll timelines always shows the name), so the name reads in one place at every scroll position and never twice in full. The sidebar becomes a drawer from the left behind a 60% black scrim; Tab stays inside it and the page behind is inert.
- **Page change:** the old page fades out in place over 200ms while the new one fades in and rises 8px over 480ms on the surface spring; the activity bar, its panel and the toasts stay still. Without the View Transitions API, or while the phone drawer is open, only the new page animates, from 50% opacity and 8px down. Under reduced motion the swap is instant.
- **Focus on navigation:** the new view's `h1` takes focus (no ring; it is not a control) and the document title becomes "<View> · aidentity". There is no breadcrumb.

### Dialogs
- **Shape:** 560px wide, 20px radius, Surface fill, Control border, Dialog shadow, header and footer pinned (the footer has a Control top border). Focus starts on the first field.
- **Add a profile:** Application (preselected from context; with no app installed, a hint under it points to the app path and the location disclosure opens), Profile name (its help and its `pattern` are the CLI's rule: letters, numbers, spaces, hyphens and underscores, 40 at most, no leading hyphen or outer space, so the browser names the rule before the CLI has to), "Use the original account" (its help says when: once a profile runs, the app's own icon only switches to that profile), then two collapsed disclosures: "Appearance" and "App location & launch settings", then the Runs line, hidden while any field is invalid. The preview stays at the top of the body while the fields scroll under it (in a dialog at least 560px tall), so a swatch, badge or name shows as it is picked. Appearance holds the badge character (it defaults to the name's first letter and sits at the corner of the launcher's icon), a "Use the original app icon" checkbox that hides the colored badge, and the badge color: ten 32px round swatches (44px on mobile), the chosen swatch's name and hex as visible text ("Periwinkle · 7C8CFF"), and a "Custom color…" link that reveals the hex field (open from the start only when the saved color is not a swatch). The default color is the first swatch that is neither the app's hue nor worn by that app's other profiles. Success selects the new card, scrolls to it, closes a 2px ring onto it while the ambient field's ring spreads out from it (to the farthest corner for the first profile), and toasts "<App> <Profile> is ready" over "Open it to sign in with that account." ("Open it to use the original account." for the original account) with an "Open it" action. On Applications the new profile drops into its folder instead (see Application folder), with the same toast. The same rule guards Rename's new name.
- **Settings, Rename, Remove, Import profiles, Export profiles:** the same dialog frame; Settings is titled "Settings for <name>", its preview is the tile alone with no strip (plus "Opens the app’s original account" where it applies), and it sends only what changed; Rename sits beside it in the detail panel, so Settings has no Rename link. Rename is titled "Rename <name>" and asks only for the new name. While its action runs, the footer says what it is doing and, from 5 seconds, for how long ("Renaming… 12s"), and Cancel and the close button are disabled, since the dialog closes only when the action ends; a failure shows in the form error alone, with no toast over the form. Remove says once, in its description, that the data stays and the profile can be restored from Recovery; its body is the "Also move the profile data to the Trash" choice, and ticking it rewrites the description to say the data moves to the Trash and Recovery cannot restore it. A confirmation whose description says it all has no body text: the Runs line follows the header.
- **Motion:** on desktop, enter rises 14px and scales from 0.96 over 420ms on the critically damped spring, with no overshoot; exit falls 14px to 0.96 over 200ms. Below 768px a dialog becomes a bottom sheet that slides up on `--ease`, with no overshoot.

### Toasts
Titles say what happened in plain words ("Opened Claude Work", "Brought Claude Work to the front"), never "<Action> complete". A toast adds text only when the title, the banner and the activity bar do not already say it (the sign-in hint on a first open, where the findings are, what a removal kept), and it links to Activity ("View details") only when its text is cut off: the activity bar already names every entry. A 340px column at the bottom of the workspace, 32px in from the sidebar (24px at 1200px and below), above the activity bar. On a phone the front toast spans the width 8px from the bottom, over the activity bar, which names the same entry, and over an open sheet it sits in the scrim above it. While a toast shows, the page's foot reserves the strip it covers, so whatever is under it can scroll clear, and focus does. A toast that says the dashboard is disconnected leaves on reconnect. Names and paths wrap inside a toast. Each toast is Tip on a Control border, 12px radius, with a status icon in Mint, Amber or Negative. A toast that is only a title ends with its title: the dismiss button's box overhangs the padding, so it adds no strip under it. The front toast is expanded; the rest stack behind it and fan out on hover.

### Profile card (signature)
The Profiles grid's unit. A 44px app tile, the app's installed icon or without one a tile in the app's hue (graphite for an app with no hue), carrying the profile's 20px badge at its corner (none for a profile that uses the original app icon), sits beside an `h2` whose name is a button (Title, the whole name, wrapping) over the app name (13px Muted). A name over 24 characters sets under the tile instead, 12px below it and across the card, wherever the column beside the tile would be under about 195px (a card under 292px wide: the grid beside the detail column, tablets, a phone under 328px; a wider phone keeps it beside), so the 40-character maximum takes two or three lines, not four, and keeps its word-safe breaks. Clicking the card or pressing Enter on the name selects it; only the visible Open button launches, and O opens only while focus is inside the selected card or the detail panel. Below: a state row with the status label (an 8px Mint dot and Mint text when running), plus small Repair and Quit actions when they apply; a Meta line of "Original account · Own extensions · N launch options"; then one full-width, 40px primary action: Open (the Secondary), or Bring to front (the hue fill) when the profile is running. Quit is a small outlined button beside the state, never in the primary slot. There is no cover strip. Hue shows only in a fallback tile, the Bring to front fill, and the hover and running borders; selection is a 2px Bone outline at a 2px offset.

### Application folder
Every app the dashboard lists (Claude and ChatGPT) is a glass folder (The Folder Glass Rule), adapted from kedhareswer's Glass Folder Cards, apps with profiles first, then by name. Its stage is 340px wide, scaled down only where the column is narrower: the back panel with its tab on the right, the files, and the glass front panel carrying the app's 44px tile, its name (Title) and "N profiles" (Meta, Muted, tabular) at its foot, followed while any profile runs by the running mark with its count ("2 running"), with two 44px keys at its right, + and ···. The count line never wraps, so the label stays on the 80% glass: where it is full, the word "running" drops and the dot and count stay.
- **States:** at rest the folder is closed and only the files' tops show over the glass. On hover or focus the front panel leans toward you on its bottom hinge (11°) and the files lift; on hover the rim takes the app hue (Muted with no hue), and keyboard focus on the folder draws the focus ring on its rim in the accent (the app hue, Mint with no hue). Opened (a click anywhere on the folder, or Enter or Space on it), the glass falls further open (20°) and the files rise out in a slight fan.
- **Files:** each is a button: the profile's badge (the app's icon when it uses the original app icon), its whole name (Title compact, wrapping at underscores) and the running mark while it runs, with the file's 1px hue edge; the badge, the name and the running mark show only while the folder is open. A file opens its profile's detail on Profiles; launching stays with Open, as on a card. Each file's strip is measured, so every name shows whole above the file in front of it, and the folder reserves the height its open fan needs, so opening never reflows the page. The fan is tight, so that reserve stays small: the file in front covers all but 5px of the strip under each name, the front strip ends on the glass's raised tab, and the fan's top may reach the folder's own top, where the title row's 24px margin is its clearance (four files with the 40-character name keep about 93px above the folder, four short names about 74px). Four files at most: past that, three and a "N more profiles" file that opens Profiles for the app. Profiles added there this session come first, then running ones, then by name.
- **Keys:** + opens Add a profile for that app. ··· opens a menu, "Show <App> profiles" and "Add profile" (arrows, Home and End move; Escape and Tab close it). When an add succeeds on Applications, from + or anywhere else, the folder opens and the new file drops in as the top file on the surface spring with no rebound, the glass gives once as it lands, the count rolls over, the ground's ring spreads from the file and focus lands on it.
- **Closing:** one folder is open at a time; a second click, Escape or a press outside closes it, and Escape returns focus to it. Leaving the page closes it.
- **Empty:** an app with no profiles is an empty folder on the neutral ramp: graphite tile when it has no installed icon, "0 profiles", + in the Bone fill, and opened, one dashed blank file: "No <App> profiles yet" over "Each profile opens <App> with its own sign-in."
- **Accessibility:** the folder is a button with `aria-expanded`, named "<App> N profiles" (and "N running" while any runs); its files are a list of buttons named by profile, inert while closed; ··· is a menu button.
- **Motion:** the hinge, lift and fan move on the surface spring (480ms, each file 30ms after the one in front); the pointer leans the folder (up to 3° and 4°) only with a fine pointer. Under reduced motion every state is a static swap (open shows the files at once) with no lean, drop or bump.
With no apps the grid holds "No AI apps found" and Refresh apps.

### Detail panel (signature)
A 320px card on the right of the grid at 901px and up: sticky 24px from the top, with a max-height that fits between the top bar and the activity bar (and the open Activity panel), scrolling inside with a fade at the bottom edge only while it overflows. Before a choice the column holds a dashed prompt instead. From 768px the selected card already shows the state, Quit and primary action, so the panel omits them; below 768px, where it replaces the grid, it keeps them. Top to bottom: the 48px app tile with its badge, the profile name as `h2` over "<App> · original account" where it applies, the "Runs:" line with a Copy button, one row of small actions (Settings and Rename, with Remove in Negative pushed to the far end), then "Launch settings: app defaults" in one line, or the launch arguments, environment variable names and extensions when any are set, and last a "Details" disclosure holding the application path, profile data folder, who made the launcher, and "Rebuild launcher" with one sentence of explanation. Below 901px it follows the grid and gains a close button; below 768px, a Back button.

### Explore focus panel (signature)
The panel holds the selected app's profiles side by side as keys, under the app's identity (44px tile, name in Card and, while any run, the running mark; the keys and the navigator row carry the count). Below 768px, where the navigator follows the panel, Prev, "N of M" and Next sit above the identity; they step through every listed app and are hidden when only one app is listed. From 768px the navigator beside the panel is the one chooser. An app with no profiles shows "No <App> profiles yet. A profile opens <App> with its own sign-in, so your accounts run side by side." as a dashed Control placeholder with no fill, never a card inside the panel, above Add profile. A change of app crossfades the identity in 160ms (a static swap under reduced motion); nothing switches apps on scroll, and there is no reel or wheel. Each key carries the profile's badge in its saved color and ink (the app's installed icon on nothing when the profile uses the original app icon; without one, its glyph on the app hue), the profile name (Title), a state line (the running mark, or the status label, plus " · Original" on the original account), and the profile's one action: Open, or Bring to front when it is running. A running key has a 1px hue edge and draws it once when it starts, as its running dot arrives; when you opened it here, the field's ring also spreads from it (all static under reduced motion), with no glow. Keys fill a grid of 200px columns and become one-row keys when the panel is narrow. "Add profile" sits under them. Keys are a real list with names that start with their visible text ("Open Work, Claude", "Bring to front, Work, Claude").

### Explore navigator
The list beside the panel chooses the app and holds no profile actions. Every listed app is a row, apps with profiles first (running ones, then most profiles, then by name), one 60px row each with a 36px tile, the app name (15px), "N profiles" and the running mark while any profile runs. An app with no profiles keeps its row, neutral, with "0 profiles". The chosen row draws a 1px hue border on Surface (Muted for an app with no hue). The rows are the count line, with no summary above them (Profiles keeps its counts on its tabs). With no apps at all, Explore shows "No AI apps found" and Refresh apps instead of the panel and list, the same words as Profiles and Applications. There is no "All profiles" button.

### Command line
Every dialog that runs an action shows a "Runs:" line under the form: the exact `aidentity …` command from the server's preview, in Mono 12px on Lampblack with a 1px Border, selectable, with a Copy button. It updates as fields change and hides while the form is invalid. The detail panel shows the Open command the same way, with its own Copy button. A command breaks only between shell words: a quoted name that fits moves to the next line whole, and one wider than the line breaks as a name does, at its own spaces, after an underscore or after a slash, never mid-word; Copy copies the plain command. Every Activity entry shows the command that ran. Values the CLI treats as secret (environment values, proxy credentials, an imported recipe's contents) always appear as `•••`. The browser never builds the command itself.

### Activity bar
A 40px bar fixed to the bottom, hidden until the first entry (or while an action runs), on the bar material. The panel rises 10px and fades in over 340ms and leaves along the same path; one animation plays forward to open and in reverse to close, so a click mid-flight turns it around from where it is. It shows a terminal icon, a summary ("Activity · Nothing run yet", then "<toast title> · View details") and a chevron that flips when the panel opens. Entries (title, time, command, output) persist in `sessionStorage` for the tab, up to twelve; if storage fails, Activity lasts for the page.

### Help terms
The Help page opens with a "Terms" block above the CLI help: a 16px-radius bordered panel of plain-word definitions (Profile, Launcher, Original account, Doctor, Unclaimed data, Restore) in a three-column list, term in Label and definition in Muted. A full-width "Keyboard" entry lists the shortcuts in Mono key caps with a Button edge border: "/ search · ⌘B collapse sidebar · O open the focused profile".

### Status labels
The CLI's status words become: `running` → Running · `in use` and `not running` → Not running · `signed out / new` → Not opened yet · `app missing` → App missing. Explore and Profiles use the same table. A profile is a "profile"; "account" means only the sign-in; "launcher" appears on Recovery, Maintenance and Help, where the `.app` itself is the subject. The app's own account is the "Original account"; the actions are Settings, Export profiles and Import profiles. The empty phrase is "No profiles yet"; Maintenance offers "Check" and "Check and repair", and Recovery "Clear unclaimed data…". The add flow is "Add profile" at every entry point (the header, Explore, Applications, and "Add your first profile" on the empty Profiles page), "Add a profile" as the dialog title and "Add profile" as its submit; nothing says "Create".

### Empty states
Every empty state names what will appear, why it matters and one next step, in the CLI's words. Profiles with nothing yet: "No Claude or ChatGPT profiles yet" with "Add your first profile". An app filter with nothing: "No <App> profiles yet" with Add profile for that app (the toolbar's All apps clears the filter); when that app is not installed, "Install <App> to add a profile." with Show all profiles instead. Needs repair before a check: "Nothing needs repair" with Show all profiles and Open Maintenance. No app installed: "No AI apps found" with Refresh apps, on Profiles, Applications and Explore alike. An app with no profiles on Applications is an empty folder that opens on one dashed blank file, "No <App> profiles yet". Recovery before any profile: "Remove a profile and keep its data, and it appears here, ready to restore." Explore whose script failed to load: "Explore did not load" with Open Profiles, where every profile action also lives. Workspace health: "Not checked yet. Choose Check to see the result here." Export with nothing to export is disabled and says "Nothing to export yet. Add a profile first." The private-file callout appears only in the Export dialog, at the moment of export. Help shows Copy output only once there is output. An empty state is a Surface block that spans the full width unless a chosen profile's panel stands beside it; the dashed prompt appears only beside at least one card.

### Connection and busy states
When a poll or action can't reach the dashboard server, a banner says "The dashboard stopped. Run `aidentity dashboard --port <this page's port> --no-open` in Terminal to reconnect. This page picks it up on its own.", with a Copy button for the command: the server picks a free port each start, and only the same port is the same page; `--no-open` keeps the restart from opening a second tab beside the one that reconnects. The command breaks between shell words, as a Runs line does. Action buttons are disabled, the sidebar status turns to "Disconnected" with a Negative dot, and a toast that reports the failure carries only its title ("Disconnected", then "Still disconnected" on a later Refresh), since the banner holds the step. Offline, the page polls every 5 seconds; all of it clears on the next good poll, which also brings back the Runs lines that hid. A server that answers with an error is not offline: its message shows in the toast, the form error or, before the first read, on a "Workspace unavailable" page whose empty state names the cause ("The local server could not read your setup", with its message) above Retry connection; a page that never reached the server says so once, under the banner, as that empty state's heading ("This page could not reach the dashboard"). Run controls stay disabled until the first good read. While an action runs, other actions show a calm disabled state, and from 5 seconds the activity bar counts the seconds ("Opening… 12s"), so a hung call is visible until the server's timeout reports it.

## Do's and Don'ts

### Do:
- **Do** give each app that has profiles exactly one hue through `--app-color`, and use it only for that app's primary fill, fallback app tile (an app without an installed icon), dots, 1px borders and focus ring.
- **Do** define a new hue only as a `--hue-*` token; both scripts read the palette from CSS.
- **Do** give a new section a `--tile-*` token and a `.section-<view>` class, and give a destructive operation the Brick tile.
- **Do** put Lampblack (#060606) text on any app-colored fill; every hue clears 6.2:1.
- **Do** keep text at Muted (#8d8b84) or brighter and at 12px or larger. Muted on Raised (5.4:1) is the lowest text pairing on a surface; over an ambient field glyph Muted is 4.6:1.
- **Do** show keyboard focus as a 2px outline in the current accent, offset 4px (swatches use Bone at 3px; controls inside clipping boxes use an inset ring).
- **Do** give every spring and crossfade a reduced-motion path that keeps the feedback.
- **Do** keep controls at least 36px tall on desktop (swatches 32px) and 44px below 768px.
- **Do** show the server's command for every action (Runs line, Activity); never build it in the browser.
- **Do** name the primary action Open, or Bring to front when the profile is running, on every surface; Open is always the Secondary (Raised fill, 1px Field border) and Bring to front the hue fill.
- **Do** mark running with an 8px Mint dot and Mint "Running", and show no dot when not running.
- **Do** default a new badge to the first swatch that is neither the app's hue nor used by that app's other profiles, and ring every badge on a tile in 2px of the surface it sits on.

### Don't:
- **Don't** add a light theme. The dashboard is dark-only.
- **Don't** bring the site's blue or its light/dark switch into the dashboard. The site is a separate world owned upstream. The official logo's own blue is the one exception.
- **Don't** recolor, redraw or animate the logo, cut into its art, or take a color from it; only trim its empty canvas to the art and scale it.
- **Don't** put a shadow on a resting card. Shadows belong to dialogs, toasts and the Applications folders (The Folder Glass Rule).
- **Don't** use a hue as a gradient, a glow, text color, a tinted background or secondary button, or an accent stripe, and don't add a second hue to an app.
- **Don't** give an app with no profiles a hue, and don't use Mint as an app hue; it is status and the default accent.
- **Don't** recolor the header Add button; it is always Bone.
- **Don't** color anything that is not an app's identity, a section tile, a status or the official logo.
- **Don't** use a section color as text, a border, a card fill or a gradient, and don't put Lampblack ink on a section tile.
- **Don't** write hex values outside `:root`; use the tokens. The two exceptions are the `dialog::backdrop` scrim, which mirrors `--scrim` because older browsers don't pass custom properties to `::backdrop`, and the official logo in `index.html` (the sidebar mark and the favicon), whose colors are the upstream art's own.
- **Don't** load webfonts or any other remote asset.
- **Don't** show a secret anywhere, including a command line; masked values read `•••`.
