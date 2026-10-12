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
      var e = document.createElement("div"); e.className = "r-empty"; e.textContent = d.r_empty; box.appendChild(e);
    }
    lines.forEach(function (l) {
      var row = document.createElement("div"); row.className = "r-line";
      var a = document.createElement("span"); a.textContent = l[0];
      var b = document.createElement("span"); b.textContent = l[1];
      row.appendChild(a); row.appendChild(b); box.appendChild(row);
    });
    var total = sum ? money(sum) + (agree ? " + " + d.t3_price : "") : agree ? d.t3_price : (mo ? "—" : "—");
    $("r-sum").textContent = total;
    $("m-sum").textContent = total;
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

  opts.forEach(function (i) {
    i.addEventListener("change", function () {
      if (i.checked && i.name !== "extra") {
        opts.forEach(function (o) { if (o !== i && o.name === i.name) o.checked = false; });
      }
      render();
    });
  });

  $("r-tg").addEventListener("click", function () {
    var text = render(), toast = $("r-toast");
    function open() { window.open(TG, "_blank", "noopener"); }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { toast.textContent = dict().r_copied; open(); }, open);
    } else { open(); }
  });

  var dt = $("r-date");
  if (dt) { var n = new Date(); dt.textContent = String(n.getDate()).padStart(2, "0") + "." + String(n.getMonth() + 1).padStart(2, "0") + "." + n.getFullYear(); }

  // re-render when the language switch changes <html lang>
  new MutationObserver(function () { $("r-toast").textContent = ""; render(); })
    .observe(document.documentElement, { attributes: true, attributeFilter: ["lang"] });
  document.addEventListener("DOMContentLoaded", render);
  render();
})();
