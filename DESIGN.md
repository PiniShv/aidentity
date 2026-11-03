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
  control: "8px"
  section-tile-nav: "7px"
  section-tile-phone: "9px"
  section-tile: "10px"
  toast: "12px"
  tile: "12px"
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
    backgroundColor: "{colors.raised}"
    textColor: "{colors.bone}"
  tab:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    height: "44px"
  tab-selected:
    textColor: "{colors.bone}"
  card:
    backgroundColor: "{colors.surface}"
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
---

# Design System: aidentity dashboard

## Overview

**Creative North Star: "The Keyring"**

The dashboard is one dark ring that holds every profile. The ground is Lampblack, a warm near-black, under a slow ambient field of glyphs in Bone at 12%, and text is Bone. Color comes in two layers that never share a form. Apps: an app that has profiles gets one bright hue from a fixed seven-hue palette, and that app's primary action, app tile, dots, borders and focus rings carry it. Sections: each part of the dashboard owns one deep tile color, a rounded square with a Bone glyph, as in macOS System Settings. Apart from those two layers and status, nothing on screen is colored. There is no second hue for an app, no gradient in a hue and no glow.

Density is a desktop tool's: a 14px base, 13px labels, a 216px sidebar and 32px gutters. The CLI stays visible: every dialog shows the command it will run, and every Activity entry the command that ran. Surfaces are tonal steps of graphite with 1px borders between them. Depth comes from tone; only things that float (dialogs and toasts) cast a shadow.

Motion is brief and springy, and it never overshoots: every surface opens on a click, not a flick, so every spring is critically damped. Controls press to 0.97 on pointer-down and spring back, dialogs rise and scale in from 0.96, panels leave the way they came, pages crossfade, and the sidebar highlight slides to the new page. Hover moves nothing; it changes fill and border. With reduced motion on, the springs and both crossfades become static swaps, the ambient field holds one still frame, and every action stays keyboard-reachable. The dashboard is dark-only. The project site (`site/`) is a separate visual world owned upstream, and this file does not describe it.

**Key Characteristics:**
- Warm black ground under a faint drifting glyph field, warm off-white text, graphite steps in between.
- One flat hue per app with profiles, assigned once and kept for that app everywhere; apps without profiles stay neutral.
- One deep tile color per section, on its sidebar row, its page title and its operation cards.
- Flat tonal cards; shadow only on floating layers.
- Spring motion with a full reduced-motion path.
- Platform UI font only; nothing loads from the network.
- The exact `aidentity` command behind every action, shown before and after it runs.

## Colors

A warm graphite ramp from Lampblack to Bone, lit only by seven app hues, eight section tiles and the status colors.

### Primary
The seven app hues, defined once in CSS as `--hue-periwinkle` … `--hue-violet`. `app.js` and `experience.js` read them from those tokens (with a frozen fallback and a console warning if one is missing). Only apps that have at least one profile get a hue: `app.js` hashes each app name into the palette, resolves collisions so no two such apps share a hue while one is free, and keeps the hue an app got first. An app with no profiles has no hue and renders in graphite with Bone ink. Every hue clears 6.2:1 against Lampblack, so app-colored fills always take Lampblack text.

- **Periwinkle**, **Teal**, **Orange**, **Pink**, **Gold**, **Sky**, **Violet** (`periwinkle` … `violet`): app hues, with no role outside app identity.
- **Mint** (`mint`): not an app hue. It is the positive status color, the sidebar logo, the connection dot and the default accent.

`--accent` is Mint globally and the app's hue inside an app-toned scope (`.app-tone{--accent:var(--app-color)}`); focus rings, the focused-field border and the caret follow it. `--app-color` is set only on an app-toned element, never on `:root`.

