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
  warning-bg: "#2a2412"
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
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "17px"
    fontWeight: 550
    lineHeight: 1.35
    letterSpacing: "-0.015em"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "14px"
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
  toast: "12px"
  tile: "14px"
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
    height: "30px"
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
  app-art:
    backgroundColor: "{colors.active}"
    rounded: "{rounded.tile}"
    size: "54px"
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

The dashboard is one dark ring that holds every account. The ground is Lampblack, a warm near-black, and text is Bone. Hue is reserved for identity: each app gets one color from a fixed eight-hue palette, and that app's account cards, primary action, focus ring and glow all carry it. Apart from status, nothing else on screen is colored.

Density is a desktop tool's: a 14px base, 13px labels, a 216px sidebar and 32px gutters. The CLI stays visible: every dialog shows the command it will run, and every Activity entry the command that ran. Surfaces are tonal steps of graphite with 1px borders between them. Depth comes from tone; only things that float (dialogs and toasts) cast a shadow.

Motion is soft and springy. Controls press to 0.97 and spring back, cards rise 3px under the pointer, and desktop dialogs scale in from 0.96 and settle with a small overshoot. With reduced motion on, the springs and spatial scenes are gone, replaced by static, keyboard-reachable content. The dashboard is dark-only. The project site (`site/`) is a separate visual world owned upstream, and this file does not describe it.

**Key Characteristics:**
- Warm black ground, warm off-white text, graphite steps in between.
- One hue per app, assigned once and kept for that app everywhere.
- Flat tonal cards; shadow only on floating layers.
- Spring motion with a full reduced-motion path.
- Platform UI font only; nothing loads from the network.
- The exact `aidentity` command behind every action, shown before and after it runs.

## Colors

A warm graphite ramp from Lampblack to Bone, lit only by eight app hues and two status colors.

### Primary
The eight app hues, defined once in CSS as `--hue-mint` … `--hue-violet`. `app.js` and `experience.js` read them from those tokens (with a frozen fallback and a console warning if one is missing), hash each app name into the palette and resolve collisions, so an app keeps its hue across screens and sessions. The app's secondary hue is the palette entry three steps on. Every hue clears 6.2:1 against Lampblack, so app-colored fills always take Lampblack text.

- **Mint** (`mint`): the default accent before any app context. It is also the positive status color and the sidebar logo color.
- **Periwinkle** (`periwinkle`): the default `--app-color` and the header add action outside app context.
- **Teal**, **Orange**, **Pink**, **Gold**, **Sky**, **Violet**: app hues, with no role outside app identity.

`--accent` is Mint globally and the app's hue inside an app-toned scope (`.app-tone{--accent:var(--app-color)}`); focus rings and focused fields follow it.

Saved account badges are a separate, user-chosen set: the eight hues (built from the same tokens) plus Gray and Graphite. A badge keeps its saved color; it never follows the app hue.

### Neutral
- **Lampblack** (`lampblack`): page ground, and the ink on any app-colored fill.
- **Surface** (`surface`): panels, dialogs, sidebar hover.
- **Card gradient** (`card-top` to `card-bottom`): the resting fill of profile, application, operation cards and the detail panel.
- **Raised** (`raised`): secondary buttons, selected nav item, cover strips, field fill.
- **Active** (`active`): pressed and selected segments, the app-art tile.
- **Border** (`border`): hairlines between regions and around cards.
- **Control** (`control`): borders of buttons and dialogs.
- **Field border** (`field-border`): text fields, selects and file inputs (3.6–3.9:1 on every surface), and the ring that makes the Graphite swatch visible.
- **Tip** (`tip`): toast ground.
- **Bone** (`bone`): primary text, the default primary button fill, the tab indicator.
- **Muted** (`muted`): secondary text, idle nav items, idle tabs, placeholders, the stat line.

### Status
- **Positive**: Mint (running state, success toasts).
- **Negative** (`negative`): errors and destructive buttons, on `negative-bg`.
- **Warning**: danger callouts use `warning-bg` with Bone text.

