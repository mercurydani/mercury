// Embed: <script src="https://YOUR_HOST/widget.js" data-workspace="WORKSPACE_ID"></script>
(function () {
  var script = document.currentScript;
  var workspace = script && script.getAttribute("data-workspace");
  if (!workspace) return console.warn("Mercury widget: data-workspace is missing");
  var base = new URL(script.src).origin;
  var title = script.getAttribute("data-title") || "Chat with us";

  var key = "mercury_session_" + workspace;
  var sessionId;
  try {
    sessionId = localStorage.getItem(key);
    if (!sessionId) localStorage.setItem(key, (sessionId = Math.random().toString(36).slice(2) + Date.now().toString(36)));
  } catch (e) {
    sessionId = Math.random().toString(36).slice(2);
  }

  var css =
    "#mw-btn{position:fixed;right:20px;bottom:20px;width:56px;height:56px;border-radius:50%;border:0;background:#4f46e5;color:#fff;font-size:24px;cursor:pointer;box-shadow:0 6px 20px rgba(0,0,0,.25);z-index:2147483646}" +
    "#mw-box{position:fixed;right:20px;bottom:88px;width:min(360px,calc(100vw - 40px));height:min(520px,calc(100vh - 120px));background:#fff;color:#111;border-radius:14px;box-shadow:0 10px 40px rgba(0,0,0,.25);display:none;flex-direction:column;overflow:hidden;font:14px/1.45 system-ui,sans-serif;z-index:2147483647}" +
    "#mw-box header{background:#4f46e5;color:#fff;padding:12px 14px;font-weight:600}" +
    "#mw-log{flex:1;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:8px}" +
    ".mw-m{max-width:85%;padding:8px 11px;border-radius:12px;white-space:pre-wrap;word-wrap:break-word}" +
    ".mw-u{align-self:flex-end;background:#4f46e5;color:#fff}.mw-a{align-self:flex-start;background:#f1f1f4}" +
    "#mw-form{display:flex;border-top:1px solid #eee}#mw-in{flex:1;border:0;padding:12px;font:inherit;outline:none}" +
    "#mw-form button{border:0;background:none;color:#4f46e5;font-weight:600;padding:0 14px;cursor:pointer}";
  var style = document.createElement("style");
  style.textContent = css;
  document.head.appendChild(style);

  var btn = document.createElement("button");
  btn.id = "mw-btn";
  btn.setAttribute("aria-label", title);
  btn.textContent = "💬";
  var box = document.createElement("div");
  box.id = "mw-box";
  box.innerHTML =
    '<header></header><div id="mw-log"></div><form id="mw-form"><input id="mw-in" placeholder="Type your question…" autocomplete="off"><button>Send</button></form>';
  box.querySelector("header").textContent = title;
  document.body.appendChild(btn);
  document.body.appendChild(box);

  var log = box.querySelector("#mw-log");
  var input = box.querySelector("#mw-in");

  function add(text, who) {
    var el = document.createElement("div");
    el.className = "mw-m " + (who === "user" ? "mw-u" : "mw-a");
    el.textContent = text;
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  }

  btn.onclick = function () {
    var open = box.style.display === "flex";
    box.style.display = open ? "none" : "flex";
    if (!open && !log.children.length) add("Hi! How can I help you today?", "assistant");
    if (!open) input.focus();
  };

  box.querySelector("#mw-form").onsubmit = function (e) {
    e.preventDefault();
    var text = input.value.trim();
    if (!text) return;
    input.value = "";
    add(text, "user");
    var pending = add("…", "assistant");
    fetch(base + "/api/chat/" + encodeURIComponent(workspace), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: text, sessionId: sessionId }),
    })
      .then(function (r) { return r.json(); })
      .then(function (d) { pending.textContent = d.reply || d.error || "Something went wrong."; })
      .catch(function () { pending.textContent = "Connection problem. Please try again."; });
  };
})();
