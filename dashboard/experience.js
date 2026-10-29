/* Adapted from sources retrieved through 21st.dev:
 * Perspective Tunnel Hero — daiwiikharihar, demo 39043
 * https://21st.dev/@daiwiikharihar/components/perspective-tunnel-hero
 * Works Wheel — crafterui, demo 28371
 * https://21st.dev/@crafterui/components/works-wheel
 * Retains their golden-angle/Z-depth and ring-to-drum geometry; replaces React
 * with a disposable DOM controller, real local profiles and accessible controls.
 */
(() => {
  "use strict";
  const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const rad = degrees => degrees * Math.PI / 180;
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const color = value => /^[0-9a-f]{6}$/i.test(value || "") ? `#${value}` : "#e3a17e";
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

  function mount(root, state, callbacks = {}) {
    const all = state.profiles.length
      ? state.profiles.map(p => ({ title: p.name, app: p.app || "App", sub: p.profile,
        color: color(p.color), badge: p.badge || p.app?.slice(0, 1) || "A", profile: p,
        status: p.status }))
      : state.apps.map(a => ({ title: a.name, app: a.name, sub: "Create your first profile",
        color: "#e3a17e", badge: a.name.slice(0, 1), status: "Available on this Mac" }));
    const items = all.slice(0, 12);
    const reducedQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    let reduced = reducedQuery.matches;
    let frame = 0, disposed = false, settling = 0, turn = 0, target = 0;
    let progress = 0.2, targetProgress = 0.2, px = 0, py = 0, tx = 0, ty = 0;
    let stageW = 0, stageH = 0, wheelW = 0, wheelH = 0, active = 0, drag = null;
    let isVisible = true;
    let lastFrame = 0, drumR = 0, ringR = 0, bow = 0, ringScale = 1;
    const camera = new Spring(progress, 180, 28);
    const rotation = new Spring(turn, 380, 26);
    const pointerX = new Spring(0, 500, 30), pointerY = new Spring(0, 500, 30);
    const cleanup = [];
    const listen = (el, type, handler, options) => {
      el.addEventListener(type, handler, options);
      cleanup.push(() => el.removeEventListener(type, handler, options));
    };
    const face = (item, index) => `<span class="xp-face" style="--identity:${item.color}">
      <span class="xp-card-top"><span>${esc(item.app)}</span><span class="xp-dot"></span></span>
      <span class="xp-monogram">${esc(item.badge)}</span>
      <span class="xp-card-foot"><span>${esc(item.sub)}</span><span class="xp-card-number">${String(index + 1).padStart(2, "0")}</span></span>
    </span>`;
    root.innerHTML = `<div class="xp-wrap${reduced ? " xp-reduced" : ""}">
      <div class="xp-topline"><span>Your apps. Your space.</span><button type="button" class="xp-jump">Go to profiles ${arrow}</button></div>
      <section class="xp-tunnel" aria-label="Perspective tunnel">
        <div class="xp-stage">
          <div class="xp-depth-rings" aria-hidden="true"><i></i><i></i><i></i></div>
          <div class="xp-anchor"><span class="xp-eyebrow">aidentity / on your Mac</span><h1>One app.<br><em>Every you.</em></h1><p>All your accounts, open at once.<br>Make room for every side of you.</p></div>
          <div class="xp-tunnel-plane" aria-hidden="true">${items.map((item, i) =>
            `<div class="xp-tunnel-card">${face(item, i)}</div>`).join("")}</div>
          <div class="xp-scroll-cue"><span>Scroll to step inside</span><span class="xp-scroll-stem"></span></div>
          <span class="xp-stage-counter">${items.length ? String(all.length).padStart(2, "0") : "00"} ${state.profiles.length ? "profiles" : "available apps"} / one Mac</span>
        </div>
      </section>
      <section class="xp-collection" aria-labelledby="xp-collection-title">
        <header class="xp-section-header"><div><span class="xp-eyebrow">A different perspective</span><h2 id="xp-collection-title">Your ${state.profiles.length ? "identities" : "apps"}, in orbit.</h2></div><p>Scroll, drag, or use the arrows.<br>Pick an ${state.profiles.length ? "account" : "app"} to make it yours.</p></header>
        ${items.length ? `<div class="xp-wheel" tabindex="0" role="region" aria-label="Identity wheel. Use arrow keys to choose an item.">
          <div class="xp-wheel-plane">${items.map((item, i) =>
            `<button type="button" class="xp-wheel-card" data-index="${i}" aria-label="Select ${esc(item.title)}">${face(item, i)}</button>`).join("")}</div>
          <div class="xp-ring-label">All together.<br><span>Entirely yours.</span></div>
          <div class="xp-wheel-caption"><span class="xp-eyebrow">In focus</span><h3></h3><p></p></div>
          <ol class="xp-index">${items.map((item, i) => `<li><button type="button" data-index="${i}"><span>${String(i + 1).padStart(2, "0")}</span>${esc(item.title)}</button></li>`).join("")}</ol>
          <div class="xp-wheel-controls"><button type="button" class="xp-prev" aria-label="Previous identity">←</button><span class="xp-position" aria-live="polite"></span><button type="button" class="xp-next" aria-label="Next identity">→</button></div>
        </div>
        <div class="xp-selection"><div><span class="xp-selection-label">Selected ${state.profiles.length ? "profile" : "app"}</span><strong class="xp-selection-title"></strong></div><button type="button" class="xp-launch"></button></div>`
          : `<div class="xp-no-apps"><h3>A little space for a new identity.</h3><p>Install a Chromium or Electron app, then add its first profile.</p><button type="button" class="xp-empty-add">Create a profile ${arrow}</button></div>`}
        ${all.length > items.length ? `<p class="xp-more">Showing ${items.length} of ${all.length}. All profiles are available in your workspace.</p>` : ""}
      </section>
      <footer class="xp-end"><span class="xp-end-symbol" aria-hidden="true">a<span>i</span></span><h2>Less switching.<br>More being you.</h2><button type="button" class="xp-jump">Back to your workspace ${arrow}</button><p>Local to this Mac. Your original apps stay untouched.</p></footer>
    </div>`;
    const wrap = root.firstElementChild;
    const tunnel = root.querySelector(".xp-tunnel");
    const stage = root.querySelector(".xp-stage");
    const anchor = root.querySelector(".xp-anchor");
    const prompt = root.querySelector(".xp-scroll-cue");
    const tunnelCards = [...root.querySelectorAll(".xp-tunnel-card")];
    const wheel = root.querySelector(".xp-wheel");
    const wheelPlane = root.querySelector(".xp-wheel-plane");
    const wheelCards = [...root.querySelectorAll(".xp-wheel-card")];
    const ringLabel = root.querySelector(".xp-ring-label");
    const caption = root.querySelector(".xp-wheel-caption");
    const indices = [...root.querySelectorAll(".xp-index button")];
    const last = Math.max(items.length - 1, 0);
    const to = next => { target = clamp(next, 0, last + 1); wake(); };
    const launch = () => {
      const item = items[active];
      if (item?.profile) callbacks.openProfile?.(item.profile);
      else callbacks.addProfile?.(item?.app || "");
    };
    root.querySelectorAll(".xp-jump").forEach(button =>
      listen(button, "click", () => callbacks.showProfiles?.()));
    const emptyAdd = root.querySelector(".xp-empty-add");
    if (emptyAdd) listen(emptyAdd, "click", () => callbacks.addProfile?.(""));

    function updateSelection() {
      if (!wheel) return;
      const item = items[active];
      caption.querySelector("h3").textContent = item.title;
      caption.querySelector("p").textContent = item.status;
      root.querySelector(".xp-selection-title").textContent = item.title;
      root.querySelector(".xp-launch").textContent = item.profile ? "Manage profile ↗" : "Create profile ↗";
      root.querySelector(".xp-position").textContent = `${active + 1} / ${items.length}`;
      for (let i = 0; i < indices.length; i++) {
        indices[i].setAttribute("aria-current", i === active ? "true" : "false");
        wheelCards[i].setAttribute("aria-pressed", i === active ? "true" : "false");
      }
      root.querySelector(".xp-prev").disabled = target === 0;
      root.querySelector(".xp-next").disabled = target >= last + 1;
    }
    function measure() {
      stageW = stage.clientWidth;
      stageH = stage.clientHeight;
      if (wheel) {
        wheelW = wheel.clientWidth; wheelH = wheel.clientHeight;
        const cardW = Math.min(wheelH * 0.38 * 1.45, wheelW * (wheelW < 700 ? 0.56 : 0.34));
        const cardH = cardW / 1.45;
        drumR = cardH * 2.22; ringR = cardH * 1.14; bow = cardH * 1.82;
        ringScale = clamp((2 * Math.PI * ringR / items.length * 0.82) / (cardW || 1), 0.16, 1);
        wheel.style.perspective = `${cardH * 2.7}px`;
        for (const card of wheelCards) {
          card.style.width = `${cardW}px`; card.style.height = `${cardH}px`;
          card.style.marginLeft = `${-cardW / 2}px`; card.style.marginTop = `${-cardH / 2}px`;
        }
      }
      scroll();
    }
    function scroll() {
      if (reduced) return;
      const bounds = tunnel.getBoundingClientRect();
      targetProgress = 0.2 + clamp(-bounds.top / Math.max(1, tunnel.offsetHeight - stageH)) * 0.8;
      wake();
    }
    function wake() {
      if (!frame && !disposed && !document.hidden && isVisible) {
        if (!lastFrame) lastFrame = performance.now();
        frame = requestAnimationFrame(draw);
      }
    }
    function draw(now) {
      frame = 0;
      if (disposed) return;
      const dt = clamp((now - lastFrame) / 1000, 0.001, 0.032);
      lastFrame = now;
      progress = reduced ? 0.35 : camera.step(targetProgress, dt);
      turn = reduced ? Math.max(1, target) : rotation.step(target, dt);
      px = reduced ? 0 : pointerX.step(tx, dt);
      py = reduced ? 0 : pointerY.step(ty, dt);
      if (!reduced) {
        const mobile = stageW < 700;
        for (let i = 0; i < tunnelCards.length; i++) {
          const card = tunnelCards[i];
          const local = clamp((progress - i / tunnelCards.length * 0.45) / 0.55);
          const z = lerp(mobile ? -1200 : -1700, mobile ? 350 : 500, local);
          const angle = rad(i * 137.5);
          const x = Math.cos(angle) * stageW * (0.28 + i % 3 * 0.08) - px * 35;
          const y = Math.sin(angle) * stageH * (0.26 + i % 2 * 0.09) - py * 35;
          card.style.transform = `translate3d(calc(-50% + ${x}px),calc(-50% + ${y}px),${z}px) rotateZ(${(i % 2 ? -1 : 1) * (3 + i % 5 * 2)}deg)`;
          card.style.opacity = String(clamp(local / 0.18) * clamp((0.98 - local) / 0.16));
        }
        anchor.style.transform = `scale(${lerp(0.86, 1.22, progress)})`;
        anchor.style.opacity = String(clamp((1 - progress) / 0.18));
        prompt.style.opacity = String(clamp(1 - (progress - 0.2) * 7));
      }
      if (wheel && !reduced) {
        const m = clamp(turn), pos = Math.max(0, turn - 1);
        wheelPlane.style.transform = `translateZ(${-m * drumR}px)`;
        for (let i = 0; i < wheelCards.length; i++) {
          const card = wheelCards[i], d = i - pos, drumDeg = d * 40;
          card.style.transform = `translateX(${-m * bow * (1 - Math.cos(rad(drumDeg)))}px) rotateZ(${(1 - m) * d * 360 / items.length}deg) translateY(${-(1 - m) * ringR}px) rotateX(${m * drumDeg}deg) translateZ(${m * drumR}px)`;
          const hidden = m > 0.5 && Math.abs(d) > 1.6;
          card.style.opacity = hidden ? "0" : "1";
          card.style.pointerEvents = hidden ? "none" : "auto";
          card.tabIndex = hidden ? -1 : 0;
          card.style.zIndex = String(Math.round(100 - Math.abs(d) * 2));
          card.firstElementChild.style.transform = `scale(${lerp(ringScale, 1, m)})`;
        }
        ringLabel.style.opacity = String(1 - m);
        caption.style.opacity = String(m);
      }
      const near = clamp(Math.round(Math.max(0, turn - 1)), 0, last);
      if (near !== active) { active = near; updateSelection(); }
      const moving = camera.moving(targetProgress) || rotation.moving(target) ||
        pointerX.moving(tx) || pointerY.moving(ty);
      if (moving && !reduced && !document.hidden && isVisible) frame = requestAnimationFrame(draw);
      else lastFrame = 0;
    }
    if (wheel) {
      updateSelection();
      listen(root.querySelector(".xp-launch"), "click", launch);
      listen(root.querySelector(".xp-prev"), "click", () => { to(Math.round(target) - 1); updateSelection(); });
      listen(root.querySelector(".xp-next"), "click", () => { to(Math.round(target) + 1); updateSelection(); });
      [...wheelCards, ...indices].forEach(button => listen(button, "click", () => {
        to(Number(button.dataset.index) + 1); updateSelection();
      }));
      listen(wheel, "keydown", e => {
        if (["ArrowDown", "ArrowRight"].includes(e.key)) to(Math.round(target) + 1);
        else if (["ArrowUp", "ArrowLeft"].includes(e.key)) to(Math.round(target) - 1);
        else if (e.key === "Home") to(1);
        else if (e.key === "End") to(last + 1);
        else return;
        e.preventDefault();
        wheel.focus({ preventScroll: true });
        updateSelection();
      });
      listen(wheel, "wheel", e => {
        if (reduced || Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
        const amount = e.deltaY * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? wheelH : 1);
        const next = target + amount / 900;
        if (next > 0 && next < last + 1) e.preventDefault();
        to(next); clearTimeout(settling);
        settling = setTimeout(() => { to(Math.round(target)); updateSelection(); }, 140);
      }, { passive: false });
      listen(wheel, "pointerdown", e => {
        if (reduced || e.pointerType !== "mouse" || e.target.closest("button")) return;
        drag = e.clientY; wheel.setPointerCapture(e.pointerId);
      });
      listen(wheel, "pointermove", e => {
        if (drag === null) return;
        to(target + (drag - e.clientY) / 420); drag = e.clientY;
      });
      const endDrag = () => { drag = null; if (target > 1) to(Math.round(target)); updateSelection(); };
      listen(wheel, "pointerup", endDrag); listen(wheel, "pointercancel", endDrag);
      listen(wheel, "lostpointercapture", endDrag);
    }
    listen(stage, "pointermove", e => {
      if (reduced || e.pointerType !== "mouse") return;
      const rect = stage.getBoundingClientRect();
      tx = (e.clientX - rect.left) / stageW * 2 - 1;
      ty = (e.clientY - rect.top) / stageH * 2 - 1;
      wake();
    });
    listen(stage, "pointerleave", () => { tx = 0; ty = 0; wake(); });
    listen(document, "scroll", scroll, { passive: true, capture: true });
    listen(window, "resize", measure, { passive: true });
    listen(document, "visibilitychange", wake);
    listen(reducedQuery, "change", () => {
      reduced = reducedQuery.matches;
      wrap.classList.toggle("xp-reduced", reduced);
      camera.reset(targetProgress); rotation.reset(target);
      pointerX.reset(0); pointerY.reset(0);
      if (reduced) {
        for (const el of [...tunnelCards, ...wheelCards, ...wheelCards.map(c => c.firstElementChild), anchor, prompt, wheelPlane, caption, ringLabel]) {
          if (el) el.removeAttribute("style");
        }
        for (let i = 0; i < wheelCards.length; i++) {
          wheelCards[i].firstElementChild.style.setProperty("--identity", items[i].color);
          wheelCards[i].tabIndex = 0;
        }
      }
      measure(); wake();
    });
    const resizeObserver = new ResizeObserver(measure);
    resizeObserver.observe(stage);
    if (wheel) resizeObserver.observe(wheel);
    const observer = new IntersectionObserver(entries => {
      isVisible = entries[0].isIntersecting;
      if (isVisible) wake();
    });
    observer.observe(root);
    measure(); wake();
    return () => {
      disposed = true; cancelAnimationFrame(frame); clearTimeout(settling);
      resizeObserver.disconnect(); observer.disconnect();
      cleanup.forEach(fn => fn());
    };
  }
  window.AidentityExperience = { mount };
})();
