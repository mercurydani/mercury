/* =====================================================================
   RENDERING · you shouldn't need to touch anything below
   ===================================================================== */
(function () {
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var lang = (function () { try { return localStorage.getItem("jin-lang") || CONFIG.defaultLang; } catch (e) { return CONFIG.defaultLang; } })();
  function T(k) { return (TEXT[lang] && TEXT[lang][k] !== undefined) ? TEXT[lang][k] : TEXT.en[k]; }
  function $(id) { return document.getElementById(id); }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var STAR = '<svg aria-hidden="true"><use href="#star"/></svg>';

  /* placeholder art: two warm colours picked from the palette by index */
  var PH = [["#e8245a", "#ff8a2a"], ["#ff3d6e", "#6b3fa0"], ["#ff8a2a", "#e8245a"], ["#b0306a", "#ffc15e"], ["#6b3fa0", "#ff3d6e"]];
  function placeholder(i, title, ratio) {
    var c = PH[i % PH.length];
    return '<div class="ph" style="--a:' + c[0] + '99;--b:' + c[1] + '88;aspect-ratio:' + ratio + '">' + STAR +
      '<span>' + esc(title || "") + '</span><small>' + esc(T("ph_art")) + '</small></div>';
  }
  /* any <img> that fails to load becomes a placeholder */
  function guard(root) {
    root.querySelectorAll("img").forEach(function (img) {
      function fail() {
        if (img.dataset.fallback === "banner") { var f = document.createElement("div"); f.className = "fallback"; img.replaceWith(f); return; }
        if (img.dataset.fallback === "avatar") {
          var d = document.createElement("div"); d.className = "fallback"; d.innerHTML = STAR; d.setAttribute("role", "img"); d.setAttribute("aria-label", img.alt || "JIN2DRAW");
          img.replaceWith(d); return;
        }
        if (!img.dataset.ph) return img.remove();
        var w = document.createElement("div"); w.innerHTML = placeholder(+img.dataset.i || 0, img.dataset.ph, img.dataset.ratio || "1"); img.replaceWith(w.firstChild);
      }
      if (img.complete && img.naturalWidth === 0 && img.getAttribute("src")) fail(); else img.addEventListener("error", fail, { once: true });
    });
  }

  /* ---------- static text ---------- */
  function texts() {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-t]").forEach(function (el) { var v = T(el.dataset.t); if (typeof v === "string") el.innerHTML = v; });
    var open = CONFIG.commissionsOpen, b = $("badge"), tl = document.querySelector(".tagline");
    if (b) {
    b.className = "badge " + (open ? "open" : "closed");
    b.querySelector("span").textContent = T(open ? "badge_open" : "badge_closed");
    }
    if (tl) tl.innerHTML = T(open ? "tagline" : "tagline_closed");
    $("lang").textContent = lang === "en" ? "RU" : "EN";
    $("year").textContent = new Date().getFullYear();
  }

  /* ---------- portfolio ---------- */
  function gallery() {
    if (!$("gallery")) return;
    $("gallery").innerHTML = WORKS.map(function (w, i) {
      var ratio = w.w + "/" + w.h;
      return '<li class="work reveal"><button type="button" data-i="' + i + '" aria-label="' + esc(w.title) + '">' +
        '<img src="' + esc(w.src) + '" alt="' + esc(w.title) + '" loading="lazy" style="aspect-ratio:' + ratio + '" data-ph="' + esc(w.title) + '" data-ratio="' + ratio + '" data-i="' + i + '">' +
        '<span class="cap">' + esc(w.title) + '<small>' + esc(w.tag) + '</small></span></button></li>';
    }).join("");
    guard($("gallery"));
  }

  /* ---------- lightbox ---------- */
  var lb = $("lb"), cur = 0;
  function show(i) {
    cur = (i + WORKS.length) % WORKS.length;
    var w = WORKS[cur], ratio = w.w + "/" + w.h;
    $("lb-stage").innerHTML = '<img src="' + esc(w.src) + '" alt="' + esc(w.title) + '" data-ph="' + esc(w.title) + '" data-ratio="' + ratio + '" data-i="' + cur + '">';
    var ph = $("lb-stage").querySelector("img"); guard($("lb-stage"));
    if (!ph) { var p = $("lb-stage").querySelector(".ph"); if (p) p.style.setProperty("--ratio", ratio); }
    $("lb-cap").innerHTML = esc(w.title) + "<small>" + esc(w.tag) + "</small>";
    $("lb-count").textContent = (cur + 1) + " / " + WORKS.length;
  }
  if (lb && $("gallery")) {
  $("gallery").addEventListener("click", function (e) { var b = e.target.closest("button[data-i]"); if (!b) return; show(+b.dataset.i); lb.showModal(); });
  $("lb-close").onclick = function () { lb.close(); };
  $("lb-prev").onclick = function () { show(cur - 1); };
  $("lb-next").onclick = function () { show(cur + 1); };
  lb.addEventListener("keydown", function (e) { if (e.key === "ArrowLeft") show(cur - 1); if (e.key === "ArrowRight") show(cur + 1); });
  lb.addEventListener("click", function (e) { if (e.target === lb || e.target.classList.contains("lb-in")) lb.close(); });
  var sx = null;
  lb.addEventListener("touchstart", function (e) { sx = e.touches[0].clientX; }, { passive: true });
  lb.addEventListener("touchend", function (e) { if (sx === null) return; var dx = e.changedTouches[0].clientX - sx; if (Math.abs(dx) > 50) show(cur + (dx < 0 ? 1 : -1)); sx = null; });
  }

  /* ---------- queue ---------- */
  var STAGES = ["waiting", "sketch", "coloring", "done"], SC = { waiting: "var(--s-wait)", sketch: "var(--s-sketch)", coloring: "var(--s-color)", done: "var(--s-done)" };
  function queue() {
    if (!$("orders")) return;
    var taken = QUEUE.filter(function (o) { return o.status !== "done"; }).length, free = Math.max(0, CONFIG.slotsTotal - taken);
    $("slots-num").innerHTML = free + "<small>/ " + CONFIG.slotsTotal + " " + esc(T("slots_free")) + "</small>";
    var p = ""; for (var i = 0; i < CONFIG.slotsTotal; i++) p += '<i class="' + (i < taken ? "taken" : "") + '"></i>'; $("pips").innerHTML = p;
    $("legend").innerHTML = STAGES.map(function (s) { return '<span><i style="background:' + SC[s] + '"></i>' + esc(T("st_" + s)) + "</span>"; }).join("");
    $("orders").innerHTML = QUEUE.length ? QUEUE.map(function (o, i) {
      var k = STAGES.indexOf(o.status), track = "";
      for (var j = 0; j < 4; j++) track += '<i class="' + (j <= k ? "on" : "") + '"></i>';
      return '<li class="glass order reveal" style="--c:' + SC[o.status] + '"><span class="no">' + (i + 1) + '</span><b>' + esc(o.client) + '</b><span class="what">' + esc(o.type) +
        '</span><span class="st"><i></i>' + esc(T("st_" + o.status)) + '</span><span class="track" aria-hidden="true">' + track + "</span></li>";
    }).join("") : '<li class="glass q-empty">' + esc(T("q_empty")) + "</li>";
  }

  /* ---------- prices ---------- */
  function prices() {
    if (!$("price-list")) return;
    var CHECK = '<svg aria-hidden="true"><use href="#star"/></svg>';
    $("price-list").innerHTML = PRICES.map(function (p, i) {
      var name = T("p_" + p.id);
      return '<li class="glass price reveal">' + (p.popular ? '<span class="tag">' + esc(T("popular")) + "</span>" : "") +
        '<div class="ex">' + (p.img ? '<img src="' + esc(p.img) + '" alt="' + esc(name + ", " + T("example")) + '" loading="lazy" data-ph="' + esc(name) + '" data-ratio="4/3" data-i="' + (i + 2) + '">' : placeholder(i + 2, name, "4/3")) + "</div>" +
        '<div class="price-b"><h3>' + esc(name) + '</h3><p class="cost"><small>' + esc(T("from")) + "</small>" + CONFIG.currency + p.price + "</p><p>" + esc(T("p_" + p.id + "_d")) + "</p><ul>" +
        T("p_" + p.id + "_l").map(function (x) { return "<li>" + CHECK + esc(x) + "</li>"; }).join("") + "</ul></div></li>";
    }).join("");
    $("extras").innerHTML = EXTRAS.map(function (x) {
      var v = /^[+\d]/.test(x.price) && x.price.indexOf("%") < 0 ? x.price.replace(/^\+/, "+" + CONFIG.currency) : x.price;
      return "<li>" + esc(T("ex_" + x.id)) + "<b>" + esc(v) + "</b></li>";
    }).join("");
    guard($("price-list"));
  }

  /* ---------- tos ---------- */
  function tos() {
    if (!$("tos-list")) return;
    var CHEV = '<svg class="chev" aria-hidden="true"><use href="#i-down"/></svg>';
    $("tos-list").innerHTML = T("tos").map(function (r, i) {
      var body = r.cols
        ? '<div class="cols"><div class="yes"><h4>' + esc(r.yes_h) + "</h4><ul>" + r.yes.map(function (x) { return "<li>" + esc(x) + "</li>"; }).join("") + '</ul></div><div><h4>' + esc(r.no_h) + "</h4><ul>" + r.no.map(function (x) { return "<li>" + esc(x) + "</li>"; }).join("") + "</ul></div></div>"
        : "<ul>" + r.a.map(function (x) { return "<li>" + esc(x) + "</li>"; }).join("") + "</ul>";
      return '<details class="glass reveal"' + (i === 0 ? " open" : "") + "><summary>" + STAR + esc(r.q) + CHEV + '</summary><div class="body">' + body + "</div></details>";
    }).join("");
  }

  /* ---------- links ---------- */
  function links() {
    if (!$("link-list")) return;
    $("link-list").innerHTML = LINKS.map(function (l) {
      var href = l.id === "email" && l.url === "#" ? "#" : l.url;
      return '<li class="reveal"><a class="glass link" href="' + esc(href) + '" style="--brand:' + l.brand + '"' + (href.indexOf("http") === 0 ? ' target="_blank" rel="noopener"' : "") +
        '><span class="ic"><svg aria-hidden="true"><use href="#' + l.icon + '"/></svg></span><span><b>' + esc(l.name) + "</b><small>" + esc(l.handle) +
        '</small></span><svg class="go" aria-hidden="true"><use href="#i-arrow"/></svg></a></li>';
    }).join("");
  }

  /* ---------- portal tiles (home page of the multi-page version) ---------- */
  function portal() {
    var box = $("portal"); if (!box) return;
    var taken = QUEUE.filter(function (o) { return o.status !== "done"; }).length, pips = "";
    for (var i = 0; i < CONFIG.slotsTotal; i++) pips += '<i class="' + (i < taken ? "taken" : "") + '"></i>';
    var min = Math.min.apply(null, PRICES.map(function (p) { return p.price; }));
    var thumbs = WORKS.slice(0, 3).map(function (w, i) { return '<span class="th"><img src="' + esc(w.src) + '" alt="" loading="lazy" data-ph=" " data-ratio="1" data-i="' + i + '"></span>'; }).join("");
    var icons = LINKS.slice(0, 5).map(function (l) { return '<i style="--brand:' + l.brand + '"><svg aria-hidden="true"><use href="#' + l.icon + '"/></svg></i>'; }).join("");
    var T_ = [
      { href: "portfolio.html", k: "portfolio", extra: '<span class="thumbs">' + thumbs + "</span>", big: true },
      { href: "queue.html", k: "queue", extra: '<span class="pips">' + pips + '</span><span class="note">' + Math.max(0, CONFIG.slotsTotal - taken) + " / " + CONFIG.slotsTotal + " " + esc(T("slots_free")) + "</span>" },
      { href: "prices.html", k: "prices", extra: '<span class="cost"><small>' + esc(T("from")) + "</small>" + CONFIG.currency + min + "</span>" },
      { href: "tos.html", k: "tos", extra: '<span class="note">' + T("tos").length + " " + esc(T("pt_rules")) + "</span>" },
      { href: "links.html", k: "links", extra: '<span class="icons">' + icons + "</span>" }
    ];
    box.innerHTML = T_.map(function (t) {
      return '<li class="reveal' + (t.big ? " big" : "") + '"><a class="glass tile" href="' + t.href + '"><span class="tile-t"><b>' + esc(T("nav_" + t.k)) + "</b><small>" + esc(T("pt_" + t.k)) +
        "</small></span>" + t.extra + '<svg class="go" aria-hidden="true"><use href="#i-arrow"/></svg></a></li>';
    }).join("");
    guard(box);
  }

  function renderAll() { texts(); gallery(); queue(); prices(); tos(); links(); portal(); reveal(); }
  $("lang").addEventListener("click", function () { lang = lang === "en" ? "ru" : "en"; try { localStorage.setItem("jin-lang", lang); } catch (e) {} renderAll(); });

  /* ---------- entrances ---------- */
  var io = "IntersectionObserver" in window && !reduce ? new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }); }, { rootMargin: "0px 0px -6% 0px" }) : null;
  function reveal() { document.querySelectorAll(".reveal:not(.in)").forEach(function (el) { io ? io.observe(el) : el.classList.add("in"); }); }

  /* ---------- sticky nav: appears after the hero, highlights the current section ---------- */
  var nav = $("nav"), links_ = [].slice.call(nav.querySelectorAll('a[href^="#"]:not(.home)'));
  function onScroll() { nav.classList.toggle("show", nav.classList.contains("static") || scrollY > innerHeight * .55); }
  addEventListener("scroll", onScroll, { passive: true }); onScroll();
  if ("IntersectionObserver" in window) {
    var secIO = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) links_.forEach(function (a) { a.setAttribute("aria-current", a.getAttribute("href") === "#" + e.target.id); }); });
    }, { rootMargin: "-45% 0px -50% 0px" });
    document.querySelectorAll("main section[id]").forEach(function (s) { secIO.observe(s); });
  }

  guard(document.querySelector(".hero")); guard(document.querySelector(".foot"));
  renderAll();
})();