### Named Rules
**The Identity-Only Rule.** Hue means an app or a status. Everything else stays on the Lampblack-to-Bone ramp. Stat counts and operation cards are neutral.

**The Ink Rule.** Text on an app-colored fill is Lampblack. A badge picks whichever of Lampblack (#060606) and white (#ffffff) contrasts more with its saved color; every preset clears 4.83:1.

## Typography

**Display Font:** the platform UI font (`-apple-system`, BlinkMacSystemFont, "Segoe UI", sans-serif)
**Body Font:** the same stack
**Label/Mono Font:** `ui-monospace`, SFMono-Regular, Menlo, monospace, for command lines and command output only

**Character:** San Francisco on a Mac, set tight at the top and plain below. Headings close up their tracking; labels stay at normal tracking and a 500 weight.

### Hierarchy
- **Headline** (600, 28px, 1.2, -0.035em): page titles on every view. Below 768px every page title is **Headline compact** (24px).
- **Card** (550, 22px, 1.2, -0.03em): dialog titles, empty-state titles, the detail title on mobile.
- **Title** (550, 17px, 1.35, -0.015em): card and section headings, profile names, account names on Explore keys.
- **Body** (400, 14px, 1.55): the base size.
- **Label** (500, 13px): buttons, tabs, form labels, page subtitles, the stat line.
- **Meta** (400, 12px): profile metadata, state rows, counts, help text.
- **Mono** (12px, 1.7): command lines ("Runs:", Activity) and command output blocks, wrapped, never truncated.

Nothing is smaller than 12px. Exempt from the ramp: the sidebar wordmark (19px, part of the logo lockup), the app-art initial (23px) and other glyphs sized inside icon boxes (Explore arrows 18px, list icons 24px, the focus panel's app icon 30px).

### Named Rules
**The System Voice Rule.** One family: the platform UI font. The dashboard loads no webfonts.

**The Tabular Count Rule.** Counts, tab totals and reel positions use tabular numerals.

## Layout

A fixed sidebar beside a fluid canvas. The sidebar is 216px, collapses to a 72px icon rail on request, narrows to 190px at 1150px, and becomes a 248px slide-over drawer with a scrim below 768px. The sidebar scrolls when it runs out of height, and the "Your apps" list is capped at 40% of the viewport, so the Command guide and Collapse stay reachable at 200% zoom and on a landscape phone. The top bar is 68px (64px on mobile).

Workspace gutters are 32px, 24px at 1150px and below, and 18px below 768px. Gaps are mostly 8, 12, 16, 20 and 24px. Profile cards sit in three columns (two at 1200px and below), and in two columns (one at 1200px and below) when the 320px detail panel is open beside them (300px at 1200px and below). Between 768px and 900px the detail panel follows the grid in reading order; selecting a card moves focus to it. Below 768px the detail panel replaces the grid. Explore splits 2:3: a sticky 556px focus panel (356px on mobile), then the app list.

The fixed activity bar is 40px tall; focusable content inside `#main` keeps a scroll margin so the bar never covers a focused control, also while the activity panel is open.

Breakpoints in use: 390px, 767/768px, 900/901px, 1100px (Explore), 1150px and 1200/1201px.

## Elevation & Depth

Tonal, with shadows only when floating. Cards, panels, Explore keys and the sidebar sit flat: depth comes from the step between Lampblack, Surface and Raised and from 1px borders. On app-toned cards a radial glow in the app hue (14% at the base, fading by 72%) tints the bottom edge; it marks identity and never lifts the card. Hover lifts a card 3px and draws its outline in the app hue, still without a shadow.

### Shadow Vocabulary
- **Dialog** (`--shadow-dialog`): modal dialogs and the mobile bottom sheet.
- **Toast** (`--shadow-toast`): the stacked toast column.
- **Focus ring** (`box-shadow: 0 0 0 3px` accent at 15%, `--ring-accent` outside app context): focused fields, with the border in the accent.
- **Identity glow** (`box-shadow: 0 0 12px` app hue at 48%): the 8px app dot in the sidebar, the "In focus" dot, and a running key on Explore.

### Named Rules
**The Floating-Only Shadow Rule.** A shadow means the layer floats above the page (dialogs, toasts). Resting cards and keys never get one; a glow marks identity or a running account, never height.

## Shapes

Soft rectangles, nested by size. Controls, nav items, icon buttons, Explore badges and the file-picker button are 8px; toasts and reel faces 12px; the app-art tile and Explore preview 14px; cards and panels 16px; dialogs 20px, and 20px on the top corners only as a mobile sheet. Status and app dots are full circles (5px running dot, 8px identity dot).

The app-art tile overlaps the card's cover strip and wears a 4px ring in the card's Surface color, so it reads as cut into the card.

## Components

### Buttons
Soft and springy: every button lifts 1px on hover, presses to 0.97 in 85ms and springs back.
- **Shape:** gently rounded (8px), 36px tall (40px in profile cards), 14px side padding, 13px label at 500. Below 768px touch targets reach 44px.
- **Default:** transparent with a Control border. Hover fills Raised and lightens the border to Muted.
- **Primary:** Bone fill, Lampblack text. On an app's screens the fill is the app hue with Lampblack text; hover mixes in 10% Bone.
- **Secondary:** Raised fill, no border.
- **Danger:** Negative text and a `negative-bg` border; hover fills `negative-bg` and borders in Negative.
- **Small:** 30px tall, 13px label, 10px side padding.
- **Busy:** a spinner replaces the label; under reduced motion the spinner pulses in opacity instead of turning.

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** the card gradient (#0f0f0f to #090909).
- **Shadow Strategy:** none at rest; see Elevation & Depth.
- **Border:** 1px Border; on app cards mixed with 32% of the app hue, 65% on hover. Operation cards stay neutral.
- **Internal Padding:** 24px desktop, 20–22px mid, 16–18px mobile.

### Inputs / Fields
- **Style:** 40px, Raised fill, 1px Field border, 8px radius, 9px × 12px padding. The search field has a 16px leading icon and a 32px clear button.
- **Focus:** the border turns to the accent (the app hue in app context) with a 3px ring at 15%. Under forced colors, a 2px Highlight outline.
- **Error:** a `negative-bg` form-error block above the actions, and `aria-invalid` on the field the server rejected.

### Navigation
- **Sidebar:** a `<nav aria-label="Main">` landmark. 40px items, 8px radius, Muted text. Hover shows Bone on Surface; the current page shows Bone on Raised. App entries carry an 8px glowing dot in their hue, and hovering one tints its row 11% toward the hue.
- **Tabs:** 13px labels in Muted, Bone when selected, 44px tall, with a 2px Bone underline that springs between tabs. Arrow, Home and End move between tabs. When the strip overflows on a narrow phone, its right edge fades and the selected tab scrolls into view.
- **Mobile:** the sidebar becomes a drawer from the left behind a 60% black scrim; Tab stays inside it and the page behind is inert.
- **Focus on navigation:** the new view's `h1` takes focus (no ring; it is not a control) and the document title becomes "<View> · aidentity".

### Stat line
One quiet text row under the page title: counts in Bone tabular numerals, labels in Muted, 13px. No tiles, no hue.

### Dialogs
- **Shape:** 560px wide, 20px radius, Surface fill, Control border, Dialog shadow, header and footer pinned (the footer has a Control top border). Focus starts on the first field.
- **Add profile:** App (preselected from context), Profile name, then "Appearance" (badge character and color, collapsed, defaulting to the name's first letter and the app's hue), then app location and launch settings, then the Runs line. Success selects the new card, scrolls to it and toasts "<App> <Profile> is ready" with "Open it".
- **Motion:** on desktop, enter rises 14px and scales from 0.96 over 420ms on the surface spring; exit falls 10px to 0.97 over 200ms. Below 768px a dialog becomes a bottom sheet that slides up on `--ease`, with no overshoot.

### Toasts
Titles say what happened in plain words ("Opened Claude Work", "Version 1.7.0 is available"), never "<Action> complete". A 340px column at the bottom of the workspace, 32px in from the sidebar (24px at 1200px and below), above the activity bar. Each toast is Tip on a Control border, 12px radius, with a status icon in Mint or Negative. The front toast is expanded; the rest stack behind it and fan out on hover.

### Profile Card (signature)
A 58px cover strip in the app's two hues, the app-art tile cut into its lower edge, the profile name (550, 17px), a meta row above a hairline, a state line with a 5px running dot, then the Open action named for the profile. The whole card is tinted by its app: the border mix, the bottom glow and the hover outline.

### Explore key ring (signature)
The focus panel holds the selected app's accounts side by side as keys. A short identity reel (the depth-wheel adaptation, faster) turns between apps; at rest the panel shows the app's icon, name and account count, then the ring. Each key carries the account's badge in its saved color and ink, the account name (Title), an "Original" mark on the main account, its status label, and one action: Open, or Bring to front when it is running. A running key glows in the app hue and lights up once when it starts (static under reduced motion). The ring wraps and scrolls from six accounts; "+ Add account" sits under it. Prev, Next, the jump select and the list's Preview buttons switch apps; a mouse or trackpad scrolling over the panel switches apps too, except over a ring that scrolls, and touch scrolls the page. Keys are a real list with names that start with their visible text ("Open, Work, Claude", "Bring to front, Work, Claude").

### Command line
Every dialog that runs an action shows a "Runs:" line under the form: the exact `aidentity …` command from the server's preview, in Mono 12px on Lampblack with a 1px Border, selectable, with a Copy button. It updates as fields change and hides while the form is invalid. Every Activity entry shows the command that ran. Values the CLI treats as secret (environment values, proxy credentials, an imported recipe's contents) always appear as `•••`. The browser never builds the command itself.

### Status labels
The CLI's status words become: `running` → Running · `in use` and `not running` → At rest · `signed out / new` → Not opened yet · `app missing` → App missing. Explore and Profiles use the same table.

### Connection and busy states
When a poll or action can't reach the dashboard server, a banner says "The dashboard stopped. Run `aidentity dashboard` in Terminal to reconnect.", action buttons are disabled, and the sidebar dot turns to "Disconnected"; all of it clears on the next good poll. While an action runs, other actions show a calm disabled state.

## Do's and Don'ts

### Do:
- **Do** give each app exactly one hue through `--app-color`, and use it for that app's primary action, focus ring, hover outline and bottom glow.
- **Do** define a new hue only as a `--hue-*` token; both scripts read the palette from CSS.
- **Do** put Lampblack (#060606) text on any app-colored fill; every hue clears 6.2:1.
- **Do** keep text at Muted (#8d8b84) or brighter and at 12px or larger. Muted on Raised (5.4:1) is the lowest text pairing in use.
- **Do** show keyboard focus as a 2px outline in the current accent, offset 4px (swatches use Bone at 3px; controls inside clipping boxes use an inset ring).
- **Do** give every spring and spatial scene a reduced-motion path that keeps the feedback.
- **Do** keep controls at least 36px tall on desktop and 44px below 768px.
- **Do** show the server's command for every action (Runs line, Activity); never build it in the browser.

### Don't:
- **Don't** add a light theme. The dashboard is dark-only.
- **Don't** bring the site's blue or its light/dark switch into the dashboard. The site is a separate world owned upstream.
- **Don't** put a shadow on a resting card. Shadows belong to dialogs and toasts.
- **Don't** color anything that is neither an app's identity nor a status.
- **Don't** write hex values outside `:root`; use the tokens. The one exception is the `dialog::backdrop` scrim, which mirrors `--scrim` because older browsers don't pass custom properties to `::backdrop`.
- **Don't** load webfonts or any other remote asset.
- **Don't** show a secret anywhere, including a command line; masked values read `•••`.
