#!/usr/bin/env python3
"""Builds both versions of the JIN2DRAW site from tools/source.html.

  onepage/    one self-contained index.html (everything on one page, anchor menu)
  multipage/  index.html (hero + portal tiles) and one page per section,
              sharing assets/site.css, assets/content.js, assets/site.js

Edit content (works, queue, prices, links, texts) at the top of the script in
tools/source.html, then run:  python3 tools/build.py
For the multi-page version you can also edit multipage/assets/content.js directly,
but it is overwritten on the next build.
"""
import pathlib, re, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / "tools/source.html").read_text(encoding="utf-8")
ASSETS = ["avatar.jpg", "banner.jpg"]


def between(s, a, b, start=0):
    i = s.index(a, start)
    j = s.index(b, i + len(a))
    return s[i:j + len(b)]


# ---------- pieces of the source ----------
head_top = SRC[:SRC.index("<style>")]
style = between(SRC, "<style>", "</style>")[len("<style>"):-len("</style>")]
sprite = between(SRC, '<svg width="0" height="0"', "</svg>\n\n<canvas")[:-len("\n\n<canvas")]
canvases = '<canvas id="space" aria-hidden="true"></canvas>'
hero = between(SRC, '<div class="banner" id="top">', "</header>")
footer = between(SRC, '<footer class="foot">', "</footer>")
dialog = between(SRC, '<dialog class="lb"', "</dialog>")
all_js = SRC[SRC.rindex("<script>") + len("<script>"):SRC.rindex("</script>")]
split = all_js.index("/* =====================================================================\n   RENDERING")
content_js, rest = all_js[:split], all_js[split:]
bg_at = rest.index("/* =====================================================================\n   BACKGROUND")
render_js, bg_js = rest[:bg_at], rest[bg_at:]

SECTIONS = {}
for sid in ["portfolio", "queue", "prices", "tos", "links"]:
    m = re.search(r'  <section class="wrap sec" id="%s".*?\n  </section>' % sid, SRC, re.S)
    SECTIONS[sid] = m.group(0)

PAGES = [  # file, section id, nav label key, <title>
    ("portfolio.html", "portfolio", "nav_portfolio", "Portfolio"),
    ("queue.html", "queue", "nav_queue", "Queue"),
    ("prices.html", "prices", "nav_prices", "Prices"),
    ("tos.html", "tos", "nav_tos", "Terms of service"),
    ("links.html", "links", "nav_links", "Links"),
]


def head(title, css_link):
    h = head_top.replace("<title>JIN2DRAW · digital artist</title>", "<title>%s</title>" % title)
    return h + css_link + "\n</head>\n"


# ---------- one-page version: the source as is ----------
one = ROOT / "onepage"
one.mkdir(exist_ok=True)
(one / "index.html").write_text(SRC, encoding="utf-8")
for a in ASSETS:
    shutil.copy(ROOT / a, one / a)
(one / "works").mkdir(exist_ok=True)

# ---------- multi-page version ----------
mp = ROOT / "multipage"
(mp / "assets").mkdir(parents=True, exist_ok=True)
(mp / "works").mkdir(exist_ok=True)
for a in ASSETS:
    shutil.copy(ROOT / a, mp / a)
(mp / "assets/site.css").write_text(style.strip() + "\n", encoding="utf-8")
(mp / "assets/content.js").write_text("/* JIN2DRAW · all content: edit here */\n" + content_js.strip() + "\n", encoding="utf-8")
(mp / "assets/site.js").write_text(render_js.strip() + "\n\n" + bg_js.strip() + "\n", encoding="utf-8")

CSS = '<link rel="stylesheet" href="assets/site.css">'
SCRIPTS = '<script src="assets/content.js"></script>\n<script src="assets/site.js"></script>'