Hue appears in exactly five forms: a solid fill with Lampblack ink (the primary button of an app scope, the app tile), a plain dot, a 1px border (hover, running, the chosen navigator row), a focus ring, and the 15% ring on a focused field. The header Add button is always Bone. A selected profile card is marked on the neutral ramp instead: a 2px Bone outline at a 2px offset.

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
- **Surface** (`surface`): panels, dialogs, Explore keys, sidebar hover.
- **Card gradient** (`card-top` to `card-bottom`): the resting fill of profile, application and operation cards, the detail panel and the Explore panel; neutral, never tinted.
- **Raised** (`raised`): secondary buttons (with a Field border edge), selected nav item, field fill, notices.
- **Active** (`active`): the app tile of an app with no hue.
- **Border** (`border`): hairlines between regions and around cards.
- **Button edge** (`button-edge`): the 1px edge of default (outlined) buttons and key caps, at least 2.1:1 on Lampblack, Surface, the card gradient and Raised.
- **Control** (`control`): borders of dialogs, toasts, Explore buttons and dashed empty states.
- **Field border** (`field-border`): text fields, selects and file inputs (3.6–3.9:1 on every surface), the edge of the secondary (Open) button, and the ring that makes the Graphite swatch visible.
- **Tip** (`tip`): toast ground.
- **Bone** (`bone`): primary text, the default primary button fill, the tab indicator, and the ambient field's glyphs at 12%.
- **Muted** (`muted`): secondary text, idle nav items, idle tabs, placeholders.

### Status
- **Positive**: Mint (the running mark, success toasts).
- **Negative** (`negative`): errors and destructive buttons, on `negative-bg`.
- **Danger edge** (`danger-edge`): the 1px edge of a destructive button at rest, at least 2.2:1 on the same surfaces as the Button edge.
- **Warning** (`warning`, Amber): the icon and level of a warning finding, the warning toast icon, the alert icon that leads every callout and danger callout, and the Needs repair count while it is above zero. Callouts use `warning-bg` with Bone text. Amber clears 9.3:1 on every surface it sits on.
- The Running tab count turns Mint while it is above zero; a finding marked ok has a Mint check. In the Workspace health summary, the OK, warning and error numbers take Mint, Amber and Negative while above zero; their words stay Muted.

### Increased contrast
Under `prefers-contrast: more`, Muted becomes #b4b2aa (7.3:1 on Warning bg, 8.7:1 on Raised, 9.5:1 on Lampblack), Border takes the Button edge, Control the Field border, the Button edge becomes Muted, the Field border #9a988f, the Danger edge Negative, and every material turns solid. The ambient field is gone, here and under forced colors, so the ground is solid Lampblack. Hues and Bone stay as they are.

### Named Rules
**The Two Layers Rule.** A bright hue means an app that has profiles; a deep tile color means a section of the dashboard; Mint, Amber and Negative mean status. Everything else stays on the Lampblack-to-Bone ramp: card surfaces, text, apps without profiles and the counts that are not status.

**The Section Rule.** A page's tiles take its section's color, except a destructive operation's tile, which is Brick. A section color is only ever a tile fill or the current-page highlight, never text, a border or a card surface.

**The One Running Mark Rule.** Running is an 8px Mint dot plus "Running" in Mint, on cards, the detail panel, Explore keys and the navigator alike, and the running card or key also keeps its 1px hue border. A profile that is not running shows no dot.

**The Flat Hue Rule.** A hue is a solid fill, a plain dot, a 1px border or a focus ring. Never a gradient, glow, tinted text, tinted background, tinted secondary button or accent stripe, and never a second hue for the same app.

