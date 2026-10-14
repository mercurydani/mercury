/* Mercury Studio — estimate builder. Prices live in the data-price attributes of index.html. */
(function () {
  var opts = Array.prototype.slice.call(document.querySelectorAll(".opt input"));
  if (!opts.length) return;
  var $ = function (id) { return document.getElementById(id); };
  var TG = "https://t.me/mercury_dani_rs", WA = "https://wa.me/381653454290";

  function lang() {
    var l = document.documentElement.lang;
    return l === "en" ? "en" : l === "ru" ? "ru" : "sr";
  }
  function dict() { return I18N[lang()] || I18N.sr; }
  function money(n, monthly) {
    var d = dict(), v = lang() === "en" ? "€" + n : n + " €";
    return d.r_from + " " + v + (monthly ? " " + d.r_mo : "");
  }
  function label(input) {
    var d = dict(), name = d[input.dataset.name] || "";
    return input.dataset.prefix ? d[input.dataset.prefix] + " · " + name : name;
  }
  function priceText(input) {
    var p = input.dataset.price;
    return p === "" ? dict().t3_price : money(+p, input.hasAttribute("data-monthly"));
  }

  function render() {
    var d = dict(), lines = [], sum = 0, mo = 0, agree = false;
    opts.forEach(function (i) {
      i.closest(".opt").querySelector("[data-price-label]").textContent = priceText(i);
      if (!i.checked) return;
      lines.push([label(i), priceText(i)]);
      if (i.dataset.price === "") agree = true;
      else if (i.hasAttribute("data-monthly")) mo += +i.dataset.price;
      else sum += +i.dataset.price;
    });
    var box = $("r-lines");
    box.innerHTML = "";
    if (!lines.length) {
      var e = document.createElement("div"); e.className = "r-empty";
      e.innerHTML = "<i></i><i></i><i></i><span></span>"; e.querySelector("span").textContent = d.r_empty; box.appendChild(e);
    }
    lines.forEach(function (l) {
      var row = document.createElement("div"); row.className = "r-line";
      var a = document.createElement("span"); a.className = "r-name"; a.textContent = l[0];
      var dots = document.createElement("i"); dots.className = "r-dots";
      var b = document.createElement("span"); b.className = "r-price"; b.textContent = l[1];
      row.appendChild(a); row.appendChild(dots); row.appendChild(b); box.appendChild(row);
    });
    var tail = agree ? (sum ? " + " : "") + d.t3_price : "";
    var total = sum ? money(sum) + tail : agree ? d.t3_price : "—";
    countTo(sum, tail);
    $("r-clear").hidden = !lines.length;
    var key = opts.filter(function (i) { return i.checked; }).map(function (i) { return i.dataset.name; }).join(",");
    $("r-no").textContent = lines.length ? estimateNo(key) : "—";
    barcode(key);
    syncPicks(key);
    $("r-mo").textContent = mo ? "+ " + money(mo, true) : "";
    $("r-tg").disabled = !lines.length;
    $("mbar").classList.toggle("on", lines.length > 0);
    var text = message(lines, total, mo);
    $("r-wa").href = lines.length ? WA + "?text=" + encodeURIComponent(text) : WA;
    return text;
  }
  function message(lines, total, mo) {
    var d = dict();
    return d.r_hello + "\n" + lines.map(function (l) { return "— " + l[0] + ": " + l[1]; }).join("\n") +
      "\n" + d.r_total + ": " + total + (mo ? " + " + money(mo, true) : "");
  }


  // animated total
  var shown = 0, anim = null;
  function countTo(target, tail) {
    var from = shown, t0 = null, el = $("r-sum"), m = $("m-sum");
    function paint(v, done) {
      var txt = (done ? target : Math.round(v)) ? money(Math.round(v)) + tail : (tail || "—");
      el.textContent = txt; m.textContent = txt;
    }
    cancelAnimationFrame(anim);
    if (from === target || matchMedia("(prefers-reduced-motion: reduce)").matches) { shown = target; paint(target, true); return; }
    function step(t) {
      if (!t0) t0 = t;
      var k = Math.min(1, (t - t0) / 420), e = 1 - Math.pow(1 - k, 3);
      shown = from + (target - from) * e; paint(shown);
      if (k < 1) anim = requestAnimationFrame(step); else { shown = target; paint(target, true); }
    }
    anim = requestAnimationFrame(step);
  }

  function hash(str) { var h = 2166136261; for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function estimateNo(key) {
    var n = new Date();
    return String(n.getMonth() + 1).padStart(2, "0") + String(n.getDate()).padStart(2, "0") + "-" + String(hash(key) % 1000).padStart(3, "0");
  }
  // barcode drawn from the current selection, so it changes with the order
  function barcode(key) {
    var el = $("r-code"), h = hash(key || "mercury"), html = "";
    for (var i = 0; i < 96; i++) {
      h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
      var w = 1 + (h % 3), gap = 1 + ((h >>> 4) % 3);
      html += '<i style="width:' + w + 'px;margin-right:' + (gap - 1) + 'px"></i>';
    }
    el.innerHTML = html;
  }

  var picks = Array.prototype.slice.call(document.querySelectorAll("[data-pick]"));
  function syncPicks(key) {
    picks.forEach(function (b) {
      var want = b.dataset.pick.split(",").sort().join(","), have = key.split(",").sort().join(",");
      b.setAttribute("aria-pressed", String(want === have));
    });
  }
  picks.forEach(function (b) {
    b.addEventListener("click", function () {
      var names = b.dataset.pick.split(",");
      opts.forEach(function (i) { i.checked = names.indexOf(i.dataset.name) > -1; });
      feed(); render();
    });
  });
  function feed() {
    var r = document.querySelector(".receipt");
    r.classList.remove("feed"); void r.offsetWidth; r.classList.add("feed");
  }

  opts.forEach(function (i) {
    i.addEventListener("change", function () {
      if (i.checked && i.name !== "extra") {
        opts.forEach(function (o) { if (o !== i && o.name === i.name) o.checked = false; });
      }
      feed(); render();
    });
  });

  $("r-tg").addEventListener("click", function () {
    var text = render(), toast = $("r-toast");
    function open() { window.open(TG, "_blank", "noopener"); }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { toast.textContent = dict().r_copied; open(); }, open);
    } else { open(); }
  });

  $("r-clear").addEventListener("click", function () { opts.forEach(function (i) { i.checked = false; }); feed(); render(); });

  var dt = $("r-date");
  if (dt) { var n = new Date(); dt.textContent = String(n.getDate()).padStart(2, "0") + "." + String(n.getMonth() + 1).padStart(2, "0") + "." + n.getFullYear(); }

  var receiptVisible = false;
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (es) { receiptVisible = es[0].isIntersecting; $("mbar").classList.toggle("away", receiptVisible); })
      .observe(document.querySelector(".receipt"));
  }

  // re-render when the language switch changes <html lang>
  new MutationObserver(function () { $("r-toast").textContent = ""; render(); })
    .observe(document.documentElement, { attributes: true, attributeFilter: ["lang"] });
  document.addEventListener("DOMContentLoaded", render);
  render();
})();
