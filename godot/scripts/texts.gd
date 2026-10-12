class_name Texts
extends RefCounted
## Локализация лобби (RU/EN). Ключи используются через tr().
## Позже можно перенести в CSV/PO; пока словарь, чтобы не зависеть от импорта в редакторе.

const DATA := {
	"ru": {
		"PROMPT_SIT": "Сесть в фургон",
		"VAN_LABEL": "МЯУ-СПАСАТЕЛИ",
		"PROMPT_STAND": "Встать с места",
		"PROMPT_SEARCH": "Поиск вызовов",
		"PROMPT_SHOP": "Ларёк баб Нюры",
		"PROMPT_SLOT": "Мяу-Джекпот",
		"PROMPT_PET": "Погладить кота-талисмана",
		"PROMPT_TOOLS": "Стена инструментов",
		"HINT_INTERACT": "[E] %s",
		"MSG_WAITING": "Ждём: %s",
		"MSG_SEARCH_START": "Ищем котиков в беде...",
		"MSG_NEED_SEAT": "Сначала сядь в фургон",
		"MSG_SHOP_STUB": "Баб Нюра: Носи на здоровье, внучок, а кота спасай!",
		"MSG_SLOT_STUB": "Автомат гремит... (заглушка)",
		"MSG_PET": "Мур! Удача +%s%%",
		"MSG_TOOLS_STUB": "Здесь будут висеть купленные инструменты (заглушка)",
		"HUD_MONEY": "Мяудоллары: %d",
		"MSG_CHECKPOINT": "Чекпоинт %d! [R] — вернуться сюда",
		"MSG_PRIZE": "Достижение: Покоритель крыши! Подушка студии твоя",
	},
	"en": {
		"PROMPT_SIT": "Sit in the van",
		"VAN_LABEL": "MEOW RESCUE",
		"PROMPT_STAND": "Leave the seat",
		"PROMPT_SEARCH": "Search for calls",
		"PROMPT_SHOP": "Granny Nyura's stall",
		"PROMPT_SLOT": "Meow Jackpot",
		"PROMPT_PET": "Pet the lucky cat",
		"PROMPT_TOOLS": "Tool wall",
		"HINT_INTERACT": "[E] %s",
		"MSG_WAITING": "Waiting for: %s",
		"MSG_SEARCH_START": "Searching for cats in trouble...",
		"MSG_NEED_SEAT": "Take a seat in the van first",
		"MSG_SHOP_STUB": "Granny Nyura: Wear it in good health, dear, and rescue that cat!",
		"MSG_SLOT_STUB": "The machine rattles... (stub)",
		"MSG_PET": "Purr! Luck +%s%%",
		"MSG_TOOLS_STUB": "Your bought tools will hang here (stub)",
		"HUD_MONEY": "Meow dollars: %d",
		"MSG_CHECKPOINT": "Checkpoint %d! [R] to return here",
		"MSG_PRIZE": "Achievement: Rooftop Conqueror! The studio pillow is yours",
	},
}


static func register() -> void:
	for locale in DATA:
		var tr_res := Translation.new()
		tr_res.locale = locale
		for key in DATA[locale]:
			tr_res.add_message(key, DATA[locale][key])
		TranslationServer.add_translation(tr_res)
	var sys := OS.get_locale_language()
	TranslationServer.set_locale("ru" if sys == "ru" else "en")