**The Ink Rule.** Text on an app-colored fill is Lampblack. A badge picks whichever of Lampblack (#060606) and white (#ffffff) contrasts more with its saved color; every preset clears 5.9:1.

## Typography

**Display Font:** the platform UI font (`-apple-system`, BlinkMacSystemFont, "Segoe UI", sans-serif)
**Body Font:** the same stack
**Label/Mono Font:** `ui-monospace`, SFMono-Regular, Menlo, monospace, for command lines, command output and key caps only

**Character:** San Francisco on a Mac, set tight at the top and plain below. Headings close up their tracking; labels stay at normal tracking and a 500 weight.

### Hierarchy
- **Headline** (600, 28px, 1.2, -0.035em): page titles on every view. Below 768px every page title is **Headline compact** (24px).
- **Card** (550, 22px, 1.2, -0.03em): dialog titles, empty-state titles, the Explore panel's app name, the detail title on mobile.
- **Card compact** (550, 19px, 1.2, -0.03em): below 768px, every Card heading inside the page (the Explore panel's app name, empty-state titles, the detail title), so it reads under the 24px page title and not beside it. Dialog titles stay at Card.
- **Title** (550, 17px, 1.35, -0.015em): card and section headings, profile names, app names, profile names on Explore keys, Recovery's profile rows.
- **Title compact** (550, 15px, 1.3, -0.015em): the Explore navigator's app names, the names on one-row Explore keys and the phone top bar's page name.
- **Body** (400, 14px, 1.55): the base size, and the text of an empty state.
- **Secondary** (400, 13px, 1.55, Muted): page subtitles, card, panel and dialog descriptions, Terms definitions.
- **Label** (500, 13px): buttons (Explore's included), tabs, form labels, the Terms and Local storage headings, toast titles and Activity entry titles. Label text that can wrap (toast and Activity titles, name lists in dialogs) sets at 1.4.
- **Meta** (400, 12px): profile metadata, state rows, counts, times, help text, the Explore "N apps · N profiles" summary, the Explore "N of M" position.
- **Mono** (12px, 1.7): command lines ("Runs:", Activity) and command output blocks, wrapped, never truncated.

Nothing is smaller than 12px. Exempt from the ramp: the sidebar wordmark (19px, part of the logo lockup) and glyphs sized inside icon boxes (the app-tile initial 20px, 21px in the detail panel; Explore navigator initial 16px and panel initial 20px; Explore arrows 18px; rail initials 12px; the badge character 13px on an Explore key and 12px on a profile tile).

### Rhythm and line breaks
A card heading sits 8px over its own description; blocks inside a card are 12px apart. A page's title row sits 24px above its body (20px below 768px), on every view, Explore included. Headings balance their lines and prose wraps `pretty`. A name joined by underscores, such as `Northwind_Research_Quarterly_Review_Team`, breaks after an underscore (a `<wbr>` in a copy hidden from assistive tech, which reads the plain name), never mid-word; only a segment wider than its line breaks inside. A command line keeps its own rule (see Command line).

### Named Rules
**The System Voice Rule.** One family: the platform UI font. The dashboard loads no webfonts.

**The Tabular Count Rule.** Counts (tab totals, "N profiles" and "N apps" lines, the health summary), the Explore position and every time use tabular numerals.

## Layout

A fixed sidebar beside a fluid canvas. The sidebar is 216px, collapses to a 72px icon rail on request, narrows to 190px at 1150px, and becomes a 248px slide-over drawer with a scrim below 768px. The sidebar scrolls when it runs out of height, and the "Your apps" list is capped at 40% of the viewport, so Help and Collapse stay reachable at 200% zoom and on a landscape phone. The top bar is 68px (64px on mobile, where it also names the page).

Workspace gutters are 32px; the canvas drops to 24px at 1200px and below (the top bar at 1150px), and to 18px below 768px. Gaps are mostly 8, 12, 16, 20 and 24px. The Profiles grid starts 20px below the tab strip (16px below 768px), also when no toolbar sits between them. Profile cards fill the grid by width (210px minimum, 20px gap; one or two cards stop at 360px) and never by selection. At 901px and up the grid always has a 320px detail column beside it while the status tab shows at least one card, or while the app filter and search still include the chosen profile, so choosing a card never reflows the grid and a status tab, an action or a poll never drops a choice; an empty state with no chosen profile spans the full width. Nothing is selected for the user: until they choose, the column holds a dashed prompt, "Select a profile to see its settings and actions." Only an explicit choice returns on a later visit, or when the filter or search shows its card again. Between 768px and 900px the detail panel follows the grid in reading order and the prompt is hidden; below 768px the panel replaces the grid behind a Back button. Selecting a card moves focus to the panel's heading, and the panel fades in over 140ms without sliding: selection is frequent, so it gets no travel.

Explore is a focus panel on the left (the remaining width) and a navigator of apps on the right (a 240px to 300px column, 28px gap; 220px to 260px and a 20px gap from 768px to 1100px). The panel's height follows its content and it sticks 24px from the top only while it fits above the activity bar; a taller panel scrolls with the page. Below 768px the columns stack. Applications is three columns (two at 1200px and below, one on mobile); Maintenance is two columns of operation cards, with Workspace health spanning both and splitting in two from 768px; Help is a 270px control column beside the output, below a three-column Terms block (two at 900px, one on mobile).

The fixed activity bar is 40px tall and absent until the first action runs; its panel opens above it up to 45% of the viewport (50% on mobile). Focusable content inside `#main` keeps a scroll margin so the bar never covers a focused control, also while the panel is open.

Breakpoints in use: 390px, 767/768px, 900/901px, 1100px (Explore gap), 1150px and 1200px.

## Elevation & Depth

Tonal, with shadows only when floating. Under everything lies the ambient field: the sidebar, the top bar and the open canvas show it, and every filled surface covers it. Cards, panels, Explore keys and the sidebar sit flat: depth comes from the step between Lampblack, Surface and Raised and from 1px borders. Hover draws a card's border in the app hue (Muted on a neutral card) and does not move it. A running profile card draws a full 1px hue border, and so does the chosen navigator row (Muted for an app with no hue). A selected profile card adds a 2px Bone outline at a 2px offset, so a card that is selected and running shows both. A running Explore key draws a plain 1px hue edge and lights it once when it starts.

### Shadow Vocabulary
- **Dialog** (`--shadow-dialog`): modal dialogs and the mobile bottom sheet.
- **Toast** (`--shadow-toast`): the stacked toast column.
- **Focus ring** (`box-shadow: 0 0 0 3px` accent at 15%, `--ring-accent` outside app context): focused fields, with the border in the accent.

### Material
The fixed chrome that content passes under is a translucent layer, not a shadow: the activity bar and the phone top bar are `--material-bar` (Lampblack at 88%), the activity panel `--material-panel` (Surface at 92%), both with `blur(20px) saturate(140%)`. Muted text on the bar stays at 4.6:1 or more even over a solid Bone area. It turns solid where `backdrop-filter` is unsupported, under `prefers-reduced-transparency` and under `prefers-contrast: more`. Nothing in the content layer is translucent.

### Named Rules
**The Floating-Only Shadow Rule.** A shadow means the layer floats above the page (dialogs, toasts). Resting cards and keys never get one, and no hue ever glows; identity and running state are a border or a dot, never height or light.

**The Ambient Ground Rule.** The glyph field is the only thing that moves at rest. It is neutral, every glyph Bone at a flat 12% and never a hue, and it lies under every layer; brightness is glyph density, not ink. It drifts at no more than 30 frames a second, grows denser near the pointer and pauses while the tab is hidden; under reduced motion it holds one still frame, and under increased contrast and forced colors it is gone. At 12% Muted text keeps 4.6:1 over any glyph; 13% would leave 4.5:1 with no margin, so 12% is the ceiling.

## Shapes

Soft rectangles, nested by size. Controls, nav items, icon buttons, Explore key badges and navigator tiles, and the file-picker button are 8px; Explore keys, navigator rows and toasts 12px; the app tile 12px (10px in the Explore panel); the Explore panel 14px; section tiles 10px at 36px (9px at 32px on phones) and 7px at 24px in the sidebar; cards and panels 16px; dialogs 20px, and 20px on the top corners only as a mobile sheet. The badge on a profile tile and the rail initial are 6px. Status and app dots and the color swatches are full circles (8px running dot, 8px app dot, 6px connection dot, 32px swatch, 44px on mobile).

A badge is always a filled rounded square in its saved color, with no stripe or shadow: 34px on an Explore key, 20px at the corner of a profile tile, where it overlaps the tile by 6px. A badge on a tile carries a 2px ring in the surface it sits on (the card gradient's top, Raised in a dialog preview), so even a badge in the tile's own color reads as a separate chip. A profile set to use the original app icon has no badge: its tiles show the app glyph alone, and its Explore key fills the 34px badge slot with the app's icon at 20px on the app hue with Lampblack ink (Raised with Bone ink for an app with no hue).

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
- **Link button:** underlined 13px text, 36px tall (44px on mobile); the "N profiles" count on an application card and "Custom color…".
- **Explore buttons:** the same 36px shape on a Surface fill with a Control border. A key's Open is the Secondary and its Bring to front the hue fill, as everywhere. Add profile is a plain Explore button while the app has profiles and takes the Bone fill while it has none: the first profile's action is the one primary in an empty panel. Bone also fills Refresh apps in the state with no apps at all. Neither has an app hue.
- **Busy:** a spinner replaces the label; under reduced motion the spinner pulses in opacity instead of turning.

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** the card gradient (#0f0f0f to #090909).
- **Shadow Strategy:** none at rest; see Elevation & Depth.
- **Border:** 1px Border; on app cards hover draws the app hue (Muted on a neutral card), and a running profile card draws it in full. Selection never takes the hue: a selected profile card adds a 2px Bone outline at a 2px offset. Operation card surfaces stay neutral; each card, and Recovery's restore panel, leads with a 36px section tile.
- **Internal Padding:** 24px for panels and operation cards, 20px for profile and application cards, 22px on mobile.

### Section tile
A flat rounded square in its section's deep color with a Bone glyph, no border, shadow or gradient. 36px with a 20px glyph beside every page title (32px with an 18px glyph below 768px), centered on the title's capitals, with the subtitle aligned under the title text, not the tile; 36px above the heading of an operation card; 24px with a 15px glyph in the sidebar. It is decorative (`aria-hidden`); the label beside it names the section. Under forced colors it gains a 1px CanvasText border.

### Inputs / Fields
- **Style:** 40px, Raised fill, 1px Field border, 8px radius, 9px × 12px padding. The search field has a 16px leading icon and a 36px clear button. Search appears on Profiles from seven profiles, and on Applications always.
- **Focus:** the border turns to the accent (the app hue in app context) with a 3px ring at 15%. Under forced colors, a 2px Highlight outline.
- **Error:** a `negative-bg` form-error block above the actions, and `aria-invalid` on the field the server rejected. A rule the browser can check first (the profile-name `pattern`) stops the submit with the browser's own message and the rule in its `title`.

### Navigation
- **Sidebar:** a `<nav aria-label="Main">` landmark. 40px items, 8px radius, Muted text, each led by its 24px section tile. Hover shows Bone on Surface; the current page shows Bone on its section color mixed 28% into Raised. On a page change that fill slides from the item it left, or from where it is mid-slide, over 340ms on the control spring; under reduced motion it jumps. Under the nav, "Your apps" lists only apps that have profiles, each with an 8px dot in its hue (36px rows, 12px text); "No profiles yet" shows only once data has loaded and there are none. Help and Collapse sit at the foot. Above the nav, one compact status row: a 6px Mint dot (Negative when offline) and "Connected · this Mac".
- **Collapsed rail:** 72px; labels hide, the section tiles stay centered, the status row shows only its dot, and each app shows its initial as a 24px rounded tile in its hue with Lampblack ink, named by a tooltip that appears beside the rail for keyboard focus, with a divider where "Your apps" was. As a mobile drawer the full labels return.
- **Tabs:** 13px labels in Muted, Bone when selected, 44px tall, with a 2px Bone underline that springs between tabs. Profiles tabs are All, Running, Not running and Needs repair, with the counts on the tabs only (Needs repair shows a muted dash until a check has run). Arrow, Home and End move between tabs. The strip appears with the first profile: with none at all it is absent, since the tabs would filter nothing, and the first-run empty state follows the title directly. When the strip overflows on a narrow phone, its right edge fades and the selected tab scrolls into view.
- **Mobile:** the top bar names the page, and the sidebar becomes a drawer from the left behind a 60% black scrim; Tab stays inside it and the page behind is inert.
- **Page change:** the old page fades out in place over 200ms while the new one fades in and rises 8px over 480ms on the surface spring; the activity bar, its panel and the toasts stay still. Without the View Transitions API, or while the phone drawer is open, only the new page animates, from 50% opacity and 8px down. Under reduced motion the swap is instant.
- **Focus on navigation:** the new view's `h1` takes focus (no ring; it is not a control) and the document title becomes "<View> · aidentity". There is no breadcrumb.

### Dialogs
- **Shape:** 560px wide, 20px radius, Surface fill, Control border, Dialog shadow, header and footer pinned (the footer has a Control top border). Focus starts on the first field.
- **Add a profile:** Application (preselected from context; with no app installed, a hint under it points to the app path and the location disclosure opens), Profile name (its help and its `pattern` are the CLI's rule: letters, numbers, spaces, hyphens and underscores, 40 at most, no leading hyphen or outer space, so the browser names the rule before the CLI has to), "Use the original account" (its help says when: once a profile runs, the app's own icon only switches to that profile), then two collapsed disclosures: "Appearance" and "App location & launch settings", then the Runs line, hidden while any field is invalid. Appearance holds the badge character (it defaults to the name's first letter and sits at the corner of the launcher's icon), a "Use the original app icon" checkbox that hides the colored badge, and the badge color: ten 32px round swatches (44px on mobile), the chosen swatch's name and hex as visible text ("Periwinkle · 7C8CFF"), and a "Custom color…" link that reveals the hex field (open from the start only when the saved color is not a swatch). The default color is the first swatch that is neither the app's hue nor worn by that app's other profiles. Success selects the new card, scrolls to it and toasts "<App> <Profile> is ready" over "Open it to sign in with that account." ("Open it to use the original account." for the original account) with an "Open it" action. The same rule guards Rename's new name.
- **Settings, Rename, Remove, Import profiles, Export profiles:** the same dialog frame; Settings is titled "Settings for <name>", its preview row omits the name and offers Rename…, and it sends only what changed.
- **Motion:** on desktop, enter rises 14px and scales from 0.96 over 420ms on the critically damped spring, with no overshoot; exit falls 14px to 0.96 over 200ms. Below 768px a dialog becomes a bottom sheet that slides up on `--ease`, with no overshoot.

### Toasts
Titles say what happened in plain words ("Opened Claude Work", "Brought Claude Work to the front"), never "<Action> complete". A 340px column at the bottom of the workspace, 32px in from the sidebar (24px at 1200px and below), above the activity bar. Each toast is Tip on a Control border, 12px radius, with a status icon in Mint, Amber or Negative. The front toast is expanded; the rest stack behind it and fan out on hover.

### Profile card (signature)
The Profiles grid's unit. A 44px app tile in the app's hue (graphite for an app with no hue), carrying the profile's 20px badge at its corner (none for a profile that uses the original app icon), sits beside an `h2` whose name is a button (Title) over the app name (13px Muted). Clicking the card or pressing Enter on the name selects it; only the visible Open button launches, and O opens only while focus is inside the selected card or the detail panel. Below: a state row with the status label (an 8px Mint dot and Mint text when running), plus small Repair and Quit actions when they apply; a Meta line of "Original account · Own extensions · N launch options"; then one full-width, 40px primary action: Open (the Secondary), or Bring to front (the hue fill) when the profile is running. Quit is a small outlined button beside the state, never in the primary slot. There is no cover strip. Hue shows only in the tile, the Bring to front fill, and the hover and running borders; selection is a 2px Bone outline at a 2px offset.

### Application card
Every app the dashboard lists (Claude and ChatGPT) is a card, apps with profiles first, then by name: a 44px tile and the name over an underlined "N profiles" link button that opens Profiles filtered to that app, then a full-width Add profile. An app with no profiles is the same card on the neutral ramp, with a graphite tile and "0 profiles". With no apps the grid holds "No AI apps found" and Refresh apps.

### Detail panel (signature)
A 320px card on the right of the grid at 901px and up: sticky 24px from the top, with a max-height that fits between the top bar and the activity bar (and the open Activity panel), scrolling inside with a fade at the bottom edge only while it overflows. Before a choice the column holds a dashed prompt instead. From 768px the selected card already shows the state, Quit and primary action, so the panel omits them; below 768px, where it replaces the grid, it keeps them. Top to bottom: the 48px app tile with its badge, the profile name as `h2` over "<App> · original account" where it applies, the "Runs:" line with a Copy button, one row of small actions (Settings and Rename, with Remove in Negative pushed to the far end), then "Launch settings: app defaults" in one line, or the launch arguments, environment variable names and extensions when any are set, and last a "Details" disclosure holding the application path, profile data folder, who made the launcher, and "Rebuild launcher" with one sentence of explanation. Below 901px it follows the grid and gains a close button; below 768px, a Back button.

### Explore focus panel (signature)
The panel holds the selected app's profiles side by side as keys, under the app's identity (44px tile, name in Card, "N profiles" and, while any run, the running mark). Above the identity sit Prev, "N of M", Next and a jump select; they step through every listed app and are hidden when only one app is listed. An app with no profiles shows "No <App> profiles yet. A profile opens <App> with its own sign-in, so your accounts run side by side." as a dashed Control placeholder with no fill, never a card inside the panel, above Add profile. Until the first profile exists anywhere, the page subtitle reads "Choose an app and add its first profile." A change of app crossfades the identity in 160ms (a static swap under reduced motion); nothing switches apps on scroll, and there is no reel or wheel. Each key carries the profile's badge in its saved color and ink (the app's icon on the app hue when the profile uses the original app icon), the profile name (Title), a state line (the running mark, or the status label, plus " · Original" on the original account), and the profile's one action: Open, or Bring to front when it is running. A running key has a 1px hue edge and draws it once when it starts (static under reduced motion), with no glow. Keys fill a grid of 200px columns and become one-row keys when the panel is narrow. "Add profile" sits under them. Keys are a real list with names that start with their visible text ("Open Work, Claude", "Bring to front, Work, Claude").

### Explore navigator
The list beside the panel chooses the app and holds no profile actions. Every listed app is a row, apps with profiles first (running ones, then most profiles, then by name), one 60px row each with a 36px tile, the app name (15px), "N profiles" and the running mark while any profile runs. An app with no profiles keeps its row, neutral, with "0 profiles". The chosen row draws a 1px hue border on Surface (Muted for an app with no hue). A 12px "N apps" and "N profiles" summary sits above the list; it is the one count line (Profiles keeps its counts on its tabs). With no apps at all, Explore shows "No AI apps found" and Refresh apps instead of the panel and list, the same words as Profiles and Applications. There is no "All profiles" button.

### Command line
Every dialog that runs an action shows a "Runs:" line under the form: the exact `aidentity …` command from the server's preview, in Mono 12px on Lampblack with a 1px Border, selectable, with a Copy button. It updates as fields change and hides while the form is invalid. The detail panel shows the Open command the same way, with its own Copy button. A command breaks only between shell words, never inside a quoted name. Every Activity entry shows the command that ran. Values the CLI treats as secret (environment values, proxy credentials, an imported recipe's contents) always appear as `•••`. The browser never builds the command itself.

### Activity bar
A 40px bar fixed to the bottom, hidden until the first entry (or while an action runs), on the bar material. The panel rises 10px and fades in over 340ms and leaves along the same path; one animation plays forward to open and in reverse to close, so a click mid-flight turns it around from where it is. It shows a terminal icon, a summary ("Activity · Nothing run yet", then "<toast title> · View details") and a chevron that flips when the panel opens. Entries (title, time, command, output) persist in `sessionStorage` for the tab, up to twelve; if storage fails, Activity lasts for the page.

### Help terms
The Help page opens with a "Terms" block above the CLI help: a 16px-radius bordered panel of plain-word definitions (Profile, Launcher, Original account, Doctor, Unclaimed data, Restore) in a three-column list, term in Label and definition in Muted. A full-width "Keyboard" entry lists the shortcuts in Mono key caps with a Button edge border: "/ search · ⌘B collapse sidebar · O open the focused profile".

### Status labels
The CLI's status words become: `running` → Running · `in use` and `not running` → Not running · `signed out / new` → Not opened yet · `app missing` → App missing. Explore and Profiles use the same table. A profile is a "profile"; "account" means only the sign-in; "launcher" appears on Recovery, Maintenance and Help, where the `.app` itself is the subject. The app's own account is the "Original account"; the actions are Settings, Export profiles and Import profiles. The empty phrase is "No profiles yet"; Maintenance offers "Check" and "Check and repair", and Recovery "Clear unclaimed data…". The add flow is "Add profile" at every entry point (the header, Explore, Applications, and "Add your first profile" on the empty Profiles page), "Add a profile" as the dialog title and "Add profile" as its submit; nothing says "Create".

### Empty states
Every empty state names what will appear, why it matters and one next step, in the CLI's words. Profiles with nothing yet: "No Claude or ChatGPT profiles yet" with "Add your first profile". An app filter with nothing: "No <App> profiles yet" with Add profile for that app (the toolbar's All apps clears the filter); when that app is not installed, "Install <App> to add a profile." with Show all profiles instead. Needs repair before a check: "Nothing needs repair" with Show all profiles and Open Maintenance. No app installed: "No AI apps found" with Refresh apps, on Profiles, Applications and Explore alike. Recovery before any profile: "Remove a profile and keep its data, and it appears here, ready to restore." Workspace health: "Not checked yet. Choose Check to see the result here." Export with nothing to export is disabled and says "Nothing to export yet. Add a profile first.", without the private-file callout. Help shows Copy output only once there is output. An empty state is a Surface block that spans the full width unless a chosen profile's panel stands beside it; the dashed prompt appears only beside at least one card.

### Connection and busy states
When a poll or action can't reach the dashboard server, a banner says "The dashboard stopped. Run `aidentity dashboard` in Terminal to reconnect.", action buttons are disabled, and the sidebar status turns to "Disconnected" with a Negative dot; all of it clears on the next good poll. While an action runs, other actions show a calm disabled state.

## Do's and Don'ts

### Do:
- **Do** give each app that has profiles exactly one hue through `--app-color`, and use it only for that app's primary fill, app tile, dots, 1px borders and focus ring.
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
- **Don't** bring the site's blue or its light/dark switch into the dashboard. The site is a separate world owned upstream.
- **Don't** put a shadow on a resting card. Shadows belong to dialogs and toasts.
- **Don't** use a hue as a gradient, a glow, text color, a tinted background or secondary button, or an accent stripe, and don't add a second hue to an app.
- **Don't** give an app with no profiles a hue, and don't use Mint as an app hue; it is status, the logo and the default accent.
- **Don't** recolor the header Add button; it is always Bone.
- **Don't** color anything that is not an app's identity, a section tile or a status.
- **Don't** use a section color as text, a border, a card fill or a gradient, and don't put Lampblack ink on a section tile.
- **Don't** write hex values outside `:root`; use the tokens. The two exceptions are the `dialog::backdrop` scrim, which mirrors `--scrim` because older browsers don't pass custom properties to `::backdrop`, and the favicon in `index.html`, the sidebar's brand mark in Mint on a Lampblack rounded square, because a favicon cannot read CSS variables.
- **Don't** load webfonts or any other remote asset.
- **Don't** show a secret anywhere, including a command line; masked values read `•••`.
