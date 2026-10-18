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
        stars.push({ x: r() * w, y: r() * h * 1.6, s: .3 + z * z * 1.4, a: .25 + r() * .6, z: z, tw: r() < .12 ? r() * 6.28 : -1, blue: r() < .18 });
      }
    }
    function draw(now) {
      ctx.clearRect(0, 0, w, h);
      var sy = window.scrollY || 0, t = (now - t0) / 1000;
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i], y = (s.y - sy * (0.02 + s.z * 0.08)) % (h * 1.6);
        if (y < 0) y += h * 1.6;
        if (y > h) continue;
        var a = s.tw >= 0 && !reduce ? s.a * (.55 + .45 * Math.sin(t * 1.3 + s.tw)) : s.a;
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

  /* ---------- the planet's surface, drawn once ---------- */
  var planet = document.getElementById("planet");
  if (planet) {
    var c = document.createElement("canvas"), W = 1024, H = 512; c.width = W; c.height = H;
    var g = c.getContext("2d"), r = rng(88);
    g.fillStyle = "#6d717a"; g.fillRect(0, 0, W, H);
    function blot(x, y, rad, col, alpha) {
      for (var dx = -W; dx <= W; dx += W) { // wrap horizontally so the roll is seamless
        g.globalAlpha = alpha; g.fillStyle = col; g.beginPath(); g.arc(x + dx, y, rad, 0, 6.2832); g.fill();
      }
      g.globalAlpha = 1;
    }
    for (var i = 0; i < 70; i++) blot(r() * W, r() * H, 30 + r() * 110, r() < .5 ? "#575b63" : "#80848c", .18 + r() * .2);
    for (var j = 0; j < 900; j++) blot(r() * W, r() * H, .6 + r() * 2.2, r() < .5 ? "#4b4f57" : "#9a9ea6", .35);
    for (var k = 0; k < 260; k++) {
      var x = r() * W, y = 30 + r() * (H - 60), rad = 1.5 + Math.pow(r(), 3) * 30;
      blot(x + rad * .08, y + rad * .08, rad, "#50545c", .32); // shadowed floor
      blot(x - rad * .06, y - rad * .06, rad * .9, "#767a82", .3);
      blot(x - rad * .3, y - rad * .3, rad * .5, "#9a9ea6", .14); // lit rim
      if (rad > 20) for (var q = 0; q < 10; q++) { var an = r() * 6.28, d = rad * (1.2 + r() * .9); blot(x + Math.cos(an) * d, y + Math.sin(an) * d, 1 + r() * 2.4, "#9ea2aa", .3); }
    }
    try { planet.style.backgroundImage = "url(" + c.toDataURL("image/jpeg", .86) + ")"; } catch (e) {}
  }

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
