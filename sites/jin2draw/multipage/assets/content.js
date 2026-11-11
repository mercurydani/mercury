/* JIN2DRAW · all content: edit here */
/* =====================================================================
   CONTENT · edit everything here
   ===================================================================== */
var CONFIG = {
  commissionsOpen: true,      // ← true = OPEN badge, false = CLOSED
  slotsTotal: 5,              // ← how many orders you take at once
  currency: "$",              // ← "$", "€", "₽"…
  defaultLang: "en"           // ← "en" or "ru"
};

/* Portfolio. Put files in /works and list them here.
   w/h only set the tile shape until the image loads (use the real pixel size). */
var WORKS = [
  { src: "works/1.jpg",  title: "Ember in the dark",   tag: "Full body", w: 3, h: 4 },
  { src: "works/2.jpg",  title: "Sleepy marble cat",   tag: "Headshot",  w: 1, h: 1 },
  { src: "works/3.jpg",  title: "Star keeper",         tag: "Half body", w: 4, h: 5 },
  { src: "works/4.jpg",  title: "Ref sheet: Jin",      tag: "Ref sheet", w: 16, h: 10 },
  { src: "works/5.jpg",  title: "Night snack",         tag: "Headshot",  w: 1, h: 1 },
  { src: "works/6.jpg",  title: "Flame horns",         tag: "Half body", w: 3, h: 4 },
  { src: "works/7.jpg",  title: "Cosmic tail",         tag: "Full body", w: 2, h: 3 },
  { src: "works/8.jpg",  title: "Little light",        tag: "Headshot",  w: 1, h: 1 },
  { src: "works/9.jpg",  title: "Marble paws",         tag: "Half body", w: 4, h: 5 },
  { src: "works/10.jpg", title: "Ref sheet: guest OC", tag: "Ref sheet", w: 16, h: 11 }
];

/* Queue. status: "waiting" | "sketch" | "coloring" | "done"
   Taken slots = everything that is not "done". */
var QUEUE = [
  { client: "@starfox",    type: "Half body", status: "coloring" },
  { client: "@mothlight",  type: "Headshot",  status: "sketch" },
  { client: "@kitsu_nyan", type: "Ref sheet", status: "waiting" },
  { client: "@emberwolf",  type: "Full body", status: "done" }
];

/* Prices. img = example picture (optional). */
var PRICES = [
  { id: "head", price: 25, img: "works/2.jpg" },
  { id: "half", price: 45, img: "works/3.jpg", popular: true },
  { id: "full", price: 70, img: "works/1.jpg" },
  { id: "ref",  price: 90, img: "works/4.jpg" }
];
var EXTRAS = [ { id: "char", price: "+80%" }, { id: "bg", price: "+15" }, { id: "rush", price: "+30%" }, { id: "nsfw", price: "—" } ];

/* Links. Replace "#" with real URLs. brand = the hover colour. */
var LINKS = [
  { id: "telegram",  icon: "s-telegram",  name: "Telegram",    handle: "@jin2draw",           url: "#", brand: "#36a6e6" },
  { id: "email",     icon: "s-mail",      name: "Email",       handle: "hello@example.com",   url: "#", brand: "#ffc15e" },
  { id: "vgen",      icon: "s-vgen",      name: "VGen",        handle: "vgen.co/jin2draw",    url: "#", brand: "#b28cff" },
  { id: "fa",        icon: "s-fa",        name: "FurAffinity", handle: "jin2draw",            url: "#", brand: "#faaf3a" },
  { id: "x",         icon: "s-x",         name: "X / Twitter", handle: "@jin2draw",           url: "#", brand: "#e6e6ef" },
  { id: "instagram", icon: "s-instagram", name: "Instagram",   handle: "@jin2draw",           url: "#", brand: "#ff5f8f" },
  { id: "vk",        icon: "s-vk",        name: "VK",          handle: "vk.com/jin2draw",     url: "#", brand: "#4c8dff" },
  { id: "discord",   icon: "s-discord",   name: "Discord",     handle: "jin2draw",            url: "#", brand: "#7b87ff" },
  { id: "kofi",      icon: "s-kofi",      name: "Ko-fi",       handle: "ko-fi.com/jin2draw",  url: "#", brand: "#ff7a6b" },
  { id: "boosty",    icon: "s-boosty",    name: "Boosty",      handle: "boosty.to/jin2draw",  url: "#", brand: "#ff8a2a" }
];

