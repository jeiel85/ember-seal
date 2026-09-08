extends Node
## GameState — 파티/인벤토리/플래그/진행도 등 게임의 모든 상태.
## 씬이 바뀌어도 유지되는 단일 진실 공급원(single source of truth).

signal gold_changed
signal inventory_changed
signal party_changed

var gold: int = 0
var stage: int = 0            # 스토리 진행 단계 (0=프롤로그)
var flags: Dictionary = {}    # 스토리/퀘스트 플래그
var party: Array = []         # 멤버 인스턴스 배열
var inventory: Dictionary = {}# {item_id: count}
var opened_chests: Dictionary = {}   # {map_id: [인덱스...]}
var defeated_field_enemies: Dictionary = {}  # {map_id: [인덱스...]}
var current_map: String = ""
var player_pos: Vector2i = Vector2i.ZERO
var player_dir: String = "down"
var play_time: float = 0.0
var battles_won: int = 0
var objective: String = ""
var resume_actions: Array = []  # 전투 후 이어서 실행할 액션 (저장하지 않음)

# 멤버 인스턴스 생성
func make_member(id: String, level: int = 1) -> Dictionary:
	var m := {
		"id": id,
		"level": level,
		"exp": DB.exp_for_level(level),
		"hp": 1,
		"equips": {"weapon": "", "armor": "", "trinket": ""},
	}
	m["hp"] = max_hp(m)
	return m

# ---------------------------------------------------------------- 스탯 계산

func _grown(m: Dictionary, key: String) -> int:
	var c := DB.char(m["id"])
	var base := int(c.get("base", {}).get(key, 0))
	var growth := float(c.get("growth", {}).get(key, 0))
	return base + int(round(growth * (int(m["level"]) - 1)))

func _equip_bonus(m: Dictionary, key: String) -> int:
	var total := 0
	for slot in ["weapon", "armor", "trinket"]:
		var eid: String = m["equips"].get(slot, "")
		if eid != "":
			total += int(DB.equip(eid).get(key, 0))
	return total

func max_hp(m: Dictionary) -> int:
	return _grown(m, "hp") + _equip_bonus(m, "hp")

func atk(m: Dictionary) -> int:
	return _grown(m, "atk") + _equip_bonus(m, "atk")

func def_(m: Dictionary) -> int:
	return _grown(m, "def") + _equip_bonus(m, "def")

func mov(m: Dictionary) -> int:
	return _grown(m, "mov") + _equip_bonus(m, "mov")

func rng(m: Dictionary) -> int:
	return _grown(m, "rng") + _equip_bonus(m, "rng")

func name_of(m: Dictionary) -> String:
	return DB.char(m["id"]).get("name", m["id"])

func known_skills(m: Dictionary) -> Array:
	var out: Array = []
	var sk: Dictionary = DB.char(m["id"]).get("skills", {})
	for lv_s in sk:
		if int(m["level"]) >= int(lv_s):
			out.append(sk[lv_s])
	return out

# ---------------------------------------------------------------- 파티 조작

func new_game() -> void:
	gold = 120
	stage = 0
	flags = {}
	party = [make_member("rune")]
	party[0]["equips"]["weapon"] = "w_old_sword"
	party[0]["equips"]["armor"] = "a_travel_clothes"
	inventory = {"potion": 3}
	opened_chests = {}
	defeated_field_enemies = {}
	current_map = ""
	player_pos = Vector2i.ZERO
	player_dir = "down"
	play_time = 0.0
	battles_won = 0
	party_changed.emit()

func add_member(id: String, level: int = 1) -> void:
	for m in party:
		if m["id"] == id:
			return
	party.append(make_member(id, level))
	party_changed.emit()

func member(id: String) -> Dictionary:
	for m in party:
		if m["id"] == id:
			return m
	return {}

func has_member(id: String) -> bool:
	return member(id).size() > 0

func alive_members() -> Array:
	var out: Array = []
	for m in party:
		if int(m["hp"]) > 0:
			out.append(m)
	return out

