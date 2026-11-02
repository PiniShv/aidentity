/* Explore: the focus panel shows one app's profiles as a ring of keys, which hold every profile action.
 * The list beside it only chooses the app: one row per app, including apps with no profiles yet.
 * A change of app crossfades the app identity in 160ms (a static swap under reduced motion).
 */
(() => {
  "use strict";
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  // The first code point, so an emoji name is not split into a lone surrogate.
  const badgeChar = profile => profile.badge || [...(profile.profile || profile.name || "A")][0];
  // A data refresh remounts Explore in the same task as cleanup. Only that
  // rebuild inherits the chosen app and focused control; a later mount starts fresh.
  let carried = null;
  // The last app chosen on Explore. Storage can throw (disabled or private); the choice then lasts only this page.
  const STORE = "aidentity.explore-app";
  const remembered = () => { try { return localStorage.getItem(STORE); } catch { return null; } };
  const remember = name => { try { localStorage.setItem(STORE, name); } catch { /* not persisted */ } };

  function mount(root, state, callbacks = {}) {
    const profiles = Array.isArray(state.profiles) ? state.profiles : [];
    const discovered = Array.isArray(state.apps) ? state.apps : [];
    // A failed inventory read leaves apps empty; say so instead of "no apps found".
    const errors = Array.isArray(state.errors) ? state.errors : [];
    const errorNotice = errors.length ? `<div class="notice error">${errors.map(esc).join("<br>")}</div>` : "";
    const inventoryFailed = errors.length > 0 && !discovered.length;
    const groupsByName = new Map();
    for (const app of discovered) {
      if (app?.name) groupsByName.set(app.name, { name: app.name, installed: true, profiles: [] });
    }
    for (const profile of profiles) {
      const name = profile.app || "Unknown app";
      if (!groupsByName.has(name)) groupsByName.set(name, { name, installed: false, profiles: [] });
      groupsByName.get(name).profiles.push(profile);
    }
    const runningCount = group => group.profiles.filter(profile => profile.status === "running").length;
    // Apps with profiles first: running ones, then by profile count, then by name.
    const groups = [...groupsByName.values()].sort((a, b) =>
      Math.sign(b.profiles.length) - Math.sign(a.profiles.length) ||
      Math.sign(runningCount(b)) - Math.sign(runningCount(a)) || b.profiles.length - a.profiles.length ||
      a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" }));
    // The navigator, Prev/Next, the counter and the jump select cover every app, in that order.
    const nav = groups;
    // app.js owns the hues and gives none to an app without profiles; such an app renders neutral.
    for (const group of groups) {
      const color = callbacks.appAccent?.(group.name)?.color;
      group.color = /^#[0-9a-f]{6}$/i.test(color || "") ? color : null;
    }
    // initial, not unset: :root defines a default --app-color that a neutral app must not inherit.
    const accentStyle = group => group.color ? `--app-color:${group.color};--app-ink:var(--ground)` : "--app-color:initial;--app-ink:var(--text)";
    for (const group of nav) group.profiles.sort((a, b) =>
      Number(Boolean(b.main)) - Number(Boolean(a.main)) ||
      String(a.profile || a.name).localeCompare(String(b.profile || b.name), undefined, { numeric: true, sensitivity: "base" }));
    const icon = name => typeof callbacks.renderAppIcon === "function"
      ? callbacks.renderAppIcon(name) : `<span aria-hidden="true">${esc([...name][0] || "A")}</span>`;
    // The dashboard's drawn icon set (app.js), so Prev/Next match every other icon.
    const uiIcon = name => callbacks.icon?.(name) ?? "";
    const profileCount = count => `${count} ${count === 1 ? "profile" : "profiles"}`;
    // The badge ink rule is app.js's (callbacks.inkFor): Lampblack or white, whichever contrasts more.
    const badgeStyle = profile => {
      const hex = /^[0-9a-f]{6}$/i.test(profile.color || "") ? profile.color : "5FE08A";
      return `--identity:#${hex};--identity-ink:${callbacks.inkFor(hex)}`;
    };
    // Display labels are app.js's too (callbacks.statusLabel); the CLI's status strings stay the data.
    const statusLabel = status => callbacks.statusLabel?.(status) || "Status unavailable";
    const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    let reduced = reducedQuery.matches;
    const kept = carried; carried = null;
    const keptIndex = kept ? nav.findIndex(group => group.name === kept.app) : -1;
    // A rebuild keeps its app. A fresh mount opens the app last chosen, else the top of the sorted list
    // (an app with a running profile, then the one with the most profiles, then the first by name).
    let active = keptIndex >= 0 ? keptIndex : Math.max(0, nav.findIndex(group => group.name === remembered()));
    let disposed = false, focusKey = null;
    const cleanup = [], launching = new Set();
    // Across a refresh, a key whose profile started running takes its hue edge once and each change is announced.
    const lit = new Set(), changes = [];
    if (kept?.statuses) for (const profile of profiles) {
      const before = kept.statuses[profile.name];
      if (before === undefined || statusLabel(before) === statusLabel(profile.status)) continue;
      if (profile.status === "running") lit.add(profile.name);
      changes.push(`${profile.profile || profile.name}, ${profile.app}: ${statusLabel(profile.status)}`);
    }
    // aria-disabled keeps a control focusable; its handler ignores activation.
    // While the app's busy/offline lock holds a control (data-locked), Explore's own reason is kept for when it lifts.
    const block = (button, off) => button.hasAttribute("data-locked") ? button.setAttribute("data-locked", off ? "own" : "")
      : off ? button.setAttribute("aria-disabled", "true") : button.removeAttribute("aria-disabled");
    // A launching button is the running action, so the app's lock leaves it alone (aria-busy), as it does for its own buttons.
    const launchingState = (button, on) => { block(button, on); if (on) button.setAttribute("aria-busy", "true"); else button.removeAttribute("aria-busy"); };
    const blocked = button => button.getAttribute("aria-disabled") === "true";
    const positionHtml = i => `<span aria-hidden="true">${i + 1} of ${nav.length}</span><span class="xp-sr-only">${esc(nav[i].name)}, ${i + 1} of ${nav.length}, ${profileCount(nav[i].profiles.length)}</span>`;
    const listen = (element, event, handler, options) => {
      element.addEventListener(event, handler, options);
      cleanup.push(() => element.removeEventListener(event, handler, options));
    };
    // A key's one verb: Open, or Bring to front for a running profile.
    const keyVerb = profile => launching.has(profile.name) ? "Opening…" : profile.status === "running" ? "Bring to front" : "Open";
    const who = profile => `${profile.profile || profile.name}, ${profile.app || "Unknown app"}`;
    // Accessible names start with the visible text (WCAG 2.5.3 Label in Name).
    const keyLabel = profile => {
      const verb = keyVerb(profile);
      return verb === "Bring to front" ? `${verb}, ${who(profile)}` : `${verb.replace("…", "")} ${who(profile)}`;
    };
    // One running mark everywhere: a Mint dot and Mint text. Not running carries no dot.
    const runMark = text => `<span class="xp-run"><span class="xp-dot" aria-hidden="true"></span>${text}</span>`;
    const appRunning = group => runningCount(group) ? runMark(`${runningCount(group)} running`) : "";
    const face = group => `<div class="xp-face" style="${accentStyle(group)}"><span class="xp-app-icon" aria-hidden="true">${icon(group.name)}</span><div class="xp-face-text"><h2 class="xp-card-name">${esc(group.name)}</h2><p class="xp-card-foot"><span>${profileCount(group.profiles.length)}</span>${appRunning(group)}</p></div></div>`;
    const keyHtml = profile => {
      const running = profile.status === "running", missing = profile.status === "app missing";
      return `<li class="xp-key${running ? " xp-key-running" : ""}${missing ? " xp-key-missing" : ""}${lit.delete(profile.name) ? " xp-key-lit" : ""}">
        ${profile.badge === null
          ? `<span class="xp-key-badge xp-key-badge-app" aria-hidden="true">${icon(profile.app || "")}</span>`
          : `<span class="xp-key-badge" style="${badgeStyle(profile)}" aria-hidden="true">${esc(badgeChar(profile))}</span>`}
        <strong class="xp-key-name">${esc(profile.profile || profile.name)}</strong>
        <span class="xp-key-state">${running ? runMark("Running") : esc(statusLabel(profile.status))}${profile.main ? " · Original" : ""}</span>
        ${missing ? '<span class="xp-key-reason">Reinstall the app to open it.</span>' : `<button type="button" class="xp-button xp-key-action" data-xp-run data-xp-key="${esc(profile.name)}" aria-label="${esc(keyLabel(profile))}"${launching.has(profile.name) ? ' aria-disabled="true"' : ""}>${keyVerb(profile)}</button>`}
      </li>`;
    };
    const navRow = (group, i) => `<li><button type="button" class="xp-nav-item" data-xp-app="${esc(group.name)}" data-xp-select="${i}" style="${accentStyle(group)}" aria-describedby="xp-select-hint" aria-current="${i === active}"><span class="xp-list-icon" aria-hidden="true">${icon(group.name)}</span><span class="xp-nav-text"><span class="xp-app-name">${esc(group.name)}</span><span class="xp-app-meta"><span>${profileCount(group.profiles.length)}${group.installed ? "" : inventoryFailed ? " · Inventory unavailable" : " · App not found"}</span>${appRunning(group)}</span></span></button></li>`;
    root.innerHTML = `<div class="xp-wrap">
      <header class="xp-header"><span class="tile section-explore" aria-hidden="true">${uiIcon("explore")}</span><div><h1 tabindex="-1">Explore</h1><p>Choose an app. Open a profile or add another.</p></div></header>${errorNotice}
      ${nav.length ? `<div class="xp-layout">
        <section class="xp-preview" data-xp-preview="${esc(nav[active].name)}" aria-label="Selected app">
          <div class="xp-pager"${nav.length > 1 ? "" : " hidden"}><button type="button" class="xp-button xp-prev" aria-label="Previous app">${uiIcon("back")}</button><span class="xp-position" aria-live="polite" aria-atomic="true" data-at="${active}">${positionHtml(active)}</span><button type="button" class="xp-button xp-next" aria-label="Next app">${uiIcon("arrow")}</button><label class="xp-jump-label"><span class="xp-sr-only">Choose app</span><select class="xp-jump" aria-label="Choose app">${nav.map((group, i) => `<option value="${i}">${esc(group.name)}</option>`).join("")}</select></label></div>
          <div class="xp-ident">${face(nav[active])}</div>
          <ul class="xp-keys"></ul>
          <div class="xp-empty" data-xp-none hidden><p></p></div>
          <p class="xp-inline-feedback" role="status" aria-live="polite" hidden></p>
          <button type="button" class="xp-button xp-key-add" data-xp-run>${uiIcon("plus")}Add profile</button>
          <p class="xp-help" id="xp-add-help" hidden></p>
          <p class="xp-sr-only" role="status" data-xp-live></p>
        </section>
        <div class="xp-app-list" role="region" aria-label="Apps">
          <span id="xp-select-hint" hidden>Shows this app's profiles</span>
          <div class="xp-list-summary"><span>${nav.length} ${nav.length === 1 ? "app" : "apps"}</span><span>${profileCount(profiles.length)}</span></div>
          <ul class="xp-nav">${nav.map(navRow).join("")}</ul>
        </div>
      </div>` : errorNotice ? "" : `<section class="xp-empty"><h2>No AI apps found</h2><p>Install Claude or ChatGPT, then refresh this workspace.</p><button type="button" class="xp-button xp-primary xp-empty-add" data-xp-run>Add profile ${uiIcon("arrow")}</button></section>`}
    </div>`;
    const preview = root.querySelector(".xp-preview"), ident = root.querySelector(".xp-ident");
    const keys = root.querySelector(".xp-keys"), feedback = root.querySelector(".xp-inline-feedback");
    const none = root.querySelector("[data-xp-none]");
    const addKey = root.querySelector(".xp-key-add"), addHelp = root.querySelector("#xp-add-help"), live = root.querySelector("[data-xp-live]");
    const jump = root.querySelector(".xp-jump");
    const prev = root.querySelector(".xp-prev"), next = root.querySelector(".xp-next");
    const position = root.querySelector(".xp-position");
    const navButtons = [...root.querySelectorAll("[data-xp-select]")];
    // Names, not list indexes or labels that change with status, identify a control across a rebuild.
    const controlKey = element => element?.matches?.("button, select") && root.contains(element)
      ? element.dataset.xpKey ? `key|${element.dataset.xpKey}` : element.dataset.xpApp ? `app|${element.dataset.xpApp}` : element === addKey ? "xp-key-add" : element.getAttribute("aria-label") || element.className : null;
    // place: the control's app; that app's navigator row takes focus if the control is gone after a rebuild.
    const focusMark = element => {
      const key = controlKey(element);
      return key ? { key, place: element.dataset.xpApp ?? (preview?.contains(element) ? nav[active].name : undefined) } : null;
    };

    function updateSelection() {
      const group = nav[active];
      preview.dataset.xpPreview = group.name;
      callbacks.focusApp?.(group.name);
      preview.setAttribute("style", accentStyle(group));
      preview.setAttribute("aria-label", `${group.name}, ${profileCount(group.profiles.length)}`);
      // Rewrite only on a real change, so the live region speaks once per app.
      if (position.dataset.at !== String(active)) { position.dataset.at = String(active); position.innerHTML = positionHtml(active); }
      jump.value = String(active);
      block(prev, active === 0);
      block(next, active === nav.length - 1);
      if (keys.dataset.app !== group.name) {
        keys.dataset.app = group.name;
        keys.setAttribute("aria-label", `${group.name} profiles`);
        keys.innerHTML = group.profiles.map(keyHtml).join("");
        // An app with no profiles yet shows the empty-state words instead of an empty ring.
        keys.hidden = !group.profiles.length; none.hidden = !keys.hidden;
        none.firstElementChild.textContent = `No ${group.name} profiles yet. Each profile keeps its own sign-in. Add the first one below.`;
      }
      addKey.setAttribute("aria-label", `Add profile, ${group.name}`);
      block(addKey, !group.installed);
      addHelp.textContent = inventoryFailed ? "The app list could not be read." : "Install the app before adding a profile.";
      addHelp.hidden = group.installed;
      if (group.installed) addKey.removeAttribute("aria-describedby");
      else addKey.setAttribute("aria-describedby", "xp-add-help");
      navButtons.forEach((button, i) => button.setAttribute("aria-current", String(i === active)));
    }
    // The app identity crossfades in one grid cell; under reduced motion it swaps in place.
    function swapIdentity(group) {
      while (ident.children.length > 1) ident.firstElementChild.remove();
      const old = ident.firstElementChild;
      ident.insertAdjacentHTML("beforeend", face(group));
      if (reduced) { old.remove(); return; }
      old.setAttribute("aria-hidden", "true"); old.inert = true;
      const timing = { duration: 160, easing: "cubic-bezier(.16,1,.3,1)" };
      old.animate({ opacity: [1, 0] }, { ...timing, fill: "forwards" }).onfinish = () => old.remove();
      ident.lastElementChild.animate({ opacity: [0, 1] }, timing);
    }
    // The only ways to change the app: the select, Prev/Next and a navigator row. Each is remembered.
    function choose(index) {
      index = Math.min(nav.length - 1, Math.max(0, index));
      if (index !== active) {
        active = index;
        swapIdentity(nav[active]); updateSelection();
        feedback.hidden = true;
        if (!reduced) keys.animate({ opacity: [0, 1] }, { duration: 160, easing: "cubic-bezier(.16,1,.3,1)" });
      }
      remember(nav[active].name);
    }
    // The panel stays in view only while it fits above the 40px activity bar; a taller one scrolls with the page.
    const fitSticky = () => preview.classList.toggle("xp-tall", preview.offsetHeight > window.innerHeight - 24 - 40 - 16);
    async function launch(profile) {
      if (!profile || profile.status === "app missing" || launching.has(profile.name)) return;
      feedback.textContent = ""; feedback.hidden = true;
      launching.add(profile.name);
      paint(profile);
      try {
        await callbacks.launchProfile(profile);
      } catch (error) {
        if (!disposed) {
          feedback.textContent = `Couldn’t open ${profile.profile || profile.name}. ${error?.message || "Try again, or check the profile on Profiles."}`;
          feedback.hidden = false;
        }
      } finally {
        launching.delete(profile.name);
        if (!disposed) paint(profile);
      }
    }
    // Updates a profile's key button in place, so a focused one keeps focus while it launches.
    function paint(profile) {
      for (const button of keys.querySelectorAll("[data-xp-key]")) {
        if (button.dataset.xpKey !== profile.name) continue;
        launchingState(button, launching.has(profile.name)); button.textContent = keyVerb(profile); button.setAttribute("aria-label", keyLabel(profile));
      }
    }
    const emptyAdd = root.querySelector(".xp-empty-add");
    if (emptyAdd) listen(emptyAdd, "click", () => { if (!blocked(emptyAdd)) callbacks.addProfile?.(""); });
    if (preview) {
      listen(addKey, "click", () => { if (!blocked(addKey)) callbacks.addProfile?.(nav[active].name); });
      listen(keys, "click", event => {
        const button = event.target.closest("[data-xp-key]");
        if (button && !blocked(button)) launch(profiles.find(profile => profile.name === button.dataset.xpKey));
      });
      listen(prev, "click", () => { if (!blocked(prev)) choose(active - 1); });
      listen(next, "click", () => { if (!blocked(next)) choose(active + 1); });
      listen(jump, "change", () => choose(Number(jump.value)));
      navButtons.forEach(button => listen(button, "click", () => {
        choose(Number(button.dataset.xpSelect));
        // A row shows its app in the panel, so bring the panel back if it scrolled away (the stacked mobile layout).
        if (preview.getBoundingClientRect().top < 0) preview.scrollIntoView({ block: "start" });
      }));
      listen(window, "resize", fitSticky);
      listen(reducedQuery, "change", () => { reduced = reducedQuery.matches; });
      const resizeObserver = new ResizeObserver(fitSticky);
      resizeObserver.observe(preview);
      cleanup.push(() => resizeObserver.disconnect());
      updateSelection();
      if (changes.length) {
        const timer = setTimeout(() => { live.textContent = `${changes.join(". ")}.`; }, 300);
        cleanup.push(() => clearTimeout(timer));
      }
    }
    // Remember the last focused control in case focus falls to the body before a rebuild.
    listen(root, "focusin", event => { focusKey = focusMark(event.target); });
    listen(root, "focusout", event => { if (event.relatedTarget && !root.contains(event.relatedTarget)) focusKey = null; });
    if (kept?.focus) ([...root.querySelectorAll("button, select")].find(element => !element.disabled && element.getClientRects().length && controlKey(element) === kept.focus.key)
      || navButtons.find(button => button.dataset.xpApp === kept.focus.place) || root.querySelector("h1"))?.focus({ preventScroll: true });
    return () => {
      const focused = document.activeElement;
      carried = { app: nav[active]?.name, statuses: Object.fromEntries(profiles.map(profile => [profile.name, profile.status])),
        focus: root.contains(focused) ? focusMark(focused) : !focused || focused === document.body ? focusKey : null };
      queueMicrotask(() => { carried = null; });
      disposed = true;
      cleanup.forEach(dispose => dispose());
    };
  }
  window.AidentityExperience = { mount };
})();

/* The ambient ground: a slow field of Bone glyphs behind the whole dashboard, adapted from 21st.dev's
 * Background ASCII Dither (nikolas-sapa) in its ascii mode. At most 30fps, paused while the tab is hidden,
 * one still frame under reduced motion, nothing at all under increased contrast or forced colours.
 */
(() => {
  "use strict";
  // Every glyph is Bone at 12% on Lampblack (#222), where Muted text keeps 4.6:1; 0.13 leaves 4.50:1, no margin, so 0.12 is the ceiling.
  const INK_MAX = 0.12;
  const RAMP = " .:-=+*#%@", CELL = 14, RADIUS = 140, FRAME_MS = 33, AWAY = -1e4;
  const noise = (x, y, t) => (Math.sin(x * 1.7 + t * 0.6) + Math.sin(y * 2.3 - t * 0.4) +
    Math.sin((x + y) * 1.1 + t * 0.25) + Math.sin(Math.hypot(x - 6, y - 4) * 1.9 - t * 0.7)) / 8 + 0.5;

  function start() {
    const canvas = document.querySelector("canvas.ambient");
    const ctx = canvas?.getContext("2d");
    if (!ctx) return;
    const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const plainQuery = window.matchMedia("(prefers-contrast: more), (forced-colors: active)");
    const target = { x: AWAY, y: AWAY }, cursor = { x: AWAY, y: AWAY };
    const atlas = document.createElement("canvas");
    let width = 0, height = 0, dpr = 1, cellPx = 0, t = 0, last = 0, frame = 0, resizeTimer = 0;

    // Setting a bitmap size resets its context to the identity transform, so the glyph atlas is rebuilt here (dpr and ink can change).
    function size() {
      dpr = Math.min(2, window.devicePixelRatio || 1);
      width = canvas.clientWidth; height = canvas.clientHeight;
      canvas.width = Math.round(width * dpr); canvas.height = Math.round(height * dpr);
      // One cell per ramp glyph, drawn once at full alpha: draw() blits them instead of calling fillText per cell.
      cellPx = Math.round(CELL * dpr);
      atlas.width = cellPx * RAMP.length; atlas.height = cellPx;
      const a = atlas.getContext("2d"), mono = getComputedStyle(document.documentElement).getPropertyValue("--font-mono").trim() || "ui-monospace, monospace";
      a.scale(cellPx / CELL, cellPx / CELL);
      a.font = `${CELL * 0.85}px ${mono}`; a.textAlign = "center"; a.textBaseline = "middle";
      a.fillStyle = getComputedStyle(canvas).color;
      [...RAMP].forEach((ch, i) => a.fillText(ch, i * CELL + CELL / 2, CELL / 2));
    }
    function draw(react) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.globalAlpha = INK_MAX; // flat ink: brightness comes from glyph density
      const r2 = RADIUS * RADIUS, cols = Math.ceil(width / CELL), rows = Math.ceil(height / CELL);
      for (let gy = 0; gy < rows; gy++) for (let gx = 0; gx < cols; gx++) {
        const x = gx * CELL + CELL / 2, y = gy * CELL + CELL / 2;
        let lum = noise(gx * 0.35 + t * 0.22, gy * 0.35, t);
        if (react) {
          const d2 = (x - cursor.x) ** 2 + (y - cursor.y) ** 2;
          if (d2 < r2 * 4) lum = Math.min(1, lum + Math.exp(-d2 / r2) * 0.7);
        }
        const glyph = Math.floor(lum * (RAMP.length - 1));
        // 1:1 at whole device pixels, so a fractional dpr never resamples the glyph; 0 is the blank.
        if (glyph) ctx.drawImage(atlas, glyph * cellPx, 0, cellPx, cellPx, Math.round(gx * CELL * dpr), Math.round(gy * CELL * dpr), cellPx, cellPx);
      }
    }
    function tick(now) {
      frame = requestAnimationFrame(tick);
      if (now - last < FRAME_MS) return;
      last = now; t += 0.028;
      cursor.x += (target.x - cursor.x) * 0.12; cursor.y += (target.y - cursor.y) * 0.12;
      draw(true);
    }
    const stop = () => { cancelAnimationFrame(frame); frame = 0; };
    // Each preference picks one mode: nothing (the CSS hides the canvas), one still frame, or the loop while visible.
    function run() {
      stop();
      if (plainQuery.matches) return;
      size();
      if (reducedQuery.matches) draw(false);
      else if (!document.hidden) frame = requestAnimationFrame(tick);
    }
    // The canvas takes no pointer events, so the window reports the pointer.
    window.addEventListener("pointermove", event => {
      if (target.x === AWAY) { cursor.x = event.clientX; cursor.y = event.clientY; } // enter at the pointer, not from offscreen
      target.x = event.clientX; target.y = event.clientY;
    }, { passive: true });
    const leave = () => { target.x = target.y = AWAY; };
    document.documentElement.addEventListener("pointerleave", leave);
    window.addEventListener("blur", leave);
    window.addEventListener("resize", () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(run, 150); });
    document.addEventListener("visibilitychange", () => { if (document.hidden) stop(); else run(); });
    reducedQuery.addEventListener("change", run);
    plainQuery.addEventListener("change", run);
    run();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
