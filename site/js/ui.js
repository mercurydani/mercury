/* Mercury Studio — small UI behaviours: Belgrade clock, scroll progress, header hide/show */
(function () {
  var clock = document.getElementById("clock");
  function tick() {
    if (!clock) return;
    try {
      clock.textContent = new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Belgrade" }).format(new Date());
    } catch (e) { clock.textContent = ""; }
  }
  tick(); setInterval(tick, 20000);

  var bar = document.querySelector(".progress");
  var header = document.querySelector(".header");
  var last = 0, ticking = false;
  function onScroll() {
    var y = window.scrollY, max = document.documentElement.scrollHeight - innerHeight;
    if (bar) bar.style.transform = "scaleX(" + (max > 0 ? y / max : 0) + ")";
    if (header && !header.classList.contains("open")) {
      header.classList.toggle("hide", y > last && y > 240);
    }
    last = y; ticking = false;
  }
  addEventListener("scroll", function () {
    if (!ticking) { ticking = true; requestAnimationFrame(onScroll); }
  }, { passive: true });
  onScroll();
})();
