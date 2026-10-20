#!/usr/bin/env python3
"""Build the two language pages from src/index.html.

/      Russian   (public/index.html)
/sr/   Serbian   (public/sr/index.html)

Each page keeps only its own language blocks, gets its own head
(title, description, canonical, hreflang, Open Graph) and JSON-LD,
so search engines see one language per URL. Run: python3 build.py
"""
import json, pathlib, re
from bs4 import BeautifulSoup

ROOT = pathlib.Path(__file__).parent
SITE = "https://mercurytennis.site"
PHONE = "+381653454290"
TG = "https://t.me/mercurydani_tenisrs"
MAP = "https://maps.app.goo.gl/VyQ3v974LtXgkpUQA"

PAGES = {
    "ru": {
        "path": "/", "out": "public/index.html", "locale": "ru_RU", "alt_locale": "sr_RS",
        "title": "Тренер по теннису в Белграде на русском · Mercury Tennis",
        "desc": "Тренировки по теннису в Белграде на русском для взрослых и детей. Индивидуально, вдвоём и в группе, корт TK Haron включён в цену. Пробное 2 000 RSD.",
        "og_title": "Теннис в Белграде на русском · Mercury Tennis",
        "og_desc": "Индивидуальные и групповые тренировки для взрослых и детей. Корт включён в цену. Пробное занятие 2 000 RSD.",
        "og_image": "/og.jpg", "og_alt": "Mercury Tennis: теннис в Белграде на русском, пробное занятие 2 000 RSD",
        "biz_desc": "Тренировки по теннису в Белграде на русском языке для взрослых и детей. Корты TK Haron у Ветеринарного факультета, корт включён в цену.",
        "job": "Тренер по теннису",
        "offers": [("Пробное занятие", 2000), ("Индивидуальная тренировка, 1 час", 4000), ("Тренировка вдвоём, 1 час", 5000),
                   ("Мини-группа, 1 час с человека", 1800), ("Детская группа, 4 занятия в месяц", 6000), ("Абонемент на 10 индивидуальных", 36000)],
    },
    "sr": {
        "path": "/sr/", "out": "public/sr/index.html", "locale": "sr_RS", "alt_locale": "ru_RU",
        "title": "Trener tenisa u Beogradu za sve nivoe · Mercury Tennis",
        "desc": "Časovi tenisa u Beogradu za odrasle i decu. Individualno, u paru i u grupi, teren TK Haron je uračunat u cenu. Probni trening 2.000 RSD.",
        "og_title": "Tenis u Beogradu za sve nivoe · Mercury Tennis",
        "og_desc": "Individualni i grupni treninzi za odrasle i decu. Teren je uračunat u cenu. Probni trening 2.000 RSD.",
        "og_image": "/og-sr.jpg", "og_alt": "Mercury Tennis: tenis u Beogradu za sve nivoe, probni trening 2.000 RSD",
        "biz_desc": "Treninzi tenisa u Beogradu na srpskom i ruskom za odrasle i decu. Tereni TK Haron kod Veterinarskog fakulteta, teren je uračunat u cenu.",
        "job": "Trener tenisa",
        "offers": [("Probni trening", 2000), ("Individualni trening, 1 sat", 4000), ("Trening u paru, 1 sat", 5000),
                   ("Mala grupa, 1 sat po osobi", 1800), ("Grupa za decu, 4 treninga mesečno", 6000), ("Paket od 10 individualnih treninga", 36000)],
    },
}

