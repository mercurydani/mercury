class_name LocationTexts
extends RefCounted
## Тексты локаций миссий (RU/EN), добавляются к Texts.register() из лобби.

const DATA := {
	"ru": {
		"LOC_ROOF": "Верхотура",
		"LOC_DIFFICULTY": "Сложность: %s",
		"DIFF_0": "простая",
		"DIFF_1": "средняя",
		"DIFF_2": "сложная",
		"PROMPT_RESCUE": "Спасти кота",
		"MSG_RESCUED": "Кот спасён! Мурзик тебя не забудет",
		"MSG_FELL": "ЛЕТИ-И-И-И! Возвращаемся на чекпоинт",
		"MSG_WIND_SOON": "Ветер крепчает, держись!",
		"MSG_WIND": "Порыв ветра!",
		"MSG_PIGEON": "Голубь-хулиган! Гу-гу-гу!",
		"MSG_FAN": "Крышный вентилятор: лопасти!",
		"MSG_SLIPPERY": "Мокрый шифер скользит!",
		"MSG_CHECKPOINT_ROOF": "Чекпоинт! [R] — вернуться сюда",
		"SIGN_EXIT": "ВЫХОД НА КРЫШУ\nЗАКРЫТ",
		"SIGN_WINDOWS": "ОКНА ПВХ\nдёшево и быстро",
		"SIGN_PHONE": "8-800-000-00-00",
		"SIGN_PELMENI": "ПЕЛЬМЕНИ «ДОМАШНИЕ»",
		"SIGN_BLADES": "ОСТОРОЖНО!\nЛОПАСТИ",
		"SIGN_MEAT": "МЯСО · РЫБА",
		"SIGN_SHOP": "ПРОДУКТЫ 24",
		"SIGN_NO_ENTRY": "НЕ ХОДИТЬ!\nКРЫША ПРОТЕКАЕТ",
		"CAT_MEOW": "Мяу!?",
		"LOC_FOREST": "Нора у ручья",
		"MSG_DROWNED": "Булька! Утиный круг вынес тебя обратно на чекпоинт",
		"MSG_SQUIRREL": "Белка-хулиганка кидается шишками!",
		"MSG_TRAP": "ЩЁЛК! Ложная тревога, капкан игрушечный",
		"SIGN_RAVINE": "ОВРАГ\nКупаться запрещено",
		"SIGN_CAMP": "Турбаза «Берёзка»\n2 км",
		"SIGN_HUNT": "ВНИМАНИЕ!\nОхотничьи угодья",
		"SIGN_MUSHROOM": "Грибы не рвать,\nтолько срезать!",
	},
	"en": {
		"LOC_ROOF": "The Rooftop",
		"LOC_DIFFICULTY": "Difficulty: %s",
		"DIFF_0": "easy",
		"DIFF_1": "medium",
		"DIFF_2": "hard",
		"PROMPT_RESCUE": "Rescue the cat",
		"MSG_RESCUED": "Cat rescued! Murzik will never forget you",
		"MSG_FELL": "WHEEEE! Back to the checkpoint",
		"MSG_WIND_SOON": "The wind is picking up, hold on!",
		"MSG_WIND": "Wind gust!",
		"MSG_PIGEON": "Hooligan pigeon! Coo-coo-coo!",
		"MSG_FAN": "Roof fan: blades!",
		"MSG_SLIPPERY": "Wet slate is slippery!",
		"MSG_CHECKPOINT_ROOF": "Checkpoint! [R] to return here",
		"SIGN_EXIT": "ROOF ACCESS\nCLOSED",
		"SIGN_WINDOWS": "PVC WINDOWS\ncheap and fast",
		"SIGN_PHONE": "8-800-000-00-00",
		"SIGN_PELMENI": "\"HOMEMADE\" DUMPLINGS",
		"SIGN_BLADES": "DANGER!\nBLADES",
		"SIGN_MEAT": "MEAT · FISH",
		"SIGN_SHOP": "GROCERIES 24",
		"SIGN_NO_ENTRY": "KEEP OFF!\nROOF LEAKS",
		"CAT_MEOW": "Meow!?",
		"LOC_FOREST": "The Creek Burrow",
		"MSG_DROWNED": "Blub! A duck ring floated you back to the checkpoint",
		"MSG_SQUIRREL": "A hooligan squirrel throws cones!",
		"MSG_TRAP": "SNAP! False alarm, the trap is a toy",
		"SIGN_RAVINE": "RAVINE\nNo swimming",
		"SIGN_CAMP": "Birch Lodge\n2 km",
		"SIGN_HUNT": "ATTENTION!\nHunting grounds",
		"SIGN_MUSHROOM": "Don't pull mushrooms,\nonly cut them!",
	},
}


static func register() -> void:
	for locale in DATA:
		var tr_res := Translation.new()
		tr_res.locale = locale
		for key in DATA[locale]:
			tr_res.add_message(key, DATA[locale][key])
		TranslationServer.add_translation(tr_res)
