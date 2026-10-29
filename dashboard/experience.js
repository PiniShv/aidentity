/* Adapted from sources retrieved through 21st.dev:
 * Perspective Tunnel Hero — daiwiikharihar, demo 39043
 * https://21st.dev/@daiwiikharihar/components/perspective-tunnel-hero
 * Works Wheel — crafterui, demo 28371
 * https://21st.dev/@crafterui/components/works-wheel
 * Retains Works Wheel's 3D drum/bow geometry and spring feedback. The former
 * tunnel introduction is replaced by real app/account rows; native page scroll
 * selects the app shown in depth. The focus panel switches apps independently.
 */
(() => {
  "use strict";
  const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
  const rad = degrees => degrees * Math.PI / 180;
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const profileColor = value => /^[0-9a-f]{6}$/i.test(value || "") ? `#${value}` : "var(--accent)";
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
    const palette = ["#5fe08a", "#7c8cff", "#2fd4c0", "#ff8a3d", "#ff6fb5", "#ffd166", "#4cc3ff", "#b26bff"];
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
    const firstRunnable = group => group.profiles.find(profile => profile.status !== "app missing");
    const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const kept = carried; carried = null;
    const keptIndex = kept ? groups.findIndex(group => group.name === kept.app) : -1;
    let reduced = reducedQuery.matches, active = Math.max(0, keptIndex), target = active, frame = 0;
    let disposed = false, isVisible = true, lastFrame = 0, drumR = 0, bow = 0;
    let chosenScrollY = keptIndex >= 0 ? kept.chosenScrollY : null, focusKey = null;
    let wheelPixels = 0, wheelStepTime = 0, wheelEventTime = 0;
    const rotation = new Spring(active, 380, 26);
    const cleanup = [], launching = new Set();
    const listen = (element, event, handler, options) => {
      element.addEventListener(event, handler, options);
      cleanup.push(() => element.removeEventListener(event, handler, options));
    };
    const profileRows = group => group.profiles.map(profile => {
      const index = profiles.indexOf(profile), missing = profile.status === "app missing";
      return `<li class="xp-account">
        <span class="xp-badge" style="--identity:${profileColor(profile.color)}" aria-hidden="true">${esc(profile.badge || (profile.profile || profile.name || "A").slice(0, 1))}</span>
        <div class="xp-account-info"><strong>${esc(profile.profile || profile.name)}</strong><span class="xp-account-status${profile.status === "running" ? " xp-running" : missing ? " xp-missing" : ""}">${esc(profile.status || "Status unavailable")}${profile.main ? " · Original account" : ""}</span></div>
        <div class="xp-account-actions"><button type="button" class="xp-button xp-open" data-xp-open="${index}" aria-label="Open ${esc(profile.name)}"${missing ? ' disabled title="Reinstall the app before opening this account"' : ""}>Open ${arrow}</button><button type="button" class="xp-button xp-manage" data-xp-manage="${index}" aria-label="Manage ${esc(profile.name)}">Manage</button></div>
      </li>`;
    }).join("");
    const face = group => `<span class="xp-face" style="${accentStyle(group)}"><span class="xp-card-top"><span class="xp-app-icon">${icon(group.name)}</span><span class="xp-card-count">${accountCount(group.profiles.length)}</span></span><strong class="xp-card-name">${esc(group.name)}</strong><span class="xp-card-foot">${group.profiles.length ? `${group.profiles.filter(profile => profile.status === "running").length} running` : "Ready for your first account"}</span></span>`;
    root.innerHTML = `<div class="xp-wrap${reduced ? " xp-reduced" : ""}">
      <header class="xp-header"><div><h1>Explore</h1><p>Choose an app. Open an account or add another.</p></div><button type="button" class="xp-button xp-workspace">All profiles ${arrow}</button></header>${errorNotice}
      ${groups.length ? `<div class="xp-layout">
        <aside class="xp-preview" data-xp-preview="${esc(groups[0].name)}" aria-label="Selected app preview">
          <div class="xp-preview-top"><span>In focus</span><span class="xp-position">1 / ${groups.length}</span></div>
          <div class="xp-wheel" aria-hidden="true"><div class="xp-wheel-plane">${groups.map((group, i) => `<div class="xp-wheel-card" data-xp-card="${i}">${face(group)}</div>`).join("")}</div></div>
          <div class="xp-preview-bottom"><button type="button" class="xp-button xp-primary"></button><div class="xp-navigation"><button type="button" class="xp-button xp-prev" aria-label="Previous app">←</button><label class="xp-jump-label"><span class="xp-sr-only">Choose app</span><select class="xp-jump" aria-label="Choose app">${groups.map((group, i) => `<option value="${i}">${esc(group.name)}</option>`).join("")}</select></label><button type="button" class="xp-button xp-next" aria-label="Next app">→</button></div></div>
          <p class="xp-preview-hint">Scroll here to switch apps.</p>
        </aside>
        <div class="xp-app-list" aria-label="Apps and accounts">
          <div class="xp-list-summary"><span>${groups.length} ${groups.length === 1 ? "app" : "apps"}</span><span>${accountCount(profiles.length)}</span></div>
          ${groups.map((group, i) => `<section class="xp-app-group" style="${accentStyle(group)}" data-xp-row="${esc(group.name)}" data-xp-group="${i}" aria-labelledby="xp-app-${i}">
            <header class="xp-app-header"><button type="button" class="xp-app-select" data-xp-select="${i}" aria-label="Preview ${esc(group.name)}" aria-current="${i === 0 ? "true" : "false"}"><span class="xp-list-icon" aria-hidden="true">${icon(group.name)}</span><span><h2 id="xp-app-${i}">${esc(group.name)}</h2><span class="xp-app-meta">${accountCount(group.profiles.length)}${group.installed ? "" : inventoryFailed ? " · Inventory unavailable" : " · App not found"}</span></span></button><button type="button" class="xp-button xp-add" data-xp-add="${i}"${group.installed ? "" : ` disabled title="${inventoryFailed ? "The app list could not be read" : "Install the app before adding an account"}"`}>+ Add account</button></header>
            ${group.profiles.length ? `<ul class="xp-accounts">${profileRows(group)}</ul>` : '<p class="xp-account-empty">No accounts yet. Add one to get started.</p>'}
            <p class="xp-inline-feedback" role="status" aria-live="polite" hidden></p>
          </section>`).join("")}
        </div>
      </div>` : errorNotice ? "" : `<section class="xp-empty"><h2>No compatible apps found</h2><p>Install a Chromium or Electron app, then add an account.</p><button type="button" class="xp-button xp-primary xp-empty-add">Add an account ${arrow}</button></section>`}
    </div>`;
    const wrap = root.firstElementChild;
    const preview = root.querySelector(".xp-preview");
    const wheel = root.querySelector(".xp-wheel");
    const plane = root.querySelector(".xp-wheel-plane");
    const cards = [...root.querySelectorAll(".xp-wheel-card")];
    const rows = [...root.querySelectorAll(".xp-app-group")];
    const primary = root.querySelector(".xp-preview .xp-primary");
    const jump = root.querySelector(".xp-jump");
    const prev = root.querySelector(".xp-prev"), next = root.querySelector(".xp-next");
    const position = root.querySelector(".xp-position");
    const selectButtons = [...root.querySelectorAll("[data-xp-select]")];
    const openButtons = [...root.querySelectorAll("[data-xp-open]")];
    // Names, not list indexes, identify a control across a rebuild.
    const controlKey = element => element?.matches?.("button, select") && root.contains(element)
      ? element.getAttribute("aria-label") || `${element.className}|${element.closest("[data-xp-row]")?.dataset.xpRow || ""}` : null;

    function updateSelection() {
      if (!preview) return;
      const group = groups[active], runnable = firstRunnable(group);
      preview.dataset.xpPreview = group.name;
      preview.style.setProperty("--app-color", group.color);
      preview.style.setProperty("--app-color-secondary", group.secondary);
      preview.setAttribute("aria-label", `${group.name} preview, ${accountCount(group.profiles.length)}`);
      position.textContent = `${active + 1} / ${groups.length}`;
      jump.value = String(active);
      prev.disabled = active === 0;
      next.disabled = active === groups.length - 1;
      if (group.profiles.length > 1 && runnable) {
        primary.textContent = "Choose account";
        primary.setAttribute("aria-label", `Choose an account for ${group.name}`);
        primary.disabled = false;
      } else if (runnable) {
        primary.textContent = launching.has(runnable.name) ? "Opening…" : `Open ${runnable.profile || runnable.name}`;
        primary.setAttribute("aria-label", `Open ${runnable.name}`);
        primary.disabled = launching.has(runnable.name);
      } else {
        primary.textContent = group.profiles.length ? "Manage accounts" : "Add account";
        primary.setAttribute("aria-label", `${group.profiles.length ? "Manage accounts for" : "Add account to"} ${group.name}`);
        primary.disabled = !group.profiles.length && !group.installed;
      }
      rows.forEach((row, i) => {
        row.classList.toggle("xp-selected", i === active);
        selectButtons[i].setAttribute("aria-current", i === active ? "true" : "false");
        // Preview artwork carries no tab stops. The stable native controls below it
        // keep keyboard focus even when scroll changes the displayed app.
        cards[i].style.pointerEvents = i === active ? "auto" : "none";
      });
    }
    function setActive(index) {
      index = clamp(index, 0, groups.length - 1);
      target = index;
      if (active !== index) { active = index; updateSelection(); }
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
      // Preserve browser zoom and horizontal-only gestures. Vertical scrolling belongs
      // to this switcher, including at its bounds; it must not chain to the page.
      if (event.ctrlKey || event.defaultPrevented || !event.deltaY) return;
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
      if (!preview || disposed) return;
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
      const cardWidth = Math.min(wheel.clientWidth * 0.72, window.innerWidth <= 767 ? 164 : 238);
      const cardHeight = cardWidth / 1.45;
      drumR = cardHeight * 2.22; bow = cardHeight * 1.82;
      wheel.style.perspective = `${cardHeight * 2.7}px`;
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
        } else {
          // Works Wheel source geometry: bowed X position, 40-degree drum steps,
          // and translate-Z radius. Its position now means a real app selection.
          card.style.transform = `translateX(${-bow * (1 - Math.cos(rad(drumDegrees)))}px) rotateX(${drumDegrees}deg) translateZ(${drumR}px)`;
          card.style.opacity = String(clamp(1 - Math.abs(distance) * 0.36));
          card.style.visibility = Math.abs(distance) < 1.6 ? "visible" : "hidden";
        }
        card.style.zIndex = String(Math.round(100 - Math.abs(distance) * 2));
      }
      if (!reduced && rotation.moving(target) && !document.hidden && isVisible) frame = requestAnimationFrame(draw);
      else lastFrame = 0;
    }
    async function launch(profile) {
      if (!profile || profile.status === "app missing" || launching.has(profile.name)) return;
      const groupIndex = groups.findIndex(group => group.profiles.includes(profile));
      const feedback = rows[groupIndex]?.querySelector(".xp-inline-feedback");
      if (feedback) { feedback.textContent = ""; feedback.hidden = true; }
      launching.add(profile.name);
      for (const button of openButtons) if (profiles[Number(button.dataset.xpOpen)] === profile) {
        button.disabled = true; button.textContent = "Opening…";
      }
      updateSelection();
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
        if (!disposed) {
          for (const button of openButtons) if (profiles[Number(button.dataset.xpOpen)] === profile) {
            button.disabled = false; button.innerHTML = `Open ${arrow}`;
          }
          updateSelection();
        }
      }
    }
    listen(root.querySelector(".xp-workspace"), "click", () => callbacks.showProfiles?.(""));
    const emptyAdd = root.querySelector(".xp-empty-add");
    if (emptyAdd) listen(emptyAdd, "click", () => callbacks.addProfile?.(""));
    for (const button of openButtons) listen(button, "click", () => launch(profiles[Number(button.dataset.xpOpen)]));
    root.querySelectorAll("[data-xp-manage]").forEach(button => listen(button, "click", () => callbacks.openProfile?.(profiles[Number(button.dataset.xpManage)])));
    root.querySelectorAll("[data-xp-add]").forEach(button => listen(button, "click", () => callbacks.addProfile?.(groups[Number(button.dataset.xpAdd)].name)));
    if (preview) {
      listen(primary, "click", () => {
        const group = groups[active], runnable = firstRunnable(group);
        if (group.profiles.length > 1 && runnable) callbacks.showProfiles?.(group.name);
        else if (runnable) launch(runnable);
        else if (group.profiles.length) callbacks.showProfiles?.(group.name);
        else callbacks.addProfile?.(group.name);
      });
      listen(prev, "click", () => choose(active - 1));
      listen(next, "click", () => choose(active + 1));
      listen(jump, "change", () => choose(Number(jump.value)));
      selectButtons.forEach(button => listen(button, "click", () => choose(Number(button.dataset.xpSelect), true)));
      cards.forEach((card, index) => listen(card, "click", () => choose(index)));
      listen(preview, "wheel", focusWheel, { passive: false });
      listen(document, "scroll", scrollSelection, { passive: true, capture: true });
      listen(window, "resize", measure, { passive: true });
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
    }
    // A disabled Open button drops focus to the body, so remember the last control.
    listen(root, "focusin", event => { focusKey = controlKey(event.target); });
    listen(root, "focusout", event => { if (event.relatedTarget && !root.contains(event.relatedTarget)) focusKey = null; });
    if (kept?.focus) [...root.querySelectorAll("button, select")]
      .find(element => controlKey(element) === kept.focus)?.focus({ preventScroll: true });
    return () => {
      const focused = document.activeElement;
      carried = { app: groups[active]?.name, chosenScrollY,
        focus: root.contains(focused) ? controlKey(focused) : !focused || focused === document.body ? focusKey : null };
      queueMicrotask(() => { carried = null; });
      disposed = true; cancelAnimationFrame(frame);
      cleanup.forEach(dispose => dispose());
    };
  }
  window.AidentityExperience = { mount };
})();
