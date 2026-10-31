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
  const button = (label, action, opts = {}) => `<button class="button ${opts.primary ? "button-primary" : ""} ${opts.danger ? "button-danger" : ""} ${opts.small ? "button-small" : ""}" data-action="${escape(action)}"${opts.name ? ` data-name="${escape(opts.name)}"` : ""}${opts.app ? ` data-app="${escape(opts.app)}"` : ""}${opts.disabled ? " disabled" : ""}${opts.label ? ` aria-label="${escape(opts.label)}"` : ""}>${opts.icon ? icon(opts.icon) : ""}<span>${escape(label)}</span></button>`;
  const cliColors = {blue:"2E7DF6",green:"2FB344",red:"E5484D",orange:"F76B15",purple:"8E4EC6",pink:"D6409F",teal:"12A594",yellow:"F5B400",gray:"6B7280",grey:"6B7280",graphite:"1F2430",black:"1F2430"};
  const defaultBadgeColor="5FE08A";
  const luminance=hex=>[0,2,4].map(i=>parseInt(String(hex).replace("#","").slice(i,i+2),16)/255).map(c=>c<=.04045?c/12.92:((c+.055)/1.055)**2.4).reduce((sum,c,i)=>sum+c*[.2126,.7152,.0722][i],0);
  // Badge letter ink: Lampblack or white, whichever contrasts more with the badge (WCAG 1.4.3).
  const inkFor=hex=>(luminance(hex)+.05)/(luminance("060606")+.05)>=(luminance("ffffff")+.05)/(luminance(hex)+.05)?"#060606":"#ffffff";
  // The eight app hues live in styles.css (--hue-*); order matches the saved accent assignments.
  // Frozen copy of those tokens, used only when one is missing or not #rrggbb.
  const hueNames=["mint","periwinkle","teal","orange","pink","gold","sky","violet"],hueDefaults=["#5fe08a","#7c8cff","#2fd4c0","#ff8a3d","#ff6fb5","#ffd166","#4cc3ff","#b26bff"];
  const appPalette=hueNames.map((hue,i)=>{const hex=getComputedStyle(document.documentElement).getPropertyValue(`--hue-${hue}`).trim().toLowerCase();return /^#[0-9a-f]{6}$/.test(hex)?hex:(console.warn(`--hue-${hue} is missing or not #rrggbb; using ${hueDefaults[i]}`),hueDefaults[i]);});
  const colors=[...hueNames.map((hue,i)=>[hue[0].toUpperCase()+hue.slice(1),appPalette[i].slice(1).toUpperCase()]),["Gray","8D8B84"],["Graphite","262624"]];
  const appAccentAssignments=new Map();
  const appKey=name=>String(name||"App").trim().toLowerCase();
  function appHash(name){
    let hash=2166136261;
    for(const character of appKey(name))hash=Math.imul(hash^character.codePointAt(0),16777619)>>>0;
    return hash;
  }
  function registerAppAccents(data){
    const names=[...new Set([...(data.apps||[]).map(item=>item.name),...(data.profiles||[]).map(item=>item.app||"Unknown app")])].sort((a,b)=>a.localeCompare(b));
    const used=new Set(names.map(name=>appAccentAssignments.get(appKey(name))).filter(index=>index!==undefined));
    for(const name of names){
      const key=appKey(name);if(appAccentAssignments.has(key))continue;
      const preferred=appHash(name)%appPalette.length;
      let index=preferred;
      for(let offset=0;offset<appPalette.length;offset++){
        const candidate=(preferred+offset)%appPalette.length;
        if(!used.has(candidate)){index=candidate;break;}
      }
      appAccentAssignments.set(key,index);used.add(index);
    }
  }
  function appAccent(name){
    const index=appAccentAssignments.get(appKey(name))??appHash(name)%appPalette.length;
    return {color:appPalette[index],secondary:appPalette[(index+3)%appPalette.length]};
  }
  const appTone=name=>{const tone=appAccent(name);return `--app-color:${tone.color};--app-color-secondary:${tone.secondary}`;};
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
    const animation=element.animate(frames,{duration:kind==="control"?360:520,easing:motionCurve(kind),fill:"backwards",...options});
    motionAnimations.set(element,animation);
    animation.finished.catch(()=>{}).finally(()=>{if(motionAnimations.get(element)===animation)motionAnimations.delete(element);});
    return animation;
  }
  function animateWorkspaceChange(){
    if(view==="explore"||reducedMotion.matches)return;
    const blocks=$$(".title-row,.stat-line,.tabs,.toolbar,.profile-card,.application-card,.operation-card,.panel,.guide-output",main);
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
  let state = null, view = [...navigation.map(item=>item[0]),"guide"].includes(initialRoute)?initialRoute:"explore", query = "", appFilter = "", statusFilter = "all", selected = "", mobileDetail = false;
  let cleanupExperience = null, lastData = "", loadedAt = null, loading = false, busy = false, dialogSubmit = null, lastFocus = null;
  let history = [], guideText = "", importDocument = null, tabPosition=null, tabScroll=0;
  let dialogRevision=0,dialogCloseTimer=null,navCloseTimer=null;
  let offline=false,lastDoctor=null,lastUpdate="",doctorFlags=new Set(),dialogBuild=null,previewTimer=null,previewSeq=0,exploreApp="";
  const time = date => new Intl.DateTimeFormat(undefined,{hour:"2-digit",minute:"2-digit"}).format(date);
  const profile = name => state?.profiles.find(item => item.name === name);
  const appName = item => item.app || "Unknown app";
  // Display words for CLI statuses, shared with Explore; the CLI values themselves stay as they are.
  const statusLabels={"running":"Running","in use":"At rest","not running":"At rest","signed out / new":"Not opened yet","app missing":"App missing"};
  const statusLabel=status=>statusLabels[status]||status;
  const plural=(count,one,many=`${one}s`)=>`${count} ${count===1?one:many}`;
  const lastLine=text=>String(text||"").trim().split("\n").pop().trim();
  // Escaped path that wraps after a slash instead of mid-word.
  const breakPath=value=>escape(value).replace(/\//g,"/<wbr>");
  const contextApp=()=>(view==="explore"&&exploreApp)||profile(selected)?.app||appFilter;
  const needsRepair=item=>item.status==="app missing"||doctorFlags.has(item.name);
  const OFFLINE="The dashboard stopped. Run “aidentity dashboard” in Terminal to reconnect.";
  const SIGN_IN_HINT="Sign in once in the window that opens. aidentity remembers it.";
  // localStorage can throw (disabled or private storage); the in-memory copy keeps this session consistent.
  const memory=new Map();
  const stored={get:key=>{try{return localStorage.getItem(key)??memory.get(key)??null;}catch{return memory.get(key)??null;}},set:(key,value)=>{memory.set(key,value);try{localStorage.setItem(key,value);}catch{}}};
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
  function hydrateIcons(root=document) { $$("[data-icon]",root).forEach(el => {el.innerHTML=icon(el.dataset.icon);el.removeAttribute("data-icon");}); }
  // Re-renders replace nodes; put focus back on the matching control so it never falls to <body>.
  const controlKey=el=>{const d=el?.dataset;if(!d||!el.matches("button,select,input,textarea,a[href]"))return null;const key=[el.id,d.view,d.appFilter,d.filter,{quit:"open"}[d.action]||d.action,d.name,d.app].join("|");return /[^|]/.test(key)?key:null;};
  function keepFocus(render){
    const key=controlKey(document.activeElement);render();
    if(key===null||(document.activeElement&&document.activeElement!==document.body))return;
    $$("button,select,input,textarea,a[href]").find(el=>controlKey(el)===key)?.focus({preventScroll:true});
  }
  let navApps=null;
  function renderNav() {
    if(!$("#primary-nav").children.length)$("#primary-nav").innerHTML=navigation.map(([id,label,glyph])=>`<button class="nav-item" data-view="${id}" title="${label}">${icon(glyph)}<span class="nav-label">${label}</span></button>`).join("");
    const apps = [...new Set((state?.profiles || []).map(appName))].sort();
    const appsKey=JSON.stringify([apps,Boolean(state?.errors?.length)]);
    if(appsKey!==navApps){navApps=appsKey;keepFocus(()=>{$("#app-nav").innerHTML=apps.map(name=>`<button class="nav-item nav-app" style="${appTone(name)}" data-app-filter="${escape(name)}" title="${escape(name)}"><span class="app-mini"><span class="nav-app-dot" aria-hidden="true"></span></span><span class="nav-label">${escape(name)}</span></button>`).join("") || `<p class="small nav-label" style="padding:0 12px">${state?.errors?.length?"Inventory unavailable":"Add your first profile"}</p>`;});}
    $$("#sidebar [data-view]").forEach(el=>view===el.dataset.view?el.setAttribute("aria-current","page"):el.removeAttribute("aria-current"));
    $("#version").textContent=state?.version ? `aidentity ${String(state.version).replace(/^aidentity\s*/,"")}`:"aidentity";
    const viewName=navigation.find(item=>item[0]===view)?.[1] || "Command guide";
    $("#breadcrumb").textContent=viewName;document.title=`${viewName} · aidentity`;
    const contextualApp=contextApp();
    $("#header-add").style.cssText=contextualApp?appTone(contextualApp):`--app-color:${appPalette[1]};--app-color-secondary:${appPalette[2]}`;
  }
  function errorNotice(){return (state.errors||[]).length?`<div class="notice error">${state.errors.map(escape).join("<br>")}</div>`:"";}
  function setupError(){return `<div class="empty-state"><h2>aidentity could not read your setup</h2>${errorNotice()}<div class="section-gap">${button("Retry","refresh",{primary:true,icon:"refresh"})}</div></div>`;}
  function title(name,description,actions=""){return `<div class="title-row"><div><h1 tabindex="-1">${escape(name)}</h1><p>${escape(description)}</p></div>${actions?`<div class="title-actions">${actions}</div>`:""}</div>`;}
  function searchField(placeholder){return `<div class="search-field">${icon("search")}<input id="workspace-search" class="input" type="search" aria-keyshortcuts="/" aria-label="${escape(placeholder)}" placeholder="${escape(placeholder)}" value="${escape(query)}">${query?`<button class="icon-button" data-action="clear-search" aria-label="Clear search">${icon("x")}</button>`:""}</div>`;}
  // educalvolpz Animated Tabs translated to native tabs with measured sliding indicator.
  function tabs(items,active){return `<div class="tabs" role="tablist" aria-label="Profile status">${items.map(([id,label,count])=>`<button id="status-${id}" role="tab" aria-selected="${active===id}" aria-controls="profile-results" tabindex="${active===id?0:-1}" data-filter="${id}">${label} <span class="tab-count">${count}</span></button>`).join("")}<span class="tab-indicator"></span></div>`;}
  function positionTabs(){
    const tab=$('.tabs [aria-selected=true]'),line=$(".tab-indicator");if(!tab||!line)return;
    const scope=`${appFilter}:${query}`,next={left:tab.offsetLeft,width:tab.offsetWidth,scope,id:tab.id},moved=tabPosition?.id!==tab.id;
    const transform=`translateX(${next.left}px) scaleX(${next.width})`;
    line.style.width="1px";line.style.transform=transform;
    if(tabPosition?.scope===scope&&(tabPosition.left!==next.left||tabPosition.width!==next.width)){
      animateMotion(line,[{transform:`translateX(${tabPosition.left}px) scaleX(${tabPosition.width})`},{transform}],"control");
    }
    tabPosition=next;
    // A re-render resets the strip to scrollLeft 0: restore the user's sideways scroll, and reveal the selected tab
    // horizontally only when the selection moved (scrollIntoView could move the page), with the strip's focus-ring padding.
    const strip=tab.parentElement,pad=strip.firstElementChild.offsetLeft;
    strip.scrollLeft=moved?Math.min(tab.offsetLeft-pad,Math.max(tabScroll,tab.offsetLeft+tab.offsetWidth+pad-strip.clientWidth)):tabScroll;
  }
  function showView(next,options={}){
    if(cleanupExperience){cleanupExperience();cleanupExperience=null;}
    if(next!==view)query="";// each view starts unfiltered; its own query survives only while you stay on it
    view=next;mobileDetail=false;
    window.history.replaceState(null,"",`#${next}`);
    if(options.app!==undefined)appFilter=options.app;
    if(options.profile){selected=options.profile;mobileDetail=true;}
    renderNav();renderView();// the staggered entrance runs on first load only (refresh)
    closeNavigation();window.scrollTo({top:0,behavior:"instant"});
    if(options.focus){const heading=(options.profile&&$("#detail-title",main))||$("h1",main)||main;heading.tabIndex=-1;heading.focus({preventScroll:true});}
  }
  function renderView(){
    if(!state)return;
    main.classList.remove("profile-detail-mobile");
    if(view==="explore"){
      if(cleanupExperience)return;
      main.innerHTML='<div id="experience-root"></div>';exploreApp="";
      if(window.AidentityExperience)cleanupExperience=window.AidentityExperience.mount($("#experience-root"),state,{
        renderAppIcon:appGlyph,
        appAccent,
        openProfile:item=>{query="";statusFilter="all";showView("profiles",{profile:typeof item==="string"?item:item.name,app:"",focus:true});},
        addProfile:app=>addDialog(app || ""),
        showProfiles:(app="")=>{query="";statusFilter="all";selected="";showView("profiles",{app:app || "",focus:true});},
        launchProfile:async item=>action("open",{name:typeof item==="string"?item:item.name}),
        focusApp:name=>{exploreApp=name;renderNav();},
      });
      else main.innerHTML=title("Every account, together","Create a separate launcher for each account.")+button("Open workspace","workspace",{primary:true,icon:"arrow"});
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
  function renderProfiles(){
    const chosen=profile(selected);
    if(!chosen)mobileDetail=false;
    main.classList.toggle("profile-detail-mobile",mobileDetail);
    const scoped=scopedProfiles();
    const running=scoped.filter(item=>item.status==="running").length;
    const visible=scoped.filter(item=>statusFilter==="all"||(statusFilter==="running"?item.status==="running":statusFilter==="attention"?needsRepair(item):item.status!=="running"));
    const appCount=new Set(scoped.map(appName)).size;
    paint(title(appFilter||"Profiles","Your accounts have their own space. Open one and pick up where you left off.")+
      `<p class="stat-line"><span><strong class="num">${scoped.length}</strong> ${scoped.length===1?"profile":"profiles"}</span><span><strong class="num">${running}</strong> running</span><span><strong class="num">${appCount}</strong> ${appCount===1?"app":"apps"}</span></p>`+
      tabs([["all","All profiles",scoped.length],["running","Running",running],["idle","At rest",scoped.length-running],["attention","Needs repair",scoped.filter(needsRepair).length]],statusFilter)+
      `<div class="toolbar">${searchField("Search profiles")}<div class="toolbar-end">${appFilter?button("All apps","all-apps",{small:true}):""}<select id="app-filter" aria-label="Filter by application"><option value="">All apps</option>${[...new Set(state.profiles.map(appName))].sort().map(name=>`<option${name===appFilter?" selected":""}>${escape(name)}</option>`).join("")}</select><span class="small" id="result-count" role="status">${visible.length} ${visible.length===1?"profile":"profiles"}</span></div></div>`+
      `<div class="profile-layout ${chosen?"":"no-selection"} ${mobileDetail?"mobile-detail":""}"><div class="profile-grid" id="profile-results" role="tabpanel" aria-labelledby="status-${statusFilter}" data-count="${visible.length}">${visible.map(card).join("")||profilesEmpty(scoped)}</div>${chosen?detail(chosen):""}</div>`);
  }
  const emptyState=(heading,text,actions="")=>`<div class="empty-state"><h2>${heading}</h2><p>${text}</p>${actions}</div>`;
  // Search-empty, filter-empty and each status tab get their own words: an empty Running tab is not a failed search.
  function profilesEmpty(scoped){
    if(!state.profiles.length)return state.errors?.length?setupError():emptyState("A new space for your next account","Choose an installed app, name the account, and create its own launcher.",button("Create your first profile","add",{primary:true,icon:"plus"}));
    if(!scoped.length)return query?emptyState(`No profiles match “${escape(query)}”`,"Check the spelling or clear the search.",button("Clear search","clear-search",{primary:true,icon:"x"})):emptyState("No matching profiles","Try another app.",button("Clear filters","reset-filters",{primary:true,icon:"search"}));
    const all=button("Show all profiles","show-all",{icon:"grid"});
    if(statusFilter==="running")return emptyState("Nothing is running","Choose Open profile on any card and it shows up here.",all);
    if(statusFilter==="attention")return emptyState("Nothing needs repair","Every launcher has its app. Run doctor on Maintenance for a deeper check.",all);
    return emptyState("Every profile is running","Quit one and it shows up here.",all);
  }
  // ravikatiyar162 ProfileCard structure: cover, offset identity, role/meta and
  // full-width action. Account badge replaces human avatar; CLI fields replace stats.
  function card(item){
    return `<article class="profile-card app-tone ${selected===item.name?"selected":""}" style="${appTone(appName(item))}" aria-labelledby="${profileId(item.name)}"><div class="profile-cover"><button class="icon-button" tabindex="-1" data-action="select" data-name="${escape(item.name)}" aria-label="Details for ${escape(item.name)}" title="Profile details">${icon("more")}</button></div><div class="profile-body">${art(appName(item),item.badge,item.color)}<button class="profile-name" id="${profileId(item.name)}"${selected===item.name?' aria-current="true"':""} data-action="select" data-name="${escape(item.name)}" title="${escape(item.name)}">${escape(item.profile||item.name)}</button><div class="profile-app">${escape(appName(item))}</div>${needsRepair(item)?`<div class="profile-state-row">${statusMark(item)}${button("Repair","repair",{small:true,icon:"tool",name:item.name,label:`Repair ${item.name}`})}</div>`:statusMark(item)}<div class="profile-meta"><span>${item.main?"Original account":"Separate account"}</span><span>${item.own_extensions?"Own extensions":(item.args||[]).length?plural(item.args.length,"launch option"):""}</span></div><button class="button open-profile ${item.status==="running"?"":"button-secondary"}" data-action="${item.status==="running"?"quit":"open"}" data-name="${escape(item.name)}" aria-label="${item.status==="running"?"Quit profile":"Open profile"} ${escape(item.name)}">${icon(item.status==="running"?"stop":"play")}<span>${item.status==="running"?"Quit profile":"Open profile"}</span></button></div></article>`;
  }
  function detail(item){
    return `<aside class="detail-panel app-tone" style="${appTone(appName(item))}" aria-label="Selected profile details">${button("Back to profiles","back-profiles",{small:true,icon:"back"}).replace('class="button ','class="button detail-back ')}<div class="detail-top">${art(appName(item),item.badge,item.color)}<button class="icon-button" data-action="close-detail" aria-label="Close details">${icon("x")}</button></div><h2 id="detail-title" tabindex="-1">${escape(item.name)}</h2><p class="small">${item.main?"Opens the app’s original account":"An independent account launcher"}</p>${statusMark(item)}<div class="detail-actions">${button(item.status==="running"?"Quit profile":"Open profile",item.status==="running"?"quit":"open",{primary:true,icon:item.status==="running"?"stop":"play",name:item.name,label:`${item.status==="running"?"Quit profile":"Open profile"} ${item.name}`})}${item.status==="running"?button("Bring to front","open",{icon:"play",name:item.name}):""}${button("Settings","settings",{icon:"settings",name:item.name})}</div><dl class="details"><div><dt>Application</dt><dd>${item.app_path?breakPath(item.app_path):escape(appName(item))}</dd></div><div><dt>Profile data</dt><dd>${item.main?"The app’s own original account":item.data_dir?breakPath(item.data_dir):"No folder recorded"}</dd></div><div><dt>Launch arguments</dt><dd>${(item.args||[]).length?(item.args||[]).map(arg=>`<code>${escape(arg)}</code>`).join("<br>"):"No additional arguments"}</dd></div><div><dt>Environment variables</dt><dd>${(item.env||[]).length?escape(item.env.join(", "))+"<br><span class='small'>Values stay private</span>":"None configured"}</dd></div><div><dt>Extensions</dt><dd>${item.own_extensions?"Separate extensions folder":"App’s default extensions"}</dd></div><div><dt>Launcher version</dt><dd>${escape(item.built_by||"Not recorded")}</dd></div></dl><div class="detail-footer">${button("Rename","rename",{small:true,icon:"rename",name:item.name})}${button("Rebuild","rebuild",{small:true,icon:"refresh",name:item.name})}${button("Remove","remove",{small:true,danger:true,icon:"trash",name:item.name})}</div></aside>`;
  }
  function renderApps(){
    const apps=state.apps.filter(item=>!query||item.name.toLowerCase().includes(query.toLowerCase()));
    paint(title("Applications",!state.apps.length&&state.errors?.length?"Inventory unavailable.":`${state.apps.length} compatible ${state.apps.length===1?"app":"apps"} found on this Mac.`)+`<div class="toolbar">${searchField("Search installed apps")}</div><div class="apps-grid">${apps.map(item=>{const count=state.profiles.filter(p=>appName(p)===item.name).length;return `<article class="application-card app-tone" style="${appTone(item.name)}">${art(item.name)}<h2>${escape(item.name)}</h2><p>${count} ${count===1?"profile":"profiles"} configured</p>${button("Add account","add",{icon:"plus",app:item.name,label:`Add account for ${item.name}`})}</article>`;}).join("")||(!state.apps.length&&state.errors?.length?setupError():state.apps.length?`<div class="empty-state"><h2>No apps match “${escape(query)}”</h2><p>Check the spelling or clear the search to see ${state.apps.length===1?"the 1 app":`all ${state.apps.length} apps`}.</p>${button("Clear search","clear-search",{primary:true,icon:"x"})}</div>`:'<div class="empty-state"><h2>No compatible apps found</h2><p>Install a Chromium or Electron app, then refresh this workspace.</p>'+button("Refresh apps","refresh",{icon:"refresh"})+"</div>")}</div>`);
  }
  function renderRecovery(){
    const entries=state.restorable||[];
    main.innerHTML=title("Recovery","Recreate deleted launchers and reconnect them to their existing profile data.")+
    `<section class="panel"><div class="panel-heading"><h2>${plural(entries.length,"restorable profile")}</h2>${button("Restore all","restore-all",{icon:"recovery",disabled:!entries.length})}</div><div class="recovery-list">${entries.map(item=>`<div class="recovery-row"><div><h3>${escape(item.name)}</h3><p>The profile data remains on this Mac.</p></div>${button("Restore","restore",{icon:"recovery",name:item.name})}</div>`).join("")||'<p class="muted">Every profile with a restore record already has a launcher.</p>'}</div></section>`+
    `<div class="operation-grid section-gap"><section class="operation-card">${icon("refresh")}<h2>Rebuild launchers</h2><p>Rebuild makes each launcher again from its saved settings, for example after an app moved or updated. Profile data is not touched.</p><div class="button-row">${button("Rebuild all","rebuild-all",{icon:"refresh"})}</div></section><section class="operation-card">${icon("trash")}<h2>Clear unclaimed data</h2><p>Unclaimed data is a profile folder that no launcher uses. Prune moves it to the Trash, so restore any account you want to keep first.</p><div class="button-row">${button("Prune…","prune",{danger:true,icon:"trash"})}</div></section></div>`;
  }
  // The latest doctor run, read from the server's summary and findings; the raw output stands in when they are absent.
  function healthResult(){
    if(!lastDoctor)return "";
    const {result,at}=lastDoctor,sum=result.summary,findings=Array.isArray(result.findings)?result.findings:null;
    const words={error:"Error",warn:"Warning",ok:"OK"},order={error:0,warn:1,ok:2};
    const count=(n,one)=>`<span><strong class="num">${n||0}</strong> ${n===1||one==="OK"?one:`${one}s`}</span>`;
    const head=`<p class="health-summary">${sum?count(sum.ok,"OK")+count(sum.warn,"warning")+count(sum.error,"error"):""}<time>Checked ${time(at)}</time></p>`;
    const body=findings?`<ul class="health-findings">${[...findings].sort((a,b)=>(order[a.level]??3)-(order[b.level]??3)).map(item=>`<li data-level="${escape(item.level)}">${icon(item.level==="ok"?"check":"alert")}<span class="finding-level">${words[item.level]||escape(item.level)}</span><span>${!item.profile?escape(item.text):item.text===item.profile?`<strong>${escape(item.profile)}</strong>`:`<strong>${escape(item.profile)}:</strong> ${escape(item.text)}`}</span></li>`).join("")}</ul>`:`<pre class="output">${escape([result.stdout,result.stderr].filter(Boolean).join("\n")||"No output.")}</pre>`;
    return `<div class="health-result">${head}${body}${healthIssues()?'<p class="health-next">Next step: <strong>Check &amp; fix</strong> rebuilds the launchers it can repair.</p>':""}</div>`;
  }
  const healthIssues=()=>{const sum=lastDoctor?.result.summary;return sum?(sum.warn||0)+(sum.error||0):0;};
  function renderMaintenance(){
    const issues=healthIssues();
    main.innerHTML=title("Maintenance","Check your setup, repair launchers, and keep aidentity current.")+
    `<div class="operation-grid"><section class="operation-card">${icon("shield")}<h2>Workspace health</h2><p>Doctor checks your setup and every profile for missing apps, stale launchers and settings problems.</p>${healthResult()}<div class="button-row">${button("Run doctor","doctor",{primary:!issues,icon:"shield"})}${button("Check & fix","doctor-fix",{primary:issues>0,icon:"tool"})}</div></section><section class="operation-card">${icon("download")}<h2>aidentity updates</h2><p>Installed version: <span class="num">${escape(state.version)}</span>. Check for a new release or install the latest one.</p>${lastUpdate?`<p class="update-status">${escape(lastUpdate)}</p>`:""}<div class="button-row">${button("Check for updates","update-check",{icon:"refresh"})}${button("Update now","update",{icon:"download"})}</div></section><section class="operation-card">${icon("refresh")}<h2>Rebuild launchers</h2><p>Rebuild makes every launcher again from its saved settings and the app’s current location. Profile data is not touched.</p><div class="button-row">${button("Rebuild all","rebuild-all",{icon:"refresh"})}</div></section></div>`+
    `<section class="storage-panel" aria-labelledby="storage-title"><h2 id="storage-title">Local storage</h2><dl class="details storage-list"><div><dt>Launchers</dt><dd>${state.paths?.launchers?breakPath(state.paths.launchers):"Not available"}</dd></div><div><dt>Profile data</dt><dd>${state.paths?.data?breakPath(state.paths.data):"Not available"}</dd></div></dl></section>${errorNotice()}`;
  }
  function renderTransfer(){
    main.innerHTML=title("Import & export","Move your profile setup between Macs with a launcher recipe.")+
    `<div class="operation-grid"><section class="operation-card">${icon("download")}<h2>Export your setup</h2><p>Download the names, badges, colors, and launch settings for ${state.profiles.length} ${state.profiles.length===1?"launcher":"launchers"}.</p><p>Account sessions and profile data stay on this Mac.</p><div class="button-row">${button("Export JSON","export",{primary:true,icon:"download"})}</div></section><section class="operation-card">${icon("upload")}<h2>Bring a setup here</h2><p>Choose an aidentity export file, review its launcher names, and build them using installed apps.</p><p>Imported profiles begin signed out unless their data already exists here.</p><div class="button-row">${button("Import JSON","import",{icon:"upload"})}</div></section></div><div class="notice">Export files include launch settings and may contain private environment or proxy values. Keep the file private.</div>`;
  }
  function renderGuide(){
    const commands=["","setup","ui","add","list","open","quit","rename","set","prune","restore","rebuild","rm","export","import","apps","doctor","update","completion","version","help","dashboard"];
    main.innerHTML=title("Command guide","The same CLI commands, with help and shell completion on hand.")+
      `<div class="guide-layout"><section class="panel guide-controls"><div class="field"><label for="help-command">Command help</label><select id="help-command">${commands.map(command=>`<option value="${command}">${command||"All commands"}</option>`).join("")}</select><div class="section-gap">${button("Read help","help",{icon:"book"})}</div></div><div class="field"><label for="completion-shell">Shell completion</label><select id="completion-shell"><option>zsh</option><option>bash</option><option>fish</option></select><div class="section-gap">${button("Generate completion","completion",{icon:"terminal"})}</div></div></section><section><div class="panel-heading"><h2>Command output</h2>${button("Copy output","copy-guide",{small:true,icon:"copy"})}</div><pre class="output guide-output">${escape(guideText||"Choose a command to read its help, or generate a completion script for your shell.")}</pre></section></div>`;
  }
  async function refresh(options={}){
    if(loading)return null;loading=true;let changed=null;
    try{
      const response=await fetch(options.force?"/api/state?fresh=1":"/api/state",{cache:"no-store"});
      const data=await response.json();
      if(!response.ok||!data.ok)throw Object.assign(new Error(data.error||"Could not read the workspace."),{server:true});
      const firstLoad=!state;
      registerAppAccents(data);
      state=data;loadedAt=new Date();$("#freshness").textContent=`Updated ${time(loadedAt)}`;
      setOffline(false);
      const current=JSON.stringify({version:data.version,profiles:data.profiles,apps:data.apps,restorable:data.restorable,errors:data.errors});
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
    }finally{loading=false;}
    return changed;
  }
  function setOffline(on){
    if(offline===on)return;
    offline=on;document.body.classList.toggle("is-offline",on);
    const banner=$("#connection-banner");banner.hidden=!on;
    banner.innerHTML=on?"<strong>The dashboard stopped.</strong> Run <code>aidentity dashboard</code> in Terminal to reconnect.":"";
    $("#connection-state").textContent=on?"Disconnected":"Local workspace";
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
  const verbs={open:"open",quit:"quit",add:"create the profile",set:"save the settings",rename:"rename",remove:"remove",restore:"restore",rebuild:"rebuild",prune:"prune",doctor:"run doctor",import:"import",export:"export",update:"update",help:"read the help",completion:"generate completion"};
  const doing={open:"Opening…",quit:"Closing…",add:"Creating the profile…",set:"Saving the settings…",rename:"Renaming…",remove:"Removing…",restore:"Restoring…",rebuild:"Rebuilding…",prune:"Clearing unclaimed data…",doctor:"Running doctor…",import:"Importing…",export:"Exporting…",update:"Updating aidentity…",help:"Loading the help…",completion:"Generating completion…"};
  async function action(name,params={},element=null,{quiet=false}={}){
    if(busy||offline||!state?.csrf_token){
      const error=busy?Object.assign(new Error("Another action is still running. Try again when it finishes."),{busy:true}):new Error(OFFLINE);
      if(!quiet){toast(busy?"Still working":"Disconnected",error.message,busy?"info":true);error.reported=true;}
      throw error;
    }
    const before=state;let note=null,entry=null;
    busy=name;setBusy(element,true);syncControls();
    $("#activity-summary").textContent=name==="update"&&params.check?"Checking for updates…":doing[name]||"Working…";
    try{
      let response,result;
      try{response=await fetch("/api/action",{method:"POST",headers:{"Content-Type":"application/json","X-AIdentity-CSRF":state.csrf_token},body:JSON.stringify({action:name,...params})});}
      catch(error){setOffline(true);entry=logActivity({action:name,ok:false,output:`${error.name}: ${error.message}\n${OFFLINE}`});throw new Error(OFFLINE);}
      try{result=await response.json();}catch{result={ok:false,error:`The dashboard sent an unreadable reply (HTTP ${response.status}).`};}
      if(response.status===409&&result.busy)throw Object.assign(new Error(result.error||"Another action is still running. Try again when it finishes."),{busy:true});
      entry=logActivity({action:name,ok:Boolean(result.ok),command:result.command,output:name==="export"?"Launcher recipe prepared for download.":[result.stdout,result.stderr,result.error].filter(Boolean).join("\n")});
      // Doctor reports findings with a non-zero exit; a summary means it ran, so it is a result, not a failure.
      const report=name==="doctor"&&Boolean(result.summary);
      if((!response.ok||!result.ok)&&!report)throw Object.assign(new Error(result.error||result.stderr||result.stdout||`${name} failed (exit ${result.exit_code}).`),{field:result.field});
      if(name==="doctor"){lastDoctor={result,at:new Date()};doctorFlags=new Set((result.findings||[]).filter(item=>item.profile&&(item.level==="warn"||item.level==="error")).map(item=>item.profile));}
      if(name==="rebuild"){if(params.all)doctorFlags.clear();else doctorFlags.delete(params.name);}
      if(name!=="add")note=describe(name,params,result,before);
      await refresh({force:true});
      if(name==="add"){result.created=state.profiles.find(item=>!before.profiles.some(old=>old.name===item.name))?.name||`${params.app} ${params.profile}`;note=describe(name,params,result,before);}
      entry.title=note.title;renderActivity();
      if(!quiet)toast(note.title,note.text,note.kind,note.extra);
      return result;
    }catch(error){
      const failure=error.busy?"Still working":error.message===OFFLINE?"Disconnected":`Could not ${verbs[name]||name}${params.name?` ${params.name}`:""}`;
      if(entry)entry.title=failure;
      if(!quiet&&!error.reported){toast(failure,String(error.message).slice(0,180),error.busy?"info":true);error.reported=true;}
      renderActivity();
      throw error;
    }finally{busy=false;setBusy(element,false);syncControls();}
  }
  // Plain-words toast for a finished action. Runs before the post-action refresh (add after it, to learn the new name).
  function describe(name,params,result,before){
    const who=params.name||"",was=before?.profiles.find(item=>item.name===who);
    if(name==="add")return {title:`${result.created} is ready`,text:"Find it in Profiles, or open it now.",extra:{label:"Open it",run:()=>action("open",{name:result.created})}};
    if(name==="open"){
      if(was?.status==="running")return {title:`Brought ${who} to the front`};
      const key=`aidentity.signin-hint.${who}`,first=was?.status==="signed out / new"&&!stored.get(key);
      if(first)stored.set(key,"shown");
      return {title:`Opened ${who}`,text:first?SIGN_IN_HINT:"It opens in its own window."};
    }
    if(name==="quit")return {title:`Closed ${who}`};
    if(name==="remove")return {title:`${who} removed`,text:params.purge?"Its profile data is in the Trash.":"Its profile data stays on this Mac.",extra:params.purge||was?.main?null:{label:"Restore",run:()=>action("restore",{name:who})}};
    if(name==="restore")return params.all?{title:`Restored ${plural(before.restorable?.length||0,"profile")}`,text:"Each one opens with its existing data."}:{title:`${who} restored`,text:"It opens with its existing data."};
    if(name==="rebuild")return params.all?{title:`Rebuilt ${plural(before.profiles.length,"launcher")}`,text:"Profile data was not touched."}:{title:`${who} rebuilt`,text:"Its profile data was not touched."};
    if(name==="rename")return {title:`Renamed ${who}`,text:`It is now ${appName(was||{})} ${params.new_name}.`};
    if(name==="set")return {title:`${who} settings saved`};
    if(name==="prune")return {title:"Unclaimed data cleared",text:lastLine(result.stdout)};
    if(name==="doctor"){
      const sum=result.summary;
      if(!sum)return {title:params.fix?"Check & fix finished":"Doctor finished",text:"The full report is in Activity."};
      const issues=(sum.warn||0)+(sum.error||0),away=view!=="maintenance";
      return {title:`Checked ${plural(before.profiles.length,"profile")}: ${issues?`${issues} ${issues===1?"needs":"need"} attention`:"all healthy"}`,text:issues?(away?"The findings are in Maintenance.":"The findings are in Workspace health."):"Nothing needs repair.",kind:sum.error?"error":sum.warn?"warn":"ok",extra:issues&&away?{label:"Show findings",run:()=>showView("maintenance",{focus:true})}:null};
    }
    if(name==="update"&&params.check){
      const {installed,available}=result;
      if(installed&&available&&available!==installed){lastUpdate=`Version ${available} is available (you have ${installed})`;return {title:`Version ${available} is available`,text:`You have ${installed}. Choose Update now to install it.`};}
      if(installed&&available===installed){lastUpdate=`You’re on the latest version (${installed})`;return {title:"aidentity is up to date",text:`${lastUpdate}.`};}
      lastUpdate="";return {title:"Update check finished",text:lastLine(result.stdout)||"The full result is in Activity."};
    }
    if(name==="update")return {title:"aidentity updated",text:lastLine(result.stdout)};
    if(name==="import"){
      // The CLI's own summary: "N created, N skipped, N failed." or "Nothing to create."/"Nothing to do." (exit 0).
      const summary=String(result.stdout||"").split("\n").map(line=>line.trim()).filter(line=>/^\d+ created, |Nothing to (create|do)\./.test(line)).pop()||"The import finished.";
      const made=Number(/^(\d+) created/.exec(summary)?.[1]||0);
      return {title:made?`Imported ${plural(made,"launcher")}`:"Nothing imported",text:summary,kind:made?"ok":"info"};
    }
    if(name==="export")return {title:"Setup exported",text:"Downloaded aidentity-profiles.json. Keep the recipe private."};
    if(name==="help")return {title:"Command help is ready"};
    if(name==="completion")return {title:`${params.shell||"Shell"} completion is ready`};
    return {title:"Done",text:lastLine(result.stdout)};
  }
  function logActivity(record){history.unshift({time:new Date(),...record});history=history.slice(0,12);renderActivity();return history[0];}
  function renderActivity(){
    $("#activity-content").innerHTML=history.map(item=>`<article class="activity-entry"><div class="activity-entry-title"><strong class="${item.ok?"":"activity-error"}">${escape(item.title||`${item.action} · ${item.ok?"Completed":"Failed"}`)}</strong><time>${time(item.time)}</time></div>${item.command?`<code class="activity-command">${escape(item.command)}</code>`:""}<pre class="output">${escape(item.output||"Completed without additional output.")}</pre></article>`).join("")||'<p class="muted">Nothing run yet. Each action you run shows up here with its command.</p>';
    // The summary uses the toast's title; an entry gets it once its action finishes, so "Running…" stays until then.
    if(!history[0]||history[0].title)$("#activity-summary").textContent=history[0]?`${history[0].title} · View details`:"Activity · Nothing run yet";
  }
  // kind: true or "error", "warn", "info", or "ok"; extra: {label, run} adds a next-step button (Open it, Restore).
  function toast(titleText,description,kind=false,extra=null){
    const level=kind===true?"error":kind||"ok";
    const viewport=toastViewport;
    const node=document.createElement("div");node.className=`toast ${level==="ok"?"":level}`;node.setAttribute("role",level==="error"?"alert":"status");
    node.innerHTML=`${icon(level==="ok"?"check":"alert")}<div><strong>${escape(titleText)}</strong>${description?`<p>${escape(description)}</p>`:""}<div class="toast-actions">${extra?`<button class="toast-action toast-primary">${escape(extra.label)}</button>`:""}<button class="toast-action toast-activity">View activity</button></div></div><button class="icon-button" aria-label="Dismiss notification">${icon("x")}</button>`;
    const dismiss=()=>{if(node.classList.contains("dismiss"))return;node.classList.add("dismiss");setTimeout(()=>animateToastLayout(()=>node.remove()),reducedMotion.matches?0:200);};
    $(".icon-button",node).onclick=dismiss;
    $(".toast-activity",node).onclick=()=>{showActivity(true);dismiss();};
    if(extra)$(".toast-primary",node).onclick=()=>{dismiss();Promise.resolve().then(extra.run).catch(()=>{});};
    animateToastLayout(()=>{viewport.prepend(node);while(viewport.children.length>3)viewport.lastChild.remove();});
    let timer=setTimeout(dismiss,level==="error"?12000:extra?9000:5500);
    const pause=()=>clearTimeout(timer),resume=()=>{clearTimeout(timer);if(!node.matches(":hover")&&!node.contains(document.activeElement))timer=setTimeout(dismiss,3000);};
    node.onpointerenter=pause;node.onpointerleave=resume;node.onfocusin=pause;node.onfocusout=resume;
  }
  // rmahammad Animated Dialog's fixed header/body/footer translated to <dialog>.
  // build(FormData) returns [action, params] for the live "Runs:" line and, when submit is null, for the submit itself.
  function showDialog(titleText,description,body,submitText,submit,{danger=false,build=null}={}){
    clearTimeout(dialogCloseTimer);dialogRevision++;
    lastFocus=document.activeElement;dialogBuild=build;dialogSubmit=submit||(async(data,el)=>{await action(...build(data),el);});dialog.classList.remove("closing");
    dialog.classList.add("app-tone");dialog.style.cssText=appTone(contextApp()||"App");
    const echo=build?`<div class="command-echo" id="command-echo" hidden><span class="command-label">Runs:</span><code></code><button type="button" class="icon-button" data-action="copy-command" aria-label="Copy command" title="Copy command">${icon("copy")}</button></div>`:"";
    dialog.innerHTML=`<form id="dialog-form" class="dialog-inner"><header class="dialog-header"><h2 id="dialog-title">${escape(titleText)}</h2><p id="dialog-description">${escape(description)}</p><button type="button" class="icon-button" data-close-dialog aria-label="Close dialog">${icon("x")}</button></header><div class="dialog-body">${body}${echo}<div id="form-error" class="form-error" role="alert" hidden></div></div><footer class="dialog-footer"><button type="button" class="button" data-close-dialog>Cancel</button><button type="submit" class="button ${danger?"button-danger":"button-primary"}" id="dialog-submit">${escape(submitText)}</button></footer></form>`;
    dialog.showModal();hostToasts();
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
      const response=await fetch("/api/preview",{method:"POST",headers:{"Content-Type":"application/json","X-AIdentity-CSRF":state.csrf_token},body:JSON.stringify({action:spec[0],...spec[1]})});
      const result=await response.json();
      if(seq!==previewSeq||!echo.isConnected)return;
      echo.hidden=!(response.ok&&result.ok&&result.command);
      if(!echo.hidden)$("code",echo).textContent=result.command;
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
  const area=(label,name,hint="")=>`<div class="field"><label for="field-${name}">${label}</label><textarea id="field-${name}" name="${name}" rows="3" spellcheck="false" autocomplete="off"${hint?` aria-describedby="hint-${name}"`:""}></textarea>${hint?`<p class="hint" id="hint-${name}">${hint}</p>`:""}</div>`;
  // Swatches first in plain words; the hex field stays for anyone who wants an exact color. data-auto: follows the app's hue until edited.
  function identityFields(p=null,fallback=defaultBadgeColor){
    const color=String(p?.color||fallback).toUpperCase();
    return `<div class="field"><p class="field-label" id="badge-color-label">Pick a color</p><div class="color-options" role="group" aria-labelledby="badge-color-label">${colors.map(([name,hex])=>`<button type="button" class="color-swatch" style="--swatch:#${hex}" data-color="${hex}" title="${name}: ${hex}" aria-label="${name}" aria-pressed="${color===hex}"></button>`).join("")}</div></div><div class="field-pair">${field("Badge character","badge",p?.badge||"","Shown on the app icon.","text",'maxlength="4"')}${field("Hex color","color",color,"","text",`maxlength="7" spellcheck="false" autocomplete="off"${p?"":" data-auto"}`)}</div>${check("no_badge","Use the original app icon","Hide the colored account badge.",p?.badge===null)}`;
  }
  // Preselect the app the user is looking at: the clicked app, the selected profile's, the filter's, the last one used, then the first.
  function addDialog(app=""){
    if(!state)return;
    const names=state.apps.map(item=>item.name),known=name=>names.includes(name)?name:"";
    const chosen=known(app)||known(contextApp())||known(stored.get("aidentity.last-app"))||names[0]||"";
    const hue=appAccent(chosen||"App").color.slice(1).toUpperCase();
    const options=state.apps.map(item=>`<option value="${escape(item.name)}"${item.name===chosen?" selected":""}>${escape(item.name)}</option>`).join("");
    const build=data=>{
      const params={app:String(data.get("app_path")||"").trim()||data.get("app"),profile:data.get("profile"),no_badge:data.has("no_badge"),main:data.has("main"),seed:data.has("seed"),args:lines(data.get("args")),env:lines(data.get("env")),own_extensions:data.has("own_extensions")};
      if(data.get("badge")&&!params.no_badge)params.badge=data.get("badge");
      if(data.get("color"))params.color=data.get("color");
      return ["add",params];
    };
    showDialog("Create a profile","Give another account its own launcher and profile folder.",`<div class="preview-row" id="identity-preview">${art(chosen||"App","W",hue)}<div><strong id="preview-name">${escape(chosen||"App")} Work</strong><span class="small">Your new account launcher</span></div></div><div class="fields"><div class="field"><label for="field-app">Application</label><select name="app" id="field-app" required>${options||'<option value="">No compatible apps found</option>'}</select></div>${field("Profile name","profile","","For example, Work, Personal, or Client.","text",'required maxlength="40" placeholder="Work"')}${check("main","Open the original account","Create a Main launcher for the app’s existing account.")}<details class="advanced"><summary>Appearance</summary><div class="fields">${identityFields(null,hue)}</div></details><details class="advanced"><summary>App location & launch settings</summary><div class="fields">${field("Application path (optional)","app_path","","Use a full .app path for an application outside discovery.","text",'placeholder="/Applications/Example.app"')}${check("seed","Copy Claude’s MCP configuration","For Claude Desktop profiles only. Copies the existing configuration into the new profile.")}${area("Launch arguments","args","One allowed switch per line, for example --lang=de.")}${area("Environment variables","env","One allowed NAME=value per line. Values are never displayed in this dashboard.")}${check("own_extensions","Use a separate extensions folder","For VS Code-style applications.")}</div></details></div>`,"Create profile",async(data,el)=>{
      const result=await action(...build(data),el);
      stored.set("aidentity.last-app",data.get("app"));
      revealProfile(result.created);
    },{build});
    setupPreview();
    $('[name="main"]',dialog).onchange=event=>{if(event.target.checked&&!$('[name="profile"]',dialog).value)$('[name="profile"]',dialog).value="Main";setupPreviewUpdate();};
  }
  // After Add: Profiles, the new card selected, scrolled into view, one gentle ring, and focus on its name once the dialog closes.
  function revealProfile(name){
    query="";statusFilter="all";selected=name||"";
    showView("profiles",{app:""});
    const target=$$(".profile-name",main).find(el=>el.dataset.name===name);if(!target)return;
    const cardNode=target.closest(".profile-card");
    cardNode.scrollIntoView({block:"center",behavior:reducedMotion.matches?"instant":"smooth"});
    lastFocus=target;
    animateMotion(cardNode,[{outlineOffset:"12px",outlineColor:"transparent"},{outlineOffset:"0px"}],"surface",{duration:900,delay:220});
  }
  const lines=value=>String(value||"").split(/\r?\n/).map(v=>v.trim()).filter(Boolean);
  function setupPreview(){
    $('[name="color"]',dialog)?.addEventListener("input",event=>event.target.removeAttribute("data-auto"));
    $$('input,select',dialog).forEach(input=>input.addEventListener("input",setupPreviewUpdate));setupPreviewUpdate();
  }
  function setupPreviewUpdate(){
    const preview=$("#identity-preview");if(!preview)return;
    const path=String($('[name="app_path"]',dialog)?.value||"").trim();
    const appSelect=$('[name="app"]',dialog);
    if(appSelect)appSelect.required=!path;
    const app=path?path.replace(/\/+$/,"").split("/").pop().replace(/\.app$/i,""):appSelect?.value||preview.dataset.app||"App";
    const name=$('[name="profile"]',dialog)?.value||preview.dataset.profile||"Work";
    const colorInput=$('[name="color"]',dialog),badgeInput=$('[name="badge"]',dialog);
    if(colorInput?.hasAttribute("data-auto")){colorInput.value=appAccent(app).color.slice(1).toUpperCase();$$(".color-swatch",dialog).forEach(el=>el.setAttribute("aria-pressed",el.dataset.color===colorInput.value));}
    if(badgeInput)badgeInput.placeholder=[...name][0]?.toUpperCase()||"";
    const badge=$('[name="no_badge"]',dialog)?.checked?null:badgeInput?.value||[...name][0]?.toUpperCase();
    const raw=colorInput?.value||defaultBadgeColor;const hex=cliColors[raw.toLowerCase()]||raw;
    preview.classList.add("app-tone");preview.style.cssText=appTone(app);dialog.style.cssText=appTone(app);
    preview.innerHTML=art(app,badge,hex)+`<div><strong>${escape(app)} ${escape(name)}</strong><span class="small">Your account launcher</span></div>`;
  }
  function settingsDialog(item){
    showDialog("Profile settings",item.name,`<div class="preview-row" id="identity-preview" data-app="${escape(appName(item))}" data-profile="${escape(item.profile)}">${art(appName(item),item.badge,item.color)}<div><strong>${escape(item.name)}</strong><span class="small">Badge and launch preferences</span></div></div><div class="fields">${identityFields(item)}<details class="advanced"><summary>Launch preferences</summary><div class="fields"><div class="field"><p class="field-label">Current launch arguments</p><p class="small">${escape((item.args||[]).join(" · ")||"None configured")}</p></div>${area("Add or change launch arguments","args","One allowed switch per line. Existing switches are kept unless cleared below.")}${check("clear_args","Clear existing launch arguments","New switches entered above are added after clearing.")}<div class="field"><p class="field-label">Existing environment variables</p><p class="small">${escape((item.env||[]).join(", ")||"None configured")} · values hidden</p></div>${area("Add or change environment variables","env","One allowed NAME=value per line. Existing variables are kept unless cleared below.")}${check("clear_env","Clear existing environment variables","New values entered above are added after clearing.")}<div class="field"><label for="field-extensions">Extensions folder</label><select id="field-extensions" name="extensions"><option value="shared"${!item.own_extensions?" selected":""}>App’s default extensions</option><option value="own"${item.own_extensions?" selected":""}>Separate profile extensions</option></select></div></div></details></div>`,"Save settings",null,{build:data=>{
      const params={name:item.name,no_badge:data.has("no_badge"),args:lines(data.get("args")),env:lines(data.get("env")),clear_env:data.has("clear_env"),clear_args:data.has("clear_args")};
      if(data.get("badge")&&!params.no_badge)params.badge=data.get("badge");
      if(data.get("color"))params.color=data.get("color");
      if(data.get("extensions")==="own"&&!item.own_extensions)params.own_extensions=true;
      if(data.get("extensions")==="shared"&&item.own_extensions)params.shared_extensions=true;
      return ["set",params];
    }});setupPreview();
  }
  function renameDialog(item){
    showDialog("Rename profile","The launcher name changes; your account stays signed in.",`<div class="fields">${field("Current launcher","current",item.name,"","text","disabled")}${field("New profile name","new_name",item.profile,"The app name is added by aidentity.","text","required maxlength=\"40\"")}</div>`,"Rename profile",async(data,el)=>{
      await action("rename",{name:item.name,new_name:data.get("new_name")},el);
      selected=`${appName(item)} ${data.get("new_name")}`;
      renderView();
    },{build:data=>["rename",{name:item.name,new_name:data.get("new_name")}]});
  }
  function removeDialog(item){
    showDialog(`Remove ${item.name}?`,"Remove this launcher from your workspace.",`<div class="danger-callout">Removes the launcher. Profile data stays on this Mac unless you choose to delete it.</div><p class="muted section-gap">With its data kept, you can restore the launcher later from Recovery.</p><div class="section-gap">${check("purge","Also move the profile data to the Trash",item.main?"A Main launcher has no separate profile data.":"The account’s sign-in and local data will be removed from this workspace.")}</div>`,"Remove launcher",async(data,el)=>{await action("remove",{name:item.name,purge:data.has("purge"),confirmed:true},el);if(selected===item.name)selected="";},{danger:true,build:data=>["remove",{name:item.name,purge:data.has("purge"),confirmed:true}]});
  }
  // An app-missing launcher cannot be fixed by a rebuild alone: say what to do first, then offer the rebuild.
  function repairDialog(item){
    const app=appName(item);
    showDialog(`Repair ${item.name}`,`${app} is not where this launcher expects it.`,`<p class="muted">Reinstall ${escape(app)} or move it back to your Applications folder. Then rebuild the launcher so it points at the app again. Its profile data is not touched.</p>`,"Rebuild launcher",null,{build:()=>["rebuild",{name:item.name}]});
  }
  const targetList=names=>names.length?`<ul class="target-list">${names.map(name=>`<li>${escape(name)}</li>`).join("")}</ul>`:"";
  // body is plain text; extra is trusted HTML built with escape() (target lists).
  function confirmAction(titleText,description,body,submit,name,params={},danger=false,extra=""){
    showDialog(titleText,description,`<p class="muted">${escape(body)}</p>${extra}`,submit,null,{danger,build:()=>[name,params]});
  }
  function importDialog(){
    importDocument=null;
    showDialog("Import profile setup","Choose a JSON file created by aidentity export.",`<div class="field"><label for="import-file">Export file</label><input class="input file-input" type="file" id="import-file" accept=".json,application/json" aria-describedby="hint-import" required><p class="hint" id="hint-import">Maximum file size: 4 MiB. Account sessions are not imported.</p></div><div id="import-preview" class="import-preview" hidden></div>`,"Build launchers",async(_,el)=>{
      if(!importDocument)throw new Error("Choose and review a valid aidentity export file first.");
      const result=await action("import",{document:importDocument,confirmed:true},el,{quiet:true});
      const note=describe("import",{},result);toast(note.title,note.text,note.kind);showView("profiles",{app:""});
    },{build:()=>importDocument?["import",{document:importDocument,confirmed:true}]:null});
    $("#import-file").onchange=async event=>{
      importDocument=null;$("#import-preview").hidden=true;$("#form-error").hidden=true;$("#dialog-submit").textContent="Build launchers";$("#dialog-submit").disabled=false;
      try{
        const file=event.target.files[0];if(!file)return;
        if(file.size>4194304)throw new Error("The export file is larger than 4 MiB.");
        const data=JSON.parse(await file.text());if(data.aidentity_export!==1||!Array.isArray(data.launchers))throw new Error("Choose a format 1 aidentity export file.");
        importDocument=data;$("#import-preview").hidden=false;
        // An estimate from the dashboard's own lists: the CLI matches apps by bundle ID and checks again when it runs.
        const owned=new Set(state.profiles.map(item=>item.name)),apps=new Set(state.apps.map(item=>item.name));
        const fates={create:"will create",exists:"already exists (skipped)",missing:"app not installed (skipped)"};
        const rows=data.launchers.map(item=>{const name=String(item?.name||[item?.app,item?.profile].filter(Boolean).join(" ")||"Unnamed launcher");return {name,fate:owned.has(name)?"exists":(item?.app?!apps.has(item.app):!item?.bundle_id)?"missing":"create"};});
        const count=fate=>rows.filter(row=>row.fate===fate).length,create=count("create");
        $("#import-preview").innerHTML=`<p class="import-summary"><strong>${plural(create,"launcher")} will be created</strong>${count("exists")?` · ${count("exists")} already ${count("exists")===1?"exists":"exist"}`:""}${count("missing")?` · ${plural(count("missing"),"app")} not installed`:""}</p><ul class="import-list">${rows.map(row=>`<li data-fate="${row.fate}"><span>${escape(row.name)}</span><span class="import-fate">${fates[row.fate]}</span></li>`).join("")}</ul><p class="small">From ${escape(file.name)}. The CLI checks each launcher again when it runs.</p>`;
        const submit=$("#dialog-submit");submit.textContent=create?`Create ${plural(create,"launcher")}`:"Nothing to create";submit.disabled=!create;
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
  async function handleAction(name,el){
    const item=profile(el.dataset.name);
    if(name==="workspace")return showView("profiles",{app:"",focus:true});
    if(name==="refresh")return refresh({notify:true,force:true});
    if(name==="add")return addDialog(el.dataset.app);
    if(name==="select"){selected=el.dataset.name;mobileDetail=true;renderNav();renderProfiles();positionTabs();animateMotion($(".detail-panel"),[{opacity:0,translate:"8px 0"},{opacity:1,translate:"0 0"}]);if(mobile.matches)window.scrollTo({top:0,behavior:"instant"});$("#detail-title")?.focus();return;}
    if(name==="close-detail"||name==="back-profiles"){const was=selected;selected="";mobileDetail=false;renderNav();renderProfiles();positionTabs();$$(".profile-name",main).find(el=>el.dataset.name===was)?.focus();return;}
    if(name==="clear-search"){query="";renderView();$("#workspace-search")?.focus();return;}
    if(name==="all-apps"){appFilter="";renderView();return;}
    if(name==="show-all"){statusFilter="all";renderProfiles();positionTabs();$("#status-all")?.focus();return;}
    if(name==="repair"&&item)return item.status==="app missing"?repairDialog(item):action("rebuild",{name:item.name},el);
    if(name==="copy-command"){
      const code=$("#command-echo code",dialog)?.textContent;if(!code)return;
      await navigator.clipboard.writeText(code);el.innerHTML=icon("check");el.setAttribute("aria-label","Copied");
      setTimeout(()=>{if(el.isConnected){el.innerHTML=icon("copy");el.setAttribute("aria-label","Copy command");}},1500);return;
    }
    if(name==="reset-filters"){query="";appFilter="";statusFilter="all";renderView();return;}
    if(name==="settings"&&item)return settingsDialog(item);
    if(name==="rename"&&item)return renameDialog(item);
    if(name==="remove"&&item)return removeDialog(item);
    if(name==="open"||name==="quit"||name==="restore"||name==="rebuild")return action(name,{name:el.dataset.name},el);
    if(name==="restore-all")return confirmAction("Restore all launchers?","Reconnect every restorable profile.",`${plural(state.restorable.length,"recorded profile")} will get new launchers using their existing account data.`,"Restore all","restore",{all:true},false,targetList(state.restorable.map(entry=>entry.name)));
    if(name==="rebuild-all")return confirmAction("Rebuild all launchers?","Refresh launcher bundles for every profile.",`${plural(state.profiles.length,"launcher")} will be rebuilt. Each profile keeps its account data.`,"Rebuild all","rebuild",{all:true});
    if(name==="prune"){
      const names=(state.restorable||[]).map(entry=>entry.name);
      return confirmAction("Move unclaimed data to the Trash?","Unclaimed data is profile data that no launcher uses.",names.length?`${plural(names.length,"restorable profile")} will move to the Trash, along with any other profile folder no launcher uses. Restore the ones you want to keep first.`:"No restorable profile is waiting. Any profile folder that no launcher uses will move to the Trash.","Move to Trash","prune",{confirmed:true},true,targetList(names));
    }
    if(name==="doctor")return action("doctor",{},el);
    if(name==="doctor-fix")return confirmAction("Check and repair the workspace?","Run doctor with automatic fixes.","Doctor checks the setup, then rebuilds the launchers it can repair.","Check & fix","doctor",{fix:true});
    if(name==="update-check")return action("update",{check:true},el);
    if(name==="update")return confirmAction("Install the latest aidentity?","Update this CLI installation.","The CLI checks its release source and installation before replacing the current executable.","Update aidentity","update",{check:false});
    if(name==="import")return importDialog();
    if(name==="export")return showDialog("Export launcher recipes?","Download your profile setup as JSON.",'<p class="muted">The file includes launch settings and may contain private environment or proxy values. Account sessions and profile data stay on this Mac.</p>',"Download private recipe",async(_,submit)=>{await exportSetup(submit);},{build:()=>["export",{}]});
    if(name==="help"){const command=$("#help-command").value;const result=await action("help",command?{command}:{},el,{quiet:true});guideText=result.stdout;renderGuide();return;}
    if(name==="completion"){const result=await action("completion",{shell:$("#completion-shell").value},el,{quiet:true});guideText=result.stdout;renderGuide();return;}
    if(name==="copy-guide"){if(!guideText)return toast("No output yet","Read command help or generate completion first.");await navigator.clipboard.writeText(guideText);toast("Copied","Command output copied to your clipboard.");}
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
      const oldLeft=main.getBoundingClientRect().left;
      document.body.classList.toggle("sidebar-collapsed");$("#collapse-nav").setAttribute("aria-label",document.body.classList.contains("sidebar-collapsed")?"Expand sidebar":"Collapse sidebar");
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
  function showActivity(open){
    const panel=$("#activity-panel");if(panel.hidden===!open)return;
    panel.hidden=!open;$("#activity-toggle").setAttribute("aria-expanded",String(open));
    if(open)animateMotion(panel,[{opacity:0,translate:"0 10px"},{opacity:1,translate:"0 0"}]);
  }
  document.addEventListener("click",event=>{
    if(event.target.closest("#experience-root"))return;
    const close=event.target.closest("[data-close-dialog]");if(close){closeDialog();return;}
    const swatch=event.target.closest("[data-color]");if(swatch){$('[name="color"]',dialog).value=swatch.dataset.color;$$(".color-swatch",dialog).forEach(el=>el.setAttribute("aria-pressed",el===swatch));setupPreviewUpdate();return;}
    const nav=event.target.closest("[data-view]");if(nav){query="";showView(nav.dataset.view,{focus:true});return;}
    const app=event.target.closest("[data-app-filter]");if(app){query="";statusFilter="all";showView("profiles",{app:app.dataset.appFilter,focus:true});return;}
    const filter=event.target.closest("[data-filter]");if(filter){statusFilter=filter.dataset.filter;keepFocus(renderProfiles);positionTabs();return;}
    const control=event.target.closest("[data-action]");if(control?.hasAttribute("data-locked"))return;if(control)handleAction(control.dataset.action,control).catch(error=>{if(!error.reported)toast("Could not complete the action",error.message,true);});
  });
  document.addEventListener("input",event=>{
    if(event.target.id!=="workspace-search")return;query=event.target.value;keepFocus(renderView);
  });
  document.addEventListener("change",event=>{if(event.target.id==="app-filter"){appFilter=event.target.value;keepFocus(renderView);}});
  document.addEventListener("keydown",event=>{
    if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==="b"){event.preventDefault();toggleNavigation();}
    if(event.key==="Escape"&&document.body.classList.contains("mobile-nav-open")){closeNavigation();$("#mobile-nav").focus();}
    if(event.key==="/"&&!event.metaKey&&!event.ctrlKey&&!event.altKey&&!dialog.open&&!event.target.closest?.("input,textarea,select,[contenteditable]")){const search=$("#workspace-search");if(search){event.preventDefault();search.focus();search.select();}}
    if(event.key==="Escape"&&event.target.id==="workspace-search"&&event.target.value){event.preventDefault();event.target.value="";query="";keepFocus(renderView);}
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
  $("#nav-scrim").onclick=()=>{closeNavigation();$("#mobile-nav").focus();};
  $("#activity-toggle").onclick=()=>showActivity($("#activity-panel").hidden);
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
  hydrateIcons();renderNav();refresh();schedulePoll();
})();
