/* Core UI adapted from retrieved 21st.dev sources:
 * Animated Sidebar (starc007, 29334), Animated Dialog (rmahammad, 26905),
 * Animated Profile Card (ravikatiyar162, 8206), Animated Tabs (educalvolpz, 24930),
 * Input/Button (originui, 159/146), Toast (cnippet-dev, 24297),
 * Button Spinner (uiable, 19975). React primitives translated to native DOM,
 * dialog, CSS transitions and Web Animations. See docs/dashboard-components.md.
 */
(() => {
  "use strict";
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];
  const escape = value => String(value ?? "").replace(/[&<>"']/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]));
  const iconPaths = {
    grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    explore:'<circle cx="12" cy="12" r="9"/><path d="m16 8-2.5 5.5L8 16l2.5-5.5L16 8Z"/>',
    apps:'<rect x="4" y="4" width="16" height="16" rx="4"/><path d="M9 4v16M4 9h16"/>',
    recovery:'<path d="M3 10a9 9 0 1 1 2.6 8.4M3 4v6h6"/><path d="M12 7v5l3 2"/>',
    tool:'<path d="m14.7 6.3 3 3 3.1-3.1a6 6 0 0 1-7.5 7.5L6.5 20.5a2.1 2.1 0 0 1-3-3l6.8-6.8a6 6 0 0 1 7.5-7.5l-3.1 3.1Z"/>',
    transfer:'<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
    book:'<path d="M12 5c-3-2-6-2-9-1v15c3-1 6-1 9 1m0-15c3-2 6-2 9-1v15c-3-1-6-1-9 1V5Z"/>',
    panel:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M9 4v16"/>',
    menu:'<path d="M4 6h16M4 12h16M4 18h16"/>',
    plus:'<path d="M12 5v14M5 12h14"/>',
    refresh:'<path d="M20 7v5h-5M4 17v-5h5"/><path d="M6.3 7a7 7 0 0 1 12.4 2M5.3 15a7 7 0 0 0 12.4 2"/>',
    // rebuild: the launcher .app as a box; update: a version step up. Neither reuses refresh or download.
    rebuild:'<path d="m12 3 8 4.5v9L12 21l-8-4.5v-9L12 3Z"/><path d="m4 7.5 8 4.5 8-4.5M12 12v9"/>',
    update:'<circle cx="12" cy="12" r="9"/><path d="M12 16.5v-9m-4 4 4-4 4 4"/>',
    search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    x:'<path d="m6 6 12 12M18 6 6 18"/>',
    play:'<path d="m8 5 11 7-11 7V5Z"/>',
    stop:'<rect x="6" y="6" width="12" height="12" rx="2"/>',
    more:'<circle cx="5" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="19" cy="12" r="1" fill="currentColor"/>',
    settings:'<path d="M4 7h16M4 17h16"/><circle cx="8" cy="7" r="3" fill="var(--surface)"/><circle cx="16" cy="17" r="3" fill="var(--surface)"/>',
    rename:'<path d="m15 4 5 5M4 20l4-1 12-12a2.8 2.8 0 0 0-4-4L4 15v5Z"/>',
    trash:'<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/>',
    shield:'<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z"/><path d="m8 12 3 3 5-6"/>',
    download:'<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
    upload:'<path d="M12 16V4m-5 5 5-5 5 5M4 16v5h16v-5"/>',
    arrow:'<path d="M5 12h14m-5-5 5 5-5 5"/>',
    back:'<path d="M19 12H5m5-5-5 5 5 5"/>',
    terminal:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m6 8 4 4-4 4M13 16h4"/>',
    chevron:'<path d="m6 15 6-6 6 6"/>',
    check:'<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
    alert:'<circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16v.5"/>',
    folder:'<path d="M3 7V5a2 2 0 0 1 2-2h5l3 4h6a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z"/>',
    copy:'<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
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
  // The seven app hues live in styles.css (--hue-*). Mint is status, the logo and the default accent, never an app hue.
  // Frozen copy of those tokens, used only when one is missing or not #rrggbb.
  const hueNames=["periwinkle","teal","orange","pink","gold","sky","violet"],hueDefaults=["#7c8cff","#2fd4c0","#ff8a3d","#ff6fb5","#ffd166","#4cc3ff","#b26bff"];
  const hueToken=(hue,fallback)=>{const hex=getComputedStyle(document.documentElement).getPropertyValue(`--hue-${hue}`).trim().toLowerCase();return /^#[0-9a-f]{6}$/.test(hex)?hex:(console.warn(`--hue-${hue} is missing or not #rrggbb; using ${fallback}`),fallback);};
  const appPalette=hueNames.map((hue,i)=>hueToken(hue,hueDefaults[i]));
  // Badge colors are the user's own choice: mint and the seven app hues, then two neutrals.
  const colors=[["Mint",hueToken("mint","#5fe08a")],...hueNames.map((hue,i)=>[hue[0].toUpperCase()+hue.slice(1),appPalette[i]])].map(([name,hex])=>[name,hex.slice(1).toUpperCase()]).concat([["Gray","8D8B84"],["Graphite","262624"]]);
  const appAccentAssignments=new Map();
  let huedApps=new Set();
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
      const preferred=appHash(name)%appPalette.length;
      let index=preferred;
      for(let offset=0;offset<appPalette.length;offset++){
        const candidate=(preferred+offset)%appPalette.length;
        if(!used.has(candidate)){index=candidate;break;}
      }
      appAccentAssignments.set(appKey(name),index);used.add(index);
    }
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
    const blocks=$$(".title-row,.terms,.tabs,.toolbar,.profile-card,.application-card,.operation-card,.panel,.guide-output,.guide-empty",main);
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
  const OFFLINE="The dashboard stopped. Run “aidentity dashboard” in Terminal to reconnect.";
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
  const appGlyph = name => {
    const n = String(name).toLowerCase();
    let paths = "";
    if(n.includes("claude")) paths='<path d="M16 3v26M3 16h26M7 7l18 18M7 25 25 7M10 4l12 24M4 10l24 12M4 22l24-12M10 28 22 4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>';
    else if(n.includes("chrome") || n.includes("chromium")) paths='<circle cx="16" cy="16" r="12" stroke="currentColor" stroke-width="2"/><circle cx="16" cy="16" r="5" stroke="currentColor" stroke-width="2"/><path d="M16 11h11M12 19 7 9M19 19l-6 10" stroke="currentColor" stroke-width="2"/>';
    else if(n.includes("code") || n.includes("cursor")) paths='<path d="m23 3 6 3v20l-6 3-15-12-5 4v-9l5 4L23 3Zm0 6-10 7 10 7V9Z" fill="currentColor"/>';
    else if(n.includes("slack")) paths='<path d="M12 3v17M3 12h17M20 12v17M12 20h17" stroke="currentColor" stroke-width="5" stroke-linecap="round"/>';
    else if(n.includes("notion")) paths='<path d="M6 6h21v22H6V6Zm5 18V10l12 14V10" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/>';
    else if(n.includes("edge") || n.includes("brave") || n.includes("arc")) paths='<path d="M6 23 16 5l10 18M10 17h12M8 26h16" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>';
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
  // A command wraps only between shell words, never inside a quoted name. Each word is an inline-block that breaks inside only when wider than the line.
  const commandHtml=command=>(String(command||"").match(/(?:[^\s'"\\]+|'[^']*'|"(?:[^"\\]|\\.)*"|\\.|['"\\])+/g)||[]).map(word=>`<span class="command-word">${escape(word)}</span>`).join(" ");
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
    // A candidate can be hidden (a closed disclosure, the panel's own copy from 768px): try the next until one takes focus.
    for(const el of [same,from.place&&area&&$(from.place==="detail"?"#detail-title":".profile-name",area),$("h1",main)]){if(!el||el.disabled)continue;el.focus({preventScroll:true});if(document.activeElement===el)return;}
  }
  let navApps=null;
  function renderNav() {
    if(!$("#primary-nav").children.length)$("#primary-nav").innerHTML=navigation.map(([id,label,glyph])=>`<button class="nav-item section-${id}" data-view="${id}" title="${label}">${tile(id,glyph)}<span class="nav-label">${label}</span></button>`).join("");
    const apps = [...new Set((state?.profiles || []).map(appName))].sort(byName);
    const appsKey=JSON.stringify([apps.map(name=>[name,appAccent(name).color]),Boolean(state?.errors?.length),Boolean(state)]);
    // Expanded: an 8px dot in the app's hue. Collapsed rail: the app's initial on its hue, named by the focus tooltip.
    if(appsKey!==navApps){navApps=appsKey;keepFocus(()=>{$("#app-nav").innerHTML=apps.map(name=>{const t=tone(name);return `<button class="nav-item nav-app${t.cls}"${t.style} data-app-filter="${escape(name)}" title="${escape(name)}"><span class="app-mini" aria-hidden="true"><span class="nav-app-dot"></span><span class="nav-app-initial">${escape([...name][0].toUpperCase())}</span></span><span class="nav-label">${escape(name)}</span></button>`;}).join("") || (state?`<p class="small nav-label" style="padding:0 12px">${state.errors?.length?"Inventory unavailable":"No profiles yet"}</p>`:"");});}
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
  function errorNotice(){return (state.errors||[]).length?`<div class="notice error">${state.errors.map(escape).join("<br>")}</div>`:"";}
  function setupError(){return `<div class="empty-state"><h2>aidentity could not read your setup</h2>${errorNotice()}<div class="section-gap">${button("Retry","refresh",{primary:true,icon:"refresh"})}</div></div>`;}
  function title(name,description="",actions="",hint=""){const glyph=view==="guide"?"book":navigation.find(item=>item[0]===view)?.[2];return `<div class="title-row"><div class="title-main">${glyph?tile(view,glyph):""}<div><h1 tabindex="-1">${escape(name)}</h1>${description?`<p>${escape(description)}</p>`:""}${hint?`<p class="title-hint">${escape(hint)}</p>`:""}</div></div>${actions?`<div class="title-actions">${actions}</div>`:""}</div>`;}
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
  // A page change crossfades #main alone (styles.css names it; the sidebar and top bar stay put). A change started mid-flight
  // skips the running one, which applies its update at once, so the last click wins. Reduced motion and options.instant swap in place.
  function showView(next,options={}){
    const update=()=>{
      if(cleanupExperience){cleanupExperience();cleanupExperience=null;}
      if(next!==view)query="";// each view starts unfiltered; its own query survives only while you stay on it
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
    document.startViewTransition(update);
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
        statusLabel,
        addProfile:app=>addDialog(app || ""),
        launchProfile:item=>action("open",{name:item.name}),
        focusApp:name=>{exploreApp=name;renderNav();},
      });
      else main.innerHTML=title("Every profile, together","Create a profile for each account you use.")+button("Open workspace","workspace",{primary:true,icon:"arrow"});
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
  // At 901px and up the detail column is always there while profiles exist, so selecting never reflows the grid.
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
    const chosen=profile(selected);
    if(!chosen)mobileDetail=false;
    main.classList.toggle("profile-detail-mobile",mobileDetail);
    // Counts live on the tabs only. Search shows from 7 profiles, the app filter once two apps have profiles.
    const appNames=[...new Set(state.profiles.map(appName))].sort(byName);
    const repairs=scoped.filter(needsRepair).length;
    const search=state.profiles.length>6||query?searchField("Search profiles"):"";
    const filter=appNames.length>1?`<select id="app-filter" aria-label="Filter by application"><option value="">All apps</option>${appNames.map(name=>`<option${name===appFilter?" selected":""}>${escape(name)}</option>`).join("")}</select>`:"";
    const toolbar=search||filter||appFilter?`<div class="toolbar">${search}<div class="toolbar-end">${appFilter?button("All apps","all-apps",{small:true}):""}${filter}${search?`<span class="sr-only" id="result-count" role="status">${plural(visible.length,"profile")}</span>`:""}</div></div>`:"";
    paint(title(appFilter||"Profiles",appFilter?"":"Each profile opens an app with its own sign-in.")+
      tabs([["all","All",scoped.length],["running","Running",running],["idle","Not running",scoped.length-running],["attention","Needs repair",lastDoctor||repairs?repairs:null,"Not checked yet. Choose Check on Maintenance."]],statusFilter)+
      toolbar+
      `<div class="profile-layout ${state.profiles.length?"":"no-selection"} ${mobileDetail?"mobile-detail":""}"><div class="profile-grid" id="profile-results" role="tabpanel" aria-labelledby="status-${statusFilter}">${visible.map(card).join("")||profilesEmpty(scoped)}</div>${chosen?detail(chosen):state.profiles.length?'<p class="detail-placeholder">Select a profile to see its settings and actions.</p>':""}</div>`);
    fillPreviews();
  }
  const emptyState=(heading,text,actions="")=>`<div class="empty-state"><h2>${heading}</h2><p>${text}</p>${actions}</div>`;
  // Search-empty, filter-empty and each status tab get their own words: an empty Running tab is not a failed search.
  function profilesEmpty(scoped){
    if(!state.profiles.length)return state.errors?.length?setupError():emptyState("No Claude or ChatGPT profiles yet","Choose an installed app and name the profile. It keeps its own sign-in, apart from the app’s original account.",button("Create your first profile","add",{primary:true,icon:"plus"}));
    if(!scoped.length)return query?emptyState(`No profiles match “${escape(query)}”`,"Check the spelling or clear the search.",button("Clear search","clear-search",{primary:true,icon:"x"})):emptyState("No matching profiles","Try another app.",button("Clear filters","reset-filters",{primary:true,icon:"search"}));
    const all=button("Show all profiles","show-all",{icon:"grid"});
    if(statusFilter==="running")return emptyState("Nothing is running","Open a profile and it shows up here.",all);
    if(statusFilter==="attention")return emptyState("Nothing needs repair",lastDoctor?`Every profile has its app, and doctor flagged none at ${time(lastDoctor.at)}.`:"Every profile has its app. Choose Check on Maintenance for a deeper check.",all);
    return emptyState("Every profile is running","Quit one and it shows up here.",all);
  }
  // A profile card: the app tile (its hue) carrying the profile's badge beside a real heading, then state, then the one primary action.
  // Enter on the name selects, as a click does; O runs the primary action only while focus is inside the selected card or the detail panel.
  function card(item){
    const t=tone(appName(item)),on=selected===item.name;
    const notes=[item.main?"Original account":"",item.own_extensions?"Own extensions":"",(item.args||[]).length?plural(item.args.length,"launch option"):""].filter(Boolean);
    const repair=needsRepair(item)?button("Repair","repair",{small:true,icon:"tool",name:item.name,label:`Repair, ${who(item)}`}):"";
    return `<article class="profile-card${t.cls}${on?" selected":""}${item.status==="running"?" running":""}"${t.style} aria-labelledby="${profileId(item.name)}"><div class="profile-head">${art(appName(item),item.badge,item.color)}<div class="profile-title"><h2><button class="profile-name" id="${profileId(item.name)}"${on?' aria-current="true"':""} title="${escape(item.name)}" data-action="select" data-name="${escape(item.name)}">${escape(item.profile||item.name)}</button></h2><p class="profile-app">${escape(appName(item))}</p></div></div><div class="profile-state-row">${statusMark(item)}${repair}${quitButton(item)}</div>${notes.length?`<p class="profile-meta">${notes.map(escape).join(" · ")}</p>`:""}${primaryButton(item,on)}</article>`;
  }
  // Detail: who, the command the primary action runs, then Settings, Rename and Remove; launch settings; paths and Rebuild behind Details.
  // From 768px the selected card beside or above it shows state, Quit and the primary action, so .detail-own (CSS) shows only below that.
  function detail(item){
    const t=tone(appName(item)),spec=JSON.stringify({action:"open",name:item.name}),command=previews.get(spec);
    const args=item.args||[],env=item.env||[];
    const launch=!args.length&&!env.length&&!item.own_extensions?'<p class="detail-defaults">Launch settings: app defaults</p>':`<dl class="details"><div><dt>Launch arguments</dt><dd>${args.length?args.map(arg=>`<code>${escape(arg)}</code>`).join("<br>"):"None"}</dd></div><div><dt>Environment variables</dt><dd>${env.length?escape(env.join(", "))+"<br><span class='small'>Values stay private</span>":"None"}</dd></div><div><dt>Extensions</dt><dd>${item.own_extensions?"Its own extensions folder":"The app’s default extensions"}</dd></div></dl>`;
    return `<aside class="detail-panel${t.cls}"${t.style} aria-labelledby="detail-title">${button("Back to profiles","back-profiles",{small:true,icon:"back"}).replace('class="button ','class="button detail-back ')}<div class="detail-top">${art(appName(item),item.badge,item.color)}<div class="detail-heading"><h2 id="detail-title" tabindex="-1">${escape(item.profile||item.name)}</h2><p class="detail-app">${escape(appName(item))}${item.main?" · original account":""}</p></div><button class="icon-button detail-close" data-action="close-detail" aria-label="Close details" title="Close details">${icon("x")}</button></div><div class="detail-own"><div class="profile-state-row">${statusMark(item)}${quitButton(item)}</div>${primaryButton(item,true)}</div><div class="command-echo detail-command" data-preview="${escape(spec)}"${command?"":" hidden"}><span class="command-label">Runs:</span><code>${commandHtml(command)}</code><button type="button" class="icon-button" data-action="copy-command" aria-label="Copy command" title="Copy command">${icon("copy")}</button></div><div class="detail-actions">${button("Settings","settings",{small:true,name:item.name,label:`Settings, ${who(item)}`})}${button("Rename","rename",{small:true,name:item.name,label:`Rename, ${who(item)}`})}${button("Remove","remove",{small:true,danger:true,name:item.name,label:`Remove, ${who(item)}`})}</div>${launch}<details class="advanced detail-more"${detailMore===item.name?" open":""}><summary>${icon("chevron")}<span>Details</span></summary><dl class="details"><div><dt>Application</dt><dd>${item.app_path?breakPath(item.app_path):escape(appName(item))}</dd></div><div><dt>Profile data</dt><dd>${item.main?"The app’s own original account":item.data_dir?breakPath(item.data_dir):"No folder recorded"}</dd></div><div><dt>Made by</dt><dd>${escape(item.built_by||"Not recorded")}</dd></div></dl><div class="detail-rebuild"><p>Makes the small app that opens this profile again from its saved settings. Its data is not touched.</p>${button("Rebuild launcher","rebuild",{small:true,icon:"rebuild",name:item.name,label:`Rebuild launcher, ${who(item)}`})}</div></details></aside>`;
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
  // Every listed app is a card, apps with profiles first; its count opens Profiles for that app.
  function renderApps(){
    const apps=sortedApps().filter(item=>!query||item.name.toLowerCase().includes(query.toLowerCase()));
    const cards=apps.map(item=>{const t=tone(item.name),count=plural(profileCount(item.name),"profile");return `<article class="application-card${t.cls}"${t.style}><div class="app-head">${art(item.name)}<div><h2>${escape(item.name)}</h2><button class="link-button app-count" data-app-filter="${escape(item.name)}" aria-label="${escape(`${count} for ${item.name}`)}">${count}</button></div></div>${button("Add profile","add",{icon:"plus",app:item.name,label:`Add profile for ${item.name}`})}</article>`;}).join("");
    const empty=!state.apps.length&&state.errors?.length?setupError():state.apps.length?`<div class="empty-state"><h2>No apps match “${escape(query)}”</h2><p>Check the spelling or clear the search to see ${state.apps.length===1?"the 1 app":`all ${state.apps.length} apps`}.</p>${button("Clear search","clear-search",{primary:true,icon:"x"})}</div>`:'<div class="empty-state"><h2>No AI apps found</h2><p>Install Claude or ChatGPT, then refresh this workspace.</p>'+button("Refresh apps","refresh",{icon:"refresh"})+"</div>";
    paint(title("Applications",!state.apps.length&&state.errors?.length?"Inventory unavailable.":`${state.apps.length} AI ${state.apps.length===1?"app":"apps"} found on this Mac.`)+`<div class="toolbar">${searchField("Search installed apps")}</div><div class="apps-body"><div class="apps-grid">${apps.length?cards:empty}</div></div>`);
  }
  function renderRecovery(){
    const entries=state.restorable||[],unclaimed=state.unclaimed||[];
    // A list the server could not read is unknown, not empty: say so instead of "Nothing …".
    const restorableFailed=state.restorable_ok===false,unclaimedFailed=state.unclaimed_ok===false;
    const unread=what=>`<p class="muted">Could not read ${what}. Refresh to try again.</p>`;
    main.innerHTML=title("Recovery","Bring back profiles whose launcher was removed; their data is still on this Mac.","",LAUNCHER)+
    `<section class="panel">${tile("recovery","recovery")}<div class="panel-heading"><h2>${entries.length?`${plural(entries.length,"profile")} to restore`:restorableFailed?"Profiles to restore":"Nothing to restore"}</h2>${entries.length?button("Restore all","restore-all",{icon:"recovery"}):""}</div>${entries.length?`<div class="recovery-list">${entries.map(item=>`<div class="recovery-row"><div><h3>${escape(item.name)}</h3><p>The profile data remains on this Mac.</p></div>${button("Restore","restore",{icon:"recovery",name:item.name,label:`Restore ${item.name}`})}</div>`).join("")}</div>`:restorableFailed?unread("restorable profiles"):'<p class="muted">Every profile with kept data already has a launcher.</p>'}</section>`+
    `<section class="operation-card section-gap">${tile("danger","trash")}<h2>${unclaimed.length||unclaimedFailed?"Clear unclaimed data":"Nothing unclaimed"}</h2>${unclaimedFailed?unread("unclaimed data"):""}<p>Unclaimed data is a profile folder that no launcher uses. Clearing moves it to the Trash, so restore any profile you want to keep first.</p><div class="button-row">${button("Clear unclaimed data…","prune",{danger:true,icon:"trash",disabled:!unclaimed.length})}</div></section>`;
  }
  const LAUNCHER="A launcher is the small app aidentity makes to open a profile.";
  // The latest doctor run, read from the server's summary and findings; the raw output stands in when they are absent.
  function healthResult(){
    if(!lastDoctor)return "";
    const {result,at}=lastDoctor,sum=result.summary,findings=Array.isArray(result.findings)?result.findings:null;
    const words={error:"Error",warn:"Warning",ok:"OK"},order={error:0,warn:1,ok:2};
    const count=(n,one,tone)=>`<span${n>0?` class="${tone}"`:""}><strong class="num">${n||0}</strong> ${n===1||one==="OK"?one:`${one}s`}</span>`;
    const head=`<p class="health-summary">${sum?count(sum.ok,"OK","positive")+count(sum.warn,"warning","warning")+count(sum.error,"error","negative"):""}<time>Checked ${time(at)}</time></p>`;
    const body=findings?`<ul class="health-findings">${[...findings].sort((a,b)=>(order[a.level]??3)-(order[b.level]??3)).map(item=>`<li data-level="${escape(item.level)}">${icon(item.level==="ok"?"check":"alert")}<span class="finding-level">${words[item.level]||escape(item.level)}</span><span>${!item.profile?escape(item.text):item.text===item.profile?`<strong>${escape(item.profile)}</strong>`:`<strong>${escape(item.profile)}:</strong> ${escape(item.text)}`}</span></li>`).join("")}</ul>`:`<pre class="output">${escape([result.stdout,result.stderr].filter(Boolean).join("\n")||"No output.")}</pre>`;
    return `<div class="health-result">${head}${body}${healthIssues()?'<p class="health-next">Next step: <strong>Check and repair</strong> rebuilds the launchers it can fix.</p>':""}</div>`;
  }
  const healthIssues=()=>{const sum=lastDoctor?.result.summary;return sum?(sum.warn||0)+(sum.error||0):0;};
  function renderMaintenance(){
    const issues=healthIssues();
    // Update now appears only once a check has found a newer version.
    const update=lastUpdate?`<p class="update-status">${escape(lastUpdate.text)} <time class="small">Checked ${time(lastUpdate.at)}</time></p>`:"";
    main.innerHTML=title("Maintenance","Check your setup, rebuild launchers and keep aidentity current.","",LAUNCHER)+
    `<div class="operation-grid"><section class="operation-card wide">${tile("maintenance","shield")}<h2>Workspace health</h2><p>Doctor checks your setup and every profile for missing apps, stale launchers and settings problems.</p>${healthResult()||'<p class="health-empty">Not checked yet.</p>'}<div class="button-row">${button("Check","doctor",{primary:!issues,icon:"shield"})}${button("Check and repair","doctor-fix",{primary:issues>0,icon:"tool"})}</div><p class="health-hint">Check only reports. Check and repair also rebuilds the launchers it can fix.</p></section><section class="operation-card">${tile("maintenance","update")}<h2>aidentity updates</h2><p>Installed version: <span class="num">${escape(state.version)}</span>.</p>${update}<div class="button-row">${button("Check for updates","update-check",{icon:"update"})}${lastUpdate?.available?button("Update now","update",{primary:true,icon:"update"}):""}</div></section><section class="operation-card">${tile("maintenance","rebuild")}<h2>Rebuild launchers</h2><p>Rebuild makes every launcher again from its saved settings and the app’s current location. Profile data is not touched.</p><div class="button-row">${button("Rebuild all","rebuild-all",{icon:"rebuild"})}</div></section></div>`+
    `<section class="storage-panel" aria-labelledby="storage-title"><h2 id="storage-title">Local storage</h2><dl class="details storage-list"><div><dt>Launchers</dt><dd>${state.paths?.launchers?breakPath(state.paths.launchers):"Not available"}</dd></div><div><dt>Profile data</dt><dd>${state.paths?.data?breakPath(state.paths.data):"Not available"}</dd></div></dl></section>${errorNotice()}`;
  }
  function renderTransfer(){
    main.innerHTML=title("Import & export","Move your profiles to another Mac. Sign-ins and profile data stay on this one.")+
    `<div class="operation-grid"><section class="operation-card">${tile("transfer","download")}<h2>Export</h2><p>Save the names, badges, colors and launch settings of ${plural(inventory.profiles.length,"profile")} to a file.</p><p class="callout">${icon("alert")}<span>The file can hold private environment or proxy values. Keep it private.</span></p><div class="button-row">${button("Export profiles","export",{primary:true,icon:"download"})}</div></section><section class="operation-card">${tile("transfer","upload")}<h2>Import</h2><p>Choose an aidentity export file and review it. Each profile is made with the apps installed here.</p><p>Imported profiles start signed out unless their data is already on this Mac.</p><div class="button-row">${button("Import profiles","import",{icon:"upload"})}</div></section></div>`;
  }
  const terms=[["Profile","An app opened with its own sign-in and data. You add, open and remove profiles."],["Launcher","The small app aidentity makes to open a profile."],["Original account","The app’s own account, opened through aidentity."],["Doctor","Checks your setup and every profile for problems."],["Unclaimed data","Profile data that no launcher uses. Clearing it moves it to the Trash."],["Restore","Makes a removed profile’s launcher again from its kept data."]];
  function renderGuide(){
    const commands=["","setup","ui","add","list","open","quit","rename","set","prune","restore","rebuild","rm","export","import","apps","doctor","update","completion","version","help","dashboard"];
    main.innerHTML=title("Help","Plain-word terms and keys, then the CLI’s own help and shell completion for your terminal.")+
      `<section class="terms" aria-labelledby="terms-title"><h2 id="terms-title">Terms</h2><dl>${terms.map(([term,text])=>`<div><dt>${term}</dt><dd>${text}</dd></div>`).join("")}<div class="terms-keys"><dt>Keyboard</dt><dd><kbd>/</kbd> search · <kbd>⌘B</kbd> collapse sidebar · <kbd>O</kbd> open the focused profile</dd></div></dl></section>`+
      `<div class="guide-layout"><section class="panel guide-controls"><div class="field"><label for="help-command">Command help</label><select id="help-command">${commands.map(command=>`<option value="${command}"${command===guideCommand?" selected":""}>${command||"All commands"}</option>`).join("")}</select><div class="section-gap">${button("Read help","help",{icon:"book"})}</div></div><div class="field"><label for="completion-shell">Shell completion</label><select id="completion-shell">${["zsh","bash","fish"].map(shell=>`<option${shell===guideShell?" selected":""}>${shell}</option>`).join("")}</select><div class="section-gap">${button("Generate completion","completion",{icon:"terminal"})}</div></div></section><section><div class="panel-heading"><h2>Command output</h2>${button("Copy output","copy-guide",{small:true,icon:"copy",disabled:!guideText})}</div>${guideText?`<pre class="output guide-output">${escape(guideText)}</pre>`:'<p class="guide-empty">Choose a command to read its help, or generate a completion script for your shell.</p>'}</section></div>`;
  }
  async function refresh(options={}){
    // loading is the read in flight: a polled read yields to it, a forced one (after an action) waits and then runs its own.
    while(loading){if(!options.force)return null;await loading;}
    let release;loading=new Promise(resolve=>{release=resolve;});let changed=null;
    try{
      const response=await fetch(options.force?"/api/state?fresh=1":"/api/state",{cache:"no-store"});
      const data=await response.json();
      if(!response.ok||!data.ok)throw Object.assign(new Error(data.error||"Could not read the workspace."),{server:true});
      const firstLoad=!state;
      // inventory keeps every entry for counts of CLI-wide actions and the import preview; recovery lists stay whole in state too.
      inventory=data;
      state={...data,apps:data.apps.filter(item=>AI_APPS.includes(item.name)),profiles:data.profiles.filter(item=>AI_APPS.includes(appName(item)))};
      registerAppAccents(state);
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
      if(options.notify)toast("Workspace refreshed","Profiles and installed apps are up to date.");
    }catch(error){
      // No reply at all (or not JSON) means the server is gone; a reported error means it is up but could not read the setup.
      if(!error.server)setOffline(true);
      if(!state)main.innerHTML=title("Workspace unavailable","The local server could not read your setup.")+`<div class="notice error">${escape(error.server?error.message:OFFLINE)}</div><div class="section-gap">${button("Retry connection","refresh",{primary:true,icon:"refresh"})}</div>`;
      $("#freshness").textContent=loadedAt?`Last updated ${time(loadedAt)}`:"Connection unavailable";
      if(options.notify)toast(error.server?"Refresh failed":"Still disconnected",error.server?error.message:"Run “aidentity dashboard” in Terminal, then try again.",true);
    }finally{loading=false;release();}
    return changed;
  }
  function setOffline(on){
    if(offline===on)return;
    offline=on;document.body.classList.toggle("is-offline",on);
    const banner=$("#connection-banner");banner.hidden=!on;
    banner.innerHTML=on?"<strong>The dashboard stopped.</strong> Run <code>aidentity dashboard</code> in Terminal to reconnect.":"";
    $("#connection-state").textContent=on?"Disconnected":"Connected";$(".scope").title=on?"Disconnected from this Mac":"Connected to this Mac";
    syncControls();
  }
  // While an action runs or the server is gone, run-type controls wait (aria-disabled); navigation and copy stay usable.
  const freeActions=new Set(["select","close-detail","back-profiles","clear-search","all-apps","reset-filters","show-all","workspace","refresh","copy-guide","copy-command"]);
  function syncControls(){
    const lock=Boolean(busy)||offline;
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
  const verbs={open:"open",quit:"quit",add:"create the profile",set:"save the settings",rename:"rename",remove:"remove",restore:"restore",rebuild:"rebuild",prune:"clear unclaimed data",doctor:"check the workspace",import:"import",export:"export",update:"update",help:"read the help",completion:"generate completion"};
  const doing={open:"Opening…",quit:"Closing…",add:"Creating the profile…",set:"Saving the settings…",rename:"Renaming…",remove:"Removing…",restore:"Restoring…",rebuild:"Rebuilding…",prune:"Clearing unclaimed data…",doctor:"Running doctor…",import:"Importing…",export:"Exporting…",update:"Updating aidentity…",help:"Loading the help…",completion:"Generating completion…"};
  async function action(name,params={},element=null,{quiet=false}={}){
    if(busy||offline||!state?.csrf_token){
      const error=busy?Object.assign(new Error("Another action is still running. Try again when it finishes."),{busy:true}):new Error(OFFLINE);
      if(!quiet){toast(busy?"Still working":"Disconnected",error.message,busy?"info":true);error.reported=true;}
      throw error;
    }
    const before=state,beforeAll=inventory,from=focusOrigin(element);let note=null,entry=null;
    busy=name;setBusy(element,true);syncControls();
    $("#activity-toggle").hidden=false;$("#activity-summary").textContent=name==="update"&&params.check?"Checking for updates…":doing[name]||"Working…";
    try{
      let response,result;
      try{response=await post("/api/action",{action:name,...params});}
      catch(error){setOffline(true);entry=logActivity({action:name,ok:false,output:`${error.name}: ${error.message}\n${OFFLINE}`});throw new Error(OFFLINE);}
      try{result=await response.json();}catch{result={ok:false,error:`The dashboard sent an unreadable reply (HTTP ${response.status}).`};}
      if(response.status===409&&result.busy)throw Object.assign(new Error(result.error||"Another action is still running. Try again when it finishes."),{busy:true});
      entry=logActivity({action:name,ok:Boolean(result.ok),command:result.command,output:name==="export"&&result.ok?"Export file prepared for download.":[result.stdout,result.stderr,result.error].filter(Boolean).join("\n")});
      // Doctor reports findings with a non-zero exit; a summary means it ran, so it is a result, not a failure.
      const report=name==="doctor"&&Boolean(result.summary);
      if((!response.ok||!result.ok)&&!report)throw Object.assign(new Error(result.error||result.stderr||result.stdout||`${name} failed (exit ${result.exit_code}).`),{field:result.field});
      if(name==="doctor"){lastDoctor={result,at:new Date()};doctorFlags=new Set((result.findings||[]).filter(item=>item.profile&&(item.level==="warn"||item.level==="error")).map(item=>item.profile));saveDoctor();}
      if(name==="rebuild"){if(params.all)doctorFlags.clear();else doctorFlags.delete(params.name);saveDoctor();}
      if(name!=="add")note=describe(name,params,result,before);
      await refresh({force:true});
      if(name==="add"){result.created=inventory.profiles.find(item=>!beforeAll.profiles.some(old=>old.name===item.name))?.name||`${params.app} ${params.profile}`;note=describe(name,params,result,before);}
      entry.title=note.title;renderActivity();
      if(!quiet)toast(note.title,note.text,note.kind,note.extra);
      return result;
    }catch(error){
      const failure=error.busy?"Still working":error.message===OFFLINE?"Disconnected":`Could not ${verbs[name]||name}${params.name?` ${params.name}`:""}`;
      if(entry)entry.title=failure;
      if(!quiet&&!error.reported){toast(failure,String(error.message),error.busy?"info":true);error.reported=true;}
      renderActivity();
      throw error;
    }finally{busy=false;setBusy(element,false);syncControls();returnFocus(from);}
  }
  // Plain-words toast for a finished action. Runs before the post-action refresh (add after it, to learn the new name).
  function describe(name,params,result,before){
    const who=params.name||"",was=before?.profiles.find(item=>item.name===who);
    // A profile added by path for another app is created but hidden; say so only when the fresh full list has it.
    if(name==="add")return {title:`${result.created} is ready`,text:!profile(result.created)&&inventory.profiles.some(item=>item.name===result.created)?"The dashboard lists only Claude and ChatGPT, so it is not shown here. Open it now.":"Find it in Profiles, or open it now.",extra:{label:"Open it",run:()=>action("open",{name:result.created})}};
    if(name==="open"){
      if(was?.status==="running")return {title:`Brought ${who} to the front`};
      const key=`aidentity.signin-hint.${who}`,first=was?.status==="signed out / new"&&!stored.get(key);
      if(first)stored.set(key,"shown");
      return {title:`Opened ${who}`,text:first?SIGN_IN_HINT:"It opens in its own window."};
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
      return {title:`Checked ${plural(before.profiles.length,"profile")}: ${issues?`${issues} ${issues===1?"needs":"need"} attention`:"all healthy"}`,text:issues?(away?"The findings are in Maintenance.":"The findings are in Workspace health."):"Nothing needs repair.",kind:sum.error?"error":sum.warn?"warn":"ok",extra:issues&&away?{label:"Show findings",run:()=>showView("maintenance",{focus:true})}:null};
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
    $("#activity-content").innerHTML=history.map(item=>`<article class="activity-entry"><div class="activity-entry-title"><strong class="${item.ok?"":"activity-error"}">${escape(item.title||`${item.action} · ${item.ok?"Completed":"Failed"}`)}</strong><time>${time(item.time)}</time></div>${item.command?`<code class="activity-command">${commandHtml(item.command)}</code>`:""}<pre class="output">${escape(item.output||"Completed without additional output.")}</pre></article>`).join("")||'<p class="muted">Nothing run yet. Each action you run shows up here with its command.</p>';
    // The summary uses the toast's title; an entry gets it once its action finishes, so "Running…" stays until then.
    if(!history[0]||history[0].title)$("#activity-summary").textContent=history[0]?`${history[0].title} · View details`:"Activity · Nothing run yet";
  }
  // kind: true or "error", "warn", "info", or "ok"; extra: {label, run} adds a next-step button (Open it, Restore).
  function toast(titleText,description,kind=false,extra=null){
    const level=kind===true?"error":kind||"ok";
    const viewport=toastViewport;
    const node=document.createElement("div");node.className=`toast ${level==="ok"?"":level}`;node.setAttribute("role",level==="error"?"alert":"status");
    // A long error shows its first 180 characters; View details opens Activity, which keeps the full output.
    const text=String(description||""),long=text.length>180;
    node.innerHTML=`${icon(level==="ok"?"check":"alert")}<div><strong>${escape(titleText)}</strong>${text?`<p>${escape(long?`${text.slice(0,180).trimEnd()}…`:text)}</p>`:""}<div class="toast-actions">${extra?`<button class="toast-action toast-primary">${escape(extra.label)}</button>`:""}${history.length?`<button class="toast-action toast-activity">${long?"View details":"View activity"}</button>`:""}</div></div><button class="icon-button" aria-label="Dismiss notification">${icon("x")}</button>`;
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
  // A dialog opened from another (Settings → Rename) keeps the focus target of the first.
  function showDialog(titleText,description,body,submitText,submit,{danger=false,build=null,app=contextApp()}={}){
    clearTimeout(dialogCloseTimer);dialogRevision++;
    if(!dialog.open)lastFocus=document.activeElement;
    dialogBuild=build;dialogSubmit=submit||(async(data,el)=>{const spec=build(data);if(!spec)throw new Error("Nothing has changed yet.");await action(...spec,el);});dialog.classList.remove("closing");
    toneDialog(app);
    const echo=build?`<div class="command-echo" id="command-echo" hidden><span class="command-label">Runs:</span><code></code><button type="button" class="icon-button" data-action="copy-command" aria-label="Copy command" title="Copy command">${icon("copy")}</button></div>`:"";
    dialog.innerHTML=`<form id="dialog-form" class="dialog-inner"><header class="dialog-header"><h2 id="dialog-title">${escape(titleText)}</h2><p id="dialog-description">${escape(description)}</p><button type="button" class="icon-button" data-close-dialog aria-label="Close dialog">${icon("x")}</button></header><div class="dialog-body">${body}${echo}<div id="form-error" class="form-error" role="alert" hidden></div></div><footer class="dialog-footer"><button type="button" class="button" data-close-dialog>Cancel</button><button type="submit" class="button ${danger?"button-danger":"button-primary"}" id="dialog-submit">${escape(submitText)}</button></footer></form>`;
    if(!dialog.open)dialog.showModal();
    hostToasts();
    $("input:not([type=checkbox]):not(:disabled),select,textarea",$(".dialog-body",dialog))?.focus();
    animateMotion($(".dialog-header",dialog),[{opacity:0,translate:"0 5px"},{opacity:1,translate:"0 0"}],"surface",{duration:420,delay:25});
    const form=$("#dialog-form");
    if(build){form.addEventListener("input",()=>schedulePreview());form.addEventListener("change",()=>schedulePreview());schedulePreview(0);}
    form.onsubmit=async event=>{
      event.preventDefault();
      if($("#dialog-submit").hasAttribute("data-locked")){if(offline){$("#form-error").textContent=OFFLINE;$("#form-error").hidden=false;}return;}
      if(!form.reportValidity())return;
      $("#form-error").hidden=true;$$("[aria-invalid]",form).forEach(el=>el.removeAttribute("aria-invalid"));
      try{await dialogSubmit(new FormData(form),$("#dialog-submit"));closeDialog();}
      catch(error){$("#form-error").textContent=error.message;$("#form-error").hidden=false;const bad=error.field&&form.elements[error.field];if(bad?.setAttribute){bad.setAttribute("aria-invalid","true");bad.focus();}}
    };
  }
  // The command comes from the server (/api/preview, redacted); it is never assembled here. An empty required field sends no request; any error hides the line.
  function schedulePreview(delay=250){clearTimeout(previewTimer);previewTimer=setTimeout(runPreview,delay);}
  async function runPreview(){
    const echo=$("#command-echo",dialog),seq=++previewSeq;if(!echo||!dialogBuild)return;
    let spec=null;try{spec=dialogBuild(new FormData($("#dialog-form")));}catch{spec=null;}
    if(!spec||offline||!state?.csrf_token||$$("[required]",$("#dialog-form")).some(el=>!el.value.trim())){echo.hidden=true;return;}
    try{
      const response=await post("/api/preview",{action:spec[0],...spec[1]});
      const result=await response.json();
      if(seq!==previewSeq||!echo.isConnected)return;
      echo.hidden=!(response.ok&&result.ok&&result.command);
      if(!echo.hidden)$("code",echo).innerHTML=commandHtml(result.command);
    }catch{if(seq===previewSeq&&echo.isConnected)echo.hidden=true;}
  }
  // A modal dialog makes the rest of the page inert, so toasts move inside it while it is open; moving hides the popover, so show it again on top.
  function hostToasts(){const host=dialog.open?dialog:document.body;if(toastViewport.parentElement!==host){host.append(toastViewport);toastViewport.showPopover?.();}}
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
  const disclosure=(label,body)=>`<details class="advanced"><summary>${icon("chevron")}<span>${label}</span></summary><div class="fields">${body}</div></details>`;
  // The CLI takes six hex digits or a color word; a leading "#" is dropped here.
  const hexValue=value=>String(value||"").trim().replace(/^#/,"");
  // Paint the dialog in the app's hue (its primary button and focus rings), or leave it neutral.
  function toneDialog(app){const color=appAccent(app).color;dialog.classList.toggle("app-tone",Boolean(color));dialog.style.cssText=color?`--app-color:${color}`:"";}
  // Named swatches, the chosen one's name and hex as text, and the hex field behind "Custom color…" (open when the color is not a swatch).
  // data-auto: the hex follows the app's default badge until edited.
  function identityFields(p=null,fallback=defaultBadgeColor){
    const color=String(p?.color||fallback).toUpperCase(),custom=!colors.some(([,hex])=>hex===color);
    return `<div class="field"><p class="field-label" id="badge-color-label">Badge color</p><div class="color-options" role="group" aria-labelledby="badge-color-label">${colors.map(([name,hex])=>`<button type="button" class="color-swatch" style="--swatch:#${hex}" data-color="${hex}" title="${name} · ${hex}" aria-label="${name}" aria-pressed="${color===hex}"></button>`).join("")}</div><div class="color-meta"><span class="color-current">${escape(colorName(color))}</span><button type="button" class="link-button" data-custom-color aria-expanded="${custom}" aria-controls="custom-color">Custom color…</button></div><div id="custom-color"${custom?"":" hidden"}>${field("Hex color","color",color,"Six hex digits, like B26BFF.","text",`maxlength="8" spellcheck="false" autocomplete="off"${p?"":" data-auto"}`)}</div></div>${field("Badge character","badge",p?.badge||"","Shown on the app icon.","text",'maxlength="4"')}${check("no_badge","Use the original app icon","Hide the colored badge.",p?.badge===null)}`;
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
    showDialog("Create a profile","Each profile opens the app with its own sign-in and data.",`<div class="preview-row"><div class="preview-identity" id="identity-preview"></div></div><div class="fields"><div class="field"><label for="field-app">Application</label><select name="app" id="field-app" required>${options||'<option value="">No AI apps found</option>'}</select></div>${field("Profile name","profile","","For example, Work, Personal, or Client.","text",'required maxlength="40"')}${check("main","Use the original account","Opens the app’s own account through aidentity instead of a new, separate one.")}${disclosure("Appearance",identityFields(null,badgeDefault(chosen)))}${disclosure("App location & launch settings",`${field("Application path (optional)","app_path","","Use a full .app path for an application outside discovery.","text",'placeholder="/Applications/Example.app"')}<div id="seed-option">${check("seed","Copy Claude’s MCP configuration","Copies the existing Claude Desktop configuration into the new profile.")}</div>${area("Launch arguments","args","One allowed switch per line, for example --lang=de.")}${area("Environment variables","env","One allowed NAME=value per line. Values are never displayed in this dashboard.")}${check("own_extensions","Use a separate extensions folder","For VS Code-style applications.")}`)}</div>`,"Create profile",async(data,el)=>{
      const result=await action(...build(data),el);
      stored.set("aidentity.last-app",data.get("app"));
      revealProfile(result.created);
    },{build,app:chosen});
    setupPreview();
    if(picked)$('[name="profile"]',dialog).focus();
    $('[name="main"]',dialog).onchange=event=>{if(event.target.checked&&!$('[name="profile"]',dialog).value)$('[name="profile"]',dialog).value="Main";setupPreviewUpdate();};
  }
  // After Add: Profiles, the new card selected, scrolled into view, one gentle ring, and focus on its name once the dialog closes.
  function revealProfile(name){
    query="";statusFilter="all";selected=name||"";if(name)stored.set(LAST_PROFILE,name);
    showView("profiles",{app:"",instant:true});// the card is looked up right after, so the page swaps now
    const target=$$(".profile-name",main).find(el=>el.dataset.name===name);if(!target)return;
    const cardNode=target.closest(".profile-card");
    cardNode.scrollIntoView({block:"center",behavior:reducedMotion.matches?"instant":"smooth"});
    lastFocus=target;
    animateMotion(cardNode,[{outlineOffset:"12px",outlineColor:"transparent"},{outlineOffset:"0px"}],"surface",{duration:900,delay:220});
  }
  const lines=value=>String(value||"").split(/\r?\n/).map(v=>v.trim()).filter(Boolean);
  function setupPreview(){
    $('[name="color"]',dialog)?.addEventListener("input",event=>event.target.removeAttribute("data-auto"));
    $$('input,select,textarea',dialog).forEach(input=>input.addEventListener("input",setupPreviewUpdate));setupPreviewUpdate();
  }
  // The preview shows what is set: the app alone until a profile name is typed, and a badge only once there is one.
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
    preview.innerHTML=art(app,badge,hex)+`<div>${label?`<strong>${escape(label)}</strong>`:""}<span class="small">${original?"Opens the app’s original account":"Keeps its own sign-in"}</span></div>`;
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
    showDialog(`Settings for ${item.name}`,"Launch changes apply the next time it opens.",`<div class="preview-row"><div class="preview-identity" id="identity-preview" data-app="${escape(appName(item))}" data-profile="${escape(item.profile||"")}" data-quiet data-main="${Boolean(item.main)}"></div><button type="button" class="link-button" data-action="rename" data-name="${escape(item.name)}">Rename…</button></div><div class="fields">${identityFields(item)}${disclosure("Launch settings",`${area("Launch arguments","args","One allowed switch per line. Saving replaces the list; empty it to remove them all.",args)}<div class="field"><p class="field-label">Environment variables</p><p class="small">${env.length?`${escape(env.join(", "))} · values stay private`:"None"}</p></div>${area(env.length?"Add or change environment variables":"Add environment variables","env","One allowed NAME=value per line. Values are never shown here.")}${env.length?check("clear_env","Clear the existing variables first","Values entered above are added after clearing."):""}<div class="field"><label for="field-extensions">Extensions folder</label><select id="field-extensions" name="extensions"><option value="shared"${!item.own_extensions?" selected":""}>The app’s default extensions</option><option value="own"${item.own_extensions?" selected":""}>Its own extensions folder</option></select></div>`)}</div>`,"Save settings",async(data,el)=>{
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
    showDialog("Rename profile","The name changes; the profile stays signed in.",`<div class="fields">${field("Current name","current",item.name,"","text","disabled")}${field("New profile name","new_name",item.profile,"The app name is added by aidentity.","text","required maxlength=\"40\"")}</div>`,"Rename profile",async(data,el)=>{
      await action("rename",{name:item.name,new_name:data.get("new_name")},el);
      selected=`${appName(item)} ${data.get("new_name")}`;stored.set(LAST_PROFILE,selected);
      renderView();
    },{build:data=>["rename",{name:item.name,new_name:data.get("new_name")}],app:appName(item)});
  }
  // An original-account profile has no data of its own, so there is nothing to move to the Trash.
  function removeDialog(item){
    const body=item.main?`<p class="muted">This is ${escape(appName(item))}’s original account. Removing the profile only stops aidentity from opening it; the app and its sign-in stay as they are.</p>`:`<div class="danger-callout">${icon("alert")}<span>Removes the profile from your workspace. Its data stays on this Mac unless you choose to delete it.</span></div><p class="muted section-gap">With its data kept, you can restore the profile later from Recovery.</p><div class="section-gap">${check("purge","Also move the profile data to the Trash","Its sign-in and local data leave this workspace.")}</div>`;
    showDialog(`Remove ${item.name}?`,item.main?"The app itself is not touched.":"You can restore it while its data is kept.",body,"Remove profile",async(data,el)=>{await action("remove",{name:item.name,purge:data.has("purge"),confirmed:true},el);if(selected===item.name)selected="";},{danger:true,build:data=>["remove",{name:item.name,purge:data.has("purge"),confirmed:true}],app:appName(item)});
    const purge=$('[name="purge"]',dialog);
    if(purge)purge.addEventListener("change",()=>{$("#dialog-submit").textContent=purge.checked?"Remove and move data to Trash":"Remove profile";});
  }
  // An app-missing profile cannot be fixed by a rebuild alone: say what to do first, then offer the rebuild.
  function repairDialog(item){
    const app=appName(item);
    showDialog(`Repair ${item.name}`,`${app} is not where this profile expects it.`,`<p class="muted">Reinstall ${escape(app)} or move it back to your Applications folder. Then rebuild the profile so it finds the app again. Its data is not touched.</p>`,"Rebuild",null,{build:()=>["rebuild",{name:item.name}],app});
  }
  const targetList=names=>names.length?`<ul class="target-list">${names.map(name=>`<li>${escape(name)}</li>`).join("")}</ul>`:"";
  // body is plain text; extra is trusted HTML built with escape() (target lists).
  function confirmAction(titleText,description,body,submit,name,params={},danger=false,extra=""){
    showDialog(titleText,description,`<p class="muted">${escape(body)}</p>${extra}`,submit,null,{danger,build:()=>[name,params]});
  }
  function importDialog(){
    importDocument=null;
    showDialog("Import profiles","Choose a JSON file made by aidentity export.",`<div class="field"><label for="import-file">Export file</label><input class="input file-input" type="file" id="import-file" accept=".json,application/json" aria-describedby="hint-import" required><p class="hint" id="hint-import">Maximum file size: 4 MiB. Sign-ins are not imported.</p></div><div id="import-preview" class="import-preview" hidden></div>`,"Import profiles",async(_,el)=>{
      if(!importDocument)throw new Error("Choose and review a valid aidentity export file first.");
      const result=await action("import",{document:importDocument,confirmed:true},el,{quiet:true});
      const note=describe("import",{},result);toast(note.title,note.text,note.kind);showView("profiles",{app:""});
    },{build:()=>importDocument?["import",{document:importDocument,confirmed:true}]:null});
    $("#import-file").onchange=async event=>{
      importDocument=null;$("#import-preview").hidden=true;$("#form-error").hidden=true;$("#dialog-submit").textContent="Import profiles";$("#dialog-submit").disabled=false;
      try{
        const file=event.target.files[0];if(!file)return;
        if(file.size>4194304)throw new Error("The export file is larger than 4 MiB.");
        const data=JSON.parse(await file.text());if(data.aidentity_export!==1||!Array.isArray(data.launchers))throw new Error("Choose a format 1 aidentity export file.");
        importDocument=data;$("#import-preview").hidden=false;
        // An estimate from the dashboard's own lists: the CLI matches apps by bundle ID and checks again when it runs.
        const owned=new Set(inventory.profiles.map(item=>item.name)),apps=new Set(inventory.apps.map(item=>item.name));
        const fates={create:"will create",exists:"already exists (skipped)",missing:"app not installed (skipped)"};
        const rows=data.launchers.map(item=>{const name=String(item?.name||[item?.app,item?.profile].filter(Boolean).join(" ")||"Unnamed profile");return {name,fate:owned.has(name)?"exists":(item?.app?!apps.has(item.app):!item?.bundle_id)?"missing":"create"};});
        const count=fate=>rows.filter(row=>row.fate===fate).length,create=count("create");
        $("#import-preview").innerHTML=`<p class="import-summary"><strong>${plural(create,"profile")} will be created</strong>${count("exists")?` · ${count("exists")} already ${count("exists")===1?"exists":"exist"}`:""}${count("missing")?` · ${plural(count("missing"),"app")} not installed`:""}</p><ul class="import-list">${rows.map(row=>`<li data-fate="${row.fate}"><span>${escape(row.name)}</span><span class="import-fate">${fates[row.fate]}</span></li>`).join("")}</ul><p class="small">From ${escape(file.name)}. The CLI checks each profile again when it runs.</p>`;
        // "App not installed" is only the estimate above, so it never blocks the import; only a list of profiles that all exist (or none) does.
        const submit=$("#dialog-submit"),nothing=rows.every(row=>row.fate==="exists");submit.textContent=create?`Create ${plural(create,"profile")}`:nothing?"Nothing to create":"Import profiles";submit.disabled=nothing;
        schedulePreview(0);
      }catch(error){$("#form-error").textContent=error.message;$("#form-error").hidden=false;}
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
    if(name==="all-apps"){appFilter="";renderView();return;}
    if(name==="show-all"){statusFilter="all";renderProfiles();positionTabs();$("#status-all")?.focus();return;}
    if(name==="repair"&&item)return item.status==="app missing"?repairDialog(item):confirmAction(`Repair ${item.name}?`,"Doctor found a problem with how this profile opens.","Rebuild makes it again from its saved settings and the app’s current location. Its data is not touched.","Rebuild","rebuild",{name:item.name});
    if(name==="copy-command"){
      const code=el.closest(".command-echo")?.querySelector("code")?.textContent;if(!code)return;
      await navigator.clipboard.writeText(code);el.innerHTML=icon("check");el.setAttribute("aria-label","Copied");
      setTimeout(()=>{if(el.isConnected){el.innerHTML=icon("copy");el.setAttribute("aria-label","Copy command");}},1500);return;
    }
    if(name==="reset-filters"){query="";appFilter="";statusFilter="all";renderView();return;}
    if(name==="settings"&&item)return settingsDialog(item);
    if(name==="rename"&&item)return renameDialog(item);
    if(name==="remove"&&item)return removeDialog(item);
    if(name==="open"||name==="quit"||name==="restore"||name==="rebuild")return action(name,{name:el.dataset.name},el);
    if(name==="restore-all")return confirmAction("Restore all launchers?","Reconnect every restorable profile.",`${plural(state.restorable.length,"recorded profile")} will get new launchers using their existing profile data.`,"Restore all","restore",{all:true},false,targetList(state.restorable.map(entry=>entry.name)));
    if(name==="rebuild-all")return confirmAction("Rebuild all launchers?","Refresh launcher bundles for every profile.",`${plural(inventory.profiles.length,"launcher")} will be rebuilt. Each profile keeps its data.`,"Rebuild all","rebuild",{all:true});
    if(name==="prune"){
      const names=(state.unclaimed||[]).map(entry=>entry.name);
      return confirmAction("Clear unclaimed data?","Unclaimed data is profile data that no launcher uses. Clearing moves it to the Trash.",`${plural(names.length,"profile folder")} will move to the Trash. Restore the ones you want to keep first.`,"Clear unclaimed data","prune",{confirmed:true},true,targetList(names));
    }
    if(name==="doctor")return action("doctor",{},el);
    if(name==="doctor-fix")return confirmAction("Check and repair the workspace?","Run doctor with automatic fixes.","Doctor checks the setup, then rebuilds the launchers it can fix.","Check and repair","doctor",{fix:true});
    if(name==="update-check")return action("update",{check:true},el);
    if(name==="update")return confirmAction("Install the latest aidentity?","Update this CLI installation.","The CLI checks its release source and installation before replacing the current executable.","Update aidentity","update",{check:false});
    if(name==="import")return importDialog();
    if(name==="export")return showDialog("Export profiles?","Download your profiles’ settings as a JSON file.",`<p class="callout">${icon("alert")}<span>The file includes launch settings and can hold private environment or proxy values. Keep it private.</span></p><p class="muted section-gap">Sign-ins and profile data stay on this Mac.</p>`,"Export profiles",async(_,submit)=>{await exportSetup(submit);},{build:()=>["export",{}]});
    if(name==="help"||name==="completion"){
      const command=guideCommand=$("#help-command").value,params=name==="help"?(command?{command}:{}):{shell:guideShell=$("#completion-shell").value};
      try{guideText=(await readOutput(name,params,el)).stdout;}
      catch(error){toast(name==="help"?"Could not read the help":"Could not generate completion",error.message,true);return;}
      // In one column (900px and below) the output sits under the controls: bring its top into view.
      renderGuide();$(`[data-action="${name}"]`,main)?.focus({preventScroll:true});
      const output=$(".guide-output",main);if(output&&output.getBoundingClientRect().top>innerHeight*.6)output.scrollIntoView({block:"start",behavior:reducedMotion.matches?"instant":"smooth"});
      return;
    }
    if(name==="copy-guide"&&guideText){await navigator.clipboard.writeText(guideText);toast("Copied","Command output copied to your clipboard.");}
  }
  // The visible button runs it (the panel's own copy is hidden from 768px), so its spinner and focus return show where the user looks.
  function runPrimary(){
    const item=profile(selected),el=$$(".open-profile",main).find(button=>button.dataset.name===item.name&&button.checkVisibility());
    if(el?.hasAttribute("data-locked"))return;
    action("open",{name:item.name},el).catch(()=>{});
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
    if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==="b"){event.preventDefault();toggleNavigation();}
    if(event.key==="Escape"&&document.body.classList.contains("mobile-nav-open")){closeNavigation();$("#mobile-nav").focus();}
    if(event.key==="/"&&!event.metaKey&&!event.ctrlKey&&!event.altKey&&!dialog.open&&!event.target.closest?.("input,textarea,select,[contenteditable]")){const search=$("#workspace-search");if(search){event.preventDefault();search.focus();search.select();}}
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
  dialog.addEventListener("click",event=>{if(event.target===dialog){const rect=dialog.getBoundingClientRect();if(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)closeDialog();}});
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
  hydrateIcons();renderNav();renderActivity();refresh();schedulePoll();
})();