def jsonld(lang, cfg, faq):
    url = SITE + cfg["path"]
    person = {"@type": "Person", "@id": SITE + "/#coach", "name": "Daniil Pomazkov",
              "alternateName": "Даниил Помазков", "jobTitle": cfg["job"], "knowsLanguage": ["ru", "sr", "en"],
              "sameAs": [TG]}
    biz = {"@type": "SportsActivityLocation", "@id": SITE + "/#business", "name": "Mercury Tennis",
           "description": cfg["biz_desc"], "url": url, "telephone": PHONE, "image": SITE + cfg["og_image"],
           "logo": SITE + "/favicon-192.png", "priceRange": "1800–5000 RSD", "currenciesAccepted": "RSD",
           "paymentAccepted": "Cash, Bank transfer", "hasMap": MAP, "sameAs": [TG],
           "address": {"@type": "PostalAddress", "addressLocality": "Beograd", "addressCountry": "RS"},
           "areaServed": {"@type": "City", "name": "Beograd"}, "knowsLanguage": ["ru", "sr", "en"],
           "founder": {"@id": SITE + "/#coach"}, "employee": {"@id": SITE + "/#coach"},
           "makesOffer": [{"@type": "Offer", "name": n, "price": p, "priceCurrency": "RSD"} for n, p in cfg["offers"]]}
    site = {"@type": "WebSite", "@id": SITE + "/#site", "name": "Mercury Tennis", "url": SITE + "/", "inLanguage": ["ru", "sr"]}
    page = {"@type": "WebPage", "@id": url + "#page", "url": url, "name": cfg["title"], "description": cfg["desc"],
            "inLanguage": lang, "isPartOf": {"@id": SITE + "/#site"}, "about": {"@id": SITE + "/#business"}}
    faqpage = {"@type": "FAQPage", "@id": url + "#faq", "inLanguage": lang,
               "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in faq]}
    return json.dumps({"@context": "https://schema.org", "@graph": [site, page, biz, person, faqpage]}, ensure_ascii=False, separators=(",", ":"))

def build(lang):
    cfg, other = PAGES[lang], ("sr" if lang == "ru" else "ru")
    soup = BeautifulSoup((ROOT / "src/index.html").read_text(encoding="utf-8"), "html.parser")
    soup.html["lang"] = lang
    for el in soup.select(f'[data-l="{other}"]'):
        el.decompose()
    for a in soup.select(".langs a[data-set]"):
        if a["data-set"] == lang: a["aria-current"] = "page"
        else: a.attrs.pop("aria-current", None)
    if lang == "sr":
        soup.select_one("#f-name")["placeholder"] = "Ana"
        soup.select_one(".langs")["aria-label"] = "Jezik"
    else:
        soup.select_one(".langs")["aria-label"] = "Язык"

    faq = [(d.summary.get_text(" ", strip=True), d.p.get_text(" ", strip=True)) for d in soup.select("#faq details")]

    head = soup.head
    for sel in ["title", 'meta[name="description"]', 'link[rel="canonical"]', 'link[rel="alternate"]', 'meta[name="robots"]',
                'meta[property^="og:"]', 'meta[name^="twitter:"]', 'script[type="application/ld+json"]']:
        for el in head.select(sel): el.decompose()
    url = SITE + cfg["path"]
    tags = [f'<title>{cfg["title"]}</title>',
            f'<meta name="description" content="{cfg["desc"]}">',
            '<meta name="robots" content="index, follow, max-image-preview:large">',
            f'<link rel="canonical" href="{url}">',
            f'<link rel="alternate" hreflang="ru" href="{SITE}/">',
            f'<link rel="alternate" hreflang="sr" href="{SITE}/sr/">',
            f'<link rel="alternate" hreflang="x-default" href="{SITE}/">',
            '<meta property="og:type" content="website">',
            f'<meta property="og:locale" content="{cfg["locale"]}">',
            f'<meta property="og:locale:alternate" content="{cfg["alt_locale"]}">',
            '<meta property="og:site_name" content="Mercury Tennis">',
            f'<meta property="og:title" content="{cfg["og_title"]}">',
            f'<meta property="og:description" content="{cfg["og_desc"]}">',
            f'<meta property="og:url" content="{url}">',
            f'<meta property="og:image" content="{SITE}{cfg["og_image"]}">',
            '<meta property="og:image:width" content="1200">', '<meta property="og:image:height" content="630">',
            f'<meta property="og:image:alt" content="{cfg["og_alt"]}">',
            '<meta name="twitter:card" content="summary_large_image">',
            f'<script type="application/ld+json">{jsonld(lang, cfg, faq)}</script>']
    anchor = head.select_one('meta[name="viewport"]')
    for t in reversed(tags):
        anchor.insert_after(BeautifulSoup(t, "html.parser"))
        anchor.insert_after("\n")
    out = ROOT / cfg["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    html = re.sub(r"\n\s*\n+", "\n", str(soup))
    out.write_text(html if html.startswith("<!") else "<!doctype html>\n" + html, encoding="utf-8")
    print("wrote", cfg["out"], len(html), "bytes")

for l in PAGES: build(l)
