/* Mercury Studio — Belgrade clock, scroll progress, works cursor preview */
(function () {
  var clock = document.getElementById("clock");
  function tick() {
    if (!clock) return;
    try { clock.textContent = new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Belgrade" }).format(new Date()); }
    catch (e) { clock.textContent = ""; }
  }
  tick(); setInterval(tick, 20000);

  var bar = document.querySelector(".progress"), ticking = false;
  function onScroll() {
    var max = document.documentElement.scrollHeight - innerHeight;
    if (bar) bar.style.transform = "scaleX(" + (max > 0 ? scrollY / max : 0) + ")";
    ticking = false;
  }
  addEventListener("scroll", function () { if (!ticking) { ticking = true; requestAnimationFrame(onScroll); } }, { passive: true });
  onScroll();

  // floating preview that follows the cursor over work rows (mouse devices only)
  var box = document.querySelector(".preview");
  if (box && matchMedia("(hover: hover) and (min-width: 961px)").matches) {
    var x = 0, y = 0, tx = 0, ty = 0, raf = null;
    function loop() {
      x += (tx - x) * 0.16; y += (ty - y) * 0.16;
      box.style.transform = "translate(" + (x + 28) + "px," + (y - 120) + "px) rotate(" + Math.max(-6, Math.min(6, (tx - x) * 0.08)) + "deg)";
      raf = box.classList.contains("on") || Math.abs(tx - x) > 0.5 ? requestAnimationFrame(loop) : null;
    }
    document.querySelectorAll(".row").forEach(function (row) {
      var media = row.querySelector(".r-media");
      row.addEventListener("mouseenter", function (e) {
        box.innerHTML = media.outerHTML; box.classList.add("on");
        tx = x = e.clientX; ty = y = e.clientY;
        if (!raf) raf = requestAnimationFrame(loop);
      });
      row.addEventListener("mousemove", function (e) { tx = e.clientX; ty = e.clientY; });
      row.addEventListener("mouseleave", function () { box.classList.remove("on"); });
    });
  }
})();