/* All interface text, by language. Add a key here, then use data-t="key" in the HTML. */
var TEXT = {
  en: {
    tagline: 'digital artist · <b>commissions open</b>', tagline_closed: 'digital artist · <b>commissions closed</b>',
    badge_open: "Commissions open", badge_closed: "Commissions closed",
    cta_prices: "See prices", cta_contact: "Contact me", scroll: "scroll",
    nav_portfolio: "Portfolio", nav_queue: "Queue", nav_prices: "Prices", nav_tos: "TOS", nav_links: "Links",
    pf_h: "Portfolio", pf_p: "A few recent pieces. Tap any to look closer.", ph_art: "artwork coming soon",
    q_h: "Queue", q_p: "Where your order is right now.", slots_free: "free slots", q_empty: "The queue is empty. Perfect time to order!",
    st_waiting: "Waiting", st_sketch: "Sketch", st_coloring: "Coloring", st_done: "Done",
    pr_h: "Prices", pr_p: "Base prices for one character. Final price depends on details.", from: "from", popular: "Most loved", example: "example",
    p_head: "Headshot", p_head_d: "Head and shoulders, clean lines, full colour.", p_head_l: ["Simple background", "1 revision on sketch"],
    p_half: "Half body", p_half_d: "Up to the waist, expression and pose of your choice.", p_half_l: ["Simple background", "2 revisions on sketch"],
    p_full: "Full body", p_full_d: "The whole character, a dynamic pose, lighting.", p_full_l: ["Simple background", "2 revisions on sketch"],
    p_ref:  "Ref sheet", p_ref_d: "Front and back views, palette, small details.", p_ref_l: ["Colour palette", "Up to 3 detail close-ups"],
    ex_h: "Extras", ex_char: "Extra character", ex_bg: "Detailed background", ex_rush: "Rush (within a week)", ex_nsfw: "NSFW: not available",
    tos_h: "Terms of service", tos_p: "By ordering you agree to these terms. Please read before writing to me.",
    tos: [
      { q: "Payment", a: ["Full payment upfront, or 50% before the sketch and 50% before colouring.", "PayPal, card or crypto: placeholder, edit me.", "Prices are final once the sketch is approved."] },
      { q: "Timeframe", a: ["Usually 1 to 3 weeks, depending on the queue.", "I post progress updates in the queue above.", "Rush orders are possible for an extra fee."] },
      { q: "Rights and usage", a: ["You may use the art for personal use: avatars, banners, prints for yourself.", "Commercial use only by agreement.", "I may post the art in my portfolio and on social media."] },
      { q: "Refunds", a: ["Full refund before I start the sketch.", "50% refund after the sketch is approved.", "No refund once colouring has started."] },
      { cols: true, q: "What I draw / don't draw", yes: ["Furries, anthro, feral", "Cute creatures and OCs", "Fantasy, cosmic themes"], no: ["NSFW, gore", "Hate symbols", "Complex mecha"], yes_h: "Happy to draw", no_h: "Won't draw" }
    ],
    ln_h: "Links", ln_p: "Find me here. For commissions, Telegram or email is fastest.",
    foot: "Made with a little fire, thank you for stopping by", to_top: "Back to top",
    pt_h: "Where to?", pt_p: "Pick a page. Everything about commissions is one tap away.", pt_portfolio: "Recent pieces and old favourites", pt_queue: "See where your order is", pt_prices: "Headshots, half body, full body, ref sheets", pt_tos: "Payment, timing, rights", pt_rules: "sections", pt_links: "Telegram, VGen, FurAffinity and more", back_home: "Home"
  },
  ru: {
    tagline: 'цифровой художник · <b>комиссии открыты</b>', tagline_closed: 'цифровой художник · <b>комиссии закрыты</b>',
    badge_open: "Комиссии открыты", badge_closed: "Комиссии закрыты",
    cta_prices: "Цены", cta_contact: "Написать мне", scroll: "вниз",
    nav_portfolio: "Работы", nav_queue: "Очередь", nav_prices: "Цены", nav_tos: "Правила", nav_links: "Ссылки",
    pf_h: "Работы", pf_p: "Несколько свежих работ. Нажмите, чтобы рассмотреть.", ph_art: "скоро здесь будет работа",
    q_h: "Очередь", q_p: "Где сейчас ваш заказ.", slots_free: "свободных мест", q_empty: "Очередь пуста. Самое время заказать!",
    st_waiting: "Ждёт", st_sketch: "Скетч", st_coloring: "Покрас", st_done: "Готово",
    pr_h: "Цены", pr_p: "Базовые цены за одного персонажа. Итог зависит от деталей.", from: "от", popular: "Любимое", example: "пример",
    p_head: "Портрет", p_head_d: "Голова и плечи, чистый лайн, цвет.", p_head_l: ["Простой фон", "1 правка на скетче"],
    p_half: "По пояс", p_half_d: "До пояса, эмоция и поза на ваш выбор.", p_half_l: ["Простой фон", "2 правки на скетче"],
    p_full: "В полный рост", p_full_d: "Персонаж целиком, динамичная поза, свет.", p_full_l: ["Простой фон", "2 правки на скетче"],
    p_ref:  "Реф-лист", p_ref_d: "Вид спереди и сзади, палитра, детали.", p_ref_l: ["Палитра", "До 3 крупных деталей"],
    ex_h: "Дополнительно", ex_char: "Ещё персонаж", ex_bg: "Детальный фон", ex_rush: "Срочно (за неделю)", ex_nsfw: "NSFW: не рисую",
    tos_h: "Правила", tos_p: "Заказывая, вы соглашаетесь с правилами. Прочитайте перед тем, как написать.",
    tos: [
      { q: "Оплата", a: ["Полная предоплата или 50% до скетча и 50% до покраса.", "PayPal, карта или крипта: заглушка, поменяйте.", "Цена фиксируется после утверждения скетча."] },
      { q: "Сроки", a: ["Обычно от 1 до 3 недель, зависит от очереди.", "Прогресс видно в очереди выше.", "Срочный заказ возможен за доплату."] },
      { q: "Права и использование", a: ["Можно использовать для себя: аватарки, баннеры, печать для себя.", "Коммерческое использование только по договорённости.", "Я могу выкладывать работу в портфолио и соцсети."] },
      { q: "Возврат", a: ["Полный возврат до начала скетча.", "50% после утверждения скетча.", "После начала покраса возврата нет."] },
      { cols: true, q: "Что рисую / не рисую", yes: ["Фурри, антро, ферал", "Милые существа и OC", "Фэнтези, космос"], no: ["NSFW, гор", "Символику ненависти", "Сложную технику"], yes_h: "Рисую", no_h: "Не рисую" }
    ],
    ln_h: "Ссылки", ln_p: "Где меня найти. Для заказов быстрее всего Telegram или почта.",
    foot: "Сделано с огоньком, спасибо, что заглянули", to_top: "Наверх",
    pt_h: "Куда дальше?", pt_p: "Выберите страницу. Всё о заказах в одно касание.", pt_portfolio: "Свежие работы и любимые старые", pt_queue: "Где сейчас ваш заказ", pt_prices: "Портрет, по пояс, в полный рост, реф", pt_tos: "Оплата, сроки, права", pt_rules: "разделов", pt_links: "Telegram, VGen, FurAffinity и другие", back_home: "Главная"
  }
};
