/* Adapted from sources retrieved through 21st.dev:
 * Perspective Tunnel Hero — daiwiikharihar, demo 39043
 * https://21st.dev/@daiwiikharihar/components/perspective-tunnel-hero
 * Works Wheel — crafterui, demo 28371
 * https://21st.dev/@crafterui/components/works-wheel
 * Retains Works Wheel's 3D drum geometry and spring feedback as a short reel
 * that turns between apps; at rest the focus panel shows the selected app's
 * accounts as a ring of keys. The former tunnel introduction is replaced by
 * real app/account rows; native page scroll selects the app in focus.
 */
(() => {
  "use strict";
  const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
  let warnedHue = false;
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const luminance = hex => [0, 2, 4].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map(c => c <= .04045 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4).reduce((sum, c, i) => sum + c * [.2126, .7152, .0722][i], 0);
  // Same rule as app.js: the badge letter takes Lampblack or white, whichever contrasts more.
  const badgeStyle = profile => {
    const hex = /^[0-9a-f]{6}$/i.test(profile.color || "") ? profile.color : "5FE08A";
    return `--identity:#${hex};--identity-ink:${(luminance(hex) + .05) / (luminance("060606") + .05) >= 1.05 / (luminance(hex) + .05) ? "#060606" : "#ffffff"}`;
  };
  const badgeChar = profile => profile.badge || (profile.profile || profile.name || "A").slice(0, 1);
  // Display labels shared with the Profiles view; the CLI's status strings stay the data.
  const statusLabels = { running: "Running", "in use": "At rest", "not running": "At rest", "signed out / new": "Not opened yet", "app missing": "App missing" };
  const statusLabel = status => statusLabels[status] || status || "Status unavailable";
  const arrow = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M5 12h14m-6-6 6 6-6 6"/></svg>';
  // An analytic damped spring keeps gesture velocity when its target changes.
  // Values are design choices; Apple HIG Motion calls for brief, realistic,
  // interruptible feedback, not a prescribed stiffness or damping.
  class Spring {
    constructor(value, stiffness, damping) {
      this.value = value; this.velocity = 0;
      this.stiffness = stiffness; this.alpha = damping / 2;
    }
    reset(value) { this.value = value; this.velocity = 0; }
    moving(target) {
      return Math.abs(this.value - target) > 0.00005 || Math.abs(this.velocity) > 0.0005;
    }
    step(target, dt) {
      const offset = this.value - target, velocity = this.velocity;
      const alpha = this.alpha, k = this.stiffness, discriminant = k - alpha * alpha;
      const decay = Math.exp(-alpha * dt);
      if (discriminant > 0.00001) {
        const w = Math.sqrt(discriminant), cosine = Math.cos(w * dt), sine = Math.sin(w * dt);
        this.value = target + decay * (offset * cosine + (velocity + alpha * offset) / w * sine);
        this.velocity = decay * (velocity * cosine - (alpha * velocity + k * offset) / w * sine);
      } else if (discriminant < -0.00001) {
        const w = Math.sqrt(-discriminant), r1 = -alpha + w, r2 = -alpha - w;
        const a = (velocity - r2 * offset) / (r1 - r2), b = offset - a;
        const first = a * Math.exp(r1 * dt), second = b * Math.exp(r2 * dt);
        this.value = target + first + second;
        this.velocity = r1 * first + r2 * second;
      } else {
        const remainder = velocity + alpha * offset;
        this.value = target + decay * (offset + remainder * dt);
        this.velocity = decay * (velocity - alpha * remainder * dt);
      }
      if (!this.moving(target)) this.reset(target);
      return this.value;
    }
  }
  // A data refresh remounts Explore in the same task as cleanup. Only that
  // rebuild inherits the chosen app and focused control; a later mount starts fresh.
  let carried = null;

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
    const groups = [...groupsByName.values()].sort((a, b) =>
      a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" }));
    // The eight hues are defined once, as --hue-* tokens in styles.css.
    const rootStyle = getComputedStyle(document.documentElement);
    const palette = ["mint", "periwinkle", "teal", "orange", "pink", "gold", "sky", "violet"]
      .map(hue => rootStyle.getPropertyValue(`--hue-${hue}`).trim() ||
        (warnedHue || console.warn(`--hue-${hue} is missing; Explore falls back to #5fe08a`), warnedHue = true, "#5fe08a"));
    for (let i = 0; i < groups.length; i++) {
      const accent = callbacks.appAccent?.(groups[i].name) || {};
      groups[i].color = /^#[0-9a-f]{6}$/i.test(accent.color || "") ? accent.color : palette[i % palette.length];
      groups[i].secondary = /^#[0-9a-f]{6}$/i.test(accent.secondary || "") ? accent.secondary : palette[(i + 3) % palette.length];
    }
    const accentStyle = group => `--app-color:${group.color};--app-color-secondary:${group.secondary}`;
    for (const group of groups) group.profiles.sort((a, b) =>
      Number(Boolean(b.main)) - Number(Boolean(a.main)) ||
      String(a.profile || a.name).localeCompare(String(b.profile || b.name), undefined, { numeric: true, sensitivity: "base" }));
    const icon = name => typeof callbacks.renderAppIcon === "function"
      ? callbacks.renderAppIcon(name) : `<span aria-hidden="true">${esc([...name][0] || "A")}</span>`;
    const accountCount = count => `${count} ${count === 1 ? "account" : "accounts"}`;
    const runningCount = group => group.profiles.filter(profile => profile.status === "running").length;
    const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");
    const kept = carried; carried = null;
    const keptIndex = kept ? groups.findIndex(group => group.name === kept.app) : -1;
    let reduced = reducedQuery.matches, active = Math.max(0, keptIndex), target = active, frame = 0;
    let disposed = false, isVisible = true, lastFrame = 0, drumR = 0;
    let chosenScrollY = keptIndex >= 0 ? kept.chosenScrollY : null, focusKey = null;
    let wheelPixels = 0, wheelStepTime = 0, wheelEventTime = 0;
    const rotation = new Spring(active, 560, 34);
    const cleanup = [], launching = new Set(), offstage = [];
    // Across a refresh, a key whose account started running lights up once and each change is announced.
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
    const positionHtml = i => `<span aria-hidden="true">${i + 1} / ${groups.length}</span><span class="xp-sr-only">${esc(groups[i].name)}, ${i + 1} of ${groups.length}, ${accountCount(groups[i].profiles.length)}</span>`;
    const listen = (element, event, handler, options) => {
      element.addEventListener(event, handler, options);
      cleanup.push(() => element.removeEventListener(event, handler, options));
    };
    const profileRows = group => group.profiles.map(profile => {
      const index = profiles.indexOf(profile), missing = profile.status === "app missing";
      return `<li class="xp-account">
        <span class="xp-badge" style="${badgeStyle(profile)}" aria-hidden="true">${esc(badgeChar(profile))}</span>
        <div class="xp-account-info"><strong>${esc(profile.profile || profile.name)}</strong><span class="xp-account-status${profile.status === "running" ? " xp-running" : missing ? " xp-missing" : ""}">${esc(statusLabel(profile.status))}${profile.main ? " · Original account" : ""}</span>${missing ? `<span class="xp-help" id="xp-open-help-${index}">Reinstall the app before opening this account.</span>` : ""}</div>
        <div class="xp-account-actions"><button type="button" class="xp-button xp-open" data-xp-run data-xp-open="${index}" aria-label="Open ${esc(profile.name)}"${missing ? ` disabled aria-describedby="xp-open-help-${index}"` : ""}>Open ${arrow}</button><button type="button" class="xp-button xp-manage" data-xp-manage="${index}" aria-label="Manage ${esc(profile.name)}">Manage</button></div>
      </li>`;
    }).join("");
    const face = group => `<span class="xp-face" style="${accentStyle(group)}"><span class="xp-app-icon">${icon(group.name)}</span><span class="xp-face-text"><strong class="xp-card-name">${esc(group.name)}</strong><span class="xp-card-foot">${group.profiles.length ? accountCount(group.profiles.length) + (runningCount(group) ? ` · ${runningCount(group)} running` : "") : "No accounts yet"}</span></span></span>`;
    const keyVerb = profile => launching.has(profile.name) ? "Opening…" : profile.status === "running" ? "Bring to front" : "Open";
    // Accessible names start with the visible text (WCAG 2.5.3 Label in Name).
    const keyLabel = profile => {
      const verb = keyVerb(profile), who = `${profile.profile || profile.name}, ${profile.app || "Unknown app"}`;
      return verb === "Bring to front" ? `${verb}, ${who}` : `${verb.replace("…", "")} ${who}`;
    };
    const keyHtml = profile => {
      const running = profile.status === "running", missing = profile.status === "app missing";
      return `<li class="xp-key${running ? " xp-key-running" : ""}${missing ? " xp-key-missing" : ""}${lit.delete(profile.name) ? " xp-key-lit" : ""}">
        <span class="xp-key-badge" style="${badgeStyle(profile)}" aria-hidden="true">${esc(badgeChar(profile))}</span>
        <strong class="xp-key-name">${esc(profile.profile || profile.name)}</strong>${profile.main ? '<span class="xp-key-tag">Original</span>' : ""}
        <span class="xp-key-state"><span class="xp-key-dot" aria-hidden="true"></span>${esc(statusLabel(profile.status))}</span>
        ${missing ? '<span class="xp-key-reason">Reinstall the app to open it.</span>' : `<button type="button" class="xp-button xp-key-action" data-xp-run data-xp-key="${esc(profile.name)}" aria-label="${esc(keyLabel(profile))}"${launching.has(profile.name) ? ' aria-disabled="true"' : ""}>${keyVerb(profile)}</button>`}
      </li>`;
    };
    root.innerHTML = `<div class="xp-wrap${reduced ? " xp-reduced" : ""}">
      <header class="xp-header"><div><h1>Explore</h1><p>Choose an app. Open an account or add another.</p></div><button type="button" class="xp-button xp-workspace">All profiles ${arrow}</button></header>${errorNotice}
      ${groups.length ? `<div class="xp-layout">
        <aside class="xp-preview" data-xp-preview="${esc(groups[0].name)}" aria-label="Selected app">
          <div class="xp-preview-top"><span>In focus</span><span class="xp-position" aria-live="polite" aria-atomic="true" data-at="${active}">${positionHtml(active)}</span><label class="xp-jump-label"><span class="xp-sr-only">Choose app</span><select class="xp-jump" aria-label="Choose app">${groups.map((group, i) => `<option value="${i}">${esc(group.name)}</option>`).join("")}</select></label></div>
          <div class="xp-frame"><button type="button" class="xp-button xp-prev" aria-label="Previous app">←</button><div class="xp-wheel" aria-hidden="true"><div class="xp-wheel-plane">${groups.map((group, i) => `<div class="xp-wheel-card" data-xp-card="${i}">${face(group)}</div>`).join("")}</div></div><button type="button" class="xp-button xp-next" aria-label="Next app">→</button></div>
          <ul class="xp-keys"></ul><p class="xp-keys-empty" hidden>No accounts yet. Each one you add keeps its own sign-in.</p>
          <div class="xp-preview-bottom"><button type="button" class="xp-button xp-key-add" data-xp-run><span aria-hidden="true">+</span> Add account</button><p class="xp-preview-hint">Scroll here to switch apps.</p></div>
          <p class="xp-sr-only" role="status" data-xp-live></p>
        </aside>
        <div class="xp-app-list" role="region" aria-label="Apps and accounts">
          <span id="xp-select-hint" hidden>Show this app in the preview</span>
          <div class="xp-list-summary"><span>${groups.length} ${groups.length === 1 ? "app" : "apps"}</span><span>${accountCount(profiles.length)}</span></div>
          ${groups.map((group, i) => `<section class="xp-app-group" style="${accentStyle(group)}" data-xp-row="${esc(group.name)}" data-xp-group="${i}" aria-labelledby="xp-app-${i}">
            <header class="xp-app-header"><h2 class="xp-app-heading" aria-labelledby="xp-app-${i}"><button type="button" class="xp-app-select" data-xp-select="${i}" aria-describedby="xp-select-hint" aria-current="${i === 0 ? "true" : "false"}"><span class="xp-list-icon" aria-hidden="true">${icon(group.name)}</span><span><span class="xp-app-name" id="xp-app-${i}">${esc(group.name)}</span><span class="xp-app-meta">${accountCount(group.profiles.length)}${group.installed ? "" : inventoryFailed ? " · Inventory unavailable" : " · App not found"}</span></span></button></h2><button type="button" class="xp-button xp-add" data-xp-run data-xp-add="${i}" aria-label="Add account, ${esc(group.name)}"${group.installed ? "" : ` disabled aria-describedby="xp-add-help-${i}"`}>+ Add account</button></header>
            ${group.installed ? "" : `<p class="xp-help" id="xp-add-help-${i}">${inventoryFailed ? "The app list could not be read." : "Install the app before adding an account."}</p>`}
            ${group.profiles.length ? `<ul class="xp-accounts">${profileRows(group)}</ul>` : '<p class="xp-account-empty">No accounts yet. Add one to get started.</p>'}
            <p class="xp-inline-feedback" role="status" aria-live="polite" hidden></p>
          </section>`).join("")}
        </div>
      </div>` : errorNotice ? "" : `<section class="xp-empty"><h2>No compatible apps found</h2><p>Install a Chromium or Electron app, then add an account.</p><button type="button" class="xp-button xp-primary xp-empty-add" data-xp-run>Add an account ${arrow}</button></section>`}
    </div>`;
    const wrap = root.firstElementChild;
    const preview = root.querySelector(".xp-preview");
    const wheel = root.querySelector(".xp-wheel");
    const plane = root.querySelector(".xp-wheel-plane");
    const cards = [...root.querySelectorAll(".xp-wheel-card")];
    const rows = [...root.querySelectorAll(".xp-app-group")];
    const keys = root.querySelector(".xp-keys"), keysEmpty = root.querySelector(".xp-keys-empty");
    const addKey = root.querySelector(".xp-key-add"), live = root.querySelector("[data-xp-live]");
    const jump = root.querySelector(".xp-jump");
    const prev = root.querySelector(".xp-prev"), next = root.querySelector(".xp-next");
    const position = root.querySelector(".xp-position");
    const selectButtons = [...root.querySelectorAll("[data-xp-select]")];
    const openButtons = [...root.querySelectorAll("[data-xp-open]")];
    // Names, not list indexes, identify a control across a rebuild.
    const controlKey = element => element?.matches?.("button, select") && root.contains(element)
      ? element.dataset.xpKey ? `key|${element.dataset.xpKey}` : element === addKey ? "xp-key-add" : element.getAttribute("aria-label") || `${element.className}|${element.closest("[data-xp-row]")?.dataset.xpRow || ""}` : null;

    function updateSelection() {
      if (!preview) return;
      const group = groups[active];
      preview.dataset.xpPreview = group.name;
      callbacks.focusApp?.(group.name);
      preview.style.setProperty("--app-color", group.color);
      preview.style.setProperty("--app-color-secondary", group.secondary);
      preview.setAttribute("aria-label", `${group.name}, ${accountCount(group.profiles.length)}`);
      // Rewrite only on a real change, so the live region speaks once per app.
      if (position.dataset.at !== String(active)) { position.dataset.at = String(active); position.innerHTML = positionHtml(active); }
      jump.value = String(active);
      block(prev, active === 0);
      block(next, active === groups.length - 1);
      if (keys.dataset.app !== group.name) {
        keys.dataset.app = group.name;
        keys.setAttribute("aria-label", `${group.name} accounts`);
        keys.innerHTML = group.profiles.map(keyHtml).join("");
        keys.hidden = !group.profiles.length; keysEmpty.hidden = !keys.hidden;
      }
      addKey.setAttribute("aria-label", `Add account, ${group.name}`);
      addKey.classList.toggle("xp-key-add-first", !group.profiles.length);
      block(addKey, !group.installed);
      if (group.installed) addKey.removeAttribute("aria-describedby");
      else addKey.setAttribute("aria-describedby", `xp-add-help-${active}`);
      rows.forEach((row, i) => {
        row.classList.toggle("xp-selected", i === active);
        selectButtons[i].setAttribute("aria-current", i === active ? "true" : "false");
      });
    }
    function setActive(index) {
      index = clamp(index, 0, groups.length - 1);
      target = index;
      if (active !== index) {
        active = index; updateSelection();
        if (!reduced) keys.animate({ opacity: [0, 1] }, { duration: 160, easing: "cubic-bezier(.16,1,.3,1)" });
      }
      wake();
    }
    function choose(index, reveal = false) {
      setActive(index);
      // Panel controls change only the selection. A list-row action can reveal
      // that row, while ordinary scrolling outside the panel still selects rows.
      if (reveal) rows[index]?.scrollIntoView({ block: "start", behavior: "auto" });
      chosenScrollY = window.scrollY;
    }
    function focusWheel(event) {
      // Only a hovering fine pointer switches apps here; touch and coarse pointers
      // scroll the page. Preserve browser zoom and horizontal-only gestures. Vertical
      // scrolling belongs to this switcher, including at its bounds; it must not chain to the page.
      if (!finePointer.matches || event.ctrlKey || event.defaultPrevented || !event.deltaY) return;
      // A ring with more keys than fit scrolls natively under the pointer.
      if (keys.contains(event.target) && keys.scrollHeight > keys.clientHeight) return;
      event.preventDefault();
      const now = performance.now();
      const pixels = event.deltaY * (event.deltaMode === 1 ? 16 :
        event.deltaMode === 2 ? preview.clientHeight : 1);
      if (now - wheelEventTime > 180 || Math.sign(pixels) !== Math.sign(wheelPixels)) wheelPixels = 0;
      wheelEventTime = now;
      wheelPixels += pixels;
      if (Math.abs(wheelPixels) >= 48 && now - wheelStepTime >= 120) {
        choose(clamp(active + Math.sign(wheelPixels), 0, groups.length - 1));
        wheelPixels = 0;
        wheelStepTime = now;
      }
    }
    function scrollSelection() {
      // Hold the app while a key has focus, so page scroll never removes the focused key.
      if (!preview || disposed || keys.contains(document.activeElement)) return;
      // Keep an explicit choice when a short final row cannot align at the top.
      // A new native page-scroll position immediately resumes row selection.
      if (chosenScrollY !== null && Math.abs(window.scrollY - chosenScrollY) < 1) return;
      chosenScrollY = null;
      const rect = preview.getBoundingClientRect();
      const anchor = window.innerWidth > 767 ? Math.max(100, rect.top + 94) : 92;
      let index = 0;
      for (let i = 0; i < rows.length; i++) {
        if (rows[i].getBoundingClientRect().top <= anchor) index = i;
        else break;
      }
      const atBottom = window.scrollY > 0 && window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 2;
      if (atBottom) index = rows.length - 1;
      setActive(index);
    }
    function measure() {
      if (!wheel) return;
      // Each face fills the reel; its neighbours sit on the drum, out of view at rest.
      const cardWidth = wheel.clientWidth, cardHeight = wheel.clientHeight;
      drumR = cardHeight * 2.22;
      wheel.style.perspective = `${cardHeight * 6}px`;
      for (const card of cards) {
        card.style.width = `${cardWidth}px`; card.style.height = `${cardHeight}px`;
        card.style.marginLeft = `${-cardWidth / 2}px`; card.style.marginTop = `${-cardHeight / 2}px`;
      }
      scrollSelection(); wake();
    }
    function wake() {
      if (!frame && !disposed && !document.hidden && isVisible && wheel) {
        lastFrame = performance.now();
        frame = requestAnimationFrame(draw);
      }
    }
    function draw(now) {
      frame = 0;
      if (disposed) return;
      const dt = clamp((now - lastFrame) / 1000, 0.001, 0.032);
      lastFrame = now;
      const turn = reduced ? target : rotation.step(target, dt);
      plane.style.transform = reduced ? "none" : `translateZ(${-drumR}px)`;
      for (let i = 0; i < cards.length; i++) {
        const card = cards[i], distance = i - turn, drumDegrees = distance * 40;
        if (reduced) {
          card.style.transform = "none";
          card.style.opacity = i === active ? "1" : "0";
          card.style.visibility = i === active ? "visible" : "hidden";
          offstage[i] = i !== active;
        } else {
          const far = Math.abs(distance) >= 1.6;
          // A card that stays out of view needs no new geometry.
          if (far && offstage[i]) continue;
          offstage[i] = far;
          // Works Wheel source geometry: 40-degree drum steps and translate-Z radius.
          // Its position now means a real app selection.
          card.style.transform = `rotateX(${drumDegrees}deg) translateZ(${drumR}px)`;
          card.style.opacity = String(clamp(1 - Math.abs(distance) * 0.36));
          card.style.visibility = far ? "hidden" : "visible";
        }
        card.style.zIndex = String(Math.round(100 - Math.abs(distance) * 2));
      }
      const moving = !reduced && rotation.moving(target);
      // will-change promotes layers only while the wheel turns.
      wheel.classList.toggle("xp-moving", moving);
      if (moving && !document.hidden && isVisible) frame = requestAnimationFrame(draw);
      else lastFrame = 0;
    }
    async function launch(profile) {
      if (!profile || profile.status === "app missing" || launching.has(profile.name)) return;
      const groupIndex = groups.findIndex(group => group.profiles.includes(profile));
      const feedback = rows[groupIndex]?.querySelector(".xp-inline-feedback");
      if (feedback) { feedback.textContent = ""; feedback.hidden = true; }
      launching.add(profile.name);
      paint(profile);
      try {
        if (typeof callbacks.launchProfile === "function") await callbacks.launchProfile(profile);
        else callbacks.openProfile?.(profile);
      } catch (error) {
        if (!disposed && feedback) {
          feedback.textContent = `Couldn’t open ${profile.profile || profile.name}. ${error?.message || "Try again or use Manage to check the account."}`;
          feedback.hidden = false;
        }
      } finally {
        launching.delete(profile.name);
        if (!disposed) paint(profile);
      }
    }
    // Updates Open buttons in place, so a focused one keeps focus while it launches.
    function paint(profile) {
      const busy = launching.has(profile.name);
      for (const button of openButtons) if (profiles[Number(button.dataset.xpOpen)] === profile) {
        launchingState(button, busy); button.innerHTML = busy ? "Opening…" : `Open ${arrow}`;
      }
      for (const button of keys ? keys.querySelectorAll("[data-xp-key]") : []) if (button.dataset.xpKey === profile.name) {
        launchingState(button, busy); button.textContent = keyVerb(profile); button.setAttribute("aria-label", keyLabel(profile));
      }
    }
    listen(root.querySelector(".xp-workspace"), "click", () => callbacks.showProfiles?.(""));
    const emptyAdd = root.querySelector(".xp-empty-add");
    if (emptyAdd) listen(emptyAdd, "click", () => { if (!blocked(emptyAdd)) callbacks.addProfile?.(""); });
    for (const button of openButtons) listen(button, "click", () => { if (!blocked(button)) launch(profiles[Number(button.dataset.xpOpen)]); });
    root.querySelectorAll("[data-xp-manage]").forEach(button => listen(button, "click", () => callbacks.openProfile?.(profiles[Number(button.dataset.xpManage)])));
    root.querySelectorAll("[data-xp-add]").forEach(button => listen(button, "click", () => { if (!blocked(button)) callbacks.addProfile?.(groups[Number(button.dataset.xpAdd)].name); }));
    if (preview) {
      listen(addKey, "click", () => { if (!blocked(addKey)) callbacks.addProfile?.(groups[active].name); });
      listen(keys, "click", event => {
        const button = event.target.closest("[data-xp-key]");
        if (button && !blocked(button)) launch(profiles.find(profile => profile.name === button.dataset.xpKey));
      });
      listen(prev, "click", () => { if (!blocked(prev)) choose(active - 1); });
      listen(next, "click", () => { if (!blocked(next)) choose(active + 1); });
      listen(jump, "change", () => choose(Number(jump.value)));
      selectButtons.forEach(button => listen(button, "click", () => choose(Number(button.dataset.xpSelect), true)));
      listen(preview, "wheel", focusWheel, { passive: false });
      let scrollFrame = 0;
      listen(window, "scroll", () => {
        if (!scrollFrame) scrollFrame = requestAnimationFrame(() => { scrollFrame = 0; scrollSelection(); });
      }, { passive: true });
      cleanup.push(() => cancelAnimationFrame(scrollFrame));
      listen(document, "visibilitychange", () => {
        if (document.hidden) { cancelAnimationFrame(frame); frame = 0; lastFrame = 0; }
        else wake();
      });
      listen(reducedQuery, "change", () => {
        reduced = reducedQuery.matches;
        wrap.classList.toggle("xp-reduced", reduced);
        rotation.reset(target); wake();
      });
      const resizeObserver = new ResizeObserver(measure);
      resizeObserver.observe(wheel);
      cleanup.push(() => resizeObserver.disconnect());
      const observer = new IntersectionObserver(entries => {
        isVisible = entries[0].isIntersecting;
        if (isVisible) wake();
        else { cancelAnimationFrame(frame); frame = 0; lastFrame = 0; }
      });
      observer.observe(root);
      cleanup.push(() => observer.disconnect());
      updateSelection(); measure(); wake();
      if (changes.length) {
        const timer = setTimeout(() => { live.textContent = `${changes.join(". ")}.`; }, 300);
        cleanup.push(() => clearTimeout(timer));
      }
    }
    // Remember the last focused control in case focus falls to the body before a rebuild.
    listen(root, "focusin", event => { focusKey = controlKey(event.target); });
    listen(root, "focusout", event => { if (event.relatedTarget && !root.contains(event.relatedTarget)) focusKey = null; });
    if (kept?.focus) [...root.querySelectorAll("button, select")]
      .find(element => controlKey(element) === kept.focus)?.focus({ preventScroll: true });
    return () => {
      const focused = document.activeElement;
      carried = { app: groups[active]?.name, chosenScrollY, statuses: Object.fromEntries(profiles.map(profile => [profile.name, profile.status])),
        focus: root.contains(focused) ? controlKey(focused) : !focused || focused === document.body ? focusKey : null };
      queueMicrotask(() => { carried = null; });
      disposed = true; cancelAnimationFrame(frame);
      cleanup.forEach(dispose => dispose());
    };
  }
  window.AidentityExperience = { mount };
})();
