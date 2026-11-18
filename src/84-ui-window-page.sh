# ------------------------------------------------------------- ui: window page --

# The page that `aidentity ui --window` shows in its window. It is one HTML
# file with one style block and one script, and it loads nothing from outside.
# The host puts a fresh random value in place of __AIDENTITY_NONCE__ before it
# loads the page, and the content policy lets only that value run script or
# style. The page asks the host for the list ("state") or for one action
# ("do"), one request at a time, and the host answers by calling aidReply (see
# 83-ui-window-host.sh). Everything the page shows comes from those answers
# and is untrusted: names and output are only ever set as text, never read as
# HTML, and an icon is used only when it is a PNG data URL. An action sends
# back the name and the id its card was drawn from, so that aidentity can
# refuse a card that no longer matches the disk.
uiw_page_html() {
  cat <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-__AIDENTITY_NONCE__'; style-src 'nonce-__AIDENTITY_NONCE__'; img-src data:; base-uri 'none'; form-action 'none'">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>aidentity</title>
<style nonce="__AIDENTITY_NONCE__">
:root {
  color-scheme: light dark;
  --bg: #f5f5f7; --card: #fff; --fg: #1d1d1f; --muted: #5a5a63; --line: #c7c7cc; --edge: #85858c;
  --soft: #ececf0; --good: #11653a; --bad: #b3261e; --warn: #7a5200; --ring: #0a5ed0;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1e1e20; --card: #2a2a2d; --fg: #f2f2f4; --muted: #b0b0b8; --line: #4a4a50; --edge: #8a8a92;
    --soft: #38383c; --good: #4cd07d; --bad: #ff8a80; --warn: #e3b341; --ring: #8ab8ff;
  }
}
[hidden] { display: none !important; }
* { box-sizing: border-box; }
html, body { height: 100%; }
body {
  margin: 0; display: flex; flex-direction: column; background: var(--bg); color: var(--fg);
  font: 13px/1.4 -apple-system, BlinkMacSystemFont, sans-serif;
}
h1 { margin: 0; font-size: 16px; }
h2 { margin: 0 0 8px; font-size: 14px; }
p { margin: 0 0 8px; }
.muted { color: var(--muted); }
.bar {
  display: flex; flex-wrap: wrap; align-items: center; gap: 8px; padding: 10px 16px;
  border-bottom: 1px solid var(--line);
}
.grow { flex: 1; }
main { flex: 1; overflow: auto; padding: 16px; }
section + section { margin-top: 24px; }
button {
  font: inherit; padding: 5px 10px; border: 1px solid var(--edge); border-radius: 6px;
  background: var(--card); color: var(--fg); cursor: default; transition: background-color 0.12s;
}
button:hover:not(:disabled) { background: var(--soft); }
button:disabled { opacity: 0.5; }
button.primary, button.primary:hover:not(:disabled) { background: #0a5ed0; border-color: var(--ring); color: #fff; }
:focus-visible { outline: 2px solid var(--ring); outline-offset: 2px; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 12px; }
.card {
  display: flex; flex-direction: column; gap: 12px; padding: 12px;
  background: var(--card); border: 1px solid var(--line); border-radius: 10px;
}
.top { display: flex; gap: 12px; align-items: center; }
.txt { min-width: 0; }
.name { font-weight: 600; overflow-wrap: anywhere; }
.sub { color: var(--muted); overflow-wrap: anywhere; }
.icon { width: 48px; height: 48px; flex: none; border-radius: 11px; }
.fb {
  display: flex; align-items: center; justify-content: center; background: #5a5a63;
  color: #fff; font-size: 22px; font-weight: 600;
}
.dot {
  display: inline-block; width: 8px; height: 8px; margin-right: 6px; border-radius: 50%;
  border: 1px solid var(--edge);
}
.dot.on { background: var(--good); border-color: var(--good); }
.acts { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
.note { flex-basis: 100%; margin: 0; color: var(--muted); font-size: 12px; }
.row {
  display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 8px 12px;
  background: var(--card); border: 1px solid var(--line); border-radius: 8px; margin-bottom: 6px;
}
.row span { overflow-wrap: anywhere; }
.empty { padding: 32px 0; text-align: center; }
footer { max-height: 40vh; overflow: auto; border-top: 1px solid var(--line); }
footer.has { padding: 10px 16px; }
.line { display: flex; align-items: center; gap: 12px; }
.good { color: var(--good); }
.bad { color: var(--bad); }
.warn { color: var(--warn); }
.cmd, pre { font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, monospace; border-radius: 6px; }
.cmd { margin-top: 8px; padding: 6px 8px; background: var(--soft); overflow-wrap: anywhere; }
pre {
  margin: 8px 0 0; padding: 8px; max-height: 30vh; overflow: auto; background: var(--soft);
  white-space: pre-wrap; overflow-wrap: anywhere;
}
dialog {
  width: min(440px, calc(100vw - 32px)); max-height: calc(100vh - 32px); overflow: auto;
  padding: 20px; background: var(--card); color: var(--fg);
  border: 1px solid var(--line); border-radius: 12px;
}
dialog::backdrop { background: rgba(0, 0, 0, 0.35); }
fieldset { min-width: 0; margin: 0; padding: 0; border: 0; }
fieldset.group { margin-bottom: 12px; }
.fld { display: block; margin-bottom: 12px; }
.lab { display: block; margin-bottom: 4px; padding: 0; color: var(--muted); font-size: 12px; }
input[type=text], select {
  width: 100%; padding: 6px 8px; font: inherit; color: var(--fg);
  background: var(--bg); border: 1px solid var(--edge); border-radius: 6px;
}
.chk { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 10px; }
.chk small { display: block; color: var(--muted); font-size: 12px; }
.opts { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 2px 8px; }
.opts .chk { align-items: center; margin-bottom: 6px; }
.swatch {
  display: inline-block; flex: none; width: 16px; height: 16px; border: 1px solid var(--edge);
  border-radius: 50%;
}
.alert { min-height: 18px; margin: 4px 0 0; color: var(--bad); white-space: pre-wrap; overflow-wrap: anywhere; }
.alert.calm { color: var(--muted); }
.btns { display: flex; justify-content: flex-end; gap: 8px; margin-top: 12px; }
@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>
</head>
<body>
<header class="bar">
  <h1>aidentity</h1><span id="ver" class="muted"></span><span class="grow"></span>
  <button id="add" class="act primary" data-fk="add" data-off="1" type="button" disabled>Add profile</button>
  <button id="check" class="act" data-fk="check" type="button">Check</button>
  <button id="refresh" class="act" data-fk="refresh" type="button">Refresh</button>
</header>
<main id="main" aria-busy="false">
  <section id="profiles"><p class="muted" role="status">Reading your profiles&hellip;</p></section>
  <section id="removed" hidden></section>
</main>
<footer id="result">
  <div class="line">
    <span id="sum" role="status"></span>
    <button id="fix" class="act" data-fk="fix" type="button" hidden>Fix</button>
  </div>
  <div id="cmd" class="cmd" hidden></div>
  <pre id="out" tabindex="0" role="region" aria-label="Command output" hidden></pre>
</footer>
<script nonce="__AIDENTITY_NONCE__">
(function () {
  "use strict";
  var PNG = "data:image/png;base64,";
  var MAX_OUT = 262144;
  var STATUS = {
    "running": "Running", "in use": "Not running", "signed out / new": "Not opened yet",
    "not running": "Not running", "app missing": "App missing"
  };
  // The exit statuses of `aidentity __window do` that are not a command's own.
  var REFUSED = 3, PROBLEMS = 10, FIXABLE = 11;
  // The host's answer to a request that came while a command was still running.
  var STILL = "aidentity is still busy with the action before this one. Wait a moment, then choose Refresh.";
  var S = {
    st: {}, icons: Object.create(null), seq: 0, flight: null, queue: [], timer: 0, busy: 0,
    result: null, shown: null, wantFk: null, ids: 0, dialogs: 0, last: 0
  };

  // ---- small helpers
  function byId(id) { return document.getElementById(id); }
  function str(x) { return x === undefined || x === null ? "" : String(x); }
  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function clear(n) { while (n.firstChild) n.removeChild(n.firstChild); }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }
  function button(label, cls, fn) {
    var b = el("button", cls, label);
    b.type = "button";
    b.addEventListener("click", fn);
    return b;
  }
  // Where focus should go back to: a kind of button and whose it is (a profile's
  // name), so it is found again after the list has been drawn anew.
  function want(n) {
    return n && n.getAttribute && n.getAttribute("data-fk")
      ? { k: n.getAttribute("data-fk"), w: n.getAttribute("data-who") } : null;
  }
  // The first line of some output that says something, without aidentity's own mark.
  function firstLine(text) {
    var lines = str(text).split("\n"), i, l;
    for (i = 0; i < lines.length; i++) {
      l = lines[i].replace(/^\s*[✓✗!]\s+/, "").trim();
      if (l) return l.slice(0, 200);
    }
    return "";
  }

  // Why a command failed: the last line aidentity marked as an error or a
  // warning ("✗ ..." or "! ..."), not the first thing it printed. An action of
  // two steps can do the first and fail the second.
  function reason(text) {
    var lines = str(text).split("\n"), i;
    for (i = lines.length - 1; i >= 0; i--) if (/^\s*[✗!]\s/.test(lines[i])) return firstLine(lines[i]);
    return "";
  }

  // ---- requests: one at a time. The host runs one aidentity command for each.
  function pump() {
    var it;
    if (S.flight || !S.queue.length) return;
    it = S.queue.shift();
    S.seq += 1;
    it.id = S.seq;
    S.flight = it;
    S.timer = setTimeout(function () { settle({ id: it.id, rc: -4, out: "" }); }, 120000);
    try {
      window.webkit.messageHandlers.aid.postMessage({ id: it.id, kind: it.kind, args: it.args });
    } catch (e) {
      settle({ id: it.id, rc: -5, out: "" });
    }
  }
  function ask(kind, args, done) {
    S.queue.push({ kind: kind, args: args, done: done });
    pump();
  }
  // An answer counts only for the request that is waiting for it.
  function settle(m) {
    var it = S.flight;
    if (!it || !m || m.id !== it.id) return;
    clearTimeout(S.timer);
    S.flight = null;
    try { it.done(m); } finally { pump(); }
  }
  window.aidReply = settle;

  // ---- busy state and the result area
  function working(d) {
    S.busy += d;
    refreshBusy();
  }
  function refreshBusy() {
    var busy = S.busy > 0, bs = document.querySelectorAll("button.act"), i;
    byId("main").setAttribute("aria-busy", busy ? "true" : "false");
    for (i = 0; i < bs.length; i++) bs[i].disabled = busy || bs[i].getAttribute("data-off") === "1";
    showResult(busy);
    if (!busy) restoreFocus();
  }
  function showResult(busy) {
    var r = S.result, sum = byId("sum");
    if (S.shown && S.shown.r === r && S.shown.b === busy) return;
    S.shown = { r: r, b: busy };
    sum.textContent = busy ? "Working…" : (r ? r.summary : "");
    sum.className = busy || !r ? "" : (r.warn ? "warn" : r.ok ? "good" : "bad");
    byId("cmd").textContent = r ? r.command : "";
    byId("cmd").hidden = !(r && r.command);
    byId("out").textContent = r ? r.output : "";
    byId("out").hidden = !(r && r.output);
    byId("fix").hidden = busy || !(r && r.fix);
    byId("result").className = busy || r ? "has" : "";
  }
  function say(summary, ok) {
    S.result = { summary: summary, ok: ok, warn: false, fix: false, command: "", output: "" };
    refreshBusy();
  }
  // Focus goes back to the button it came from once that button can take it again.
  function restoreFocus() {
    var w = S.wantFk, all, i;
    if (!w || S.dialogs || (document.activeElement && document.activeElement !== document.body)) return;
    all = document.querySelectorAll("[data-fk]");
    for (i = 0; i < all.length; i++) {
      if (all[i].getAttribute("data-fk") === w.k && all[i].getAttribute("data-who") === w.w) {
        if (!all[i].disabled) { S.wantFk = null; all[i].focus(); }
        return;
      }
    }
    // That button is gone, with its card or its row. Focus goes to a place
    // that makes sense, not to the top of the page without a word.
    S.wantFk = null;
    all = w.k === "fix" ? byId("check") : (document.querySelector(".card button:not(:disabled)") || byId("add"));
    if (all && !all.disabled) all.focus();
  }

  // ---- the list
  // parts: launchers, apps, restorable. What comes back replaces those parts only.
  // keep: a list that cannot be read is not reported, so that the result of
  // the action before it stays on screen.
  function load(parts, done, keep) {
    ask("state", parts, function (m) {
      var k;
      if (m.rc === 0 && m.state && typeof m.state === "object") {
        for (k in m.state) if (has(m.state, k)) S.st[k] = m.state[k];
        if (m.icons && typeof m.icons === "object") {
          for (k in m.icons) if (has(m.icons, k) && typeof m.icons[k] === "string") S.icons[k] = m.icons[k];
        }
        S.last = Date.now();
        render();
      } else if (!keep) {
        // Nothing drawn yet: the line that says it is being read would stay for ever.
        if (!Array.isArray(S.st.profiles)) {
          clear(byId("profiles"));
          byId("profiles").appendChild(el("p", "muted", "The list could not be read."));
        }
        say(m.rc === -1 ? STILL
          : "The list could not be read. " + (firstLine(m.out) || "Choose Refresh to try again."), false);
      }
      if (done) done(m);
    });
  }

  // ---- actions
  // What one `aidentity __window do` answered: the command it ran on the first
  // line, then that command's output.
  function outcome(verb, m) {
    var out = str(m.out).replace(/\u001b\[[0-9;?]*[A-Za-z]/g, ""), nl = out.indexOf("\n");
    var r = {
      ok: m.rc === 0, refused: m.rc === REFUSED, warn: false, fix: false, summary: "",
      command: (nl < 0 ? out : out.slice(0, nl)).trim(),
      output: nl < 0 ? "" : out.slice(nl + 1).replace(/\s+$/, "")
    };
    var line = firstLine(r.output), warned = /^! (.+)$/m.exec(r.output);
    if (r.output.length > MAX_OUT) {
      r.output = r.output.slice(0, MAX_OUT) +
        "\n(The output was cut here. Run the command in a terminal to see all of it.)";
    }
    if (m.rc === -4) {
      r.summary = "No answer from aidentity for 2 minutes. It may still be working. Choose Refresh " +
        "to see the list as it is now.";
    } else if (m.rc === -1) {
      r.summary = STILL;
    } else if (m.rc < 0) {
      r.summary = "The window could not run aidentity. Close the window and open it again.";
    } else if (m.rc === REFUSED) {
      r.summary = "Not done. " + line;
    } else if (verb === "check" && (m.rc === PROBLEMS || m.rc === FIXABLE)) {
      r.summary = "The check found problems. See below.";
      r.warn = true;
      r.fix = m.rc === FIXABLE;
    } else if (verb === "fix" && m.rc === PROBLEMS) {
      r.summary = "Some problems are left. See below.";
      r.warn = true;
    } else if (verb === "check" && r.ok) {
      r.summary = "The check found no problems.";
    } else if (verb === "fix" && r.ok) {
      r.summary = "Fixed. No problems are left.";
    } else if (r.ok && warned) {
      // A command that did less than asked still ends well, after a warning ("! ...").
      r.summary = "Done, with a warning: " + warned[1].slice(0, 200);
      r.warn = true;
    } else if (r.ok) {
      r.summary = "Done. " + line;
    } else {
      r.summary = "Failed. " + (reason(r.output) || line);
    }
    return r;
  }
  // words: the verb and what goes with it. after(result) hears how it went, before
  // the list is read again. again: also look at what is running a moment later,
  // for an app that takes its time to start or to quit.
  function run(words, after, again) {
    S.wantFk = want(document.activeElement) || S.wantFk;
    working(1);
    ask("do", words, function (m) {
      S.result = outcome(words[0], m);
      if (after) after(S.result);
      load(["launchers", "restorable"], function () {
        working(-1);
        if (again) setTimeout(function () { if (idle()) load(["launchers"], null, true); }, 2500);
      }, true);
    });
  }
  function idle() { return !S.flight && !S.queue.length && !S.dialogs && S.busy === 0; }

  // ---- drawing the profiles
  // Black or white, whichever reads better on this colour.
  function ink(hex) {
    function lin(i) {
      var c = parseInt(hex.substr(i, 2), 16) / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * lin(0) + 0.7152 * lin(2) + 0.0722 * lin(4) > 0.179 ? "#000" : "#fff";
  }
  function icon(p) {
    var src = p.icon ? S.icons[p.icon] : "", img, d;
    if (typeof src === "string" && src.indexOf(PNG) === 0) {
      img = el("img", "icon");
      img.src = src;
      img.alt = "";
      img.width = 48;
      img.height = 48;
      return img;
    }
    d = el("div", "icon fb", Array.from(str(p.badge) || str(p.app) || "?")[0].toUpperCase());
    d.setAttribute("aria-hidden", "true");
    if (/^[0-9A-Fa-f]{6}$/.test(str(p.color))) {
      d.style.setProperty("background", "#" + p.color);
      d.style.setProperty("color", ink(str(p.color)));
    }
    return d;
  }
  // A button of a card or a row. who: the profile it belongs to, said with the label.
  function act(label, cls, fk, who, off, fn) {
    var b = button(label, "act " + cls, function () { fn(b); });
    b.setAttribute("data-fk", fk);
    b.setAttribute("data-who", who);
    b.setAttribute("data-off", off ? "1" : "0");
    b.setAttribute("aria-label", label.replace("…", "") + " " + who);
    return b;
  }
  function card(p) {
    var name = str(p.name), running = p.status === "running", off = p.usable === false;
    var c = el("article", "card"), top = el("div", "top"), txt = el("div", "txt");
    var sub = el("div", "sub"), dot = el("span", running ? "dot on" : "dot");
    var acts = el("div", "acts"), title = el("div", "name", name);
    // The profile as this card shows it: aidentity acts only while the disk agrees.
    function who() { return [name, str(p.id)]; }
    dot.setAttribute("aria-hidden", "true");
    sub.appendChild(dot);
    sub.appendChild(document.createTextNode(str(p.app) + " · " + (STATUS[p.status] || "Not running")));
    title.id = "name-" + (S.ids += 1);
    c.setAttribute("aria-labelledby", title.id);
    txt.appendChild(title);
    txt.appendChild(sub);
    top.appendChild(icon(p));
    top.appendChild(txt);
    c.appendChild(top);
    // Open and Quit are two buttons, each always in its own place: a button
    // that changed its meaning between two clicks would quit an app just opened.
    acts.appendChild(act("Open", "primary", "open", name, off || p.status === "app missing",
      function () { run(["open"].concat(who()), null, true); }));
    if (running) {
      acts.appendChild(act("Quit", "", "quit", name, off,
        function () { run(["quit"].concat(who()), null, true); }));
    }
    acts.appendChild(act("Edit…", "", "edit", name, off, function (b) { editDialog(p, b); }));
    acts.appendChild(act("Remove…", "", "remove", name, off, function (b) { removeDialog(p, b); }));
    if (off) {
      acts.appendChild(el("p", "note", "Its name starts with a hyphen. Use the terminal for it, " +
        "with ./ before the name."));
    } else if (p.status === "app missing") {
      acts.appendChild(el("p", "note", "The app it opens is not there. Install it again, or choose " +
        "Check to see what can be fixed."));
    }
    c.appendChild(acts);
    return c;
  }
  function render() {
    var st = S.st, box = byId("profiles"), rm = byId("removed"), list, grid, rest, seen = {};
    var had = want(document.activeElement);
    byId("ver").textContent = st.version ? "v" + st.version : "";
    byId("add").setAttribute("data-off", Array.isArray(st.apps) && st.apps.length ? "0" : "1");
    if (Array.isArray(st.profiles)) {
      list = st.profiles;
      clear(box);
      if (list.length) {
        grid = el("div", "grid");
        list.forEach(function (p) { grid.appendChild(card(p)); });
        box.appendChild(el("h2", "", "Profiles"));
        box.appendChild(grid);
      } else {
        box.appendChild(el("div", "empty")).appendChild(el("p", "", !Array.isArray(st.apps)
          ? "You have no profiles yet."
          : st.apps.length
            ? "You have no profiles yet. A profile is one more account of an app such as Claude, " +
              "signed in next to the one you have. Choose Add profile to make one."
            : "You have no profiles yet, and no app here can have one. Install an app such as " +
              "Claude or ChatGPT, then choose Refresh."));
      }
    }
    clear(rm);
    rest = Array.isArray(st.restorable) ? st.restorable : [];
    if (st.restorable_ok === false) {
      rm.appendChild(el("h2", "", "Removed profiles"));
      rm.appendChild(el("p", "muted", "A folder in " + (str(st.apps_dir) || "the launcher folder") +
        " could not be read, so removed profiles are not listed here. Check its permissions, " +
        "then choose Refresh."));
    } else if (rest.length) {
      rm.appendChild(el("h2", "", "Removed profiles"));
      rm.appendChild(el("p", "muted", "Their launchers were removed, but their data is still here. " +
        "Restore brings the launcher back, still signed in."));
      rest.forEach(function (x) { seen[str(x.label)] = (seen[str(x.label)] || 0) + 1; });
      rest.forEach(function (x) {
        // Two removed profiles can have one name: their folders tell them apart.
        var label = str(x.label) + (seen[str(x.label)] > 1 ? " (" + str(x.folder) + ")" : "");
        var r = el("div", "row");
        r.appendChild(el("span", "", label));
        r.appendChild(act("Restore", "", "restore", label, false,
          function () { run(["restore", str(x.dir)]); }));
        rm.appendChild(r);
      });
    }
    rm.hidden = !rm.firstChild;
    if (had) S.wantFk = had;
    refreshBusy();
  }

  // ---- dialogs
  // o.build(set) adds the fields and may give the one to start in. o.words(fail)
  // gives the action to run, or calls fail(message, field) and gives nothing.
  // The dialog stays open while the action runs, and after an action that
  // failed: what was typed is kept, and the reason is shown where the person
  // is looking.
  function dialog(o) {
    var dlg, form, set, title, alert, btns, cancel, okb, f, running = false;
    // <dialog> came with macOS 12.3: without it nothing here would open.
    if (typeof HTMLDialogElement !== "function") {
      say("This needs macOS 12.3 or later. Use aidentity ui in a terminal instead.", false);
      return;
    }
    dlg = el("dialog");
    form = el("form");
    set = el("fieldset");
    title = el("h2", "", o.title);
    alert = el("p", "alert");
    btns = el("div", "btns");
    okb = el("button", "primary", o.ok);
    function fail(msg, field) {
      alert.className = "alert";
      alert.textContent = msg;
      if (field) field.focus();
      return null;
    }
    form.noValidate = true;
    title.id = "title-" + (S.ids += 1);
    dlg.setAttribute("aria-labelledby", title.id);
    alert.setAttribute("role", "alert");
    form.appendChild(title);
    f = o.build(set);
    form.appendChild(set);
    form.appendChild(alert);
    cancel = button("Cancel", "", function () { dlg.close(); });
    btns.appendChild(cancel);
    okb.type = "submit";
    btns.appendChild(okb);
    form.appendChild(btns);
    form.addEventListener("submit", function (e) {
      var words;
      e.preventDefault();
      if (okb.disabled) return;
      alert.textContent = "";
      words = o.words(fail);
      if (!words) return;
      // An action that has started cannot be taken back: Cancel and Esc wait
      // for it, so that nobody thinks they stopped it.
      running = true;
      set.disabled = true;
      okb.disabled = true;
      cancel.disabled = true;
      alert.className = "alert calm";
      alert.textContent = "Working…";
      run(words, function (res) {
        running = false;
        cancel.disabled = false;
        // Done, or refused because the list has changed: the list behind the
        // dialog is read again, and the result line says what happened.
        if (res.ok || res.refused) { dlg.close(); return; }
        set.disabled = false;
        okb.disabled = false;
        fail(res.summary, set.querySelector("input[type=text]:not(:disabled)"));
      });
    });
    dlg.addEventListener("cancel", function (e) { if (running) e.preventDefault(); });
    dlg.addEventListener("close", function () {
      S.dialogs -= 1;
      if (dlg.parentNode) dlg.parentNode.removeChild(dlg);
      if (o.opener && o.opener.isConnected && !o.opener.disabled) o.opener.focus();
      else if (want(o.opener)) { S.wantFk = want(o.opener); restoreFocus(); }
    });
    dlg.appendChild(form);
    document.body.appendChild(dlg);
    S.dialogs += 1;
    dlg.showModal();
    f = f || set.querySelector("input[type=text]:not(:disabled)") || set.querySelector("input[type=radio]:checked");
    if (f) f.focus();
  }
  function field(label, control) {
    var l = el("label", "fld");
    l.appendChild(el("span", "lab", label));
    l.appendChild(control);
    return l;
  }
  function textInput(value, max) {
    var i = el("input");
    i.type = "text";
    i.value = value;
    i.maxLength = max;
    i.autocomplete = "off";
    i.spellcheck = false;
    return i;
  }
  // A check box or a radio button with its words, and a second line if given.
  function choice(type, name, label, more, on) {
    var l = el("label", "chk"), c = el("input"), t = el("span", "", label);
    c.type = type;
    if (name) c.name = name;
    c.checked = !!on;
    if (more) t.appendChild(el("small", "", more));
    l.appendChild(c);
    l.appendChild(t);
    return { row: l, box: c };
  }
  // The badge and the colour, for Add and for Edit. was: the profile as it is,
  // or nothing for a new one. read(fail) gives what to change; "" leaves a
  // thing as it is (for a new profile: aidentity's own choice).
  function lookFields(set, was) {
    var colors = Array.isArray(S.st.colors) ? S.st.colors : [];
    var old = was ? str(was.badge) : "", current = "", radios = [];
    var badge = textInput(old, 8);
    var none = choice("checkbox", "", "No badge (the app's own icon)", "", was && !old);
    var group = el("fieldset", "group"), opts = el("div", "opts");
    function sync() { badge.disabled = none.box.checked; }
    function radio(value, label, hex, on) {
      var c = choice("radio", "colour", label, "", on), sw = el("span", "swatch");
      c.box.value = value;
      sw.setAttribute("aria-hidden", "true");
      if (/^[0-9A-Fa-f]{6}$/.test(hex)) sw.style.setProperty("background", "#" + hex);
      c.row.insertBefore(sw, c.row.lastChild);
      radios.push(c.box);
      opts.appendChild(c.row);
    }
    none.box.addEventListener("change", sync);
    sync();
    if (!was) badge.placeholder = "First letter of the name";
    set.appendChild(field(was ? "Badge (one character)" : "Badge (optional, one character)", badge));
    set.appendChild(none.row);
    colors.forEach(function (c) {
      if (was && str(c.hex).toUpperCase() === str(was.color).toUpperCase()) current = str(c.name);
    });
    group.appendChild(el("legend", "lab", "Colour"));
    if (!was) radio("", "Automatic", "", true);
    else if (!current) radio("", "As it is now", str(was.color), true);
    colors.forEach(function (c) { radio(str(c.name), str(c.name), str(c.hex), !!current && str(c.name) === current); });
    group.appendChild(opts);
    set.appendChild(group);
    return {
      read: function (fail) {
        var b, c = "", i;
        if (none.box.checked) b = was && !old ? "" : "none";
        else if (badge.value === old && (old || !was)) b = "";
        else if (Array.from(badge.value).length === 1) b = badge.value;
        else return fail("Type one character for the badge, or choose No badge.", badge);
        for (i = 0; i < radios.length; i++) if (radios[i].checked) c = radios[i].value;
        return { badge: b, color: c === current ? "" : c };
      }
    };
  }
  function addDialog(opener) {
    var apps = Array.isArray(S.st.apps) ? S.st.apps : [], app, name, look;
    dialog({
      title: "Add profile", ok: "Add", opener: opener,
      build: function (set) {
        app = el("select");
        apps.forEach(function (a) {
          // Two apps with one name are told apart by their folder.
          var twins = apps.filter(function (x) { return str(x.name) === str(a.name); }).length > 1;
          app.appendChild(el("option", "", str(a.name) + (twins ? " (" + str(a.where) + ")" : "")));
        });
        name = textInput("", 40);
        set.appendChild(field("App", app));
        set.appendChild(field("Profile name, such as Work", name));
        look = lookFields(set, null);
        // The app is chosen already; the name is what a person types.
        return name;
      },
      words: function (fail) {
        var a = apps[app.selectedIndex], l;
        if (!a) return fail("Choose an app.", app);
        if (!name.value) return fail("Type a name for the profile.", name);
        l = look.read(fail);
        return l ? ["add", str(a.path), name.value, l.badge, l.color] : null;
      }
    });
  }
  function editDialog(p, opener) {
    var name, look;
    dialog({
      title: "Edit " + str(p.name), ok: "Save", opener: opener,
      build: function (set) {
        // A Main launcher opens the app's own account and keeps its name.
        if (!p.main) {
          name = textInput(str(p.profile), 40);
          set.appendChild(field("Profile name", name));
          if (p.status === "running") {
            set.appendChild(el("p", "muted", "It is running. Quit it before you give it a new name."));
          }
        }
        look = lookFields(set, p);
      },
      words: function (fail) {
        var l, n = "";
        if (name && !name.value) return fail("Type a name for the profile.", name);
        if (name && name.value !== str(p.profile)) n = name.value;
        l = look.read(fail);
        if (!l) return null;
        if (!n && !l.badge && !l.color) return fail("Nothing was changed.");
        return ["edit", str(p.name), str(p.id), n, l.badge, l.color];
      }
    });
  }
  function removeDialog(p, opener) {
    var purge = null;
    dialog({
      title: "Remove " + str(p.name) + "?", ok: "Remove", opener: opener,
      build: function (set) {
        var group, keep;
        if (p.main) {
          // Nothing of a Main launcher is kept for a restore, and none is needed.
          set.appendChild(el("p", "", "This removes the launcher only. Your original account is not affected."));
          set.appendChild(el("p", "muted", "To make the launcher again, run in a terminal: aidentity add \"" +
            str(p.app) + "\" --main"));
          return;
        }
        if (p.status === "running") {
          set.appendChild(el("p", "muted", "It is running. Quit it first: a profile cannot be removed while it runs."));
        }
        group = el("fieldset", "group");
        group.appendChild(el("legend", "lab", "What happens to its data"));
        keep = choice("radio", "remove", "Keep the data", "The account stays signed in. You can bring " +
          "the launcher back later, under Removed profiles.", true);
        purge = choice("radio", "remove", "Move the data to the Trash", "You will be signed out of " +
          "this account.", false);
        group.appendChild(keep.row);
        group.appendChild(purge.row);
        set.appendChild(group);
      },
      words: function () {
        return ["remove", str(p.name), str(p.id), purge && purge.box.checked ? "purge" : "keep"];
      }
    });
  }
  function fixDialog() {
    dialog({
      title: "Fix problems", ok: "Fix", opener: byId("fix"),
      build: function (set) {
        set.appendChild(el("p", "", "Fix what the check can fix by itself?"));
        set.appendChild(el("p", "muted", "It rebuilds launchers that are out of date or broken, and makes " +
          "profile folders private to you. The rest is left for you."));
      },
      words: function () { return ["fix"]; }
    });
  }

  // ---- start
  byId("add").addEventListener("click", function () { addDialog(byId("add")); });
  byId("check").addEventListener("click", function () {
    // Fix sits below the cards: when there is something to fix, focus goes to it.
    run(["check"], function (res) { if (res.fix) S.wantFk = { k: "fix", w: null }; });
  });
  byId("fix").addEventListener("click", fixDialog);
  byId("refresh").addEventListener("click", function () {
    S.wantFk = want(byId("refresh"));
    working(1);
    load(["launchers", "apps", "restorable"], function (m) {
      if (m.rc === 0) S.result = { summary: "List updated.", ok: true, warn: false, fix: false, command: "", output: "" };
      working(-1);
    });
  });
  // Nothing dropped on the window and no menu item may load another page in it.
  ["dragenter", "dragover", "drop", "contextmenu"].forEach(function (t) {
    document.addEventListener(t, function (e) { e.preventDefault(); });
  });
  // The host calls this when the window comes to the front again. The page
  // does not poll: what is running is read then, and after each action.
  window.aidFocus = function () {
    if (idle() && Date.now() - S.last > 1500) load(["launchers", "restorable"], null, true);
  };
  // The launchers first, which are quick, so the cards show at once; then the rest.
  load(["launchers"], function () { load(["apps", "restorable"]); });
})();
</script>
</body>
</html>
HTML
}
