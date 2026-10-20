# Mercury Tennis

Edit `src/index.html` (both languages live there, marked `data-l="ru"` / `data-l="sr"`),
then run `python3 build.py`. It writes:

- `public/index.html` — Russian, served at `/`
- `public/sr/index.html` — Serbian, served at `/sr/`

Each page keeps only its own language and gets its own title, description,
canonical, hreflang, Open Graph and JSON-LD (business, coach, prices, FAQ).
Titles, descriptions and prices for search live at the top of `build.py`.

Deploy: `npx wrangler deploy` (serves `./public`).
After the first deploy: add the site in Google Search Console and Yandex Webmaster
and submit `https://mercurytennis.site/sitemap.xml`.
