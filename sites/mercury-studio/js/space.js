/* Mercury Studio — the sky, the planet, and where Mercury really is today. */
(function () {
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  function rng(seed) { return function () { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }

  /* ---------- stars ---------- */
  var sky = document.getElementById("sky");
  if (sky && sky.getContext) {
    var ctx = sky.getContext("2d"), stars = [], dpr = Math.min(window.devicePixelRatio || 1, 2), w = 0, h = 0, t0 = performance.now();
    function build() {
      w = sky.clientWidth; h = sky.clientHeight;
      sky.width = w * dpr; sky.height = h * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var r = rng(7), n = Math.round(w * h / 4200); stars = [];
      for (var i = 0; i < n; i++) {
        var z = r();
        stars.push({ x: r() * w, y: r() * h * 1.6, s: .3 + z * z * 1.4, a: .25 + r() * .6, z: z, tw: r() < .5 ? r() * 6.28 : -1, sp: .5 + r() * 1.6, blue: r() < .18 });
      }
    }
    function draw(now) {
      ctx.clearRect(0, 0, w, h);
      var sy = window.scrollY || 0, t = (now - t0) / 1000;
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i], y = (s.y - sy * (0.02 + s.z * 0.08)) % (h * 1.6);
        if (y < 0) y += h * 1.6;
        if (y > h) continue;
        var a = s.tw >= 0 && !reduce ? s.a * (.7 + .3 * Math.sin(t * s.sp + s.tw)) : s.a;
        ctx.globalAlpha = a; ctx.fillStyle = s.blue ? "#a9bcff" : "#ffffff";
        ctx.beginPath(); ctx.arc(s.x, y, s.s, 0, 6.2832); ctx.fill();
      }
      ctx.globalAlpha = 1;
    }
    var ticking = false;
    function loop(now) { draw(now); if (!reduce) requestAnimationFrame(loop); }
    build();
    if (reduce) {
      draw(performance.now());
      addEventListener("scroll", function () { if (!ticking) { ticking = true; requestAnimationFrame(function (n) { draw(n); ticking = false; }); } }, { passive: true });
    } else requestAnimationFrame(loop);
    addEventListener("resize", function () { build(); draw(performance.now()); });
  }

  /* ---------- the planet: a real sphere, with a screen set into its surface ---------- */
  var cv = document.getElementById("planet");
  if (cv && cv.getContext) {
    var TW = 3072, TH = 1536;                       // equirectangular texture
    var base = document.createElement("canvas"); base.width = TW; base.height = TH;
    var g = base.getContext("2d"), r = rng(88);
    g.fillStyle = "#6d717a"; g.fillRect(0, 0, TW, TH);
    function blot(x, y, rad, col, alpha) {
      for (var dx = -TW; dx <= TW; dx += TW) { g.globalAlpha = alpha; g.fillStyle = col; g.beginPath(); g.arc(x + dx, y, rad, 0, 6.2832); g.fill(); }
      g.globalAlpha = 1;
    }
    for (var i = 0; i < 90; i++) blot(r() * TW, r() * TH, 90 + r() * 300, r() < .5 ? "#575b63" : "#80848c", .16 + r() * .18);
    for (var j = 0; j < 3000; j++) blot(r() * TW, r() * TH, 1 + r() * 5, r() < .5 ? "#4b4f57" : "#9a9ea6", .3);
    for (var k = 0; k < 520; k++) {
      var x = r() * TW, y = 80 + r() * (TH - 160), rad = 4 + Math.pow(r(), 3) * 90;
      blot(x + rad * .1, y + rad * .1, rad, "#4c5058", .36);
      blot(x - rad * .06, y - rad * .06, rad * .88, "#777b83", .32);
      blot(x - rad * .3, y - rad * .3, rad * .45, "#9ea2aa", .16);
    }
    /* where the billboard stands: a dark trench dug into the ground and blue light spilling round it */
    var BLAT = -0.17, BU = TW / 2, BV = Math.round(TH * (0.5 - BLAT / Math.PI));
    g.save(); g.filter = "blur(26px)"; g.fillStyle = "rgba(10,12,18,.85)";
    g.beginPath(); g.ellipse(BU, BV, TW * 37 / 360, TH * 23 / 180, 0, 0, 6.2832); g.fill(); g.restore();
    g.save(); g.filter = "blur(60px)"; g.globalCompositeOperation = "lighter"; g.fillStyle = "rgba(61,107,255,.22)";
    g.beginPath(); g.ellipse(BU, BV, TW * 44 / 360, TH * 30 / 180, 0, 0, 6.2832); g.fill(); g.restore();
    var baseData = g.getImageData(0, 0, TW, TH).data;

    /* the billboard's face: a flat screen, painted once per slide */
    var SW = 1200, SH = 740, scr = document.createElement("canvas"); scr.width = SW; scr.height = SH;
    var e = scr.getContext("2d");
    var sat = document.querySelector(".sat");
    var say = sat ? (sat.querySelector(".sat-say b") || {}).textContent : "";
    var sub = sat ? (sat.querySelector(".sat-say span") || {}).textContent : "";
    var urlT = (document.getElementById("sat-url") || {}).textContent || "";
    var pics = sat ? Array.prototype.slice.call(sat.querySelectorAll(".sat-screen img")) : [], pic = 0;
    function wrap(c, text, maxW) {
      var words = text.split(" "), lines = [], line = "";
      words.forEach(function (w) { var t = line ? line + " " + w : w; if (c.measureText(t).width > maxW && line) { lines.push(line); line = w; } else line = t; });
      if (line) lines.push(line); return lines;
    }
    function paintScreen() {
      var bar = 92, pad = 96;
      e.fillStyle = "#0a0d13"; e.fillRect(0, 0, SW, SH);
      var img = pics[pic];
      if (img && img.complete && img.naturalWidth) {
        var ih = SW * img.naturalHeight / img.naturalWidth;
        e.globalAlpha = .4; e.drawImage(img, 0, bar, SW, Math.max(ih, SH - bar)); e.globalAlpha = 1;
      }
      e.fillStyle = "rgba(6,9,16,.58)"; e.fillRect(0, bar, SW, SH - bar);
      e.fillStyle = "#141a26"; e.fillRect(0, 0, SW, bar);
      ["#6a8dff", "#343c4d", "#343c4d"].forEach(function (c, i) { e.fillStyle = c; e.beginPath(); e.arc(56 + i * 42, bar / 2, 13, 0, 6.2832); e.fill(); });
      e.fillStyle = "#9ba3b1"; e.font = "500 40px Onest, sans-serif"; e.textBaseline = "middle"; e.fillText(urlT, 200, bar / 2 + 2);
      e.textBaseline = "alphabetic"; e.fillStyle = "#fff"; e.font = "700 112px Onest, sans-serif";
      var lines = wrap(e, say, SW - pad * 2), lh = 118, block = (lines.length - 1) * lh + 112 + 90;
      var ty = bar + (SH - bar - block) / 2 + 96;
      lines.forEach(function (l, i) { e.fillText(l, pad, ty + i * lh); });
      e.fillStyle = "#b9c8ff"; e.font = "600 54px Onest, sans-serif"; e.fillText(sub, pad, ty + (lines.length - 1) * lh + 96);
      var sh = e.createLinearGradient(0, 0, SW * .7, SH); sh.addColorStop(0, "rgba(255,255,255,.08)"); sh.addColorStop(.45, "rgba(255,255,255,0)"); // glass glare
      e.fillStyle = sh; e.fillRect(0, 0, SW, SH);
    }

    /* billboard geometry in sphere units: a flat panel standing out of the surface, with a frame and depth */
    function bill(off) {
      var ph = -off, th = BLAT, cp = Math.cos(ph), sp = Math.sin(ph), ct = Math.cos(th), st = Math.sin(th);
      var n = [ct * sp, -st, ct * cp], east = [cp, 0, -sp], down = [st * sp, ct, st * cp];
      function pt(dn, ex, dy) { return [n[0] * dn + east[0] * ex + down[0] * dy, n[1] * dn + east[1] * ex + down[1] * dy, n[2] * dn + east[2] * ex + down[2] * dy]; }
      return { n: n, east: east, down: down, pt: pt };
    }
    /* per-pixel sphere: orthographic view, lit from the upper left */
    var N = 0, px, out, ctx2 = cv.getContext("2d"), idx, lonA, rowA, shadeA, limbA;
    function setup() {
      var css = cv.clientWidth || 600; N = Math.min(720, Math.round(css * Math.min(devicePixelRatio || 1, 1.5)));
      cv.width = N; cv.height = N; out = ctx2.createImageData(N, N); px = new Uint32Array(out.data.buffer);
      var cnt = 0, R = N / 2, list = [], lon = [], row = [], sh = [], lb = [];
      var Lx = -0.55, Ly = -0.5, Lz = 0.67;
      for (var yy = 0; yy < N; yy++) for (var xx = 0; xx < N; xx++) {
        var nx = (xx + .5 - R) / R, ny = (yy + .5 - R) / R, d = nx * nx + ny * ny;
        if (d >= 1) continue;
        var nz = Math.sqrt(1 - d), lat = Math.asin(-ny), lo = Math.atan2(nx, nz);
        list.push(yy * N + xx); lon.push(lo); row.push(Math.min(TH - 1, Math.max(0, Math.round((0.5 - lat / Math.PI) * TH))));
        var dif = Math.max(0, nx * Lx + ny * Ly + nz * Lz);
        sh.push(Math.min(1.25, 0.05 + 1.15 * Math.pow(dif, 1.1))); lb.push(0.45 + 0.55 * Math.pow(nz, 0.5));
      }
      idx = new Int32Array(list); lonA = new Float32Array(lon); rowA = new Int32Array(row); shadeA = new Float32Array(sh); limbA = new Float32Array(lb);
    }
    function render(off) {
      var n = idx.length, twoPi = 6.2832;
      for (var q = 0; q < n; q++) {
        var u = (lonA[q] + off) / twoPi + 0.5; u -= Math.floor(u);
        var t = (rowA[q] * TW + ((u * TW) | 0)) * 4, s = shadeA[q];
        var rr_ = baseData[t] * s, gg = baseData[t + 1] * s, bb = baseData[t + 2] * s;
        px[idx[q]] = 0xff000000 | (Math.min(255, bb) << 16) | (Math.min(255, gg) << 8) | Math.min(255, rr_);
      }
      ctx2.putImageData(out, 0, 0);
      drawBill(off);
    }
    function drawBill(off) {
      var B = bill(off), R = N / 2, F = 0.94, D = 0.16, A = 0.5, H = 0.31, FR = 0.035;
      function P(v) { return [R + v[0] * R, R + v[1] * R]; }
      var c = ctx2;
      function quad(p, fill) { c.beginPath(); c.moveTo(p[0][0], p[0][1]); for (var i = 1; i < p.length; i++) c.lineTo(p[i][0], p[i][1]); c.closePath(); c.fillStyle = fill; c.fill(); }
      var fA = A + FR, fH = H + FR;
      var f = [B.pt(F, -fA, -fH), B.pt(F, fA, -fH), B.pt(F, fA, fH), B.pt(F, -fA, fH)];
      var k = [B.pt(F - D, -fA, -fH), B.pt(F - D, fA, -fH), B.pt(F - D, fA, fH), B.pt(F - D, -fA, fH)];
      var Lx = -0.55, Ly = -0.5, Lz = 0.67;
      function lit(nv, base) { var d = Math.max(0, nv[0] * Lx + nv[1] * Ly + nv[2] * Lz), v = Math.round(base * (0.35 + 0.9 * d)); return "rgb(" + v + "," + (v + 3) + "," + (v + 10) + ")"; }
      var sides = [ [[0, 1], [-B.down[0], -B.down[1], -B.down[2]]], [[1, 2], B.east], [[2, 3], B.down], [[3, 0], [-B.east[0], -B.east[1], -B.east[2]]] ];
      c.save();
      sides.forEach(function (sd) {                         // the thickness of the panel
        var nv = sd[1]; if (nv[2] <= 0.002) return;
        var i = sd[0][0], j = sd[0][1];
        quad([P(f[i]), P(f[j]), P(k[j]), P(k[i])], lit(nv, 92));
      });
      c.shadowColor = "rgba(61,107,255,.9)"; c.shadowBlur = R * .16;   // the screen's light
      quad(f.map(P), "#1c212c");
      c.shadowBlur = 0;
      quad(f.map(P), lit(B.n, 70));                         // the frame face
      var s0 = P(B.pt(F + .001, -A, -H)), s1 = P(B.pt(F + .001, A, -H)), s3 = P(B.pt(F + .001, -A, H));
      c.setTransform((s1[0] - s0[0]) / SW, (s1[1] - s0[1]) / SW, (s3[0] - s0[0]) / SH, (s3[1] - s0[1]) / SH, s0[0], s0[1]);
      c.drawImage(scr, 0, 0);
      c.setTransform(1, 0, 0, 1, 0, 0);
      c.restore();
    }
    setup();
    var ready = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve();
    paintScreen(); ready.then(function () { paintScreen(); render(swing(performance.now())); });
    pics.forEach(function (im) { im.loading = "eager"; if (!im.complete) im.addEventListener("load", function () { if (im === pics[pic]) paintScreen(); }); });
    function swing(now) { return reduce ? 0 : 0.42 * Math.sin(now / 1000 * 0.22); }  // the planet turns side to side, about 24 degrees
    render(0);
    if (!reduce) {
      var last = 0, visible = true;
      if ("IntersectionObserver" in window) new IntersectionObserver(function (es) { visible = es[0].isIntersecting; }).observe(cv);
      (function frame(now) { if (visible && now - last > 33) { last = now; render(swing(now)); } requestAnimationFrame(frame); })(0);
      if (pics.length > 1) setInterval(function () { pic = (pic + 1) % pics.length; paintScreen(); }, 4200);
    }
    addEventListener("resize", function () { var c = cv.clientWidth; if (Math.abs(c * Math.min(devicePixelRatio || 1, 1.5) - N) > 40) { setup(); render(swing(performance.now())); } });
  }

  /* ---------- the screen in orbit cycles through our work ---------- */
  /* ---------- where Mercury is today (mean heliocentric longitude, J2000) ---------- */
  var line = document.getElementById("orbit-now");
  var days = (Date.now() - Date.UTC(2000, 0, 1, 12)) / 864e5;
  var L = ((252.25084 + 4.09233445 * days) % 360 + 360) % 360;
  if (line) {
    var lang = (document.documentElement.lang || "sr").slice(0, 2), deg = Math.round(L) + "°";
    var T = {
      sr: "Merkur obiđe Sunce za 88 dana, brže od svih planeta. Sada je na <b>" + deg + "</b> svoje orbite. Prvu verziju sajta pokazujemo za nekoliko dana.",
      en: "Mercury circles the Sun in 88 days, faster than any other planet. Right now it is at <b>" + deg + "</b> of its orbit. We show the first version of your site in a few days.",
      ru: "Меркурий облетает Солнце за 88 дней — быстрее всех планет. Сейчас он на <b>" + deg + "</b> своей орбиты. Первую версию сайта мы показываем за несколько дней."
    };
    line.innerHTML = T[lang] || T.sr;
  }
})();
