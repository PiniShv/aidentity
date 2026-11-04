/* Core UI adapted from retrieved 21st.dev sources:
 * Animated Sidebar (starc007, 29334), Animated Dialog (rmahammad, 26905),
 * Animated Profile Card (ravikatiyar162, 8206), Animated Tabs (educalvolpz, 24930),
 * Input/Button (originui, 159/146), Toast (cnippet-dev, 24297),
 * Button Spinner (uiable, 19975), Glass Folder Cards (kedhareswer, 37625). React primitives translated to native DOM,
 * dialog, CSS transitions and Web Animations. See docs/dashboard-components.md.
 */
(() => {
  "use strict";
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];
  const escape = value => String(value ?? "").replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]));
  // A name such as Northwind_Research_Team wraps after an underscore, not mid-word. Chromium names each <wbr> as a space, so assistive tech reads a plain copy.
  const breakable = value => {const text=escape(value);return text.includes("_")?`<span aria-hidden="true">${text.replace(/_/g,"_<wbr>")}</span><span class="sr-only">${text}</span>`:text;};
  // UI icons: Hugeicons stroke-rounded (@hugeicons/core-free-icons 4.4.0, MIT, (c) 2025 Hugeicons; notice in docs/dashboard-components.md), 24px grid, stroke 1.5.
  const iconPaths = {
    grid:'<path d="M3.89 9.66C4.39 10 5.1 10 6.5 10C7.9 10 8.61 10 9.11 9.66C9.33 9.52 9.52 9.33 9.66 9.11C10 8.61 10 7.9 10 6.5C10 5.1 10 4.39 9.66 3.89C9.52 3.67 9.33 3.48 9.11 3.34C8.61 3 7.9 3 6.5 3C5.1 3 4.39 3 3.89 3.34C3.67 3.48 3.48 3.67 3.34 3.89C3 4.39 3 5.1 3 6.5C3 7.9 3 8.61 3.34 9.11C3.48 9.33 3.67 9.52 3.89 9.66Z"/><path d="M14.89 9.66C15.39 10 16.1 10 17.5 10C18.9 10 19.61 10 20.11 9.66C20.33 9.52 20.52 9.33 20.66 9.11C21 8.61 21 7.9 21 6.5C21 5.1 21 4.39 20.66 3.89C20.52 3.67 20.33 3.48 20.11 3.34C19.61 3 18.9 3 17.5 3C16.1 3 15.39 3 14.89 3.34C14.67 3.48 14.48 3.67 14.34 3.89C14 4.39 14 5.1 14 6.5C14 7.9 14 8.61 14.34 9.11C14.48 9.33 14.67 9.52 14.89 9.66Z"/><path d="M3.89 20.66C4.39 21 5.1 21 6.5 21C7.9 21 8.61 21 9.11 20.66C9.33 20.52 9.52 20.33 9.66 20.11C10 19.61 10 18.9 10 17.5C10 16.1 10 15.39 9.66 14.89C9.52 14.67 9.33 14.48 9.11 14.34C8.61 14 7.9 14 6.5 14C5.1 14 4.39 14 3.89 14.34C3.67 14.48 3.48 14.67 3.34 14.89C3 15.39 3 16.1 3 17.5C3 18.9 3 19.61 3.34 20.11C3.48 20.33 3.67 20.52 3.89 20.66Z"/><path d="M14.89 20.66C15.39 21 16.1 21 17.5 21C18.9 21 19.61 21 20.11 20.66C20.33 20.52 20.52 20.33 20.66 20.11C21 19.61 21 18.9 21 17.5C21 16.1 21 15.39 20.66 14.89C20.52 14.67 20.33 14.48 20.11 14.34C19.61 14 18.9 14 17.5 14C16.1 14 15.39 14 14.89 14.34C14.67 14.48 14.48 14.67 14.34 14.89C14 15.39 14 16.1 14 17.5C14 18.9 14 19.61 14.34 20.11C14.48 20.33 14.67 20.52 14.89 20.66Z"/>',
    explore:'<path d="M22 12C22 6.48 17.52 2 12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12Z"/><path d="M12.4 8.3L15.32 7.32C16.21 7.03 16.65 6.88 16.88 7.12C17.12 7.35 16.97 7.79 16.68 8.68L15.7 11.6C15.2 13.11 14.95 13.86 14.41 14.41C13.86 14.95 13.11 15.2 11.6 15.7L8.68 16.68C7.79 16.97 7.35 17.12 7.12 16.88C6.88 16.65 7.03 16.21 7.32 15.32L8.3 12.4C8.8 10.89 9.05 10.14 9.59 9.59C10.14 9.05 10.89 8.8 12.4 8.3Z"/><path d="M12.12 12H12M12.25 12C12.25 12.14 12.14 12.25 12 12.25C11.86 12.25 11.75 12.14 11.75 12C11.75 11.86 11.86 11.75 12 11.75C12.14 11.75 12.25 11.86 12.25 12Z"/>',
    apps:'<path d="M3.5 9L20.5 9"/><path d="M11.75 5.81V6M12 6C12 6.14 11.89 6.25 11.75 6.25C11.61 6.25 11.5 6.14 11.5 6C11.5 5.86 11.61 5.75 11.75 5.75C11.89 5.75 12 5.86 12 6Z"/><path d="M8.75 5.81V6M9 6C9 6.14 8.89 6.25 8.75 6.25C8.61 6.25 8.5 6.14 8.5 6C8.5 5.86 8.61 5.75 8.75 5.75C8.89 5.75 9 5.86 9 6Z"/><path d="M5.75 5.81V6M6 6C6 6.14 5.89 6.25 5.75 6.25C5.61 6.25 5.5 6.14 5.5 6C5.5 5.86 5.61 5.75 5.75 5.75C5.89 5.75 6 5.86 6 6Z"/><path d="M3 12C3 7.76 3 5.64 4.32 4.32C5.64 3 7.76 3 12 3C16.24 3 18.36 3 19.68 4.32C21 5.64 21 7.76 21 12C21 16.24 21 18.36 19.68 19.68C18.36 21 16.24 21 12 21C7.76 21 5.64 21 4.32 19.68C3 18.36 3 16.24 3 12Z"/>',
    recovery:'<path d="M3.5 14.97C4.72 18.48 8.07 21 12 21C16.97 21 21 16.97 21 12C21 7.03 16.97 3 12 3C8.3 3 4.9 5.68 3.69 8.5"/><path d="M12 7V12L15 14"/><path d="M7.5 8.74C7.5 8.74 3.81 9.3 3.25 8.74C2.7 8.18 3.25 4.5 3.25 4.5"/>',
    tool:'<path d="M3.74 16.11L8.66 12.6C9.19 12.22 9.5 11.62 9.5 10.97V7.5C9.5 4.74 11.74 2.5 14.5 2.5H18L14.98 6.81C14.7 7.21 14.75 7.75 15.09 8.09L15.91 8.91C16.25 9.25 16.79 9.3 17.19 9.02L21.5 6V9.5C21.5 12.26 19.26 14.5 16.5 14.5H13.03C12.38 14.5 11.78 14.81 11.4 15.34L7.89 20.26C7.33 21.04 6.43 21.5 5.47 21.5C3.83 21.5 2.5 20.17 2.5 18.53C2.5 17.57 2.96 16.67 3.74 16.11Z"/>',
    transfer:'<path d="M19 9H6.66C5.65 9 5.15 9 5.02 8.69C4.9 8.38 5.26 8.02 5.97 7.29L8.21 5"/><path d="M5 15H17.34C18.35 15 18.85 15 18.98 15.31C19.1 15.62 18.74 15.98 18.03 16.71L15.79 19"/>',
    book:'<path d="M8 3.5H6.6C4.43 3.5 3.35 3.5 2.67 4.17C2 4.85 2 5.93 2 8.1L2 13.4C2 15.57 2 16.65 2.67 17.33C3.35 18 4.43 18 6.6 18H8.95C10.43 18 11.71 19.05 12 20.5V5.5C11.06 4.24 10 3.5 8 3.5Z"/><path d="M16 3.5H17.4C19.57 3.5 20.65 3.5 21.33 4.17C22 4.85 22 5.93 22 8.1L22 13.4C22 15.57 22 16.65 21.33 17.33C20.65 18 19.57 18 17.4 18H15.05C13.57 18 12.29 19.05 12 20.5V5.5C12.94 4.24 14 3.5 16 3.5Z"/>',
    panel:'<path d="M2 12C2 8.31 2 6.47 2.81 5.16C3.11 4.68 3.49 4.25 3.92 3.92C5.08 3 6.72 3 10 3H14C17.28 3 18.92 3 20.08 3.92C20.51 4.25 20.89 4.68 21.19 5.16C22 6.47 22 8.31 22 12C22 15.69 22 17.53 21.19 18.84C20.89 19.32 20.51 19.75 20.08 20.08C18.92 21 17.28 21 14 21H10C6.72 21 5.08 21 3.92 20.08C3.49 19.75 3.11 19.32 2.81 18.84C2 17.53 2 15.69 2 12Z"/><path d="M9.5 3L9.5 21"/><path d="M5 7H6M5 10H6"/>',
    menu:'<path d="M4 5L20 5"/><path d="M4 12L20 12"/><path d="M4 19L20 19"/>',
    plus:'<path d="M12 4V20"/><path d="M20 12L4 12"/>',
    refresh:'<path d="M16.5 8H18C19.41 8 20.12 8 20.56 7.56C21 7.12 21 6.41 21 5V3.5"/><path d="M3 12C3 7.03 7.03 3 12 3C15.57 3 18.09 4.73 20 7.08M21 12C21 16.97 16.97 21 12 21C8.43 21 5.91 19.27 4 16.92"/><path d="M7.5 16H6C4.59 16 3.88 16 3.44 16.44C3 16.88 3 17.59 3 19V20.5"/>',
    // rebuild: the launcher .app as a box being remade; update: a version step up. Neither reuses refresh or download.
    rebuild:'<path d="M11 22C10.18 22 9.4 21.67 7.84 21.01C3.95 19.37 2 18.54 2 17.16C2 16.77 2 10.06 2 7M11 22L11 11.35M11 22C11.34 22 11.65 21.94 12 21.83M20 7V11.5"/><path d="M18 18L18.91 17.09M22 18C22 15.79 20.21 14 18 14C15.79 14 14 15.79 14 18C14 20.21 15.79 22 18 22C20.21 22 22 20.21 22 18Z"/><path d="M7.33 9.69L4.4 8.28C2.8 7.5 2 7.11 2 6.5C2 5.89 2.8 5.5 4.4 4.72L7.33 3.31C9.13 2.44 10.03 2 11 2C11.97 2 12.87 2.44 14.67 3.31L17.6 4.72C19.2 5.5 20 5.89 20 6.5C20 7.11 19.2 7.5 17.6 8.28L14.67 9.69C12.87 10.56 11.97 11 11 11C10.03 11 9.13 10.56 7.33 9.69Z"/><path d="M5 12L7 13"/><path d="M16 4L6 9"/>',
    update:'<path d="M22 12C22 17.52 17.52 22 12 22C6.48 22 2 17.52 2 12C2 6.48 6.48 2 12 2C17.52 2 22 6.48 22 12Z"/><path d="M12 9V16M15.5 11.5C15.5 11.5 12.92 8 12 8C11.08 8 8.5 11.5 8.5 11.5"/>',
    search:'<path d="M17 17L21 21"/><path d="M19 11C19 6.58 15.42 3 11 3C6.58 3 3 6.58 3 11C3 15.42 6.58 19 11 19C15.42 19 19 15.42 19 11Z"/>',
    x:'<path d="M19 19L5 5"/><path d="M19 5L5 19"/>',
    play:'<path d="M18.89 12.85C18.54 14.19 16.87 15.14 13.53 17.04C10.3 18.87 8.68 19.79 7.38 19.42C6.84 19.27 6.35 18.98 5.96 18.58C5 17.61 5 15.74 5 12C5 8.26 5 6.39 5.96 5.42C6.35 5.02 6.84 4.73 7.38 4.58C8.68 4.21 10.3 5.13 13.53 6.96C16.87 8.86 18.54 9.81 18.89 11.15C19.04 11.71 19.04 12.29 18.89 12.85Z"/>',
    stop:'<path d="M4 12C4 8.72 4 7.08 4.81 5.92C5.11 5.49 5.49 5.11 5.92 4.81C7.08 4 8.72 4 12 4C15.28 4 16.92 4 18.08 4.81C18.51 5.11 18.89 5.49 19.19 5.92C20 7.08 20 8.72 20 12C20 15.28 20 16.92 19.19 18.08C18.89 18.51 18.51 18.89 18.08 19.19C16.92 20 15.28 20 12 20C8.72 20 7.08 20 5.92 19.19C5.49 18.89 5.11 18.51 4.81 18.08C4 16.92 4 15.28 4 12Z"/>',
    more:'<path d="M6 12.5V12M18 12.5V12M12 12.5V12M7 12.5C7 11.95 6.56 11.5 6 11.5C5.45 11.5 5 11.95 5 12.5C5 13.05 5.45 13.5 6 13.5C6.56 13.5 7 13.05 7 12.5ZM19 12.5C19 11.95 18.56 11.5 18 11.5C17.45 11.5 17 11.95 17 12.5C17 13.05 17.45 13.5 18 13.5C18.56 13.5 19 13.05 19 12.5ZM13 12.5C13 11.95 12.56 11.5 12 11.5C11.45 11.5 11 11.95 11 12.5C11 13.05 11.45 13.5 12 13.5C12.56 13.5 13 13.05 13 12.5Z"/>',
    trash:'<path d="M18.85 16.37L19.5 6H4.5L5.15 16.37C5.32 19.04 5.4 20.37 6.26 21.19C7.13 22 8.47 22 11.14 22H12.86C15.53 22 16.87 22 17.74 21.19C18.6 20.37 18.68 19.04 18.85 16.37Z"/><path d="M16 6H21M16 6L15.38 4.34C15 3.34 14.81 2.83 14.44 2.5C14.32 2.4 14.19 2.31 14.05 2.23C13.61 2 13.07 2 12 2C10.93 2 10.39 2 9.95 2.23C9.81 2.31 9.68 2.4 9.56 2.5C9.19 2.83 9 3.34 8.62 4.34L8 6M16 6H8M3 6H8"/><path d="M9.5 11V17M14.5 11V17"/>',
    shield:'<path d="M18.71 3.5C16.82 2.55 14.5 2 12 2C9.5 2 7.18 2.55 5.29 3.5C4.36 3.96 3.9 4.19 3.45 4.91C3 5.64 3 6.34 3 7.75V11.24C3 16.92 7.54 20.08 10.17 21.43C10.91 21.81 11.27 22 12 22C12.73 22 13.09 21.81 13.83 21.43C16.46 20.08 21 16.92 21 11.24L21 7.75C21 6.34 21 5.64 20.55 4.91C20.1 4.19 19.64 3.96 18.71 3.5Z"/><path d="M9 11.5C9 11.5 10.41 11.75 11 13.5C11 13.5 12.5 10.5 15 9.5"/>',
    download:'<path d="M3 17C3 17.93 3 18.4 3.1 18.78C3.38 19.81 4.19 20.62 5.22 20.9C5.6 21 6.07 21 7 21L17 21C17.93 21 18.39 21 18.78 20.9C19.81 20.62 20.62 19.81 20.9 18.78C21 18.4 21 17.93 21 17"/><path d="M16.5 11.5C16.5 11.5 13.19 16 12 16C10.81 16 7.5 11.5 7.5 11.5M12 15V3"/>',
    upload:'<path d="M3 17C3 17.93 3 18.39 3.1 18.78C3.38 19.81 4.19 20.62 5.22 20.9C5.6 21 6.07 21 7 21L17 21C17.93 21 18.39 21 18.78 20.9C19.81 20.62 20.62 19.81 20.9 18.78C21 18.39 21 17.93 21 17"/><path d="M16.5 7.5C16.5 7.5 13.19 3 12 3C10.81 3 7.5 7.5 7.5 7.5M12 4V16"/>',
    arrow:'<path d="M18.5 12L5 12"/><path d="M13 18C13 18 19 13.58 19 12C19 10.42 13 6 13 6"/>',
    back:'<path d="M5.5 12H19"/><path d="M11 18C11 18 5 13.58 5 12C5 10.42 11 6 11 6"/>',
    terminal:'<path d="M14 4H10C6.23 4 4.34 4 3.17 5.17C2 6.34 2 8.23 2 12C2 15.77 2 17.66 3.17 18.83C4.34 20 6.23 20 10 20H14C17.77 20 19.66 20 20.83 18.83C22 17.66 22 15.77 22 12C22 8.23 22 6.34 20.83 5.17C19.66 4 17.77 4 14 4Z"/><path d="M7 9L8.84 10.59C9.61 11.25 10 11.59 10 12C10 12.41 9.61 12.75 8.84 13.41L7 15"/><path d="M13 16H17"/>',
    chevron:'<path d="M18 15C18 15 13.58 9 12 9C10.42 9 6 15 6 15"/>',
    check:'<path d="M22 12C22 6.48 17.52 2 12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12Z"/><path d="M8 12.5L10.5 15L16 9"/>',
    alert:'<circle cx="12" cy="12" r="10"/><path d="M12 8V12"/><path d="M12.12 15.75H12M12.25 15.75C12.25 15.89 12.14 16 12 16C11.86 16 11.75 15.89 11.75 15.75C11.75 15.61 11.86 15.5 12 15.5C12.14 15.5 12.25 15.61 12.25 15.75Z"/>',
    copy:'<path d="M7.5 14.5C7.5 11.2 7.5 9.55 8.53 8.53C9.55 7.5 11.2 7.5 14.5 7.5C17.8 7.5 19.45 7.5 20.47 8.53C21.5 9.55 21.5 11.2 21.5 14.5C21.5 17.8 21.5 19.45 20.47 20.47C19.45 21.5 17.8 21.5 14.5 21.5C11.2 21.5 9.55 21.5 8.53 20.47C7.5 19.45 7.5 17.8 7.5 14.5Z"/><path d="M7.5 16.5C6.1 16.5 5.41 16.5 4.84 16.3C3.84 15.95 3.05 15.16 2.7 14.16C2.5 13.59 2.5 12.9 2.5 11.5V9.5C2.5 6.2 2.5 4.55 3.53 3.53C4.55 2.5 6.2 2.5 9.5 2.5H11.5C12.9 2.5 13.59 2.5 14.16 2.7C15.16 3.05 15.95 3.84 16.3 4.84C16.5 5.41 16.5 6.1 16.5 7.5"/>',
  };
  const icon = name => `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${iconPaths[name] || iconPaths.grid}</svg>`;
  const tile = (section, glyph) => `<span class="tile section-${section}" aria-hidden="true">${icon(glyph)}</span>`;
  const button = (label, action, opts = {}) => `<button class="button ${opts.primary ? "button-primary" : ""} ${opts.danger ? "button-danger" : ""} ${opts.small ? "button-small" : ""}" data-action="${escape(action)}"${opts.name ? ` data-name="${escape(opts.name)}"` : ""}${opts.app ? ` data-app="${escape(opts.app)}"` : ""}${opts.disabled ? " disabled" : ""}${opts.label ? ` aria-label="${escape(opts.label)}"` : ""}>${opts.icon ? icon(opts.icon) : ""}<span>${escape(label)}</span></button>`;
  // The CLI's color words; the hex field still takes them, unadvertised.
  const cliColors = {blue:"2E7DF6",green:"2FB344",red:"E5484D",orange:"F76B15",purple:"8E4EC6",pink:"D6409F",teal:"12A594",yellow:"F5B400",gray:"6B7280",grey:"6B7280",graphite:"1F2430",black:"1F2430"};
  const defaultBadgeColor="5FE08A";
  const wordHex=raw=>Object.hasOwn(cliColors,raw.toLowerCase())?cliColors[raw.toLowerCase()]:raw;
  const luminance=hex=>[0,2,4].map(i=>parseInt(String(hex).replace("#","").slice(i,i+2),16)/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4).reduce((sum,c,i)=>sum+c*[.2126,.7152,.0722][i],0);
  // Badge letter ink: Lampblack or white, whichever contrasts more with the badge (WCAG 1.4.3).
  const inkFor=hex=>(luminance(hex)+.05)/(luminance("060606")+.05)>=(luminance("ffffff")+.05)/(luminance(hex)+.05)?"#060606":"#ffffff";
  // The seven app hues live in styles.css (--hue-*). Mint is status and the default accent, never an app hue.
  // Frozen copy of those tokens, used only when one is missing or not #rrggbb.
  const hueNames=["periwinkle","teal","orange","pink","gold","sky","violet"],hueDefaults=["#7c8cff","#2fd4c0","#ff8a3d","#ff6fb5","#ffd166","#4cc3ff","#b26bff"];
  const hueToken=(hue,fallback)=>{const hex=getComputedStyle(document.documentElement).getPropertyValue(`--hue-${hue}`).trim().toLowerCase();return /^#[0-9a-f]{6}$/.test(hex)?hex:(console.warn(`--hue-${hue} is missing or not #rrggbb; using ${fallback}`),fallback);};
  const appPalette=hueNames.map((hue,i)=>hueToken(hue,hueDefaults[i]));
  // Badge colors are the user's own choice: mint and the seven app hues, then two neutrals.
  const colors=[["Mint",hueToken("mint","#5fe08a")],...hueNames.map((hue,i)=>[hue[0].toUpperCase()+hue.slice(1),appPalette[i]])].map(([name,hex])=>[name,hex.slice(1).toUpperCase()]).concat([["Gray","8D8B84"],["Graphite","262624"]]);
  const appAccentAssignments=new Map();
  let huedApps=new Set();
  // Apps the server can show their own installed icon for (state: apps[].icon, profiles[].app_icon).
  let iconApps=new Set();
  // An installed icon's own color as a hue angle (null for a neutral icon), learned once per page by learnIconAngles.
  const iconAngles=new Map();
  const hueAngle=(r,g,b)=>{const max=Math.max(r,g,b),c=max-Math.min(r,g,b);return c?((max===r?(g-b)/c+6:max===g?(b-r)/c+2:(r-g)/c+4)*60)%360:0;};
  const paletteAngles=appPalette.map(hex=>hueAngle(...[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16))));
  const arc=(a,b)=>{const d=Math.abs(a-b)%360;return Math.min(d,360-d);};
  const appKey=name=>String(name||"App").trim().toLowerCase();
  // One app order everywhere: by name, numbers compared as numbers ("ChatGPT 2" after "ChatGPT").
  const byName=(a,b)=>String(a).localeCompare(String(b),undefined,{numeric:true,sensitivity:"base"});
  function appHash(name){
    let hash=2166136261;
    for(const character of appKey(name))hash=Math.imul(hash^character.codePointAt(0),16777619)>>>0;
    return hash;
  }
  // Only apps with at least one profile get a hue. An app keeps the hue it got first, and no two share one while hues are left.
  function registerAppAccents(data){
    const names=[...new Set((data.profiles||[]).map(item=>item.app||"Unknown app"))].sort(byName);
    huedApps=new Set(names.map(appKey));
    const used=new Set(),fresh=[];
    for(const name of names){const index=appAccentAssignments.get(appKey(name));if(index!==undefined&&!used.has(index))used.add(index);else fresh.push(name);}
    for(const name of fresh){
      // An app with a colored installed icon takes the palette hue nearest the icon's own color, so icon and hue read as one;
      // any other app takes its name's hash. Either way, the next free hue on a collision.
      const preferred=appHash(name)%appPalette.length,angle=iconAngles.get(appKey(name));
      const order=appPalette.map((_,offset)=>(preferred+offset)%appPalette.length);
      if(angle!=null)order.sort((a,b)=>arc(angle,paletteAngles[a])-arc(angle,paletteAngles[b]));
      const index=order.find(candidate=>!used.has(candidate))??order[0];
      appAccentAssignments.set(appKey(name),index);used.add(index);
    }
  }
  // Reads each new app icon's chroma-weighted mean hue over its pixels before that app gets its hue. The PNG is same-origin
  // (server.py /api/app-icon), so the canvas stays readable, and the <img> tiles reuse the cached response.
  function learnIconAngles(profiles){
    const names=[...new Set(profiles.map(appName))].filter(name=>iconApps.has(name)&&!iconAngles.has(appKey(name)));
    return Promise.all(names.map(name=>new Promise(resolve=>{
      const image=new Image();
      // shortcut: an icon slower than 2s leaves this page on the name's hash hue; a reload reads it again.
      setTimeout(resolve,2000);
      image.onerror=()=>{iconAngles.set(appKey(name),null);resolve();};
      image.onload=()=>{
        const canvas=document.createElement("canvas");canvas.width=canvas.height=32;
        const context=canvas.getContext("2d",{willReadFrequently:true});context.drawImage(image,0,0,32,32);
        const pixels=context.getImageData(0,0,32,32).data;let x=0,y=0,weight=0;
        for(let i=0;i<pixels.length;i+=4){
          const r=pixels[i],g=pixels[i+1],b=pixels[i+2],alpha=pixels[i+3]/255,chroma=(Math.max(r,g,b)-Math.min(r,g,b))*alpha,h=hueAngle(r,g,b)*Math.PI/180;
          x+=chroma*Math.cos(h);y+=chroma*Math.sin(h);weight+=alpha;
        }
        // A mean chroma under 24 of 255 is a neutral icon (ChatGPT's black and white): no hue of its own, so the hash picks.
        iconAngles.set(appKey(name),weight&&Math.hypot(x,y)/weight>=24?(Math.atan2(y,x)*180/Math.PI+360)%360:null);
        resolve();
      };
      image.src=`/api/app-icon?app=${encodeURIComponent(name)}`;
    })));
  }
  // {color}: the app's hue, or null for an app with no profiles, which renders neutral (Explore reads this too).
  const appAccent=name=>({color:huedApps.has(appKey(name))?appPalette[appAccentAssignments.get(appKey(name))]:null});
  const tone=name=>{const color=appAccent(name).color;return color?{cls:" app-tone",style:` style="--app-color:${color}"`}:{cls:"",style:""};};
  // A new profile's badge: the first preset that is neither the app's hue nor worn by another profile of that app.
  const badgeDefault=app=>{const taken=new Set([(appAccent(app).color||"").slice(1).toUpperCase(),...(state?.profiles||[]).filter(item=>appName(item)===app).map(item=>String(item.color||"").toUpperCase())]);return (colors.find(([,hex])=>!taken.has(hex))||colors[0])[1];};
  const navigation = [
    ["explore","Explore","explore"],["profiles","Profiles","grid"],["apps","Applications","apps"],
    ["recovery","Recovery","recovery"],["maintenance","Maintenance","tool"],["transfer","Import & export","transfer"]
  ];
  const main = $("#main");
  const dialog = $("#dialog");
  // Toasts live in the top layer (a manual popover), so an open modal dialog never covers them.
  const toastViewport = $("#toast-viewport");toastViewport.popover="manual";toastViewport.showPopover?.();
  // The page's foot reserves the strip of screen the toasts cover (none while no toast shows), so whatever a toast covers can scroll
  // clear of it, and focus does (styles.css --toast-inset). Over a dialog it keeps the last inset, so the page behind never jumps.
  const toastInset=()=>{if(toastViewport.parentElement===document.body)document.documentElement.style.setProperty("--toast-inset",`${toastViewport.offsetHeight?Math.ceil(innerHeight-toastViewport.getBoundingClientRect().top+8):0}px`);};
  new ResizeObserver(toastInset).observe(toastViewport);
  const reducedMotion=matchMedia("(prefers-reduced-motion: reduce)");
  const motionAnimations=new WeakMap();
  const motionCurve=kind=>getComputedStyle(document.documentElement).getPropertyValue(kind==="control"?"--spring-control":"--spring-surface").trim()||"cubic-bezier(.16,1,.3,1)";
  function animateMotion(element,frames,kind="surface",options={}){
    if(!element||reducedMotion.matches||!element.animate)return null;
    motionAnimations.get(element)?.cancel();
    const animation=element.animate(frames,{duration:kind==="control"?340:480,easing:motionCurve(kind),fill:"backwards",...options});// --motion-control / --motion-surface
    motionAnimations.set(element,animation);
    animation.finished.catch(()=>{}).finally(()=>{if(motionAnimations.get(element)===animation)motionAnimations.delete(element);});
    return animation;
  }
  // A shown/hidden layer that enters and leaves on the same path. One animation plays forward to show and in reverse to hide,
  // so a toggle mid-flight turns around from where the layer is on screen, on the mirrored curve. hidden is set when it ends.
  const presences=new WeakMap();
  function present(element,show,frames){
    let animation=presences.get(element);
    if(reducedMotion.matches||!element.animate){animation?.cancel();element.hidden=!show;return;}
    if(animation){if((animation.playbackRate>0)!==show)animation.reverse();return;}
    if(element.hidden===!show)return;
    element.hidden=false;
    animation=element.animate(frames,{duration:340,easing:motionCurve("control"),fill:"both"});
    if(!show)animation.reverse();
    presences.set(element,animation);
    animation.oncancel=()=>presences.delete(element);
    animation.onfinish=()=>{presences.delete(element);const hide=animation.playbackRate<0;animation.cancel();if(hide)element.hidden=true;};
  }
  function animateWorkspaceChange(){
    if(view==="explore"||reducedMotion.matches)return;
    const blocks=$$(".title-row,.terms,.tabs,.toolbar,.profile-card,.folder,.operation-card,.panel,.guide-output,.guide-empty",main);
    blocks.forEach((element,index)=>animateMotion(element,[{opacity:0,translate:"0 9px"},{opacity:1,translate:"0 0"}],"surface",{delay:Math.min(index,7)*14}));
  }
  function animateToastLayout(update){
    const existing=$$(".toast");
    const positions=existing.map(element=>[element,element.getBoundingClientRect().top]);
    update();
    positions.forEach(([element,top])=>{
      if(!element.isConnected)return;
      const delta=top-element.getBoundingClientRect().top;
      if(Math.abs(delta)>.5)animateMotion(element,[{translate:`0 ${delta}px`},{translate:"0 0"}]);
    });
  }
  // The ambient ground (experience.js) answers a profile that starts running, joins or comes back, and a reconnect: one ring of denser glyphs from where it shows.
  const ripple=(from,reach="near")=>{if(from)document.dispatchEvent(new CustomEvent("aidentity:ripple",{detail:{from,reach}}));};
  // Where a profile shows now: its visible Open or Bring to front, on a card, the detail panel or an Explore key.
  // It runs after a successful action, so a browser without checkVisibility() must not turn that success into an error.
  const profileSpot=name=>$$(".open-profile,[data-xp-key]",main).find(el=>(el.dataset.name??el.dataset.xpKey)===name&&(el.checkVisibility?.()??el.getClientRects().length>0));
  // Profiles that started running since the last read: their card draws its hue edge once and its running dot arrives (Explore keeps its own).
  const litCards=new Set();
  const initialRoute=location.hash.slice(1);
  let state = null, inventory = null, view = [...navigation.map(item=>item[0]),"guide"].includes(initialRoute)?initialRoute:"explore", query = "", appFilter = "", statusFilter = "all", selected = "", mobileDetail = false;
  let cleanupExperience = null, lastData = "", loadedAt = null, loading = false, busy = false, dialogSubmit = null, lastFocus = null;
  // guideCommand and guideShell keep the Help selects across the re-render that shows the output.
  let history = [], guideText = "", guideCommand = "", guideShell = "zsh", importDocument = null, tabPosition=null, tabScroll=0;
  // Activity survives a reload in this tab (sessionStorage); outputs and commands are already redacted by the server.
  const ACTIVITY="aidentity.activity";
  try{const saved=JSON.parse(sessionStorage.getItem(ACTIVITY)||"[]");if(Array.isArray(saved))history=saved.filter(item=>item&&typeof item==="object"&&!Number.isNaN(new Date(item.time).getTime())).map(item=>({...item,time:new Date(item.time)})).slice(0,12);}catch{history=[];}
  let dialogRevision=0,dialogCloseTimer=null,navCloseTimer=null;
  let offline=false,lastDoctor=null,lastUpdate=null,doctorFlags=new Set(),dialogBuild=null,previewTimer=null,previewSeq=0,exploreApp="";
  const time = date => new Intl.DateTimeFormat(undefined,{hour:"2-digit",minute:"2-digit"}).format(date);
  const profile = name => state?.profiles.find(item => item.name === name);
  const appName = item => item.app || "Unknown app";
  // The dashboard shows only these apps (exact names) and their profiles.
  const AI_APPS = ["Claude","ChatGPT"];
  // Display words for CLI statuses, shared with Explore; the CLI values themselves stay as they are.
  const statusLabels={"running":"Running","in use":"Not running","not running":"Not running","signed out / new":"Not opened yet","app missing":"App missing"};
  const statusLabel=status=>statusLabels[status]||status;
  const plural=(count,one,many=`${one}s`)=>`${count} ${count===1?one:many}`;
  const lastLine=text=>String(text||"").trim().split("\n").pop().trim();
  // The one CSRF-protected POST to the local server; body is an object, or a string already serialized.
  const post=(path,body)=>fetch(path,{method:"POST",headers:{"Content-Type":"application/json","X-AIdentity-CSRF":state.csrf_token},body:typeof body==="string"?body:JSON.stringify(body)});
  // Escaped path that wraps after a slash instead of mid-word.
  const breakPath=value=>escape(value).replace(/\//g,"/<wbr>");
  const contextApp=()=>(view==="explore"&&exploreApp)||profile(selected)?.app||appFilter;
  const needsRepair=item=>item.status==="app missing"||doctorFlags.has(item.name);
  // The server picks a free port each time it starts; started on this page's port again, it is the same origin and this tab reconnects,
  // so --no-open: the restart opens no second tab.
  const RECONNECT=location.port?`aidentity dashboard --port ${location.port} --no-open`:"aidentity dashboard";
  const OFFLINE=`The dashboard stopped. Run “${RECONNECT}” in Terminal to reconnect.`;
  const SIGN_IN_HINT="Sign in once in the window that opens. aidentity remembers it.";
  // localStorage can throw (disabled or private storage); the in-memory copy keeps this session consistent.
  const memory=new Map();
  const stored={get:key=>{try{return localStorage.getItem(key)??memory.get(key)??null;}catch{return memory.get(key)??null;}},set:(key,value)=>{memory.set(key,value);try{localStorage.setItem(key,value);}catch{}}};
  // The last doctor run outlives a reload: its summary, findings, time and the profiles it flagged.
  const DOCTOR="aidentity.last-doctor";
  try{const saved=JSON.parse(stored.get(DOCTOR)||"null"),at=new Date(saved?.at);if(saved?.result&&typeof saved.result==="object"&&!Number.isNaN(at.getTime())){lastDoctor={result:saved.result,at};doctorFlags=new Set(Array.isArray(saved.flags)?saved.flags.map(String):[]);}}catch{}
  function saveDoctor(){
    if(!lastDoctor)return;
    const {summary,findings,stdout,stderr}=lastDoctor.result;
    stored.set(DOCTOR,JSON.stringify({result:Array.isArray(findings)?{summary,findings}:{summary,stdout,stderr},at:lastDoctor.at,flags:[...doctorFlags]}));
  }
  // An app is drawn with its own installed icon (server.py /api/app-icon), never with artwork shipped here. alt is empty: its name is always beside it.
  const appIcon=name=>iconApps.has(name)?`<img class="app-icon" src="/api/app-icon?app=${encodeURIComponent(name)}" width="128" height="128" alt="" decoding="async" draggable="false">`:"";
  const appGlyph = name => {
    if(iconApps.has(name)) return appIcon(name);
    const n = String(name).toLowerCase();
    // Hugeicons brand marks (24px grid) where the free set has one; Cursor, Edge and Brave keep their own drawn marks (32px grid).
    let huge = "", paths = "";
    if(n.includes("claude")) huge='<path d="M13 12L18.5 5M7.64 3L12.5 12L13.69 3M4.48 6.72L11.99 12M3 12L11.99 12.47M12.22 13.18L7 20M4.84 16.87L11.28 12.98M11.5 21L12.66 13.18M21 14L13.18 12.67M21 10.58L13 12.32M16.78 19.65L12.89 13.38M19.36 18.21L13.31 12.99"/>';
    else if(n.includes("chatgpt")) huge='<path d="M11.75 14.85L6.9 12V7C6.9 4.79 8.73 3 10.98 3C12.38 3 13.61 3.69 14.35 4.74"/><path d="M9.6 19.18C10.33 20.28 11.59 21 13.02 21C15.27 21 17.1 19.21 17.1 17V12L12.16 9.1"/><path d="M9.45 13.5L9.45 7.67L13.86 5.17C15.81 4.06 18.31 4.72 19.43 6.63C20.16 7.87 20.14 9.32 19.51 10.5"/><path d="M4.49 13.5C3.86 14.67 3.84 16.13 4.57 17.37C5.69 19.28 8.18 19.93 10.13 18.83L14.55 16.33L14.64 10.73"/><path d="M17.1 17.63C18.44 17.57 19.73 16.86 20.45 15.63C21.58 13.72 20.91 11.27 18.96 10.17L14.55 7.67L9.49 10.43"/><path d="M6.9 6.37C5.56 6.43 4.27 7.14 3.55 8.37C2.42 10.28 3.09 12.73 5.04 13.83L9.45 16.33L14.5 13.58"/>';
    else if(n.includes("chrome") || n.includes("chromium")) huge='<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><path d="M8.53 14L4.03 6"/><path d="M11.5 21.5L15.5 14"/><path d="M12 8H21"/>';
    else if(n.includes("cursor")) paths='<path d="m23 3 6 3v20l-6 3-15-12-5 4v-9l5 4L23 3Zm0 6-10 7 10 7V9Z" fill="currentColor"/>';
    else if(n.includes("code")) huge='<path d="M17.02 16.5V21.28C17.02 21.6 16.81 21.87 16.52 21.97M17.02 16.5L10.88 12M17.02 16.5V7.5M7.75 9.71L4.25 7.03C3.85 6.73 3.29 6.76 2.94 7.12L2.29 7.77C1.89 8.17 1.9 8.82 2.31 9.21L5.28 12M7.75 9.71L10.88 12M7.75 9.71L15.81 2.19C15.95 2.07 16.12 2 16.3 2C16.38 2 16.45 2.01 16.52 2.03M10.88 12L17.02 7.5M17.02 7.5V2.72C17.02 2.4 16.81 2.13 16.52 2.03M7.75 14.29L4.25 16.97C3.85 17.27 3.29 17.24 2.94 16.88L2.29 16.23C1.89 15.83 1.9 15.18 2.31 14.79L5.28 12M7.75 14.29L15.81 21.81C15.95 21.93 16.12 22 16.3 22C16.38 22 16.45 21.99 16.52 21.97M7.75 14.29L5.28 12M16.52 2.03L21.41 4.24C21.77 4.4 22 4.75 22 5.15V18.85C22 19.25 21.77 19.6 21.41 19.76L16.52 21.97"/>';
    else if(n.includes("slack")) huge='<path d="M13 9.25V3.75C13 2.78 13.78 2 14.75 2C15.72 2 16.5 2.78 16.5 3.75V9.25C16.5 10.22 15.72 11 14.75 11C13.78 11 13 10.22 13 9.25Z"/><path d="M7.5 20.25V14.75C7.5 13.78 8.28 13 9.25 13C10.22 13 11 13.78 11 14.75V20.25C11 21.22 10.22 22 9.25 22C8.28 22 7.5 21.22 7.5 20.25Z"/><path d="M14.75 13L20.25 13C21.22 13 22 13.78 22 14.75C22 15.72 21.22 16.5 20.25 16.5L14.75 16.5C13.78 16.5 13 15.72 13 14.75C13 13.78 13.78 13 14.75 13Z"/><path d="M3.75 7.5L9.25 7.5C10.22 7.5 11 8.28 11 9.25C11 10.22 10.22 11 9.25 11L3.75 11C2.78 11 2 10.22 2 9.25C2 8.28 2.78 7.5 3.75 7.5Z"/><path d="M7 3.75C7 4.72 7.78 5.5 8.75 5.5H10.5V3.75C10.5 2.78 9.72 2 8.75 2C7.78 2 7 2.78 7 3.75Z"/><path d="M17 20.25C17 19.28 16.22 18.5 15.25 18.5H13.5V20.25C13.5 21.22 14.28 22 15.25 22C16.22 22 17 21.22 17 20.25Z"/><path d="M20.25 7C19.28 7 18.5 7.78 18.5 8.75L18.5 10.5H20.25C21.22 10.5 22 9.72 22 8.75C22 7.78 21.22 7 20.25 7Z"/><path d="M3.75 17C4.72 17 5.5 16.22 5.5 15.25V13.5L3.75 13.5C2.78 13.5 2 14.28 2 15.25C2 16.22 2.78 17 3.75 17Z"/>';
    else if(n.includes("notion")) huge='<path d="M2.5 12C2.5 7.52 2.5 5.28 3.89 3.89C5.28 2.5 7.52 2.5 12 2.5C16.48 2.5 18.72 2.5 20.11 3.89C21.5 5.28 21.5 7.52 21.5 12C21.5 16.48 21.5 18.72 20.11 20.11C18.72 21.5 16.48 21.5 12 21.5C7.52 21.5 5.28 21.5 3.89 20.11C2.5 18.72 2.5 16.48 2.5 12Z"/><path d="M8.43 10L13.52 16.4C13.72 16.64 13.9 16.88 14.22 16.96C14.35 17 14.49 17 14.77 17C15.05 17 15.19 17 15.3 16.95C15.59 16.8 15.57 16.48 15.57 16.2V13.43M8.43 10V7M8.43 10V17M8.43 7H9.53C10.01 7 10.24 7 10.45 7.1C10.66 7.2 10.81 7.39 11.1 7.76L15.57 13.43M8.43 7H7M8.43 17H7M8.43 17H10M15.57 7V13.43M15.57 7H14M15.57 7H17"/>';
    else if(n.includes("edge") || n.includes("brave")) paths='<path d="M6 23 16 5l10 18M10 17h12M8 26h16" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>';
    else if(n.includes("arc")) huge='<path d="M13.51 13.6C12.9 13.79 12.27 13.89 11.6 13.89C9.12 13.89 6.97 12.48 5.93 10.43C5.49 9.55 4.4 9.19 3.5 9.63C2.61 10.07 2.24 11.13 2.69 12.01C4.31 15.23 7.69 17.44 11.6 17.44C12.85 17.44 14.04 17.22 15.14 16.81"/><path d="M18.24 14.95C20.01 13.39 21.21 11.21 21.49 8.75C21.6 7.77 20.88 6.9 19.89 6.79C18.9 6.68 18 7.38 17.89 8.36C17.76 9.57 17.26 10.68 16.52 11.58"/><path d="M11.55 4C12.23 4 12.86 4.38 13.17 4.98L19.5 17.43C19.95 18.31 19.58 19.37 18.69 19.81C17.8 20.25 16.71 19.9 16.26 19.02L11.55 9.75L9.6 13.57C8.41 13.18 7.37 12.45 6.61 11.5L9.93 4.98C10.24 4.38 10.86 4 11.55 4Z"/><path d="M6.83 19.02C6.39 19.9 5.3 20.25 4.4 19.81C3.51 19.37 3.15 18.31 3.6 17.43L4.89 14.88C5.78 15.69 6.83 16.33 7.97 16.77L6.83 19.02Z"/>';
    if(huge) return `<svg class="app-vector" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${huge}</svg>`;
    if(paths) return `<svg class="app-vector" viewBox="0 0 32 32" fill="none" aria-hidden="true">${paths}</svg>`;
    return `<span aria-hidden="true">${escape([...String(name || "A")][0].toUpperCase())}</span>`;
  };
  const art = (name, badge = null, color = "") => {
    const hex = /^[0-9a-f]{6}$/i.test(color) ? color : defaultBadgeColor;
    return `<span class="app-art">${appGlyph(name)}${badge ? `<span class="identity-badge" style="--identity-color:#${hex};--identity-ink:${inkFor(hex)}">${escape(badge)}</span>` : ""}</span>`;
  };
  // Stable per-profile id so a card can be labelled by its name button.
  const profileId = name => `profile-${appHash(name).toString(36)}`;
  const statusMark = item => `<span class="profile-state ${item.status === "running" ? "status-running" : item.status === "app missing" ? "status-missing" : ""}">${item.status === "running" ? '<span class="running-dot"></span>' : ""}${escape(statusLabel(item.status))}</span>`;
  // A running profile's primary verb is Bring to front everywhere (the hue fill); Open is the secondary everywhere. Quit is a small secondary beside its state.
  const primaryVerb=item=>item.status==="running"?"Bring to front":"Open";
  const who=item=>`${item.profile||item.name}, ${appName(item)}`;
  const primaryButton=(item,shortcut)=>{const verb=primaryVerb(item);return `<button class="button ${item.status==="running"?"button-primary":"button-secondary"} open-profile" data-action="open" data-name="${escape(item.name)}" aria-label="${escape(`${verb}, ${who(item)}`)}"${shortcut?` aria-keyshortcuts="O" title="${verb} (O)"`:""}>${icon(item.status==="running"?"arrow":"play")}<span>${verb}</span></button>`;};
  // A command wraps only between shell words. Each word is an inline-block, so a quoted name moves to the next line whole; one wider than
  // the line breaks as a name does, at its spaces and after an underscore or a slash, never mid-word. As breakable(), AT reads a plain copy.
  const commandHtml=command=>{const text=String(command||""),words=(text.match(/(?:[^\s'"\\]+|'[^']*'|"(?:[^"\\]|\\.)*"|\\.|['"\\])+/g)||[]).map(word=>`<span class="command-word">${escape(word).replace(/[_/]/g,"$&<wbr>")}</span>`).join(" ");return /[_/]/.test(text)?`<span aria-hidden="true">${words}</span><span class="sr-only">${escape(text)}</span>`:words;};
  const quitButton=item=>item.status==="running"?button("Quit","quit",{small:true,icon:"stop",name:item.name,label:`Quit, ${who(item)}`}):"";
  function hydrateIcons(root=document) { $$("[data-icon]",root).forEach(el => {el.innerHTML=icon(el.dataset.icon);el.removeAttribute("data-icon");}); }
  // Re-renders replace nodes; put focus back on the matching control so it never falls to <body>.
  // The place keeps a card's control apart from the detail panel's copy of it.
  const focusPlace=el=>el.closest(".detail-panel")?"detail":el.closest(".profile-card")?"card":"";
  const controlKey=el=>{const d=el?.dataset;if(!d||!el.matches("button,select,input,textarea,a[href]"))return null;const key=[el.id,d.view,d.appFilter,d.filter,d.action,d.name,d.app].join("|");return /[^|]/.test(key)?`${key}|${focusPlace(el)}`:null;};
  function keepFocus(render){
    const key=controlKey(document.activeElement),from=focusOrigin(document.activeElement);render();
    if(key===null||(document.activeElement&&document.activeElement!==document.body))return;
    const same=$$("button,select,input,textarea,a[href]").find(el=>controlKey(el)===key);
    same?.focus({preventScroll:true});if(document.activeElement!==same)returnFocus(from);
  }
  // setBusy disables the control that ran an action, so focus falls to <body>. When it ends, unless the user moved on, focus that
  // control again (same id, or same action and profile in the same card or detail panel), else that profile's name or heading, else the h1.
  const focusOrigin=el=>el&&el===document.activeElement?{id:el.id,action:el.dataset.action,name:el.dataset.name||"",place:focusPlace(el)}:null;
  function returnFocus(from){
    if(!from||document.activeElement&&document.activeElement!==document.body)return;
    const area=from.place==="detail"?$(".detail-panel",main):from.place==="card"?$$(".profile-card",main).find(node=>$(".profile-name",node)?.dataset.name===from.name):main;
    const same=from.id?document.getElementById(from.id):area&&$$("[data-action]",area).find(el=>el.dataset.action===from.action&&(el.dataset.name||"")===from.name);
    // A candidate can be hidden (a closed disclosure, the panel's own copy beside a shown card from 768px): try the next until one takes focus.
    for(const el of [same,from.place&&area&&$(from.place==="detail"?"#detail-title":".profile-name",area),$("h1",main)]){if(!el||el.disabled)continue;el.focus({preventScroll:true});if(document.activeElement===el)return;}
  }
  let navApps=null;
  function renderNav() {
    if(!$("#primary-nav").children.length)$("#primary-nav").innerHTML=navigation.map(([id,label,glyph])=>`<button class="nav-item section-${id}" data-view="${id}" title="${label}">${tile(id,glyph)}<span class="nav-label">${label}</span></button>`).join("");
    const apps = [...new Set((state?.profiles || []).map(appName))].sort(byName);
    const appsKey=JSON.stringify([apps.map(name=>[name,appAccent(name).color,iconApps.has(name)]),Boolean(state?.errors?.length),Boolean(state)]);
    // The app's own icon, at the label's size (24px on the collapsed rail). Without one: an 8px dot in its hue, and on the rail its initial on its hue. The focus tooltip names it.
    if(appsKey!==navApps){navApps=appsKey;keepFocus(()=>{$("#app-nav").innerHTML=apps.map(name=>{const t=tone(name);return `<button class="nav-item nav-app${t.cls}"${t.style} data-app-filter="${escape(name)}" title="${escape(name)}"><span class="app-mini" aria-hidden="true">${appIcon(name)||`<span class="nav-app-dot"></span><span class="nav-app-initial">${escape([...name][0].toUpperCase())}</span>`}</span><span class="nav-label">${escape(name)}</span></button>`;}).join("") || (state?`<p class="small nav-label" style="padding:0 12px">${state.errors?.length?"Inventory unavailable":"No profiles yet"}</p>`:"");});}
    // The highlight (the current item's ::before) slides in from where the old one is on screen, mid-slide included.
    const was=$("#sidebar [data-view][aria-current]"),now=$(`#sidebar [data-view="${view}"]`),top=el=>el.getBoundingClientRect().top+(parseFloat(getComputedStyle(el,"::before").translate.split(" ")[1])||0);
    const from=was&&now&&was!==now?top(was)-now.getBoundingClientRect().top:0;
    $$("#sidebar [data-view]").forEach(el=>el===now?el.setAttribute("aria-current","page"):el.removeAttribute("aria-current"));
    if(from)animateMotion(now,[{translate:`0 ${from}px`},{translate:"0 0"}],"control",{pseudoElement:"::before"});
    $("#version").textContent=state?.version ? `aidentity ${String(state.version).replace(/^aidentity\s*/,"")}`:"aidentity";
    const viewName=navigation.find(item=>item[0]===view)?.[1] || "Help";
    document.title=`${viewName} · aidentity`;$("#topbar-title").textContent=viewName;
  }
  // Collapsed rail: a keyboard-focused item shows its name beside the rail (a top-layer popover, so the rail's overflow never clips it).
  const railTip=document.createElement("div");railTip.className="rail-tip";railTip.popover="manual";railTip.setAttribute("aria-hidden","true");document.body.append(railTip);
  const hideRailTip=()=>{if(railTip.matches?.(":popover-open"))railTip.hidePopover();};
  $("#sidebar").addEventListener("focusin",event=>{
    const item=event.target.closest(".nav-item,.brand,#collapse-nav");hideRailTip();
    if(!item||!document.body.classList.contains("sidebar-collapsed")||!item.matches(":focus-visible")||mobile.matches)return;
    const box=item.getBoundingClientRect();railTip.textContent=item.title||item.getAttribute("aria-label")||item.textContent.trim();
    railTip.style.left=`${box.right+10}px`;railTip.style.top=`${box.top+box.height/2}px`;railTip.showPopover?.();
  });
  $("#sidebar").addEventListener("focusout",hideRailTip);
  function errorNotice(){return (state.errors||[]).length?`<div class="notice error" tabindex="0">${state.errors.map(escape).join("<br>")}</div>`:"";}
  function setupError(){return `<div class="empty-state"><h2>aidentity could not read your setup</h2>${errorNotice()}<div class="section-gap">${button("Retry","refresh",{primary:true,icon:"refresh"})}</div></div>`;}
  // The section tile and the page title, with no subtitle: the cards say what each part does and Help's Terms define the words.
  // Profiles filtered to one app leads with that app's own icon in place of the section tile.
  function title(name,actions=""){const glyph=view==="guide"?"book":navigation.find(item=>item[0]===view)?.[2],own=view==="profiles"&&appFilter?appIcon(appFilter):"";return `<div class="title-row"><div class="title-main">${own?`<span class="title-app" aria-hidden="true">${own}</span>`:glyph?tile(view,glyph):""}<h1 tabindex="-1">${escape(name)}</h1></div>${actions?`<div class="title-actions">${actions}</div>`:""}</div>`;}
  function searchField(placeholder){return `<div class="search-field">${icon("search")}<input id="workspace-search" class="input" type="search" aria-keyshortcuts="/" aria-label="${escape(placeholder)}" placeholder="${escape(placeholder)}" value="${escape(query)}">${query?`<button class="icon-button" data-action="clear-search" aria-label="Clear search">${icon("x")}</button>`:""}</div>`;}
  // educalvolpz Animated Tabs translated to native tabs with measured sliding indicator.
  // count null: not counted yet, so a muted dash and the tab's title say why.
  function tabs(items,active){return `<div class="tabs" role="tablist" aria-label="Profile status">${items.map(([id,label,count,unknown=""])=>`<button id="status-${id}" role="tab" aria-selected="${active===id}" aria-controls="profile-results" tabindex="${active===id?0:-1}" data-filter="${id}"${count===null&&unknown?` title="${escape(unknown)}"`:""}>${label}${count===null?(unknown?' <span class="tab-count" aria-hidden="true">–</span>':""):` <span class="tab-count${count>0?{running:" positive",attention:" warning"}[id]??"":""}">${count}</span>`}</button>`).join("")}<span class="tab-indicator"></span></div>`;}
  let tabMotion=null;
  function positionTabs(){
    const tab=$('.tabs [aria-selected=true]'),line=$(".tab-indicator");if(!tab||!line)return;
    const scope=`${appFilter}:${query}`,next={left:tab.offsetLeft,width:tab.offsetWidth,scope,id:tab.id},moved=tabPosition?.id!==tab.id;
    const transform=`translateX(${next.left}px) scaleX(${next.width})`;
    line.style.width="1px";line.style.transform=transform;
    if(tabPosition?.scope===scope&&(tabPosition.left!==next.left||tabPosition.width!==next.width)){
      // Start where the line is on screen, also mid-flight (a re-render replaced the element), never from the last target.
      const running=tabMotion?.animation.playState==="running",p=running?tabMotion.animation.effect.getComputedTiming().progress:null;
      const from=p===null?tabPosition:{left:tabMotion.from.left+(tabMotion.to.left-tabMotion.from.left)*p,width:tabMotion.from.width+(tabMotion.to.width-tabMotion.from.width)*p};
      tabMotion?.animation.cancel();
      const animation=animateMotion(line,[{transform:`translateX(${from.left}px) scaleX(${from.width})`},{transform}],"control");
      tabMotion=animation&&{animation,from,to:next};
    }
    tabPosition=next;
    // A re-render resets the strip to scrollLeft 0: restore the user's sideways scroll, and reveal the selected tab
    // horizontally only when the selection moved (scrollIntoView could move the page), with the strip's focus-ring padding.
    const strip=tab.parentElement,pad=strip.firstElementChild.offsetLeft;
    strip.scrollLeft=moved?Math.min(tab.offsetLeft-pad,Math.max(tabScroll,tab.offsetLeft+tab.offsetWidth+pad-strip.clientWidth)):tabScroll;
  }
  // A page change crossfades #main alone (the sidebar and top bar stay put). A change started mid-flight skips the running one,
  // which applies its update at once, so the last click wins. Reduced motion and options.instant swap in place.
  let pageChange=null;
  function showView(next,options={}){
    const update=()=>{
      if(cleanupExperience){cleanupExperience();cleanupExperience=null;}
      if(next!==view){query="";openFolder="";openMenu="";}// each view starts unfiltered and closed; its own query survives only while you stay on it
      view=next;mobileDetail=false;
      window.history.replaceState(null,"",`#${next}`);
      if(options.app!==undefined)appFilter=options.app;
      if(options.profile){selected=options.profile;mobileDetail=true;}
      renderNav();renderView();// the staggered entrance runs on first load only (refresh)
      closeNavigation();window.scrollTo({top:0,behavior:"instant"});
      if(options.focus){const heading=(options.profile&&$("#detail-title",main))||$("h1",main)||main;heading.tabIndex=-1;heading.focus({preventScroll:true});}
    };
    if(options.instant||reducedMotion.matches)return update();
    // No API, or the phone drawer is open (its slide is the motion; snapshots would cover it): enter only, never from blank.
    if(!document.startViewTransition||document.body.classList.contains("mobile-nav-open")){update();animateMotion(main,[{opacity:.5,translate:"0 8px"},{opacity:1,translate:"0 0"}]);return;}
    // The old page stays where it was on screen while it fades, though the update scrolls to the top.
    document.documentElement.style.setProperty("--page-scroll",`${window.scrollY}px`);
    // #main is named only for the change: a named element is a Backdrop Root, which would keep the folder glass from frosting the ambient field.
    main.style.viewTransitionName="main";
    const change=pageChange=document.startViewTransition(update),unname=()=>{if(pageChange===change)main.style.viewTransitionName="";};
    change.finished.then(unname,unname);
  }
  function renderView(){
    if(!state)return;
    main.classList.remove("profile-detail-mobile");
    if(view==="explore"){
      if(cleanupExperience)return;
      main.innerHTML='<div id="experience-root"></div>';exploreApp="";
      if(window.AidentityExperience)cleanupExperience=window.AidentityExperience.mount($("#experience-root"),state,{
        renderAppIcon:appGlyph,
        icon,
        appAccent,
        inkFor,
        breakable,
        statusLabel,
        addProfile:app=>addDialog(app || ""),
        refreshApps:()=>refresh({notify:true,force:true}),
        launchProfile:item=>action("open",{name:item.name}),
        focusApp:name=>{exploreApp=name;renderNav();},
      });
      // experience.js missing or broken: say so in Explore's own words, and point to Profiles, where every profile action also lives.
      else main.innerHTML=title("Explore")+emptyState("Explore did not load","Reload the page to try again. Every profile and its actions are also on Profiles.",button("Open Profiles","workspace",{primary:true,icon:"grid"}));
      return;
    }
    if(view==="profiles")renderProfiles();
    else if(view==="apps")renderApps();
    else if(view==="recovery")renderRecovery();
    else if(view==="maintenance")renderMaintenance();
    else if(view==="transfer")renderTransfer();
    else renderGuide();
    positionTabs();
  }
  // While the search field has focus, swap everything around it and keep the input itself.
  // shortcut: the toolbar's app select is not refreshed while typing; the next full render (blur, tab, nav) catches up.
  function paint(html){
    const input=$("#workspace-search",main),tpl=document.createElement("template");tpl.innerHTML=html;
    const live=[...main.children],fresh=[...tpl.content.children];
    if(!input||document.activeElement!==input||live.length!==fresh.length||!$("#workspace-search",tpl.content)){main.innerHTML=html;return;}
    live.forEach((node,i)=>{
      if(!node.contains(input))return node.replaceWith(fresh[i]);
      $('[data-action="clear-search"]',node)?.remove();
      const clear=$('[data-action="clear-search"]',fresh[i]);if(clear)input.after(clear);
      const count=$("#result-count",node),next=$("#result-count",fresh[i]);if(count&&next)count.textContent=next.textContent;
    });
  }
  function scopedProfiles(){return state.profiles.filter(item=>(!appFilter||appName(item)===appFilter)&&(!query||`${item.name} ${appName(item)} ${item.profile}`.toLowerCase().includes(query.toLowerCase())));}
  // At 901px and up the detail column is always there while the filter shows a card or holds the chosen profile, so selecting never reflows the grid
  // and a status tab, an action or a poll never drops a choice; a filter or search that hides the card does.
  // Nothing is selected for the user: only a selection they made (stored on select, cleared on close) comes back.
  const wide=matchMedia("(min-width:901px)");
  const LAST_PROFILE="aidentity.last-profile";
  function restoreSelection(visible){
    if(!wide.matches||profile(selected))return;
    const last=stored.get(LAST_PROFILE);
    if(last&&visible.some(item=>item.name===last))selected=last;
  }
  function renderProfiles(){
    const scoped=scopedProfiles();
    const running=scoped.filter(item=>item.status==="running").length;
    const visible=scoped.filter(item=>statusFilter==="all"||(statusFilter==="running"?item.status==="running":statusFilter==="attention"?needsRepair(item):item.status!=="running"));
    restoreSelection(visible);
    const chosen=scoped.some(item=>item.name===selected)?profile(selected):null;
    // The panel keeps a profile whose card left this tab; its own state, Quit and primary show again while no card carries them.
    const cardShown=Boolean(chosen)&&visible.some(item=>item.name===chosen.name);
    if(!chosen)mobileDetail=false;
    main.classList.toggle("profile-detail-mobile",mobileDetail);
    // Counts live on the tabs only. Search shows from 7 profiles, the app filter once two apps have profiles; All apps clears a filter the select cannot.
    const appNames=[...new Set(state.profiles.map(appName))].sort(byName);
    const repairs=scoped.filter(needsRepair).length;
    const search=state.profiles.length>6||query?searchField("Search profiles"):"";
    const filter=appNames.length>1?`<select id="app-filter" aria-label="Filter by application"><option value="">All apps</option>${appNames.map(name=>`<option${name===appFilter?" selected":""}>${escape(name)}</option>`).join("")}</select>`:"";
    const toolbar=search||filter||appFilter?`<div class="toolbar">${search}<div class="toolbar-end">${appFilter&&!filter?button("All apps","all-apps",{small:true}):""}${filter}${search?`<span class="sr-only" id="result-count" role="status">${plural(visible.length,"profile")}</span>`:""}</div></div>`:"";
    // No tabs until the first profile exists: on a first run they would filter nothing, and the grid is then no tabpanel.
    const strip=state.profiles.length?tabs([["all","All",scoped.length],["running","Running",running],["idle","Not running",scoped.length-running],["attention","Needs repair",lastDoctor||repairs?repairs:null,"Not checked yet. Choose Check on Maintenance."]],statusFilter):"";
    paint(title(appFilter||"Profiles")+
      strip+
      toolbar+
      `<div class="profile-layout ${visible.length||chosen?"":"no-selection"} ${mobileDetail?"mobile-detail":""}${cardShown?" card-shown":""}"><div class="profile-grid" id="profile-results"${strip?` role="tabpanel" aria-labelledby="status-${statusFilter}"`:""}>${visible.map(card).join("")||profilesEmpty(scoped)}</div>${chosen?detail(chosen):visible.length?'<p class="detail-placeholder">Select a profile to see its settings and actions.</p>':""}</div>`);
    fillPreviews();
  }
  const emptyState=(heading,text,actions="")=>`<div class="empty-state"><h2>${heading}</h2><p>${text}</p>${actions}</div>`;
  // The same words on Profiles, Applications and Explore: nothing to add to until an app is installed.
  const noAppsState=()=>emptyState("No AI apps found","Install Claude or ChatGPT, then refresh this workspace.",button("Refresh apps","refresh",{icon:"refresh"}));
  // Search-empty, filter-empty and each status tab get their own words: an empty Running tab is not a failed search.
  function profilesEmpty(scoped){
    if(!state.profiles.length)return state.errors?.length?setupError():!state.apps.length?noAppsState():emptyState("No Claude or ChatGPT profiles yet","Add one for each account, open it and sign in once. Your accounts then stay open side by side.",button("Add your first profile","add",{primary:true,icon:"plus"}));
    if(!scoped.length)return query?emptyState(`No profiles match “${escape(query)}”`,"Check the spelling or clear the search.",button("Clear search","clear-search",{primary:true,icon:"x"})):state.apps.some(item=>item.name===appFilter)?emptyState(`No ${escape(appFilter)} profiles yet`,`Each profile opens ${escape(appFilter)} with its own sign-in.`,button("Add profile","add",{primary:true,icon:"plus",app:appFilter,label:`Add profile for ${appFilter}`})):emptyState(`No ${escape(appFilter)} profiles yet`,`Install ${escape(appFilter)} to add a profile.`,button("Show all profiles","reset-filters",{icon:"grid"}));
    const all=button("Show all profiles","show-all",{icon:"grid"});
    if(statusFilter==="running")return emptyState("Nothing is running","Open a profile and it shows up here.",all);
    if(statusFilter==="attention")return emptyState("Nothing needs repair",lastDoctor?`Every profile has its app, and doctor flagged none at ${time(lastDoctor.at)}.`:"Every profile has its app. Choose Check on Maintenance for a deeper check.",lastDoctor?all:`<div class="button-row">${all}<button class="button" data-view="maintenance">${icon("shield")}<span>Open Maintenance</span></button></div>`);
    return emptyState("Every profile is running","Quit one and it shows up here.",all);
  }
  // A profile card: the app tile (its hue) carrying the profile's badge beside a real heading, then state, then the one primary action.
  // Enter on the name selects, as a click does; O runs the primary action only while focus is inside the selected card or the detail panel.
  function card(item){
    const t=tone(appName(item)),on=selected===item.name;
    const notes=[item.main?"Original account":"",item.own_extensions?"Own extensions":"",(item.args||[]).length?plural(item.args.length,"launch option"):""].filter(Boolean);
    const repair=needsRepair(item)?button("Repair","repair",{small:true,icon:"tool",name:item.name,label:`Repair, ${who(item)}`}):"";
    return `<article class="profile-card${t.cls}${on?" selected":""}${item.status==="running"?" running":""}${litCards.has(item.name)?" lit":""}${[...(item.profile||item.name)].length>24?" long-name":""}"${t.style} aria-labelledby="${profileId(item.name)}"><div class="profile-head">${art(appName(item),item.badge,item.color)}<div class="profile-title"><h2><button class="profile-name" id="${profileId(item.name)}"${on?' aria-current="true"':""} data-action="select" data-name="${escape(item.name)}">${breakable(item.profile||item.name)}</button></h2><p class="profile-app">${escape(appName(item))}</p></div></div><div class="profile-state-row">${statusMark(item)}${repair}${quitButton(item)}</div>${notes.length?`<p class="profile-meta">${notes.map(escape).join(" · ")}</p>`:""}${primaryButton(item,on)}</article>`;
  }
  // Detail: who, the command the primary action runs, then Settings, Rename and Remove; launch settings; paths and Rebuild behind Details.
  // From 768px, while the selected card is on screen it shows state, Quit and the primary action, so .detail-own (CSS) hides then (.card-shown).
  function detail(item){
    const t=tone(appName(item)),spec=JSON.stringify({action:"open",name:item.name}),command=previews.get(spec);
    const args=item.args||[],env=item.env||[];
    const launch=!args.length&&!env.length&&!item.own_extensions?'<p class="detail-defaults">Launch settings: app defaults</p>':`<dl class="details"><div><dt>Launch arguments</dt><dd>${args.length?args.map(arg=>`<code>${escape(arg)}</code>`).join("<br>"):"None"}</dd></div><div><dt>Environment variables</dt><dd>${env.length?escape(env.join(", "))+"<br><span class='small'>Values stay private</span>":"None"}</dd></div><div><dt>Extensions</dt><dd>${item.own_extensions?"Its own extensions folder":"The app’s default extensions"}</dd></div></dl>`;
    return `<aside class="detail-panel${t.cls}${litCards.has(item.name)?" lit":""}"${t.style} aria-labelledby="detail-title">${button("Back to profiles","back-profiles",{small:true,icon:"back"}).replace('class="button ','class="button detail-back ')}<div class="detail-top">${art(appName(item),item.badge,item.color)}<div class="detail-heading"><h2 id="detail-title" tabindex="-1">${breakable(item.profile||item.name)}</h2><p class="detail-app">${escape(appName(item))}${item.main?" · original account":""}</p></div><button class="icon-button detail-close" data-action="close-detail" aria-label="Close details" title="Close details">${icon("x")}</button></div><div class="detail-own"><div class="profile-state-row">${statusMark(item)}${quitButton(item)}</div>${primaryButton(item,true)}</div><div class="command-echo detail-command" data-preview="${escape(spec)}"${command?"":" hidden"}><span class="command-label">Runs:</span><code>${commandHtml(command)}</code><button type="button" class="icon-button" data-action="copy-command" aria-label="Copy command" title="Copy command">${icon("copy")}</button></div><div class="detail-actions">${button("Settings","settings",{small:true,name:item.name,label:`Settings, ${who(item)}`})}${button("Rename","rename",{small:true,name:item.name,label:`Rename, ${who(item)}`})}${button("Remove","remove",{small:true,danger:true,name:item.name,label:`Remove, ${who(item)}`})}</div>${launch}<details class="advanced detail-more"${detailMore===item.name?" open":""}><summary>${icon("chevron")}<span>Details</span></summary><dl class="details"><div><dt>Application</dt><dd>${item.app_path?breakPath(item.app_path):escape(appName(item))}</dd></div><div><dt>Profile data</dt><dd>${item.main?"The app’s own original account":item.data_dir?breakPath(item.data_dir):"No folder recorded"}</dd></div><div><dt>Made by</dt><dd>${escape(item.built_by||"Not recorded")}</dd></div></dl><div class="detail-rebuild"><p>Makes the small app that opens this profile again from its saved settings. Its data is not touched.</p>${button("Rebuild launcher","rebuild",{small:true,icon:"rebuild",name:item.name,label:`Rebuild launcher, ${who(item)}`})}</div></details></aside>`;
  }
  let detailMore="";
  // The detail panel's "Runs:" line comes from the server's /api/preview, like the dialogs' line; never built here.
  const previews=new Map();
  async function fillPreviews(){
    for(const echo of $$("[data-preview]",main)){
      const spec=echo.dataset.preview;let command=previews.get(spec);
      if(command===undefined&&!offline&&state?.csrf_token){
        try{const response=await post("/api/preview",spec);const result=await response.json();if(response.ok&&result.ok&&result.command){command=result.command;previews.set(spec,command);}}catch{}
      }
      if(command&&echo.isConnected){$("code",echo).innerHTML=commandHtml(command);echo.hidden=false;}
    }
  }
  const profileCount=name=>state.profiles.filter(item=>appName(item)===name).length;
  // Apps with profiles first, then by name: Applications and the Add dialog's select share this order.
  const sortedApps=()=>[...state.apps].sort((a,b)=>(profileCount(b.name)>0)-(profileCount(a.name)>0)||byName(a.name,b.name));
  // Applications: every listed app is a glass folder, apps with profiles first, adapted from kedhareswer's Glass Folder Cards
  // (21st.dev): a back panel, the app's profiles as files and a frosted front panel. Open, the files fan out and each one shows
  // its profile on Profiles; + adds a profile; ··· holds Show profiles and Add profile. One folder is open at a time, and a
  // re-render keeps it open. Two apps at most (AI_APPS), so no search.
  const FOLDER_BACK="M0 54A20 20 0 0 1 20 34L146 34C170 34 172 0 198 0L320 0A20 20 0 0 1 340 20L340 252A20 20 0 0 1 320 272L20 272A20 20 0 0 1 0 252Z";
  const FOLDER_FRONT="M0 20A20 20 0 0 1 20 0L118 0C144 0 146 32 172 32L320 32A20 20 0 0 1 340 52L340 178A20 20 0 0 1 320 198L20 198A20 20 0 0 1 0 178Z";
  // Four files at most: past that, three and a "N more profiles" file that opens Profiles for the app. Profiles added on this
  // page this session come first, newest on top, then running ones, then by name.
  const FOLDER_FILES=4,folderRecent=[];
  let openFolder="",openMenu="",folderDrop="";
  const folderId=name=>`folder-${appHash(name).toString(36)}`;
  function folderCard(app){
    const t=tone(app),id=folderId(app),open=openFolder===app,menuOpen=openMenu===app,rank=item=>{const at=folderRecent.indexOf(item.name);return at<0?Infinity:at;};
    const items=state.profiles.filter(item=>appName(item)===app).sort((a,b)=>rank(a)-rank(b)||(b.status==="running")-(a.status==="running")||byName(a.profile||a.name,b.profile||b.name));
    const shown=items.length>FOLDER_FILES?items.slice(0,FOLDER_FILES-1):items,running=items.filter(item=>item.status==="running").length;
    const files=shown.map(item=>{const hex=/^[0-9a-f]{6}$/i.test(item.color)?item.color:defaultBadgeColor;return [item.name,`<button type="button" class="gf-sheet${item.status==="running"?" gf-running":""}" data-folder-file data-name="${escape(item.name)}"><span class="gf-head">${item.badge?`<span class="gf-chip" style="--identity-color:#${hex};--identity-ink:${inkFor(hex)}" aria-hidden="true">${escape(item.badge)}</span>`:`<span class="gf-chip gf-chip-app" aria-hidden="true">${appGlyph(app)}</span>`}<span class="gf-name">${breakable(item.profile||item.name)}</span>${item.status==="running"?'<span class="gf-state status-running"><span class="running-dot"></span>Running</span>':item.status==="app missing"?'<span class="gf-state status-missing">App missing</span>':""}</span></button>`];});
    if(items.length>shown.length)files.push(["",`<button type="button" class="gf-sheet" id="${id}-more" data-app-filter="${escape(app)}"><span class="gf-head"><span class="gf-chip gf-chip-more" aria-hidden="true">${icon("grid")}</span><span class="gf-name">${items.length-shown.length} more profiles</span><span class="gf-state">Show all</span></span></button>`]);
    if(!items.length)files.push(["",`<div class="gf-sheet gf-sheet-empty"><span class="gf-head"><span class="gf-name">No ${escape(app)} profiles yet<span class="gf-note">Each profile opens ${escape(app)} with its own sign-in.</span></span></span></div>`]);
    // Back to front in reading order; --slot places a file across the fan (-1 to 1), --depth counts the files in front of it,
    // and a small offset from its name's hash keeps the stack hand-placed.
    const last=files.length-1,sheets=files.map(([name,html],at)=>{const seed=appHash(name||app);return `<li class="gf-slot${name&&name===folderDrop?" gf-drop":""}" style="--slot:${last?(at/last*2-1).toFixed(3):0};--depth:${last-at};--jx:${((seed&255)/42.5-3).toFixed(2)};--jr:${((seed>>8&255)/160-.8).toFixed(2)};z-index:${at+1}">${html}</li>`;}).join("");
    return `<article class="folder${t.cls}"${t.style} data-folder-app="${escape(app)}"${open?" data-open":""} aria-labelledby="${id}-title"><div class="gf-stage"><div class="gf-tilt"><div class="gf-shadow" aria-hidden="true"></div><div class="gf-back" style="clip-path:path('${FOLDER_BACK}')" aria-hidden="true"></div><svg class="gf-rim gf-back-rim" viewBox="0 0 340 272" aria-hidden="true"><path d="${FOLDER_BACK}"/></svg><div class="gf-front" style="clip-path:path('${FOLDER_FRONT}')"><div class="gf-glass" aria-hidden="true"></div><svg class="gf-rim gf-front-rim" viewBox="0 0 340 198" aria-hidden="true"><path d="${FOLDER_FRONT}"/></svg><div class="gf-label">${art(app)}<div><h2 id="${id}-title">${escape(app)}</h2><p class="gf-count" id="${id}-count"><span>${plural(items.length,"profile")}</span>${running?`<span class="gf-run status-running"><span class="running-dot"></span><span>${running} running</span></span>`:""}</p></div></div><button type="button" class="gf-hit" id="${id}" data-folder aria-expanded="${open}" aria-controls="${id}-files" aria-labelledby="${id}-title ${id}-count"></button></div><ul class="gf-files" id="${id}-files" aria-label="${escape(app)} profiles"${open?"":" inert"}>${sheets}</ul><div class="gf-keys"><button type="button" class="gf-key${items.length?"":" gf-key-primary"}" data-action="add" data-app="${escape(app)}" aria-label="${escape(`Add profile for ${app}`)}" title="Add profile">${icon("plus")}</button><button type="button" class="gf-key" data-folder-menu aria-haspopup="menu" aria-expanded="${menuOpen}" aria-controls="${id}-menu" aria-label="${escape(`More for ${app}`)}" title="More">${icon("more")}</button></div><div class="gf-menu" id="${id}-menu" role="menu" aria-label="${escape(app)}"${menuOpen?"":" hidden"}><button type="button" role="menuitem" tabindex="-1" id="${id}-show" data-app-filter="${escape(app)}">${icon("grid")}<span>Show ${escape(app)} profiles</span></button><button type="button" role="menuitem" tabindex="-1" id="${id}-add" data-action="add" data-app="${escape(app)}">${icon("plus")}<span>Add profile</span></button></div></div></div></article>`;
  }
  function renderApps(){
    const apps=sortedApps().map(item=>item.name);
    if(!apps.includes(openFolder))openFolder="";if(!apps.includes(openMenu))openMenu="";// its app left discovery, or a new profile's app has no folder
    const folders=apps.map(name=>folderCard(name)).join("");
    main.innerHTML=title("Applications")+`<div class="apps-grid">${folders||(state.errors?.length?setupError():noAppsState())}</div>`;
    layoutFolders();
  }
  // Each folder's scale (--k: it never grows past 340px) and its open fan. Every open file shows its whole name strip above the
  // file in front of it, so the strips are measured front to back, and the folder reserves the room its fan needs (--headroom),
  // so opening never reflows the page. Stage units: the front file's strip ends at 70, on the glass's raised tab (74), and the
  // file in front covers 6 of each strip's 11px foot, so the fan needs about a third less room than whole strips would.
  // The fan's top may reach the folder's own top: the title row's 24px margin is its clearance.
  function layoutFolders(){
    for(const node of $$(".folder",main)){
      node.style.setProperty("--k",Math.min(1,node.clientWidth/340).toFixed(4));
      let top=70;
      for(const slot of $$(".gf-slot",node).reverse()){top-=$(".gf-head",slot).offsetHeight-6;slot.style.setProperty("--open-y",String(top-96));}
      node.style.setProperty("--headroom",String(Math.max(16,Math.ceil(4-top))));
    }
  }
  function setFolder(node,open){
    closeFolderMenu();
    $$(".folder[data-open]",main).forEach(other=>{if(other===node&&open)return;other.removeAttribute("data-open");$(".gf-hit",other).setAttribute("aria-expanded","false");$(".gf-files",other).inert=true;});
    openFolder=open&&node?node.dataset.folderApp:"";
    if(!openFolder)return;
    node.setAttribute("data-open","");$(".gf-hit",node).setAttribute("aria-expanded","true");$(".gf-files",node).inert=false;
    node.scrollIntoView({block:"nearest",behavior:reducedMotion.matches?"instant":"smooth"});
  }
  function setFolderMenu(node,open){
    if(open)closeFolderMenu();
    openMenu=open?node.dataset.folderApp:"";
    const menu=$(".gf-menu",node);$("[data-folder-menu]",node).setAttribute("aria-expanded",String(open));
    present(menu,open,[{opacity:0,transform:"translateY(6px) scale(.96)"},{opacity:1,transform:"none"}]);
    if(open)$("[role=menuitem]",menu).focus();
  }
  // focusKey: focus goes back to ··· before the menu hides, so it never falls to <body> (a dialog opened from the menu returns there).
  function closeFolderMenu(focusKey=false){
    openMenu="";const key=$('[data-folder-menu][aria-expanded="true"]',main);if(!key)return;
    if(focusKey)key.focus();setFolderMenu(key.closest(".folder"),false);
  }
  // After an add on Applications: its folder opens and the new profile drops in as the top file, the count rolls over, and focus
  // lands on the file once the dialog closes. The ground's ring spreads from it as it lands (across the field for the first profile).
  function dropIntoFolder(name,first=false){
    const item=profile(name);if(!item)return;// a profile made for another app is not listed; its toast says so
    folderRecent.unshift(name);openFolder=appName(item);folderDrop=name;
    renderApps();folderDrop="";
    const file=$$("[data-folder-file]",main).find(el=>el.dataset.name===name),node=file?.closest(".folder");if(!file)return;
    node.classList.add("gf-landed");lastFocus=file;
    node.scrollIntoView({block:"nearest",behavior:reducedMotion.matches?"instant":"smooth"});
    setTimeout(()=>ripple(file,first?"far":"near"),600);
  }
  function renderRecovery(){
    const entries=state.restorable||[],unclaimed=state.unclaimed||[];
    // A list the server could not read is unknown, not empty: say so instead of "Nothing …".
    const restorableFailed=state.restorable_ok===false,unclaimedFailed=state.unclaimed_ok===false;
    const unread=what=>`<p class="muted">Could not read ${what}. Refresh to try again.</p>`;
    main.innerHTML=title("Recovery")+
    `<section class="panel">${tile("recovery","recovery")}<div class="panel-heading"><h2>${entries.length?`${plural(entries.length,"profile")} to restore`:restorableFailed?"Profiles to restore":"Nothing to restore"}</h2>${entries.length>1?button("Restore all","restore-all",{icon:"recovery"}):""}</div>${entries.length?`<p>${entries.length===1?"Its launcher was removed, but its data is still on this Mac.":"Their launchers were removed, but their data is still on this Mac."}</p><div class="recovery-list">${entries.map(item=>`<div class="recovery-row"><h3>${breakable(item.name)}</h3>${button("Restore","restore",{icon:"recovery",name:item.name,label:`Restore ${item.name}`})}</div>`).join("")}</div>`:restorableFailed?unread("restorable profiles"):state.profiles.length?'<p class="muted">Every profile with kept data already has a launcher.</p>':'<p class="muted">Remove a profile and keep its data, and it appears here, ready to restore.</p>'}</section>`+
    `<section class="operation-card section-gap">${tile("danger","trash")}<h2>${unclaimed.length||unclaimedFailed?"Clear unclaimed data":"Nothing unclaimed"}</h2>${unclaimedFailed?unread("unclaimed data"):""}<p>Unclaimed data is a profile folder that no launcher uses. Clearing moves it to the Trash, so restore any profile you want to keep first.</p><div class="button-row">${button("Clear unclaimed data…","prune",{danger:true,icon:"trash",disabled:!unclaimed.length})}</div></section>`;
  }
  // The latest doctor run, read from the server's summary and findings; the raw output stands in when they are absent.
  function healthResult(){
    if(!lastDoctor)return "";
    const {result,at}=lastDoctor,sum=result.summary,findings=Array.isArray(result.findings)?result.findings:null;
    const words={error:"Error",warn:"Warning",ok:"OK"},order={error:0,warn:1,ok:2};
    const count=(n,one,tone)=>`<span${n>0?` class="${tone}"`:""}><strong class="num">${n||0}</strong> ${n===1||one==="OK"?one:`${one}s`}</span>`;
    const head=`<p class="health-summary">${sum?count(sum.ok,"OK","positive")+count(sum.warn,"warning","warning")+count(sum.error,"error","negative"):""}<time>Checked ${time(at)}</time></p>`;
    const body=findings?`<ul class="health-findings">${[...findings].sort((a,b)=>(order[a.level]??3)-(order[b.level]??3)).map(item=>`<li data-level="${escape(item.level)}">${icon(item.level==="ok"?"check":"alert")}<span class="finding-level">${words[item.level]||escape(item.level)}</span><span>${!item.profile?escape(item.text):item.text===item.profile?`<strong>${breakable(item.profile)}</strong>`:`<strong>${breakable(item.profile)}:</strong> ${escape(item.text)}`}</span></li>`).join("")}</ul>`:`<pre class="output">${escape([result.stdout,result.stderr].filter(Boolean).join("\n")||"No output.")}</pre>`;
    return `<div class="health-result">${head}${body}${healthIssues()?'<p class="health-next">Next step: <strong>Check and repair</strong> rebuilds the launchers it can fix.</p>':""}</div>`;
  }
  const healthIssues=()=>{const sum=lastDoctor?.result.summary;return sum?(sum.warn||0)+(sum.error||0):0;};
  function renderMaintenance(){
    const issues=healthIssues();
    // Update now appears only once a check has found a newer version.
    const update=lastUpdate?`<p class="update-status">${escape(lastUpdate.text)} <time class="small">Checked ${time(lastUpdate.at)}</time></p>`:"";
    main.innerHTML=title("Maintenance")+
    `<div class="operation-grid"><section class="operation-card wide">${tile("maintenance","shield")}<h2>Workspace health</h2><p>Doctor checks your setup and every profile for missing apps, stale launchers and settings problems.</p>${healthResult()||'<p class="health-empty">Not checked yet. Choose Check to see the result here.</p>'}<div class="button-row">${button("Check","doctor",{primary:!issues,icon:"shield"})}${button("Check and repair","doctor-fix",{primary:issues>0,icon:"tool"})}</div></section><section class="operation-card">${tile("maintenance","update")}<h2>aidentity updates</h2><p>Installed version: <span class="num">${escape(state.version)}</span>.</p>${update}<div class="button-row">${button("Check for updates","update-check",{icon:"update"})}${lastUpdate?.available?button("Update now","update",{primary:true,icon:"update"}):""}</div></section><section class="operation-card">${tile("maintenance","rebuild")}<h2>Rebuild launchers</h2><p>Rebuild makes every launcher again from its saved settings and the app’s current location. Profile data is not touched.</p><div class="button-row">${button("Rebuild all","rebuild-all",{icon:"rebuild"})}</div></section></div>`+
    `<section class="storage-panel" aria-labelledby="storage-title"><h2 id="storage-title">Local storage</h2><dl class="details storage-list"><div><dt>Launchers</dt><dd>${state.paths?.launchers?breakPath(state.paths.launchers):"Not available"}</dd></div><div><dt>Profile data</dt><dd>${state.paths?.data?breakPath(state.paths.data):"Not available"}</dd></div></dl></section>${errorNotice()}`;
  }
  function renderTransfer(){
    main.innerHTML=title("Import & export")+
    `<div class="operation-grid"><section class="operation-card">${tile("transfer","download")}<h2>Export</h2><p>${inventory.profiles.length?`Save the names, badges, colors and launch settings of ${plural(inventory.profiles.length,"profile")} to a file.`:"Nothing to export yet. Add a profile first."}</p><div class="button-row">${button("Export profiles","export",{primary:true,icon:"download",disabled:!inventory.profiles.length})}</div></section><section class="operation-card">${tile("transfer","upload")}<h2>Import</h2><p>Review an aidentity export file, then make its profiles with the apps installed here. They start signed out unless their data is already on this Mac.</p><div class="button-row">${button("Import profiles","import",{icon:"upload"})}</div></section></div>`;
  }
  const terms=[["Profile","An app opened with its own sign-in and data. You add, open and remove profiles."],["Launcher","The small app aidentity makes to open a profile."],["Original account","The app’s own account, opened through aidentity."],["Doctor","Checks your setup and every profile for problems."],["Unclaimed data","Profile data that no launcher uses. Clearing it moves it to the Trash."],["Restore","Makes a removed profile’s launcher again from its kept data."]];
  function renderGuide(){
    const commands=["","setup","ui","add","list","open","quit","rename","set","prune","restore","rebuild","rm","export","import","apps","doctor","update","completion","version","help","dashboard"];
    main.innerHTML=title("Help")+
      `<section class="terms" aria-labelledby="terms-title"><h2 id="terms-title">Terms</h2><dl>${terms.map(([term,text])=>`<div><dt>${term}</dt><dd>${text}</dd></div>`).join("")}<div class="terms-keys"><dt>Keyboard</dt><dd><kbd>/</kbd> search · <kbd>⌘B</kbd> collapse sidebar · <kbd>O</kbd> open the focused profile</dd></div></dl></section>`+
      `<div class="guide-layout"><section class="panel guide-controls"><div class="field"><label for="help-command">Command help</label><select id="help-command">${commands.map(command=>`<option value="${command}"${command===guideCommand?" selected":""}>${command||"All commands"}</option>`).join("")}</select><div class="section-gap">${button("Read help","help",{icon:"book"})}</div></div><div class="field"><label for="completion-shell">Shell completion</label><select id="completion-shell">${["zsh","bash","fish"].map(shell=>`<option${shell===guideShell?" selected":""}>${shell}</option>`).join("")}</select><div class="section-gap">${button("Generate completion","completion",{icon:"terminal"})}</div></div></section><section><div class="panel-heading"><h2>Command output</h2>${guideText?button("Copy output","copy-guide",{small:true,icon:"copy"}):""}</div>${guideText?`<pre class="output guide-output">${escape(guideText)}</pre>`:'<p class="guide-empty">Choose a command to read its help, or generate a completion script for your shell.</p>'}</section></div>`;
  }
  async function refresh(options={}){
    // loading is the read in flight: a polled read yields to it, a forced one (after an action) waits and then runs its own.
    while(loading){if(!options.force)return null;await loading;}
    let release;loading=new Promise(resolve=>{release=resolve;});let changed=null;
    try{
      const response=await fetch(options.force?"/api/state?fresh=1":"/api/state",{cache:"no-store"});
      const data=await response.json();
      if(!response.ok||!data.ok)throw Object.assign(new Error(data.error||"Could not read the workspace."),{server:true});
      const firstLoad=!state,was=new Map((state?.profiles||[]).map(item=>[item.name,item.status]));
      // inventory keeps every entry for counts of CLI-wide actions and the import preview; recovery lists stay whole in state too.
      inventory=data;
      iconApps=new Set([...data.apps.filter(item=>item.icon).map(item=>item.name),...data.profiles.filter(item=>item.app_icon).map(appName)]);
      const profiles=data.profiles.filter(item=>AI_APPS.includes(appName(item)));
      await learnIconAngles(profiles);
      state={...data,apps:data.apps.filter(item=>AI_APPS.includes(item.name)),profiles};
      registerAppAccents(state);
      for(const item of state.profiles)if(item.status==="running"&&was.has(item.name)&&was.get(item.name)!=="running")litCards.add(item.name);
      loadedAt=new Date();$("#freshness").textContent=`Updated ${time(loadedAt)}`;
      setOffline(false);
      const current=JSON.stringify({version:data.version,profiles:data.profiles,apps:data.apps,restorable:data.restorable,unclaimed:data.unclaimed,errors:data.errors});
      changed=current!==lastData;
      keepFocus(()=>{
        renderNav();
        if(!changed&&!options.force)return;
        lastData=current;
        const previousScroll=window.scrollY;
        if(view==="explore"&&cleanupExperience){cleanupExperience();cleanupExperience=null;}
        renderView();
        if(firstLoad)animateWorkspaceChange();
        if(view==="explore")requestAnimationFrame(()=>requestAnimationFrame(()=>window.scrollTo({top:previousScroll,behavior:"instant"})));
      });
      litCards.clear();// lit once, in the render this read caused; a later render or visit shows the card at rest
      syncControls();// the first good read unlocks the controls
      if(options.notify)toast("Workspace refreshed");
    }catch(error){
      // No reply at all (or not JSON) means the server is gone; a reported error means it is up but could not read the setup.
      const wasOffline=offline;if(!error.server)setOffline(true);
      // Server gone: the banner holds the step, so the page does not repeat it. Server up but failing: its own words.
      // The cause leads the body as an empty state, under the page title.
      const unavailable=(cause,notice="")=>`${title("Workspace unavailable")}<div class="empty-state"><h2>${cause}</h2>${notice}<div class="section-gap">${button("Retry connection","refresh",{primary:true,icon:"refresh"})}</div></div>`;
      if(!state)main.innerHTML=error.server?unavailable("The local server could not read your setup",`<div class="notice error" tabindex="0">${escape(error.message)}</div>`):unavailable("This page could not reach the dashboard");
      $("#freshness").textContent=loadedAt?`Last updated ${time(loadedAt)}`:"Connection unavailable";
      if(options.notify)toast(error.server?"Refresh failed":wasOffline?"Still disconnected":"Disconnected",error.server?error.message:"",true);// the banner says how to reconnect
    }finally{loading=false;release();}
    return changed;
  }
  function setOffline(on){
    if(offline===on)return;
    offline=on;document.body.classList.toggle("is-offline",on);
    const banner=$("#connection-banner");banner.hidden=!on;
    banner.innerHTML=on?`<p><strong>The dashboard stopped.</strong> Run <code>${commandHtml(RECONNECT)}</code> in Terminal to reconnect. This page picks it up on its own.</p><button type="button" class="icon-button" data-action="copy-command" aria-label="Copy command" title="Copy command">${icon("copy")}</button>`:"";
    $("#connection-state").textContent=on?"Disconnected":"Connected";$(".scope").title=on?"Disconnected from this Mac":"Connected to this Mac";
    syncControls();
    // Gone: poll at the offline pace from now, not after a quiet poll's 30s, so a restarted server is picked up within 5s.
    if(on)schedulePoll();
    // Back online: a toast that says disconnected leaves, the Runs lines that hid come back, and an open form drops the reconnect step.
    if(!on){ripple($(mobile.matches?"#refresh":".connection-dot"));$$(".toast[data-offline]").forEach(node=>$(".icon-button",node).click());fillPreviews();if(dialog.open){schedulePreview(0);const error=$("#form-error",dialog);if(error?.textContent===OFFLINE)error.hidden=true;}}
  }
  // While an action runs or the server is gone, run-type controls wait (aria-disabled); navigation and copy stay usable.
  const freeActions=new Set(["select","close-detail","back-profiles","clear-search","all-apps","reset-filters","show-all","workspace","refresh","copy-guide","copy-command"]);
  function syncControls(){
    const lock=Boolean(busy)||offline||!state;// !state: nothing to act on before the first good read
    document.body.classList.toggle("is-busy",Boolean(busy));
    $$("[data-action],[data-xp-run],#header-add,#dialog-submit").forEach(el=>{
      if(freeActions.has(el.dataset.action)||el.closest("#experience-root")&&!el.hasAttribute("data-xp-run"))return;
      const on=lock&&el.getAttribute("aria-busy")!=="true";
      // data-locked="own": the control was already disabled for its own reason (Explore), so unlocking keeps aria-disabled.
      if(on&&!el.hasAttribute("data-locked")){el.setAttribute("data-locked",el.getAttribute("aria-disabled")==="true"?"own":"");el.setAttribute("aria-disabled","true");}
      else if(!on&&el.hasAttribute("data-locked")){if(el.getAttribute("data-locked")!=="own")el.removeAttribute("aria-disabled");el.removeAttribute("data-locked");}
    });
  }
  function setBusy(element,on){
    if(!element)return;
    if(on){element.dataset.original=element.innerHTML;element.innerHTML=`<span class="button-content">${element.innerHTML}</span><span class="button-loader"><span class="spinner"></span></span>`;element.dataset.loading="true";element.disabled=true;element.setAttribute("aria-busy","true");}
    else {if(element.dataset.original!==undefined)element.innerHTML=element.dataset.original;delete element.dataset.loading;element.disabled=false;element.removeAttribute("aria-busy");}
  }
  const verbs={open:"open",quit:"quit",add:"add the profile",set:"save the settings",rename:"rename",remove:"remove",restore:"restore",rebuild:"rebuild",prune:"clear unclaimed data",doctor:"check the workspace",import:"import",export:"export",update:"update",help:"read the help",completion:"generate completion"};
  const doing={open:"Opening…",quit:"Closing…",add:"Adding the profile…",set:"Saving the settings…",rename:"Renaming…",remove:"Removing…",restore:"Restoring…",rebuild:"Rebuilding…",prune:"Clearing unclaimed data…",doctor:"Running doctor…",import:"Importing…",export:"Exporting…",update:"Updating aidentity…",help:"Loading the help…",completion:"Generating completion…"};
  async function action(name,params={},element=null,{quiet=false}={}){
    // A dialog's own action reports a failure in its form error while that form is on screen, so no toast says it again over it.
    const inDialog=element?.id==="dialog-submit";
    if(busy||offline||!state?.csrf_token){
      const error=busy?Object.assign(new Error("Another action is still running. Try again when it finishes."),{busy:true}):new Error(OFFLINE);
      if(!quiet&&!inDialog){toast(busy?"Still working":"Disconnected",busy?error.message:"",busy?"info":true);error.reported=true;}
      throw error;
    }
    const before=state,beforeAll=inventory,from=focusOrigin(element);let note=null,entry=null;
    busy=name;setBusy(element,true);syncControls();
    const doingText=name==="update"&&params.check?"Checking for updates…":doing[name]||"Working…",started=Date.now();
    $("#activity-toggle").hidden=false;$("#activity-summary").textContent=doingText;
    // A slow or hung CLI call says how long it has run, from 5s: in the activity bar, and in the footer of the dialog that ran it.
    // Only the seconds change, in an aria-hidden span, so the footer's status speaks once.
    const ticker=setInterval(()=>{
      const seconds=Math.round((Date.now()-started)/1000);if(seconds<5)return;
      $("#activity-summary").innerHTML=`<span>${escape(doingText)}</span> <span class="num">${seconds}s</span>`;
      const status=element?.id==="dialog-submit"&&$(".dialog-status",dialog);
      if(status){if(!status.firstChild)status.innerHTML=`<span>${escape(doingText)}</span> <span class="num" aria-hidden="true"></span>`;status.lastChild.textContent=`${seconds}s`;}
    },1000);
    try{
      let response,result;
      try{response=await post("/api/action",{action:name,...params});}
      catch(error){setOffline(true);entry=logActivity({action:name,ok:false,output:`${error.name}: ${error.message}\n${OFFLINE}`});throw new Error(OFFLINE);}
      try{result=await response.json();}catch{result={ok:false,error:`The dashboard sent an unreadable reply (HTTP ${response.status}).`};}
      if(response.status===409&&result.busy)throw Object.assign(new Error(result.error||"Another action is still running. Try again when it finishes."),{busy:true});
      entry=logActivity({action:name,ok:Boolean(result.ok),command:result.command,output:name==="export"&&result.ok?"Export file prepared for download.":[result.stdout,result.stderr,result.error].filter(Boolean).join("\n")});
      // Doctor reports findings with a non-zero exit; a summary means it ran, so it is a result, not a failure.
      const report=name==="doctor"&&Boolean(result.summary);
      if((!response.ok||!result.ok)&&!report)throw Object.assign(new Error(result.error||result.stderr||result.stdout||`${name} failed (exit ${result.exit_code}).`),{field:result.field,stale:response.status===409});
      if(name==="doctor"){lastDoctor={result,at:new Date()};doctorFlags=new Set((result.findings||[]).filter(item=>item.profile&&(item.level==="warn"||item.level==="error")).map(item=>item.profile));saveDoctor();}
      if(name==="rebuild"){if(params.all)doctorFlags.clear();else doctorFlags.delete(params.name);saveDoctor();}
      if(name!=="add")note=describe(name,params,result,before);
      await refresh({force:true});
      if(name==="add"){result.created=inventory.profiles.find(item=>!beforeAll.profiles.some(old=>old.name===item.name))?.name||`${params.app} ${params.profile}`;note=describe(name,params,result,before);}
      entry.title=note.title;renderActivity();
      if(!quiet)toast(note.title,note.text,note.kind,note.extra);
      // A profile that starts running, or comes back, sends the ground's ring: from where it shows, else from the toast that says so.
      const woke=name==="open"&&before.profiles.find(item=>item.name===params.name)?.status!=="running";
      if(woke||name==="restore")ripple((woke&&profileSpot(params.name))||toastViewport.firstElementChild);
      return result;
    }catch(error){
      // A 409 that is not "busy" means what the user approved changed underneath: reread, so the page shows the current list.
      if(error.stale)await refresh({force:true}).catch(()=>{});
      const failure=error.busy?"Still working":error.message===OFFLINE?"Disconnected":`Could not ${verbs[name]||name}${params.name?` ${params.name}`:""}`;
      if(entry)entry.title=failure;
      if(!quiet&&!(inDialog&&dialog.open)&&!error.reported){toast(failure,error.message===OFFLINE?"":String(error.message),error.busy?"info":true);error.reported=true;}
      renderActivity();
      throw error;
    }finally{clearInterval(ticker);$(".dialog-status",dialog)?.replaceChildren();busy=false;setBusy(element,false);syncControls();returnFocus(from);}
  }
  // Plain-words toast for a finished action. Runs before the post-action refresh (add after it, to learn the new name).
  function describe(name,params,result,before){
    const who=params.name||"",was=before?.profiles.find(item=>item.name===who);
    // A profile added by path for another app is created but hidden; say so only when the fresh full list has it.
    if(name==="add")return {title:`${result.created} is ready`,text:!profile(result.created)&&inventory.profiles.some(item=>item.name===result.created)?"The dashboard lists only Claude and ChatGPT, so it is not shown here. Open it now.":params.main?"Open it to use the original account.":"Open it to sign in with that account.",extra:{label:"Open it",run:()=>action("open",{name:result.created})}};
    if(name==="open"){
      if(was?.status==="running")return {title:`Brought ${who} to the front`};
      const key=`aidentity.signin-hint.${who}`,first=was?.status==="signed out / new"&&!stored.get(key);
      if(first)stored.set(key,"shown");
      return {title:`Opened ${who}`,text:first?SIGN_IN_HINT:""};
    }
    if(name==="quit")return {title:`Closed ${who}`};
    if(name==="remove")return {title:`${who} removed`,text:params.purge?"Its profile data is in the Trash.":"Its profile data stays on this Mac.",extra:params.purge||was?.main?null:{label:"Restore",run:()=>action("restore",{name:who})}};
    if(name==="restore")return params.all?{title:`Restored ${plural(before.restorable?.length||0,"profile")}`,text:"Each one opens with its existing data."}:{title:`${who} restored`,text:"It opens with its existing data."};
    if(name==="rebuild")return params.all?{title:`Rebuilt ${plural(inventory.profiles.length,"launcher")}`,text:"Profile data was not touched."}:{title:`${who} rebuilt`,text:"Its profile data was not touched."};
    if(name==="rename")return {title:`Renamed ${who}`,text:`It is now ${appName(was||{})} ${params.new_name}.`};
    if(name==="set")return {title:`${who} settings saved`};
    if(name==="prune")return {title:"Unclaimed data cleared",text:lastLine(result.stdout)};
    if(name==="doctor"){
      const sum=result.summary;
      if(!sum)return {title:params.fix?"Check and repair finished":"Check finished",text:"The full report is in Activity."};
      const issues=(sum.warn||0)+(sum.error||0),away=view!=="maintenance";
      return {title:`Checked ${plural(inventory.profiles.length,"profile")}: ${issues?`${issues} ${issues===1?"needs":"need"} attention`:"all healthy"}`,text:issues?(away?"The findings are in Maintenance.":"The findings are in Workspace health."):"",kind:sum.error?"error":sum.warn?"warn":"ok",extra:issues&&away?{label:"Show findings",run:()=>showView("maintenance",{focus:true})}:null};
    }
    if(name==="update"&&params.check){
      const {installed,available}=result;
      // The CLI never downgrades: a build newer than the latest release is up to date, not an update.
      if(installed&&available&&byName(available,installed)>0){lastUpdate={text:`Version ${available} is available (you have ${installed}).`,available:true,at:new Date()};return {title:`Version ${available} is available`,text:`You have ${installed}. Choose Update now on Maintenance to install it.`};}
      if(installed&&available){lastUpdate={text:byName(available,installed)===0?`You’re on the latest version (${installed}).`:`You have ${installed}, newer than the latest release (${available}).`,available:false,at:new Date()};return {title:"aidentity is up to date",text:lastUpdate.text};}
      lastUpdate=null;return {title:"Update check finished",text:lastLine(result.stdout)||"The full result is in Activity."};
    }
    if(name==="update"){lastUpdate=null;return {title:"aidentity updated",text:lastLine(result.stdout)};}
    if(name==="import"){
      // The CLI's own summary: "N created, N skipped, N failed." or "Nothing to create."/"Nothing to do." (exit 0).
      const summary=String(result.stdout||"").split("\n").map(line=>line.trim()).filter(line=>/^\d+ created, |Nothing to (create|do)\./.test(line)).pop()||"The import finished.";
      const made=Number(/^(\d+) created/.exec(summary)?.[1]||0);
      return {title:made?`Imported ${plural(made,"profile")}`:"Nothing imported",text:summary,kind:made?"ok":"info"};
    }
    if(name==="export")return {title:"Profiles exported",text:"Downloaded aidentity-profiles.json. Keep the file private."};
    if(name==="help")return {title:"Command help is ready"};
    if(name==="completion")return {title:`${params.shell||"Shell"} completion is ready`};
    return {title:"Done",text:lastLine(result.stdout)};
  }
  function logActivity(record){history.unshift({time:new Date(),...record});history=history.slice(0,12);renderActivity();return history[0];}
  // The bar stays hidden until the first entry; sessionStorage may throw or be full, and then Activity lasts for this page only.
  function renderActivity(){
    $("#activity-toggle").hidden=!history.length&&!busy;if(!history.length)showActivity(false);
    try{sessionStorage.setItem(ACTIVITY,JSON.stringify(history));}catch{}
    $("#activity-content").innerHTML=history.map(item=>`<article class="activity-entry"><div class="activity-entry-title"><strong class="${item.ok?"":"activity-error"}">${breakable(item.title||`${item.action} · ${item.ok?"Completed":"Failed"}`)}</strong><time>${time(item.time)}</time></div>${item.command?`<code class="activity-command">${commandHtml(item.command)}</code>`:""}<pre class="output">${escape(item.output||"Completed without additional output.")}</pre></article>`).join("")||'<p class="muted">Nothing run yet. Each action you run shows up here with its command.</p>';
    // The summary uses the toast's title; an entry gets it once its action finishes, so "Running…" stays until then.
    // A long title gives way, cut with an ellipsis, so "View details" stays on the one line of the bar.
    if(!history[0]||history[0].title)$("#activity-summary").innerHTML=history[0]?`<span class="activity-summary-title">${escape(history[0].title)}</span> <span class="activity-summary-more">· View details</span>`:"Activity · Nothing run yet";
  }
  // kind: true or "error", "warn", "info", or "ok"; extra: {label, run} adds a next-step button (Open it, Restore).
  function toast(titleText,description,kind=false,extra=null){
    const level=kind===true?"error":kind||"ok";
    const viewport=toastViewport;
    const node=document.createElement("div");node.className=`toast ${level==="ok"?"":level}`;node.setAttribute("role",level==="error"?"alert":"status");
    if(/^(Still )?disconnected$/i.test(titleText))node.dataset.offline="";// dismissed on reconnect
    // A long error shows its first 180 characters; View details opens Activity, which keeps the full output. A short toast needs no link: the activity bar names it.
    const text=String(description||""),long=text.length>180;
    const actions=`${extra?`<button class="toast-action toast-primary">${escape(extra.label)}</button>`:""}${long&&history.length?'<button class="toast-action toast-activity">View details</button>':""}`;
    node.innerHTML=`${icon(level==="ok"?"check":"alert")}<div><strong>${breakable(titleText)}</strong>${text?`<p>${breakable(long?`${text.slice(0,180).trimEnd()}…`:text)}</p>`:""}${actions?`<div class="toast-actions">${actions}</div>`:""}</div><button class="icon-button" aria-label="Dismiss notification">${icon("x")}</button>`;
    const dismiss=()=>{if(node.classList.contains("dismiss"))return;node.classList.add("dismiss");setTimeout(()=>animateToastLayout(()=>node.remove()),reducedMotion.matches?0:200);};
    $(".icon-button",node).onclick=dismiss;
    // Focus moves into the panel before the toast (and the focused button) goes away, so it never falls to <body>.
    const activity=$(".toast-activity",node);if(activity)activity.onclick=()=>{showActivity(true);$("#activity-title").focus();dismiss();};
    if(extra)$(".toast-primary",node).onclick=()=>{dismiss();Promise.resolve().then(extra.run).catch(()=>{});};
    animateToastLayout(()=>{viewport.prepend(node);while(viewport.children.length>3)viewport.lastChild.remove();});
    let timer=setTimeout(dismiss,level==="error"?12000:extra?9000:5500);
    const pause=()=>clearTimeout(timer),resume=()=>{clearTimeout(timer);if(!node.matches(":hover")&&!node.contains(document.activeElement))timer=setTimeout(dismiss,3000);};
    node.onpointerenter=pause;node.onpointerleave=resume;node.onfocusin=pause;node.onfocusout=resume;
  }
  // rmahammad Animated Dialog's fixed header/body/footer translated to <dialog>.
  // build(FormData) returns [action, params] for the live "Runs:" line and, when submit is null, for the submit itself.
  // app: the app whose hue the dialog takes (default: the one in view); an app with no profiles keeps it neutral.
  // A dialog opened over another keeps the focus target of the first.
  function showDialog(titleText,description,body,submitText,submit,{danger=false,build=null,app=contextApp()}={}){
    clearTimeout(dialogCloseTimer);dialogRevision++;
    if(!dialog.open)lastFocus=document.activeElement;
    dialogBuild=build;dialogSubmit=submit||(async(data,el)=>{const spec=build(data);if(!spec)throw new Error("Nothing has changed yet.");await action(...spec,el);});dialog.classList.remove("closing");
    toneDialog(app);
    const echo=build?`<div class="command-echo" id="command-echo" hidden><span class="command-label">Runs:</span><code></code><button type="button" class="icon-button" data-action="copy-command" aria-label="Copy command" title="Copy command">${icon("copy")}</button></div>`:"";
    dialog.innerHTML=`<form id="dialog-form" class="dialog-inner"><header class="dialog-header"><h2 id="dialog-title">${breakable(titleText)}</h2><p id="dialog-description">${escape(description)}</p><button type="button" class="icon-button" data-close-dialog aria-label="Close dialog">${icon("x")}</button></header><div class="dialog-body">${body}${echo}<div id="form-error" class="form-error" role="alert" tabindex="0" hidden></div></div><footer class="dialog-footer"><p class="dialog-status" role="status"></p><button type="button" class="button" data-close-dialog>Cancel</button><button type="submit" class="button ${danger?"button-danger":"button-primary"}" id="dialog-submit">${escape(submitText)}</button></footer></form>`;
    if(!dialog.open)dialog.showModal();
    hostToasts();
    $("input:not([type=checkbox]):not(:disabled),select,textarea",$(".dialog-body",dialog))?.focus();
    animateMotion($(".dialog-header",dialog),[{opacity:0,translate:"0 5px"},{opacity:1,translate:"0 0"}],"surface",{duration:420,delay:25});
    const form=$("#dialog-form");
    if(build){form.addEventListener("input",()=>schedulePreview());form.addEventListener("change",()=>schedulePreview());schedulePreview(0);}
    form.onsubmit=async event=>{
      event.preventDefault();
      if($("#dialog-submit").hasAttribute("data-locked")){if(offline)showFormError(OFFLINE);return;}
      if(!form.reportValidity())return;
      $("#form-error").hidden=true;$$("[aria-invalid]",form).forEach(el=>el.removeAttribute("aria-invalid"));
      // While it runs the dialog cannot close (closeDialog waits), so Cancel and the close button say so.
      const closers=$$("[data-close-dialog]",dialog);closers.forEach(el=>{el.disabled=true;});
      try{await dialogSubmit(new FormData(form),$("#dialog-submit"));closers.forEach(el=>{el.disabled=false;});closeDialog();}
      catch(error){closers.forEach(el=>{el.disabled=false;});const bad=error.field&&form.elements[error.field];showFormError(error.message,!bad?.setAttribute);if(bad?.setAttribute){bad.setAttribute("aria-invalid","true");bad.focus();}}
    };
  }
  // The error sits at the foot of a body that may be scrolled away: bring it into view, unless focus goes to the field it names.
  function showFormError(message,reveal=true){const box=$("#form-error");box.textContent=message;box.hidden=false;if(reveal)box.scrollIntoView({block:"nearest",behavior:reducedMotion.matches?"instant":"smooth"});}
  // The command comes from the server (/api/preview, redacted); it is never assembled here. An empty required field sends no request; any error hides the line.
  function schedulePreview(delay=250){clearTimeout(previewTimer);previewTimer=setTimeout(runPreview,delay);}
  async function runPreview(){
    const echo=$("#command-echo",dialog),seq=++previewSeq;if(!echo||!dialogBuild)return;
    let spec=null;try{spec=dialogBuild(new FormData($("#dialog-form")));}catch{spec=null;}
    if(!spec||offline||!state?.csrf_token||!$("#dialog-form").checkValidity()){echo.hidden=true;return;}
    try{
      const response=await post("/api/preview",{action:spec[0],...spec[1]});
      const result=await response.json();
      if(seq!==previewSeq||!echo.isConnected)return;
      echo.hidden=!(response.ok&&result.ok&&result.command);
      if(!echo.hidden)$("code",echo).innerHTML=commandHtml(result.command);
    }catch{if(seq===previewSeq&&echo.isConnected)echo.hidden=true;}
  }
  // A modal dialog makes the rest of the page inert, so toasts move inside it while it is open; moving hides the popover, so show it again on top.
  function hostToasts(){const host=dialog.open?dialog:document.body;if(toastViewport.parentElement!==host){host.append(toastViewport);toastViewport.showPopover?.();toastInset();}}
  function closeDialog(){
    if($("#dialog-submit")?.getAttribute("aria-busy")==="true")return;
    if(!dialog.open||dialog.classList.contains("closing"))return;
    const revision=dialogRevision;
    dialog.classList.add("closing");clearTimeout(previewTimer);previewSeq++;
    // The control that opened the dialog may be gone after a re-render; the page heading takes focus instead of <body>.
    dialogCloseTimer=setTimeout(()=>{if(revision!==dialogRevision)return;dialog.close();hostToasts();dialog.innerHTML="";dialogSubmit=null;dialogBuild=null;importDocument=null;(lastFocus?.isConnected?lastFocus:$("h1",main)||main).focus({preventScroll:true});},reducedMotion.matches?0:200);
  }
  const field=(label,name,value="",hint="",type="text",attrs="")=>`<div class="field"><label for="field-${name}">${label}</label><input class="input" id="field-${name}" name="${name}" type="${type}" value="${escape(value)}" ${hint?`aria-describedby="hint-${name}" `:""}${attrs}>${hint?`<p class="hint" id="hint-${name}">${hint}</p>`:""}</div>`;
  const check=(name,label,description="",checked=false)=>`<label class="check-row"><input type="checkbox" name="${name}" ${checked?"checked":""}><span>${label}${description?`<span>${description}</span>`:""}</span></label>`;
  const area=(label,name,hint="",value="")=>`<div class="field"><label for="field-${name}">${label}</label><textarea id="field-${name}" name="${name}" rows="3" spellcheck="false" autocomplete="off"${hint?` aria-describedby="hint-${name}"`:""}>${escape(value)}</textarea>${hint?`<p class="hint" id="hint-${name}">${hint}</p>`:""}</div>`;
  const disclosure=(label,body,open=false)=>`<details class="advanced"${open?" open":""}><summary>${icon("chevron")}<span>${label}</span></summary><div class="fields">${body}</div></details>`;
  // The CLI takes six hex digits or a color word; a leading "#" is dropped here.
  const hexValue=value=>String(value||"").trim().replace(/^#/,"");
  // The CLI's profile-name rule (validate_profile_name): letters, numbers, spaces, hyphens and underscores, 40 at most, no leading hyphen or outer space.
  const NAME_RULE='required maxlength="40" pattern="[A-Za-z0-9_]([A-Za-z0-9 _\\-]*[A-Za-z0-9_\\-])?" title="Letters, numbers, spaces, hyphens and underscores. It cannot start with a hyphen or start or end with a space."';
  // Paint the dialog in the app's hue (its primary button and focus rings), or leave it neutral.
  function toneDialog(app){const color=appAccent(app).color;dialog.classList.toggle("app-tone",Boolean(color));dialog.style.cssText=color?`--app-color:${color}`:"";}
  // Named swatches, the chosen one's name and hex as text, and the hex field behind "Custom color…" (open when the color is not a swatch).
  // data-auto: the hex follows the app's default badge until edited.
  function identityFields(p=null,fallback=defaultBadgeColor){
    const color=String(p?.color||fallback).toUpperCase(),custom=!colors.some(([,hex])=>hex===color);
    return `<div class="field"><p class="field-label" id="badge-color-label">Badge color</p><div class="color-options" role="group" aria-labelledby="badge-color-label">${colors.map(([name,hex])=>`<button type="button" class="color-swatch" style="--swatch:#${hex}" data-color="${hex}" title="${name} · ${hex}" aria-label="${name}" aria-pressed="${color===hex}"></button>`).join("")}</div><div class="color-meta"><span class="color-current">${escape(colorName(color))}</span><button type="button" class="link-button" data-custom-color aria-expanded="${custom}" aria-controls="custom-color">Custom color…</button></div><div id="custom-color"${custom?"":" hidden"}>${field("Hex color","color",color,"Six hex digits, like B26BFF.","text",`maxlength="8" spellcheck="false" autocomplete="off"${p?"":" data-auto"}`)}</div></div>${field("Badge character","badge",p?.badge||"","Shown at the corner of the launcher’s icon.","text",'maxlength="4"')}${check("no_badge","Use the original app icon","Hide the colored badge.",p?.badge===null)}`;
  }
  // "Periwinkle · 7C8CFF" for a swatch, "Custom · 123ABC" for any other valid color (a CLI color word resolves to its hex).
  function colorName(value){
    const raw=hexValue(value).toUpperCase(),hex=wordHex(raw),named=colors.find(([,swatch])=>swatch===hex);
    return named?`${named[0]} · ${hex}`:/^[0-9A-F]{6}$/.test(hex)?`Custom · ${hex}`:"Custom color";
  }
  // Preselect the app the user is looking at: the clicked app, the selected profile's, the filter's, the last one used, then the first.
  function addDialog(app=""){
    if(!state)return;
    const names=sortedApps().map(item=>item.name),known=name=>names.includes(name)?name:"";
    const picked=known(app)||known(contextApp())||known(stored.get("aidentity.last-app"));
    const chosen=picked||names[0]||"";
    const options=names.map(name=>`<option value="${escape(name)}"${name===chosen?" selected":""}>${escape(name)}</option>`).join("");
    const build=data=>{
      const params={app:String(data.get("app_path")||"").trim()||data.get("app"),profile:data.get("profile"),no_badge:data.has("no_badge"),main:data.has("main"),seed:data.has("seed"),args:lines(data.get("args")),env:lines(data.get("env")),own_extensions:data.has("own_extensions")};
      if(data.get("badge")&&!params.no_badge)params.badge=data.get("badge");
      if(hexValue(data.get("color")))params.color=hexValue(data.get("color"));
      return ["add",params];
    };
    showDialog("Add a profile","Each profile opens the app with its own sign-in and data.",`<div class="preview-dock"><div class="preview-row"><div class="preview-identity" id="identity-preview"></div></div></div><div class="fields"><div class="field"><label for="field-app">Application</label><select name="app" id="field-app" required${names.length?"":' aria-describedby="hint-app"'}>${options||'<option value="">No AI apps found</option>'}</select>${names.length?"":'<p class="hint" id="hint-app">Install Claude or ChatGPT and refresh, or give the app’s path below.</p>'}</div>${field("Profile name","profile","","For example Work, Personal or Client. Letters, numbers, spaces, hyphens and underscores.","text",NAME_RULE)}${check("main","Use the original account","Opens the app’s own account. Once a profile runs, the app’s own icon only switches to that profile; this launcher still opens the original.")}${disclosure("Appearance",identityFields(null,badgeDefault(chosen)))}${disclosure("App location & launch settings",`${field("Application path (optional)","app_path","","Use a full .app path for an application outside discovery.","text",'placeholder="/Applications/Example.app"')}<div id="seed-option">${check("seed","Copy Claude’s MCP configuration","Copies the existing Claude Desktop configuration into the new profile.")}</div>${area("Launch arguments","args","One allowed switch per line, for example --lang=de.")}${area("Environment variables","env","One allowed NAME=value per line. Values are never displayed in this dashboard.")}${check("own_extensions","Use a separate extensions folder","For VS Code-style applications.")}`,!names.length)}</div>`,"Add profile",async(data,el)=>{
      const first=!state.profiles.length,result=await action(...build(data),el);
      stored.set("aidentity.last-app",data.get("app"));
      if(view==="apps")dropIntoFolder(result.created,first);else revealProfile(result.created,first);
    },{build,app:chosen});
    setupPreview();
    if(picked)$('[name="profile"]',dialog).focus();
    $('[name="main"]',dialog).onchange=event=>{if(event.target.checked&&!$('[name="profile"]',dialog).value)$('[name="profile"]',dialog).value="Main";setupPreviewUpdate();};
  }
  // After Add: Profiles, the new card selected, scrolled into view, one gentle ring, and focus on its name once the dialog closes.
  function revealProfile(name,first=false){
    query="";statusFilter="all";selected=name||"";if(name)stored.set(LAST_PROFILE,name);
    showView("profiles",{app:"",instant:true});// the card is looked up right after, so the page swaps now
    const target=$$(".profile-name",main).find(el=>el.dataset.name===name);if(!target)return;
    const cardNode=target.closest(".profile-card");
    cardNode.scrollIntoView({block:"center",behavior:reducedMotion.matches?"instant":"smooth"});
    lastFocus=target;
    animateMotion(cardNode,[{outlineOffset:"12px",outlineColor:"transparent"},{outlineOffset:"0px"}],"surface",{duration:900,delay:220});
    // The card's ring closes in while the ground's spreads out from it; the first profile's crosses the whole field.
    setTimeout(()=>ripple(cardNode,first?"far":"near"),220);
  }
  const lines=value=>String(value||"").split(/\r?\n/).map(v=>v.trim()).filter(Boolean);
  function setupPreview(){
    $('[name="color"]',dialog)?.addEventListener("input",event=>event.target.removeAttribute("data-auto"));
    $$('input,select,textarea',dialog).forEach(input=>input.addEventListener("input",setupPreviewUpdate));setupPreviewUpdate();
  }
  // The preview shows what is set: the app alone until a profile name is typed, a badge only once there is one, and the original-account line only when it applies.
  function setupPreviewUpdate(){
    const preview=$("#identity-preview");if(!preview)return;
    const path=String($('[name="app_path"]',dialog)?.value||"").trim();
    const appSelect=$('[name="app"]',dialog);
    if(appSelect)appSelect.required=!path;
    const app=path?path.replace(/\/+$/,"").split("/").pop().replace(/\.app$/i,""):appSelect?.value||preview.dataset.app||"App";
    const nameInput=$('[name="profile"]',dialog),name=nameInput?nameInput.value.trim():preview.dataset.profile||"";
    // Settings (data-quiet) names the profile in its title, so its preview shows no name.
    const label=preview.hasAttribute("data-quiet")?"":name?`${app} ${name}`:app;
    const original=preview.dataset.main==="true"||Boolean($('[name="main"]',dialog)?.checked);
    const colorInput=$('[name="color"]',dialog),badgeInput=$('[name="badge"]',dialog);
    if(colorInput?.hasAttribute("data-auto"))colorInput.value=badgeDefault(app);
    const raw=hexValue(colorInput?.value)||defaultBadgeColor,hex=wordHex(raw);
    $$(".color-swatch",dialog).forEach(el=>el.setAttribute("aria-pressed",el.dataset.color===hex.toUpperCase()));
    const current=$(".color-current",dialog);if(current)current.textContent=colorName(raw);
    if(badgeInput)badgeInput.placeholder=[...name][0]?.toUpperCase()||"";
    const badge=$('[name="no_badge"]',dialog)?.checked?null:badgeInput?.value||[...name][0]?.toUpperCase()||null;
    const seed=$("#seed-option",dialog);
    if(seed){seed.hidden=!/claude/i.test(app);if(seed.hidden)$('[name="seed"]',dialog).checked=false;}
    const color=appAccent(app).color;
    preview.classList.toggle("app-tone",Boolean(color));preview.style.cssText=color?`--app-color:${color}`:"";toneDialog(app);
    preview.innerHTML=art(app,badge,hex)+`<div>${label?`<strong>${breakable(label)}</strong>`:""}${original?'<span class="small">Opens the app’s original account</span>':""}</div>`;
  }
  // Settings sends only what changed: Save and the Runs line wait for a change. Launch arguments are one list, and saving replaces it.
  function settingsDialog(item){
    const args=(item.args||[]).join("\n"),color=String(item.color||defaultBadgeColor).toUpperCase(),env=item.env||[];
    const build=data=>{
      // An empty badge field means the CLI's default, the name's first character, as the preview shows.
      const params={name:item.name},noBadge=data.has("no_badge"),badge=String(data.get("badge")||"")||[...(item.profile||item.name)][0]?.toUpperCase()||"",next=hexValue(data.get("color"));
      if(next&&wordHex(next).toUpperCase()!==color)params.color=next;
      // Checked, --no-badge rides along with a color too: set --color alone adds a letter badge to a badge-less profile.
      if(noBadge&&(item.badge!==null||params.color))params.no_badge=true;
      if(!noBadge&&badge&&badge!==(item.badge||""))params.badge=badge;
      const nextArgs=lines(data.get("args"));
      if(nextArgs.join("\n")!==args){params.clear_args=true;if(nextArgs.length)params.args=nextArgs;}
      if(lines(data.get("env")).length)params.env=lines(data.get("env"));
      if(data.has("clear_env"))params.clear_env=true;
      if(data.get("extensions")==="own"&&!item.own_extensions)params.own_extensions=true;
      if(data.get("extensions")==="shared"&&item.own_extensions)params.shared_extensions=true;
      return Object.keys(params).length>1?["set",params]:null;
    };
    showDialog(`Settings for ${item.name}`,"Launch changes apply the next time it opens.",`<div class="preview-dock"><div class="preview-row"><div class="preview-identity" id="identity-preview" data-app="${escape(appName(item))}" data-profile="${escape(item.profile||"")}" data-quiet data-main="${Boolean(item.main)}"></div></div></div><div class="fields">${identityFields(item)}${disclosure("Launch settings",`${area("Launch arguments","args","One allowed switch per line. Saving replaces the list; empty it to remove them all.",args)}<div class="field"><p class="field-label">Environment variables</p><p class="small">${env.length?`${escape(env.join(", "))} · values stay private`:"None"}</p></div>${area(env.length?"Add or change environment variables":"Add environment variables","env","One allowed NAME=value per line. Values are never shown here.")}${env.length?check("clear_env","Clear the existing variables first","Values entered above are added after clearing."):""}<div class="field"><label for="field-extensions">Extensions folder</label><select id="field-extensions" name="extensions"><option value="shared"${!item.own_extensions?" selected":""}>The app’s default extensions</option><option value="own"${item.own_extensions?" selected":""}>Its own extensions folder</option></select></div>`)}</div>`,"Save settings",async(data,el)=>{
      const spec=build(data);if(!spec)throw new Error("Nothing has changed yet.");
      // The dashboard shows private parts of an argument as [hidden]; saving that text would replace the real value.
      if((spec[1].args||[]).some(arg=>arg.includes("[hidden]")))throw Object.assign(new Error("A launch argument still shows [hidden]. Type its full value again, or remove that line."),{field:"args"});
      await action(...spec,el);
    },{build,app:appName(item)});
    setupPreview();
    const form=$("#dialog-form"),sync=()=>{$("#dialog-submit").disabled=!build(new FormData(form));};
    form.addEventListener("input",sync);form.addEventListener("change",sync);sync();
  }
  function renameDialog(item){
    showDialog(`Rename ${item.name}`,"The name changes; the profile stays signed in.",field("New profile name","new_name",item.profile,"The app name is added by aidentity.","text",NAME_RULE),"Rename profile",async(data,el)=>{
      await action("rename",{name:item.name,new_name:data.get("new_name")},el);
      selected=`${appName(item)} ${data.get("new_name")}`;stored.set(LAST_PROFILE,selected);
      renderView();
    },{build:data=>["rename",{name:item.name,new_name:data.get("new_name")}],app:appName(item)});
  }
  // An original-account profile has no data of its own, so there is nothing to move to the Trash.
  function removeDialog(item){
    const body=item.main?"":check("purge","Also move the profile data to the Trash","Its sign-in and local data leave this workspace."),kept="Its data stays on this Mac, so you can restore it from Recovery.";
    showDialog(`Remove ${item.name}?`,item.main?`This is ${appName(item)}’s original account. aidentity stops opening it; the app and its sign-in stay as they are.`:kept,body,"Remove profile",async(data,el)=>{await action("remove",{name:item.name,purge:data.has("purge"),confirmed:true},el);if(selected===item.name)selected="";},{danger:true,build:data=>["remove",{name:item.name,purge:data.has("purge"),confirmed:true}],app:appName(item)});
    const purge=$('[name="purge"]',dialog);
    if(purge)purge.addEventListener("change",()=>{$("#dialog-submit").textContent=purge.checked?"Remove and move data to Trash":"Remove profile";$("#dialog-description").textContent=purge.checked?"Its data moves to the Trash, so Recovery cannot restore it.":kept;});
  }
  // An app-missing profile cannot be fixed by a rebuild alone: say what to do first, then offer the rebuild.
  function repairDialog(item){
    const app=appName(item);
    showDialog(`Repair ${item.name}`,`${app} is not where this profile expects it.`,`<p class="muted">Reinstall ${escape(app)} or move it back to your Applications folder. Then rebuild the profile so it finds the app again. Its data is not touched.</p>`,"Rebuild",null,{build:()=>["rebuild",{name:item.name}],app});
  }
  const targetList=names=>names.length?`<ul class="target-list">${names.map(name=>`<li>${breakable(name)}</li>`).join("")}</ul>`:"";
  // body is plain text, or empty when the description says it all; extra is trusted HTML built with escape() (target lists).
  function confirmAction(titleText,description,body,submit,name,params={},danger=false,extra=""){
    showDialog(titleText,description,`${body?`<p class="muted">${escape(body)}</p>`:""}${extra}`,submit,null,{danger,build:()=>[name,params]});
  }
  function importDialog(){
    importDocument=null;
    showDialog("Import profiles","Choose a JSON file made by aidentity export.",`<div class="field"><label for="import-file">Export file</label><input class="input file-input" type="file" id="import-file" accept=".json,application/json" aria-describedby="hint-import" required><p class="hint" id="hint-import">Maximum file size: 4 MiB. Sign-ins are not imported.</p></div><div id="import-preview" class="import-preview" hidden></div>`,"Import profiles",async(_,el)=>{
      if(!importDocument)throw new Error("Choose and review a valid aidentity export file first.");
      const result=await action("import",{document:importDocument,confirmed:true},el,{quiet:true});
      const note=describe("import",{},result);toast(note.title,note.text,note.kind);if(note.kind==="ok")ripple(toastViewport.firstElementChild);showView("profiles",{app:""});
    },{build:()=>importDocument?["import",{document:importDocument,confirmed:true}]:null});
    // Instant checks first (size, JSON, format), then the CLI's own plan: its real targets and redacted launch settings, proxies included.
    $("#import-file").onchange=async event=>{
      const input=event.target,preview=$("#import-preview"),submit=$("#dialog-submit");
      importDocument=null;preview.hidden=true;$("#form-error").hidden=true;submit.textContent="Import profiles";submit.disabled=false;
      const file=input.files[0];if(!file)return;
      submit.disabled=true;
      try{
        if(file.size>4194304)throw new Error("The export file is larger than 4 MiB.");
        const data=JSON.parse(await file.text());if(data.aidentity_export!==1||!Array.isArray(data.launchers))throw new Error("Choose a format 1 aidentity export file.");
        preview.hidden=false;preview.innerHTML='<p class="muted" role="status">Checking the file with aidentity…</p>';
        // The file input is locked while the plan loads, so no second file can race this one.
        input.disabled=true;
        const result=await readOutput("import",{document:data,plan:true},null);
        if(!input.isConnected)return;
        importDocument=data;
        preview.innerHTML=`<pre class="output import-plan">${escape(result.stdout||"")}</pre><p class="small">From ${escape(file.name)}.</p>`;
        const creates=result.creates||0;submit.disabled=!(creates>0);submit.textContent=creates>0?`Create ${plural(creates,"profile")}`:"Nothing to create";
        schedulePreview(0);
      }catch(error){if(!input.isConnected)return;importDocument=null;preview.hidden=true;submit.disabled=true;showFormError(error.message);}
      finally{input.disabled=false;if(input.isConnected&&document.activeElement===document.body)input.focus({preventScroll:true});}
    };
  }
  async function exportSetup(el){
    const result=await action("export",{},el,{quiet:true});
    const blob=new Blob([result.stdout],{type:"application/json"});const url=URL.createObjectURL(blob);const link=document.createElement("a");
    link.href=url;link.download="aidentity-profiles.json";document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
    const note=describe("export",{},result);toast(note.title,note.text);
  }
  // Help and completion only print text: they skip the busy lock and Activity, and a failure is a toast.
  async function readOutput(name,params,el){
    if(offline||!state?.csrf_token)throw new Error(OFFLINE);
    setBusy(el,true);
    try{
      let response;
      try{response=await post("/api/action",{action:name,...params});}
      catch{setOffline(true);throw new Error(OFFLINE);}
      const result=await response.json().catch(()=>({ok:false,error:`The dashboard sent an unreadable reply (HTTP ${response.status}).`}));
      if(!response.ok||!result.ok)throw new Error(result.error||result.stderr||`${name} failed (exit ${result.exit_code}).`);
      return result;
    }finally{setBusy(el,false);}
  }
  async function handleAction(name,el){
    const item=profile(el.dataset.name);
    if(name==="workspace")return showView("profiles",{app:"",focus:true});
    if(name==="refresh")return refresh({notify:true,force:true});
    if(name==="add")return addDialog(el.dataset.app);
    if(name==="select"){selected=el.dataset.name;stored.set(LAST_PROFILE,selected);mobileDetail=true;renderNav();renderProfiles();positionTabs();animateMotion($(".detail-panel"),[{opacity:0},{opacity:1}],"surface",{duration:140,easing:"ease-out"});if(mobile.matches)window.scrollTo({top:0,behavior:"instant"});$("#detail-title")?.focus();return;}
    if(name==="close-detail"||name==="back-profiles"){const was=selected;selected="";stored.set(LAST_PROFILE,"");mobileDetail=false;renderNav();renderProfiles();positionTabs();$$(".profile-name",main).find(el=>el.dataset.name===was)?.focus();return;}
    if(name==="clear-search"){query="";renderView();$("#workspace-search")?.focus();return;}
    if(name==="all-apps"){appFilter="";renderView();($("#app-filter")||$("#status-all")||$("h1",main))?.focus();return;}
    if(name==="show-all"){statusFilter="all";renderProfiles();positionTabs();$("#status-all")?.focus();return;}
    if(name==="repair"&&item)return item.status==="app missing"?repairDialog(item):confirmAction(`Repair ${item.name}?`,"Doctor found a problem with how this profile opens.","Rebuild makes it again from its saved settings and the app’s current location. Its data is not touched.","Rebuild","rebuild",{name:item.name});
    if(name==="copy-command"){
      // The plain copy when commandHtml made one (the visible words carry <wbr>), else the text itself.
      const box=el.closest(".command-echo,.connection-banner")?.querySelector("code"),code=box&&($(".sr-only",box)||box).textContent;if(!code)return;
      // The browser can refuse the clipboard (no permission, no user gesture): say so in words, not as a DOMException.
      try{await navigator.clipboard.writeText(code);}catch{toast("Could not copy the command","Select it and press ⌘C instead.",true);return;}
      el.innerHTML=icon("check");el.setAttribute("aria-label","Copied");
      setTimeout(()=>{if(el.isConnected){el.innerHTML=icon("copy");el.setAttribute("aria-label","Copy command");}},1500);return;
    }
    if(name==="reset-filters"){query="";appFilter="";statusFilter="all";renderView();$("#status-all")?.focus();return;}
    if(name==="settings"&&item)return settingsDialog(item);
    if(name==="rename"&&item)return renameDialog(item);
    if(name==="remove"&&item)return removeDialog(item);
    if(name==="open"||name==="quit"||name==="restore"||name==="rebuild")return action(name,{name:el.dataset.name},el);
    if(name==="restore-all")return confirmAction(`Restore ${plural(state.restorable.length,"profile")}?`,"Each gets a new launcher that uses its kept data.","","Restore all","restore",{all:true},false,targetList(state.restorable.map(entry=>entry.name)));
    if(name==="rebuild-all")return confirmAction("Rebuild all launchers?",`Makes ${plural(inventory.profiles.length,"launcher")} again from saved settings. Profile data is not touched.`,"","Rebuild all","rebuild",{all:true});
    if(name==="prune"){
      const names=(state.unclaimed||[]).map(entry=>entry.name);
      // names is the list shown: the server refuses (409) if the unclaimed folders changed since, so only what was approved moves.
      return confirmAction("Clear unclaimed data?",`${plural(names.length,"profile folder")} that no launcher uses will move to the Trash.`,"Restore any you want to keep first.","Clear unclaimed data","prune",{confirmed:true,names},true,targetList(names));
    }
    if(name==="doctor")return action("doctor",{},el);
    if(name==="doctor-fix")return confirmAction("Check and repair the workspace?","Doctor checks your setup, then rebuilds the launchers it can fix.","","Check and repair","doctor",{fix:true});
    if(name==="update-check")return action("update",{check:true},el);
    if(name==="update")return confirmAction("Install the latest aidentity?","aidentity checks the release and its installation before it replaces itself.","","Update aidentity","update",{check:false});
    if(name==="import")return importDialog();
    if(name==="export")return showDialog("Export profiles?","Downloads your profiles’ settings as a JSON file. Sign-ins and profile data stay on this Mac.",`<p class="callout">${icon("alert")}<span>The file can hold private environment or proxy values. Keep it private.</span></p>`,"Export profiles",async(_,submit)=>{await exportSetup(submit);},{build:()=>["export",{}]});
    if(name==="help"||name==="completion"){
      const command=guideCommand=$("#help-command").value,params=name==="help"?(command?{command}:{}):{shell:guideShell=$("#completion-shell").value};
      try{guideText=(await readOutput(name,params,el)).stdout;}
      catch(error){toast(name==="help"?"Could not read the help":"Could not generate completion",error.message===OFFLINE?"":error.message,true);return;}
      // The user may have left Help while it loaded: keep the text for their return, but leave the page they are on alone.
      if(view!=="guide")return;
      // In one column (900px and below) the output sits under the controls: bring its top into view.
      renderGuide();$(`[data-action="${name}"]`,main)?.focus({preventScroll:true});
      const output=$(".guide-output",main);if(output&&output.getBoundingClientRect().top>innerHeight*.6)output.scrollIntoView({block:"start",behavior:reducedMotion.matches?"instant":"smooth"});
      return;
    }
    if(name==="copy-guide"&&guideText){try{await navigator.clipboard.writeText(guideText);}catch{toast("Could not copy the output","Select it and press ⌘C instead.",true);return;}toast("Copied","Command output copied to your clipboard.");}
  }
  // The visible button runs it (from 768px the panel's own copy hides while the selected card is shown), so its spinner and focus return show where the user looks.
  function runPrimary(){
    const el=profileSpot(selected);
    if(el?.hasAttribute("data-locked"))return;
    action("open",{name:selected},el).catch(()=>{});
  }
  // Animated Sidebar adaptation: desktop rail, mobile modal navigation, Cmd+B.
  function closeNavigation(){
    const wasOpen=document.body.classList.contains("mobile-nav-open");
    document.body.classList.remove("mobile-nav-open");$(".main-shell").inert=false;$("#mobile-nav").setAttribute("aria-expanded","false");
    clearTimeout(navCloseTimer);
    if(wasOpen&&!reducedMotion.matches){
      animateMotion($("#nav-scrim"),[{opacity:1},{opacity:0}],"control",{duration:180,easing:"ease-out"});
      navCloseTimer=setTimeout(()=>{if(!document.body.classList.contains("mobile-nav-open"))$("#nav-scrim").hidden=true;},180);
    }else $("#nav-scrim").hidden=true;
    if(matchMedia("(max-width:767px)").matches)$("#sidebar").inert=true;
  }
  function toggleNavigation(){
    if(!matchMedia("(max-width:767px)").matches){
      const oldLeft=main.getBoundingClientRect().left;// on screen, including a slide still in flight
      document.body.classList.toggle("sidebar-collapsed");[main,$(".topbar")].forEach(element=>motionAnimations.get(element)?.cancel());const label=document.body.classList.contains("sidebar-collapsed")?"Expand sidebar":"Collapse sidebar";$("#collapse-nav").setAttribute("aria-label",label);$("#collapse-nav").title=label;
      const delta=oldLeft-main.getBoundingClientRect().left;
      [main,$(".topbar")].forEach(element=>animateMotion(element,[{translate:`${delta}px 0`},{translate:"0 0"}]));
      if(!document.body.classList.contains("sidebar-collapsed"))$$(".nav-label",$("#sidebar")).forEach((element,index)=>animateMotion(element,[{opacity:0,translate:"-5px 0"},{opacity:1,translate:"0 0"}],"control",{delay:Math.min(index,5)*12}));
      return;
    }
    if(document.body.classList.contains("mobile-nav-open")){closeNavigation();$("#mobile-nav").focus();return;}
    clearTimeout(navCloseTimer);
    document.body.classList.add("mobile-nav-open");$(".main-shell").inert=true;$("#nav-scrim").hidden=false;$("#mobile-nav").setAttribute("aria-expanded","true");$("#sidebar").inert=false;$(".brand").focus();
    animateMotion($("#nav-scrim"),[{opacity:0},{opacity:1}],"control",{duration:180,easing:"ease-out"});
  }
  // aria-expanded is the panel's state: while it animates out it is still shown, but already closed.
  function showActivity(open){
    const toggle=$("#activity-toggle");if((toggle.getAttribute("aria-expanded")==="true")===open)return;
    toggle.setAttribute("aria-expanded",String(open));
    present($("#activity-panel"),open,[{opacity:0,translate:"0 10px"},{opacity:1,translate:"0 0"}]);
  }
  document.addEventListener("click",event=>{
    if(event.target.closest("#experience-root"))return;
    const close=event.target.closest("[data-close-dialog]");if(close){closeDialog();return;}
    // A swatch writes the hex field as typing would, so the preview, the Runs line and Save all follow.
    const swatch=event.target.closest("[data-color]");if(swatch){const input=$('[name="color"]',dialog);input.value=swatch.dataset.color;input.dispatchEvent(new Event("input",{bubbles:true}));return;}
    const custom=event.target.closest("[data-custom-color]");if(custom){const open=custom.getAttribute("aria-expanded")!=="true";custom.setAttribute("aria-expanded",String(open));$("#custom-color",dialog).hidden=!open;if(open)$('[name="color"]',dialog).focus();return;}
    // A folder: ··· toggles its menu; a menu item closes the menu, then runs as its plain button would; a file shows its profile
    // on Profiles; a click anywhere else on the folder opens or closes it.
    const fold=event.target.closest(".folder");
    if(fold){
      const file=event.target.closest("[data-folder-file]");
      if(event.target.closest("[role=menuitem]"))closeFolderMenu(true);
      else if(event.target.closest("[data-folder-menu]")){setFolderMenu(fold,$("[data-folder-menu]",fold).getAttribute("aria-expanded")!=="true");return;}
      else if(file){query="";statusFilter="all";stored.set(LAST_PROFILE,file.dataset.name);showView("profiles",{app:"",profile:file.dataset.name,focus:true});return;}
      else if(!event.target.closest("button:not(.gf-hit),.gf-menu")){setFolder(fold,!fold.hasAttribute("data-open"));return;}
    }
    const nav=event.target.closest("[data-view]");if(nav){query="";showView(nav.dataset.view,{focus:true});return;}
    const app=event.target.closest("[data-app-filter]");if(app){query="";statusFilter="all";showView("profiles",{app:app.dataset.appFilter,focus:true});return;}
    const filter=event.target.closest("[data-filter]");if(filter){statusFilter=filter.dataset.filter;keepFocus(renderProfiles);positionTabs();return;}
    const control=event.target.closest("[data-action]");if(control?.hasAttribute("data-locked"))return;if(control)return handleAction(control.dataset.action,control).catch(error=>{if(!error.reported)toast("Could not complete the action",error.message,true);});
    // A click anywhere else on a profile card selects it, as its name does.
    const cardNode=event.target.closest(".profile-card");if(cardNode&&!event.target.closest("a,button,input,select,textarea,summary"))$(".profile-name",cardNode)?.click();
  });
  document.addEventListener("input",event=>{
    if(event.target.id!=="workspace-search")return;query=event.target.value;keepFocus(renderView);
  });
  document.addEventListener("change",event=>{
    if(event.target.id==="app-filter"){appFilter=event.target.value;keepFocus(renderView);}
    if(event.target.id==="help-command")guideCommand=event.target.value;
    if(event.target.id==="completion-shell")guideShell=event.target.value;
  });
  // The selected profile's Details disclosure keeps its state across re-renders (Rebuild launcher lives there).
  document.addEventListener("toggle",event=>{
    if(event.target.matches?.(".detail-more"))detailMore=event.target.open?selected:"";
  },true);
  document.addEventListener("keydown",event=>{
    if(event.metaKey&&event.key.toLowerCase()==="b"){event.preventDefault();toggleNavigation();}
    if(event.key==="Escape"&&document.body.classList.contains("mobile-nav-open")){closeNavigation();$("#mobile-nav").focus();return;}
    if(event.key==="/"&&!event.metaKey&&!event.ctrlKey&&!event.altKey&&!dialog.open&&!event.target.closest?.("input,textarea,select,[contenteditable]")){const search=$("#workspace-search");if(search){event.preventDefault();search.focus();search.select();}}
    // Folder menu: arrows, Home and End move between its items and Tab leaves it closed; Escape closes it, then the open folder.
    const menu=event.target.closest?.(".gf-menu"),items=menu?$$("[role=menuitem]",menu):[];
    if(menu&&["ArrowDown","ArrowUp","Home","End"].includes(event.key)){event.preventDefault();const at=items.indexOf(event.target);items[event.key==="Home"?0:event.key==="End"?items.length-1:(at+(event.key==="ArrowDown"?1:-1)+items.length)%items.length].focus();}
    if(menu&&event.key==="Tab")closeFolderMenu();
    if(event.key==="Escape"&&view==="apps"&&!dialog.open){
      if($('[data-folder-menu][aria-expanded="true"]',main)){event.preventDefault();closeFolderMenu(true);}
      else if(openFolder){const node=$(".folder[data-open]",main);event.preventDefault();setFolder(null,false);if(node)$(".gf-hit",node).focus();}
    }
    if(event.key==="Escape"&&event.target.id==="workspace-search"&&event.target.value){event.preventDefault();event.target.value="";query="";keepFocus(renderView);}
    // O runs the selected profile's primary action (Open or Bring to front) only while focus is inside its card or the detail panel (WCAG 2.1.4).
    if((event.key==="o"||event.key==="O")&&view==="profiles"&&profile(selected)&&!event.metaKey&&!event.ctrlKey&&!event.altKey&&!dialog.open&&!event.target.closest?.("input,textarea,select,[contenteditable]")&&event.target.closest?.(".profile-card.selected,.detail-panel")){event.preventDefault();runPrimary();}
    if(event.key==="Tab"&&document.body.classList.contains("mobile-nav-open")){
      const items=$$("a[href],button:not(:disabled)",$("#sidebar")).filter(el=>el.offsetParent!==null);const first=items[0],last=items.at(-1);
      if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}
    }
    // 21st Animated Tabs keyboard navigation: roving tabIndex, arrows, Home, End.
    if(event.target.matches("[role=tab]")&&["ArrowRight","ArrowLeft","Home","End"].includes(event.key)){
      event.preventDefault();const items=$$("[role=tab]",event.target.parentElement);const index=items.indexOf(event.target);
      const next=event.key==="Home"?0:event.key==="End"?items.length-1:(index+(event.key==="ArrowRight"?1:-1)+items.length)%items.length;
      statusFilter=items[next].dataset.filter;renderProfiles();positionTabs();$(`[data-filter="${statusFilter}"]`)?.focus();
    }
  });
  dialog.addEventListener("cancel",event=>{event.preventDefault();closeDialog();});
  // Chrome lets a dialog block Esc once per user activation, so a second Esc closes it natively: whatever closes it hands the toasts back to the page.
  dialog.addEventListener("close",hostToasts);
  // A click lands on the nearest common ancestor of the press and the release, so a drag that selects text in a field and lets go outside would close the dialog: the press must begin on the backdrop too.
  let pressedBackdrop=false;
  dialog.addEventListener("pointerdown",event=>{pressedBackdrop=event.target===dialog;});
  dialog.addEventListener("click",event=>{if(pressedBackdrop&&event.target===dialog){const rect=dialog.getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)closeDialog();}});
  $("#header-add").onclick=()=>{if(!$("#header-add").hasAttribute("data-locked"))addDialog();};
  $("#refresh").onclick=()=>refresh({force:true,notify:true});
  $("#mobile-nav").onclick=toggleNavigation;
  $("#collapse-nav").onclick=toggleNavigation;
  $("#nav-scrim").onclick=$("#nav-close").onclick=()=>{closeNavigation();$("#mobile-nav").focus();};
  wide.addEventListener("change",()=>{if(view==="profiles"&&state)keepFocus(renderProfiles);});
  $("#activity-toggle").onclick=()=>showActivity($("#activity-toggle").getAttribute("aria-expanded")!=="true");
  $("#activity-close").onclick=()=>showActivity(false);
  reducedMotion.addEventListener("change",()=>{
    if(reducedMotion.matches)document.getAnimations().forEach(animation=>{
      if(animation.effect?.getTiming().iterations===Infinity)animation.cancel();
      else {try{animation.finish();}catch{animation.cancel();}}
    });
  });
  window.addEventListener("resize",positionTabs);
  window.addEventListener("resize",()=>{if(view==="apps"&&state)layoutFolders();});
  // A press outside closes the folder menu, then the open folder (not while a dialog is over the page).
  document.addEventListener("pointerdown",event=>{
    if(view!=="apps"||dialog.open)return;
    if(!event.target.closest?.(".gf-menu,[data-folder-menu]"))closeFolderMenu();
    if(openFolder&&!event.target.closest?.(".folder[data-open]"))setFolder(null,false);
  });
  // A fine pointer leans the folder under it toward itself, and the glass's sheen follows (styles.css gates the tilt the same way).
  const finePointer=matchMedia("(hover:hover) and (pointer:fine)");
  let leaning=null,leanFrame=0;
  const unlean=()=>{cancelAnimationFrame(leanFrame);if(leaning){leaning.style.removeProperty("--px");leaning.style.removeProperty("--py");leaning=null;}};
  main.addEventListener("pointermove",event=>{
    const node=event.target.closest?.(".folder");if(node!==leaning)unlean();
    if(!node||event.pointerType==="touch"||!finePointer.matches||reducedMotion.matches)return;
    const box=node.getBoundingClientRect(),x=(event.clientX-box.left)/box.width*2-1,y=(event.clientY-box.top)/box.height*2-1;leaning=node;
    cancelAnimationFrame(leanFrame);leanFrame=requestAnimationFrame(()=>{node.style.setProperty("--px",x.toFixed(3));node.style.setProperty("--py",y.toFixed(3));});
  });
  main.addEventListener("pointerleave",unlean);
  document.addEventListener("scroll",event=>{if(event.target.classList?.contains("tabs"))tabScroll=event.target.scrollLeft;},{capture:true,passive:true});
  window.addEventListener("hashchange",()=>{const next=location.hash.slice(1);if([...navigation.map(item=>item[0]),"guide"].includes(next))showView(next,{focus:true});});
  const mobile=matchMedia("(max-width:767px)");
  mobile.addEventListener("change",()=>{closeNavigation();$("#sidebar").inert=mobile.matches;});
  $("#sidebar").inert=mobile.matches;
  let quietPolls=0,pollTimer=null;
  function schedulePoll(){clearTimeout(pollTimer);pollTimer=setTimeout(poll,offline?5000:quietPolls>=3?30000:10000);}
  // Only a successful, unchanged read is quiet; a failed or skipped read leaves the back-off where it was.
  async function poll(){if(!document.hidden&&!busy&&(!dialog.open||offline)){const changed=await refresh();if(changed!==null)quietPolls=changed?0:quietPolls+1;}schedulePoll();}
  function wake(){const slow=quietPolls>=3;quietPolls=0;if(slow)schedulePoll();}
  ["click","keydown","focus"].forEach(type=>window.addEventListener(type,wake,true));
  document.addEventListener("visibilitychange",()=>{if(!document.hidden){quietPolls=0;refresh();schedulePoll();}});
  // Re-renders replace buttons; re-apply the busy/offline lock to whatever just appeared.
  new MutationObserver(()=>{if(busy||offline||$("[data-locked]"))syncControls();}).observe(document.body,{childList:true,subtree:true});
  hydrateIcons();renderNav();renderActivity();syncControls();refresh();schedulePoll();
})();
