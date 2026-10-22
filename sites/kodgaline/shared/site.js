/* Kod Galine demo: the words in three languages, the menu, and the small behaviours both variants share. */
var KG = (function () {
  var T = {
    sr: {
      nav_menu: "Meni", nav_about: "O nama", nav_find: "Kontakt",
      open: "Novo mesto · We are open",
      hero_sub: "Ručno pravljeni pelmeni, manti i vareniki u centru Beograda.",
      hero_where: "Cara Dušana 14 · pon–pet 11:00–20:00",
      wolt: "Naruči na Wolt", see_menu: "Pogledaj meni", call: "Pozovi",
      about_h: "Kao kod bake",
      about_p1: "Kod Galine znači „kod Galine“. Mesto gde se jede kao kod kuće: Galina ručno pravi pelmene, mante i varenike po domaćim receptima.",
      about_p2: "Samo prirodni sastojci, testo i fil spremamo sveže. Svratite na topao obrok ili poručite kući preko Wolta.",
      f1: "Ručna izrada", f2: "Prirodni sastojci", f3: "Uvek sveže",
      ph_galina: "Ovde ide fotografija Galine",
      menu_h: "Meni", menu_note: "Cene su primer, prave cene dodajemo zajedno sa vama.",
      c_all: "Sve", c_pelmeni: "Pelmeni", c_manti: "Manti", c_vareniki: "Vareniki", c_supe: "Supe i topla jela", c_salate: "Salate", c_deserti: "Deserti", c_pica: "Pića",
      rev_h: "Šta kažu gosti", rev_tag: "Primer recenzije", rev_text: "Ovde će stajati prava recenzija gosta sa Google mapa ili Instagrama.", rev_name: "Ime gosta",
      find_h: "Gde smo", addr_l: "Adresa", hours_l: "Radno vreme", hours: "Ponedeljak–petak, 11:00–20:00", phone_l: "Telefon", phone: "[broj telefona]",
      map_ph: "Mapa: Cara Dušana 14, Beograd",
      foot_demo: "Demo verzija sajta, Mercury Studio",
      ph: "foto", order_short: "Wolt",
      slogan2: "Pelmeni. Manti. Vareniki.", strip: "Soul in every bite · Handmade Dumplings · Ručno pravljeni dumplingi"
    },
    en: {
      nav_menu: "Menu", nav_about: "About", nav_find: "Contact",
      open: "New place · We are open",
      hero_sub: "Handmade pelmeni, manti and vareniki in the centre of Belgrade.",
      hero_where: "Cara Dušana 14 · Mon–Fri 11:00–20:00",
      wolt: "Order on Wolt", see_menu: "See the menu", call: "Call us",
      about_h: "Just like grandma's",
      about_p1: "Kod Galine means “at Galina's”. A place to eat like at home: Galina makes every pelmen, mant and varenik by hand, from home recipes.",
      about_p2: "Only natural ingredients, dough and fillings made fresh. Drop in for a warm meal or order home via Wolt.",
      f1: "Made by hand", f2: "Natural ingredients", f3: "Always fresh",
      ph_galina: "Galina's photo goes here",
      menu_h: "Menu", menu_note: "Prices are placeholders, we add the real ones together with you.",
      c_all: "All", c_pelmeni: "Pelmeni", c_manti: "Manti", c_vareniki: "Vareniki", c_supe: "Soups and hot dishes", c_salate: "Salads", c_deserti: "Desserts", c_pica: "Drinks",
      rev_h: "What guests say", rev_tag: "Sample review", rev_text: "A real guest review from Google Maps or Instagram will go here.", rev_name: "Guest name",
      find_h: "Find us", addr_l: "Address", hours_l: "Opening hours", hours: "Monday–Friday, 11:00–20:00", phone_l: "Phone", phone: "[phone number]",
      map_ph: "Map: Cara Dušana 14, Belgrade",
      foot_demo: "Demo version of the site, Mercury Studio",
      ph: "photo", order_short: "Wolt",
      slogan2: "Pelmeni. Manti. Vareniki.", strip: "Soul in every bite · Handmade Dumplings · Made by hand in Belgrade"
    },
    ru: {
      nav_menu: "Меню", nav_about: "О нас", nav_find: "Контакты",
      open: "Новое место · We are open",
      hero_sub: "Пельмени, манты и вареники ручной лепки в центре Белграда.",
      hero_where: "Cara Dušana 14 · пн–пт 11:00–20:00",
      wolt: "Заказать на Wolt", see_menu: "Посмотреть меню", call: "Позвонить",
      about_h: "Как у бабушки",
      about_p1: "Kod Galine значит «у Галины». Место, где едят как дома: Галина лепит пельмени, манты и вареники руками, по домашним рецептам.",
      about_p2: "Только натуральные продукты, тесто и начинку готовим свежими. Заходите на горячий обед или закажите домой через Wolt.",
      f1: "Ручная лепка", f2: "Натуральные продукты", f3: "Всегда свежее",
      ph_galina: "Здесь будет фото Галины",
      menu_h: "Меню", menu_note: "Цены для примера, настоящие добавим вместе с вами.",
      c_all: "Всё", c_pelmeni: "Пельмени", c_manti: "Манты", c_vareniki: "Вареники", c_supe: "Супы и горячее", c_salate: "Салаты", c_deserti: "Десерты", c_pica: "Напитки",
      rev_h: "Что говорят гости", rev_tag: "Пример отзыва", rev_text: "Здесь будет настоящий отзыв гостя из Google Карт или Instagram.", rev_name: "Имя гостя",
      find_h: "Как нас найти", addr_l: "Адрес", hours_l: "Часы работы", hours: "Понедельник–пятница, 11:00–20:00", phone_l: "Телефон", phone: "[номер телефона]",
      map_ph: "Карта: Cara Dušana 14, Белград",
      foot_demo: "Демо-версия сайта, Mercury Studio",
      ph: "фото", order_short: "Wolt",
      slogan2: "Пельмени. Манты. Вареники.", strip: "Soul in every bite · Handmade Dumplings · Ручная лепка в Белграде"
    }
  };

  // name per language, description per language, image (or null for a placeholder)
  var MENU = [
    { c: "pelmeni", img: "pelmeni-wolt.jpg", n: { sr: "Pelmeni", en: "Pelmeni", ru: "Пельмени" },
      d: { sr: "Klasični pelmeni ručne izrade", en: "Classic handmade pelmeni", ru: "Классические пельмени ручной лепки" } },
    { c: "manti", img: null, n: { sr: "Manti", en: "Manti", ru: "Манты" },
      d: { sr: "Veliki dumplingi kuvani na pari", en: "Large steamed dumplings", ru: "Большие манты на пару" } },
    { c: "vareniki", img: null, n: { sr: "Vareniki", en: "Vareniki", ru: "Вареники" },
      d: { sr: "Domaći vareniki ručne izrade", en: "Homemade vareniki, made by hand", ru: "Домашние вареники ручной лепки" } },
    { c: "supe", img: "supa.jpg", n: { sr: "Supa sa ćuftama", en: "Meatball soup", ru: "Суп с фрикадельками" },
      d: { sr: "Topla domaća supa", en: "A warm homemade soup", ru: "Горячий домашний суп" } },
    { c: "supe", img: null, n: { sr: "Plov", en: "Plov", ru: "Плов" },
      d: { sr: "Pirinač sa mesom i šargarepom", en: "Rice with meat and carrots", ru: "Рис с мясом и морковью" } },
    { c: "supe", img: "pirozki.jpg", n: { sr: "Pirožki", en: "Pirozhki", ru: "Пирожки" },
      d: { sr: "Male domaće pite", en: "Small homemade pies", ru: "Домашние пирожки" } },
    { c: "salate", img: "salate.jpg", n: { sr: "Vinegret", en: "Vinegret", ru: "Винегрет" },
      d: { sr: "Salata od cvekle i povrća", en: "Beetroot and vegetable salad", ru: "Салат из свёклы и овощей" } },
    { c: "salate", img: null, n: { sr: "Kupus provansalski", en: "Provençal cabbage", ru: "Капуста провансаль" },
      d: { sr: "Mariniran kupus na domaći način", en: "Home-style marinated cabbage", ru: "Маринованная капуста по-домашнему" } },
    { c: "deserti", img: null, n: { sr: "Domaća torta", en: "Homemade cake", ru: "Домашний торт" },
      d: { sr: "Parče torte uz čaj ili kafu", en: "A slice to go with tea or coffee", ru: "Кусочек к чаю или кофе" } },
    { c: "deserti", img: "desert-casa.jpg", n: { sr: "Desert u čaši", en: "Dessert in a cup", ru: "Десерт в стаканчике" },
      d: { sr: "Slojeviti domaći desert", en: "A layered homemade dessert", ru: "Слоёный домашний десерт" } },
    { c: "pica", img: "mors.jpg", n: { sr: "Mors", en: "Mors", ru: "Морс" },
      d: { sr: "Napitak od bobica", en: "A berry drink", ru: "Ягодный морс" } }
  ];
  var CATS = ["all", "pelmeni", "manti", "vareniki", "supe", "salate", "deserti", "pica"];
  var lang = "sr", card = null, cat = "all";

  function t(k) { return (T[lang] || T.sr)[k] || k; }
  function renderMenu() {
    var tabs = document.getElementById("cats"), list = document.getElementById("dishes");
    if (!tabs || !list || !card) return;
    tabs.innerHTML = CATS.map(function (c) {
      return '<button type="button" data-c="' + c + '" aria-pressed="' + (c === cat) + '">' + t("c_" + c) + "</button>";
    }).join("");
    list.innerHTML = MENU.filter(function (m) { return cat === "all" || m.c === cat; }).map(function (m) {
      return card({ name: m.n[lang], desc: m.d[lang], img: m.img ? "../img/" + m.img : null, ph: t("ph") + ": " + m.n[lang].toLowerCase(), price: "000 RSD" });
    }).join("");
  }
  function setLang(l) {
    lang = T[l] ? l : "sr";
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-i]").forEach(function (el) { el.textContent = t(el.getAttribute("data-i")); });
    document.querySelectorAll("[data-lang]").forEach(function (b) { b.setAttribute("aria-pressed", b.getAttribute("data-lang") === lang); });
    renderMenu();
  }
  function init(opts) {
    card = opts.card;
    document.addEventListener("click", function (e) {
      var b = e.target.closest("[data-lang]");
      if (b) { setLang(b.getAttribute("data-lang")); return; }
      var c = e.target.closest("#cats [data-c]");
      if (c) { cat = c.getAttribute("data-c"); renderMenu(); }
    });
    setLang("sr");
  }
  return { init: init };
})();
