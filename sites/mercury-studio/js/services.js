/* Mercury Studio — services showcase: tabs switch the picture, the text and the price. */
(function () {
  var tabs = Array.prototype.slice.call(document.querySelectorAll(".show-tabs [data-show]"));
  if (!tabs.length) return;
  var TG = "https://t.me/mercury_dani_rs", WA = "https://wa.me/381653454290";
  var $ = function (id) { return document.getElementById(id); };
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var current = tabs[0].dataset.show;

  function lang() { var l = document.documentElement.lang; return l === "en" ? "en" : l === "ru" ? "ru" : "sr"; }
  function dict() { return I18N[lang()] || I18N.sr; }
  function money(n, monthly) {
    var d = dict(), v = lang() === "en" ? "€" + n : n + " €";
    return d.r_from + " " + v + (monthly ? " " + d.r_mo : "");
  }

  function paintPrices() {
    document.querySelectorAll("[data-prices]").forEach(function (box) {
      var parts = Array.prototype.map.call(box.querySelectorAll("[data-price]"), function (s) {
        var t = money(+s.dataset.price, s.hasAttribute("data-monthly"));
        s.textContent = t; return t;
      });
      box.setAttribute("aria-label", parts.join(" + "));
      Array.prototype.forEach.call(box.querySelectorAll("[data-price]"), function (s, i) { s.classList.toggle("plus", i > 0); });
    });
  }
  function message() {
    var d = dict(), name = d["tab_" + current] || "";
    return d.wa_hello + name;
  }
  function syncLinks() { $("sh-wa").href = WA + "?text=" + encodeURIComponent(message()); }

  function show(key, focus) {
    current = key;
    tabs.forEach(function (t) {
      var on = t.dataset.show === key;
      t.setAttribute("aria-selected", String(on)); t.tabIndex = on ? 0 : -1;
      if (on && focus) t.focus();
    });
    document.querySelectorAll(".show-pic").forEach(function (p) { p.classList.toggle("on", p.dataset.pic === key); });
    document.querySelectorAll(".show-text").forEach(function (p) {
      var on = p.id === "pn-" + key; p.hidden = !on;
      if (on && !reduce && p.animate) p.animate([{ opacity: 0, transform: "translateY(10px)" }, { opacity: 1, transform: "none" }], { duration: 380, easing: "cubic-bezier(.2,.7,.1,1)" });
    });
    $("sh-toast").textContent = "";
    syncLinks();
  }

  tabs.forEach(function (t, i) {
    t.addEventListener("click", function () { show(t.dataset.show); });
    t.addEventListener("keydown", function (e) {
      var n = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      if (n) { e.preventDefault(); show(tabs[(i + n + tabs.length) % tabs.length].dataset.show, true); }
    });
  });

  $("sh-tg").addEventListener("click", function () {
    var text = message(), toast = $("sh-toast");
    function open() { window.open(TG, "_blank", "noopener"); }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { toast.textContent = dict().show_copied; open(); }, open);
    } else { open(); }
  });

  new MutationObserver(function () { paintPrices(); syncLinks(); $("sh-toast").textContent = ""; })
    .observe(document.documentElement, { attributes: true, attributeFilter: ["lang"] });
  document.addEventListener("DOMContentLoaded", function () { paintPrices(); syncLinks(); });
  paintPrices(); syncLinks();
})();