def nav(current, static):
    items = "".join(
        '\n    <a href="%s" data-t="%s"%s>%s</a>' % (f, k, ' aria-current="true"' if f == current else "", t.split()[0] if f != "tos.html" else "TOS")
        for f, _, k, t in PAGES)
    return ('<nav class="nav%s" id="nav" aria-label="Pages">\n  <div class="nav-in">\n'
            '    <a class="home" href="index.html" aria-label="Home"><img src="avatar.jpg" alt="" width="30" height="30"></a>%s\n'
            '    <button class="lang" type="button" id="lang" aria-label="Switch language">RU</button>\n  </div>\n</nav>') % (" static" if static else "", items)


# home: the full hero, then portal tiles
home_hero = (hero.replace('href="#prices"', 'href="prices.html"').replace('href="#links"', 'href="links.html"')
             .replace('href="#portfolio"', 'href="#portal"'))
portal = '''  <section class="wrap sec" id="portal" aria-labelledby="pt-h">
    <div class="sec-h reveal"><span class="star-rule"><svg aria-hidden="true"><use href="#star"/></svg></span><h2 id="pt-h" data-t="pt_h">Where to?</h2><p data-t="pt_p">Pick a page.</p></div>
    <ul class="portal" id="portal"></ul>
  </section>'''.replace('id="portal" aria-labelledby', 'id="where" aria-labelledby')
home_hero = home_hero.replace('href="#portal"', 'href="#where"')
home = (head("JIN2DRAW · digital artist", CSS) + "<body>\n" + '<script>document.documentElement.classList.add("js")</script>\n'
        + sprite + "\n\n" + canvases + "\n\n" + home_hero + "\n\n" + nav("", False) + "\n\n<main>\n" + portal + "\n</main>\n\n"
        + footer + "\n\n" + SCRIPTS + "\n</body>\n</html>\n")
(mp / "index.html").write_text(home, encoding="utf-8")

# inner pages: small header, static nav, one section, prev/next
for n, (f, sid, k, title) in enumerate(PAGES):
    sec = SECTIONS[sid]
    prev_ = PAGES[n - 1] if n > 0 else None
    next_ = PAGES[n + 1] if n + 1 < len(PAGES) else None
    pager = '\n    <nav class="pager" aria-label="More pages">'
    pager += ('<a class="glass" href="%s"><small>←</small><b data-t="%s">%s</b></a>' % (prev_[0], prev_[2], prev_[3])) if prev_ else \
             '<a class="glass" href="index.html"><small>←</small><b data-t="back_home">Home</b></a>'
    if next_:
        pager += '<a class="glass" href="%s"><small>→</small><b data-t="%s">%s</b></a>' % (next_[0], next_[2], next_[3])
    pager += "</nav>\n  </section>"
    sec = sec[:sec.rindex("  </section>")] + pager.lstrip("\n").replace("    <nav", "    <nav", 1)
    header = '''<div class="banner banner-sm" id="top"><img src="banner.jpg" alt="" width="1600" height="900" data-fallback="banner"></div>
<header class="hero hero-sm">
  <div class="hero-in">
    <h1><a class="mini" href="index.html"><img src="avatar.jpg" alt="" width="52" height="52" data-fallback="avatar"><span class="logo">JIN2DRAW</span></a></h1>
    <p class="badge" id="badge"><i></i><span data-t="badge_open">Commissions open</span></p>
  </div>
</header>'''
    page = (head("%s · JIN2DRAW" % title, CSS) + '<body class="sub">\n<script>document.documentElement.classList.add("js")</script>\n'
            + sprite + "\n\n" + canvases + "\n\n" + header + "\n\n" + nav(f, True) + "\n\n<main>\n" + sec + "\n</main>\n\n" + footer + "\n\n"
            + (dialog + "\n\n" if sid == "portfolio" else "") + SCRIPTS + "\n</body>\n</html>\n")
    (mp / f).write_text(page, encoding="utf-8")

print("built onepage/index.html and multipage/ (%d pages)" % (len(PAGES) + 1))
