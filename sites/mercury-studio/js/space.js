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
    var baseData = g.getImageData(0, 0, TW, TH).data;

    /* the screen lives in the texture: lon -38..38 deg, lat -22..22 deg around the front */
    var em = document.createElement("canvas"); em.width = TW; em.height = TH;
    var e = em.getContext("2d"), emData = null;
    var SX0 = Math.round(TW * (0.5 - 38 / 360)), SX1 = Math.round(TW * (0.5 + 38 / 360));
    var SY0 = Math.round(TH * (0.5 - 22 / 180)), SY1 = Math.round(TH * (0.5 + 22 / 180));
    var sat = document.querySelector(".sat");
    var say = sat ? (sat.querySelector(".sat-say b") || {}).textContent : "";
    var sub = sat ? (sat.querySelector(".sat-say span") || {}).textContent : "";
    var urlT = (document.getElementById("sat-url") || {}).textContent || "";
    var pics = sat ? Array.prototype.slice.call(sat.querySelectorAll(".sat-screen img")) : [], pic = 0;
    function rr(c, x, y, w, h, rd) { c.beginPath(); c.moveTo(x + rd, y); c.arcTo(x + w, y, x + w, y + h, rd); c.arcTo(x + w, y + h, x, y + h, rd); c.arcTo(x, y + h, x, y, rd); c.arcTo(x, y, x + w, y, rd); c.closePath(); }
    function wrap(c, text, maxW) {
      var words = text.split(" "), lines = [], line = "";
      words.forEach(function (w) { var t = line ? line + " " + w : w; if (c.measureText(t).width > maxW && line) { lines.push(line); line = w; } else line = t; });
      if (line) lines.push(line); return lines;
    }
    function paintScreen() {
      var W = SX1 - SX0, H = SY1 - SY0, pad = 56;
      e.clearRect(0, 0, TW, TH);
      e.save();
      e.shadowColor = "rgba(61,107,255,.95)"; e.shadowBlur = 90;          // glow spilling onto the ground
      rr(e, SX0, SY0, W, H, 34); e.fillStyle = "#0a0d13"; e.fill();
      e.shadowBlur = 40; e.fill();
      e.restore();
      e.save(); rr(e, SX0, SY0, W, H, 34); e.clip();
      var img = pics[pic];
      if (img && img.complete && img.naturalWidth) {
        var ih = W * img.naturalHeight / img.naturalWidth;
        e.globalAlpha = .38; e.drawImage(img, SX0, SY0 + 64, W, Math.max(ih, H)); e.globalAlpha = 1;
      }
      e.fillStyle = "rgba(6,9,16,.6)"; e.fillRect(SX0, SY0, W, H);
      e.fillStyle = "#141a26"; e.fillRect(SX0, SY0, W, 64);
      ["#6a8dff", "#343c4d", "#343c4d"].forEach(function (c, i) { e.fillStyle = c; e.beginPath(); e.arc(SX0 + 40 + i * 30, SY0 + 32, 9, 0, 6.2832); e.fill(); });
      e.fillStyle = "#9ba3b1"; e.font = "500 26px Onest, sans-serif"; e.textBaseline = "middle"; e.fillText(urlT, SX0 + 140, SY0 + 33);
      e.fillStyle = "#ffffff"; e.font = "700 62px Onest, sans-serif"; e.textBaseline = "alphabetic";
      var lines = wrap(e, say, W - pad * 2), lh = 66, ty = SY0 + 64 + (H - 64) / 2 - ((lines.length - 1) * lh + 60) / 2 + 22;
      lines.forEach(function (l, i) { e.fillText(l, SX0 + pad, ty + i * lh); });
      e.fillStyle = "#b9c8ff"; e.font = "600 30px Onest, sans-serif"; e.fillText(sub, SX0 + pad, ty + (lines.length - 1) * lh + 58);
      e.restore();
      e.save(); rr(e, SX0, SY0, W, H, 34); e.lineWidth = 6; e.strokeStyle = "rgba(106,141,255,.8)"; e.stroke(); e.restore();
      emData = e.getImageData(0, 0, TW, TH).data;
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
        if (emData) {
          var a = emData[t + 3] / 255;
          if (a > 0) { var k2 = limbA[q]; rr_ = rr_ * (1 - a) + emData[t] * k2 * a; gg = gg * (1 - a) + emData[t + 1] * k2 * a; bb = bb * (1 - a) + emData[t + 2] * k2 * a; }
        }
        px[idx[q]] = 0xff000000 | (Math.min(255, bb) << 16) | (Math.min(255, gg) << 8) | Math.min(255, rr_);
      }
      ctx2.putImageData(out, 0, 0);
    }
    setup();
    var ready = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve();
    ready.then(function () { paintScreen(); render(swing(performance.now())); });
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
