extends Node
## DB — data/*.json 을 로드해 전역에서 조회하는 데이터 저장소.
## 모든 캐릭터/스킬/아이템/장비/적/맵/전투 정의는 코드가 아닌 JSON에 둔다.

var characters: Dictionary = {}
var skills: Dictionary = {}
var items: Dictionary = {}
var equipment: Dictionary = {}
var enemies: Dictionary = {}
var levels: Dictionary = {}
var maps: Dictionary = {}
var battles: Dictionary = {}
var shops: Dictionary = {}
var texts: Dictionary = {}

func _ready() -> void:
	characters = _load("res://data/characters.json")
	skills = _load("res://data/skills.json")
	items = _load("res://data/items.json")
	equipment = _load("res://data/equipment.json")
	enemies = _load("res://data/enemies.json")
	levels = _load("res://data/levels.json")
	shops = _load("res://data/shops.json")
	texts = _load("res://data/texts.json")
	for f in _list_dir("res://data/maps"):
		var m: Dictionary = _load("res://data/maps/" + f)
		if not m.is_empty() and m.has("id"):
			maps[m["id"]] = m
	for f in _list_dir("res://data/battles"):
		var b: Dictionary = _load("res://data/battles/" + f)
		if not b.is_empty() and b.has("id"):
			battles[b["id"]] = b

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DB: 파일 없음 " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("DB: JSON 파싱 실패 " + path)
	return {}

func _list_dir(path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(".json"):
			out.append(fname)
		fname = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func char(id: String) -> Dictionary:
	return characters.get(id, {})

func skill(id: String) -> Dictionary:
	return skills.get(id, {})

func item(id: String) -> Dictionary:
	return items.get(id, {})

func equip(id: String) -> Dictionary:
	return equipment.get(id, {})

func enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func map(id: String) -> Dictionary:
	return maps.get(id, {})

func battle(id: String) -> Dictionary:
	return battles.get(id, {})

func shop(id: String) -> Dictionary:
	return shops.get(id, {})

func exp_for_level(lv: int) -> int:
	var table: Array = levels.get("exp_table", [0, 30, 70, 120, 180, 250, 330, 420, 520, 630])
	if lv < 1:
		return 0
	if lv - 1 >= table.size():
		return int(table[table.size() - 1])
	return int(table[lv - 1])

func max_level() -> int:
	return int(levels.get("max_level", 10))