func full_heal() -> void:
	for m in party:
		m["hp"] = max_hp(m)
	party_changed.emit()

# 경험치 → 레벨업. 반환: 레벨업한 멤버 이름 배열
func gain_exp(m: Dictionary, amount: int) -> Array:
	var leveled: Array = []
	if int(m["level"]) >= DB.max_level():
		return leveled
	m["exp"] = int(m["exp"]) + amount
	while int(m["level"]) < DB.max_level() and int(m["exp"]) >= DB.exp_for_level(int(m["level"]) + 1):
		var before := max_hp(m)
		m["level"] = int(m["level"]) + 1
		var gained := max_hp(m) - before
		m["hp"] = mini(int(m["hp"]) + gained, max_hp(m))
		leveled.append(name_of(m))
	party_changed.emit()
	return leveled

# ---------------------------------------------------------------- 아이템/골드

func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()

func remove_item(id: String, count: int = 1) -> bool:
	if int(inventory.get(id, 0)) < count:
		return false
	inventory[id] = int(inventory[id]) - count
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit()

# ---------------------------------------------------------------- 장비

func equip_item(m: Dictionary, equip_id: String) -> String:
	var e := DB.equip(equip_id)
	if e.is_empty():
		return ""
	var slot: String = e["slot"]
	var old: String = m["equips"].get(slot, "")
	m["equips"][slot] = equip_id
	m["hp"] = mini(int(m["hp"]), max_hp(m))
	party_changed.emit()
	return old

func unequip(m: Dictionary, slot: String) -> String:
	var old: String = m["equips"].get(slot, "")
	if old != "":
		m["equips"][slot] = ""
		m["hp"] = mini(int(m["hp"]), max_hp(m))
		party_changed.emit()
	return old

# ---------------------------------------------------------------- 플래그/진행

func set_flag(f: String, v: bool = true) -> void:
	flags[f] = v

func has_flag(f: String) -> bool:
	return flags.get(f, false) == true

func flag_value(f: String, def_v = null):
	return flags.get(f, def_v)

func set_stage(s: int) -> void:
	stage = s

# ---------------------------------------------------------------- 직렬화

func to_dict() -> Dictionary:
	var pl: Array = []
	for m in party:
		pl.append({
			"id": m["id"], "level": m["level"], "exp": m["exp"], "hp": m["hp"],
			"equips": m["equips"].duplicate(),
		})
	return {
		"gold": gold, "stage": stage, "flags": flags.duplicate(),
		"party": pl, "inventory": inventory.duplicate(),
		"opened_chests": opened_chests.duplicate(true),
		"defeated_field_enemies": defeated_field_enemies.duplicate(true),
		"current_map": current_map,
		"player_pos": [player_pos.x, player_pos.y],
		"player_dir": player_dir,
		"play_time": play_time,
		"battles_won": battles_won,
		"objective": objective,
	}

func from_dict(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	stage = int(d.get("stage", 0))
	flags = d.get("flags", {}).duplicate()
	party = []
	for pm in d.get("party", []):
		var m := make_member(pm["id"], int(pm["level"]))
		m["exp"] = int(pm.get("exp", 0))
		m["hp"] = int(pm.get("hp", max_hp(m)))
		var eq: Dictionary = pm.get("equips", {})
		m["equips"] = {"weapon": eq.get("weapon", ""), "armor": eq.get("armor", ""), "trinket": eq.get("trinket", "")}
		party.append(m)
	inventory = d.get("inventory", {}).duplicate()
	opened_chests = d.get("opened_chests", {}).duplicate(true)
	defeated_field_enemies = d.get("defeated_field_enemies", {}).duplicate(true)
	current_map = d.get("current_map", "")
	var pp: Array = d.get("player_pos", [0, 0])
	player_pos = Vector2i(int(pp[0]), int(pp[1]))
	player_dir = d.get("player_dir", "down")
	play_time = float(d.get("play_time", 0.0))
	battles_won = int(d.get("battles_won", 0))
	objective = d.get("objective", "")
	resume_actions = []
	party_changed.emit()