/* =====================================================================
   BACKGROUND · space behind the banner: nebulae painted once,
   stars twinkle, parallax on scroll, a shooting star now and then.
   ===================================================================== */
(function () {
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var sc = document.getElementById("space");
  if (!sc.getContext) return;
  var sx = sc.getContext("2d"), VW = 0, VH = 0, dpr = Math.min(devicePixelRatio || 1, 2);
  var seed = 7; function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }

  /* ---------- space ---------- */
  var neb = null, stars = [], shoot = null, nextShoot = 0;
  function buildSpace() {
    VW = innerWidth; VH = innerHeight;
    sc.width = VW * dpr; sc.height = VH * dpr; sx.setTransform(dpr, 0, 0, dpr, 0, 0);
    neb = document.createElement("canvas"); neb.width = sc.width; neb.height = sc.height;
    var g = neb.getContext("2d"); g.scale(dpr, dpr);
    g.fillStyle = "#0b0710"; g.fillRect(0, 0, VW, VH);
    function blob(x, y, r, col) { var gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, col); gr.addColorStop(1, "rgba(11,7,16,0)"); g.fillStyle = gr; g.fillRect(0, 0, VW, VH); }
    var M = Math.max(VW, VH);
    blob(VW * .85, VH * .2, M * .55, "rgba(120,40,140,.30)");
    blob(VW * .1, VH * .75, M * .5, "rgba(232,36,90,.18)");
    blob(VW * .7, VH * .9, M * .45, "rgba(255,138,42,.12)");
    blob(VW * .3, VH * .25, M * .35, "rgba(90,50,160,.22)");
    seed = 11; stars = [];
    var n = Math.round(VW * VH / 2600);
    for (var i = 0; i < n; i++) {
      var z = rnd(), layer = z < .6 ? 0 : z < .9 ? 1 : 2;                // three depths
      stars.push({ x: rnd() * VW, y: rnd() * VH * 2, r: [.55, .95, 1.5][layer], d: [.03, .07, .13][layer], a: .35 + rnd() * .55,
        sp: .6 + rnd() * 1.8, ph: rnd() * 6.28, warm: rnd() < .14 });
    }
  }
  function sparkle(x, y, r, a) { // the four-pointed star from the mascot, for the brightest stars
    sx.globalAlpha = a; sx.fillStyle = "#ffe2a8"; sx.beginPath();
    sx.moveTo(x, y - r * 3.2); sx.quadraticCurveTo(x, y, x + r * 3.2, y); sx.quadraticCurveTo(x, y, x, y + r * 3.2); sx.quadraticCurveTo(x, y, x - r * 3.2, y); sx.quadraticCurveTo(x, y, x, y - r * 3.2); sx.fill();
  }
  function drawSpace(t) {
    sx.globalAlpha = 1; sx.drawImage(neb, 0, 0, VW, VH);
    var sy = scrollY, span = VH * 2;
    for (var i = 0; i < stars.length; i++) {
      var s = stars[i], y = (s.y - sy * s.d) % span; if (y < 0) y += span; if (y > VH) continue;
      var a = reduce ? s.a : s.a * (.55 + .45 * Math.sin(t * .001 * s.sp + s.ph));
      if (s.r > 1.2 && a > .7) { sparkle(s.x, y, s.r * .9, a); continue; }
      sx.globalAlpha = a; sx.fillStyle = s.warm ? "#ffc9a0" : "#f2e8ff"; sx.beginPath(); sx.arc(s.x, y, s.r, 0, 6.2832); sx.fill();
    }
    if (!reduce) {                                                        // shooting star every 7–14 s
      if (!shoot && t > nextShoot) { shoot = { x: VW * (.2 + Math.random() * .7), y: VH * Math.random() * .4, t0: t }; }
      if (shoot) {
        var k = (t - shoot.t0) / 900; if (k > 1) { shoot = null; nextShoot = t + 7000 + Math.random() * 7000; }
        else { var x = shoot.x - k * 260, y2 = shoot.y + k * 140, gr = sx.createLinearGradient(x, y2, x + 90, y2 - 48);
          gr.addColorStop(0, "rgba(255,226,168," + (1 - k) + ")"); gr.addColorStop(1, "rgba(255,138,42,0)");
          sx.globalAlpha = 1; sx.strokeStyle = gr; sx.lineWidth = 1.6; sx.beginPath(); sx.moveTo(x, y2); sx.lineTo(x + 90, y2 - 48); sx.stroke(); }
      }
    }
    sx.globalAlpha = 1;
  }

  var last = 0;
  function frame(t) { if (t - last > 33) { last = t; drawSpace(t); } requestAnimationFrame(frame); }   // ~30 fps is plenty
  buildSpace(); drawSpace(0); nextShoot = 3000;
  if (reduce) addEventListener("scroll", function () { drawSpace(0); }, { passive: true });
  else requestAnimationFrame(frame);
  var rt; addEventListener("resize", function () { clearTimeout(rt); rt = setTimeout(function () { if (Math.abs(innerWidth - VW) > 40 || Math.abs(innerHeight - VH) > 160) { buildSpace(); drawSpace(0); } }, 200); });
})();
