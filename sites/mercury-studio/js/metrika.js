/* Yandex.Metrika. Put the counter number from metrika.yandex.ru instead of 0 and the site starts sending visits.
   Clicks on Telegram, WhatsApp and the phone are sent as goals: tg, wa, phone. */
(function () {
  var YM_ID = 0;
  if (!YM_ID) return;
  (function (m, e, t, r, i, k, a) {
    m[i] = m[i] || function () { (m[i].a = m[i].a || []).push(arguments); };
    m[i].l = 1 * new Date();
    for (var j = 0; j < document.scripts.length; j++) { if (document.scripts[j].src === r) return; }
    k = e.createElement(t); a = e.getElementsByTagName(t)[0]; k.async = 1; k.src = r; a.parentNode.insertBefore(k, a);
  })(window, document, "script", "https://mc.yandex.ru/metrika/tag.js", "ym");
  ym(YM_ID, "init", { clickmap: true, trackLinks: true, accurateTrackBounce: true, webvisor: true });
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[href], #sh-tg");
    if (!a) return;
    var h = a.getAttribute("href") || "";
    var goal = a.id === "sh-tg" || h.indexOf("t.me/") > -1 ? "tg" : h.indexOf("wa.me/") > -1 ? "wa" : h.indexOf("tel:") === 0 ? "phone" : "";
    if (goal) ym(YM_ID, "reachGoal", goal);
  });
})();
