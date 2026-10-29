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
  const button = (label, action, opts = {}) => `<button class="button ${opts.primary ? "button-primary" : ""} ${opts.danger ? "button-danger" : ""} ${opts.small ? "button-small" : ""}" data-action="${escape(action)}"${opts.name ? ` data-name="${escape(opts.name)}"` : ""}${opts.app ? ` data-app="${escape(opts.app)}"` : ""}${opts.disabled ? " disabled" : ""}>${opts.icon ? icon(opts.icon) : ""}<span>${escape(label)}</span></button>`;
  const colors = [["Blue","2E7DF6"],["Green","2FB344"],["Orange","F76B15"],["Purple","8E4EC6"],["Teal","12A594"],["Pink","D6409F"],["Red","E5484D"],["Yellow","F5B400"],["Gray","6B7280"],["Graphite","1F2430"]];
  const navigation = [
    ["explore","Explore","explore"],["profiles","Profiles","grid"],["apps","Applications","apps"],
    ["recovery","Recovery","recovery"],["maintenance","Maintenance","tool"],["transfer","Import & export","transfer"]
  ];
  const main = $("#main");
  const dialog = $("#dialog");
  const reducedMotion=matchMedia("(prefers-reduced-motion: reduce)");
  const motionAnimations=new WeakMap();
  const motionCurve=kind=>getComputedStyle(document.documentElement).getPropertyValue(kind==="control"?"--spring-control":"--spring-surface").trim()||"cubic-bezier(.16,1,.3,1)";
  function animateMotion(element,frames,kind="surface",options={}){
    if(!element||reducedMotion.matches||!element.animate)return null;
    motionAnimations.get(element)?.cancel();
    const animation=element.animate(frames,{duration:kind==="control"?360:520,easing:motionCurve(kind),...options});
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
  let history = [], guideText = "", importDocument = null, tabPosition=null;
  let dialogRevision=0,dialogCloseTimer=null,navCloseTimer=null;
  const time = date => new Intl.DateTimeFormat(undefined,{hour:"2-digit",minute:"2-digit"}).format(date);
  const profile = name => state?.profiles.find(item => item.name === name);
  const appName = item => item.app || "Unknown app";
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
  const art = (name, badge = null, color = "") => `<span class="app-art">${appGlyph(name)}${badge ? `<span class="identity-badge" style="--identity-color:#${/^[0-9a-f]{6}$/i.test(color) ? color : "F76B15"}">${escape(badge)}</span>` : ""}</span>`;
  const statusMark = item => `<span class="profile-state ${item.status === "running" ? "status-running" : item.status === "app missing" ? "status-missing" : ""}">${item.status === "running" ? '<span class="running-dot"></span>' : ""}${escape(item.status)}</span>`;
  function hydrateIcons(root=document) { $$("[data-icon]",root).forEach(el => {el.innerHTML=icon(el.dataset.icon);el.removeAttribute("data-icon");}); }
  function renderNav() {
    $("#primary-nav").innerHTML=navigation.map(([id,label,glyph])=>`<button class="nav-item" data-view="${id}" title="${label}"${view===id?' aria-current="page"':""}>${icon(glyph)}<span class="nav-label">${label}</span></button>`).join("");
    const apps = [...new Set((state?.profiles || []).map(appName))].sort();
    $("#app-nav").innerHTML=apps.map(name=>`<button class="nav-item nav-app" data-app-filter="${escape(name)}" title="${escape(name)}"><span class="app-mini">${appGlyph(name)}</span><span class="nav-label">${escape(name)}</span></button>`).join("") || '<p class="small nav-label" style="padding:0 12px">Add your first profile</p>';
    $$(".sidebar-foot [data-view]").forEach(el=>el.setAttribute("aria-current",view===el.dataset.view?"page":"false"));
    $("#version").textContent=state?.version ? `aidentity ${String(state.version).replace(/^aidentity\s*/,"")}`:"aidentity";
    $("#breadcrumb").textContent=navigation.find(item=>item[0]===view)?.[1] || "Command guide";
  }
  function title(name,description,actions=""){return `<div class="title-row"><div><h1>${escape(name)}</h1><p>${escape(description)}</p></div>${actions?`<div class="title-actions">${actions}</div>`:""}</div>`;}
  function searchField(placeholder){return `<div class="search-field">${icon("search")}<input id="workspace-search" class="input" type="search" aria-label="${escape(placeholder)}" placeholder="${escape(placeholder)}" value="${escape(query)}">${query?`<button class="icon-button" data-action="clear-search" aria-label="Clear search">${icon("x")}</button>`:""}</div>`;}
  // educalvolpz Animated Tabs translated to native tabs with measured sliding indicator.
  function tabs(items,active){return `<div class="tabs" role="tablist" aria-label="Profile status">${items.map(([id,label,count])=>`<button id="status-${id}" role="tab" aria-selected="${active===id}" tabindex="${active===id?0:-1}" data-filter="${id}">${label}<span class="tab-count">${count}</span></button>`).join("")}<span class="tab-indicator"></span></div>`;}
  function positionTabs(){
    const tab=$('.tabs [aria-selected=true]'),line=$(".tab-indicator");if(!tab||!line)return;
    const scope=`${appFilter}:${query}`,next={left:tab.offsetLeft,width:tab.offsetWidth,scope};
    const transform=`translateX(${next.left}px) scaleX(${next.width})`;
    line.style.width="1px";line.style.transform=transform;
    if(tabPosition?.scope===scope&&(tabPosition.left!==next.left||tabPosition.width!==next.width)){
      animateMotion(line,[{transform:`translateX(${tabPosition.left}px) scaleX(${tabPosition.width})`},{transform}],"control");
    }
    tabPosition=next;
  }
  function showView(next,options={}){
    if(cleanupExperience){cleanupExperience();cleanupExperience=null;}
    view=next;mobileDetail=false;
    window.history.replaceState(null,"",`#${next}`);
    if(options.app!==undefined)appFilter=options.app;
    if(options.profile){selected=options.profile;mobileDetail=true;}
    renderNav();renderView();animateWorkspaceChange();
    closeNavigation();window.scrollTo({top:0,behavior:"instant"});
  }
  function renderView(){
    if(!state)return;
    main.classList.remove("profile-detail-mobile");
    if(view==="explore"){
      if(cleanupExperience)return;
      main.innerHTML='<div id="experience-root"></div>';
      if(window.AidentityExperience)cleanupExperience=window.AidentityExperience.mount($("#experience-root"),state,{openProfile:item=>showView("profiles",{profile:typeof item==="string"?item:item.name,app:""}),addProfile:app=>addDialog(app || ""),showProfiles:()=>showView("profiles",{app:""})});
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
  function scopedProfiles(){return state.profiles.filter(item=>(!appFilter||appName(item)===appFilter)&&(!query||`${item.name} ${appName(item)} ${item.profile}`.toLowerCase().includes(query.toLowerCase())));}
  function renderProfiles(){
    main.classList.toggle("profile-detail-mobile",mobileDetail);
    const scoped=scopedProfiles();
    const running=scoped.filter(item=>item.status==="running").length;
    const visible=scoped.filter(item=>statusFilter==="all"||(statusFilter==="running"?item.status==="running":statusFilter==="attention"?item.status==="app missing":item.status!=="running"));
    const chosen=profile(selected);
    main.innerHTML=title(appFilter||"Profiles","Your accounts have their own space. Open one and pick up where you left off.")+
      `<div class="stat-line"><span><strong class="num">${scoped.length}</strong> ${scoped.length===1?"profile":"profiles"}</span><span><span class="running-dot"></span><strong class="num">${running}</strong> running</span><span><strong class="num">${new Set(scoped.map(appName)).size}</strong> apps</span></div>`+
      tabs([["all","All profiles",scoped.length],["running","Running",running],["idle","At rest",scoped.length-running],["attention","Needs repair",scoped.filter(item=>item.status==="app missing").length]],statusFilter)+
      `<div class="toolbar">${searchField("Search profiles")}<div class="toolbar-end">${appFilter?button("All apps","all-apps",{small:true}):""}<select id="app-filter" aria-label="Filter by application"><option value="">All apps</option>${[...new Set(state.profiles.map(appName))].sort().map(name=>`<option${name===appFilter?" selected":""}>${escape(name)}</option>`).join("")}</select><span class="small">${visible.length} ${visible.length===1?"profile":"profiles"}</span></div></div>`+
      `<div class="profile-layout ${chosen?"":"no-selection"} ${mobileDetail?"mobile-detail":""}"><div class="profile-grid" data-count="${visible.length}">${visible.map(card).join("")||`<div class="empty-state"><h2>${state.profiles.length?"No matching profiles":"A new space for your next account"}</h2><p>${state.profiles.length?"Try another app or search.":"Choose an installed app, name the account, and create its own launcher."}</p>${button(state.profiles.length?"Clear filters":"Create your first profile",state.profiles.length?"reset-filters":"add",{primary:true,icon:state.profiles.length?"search":"plus"})}</div>`}</div>${chosen?detail(chosen):""}</div>`;
  }
  // ravikatiyar162 ProfileCard structure: cover, offset identity, role/meta and
  // full-width action. Account badge replaces human avatar; CLI fields replace stats.
  function card(item){
    return `<article class="profile-card ${selected===item.name?"selected":""}"><div class="profile-cover"><button class="icon-button" data-action="select" data-name="${escape(item.name)}" aria-label="Details for ${escape(item.name)}" title="Profile details">${icon("more")}</button></div><div class="profile-body">${art(appName(item),item.badge,item.color)}<button class="profile-name" data-action="select" data-name="${escape(item.name)}" title="${escape(item.name)}">${escape(item.profile||item.name)}</button><div class="profile-app">${escape(appName(item))}</div>${statusMark(item)}<div class="profile-meta"><span>${item.main?"Original account":"Separate account"}</span><span>${item.own_extensions?"Own extensions":`${(item.args||[]).length} ${(item.args||[]).length===1?"flag":"flags"}`}</span></div><button class="button open-profile ${item.status==="running"?"":"button-secondary"}" data-action="${item.status==="running"?"quit":"open"}" data-name="${escape(item.name)}">${icon(item.status==="running"?"stop":"play")}<span>${item.status==="running"?"Quit profile":"Open profile"}</span></button></div></article>`;
  }
  function detail(item){
    return `<aside class="detail-panel" aria-label="Selected profile details">${button("Back to profiles","back-profiles",{small:true,icon:"back"}).replace('class="button ','class="button detail-back ')}<div class="detail-top">${art(appName(item),item.badge,item.color)}<button class="icon-button" data-action="close-detail" aria-label="Close details">${icon("x")}</button></div><h2>${escape(item.name)}</h2><p class="small">${item.main?"Opens the app’s original account":"An independent account launcher"}</p>${statusMark(item)}<div class="detail-actions">${button(item.status==="running"?"Quit profile":"Open profile",item.status==="running"?"quit":"open",{primary:true,icon:item.status==="running"?"stop":"play",name:item.name})}${item.status==="running"?button("Bring to front","open",{icon:"play",name:item.name}):""}${button("Settings","settings",{icon:"settings",name:item.name})}</div><dl class="details"><div><dt>Application</dt><dd>${escape(item.app_path||appName(item))}</dd></div><div><dt>Profile data</dt><dd>${escape(item.main?"The app’s own original account":item.data_dir||"No folder recorded")}</dd></div><div><dt>Launch arguments</dt><dd>${(item.args||[]).length?(item.args||[]).map(arg=>`<code>${escape(arg)}</code>`).join("<br>"):"No additional arguments"}</dd></div><div><dt>Environment variables</dt><dd>${(item.env||[]).length?escape(item.env.join(", "))+"<br><span class='small'>Values stay private</span>":"None configured"}</dd></div><div><dt>Extensions</dt><dd>${item.own_extensions?"Separate extensions folder":"App’s default extensions"}</dd></div><div><dt>Launcher version</dt><dd>${escape(item.built_by||"Not recorded")}</dd></div></dl><div class="detail-footer">${button("Rename","rename",{small:true,icon:"rename",name:item.name})}${button("Rebuild","rebuild",{small:true,icon:"refresh",name:item.name})}${button("Remove","remove",{small:true,danger:true,icon:"trash",name:item.name})}</div></aside>`;
  }
  function renderApps(){
    const apps=state.apps.filter(item=>!query||item.name.toLowerCase().includes(query.toLowerCase()));
    main.innerHTML=title("Applications",`${state.apps.length} compatible ${state.apps.length===1?"app":"apps"} found on this Mac.`)+`<div class="toolbar">${searchField("Search installed apps")}</div><div class="apps-grid">${apps.map(item=>{const count=state.profiles.filter(p=>appName(p)===item.name).length;return `<article class="application-card">${art(item.name)}<h2>${escape(item.name)}</h2><p>${count} ${count===1?"profile":"profiles"} configured</p>${button("Add account","add",{icon:"plus",app:item.name})}</article>`;}).join("")||'<div class="empty-state"><h2>No compatible apps found</h2><p>Install a Chromium or Electron app, then refresh this workspace.</p>'+button("Refresh apps","refresh",{icon:"refresh"})+"</div>"}</div>`;
  }
  function renderRecovery(){
    const entries=state.restorable||[];
    main.innerHTML=title("Recovery","Recreate deleted launchers and reconnect them to their existing profile data.")+
    `<section class="panel"><div class="panel-heading"><h2>${entries.length} restorable ${entries.length===1?"profile":"profiles"}</h2>${button("Restore all","restore-all",{icon:"recovery",disabled:!entries.length})}</div><div class="recovery-list">${entries.map(item=>`<div class="recovery-row"><div><h3>${escape(item.name)}</h3><p>The profile data remains on this Mac.</p></div>${button("Restore","restore",{icon:"recovery",name:item.name})}</div>`).join("")||'<p class="muted">Every profile with a restore record already has a launcher.</p>'}</div></section>`+
    `<div class="operation-grid section-gap"><section class="operation-card">${icon("refresh")}<h2>Rebuild launchers</h2><p>Repair launcher bundles after an app is moved or updated. Each account keeps its profile data.</p><div class="button-row">${button("Rebuild all","rebuild-all",{icon:"refresh"})}</div></section><section class="operation-card">${icon("trash")}<h2>Clear unclaimed data</h2><p>Move profile folders with no launcher to the Trash. Restore any account you want to keep first.</p><div class="button-row">${button("Review & prune","prune",{danger:true,icon:"trash"})}</div></section></div>`;
  }
  function renderMaintenance(){
    main.innerHTML=title("Maintenance","Check your setup, repair launchers, and keep aidentity current.")+
    `<div class="operation-grid"><section class="operation-card">${icon("shield")}<h2>Workspace health</h2><p>Check the setup and every profile for missing apps, stale launchers, and configuration issues.</p><div class="button-row">${button("Run doctor","doctor",{primary:true,icon:"shield"})}${button("Check & fix","doctor-fix",{icon:"tool"})}</div></section><section class="operation-card">${icon("download")}<h2>aidentity updates</h2><p>Installed version: <span class="num">${escape(state.version)}</span>. Check for a new release or install the latest one.</p><div class="button-row">${button("Check for updates","update-check",{icon:"refresh"})}${button("Update now","update",{icon:"download"})}</div></section><section class="operation-card">${icon("refresh")}<h2>Refresh launchers</h2><p>Rebuild every launcher using its recorded identity and current application path.</p><div class="button-row">${button("Rebuild all","rebuild-all",{icon:"refresh"})}</div></section><section class="operation-card">${icon("folder")}<h2>Local storage</h2><p>Launchers and their data are stored in these workspace locations.</p><div class="path-list"><span>Launchers<br><strong>${escape(state.paths?.launchers||"Not available")}</strong></span><span>Profile data<br><strong>${escape(state.paths?.data||"Not available")}</strong></span></div></section></div>${(state.errors||[]).length?`<div class="notice error">${state.errors.map(escape).join("<br>")}</div>`:""}`;
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
    if(loading)return;loading=true;
    try{
      const response=await fetch("/api/state",{cache:"no-store"});
      const data=await response.json();
      if(!response.ok||!data.ok)throw new Error(data.error||"Could not read the workspace.");
      const firstLoad=!state;
      state=data;loadedAt=new Date();$("#freshness").textContent=`Updated ${time(loadedAt)}`;
      const current=JSON.stringify({version:data.version,profiles:data.profiles,apps:data.apps,restorable:data.restorable,errors:data.errors});
      renderNav();
      if(current!==lastData||options.force){
        lastData=current;
        const previousScroll=window.scrollY;
        if(view==="explore"&&cleanupExperience){cleanupExperience();cleanupExperience=null;}
        renderView();
        if(firstLoad)animateWorkspaceChange();
        if(view==="explore")requestAnimationFrame(()=>requestAnimationFrame(()=>window.scrollTo({top:previousScroll,behavior:"instant"})));
      }
      if(options.notify)toast("Workspace refreshed","Profiles and installed apps are up to date.");
    }catch(error){
      if(!state)main.innerHTML=title("Workspace unavailable","The local server could not read your setup.")+`<div class="notice error">${escape(error.message)}</div><div class="section-gap">${button("Retry connection","refresh",{primary:true,icon:"refresh"})}</div>`;
      $("#freshness").textContent=loadedAt?`Last updated ${time(loadedAt)}`:"Connection unavailable";
      if(options.notify)toast("Refresh failed",error.message,true);
    }finally{loading=false;}
  }
  function setBusy(element,on){
    if(!element)return;
    if(on){element.dataset.original=element.innerHTML;element.innerHTML=`<span class="button-content">${element.innerHTML}</span><span class="button-loader"><span class="spinner"></span></span>`;element.dataset.loading="true";element.disabled=true;element.setAttribute("aria-busy","true");}
    else {if(element.dataset.original!==undefined)element.innerHTML=element.dataset.original;delete element.dataset.loading;element.disabled=false;element.removeAttribute("aria-busy");}
  }
  async function action(name,params={},element=null,{quiet=false}={}){
    if(busy)throw new Error("An operation is already running. Wait for it to finish.");
    if(!state?.csrf_token)throw new Error("The workspace is not connected. Refresh and try again.");
    busy=true;setBusy(element,true);
    $("#activity-summary").textContent=`Running ${name}…`;
    try{
      const response=await fetch("/api/action",{method:"POST",headers:{"Content-Type":"application/json","X-AIdentity-CSRF":state.csrf_token},body:JSON.stringify({action:name,...params})});
      const result=await response.json();
      const record={action:name,ok:Boolean(result.ok),time:new Date(),output:name==="export"?"Launcher recipe prepared for download.":[result.stdout,result.stderr,result.error].filter(Boolean).join("\n")};
      history.unshift(record);history=history.slice(0,12);renderActivity();
      if(!response.ok||!result.ok)throw new Error(result.error||result.stderr||result.stdout||`${name} failed (exit ${result.exit_code}).`);
      if(!quiet)toast(`${name[0].toUpperCase()+name.slice(1)} complete`,params.name||"The operation finished successfully.");
      await refresh({force:true});
      return result;
    }catch(error){
      if(!quiet)toast("Operation failed",String(error.message).slice(0,180),true);
      $("#activity-summary").textContent=`${name} failed · View details`;
      throw error;
    }finally{busy=false;setBusy(element,false);}
  }
  function renderActivity(){
    $("#activity-content").innerHTML=history.map(item=>`<article class="activity-entry"><div class="activity-entry-title"><strong class="${item.ok?"":"activity-error"}">${escape(item.action)} · ${item.ok?"Completed":"Failed"}</strong><time>${time(item.time)}</time></div><pre class="output">${escape(item.output||"Completed without additional output.")}</pre></article>`).join("");
    if(history[0])$("#activity-summary").textContent=`${history[0].action} ${history[0].ok?"completed":"failed"} · View details`;
  }
  function toast(titleText,description,error=false){
    const viewport=$("#toast-viewport");
    const node=document.createElement("div");node.className=`toast ${error?"error":""}`;node.setAttribute("role",error?"alert":"status");
    node.innerHTML=`${icon(error?"alert":"check")}<div><strong>${escape(titleText)}</strong><p>${escape(description)}</p><button class="toast-action">View activity</button></div><button class="icon-button" aria-label="Dismiss notification">${icon("x")}</button>`;
    const dismiss=()=>{if(node.classList.contains("dismiss"))return;node.classList.add("dismiss");setTimeout(()=>animateToastLayout(()=>node.remove()),reducedMotion.matches?0:200);};
    $(".icon-button",node).onclick=dismiss;
    $(".toast-action",node).onclick=()=>{showActivity(true);dismiss();};
    animateToastLayout(()=>{viewport.prepend(node);while(viewport.children.length>3)viewport.lastChild.remove();});
    let timer=setTimeout(dismiss,error?12000:5500);
    const pause=()=>clearTimeout(timer),resume=()=>{clearTimeout(timer);if(!node.matches(":hover")&&!node.contains(document.activeElement))timer=setTimeout(dismiss,3000);};
    node.onpointerenter=pause;node.onpointerleave=resume;node.onfocusin=pause;node.onfocusout=resume;
  }
  // rmahammad Animated Dialog's fixed header/body/footer translated to <dialog>.
  function showDialog(titleText,description,body,submitText,submit,{danger=false}={}){
    clearTimeout(dialogCloseTimer);dialogRevision++;
    lastFocus=document.activeElement;dialogSubmit=submit;dialog.classList.remove("closing");
    dialog.innerHTML=`<form id="dialog-form" class="dialog-inner"><header class="dialog-header"><h2 id="dialog-title">${escape(titleText)}</h2><p id="dialog-description">${escape(description)}</p><button type="button" class="icon-button" data-close-dialog aria-label="Close dialog">${icon("x")}</button></header><div class="dialog-body">${body}<div id="form-error" class="form-error" role="alert" hidden></div></div><footer class="dialog-footer"><button type="button" class="button" data-close-dialog>Cancel</button><button type="submit" class="button ${danger?"button-danger":"button-primary"}" id="dialog-submit">${escape(submitText)}</button></footer></form>`;
    dialog.showModal();
    animateMotion($(".dialog-header",dialog),[{opacity:0,translate:"0 5px"},{opacity:1,translate:"0 0"}],"surface",{duration:420,delay:25});
    $("#dialog-form").onsubmit=async event=>{
      event.preventDefault();const form=event.currentTarget;
      if(!form.reportValidity())return;
      $("#form-error").hidden=true;
      try{await dialogSubmit(new FormData(form),$("#dialog-submit"));closeDialog();}
      catch(error){$("#form-error").textContent=error.message;$("#form-error").hidden=false;}
    };
  }
  function closeDialog(){
    if($("#dialog-submit")?.getAttribute("aria-busy")==="true")return;
    if(!dialog.open||dialog.classList.contains("closing"))return;
    const revision=dialogRevision;
    dialog.classList.add("closing");
    dialogCloseTimer=setTimeout(()=>{if(revision!==dialogRevision)return;dialog.close();dialog.innerHTML="";dialogSubmit=null;importDocument=null;lastFocus?.focus({preventScroll:true});},reducedMotion.matches?0:200);
  }
  const field=(label,name,value="",hint="",type="text",attrs="")=>`<div class="field"><label for="field-${name}">${label}</label><input class="input" id="field-${name}" name="${name}" type="${type}" value="${escape(value)}" ${attrs}>${hint?`<p class="hint">${hint}</p>`:""}</div>`;
  const check=(name,label,description="",checked=false)=>`<label class="check-row"><input type="checkbox" name="${name}" ${checked?"checked":""}><span>${label}${description?`<span>${description}</span>`:""}</span></label>`;
  const area=(label,name,hint="")=>`<div class="field"><label for="field-${name}">${label}</label><textarea id="field-${name}" name="${name}" rows="3" spellcheck="false" autocomplete="off"></textarea>${hint?`<p class="hint">${hint}</p>`:""}</div>`;
  function identityFields(p=null){
    return `<div class="field-pair">${field("Badge character","badge",p?.badge||"","One character displayed on the app icon.","text",'maxlength="4"')}${field("Badge color","color",p?.color||"F76B15","Color name or six hex digits.")}</div><div class="color-options" aria-label="Badge color presets">${colors.map(([name,color])=>`<button type="button" class="color-swatch" style="--swatch:#${color}" data-color="${color}" title="${name}" aria-label="${name}" aria-pressed="${(p?.color||"F76B15").toUpperCase()===color}"></button>`).join("")}</div>${check("no_badge","Use the original app icon","Hide the colored account badge.",p?.badge===null)}`;
  }
  function addDialog(app=""){
    if(!state)return;
    const options=state.apps.map(item=>`<option value="${escape(item.name)}"${item.name===app?" selected":""}>${escape(item.name)}</option>`).join("");
    showDialog("Create a profile","Give another account its own launcher and profile folder.",`<div class="preview-row" id="identity-preview">${art(app||state.apps[0]?.name||"App","W","F76B15")}<div><strong id="preview-name">${escape(app||state.apps[0]?.name||"App")} Work</strong><span class="small">Your new account launcher</span></div></div><div class="fields"><div class="field"><label for="field-app">Application</label><select name="app" id="field-app" required>${options||'<option value="">No compatible apps found</option>'}</select></div>${field("Application path (optional)","app_path","","Use a full .app path for an application outside discovery.","text",'placeholder="/Applications/Example.app"')}${field("Profile name","profile","","For example, Work, Personal, or Client.","text",'required maxlength="40" placeholder="Work"')}${identityFields()}${check("main","Open the original account","Create a Main launcher for the app’s existing account.")}<details class="advanced"><summary>Launch settings & advanced options</summary><div class="fields">${check("seed","Copy Claude’s MCP configuration","For Claude Desktop profiles only. Copies the existing configuration into the new profile.")}${area("Launch arguments","args","One allowed switch per line, for example --lang=de.")}${area("Environment variables","env","One allowed NAME=value per line. Values are never displayed in this dashboard.")}${check("own_extensions","Use a separate extensions folder","For VS Code-style applications.")}</div></details></div>`, "Create profile",async(data,el)=>{
      const params={app:String(data.get("app_path")||"").trim()||data.get("app"),profile:data.get("profile"),color:data.get("color"),no_badge:data.has("no_badge"),main:data.has("main"),seed:data.has("seed"),args:lines(data.get("args")),env:lines(data.get("env")),own_extensions:data.has("own_extensions")};
      if(data.get("badge")&&!params.no_badge)params.badge=data.get("badge");
      await action("add",params,el);showView("profiles",{app:""});
    });
    setupPreview();
    $('[name="main"]',dialog).onchange=event=>{if(event.target.checked&&!$('[name="profile"]',dialog).value)$('[name="profile"]',dialog).value="Main";setupPreviewUpdate();};
  }
  const lines=value=>String(value||"").split(/\r?\n/).map(v=>v.trim()).filter(Boolean);
  function setupPreview(){
    $$('input,select',dialog).forEach(input=>input.addEventListener("input",setupPreviewUpdate));setupPreviewUpdate();
  }
  function setupPreviewUpdate(){
    const preview=$("#identity-preview");if(!preview)return;
    const path=String($('[name="app_path"]',dialog)?.value||"").trim();
    const appSelect=$('[name="app"]',dialog);
    if(appSelect)appSelect.required=!path;
    const app=path?path.replace(/\/+$/,"").split("/").pop().replace(/\.app$/i,""):appSelect?.value||preview.dataset.app||"App";
    const name=$('[name="profile"]',dialog)?.value||preview.dataset.profile||"Work";
    const badge=$('[name="no_badge"]',dialog)?.checked?null:$('[name="badge"]',dialog)?.value||[...name][0]?.toUpperCase();
    const raw=$('[name="color"]',dialog)?.value||"F76B15";const hex=colors.find(([name])=>name.toLowerCase()===raw.toLowerCase())?.[1]||raw;
    preview.innerHTML=art(app,badge,hex)+`<div><strong>${escape(app)} ${escape(name)}</strong><span class="small">Your account launcher</span></div>`;
  }
  function settingsDialog(item){
    showDialog("Profile settings",item.name,`<div class="preview-row" id="identity-preview" data-app="${escape(appName(item))}" data-profile="${escape(item.profile)}">${art(appName(item),item.badge,item.color)}<div><strong>${escape(item.name)}</strong><span class="small">Badge and launch preferences</span></div></div><div class="fields">${identityFields(item)}<details class="advanced" open><summary>Launch preferences</summary><div class="fields"><div class="field"><label>Current launch arguments</label><p class="small">${escape((item.args||[]).join(" · ")||"None configured")}</p></div>${area("Add or change launch arguments","args","One allowed switch per line. Existing switches are kept unless cleared below.")}${check("clear_args","Clear existing launch arguments","New switches entered above are added after clearing.")}<div class="field"><label>Existing environment variables</label><p class="small">${escape((item.env||[]).join(", ")||"None configured")} · values hidden</p></div>${area("Add or change environment variables","env","One allowed NAME=value per line. Existing variables are kept unless cleared below.")}${check("clear_env","Clear existing environment variables","New values entered above are added after clearing.")}<div class="field"><label for="field-extensions">Extensions folder</label><select id="field-extensions" name="extensions"><option value="shared"${!item.own_extensions?" selected":""}>App’s default extensions</option><option value="own"${item.own_extensions?" selected":""}>Separate profile extensions</option></select></div></div></details></div>`,"Save settings",async(data,el)=>{
      const params={name:item.name,no_badge:data.has("no_badge"),args:lines(data.get("args")),env:lines(data.get("env")),clear_env:data.has("clear_env"),clear_args:data.has("clear_args")};
      if(data.get("badge")&&!params.no_badge)params.badge=data.get("badge");
      if(data.get("color"))params.color=data.get("color");
      if(data.get("extensions")==="own"&&!item.own_extensions)params.own_extensions=true;
      if(data.get("extensions")==="shared"&&item.own_extensions)params.shared_extensions=true;
      await action("set",params,el);
    });setupPreview();
  }
  function renameDialog(item){
    showDialog("Rename profile","The launcher name changes; your account stays signed in.",`<div class="fields">${field("Current launcher","current",item.name,"","text","disabled")}${field("New profile name","new_name",item.profile,"The app name is added by aidentity.","text","required maxlength=\"40\"")}</div>`,"Rename profile",async(data,el)=>{
      await action("rename",{name:item.name,new_name:data.get("new_name")},el);
      selected=`${appName(item)} ${data.get("new_name")}`;
      renderView();
    });
  }
  function removeDialog(item){
    showDialog(`Remove ${item.name}?`,"Remove this launcher from your workspace.",`<p class="muted">Its account data is kept by default, so you can restore the launcher later.</p><div class="section-gap">${check("purge","Also move the profile data to the Trash",item.main?"A Main launcher has no separate profile data.":"The account’s sign-in and local data will be removed from this workspace.")}</div><div class="danger-callout">Launcher: <strong>${escape(item.name)}</strong></div>`,"Remove launcher",async(data,el)=>{await action("remove",{name:item.name,purge:data.has("purge"),confirmed:true},el);if(selected===item.name)selected="";},{danger:true});
  }
  function confirmAction(titleText,description,body,submit,name,params={},danger=false){
    showDialog(titleText,description,`<p class="muted">${body}</p>`,submit,async(_,el)=>{await action(name,params,el);},{danger});
  }
  function importDialog(){
    importDocument=null;
    showDialog("Import profile setup","Choose a JSON file created by aidentity export.",`<div class="field"><label for="import-file">Export file</label><input class="input file-input" type="file" id="import-file" accept=".json,application/json" required><p class="hint">Maximum file size: 4 MiB. Account sessions are not imported.</p></div><div id="import-preview" class="import-preview" hidden></div>`,"Build launchers",async(_,el)=>{
      if(!importDocument)throw new Error("Choose and review a valid aidentity export file first.");
      await action("import",{document:importDocument,confirmed:true},el);showView("profiles",{app:""});
    });
    $("#import-file").onchange=async event=>{
      importDocument=null;$("#import-preview").hidden=true;$("#form-error").hidden=true;
      try{
        const file=event.target.files[0];if(!file)return;
        if(file.size>4194304)throw new Error("The export file is larger than 4 MiB.");
        const data=JSON.parse(await file.text());if(data.aidentity_export!==1||!Array.isArray(data.launchers))throw new Error("Choose a format 1 aidentity export file.");
        importDocument=data;$("#import-preview").hidden=false;$("#import-preview").innerHTML=`<strong>${data.launchers.length} launchers in ${escape(file.name)}</strong><br>${data.launchers.map(item=>escape(item.name||item.profile||"Unnamed launcher")).join("<br>")}`;
      }catch(error){$("#form-error").textContent=error.message;$("#form-error").hidden=false;}
    };
  }
  async function exportSetup(el){
    const result=await action("export",{},el,{quiet:true});
    const blob=new Blob([result.stdout],{type:"application/json"});const url=URL.createObjectURL(blob);const link=document.createElement("a");
    link.href=url;link.download="aidentity-profiles.json";document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
    toast("Setup exported","Downloaded aidentity-profiles.json. Keep the recipe private.");
  }
  async function handleAction(name,el){
    const item=profile(el.dataset.name);
    if(name==="workspace")return showView("profiles",{app:""});
    if(name==="refresh")return refresh({notify:true,force:true});
    if(name==="add")return addDialog(el.dataset.app||appFilter);
    if(name==="select"){selected=el.dataset.name;mobileDetail=true;renderProfiles();positionTabs();animateMotion($(".detail-panel"),[{opacity:0,translate:"8px 0"},{opacity:1,translate:"0 0"}]);if(mobile.matches)window.scrollTo({top:0,behavior:"instant"});return;}
    if(name==="close-detail"||name==="back-profiles"){selected="";mobileDetail=false;renderProfiles();positionTabs();return;}
    if(name==="clear-search"){query="";renderView();$("#workspace-search")?.focus();return;}
    if(name==="all-apps"){appFilter="";renderView();return;}
    if(name==="reset-filters"){query="";appFilter="";statusFilter="all";renderView();return;}
    if(name==="settings"&&item)return settingsDialog(item);
    if(name==="rename"&&item)return renameDialog(item);
    if(name==="remove"&&item)return removeDialog(item);
    if(name==="open"||name==="quit"||name==="restore"||name==="rebuild")return action(name,{name:el.dataset.name},el);
    if(name==="restore-all")return confirmAction("Restore all launchers?","Reconnect every restorable profile.",`${state.restorable.length} recorded profiles will get new launchers using their existing account data.`,"Restore all","restore",{all:true});
    if(name==="rebuild-all")return confirmAction("Rebuild all launchers?","Refresh launcher bundles for every profile.",`${state.profiles.length} launchers will be rebuilt. Each profile keeps its account data.`,"Rebuild all","rebuild",{all:true});
    if(name==="prune")return confirmAction("Prune unclaimed profile data?","Move folders with no launcher to the Trash.","Restore any account you want to keep first. The CLI checks all launchers and running profiles before moving unclaimed data.","Move unclaimed data to Trash","prune",{confirmed:true},true);
    if(name==="doctor")return action("doctor",{},el);
    if(name==="doctor-fix")return confirmAction("Check and repair the workspace?","Run doctor with automatic fixes.","aidentity will inspect the setup and rebuild launchers it can repair.","Check & fix","doctor",{fix:true});
    if(name==="update-check")return action("update",{check:true},el);
    if(name==="update")return confirmAction("Install the latest aidentity?","Update this CLI installation.","The CLI checks its release source and installation before replacing the current executable.","Update aidentity","update",{check:false});
    if(name==="import")return importDialog();
    if(name==="export")return showDialog("Export launcher recipes?","Download your profile setup as JSON.",'<p class="muted">The file includes launch settings and may contain private environment or proxy values. Account sessions and profile data stay on this Mac.</p>',"Download private recipe",async(_,submit)=>{await exportSetup(submit);});
    if(name==="help"){const command=$("#help-command").value;const result=await action("help",command?{command}:{},el);guideText=result.stdout;renderGuide();return;}
    if(name==="completion"){const result=await action("completion",{shell:$("#completion-shell").value},el);guideText=result.stdout;renderGuide();return;}
    if(name==="copy-guide"){if(!guideText)return toast("No output yet","Read command help or generate completion first.");await navigator.clipboard.writeText(guideText);toast("Copied","Command output copied to your clipboard.");}
  }
  // Animated Sidebar adaptation: desktop rail, mobile modal navigation, Cmd+B.
  function closeNavigation(){
    const wasOpen=document.body.classList.contains("mobile-nav-open");
    document.body.classList.remove("mobile-nav-open");$("#mobile-nav").setAttribute("aria-expanded","false");$("#sidebar").removeAttribute("role");$("#sidebar").removeAttribute("aria-modal");
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
    document.body.classList.add("mobile-nav-open");$("#nav-scrim").hidden=false;$("#mobile-nav").setAttribute("aria-expanded","true");$("#sidebar").inert=false;$("#sidebar").setAttribute("role","dialog");$("#sidebar").setAttribute("aria-modal","true");$(".brand").focus();
    animateMotion($("#nav-scrim"),[{opacity:0},{opacity:1}],"control",{duration:180,easing:"ease-out"});
  }
  function showActivity(open){
    const panel=$("#activity-panel");if(panel.hidden===!open)return;
    panel.hidden=!open;$("#activity-toggle").setAttribute("aria-expanded",String(open));
    if(open)animateMotion(panel,[{opacity:0,translate:"0 10px"},{opacity:1,translate:"0 0"}]);
  }
  document.addEventListener("click",event=>{
    const close=event.target.closest("[data-close-dialog]");if(close){closeDialog();return;}
    const swatch=event.target.closest("[data-color]");if(swatch){$('[name="color"]',dialog).value=swatch.dataset.color;$$(".color-swatch",dialog).forEach(el=>el.setAttribute("aria-pressed",el===swatch));setupPreviewUpdate();return;}
    const nav=event.target.closest("[data-view]");if(nav){query="";showView(nav.dataset.view);return;}
    const app=event.target.closest("[data-app-filter]");if(app){query="";statusFilter="all";showView("profiles",{app:app.dataset.appFilter});return;}
    const filter=event.target.closest("[data-filter]");if(filter){statusFilter=filter.dataset.filter;renderProfiles();positionTabs();return;}
    const control=event.target.closest("[data-action]");if(control)handleAction(control.dataset.action,control).catch(error=>{if(!history[0]||history[0].ok)toast("Could not complete the action",error.message,true);});
  });
  document.addEventListener("input",event=>{
    if(event.target.id!=="workspace-search")return;query=event.target.value;
    const start=event.target.selectionStart;renderView();const input=$("#workspace-search");input?.focus();if(input&&start!==null)input.setSelectionRange(start,start);
  });
  document.addEventListener("change",event=>{if(event.target.id==="app-filter"){appFilter=event.target.value;renderView();}});
  document.addEventListener("keydown",event=>{
    if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==="b"){event.preventDefault();toggleNavigation();}
    if(event.key==="Escape"&&document.body.classList.contains("mobile-nav-open")){closeNavigation();$("#mobile-nav").focus();}
    if(event.key==="Tab"&&document.body.classList.contains("mobile-nav-open")){
      const items=$$("a[href],button:not(:disabled)",$("#sidebar"));const first=items[0],last=items.at(-1);
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
  $("#header-add").onclick=()=>addDialog();
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
  window.addEventListener("hashchange",()=>{const next=location.hash.slice(1);if([...navigation.map(item=>item[0]),"guide"].includes(next))showView(next);});
  const mobile=matchMedia("(max-width:767px)");
  mobile.addEventListener("change",()=>{closeNavigation();$("#sidebar").inert=mobile.matches;});
  $("#sidebar").inert=mobile.matches;
  hydrateIcons();renderNav();refresh();
  setInterval(()=>{if(!document.hidden&&!busy&&!dialog.open)refresh();},10000);
})();
