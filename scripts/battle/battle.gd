class_name Battle
extends Node2D
## Battle — 타일 기반 턴제 전술 전투.
## 이동범위/공격범위 표시, 예상 피해, 행동 취소, 턴 종료, 적 AI, 승패 처리.

static var pending_battle_id := ""
static var pending_context := {}  # {"map": String, "fe_idx": int}

const TS := 32          # 전투 타일 화면 크기 (16px 아트 × 2)
const DIRS4 := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

enum St { INTRO, SELECT, MOVE, ACTION, SKILL, ITEM, TARGET, ANIM, ENEMY, END }

var bdef: Dictionary = {}
var W := 0
var H := 0
var blocked := {}
var origin := Vector2i.ZERO
var units: Array = []
var turn := 1
var st: int = St.INTRO
var cursor := Vector2i.ZERO
var sel := {}
var sel_origin := Vector2i.ZERO
var move_range := {}
var targets: Array = []
var tsel := 0
var action_opts: Array = []
var action_idx := 0
var list_items: Array = []
var list_idx := 0
var cur_action := ""
var pending_skill := ""
var pending_item := ""
var battle_exp := 0

var world: Node2D
var hl_root: Node2D
var cursor_node: Node2D
var _white: ImageTexture
var _cursor_t := 0.0

var ui: CanvasLayer
var info_name: Label
var info_sub: Label
var info_hp_bar: Control
var info_hp_text: Label
var forecast_label: Label
var turn_label: Label
var objective_label: Label
var banner: Label
var action_panel: PanelContainer
var action_box: VBoxContainer
var hint_label: Label

func _ready() -> void:
	bdef = DB.battle(pending_battle_id)
	if bdef.is_empty():
		push_error("전투 정의 없음: " + pending_battle_id)
		Events.battle_finished.emit("win")
		return
	# 어두운 배경
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Color("0c0a14")
	bg.size = Vector2(640, 360)
	bg_layer.add_child(bg)
	add_child(bg_layer)
	_white = _make_white()
	_build_map()
	_spawn_units()
	_build_ui()
	Audio.play_bgm(bdef.get("bgm", "battle"))
	_intro()

# ---------------------------------------------------------------- 구축

func _make_white() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _build_map() -> void:
	world = Node2D.new()
	add_child(world)
	var rows: Array = bdef["tiles"]
	H = rows.size()
	W = (rows[0] as String).length()
	var tmap: Dictionary = bdef["tilemap"]
	var bchars: String = bdef.get("blocked", "")
	for y in H:
		var row: String = rows[y]
		for x in W:
			var ch := row[x]
			var s := Sprite2D.new()
			s.texture = PixelArt.tile_texture(tmap.get(ch, "grass"))
			s.centered = false
			s.scale = Vector2(2, 2)
			s.position = Vector2(x * TS, y * TS)
			world.add_child(s)
			if bchars.contains(ch):
				blocked[Vector2i(x, y)] = true
	# 격자선
	var grid := Node2D.new()
	grid.z_index = 5
	grid.draw.connect(func() -> void:
		var c := Color(1, 1, 1, 0.07)
		for x in W + 1:
			grid.draw_line(Vector2(x * TS, 0), Vector2(x * TS, H * TS), c, 1.0)
		for y in H + 1:
			grid.draw_line(Vector2(0, y * TS), Vector2(W * TS, y * TS), c, 1.0)
	)
	world.add_child(grid)
	hl_root = Node2D.new()
	hl_root.z_index = 6
	world.add_child(hl_root)
	origin = Vector2i(int((640 - W * TS) / 2.0), int((360 - H * TS) / 2.0))
	world.position = Vector2(origin)
	cursor_node = Node2D.new()
	cursor_node.z_index = 20
	cursor_node.draw.connect(func() -> void:
		cursor_node.draw_rect(Rect2(2, 2, TS - 4, TS - 4), Color(1, 1, 1, 0.9), false, 2.0)
	)
	world.add_child(cursor_node)

func _spawn_units() -> void:
	var spawns: Array = bdef.get("player_spawns", [])
	var i := 0
	for m in GameState.party:
		if i >= spawns.size():
			break
		var u := _make_player_unit(m, Vector2i(int(spawns[i][0]), int(spawns[i][1])))
		units.append(u)
		_make_unit_node(u)
		i += 1
	for e in bdef.get("enemies", []):
		var edef: Dictionary = DB.enemy(e["enemy"])
		var u := _make_enemy_unit(edef, Vector2i(int(e["x"]), int(e["y"])))
		units.append(u)
		_make_unit_node(u)

func _make_player_unit(m: Dictionary, spawn: Vector2i) -> Dictionary:
	return {
		"side": "p", "member": m, "grid": spawn,
		"name": GameState.name_of(m), "lv": int(m["level"]),
		"hp": int(m["hp"]), "max_hp": GameState.max_hp(m),
		"atk": GameState.atk(m), "def": GameState.def_(m),
		"mov": GameState.mov(m), "rng": GameState.rng(m),
		"skills": GameState.known_skills(m), "skill_uses": {},
		"done": false, "poison": 0, "sprite_kind": "char",
		"palette": DB.char(m["id"])["palette"],
	}

func _make_enemy_unit(edef: Dictionary, spawn: Vector2i) -> Dictionary:
	return {
		"side": "e", "edef": edef, "grid": spawn,
		"name": edef["name"], "lv": 0,
		"hp": int(edef["hp"]), "max_hp": int(edef["hp"]),
		"atk": int(edef["atk"]), "def": int(edef["def"]),
		"mov": int(edef["mov"]), "rng": int(edef["rng"]),
		"skills": ([edef["skill"]] if edef.has("skill") else []), "skill_uses": {},
		"done": false, "poison": 0, "sprite_kind": edef["sprite"],
		"exp": int(edef.get("exp", 0)), "gold": int(edef.get("gold", 0)),
		"boss": bool(edef.get("boss", false)), "actions": int(edef.get("actions", 1)),
		"ai": edef.get("ai", "melee"), "poison_chance": int(edef.get("poison_chance", 0)),
	}

func _make_unit_node(u: Dictionary) -> void:
	var n := Node2D.new()
	n.z_index = 10 + u["grid"].y
	var spr := Node2D.new()
	n.add_child(spr)
	if u["sprite_kind"] == "char":
		var a := AnimatedSprite2D.new()
		a.sprite_frames = PixelArt.make_sprite_frames(u["palette"])
		a.scale = Vector2(2, 2)
		a.position = Vector2(0, -TS + 16)
		a.play("idle_down")
		spr.add_child(a)
		u["anim"] = a
	else:
		var s := Sprite2D.new()
		s.texture = PixelArt.enemy_texture(u["sprite_kind"])
		s.scale = Vector2(2, 2)
		var sz := int(PixelArt.enemy_size(u["sprite_kind"])) * 2
		s.position = Vector2(0, -sz / 2.0)
		spr.add_child(s)
	# HP 바
	var bar := Node2D.new()
	bar.position = Vector2(-14, -TS - 6 if u["sprite_kind"] == "char" else -int(PixelArt.enemy_size(u["sprite_kind"])) * 2 - 6)
	n.add_child(bar)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.size = Vector2(28, 4)
	bg.position = Vector2(-1, -1)
	bar.add_child(bg)
	var fill := ColorRect.new()
	fill.size = Vector2(28, 4)
	bar.add_child(fill)
	u["node"] = n
	u["bar_fill"] = fill
	u["spr"] = spr
	_update_bar(u)
	n.position = _grid_px(u["grid"])
	world.add_child(n)

func _grid_px(g: Vector2i) -> Vector2:
	return Vector2(g.x * TS + TS / 2.0, g.y * TS + TS)

func _update_bar(u: Dictionary) -> void:
	var ratio := float(u["hp"]) / maxf(1.0, float(u["max_hp"]))
	var fill: ColorRect = u["bar_fill"]
	fill.size = Vector2(maxi(0, int(28 * ratio)), 4)
	fill.color = UIKit.COL_HP if ratio > 0.3 else UIKit.COL_HP_LOW

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	turn_label = UIKit.label("", 12, Color("fff3b0"))
	turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	turn_label.add_theme_constant_override("outline_size", 3)
	turn_label.position = Vector2(8, 6)
	root.add_child(turn_label)

	objective_label = UIKit.label("", 11, UIKit.COL_DIM)
	objective_label.anchor_left = 1.0
	objective_label.anchor_right = 1.0
	objective_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	objective_label.position = Vector2(-8, 6)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(objective_label)
	var obj: String = DB.texts.get("objective_defeat_all", "목표: 적을 모두 쓰러뜨려라")
	if bdef.get("objective", "") == "boss":
		obj = DB.texts.get("objective_boss", "목표: 보스를 쓰러뜨려라")
	objective_label.text = obj

	banner = UIKit.label("", 22, Color("ffc857"))
	banner.add_theme_color_override("font_outline_color", Color("3a1a08"))
	banner.add_theme_constant_override("outline_size", 5)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.anchor_top = 0.32
	banner.anchor_bottom = 0.32
	banner.visible = false
	root.add_child(banner)

	# 하단 정보 패널
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UIKit.panel_style())
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.anchor_left = 0.0
	info.anchor_right = 1.0
	info.offset_top = -66
	info.offset_bottom = -4
	info.offset_left = 4
	info.offset_right = -4
	root.add_child(info)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	info.add_child(hb)
	var vb1 := VBoxContainer.new()
	vb1.custom_minimum_size = Vector2(190, 0)
	hb.add_child(vb1)
	info_name = UIKit.label("", 12, UIKit.COL_ACCENT)
	vb1.add_child(info_name)
	info_sub = UIKit.label("", 10)
	vb1.add_child(info_sub)
	var vb2 := VBoxContainer.new()
	vb2.custom_minimum_size = Vector2(150, 0)
	hb.add_child(vb2)
	info_hp_bar = UIKit.hp_bar(120, 8, 1.0)
	vb2.add_child(info_hp_bar)
	info_hp_text = UIKit.label("", 10)
	vb2.add_child(info_hp_text)
	var vb3 := VBoxContainer.new()
	vb3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb3)
	forecast_label = UIKit.label("", 11, Color("fff3b0"))
	vb3.add_child(forecast_label)
	hint_label = UIKit.label("", 10, UIKit.COL_DIM)
	vb3.add_child(hint_label)

	# 액션 메뉴
	action_panel = PanelContainer.new()
	action_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	action_panel.anchor_left = 1.0
	action_panel.anchor_right = 1.0
	action_panel.anchor_top = 1.0
	action_panel.anchor_bottom = 1.0
	action_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	action_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	action_panel.offset_left = -150
	action_panel.offset_right = -6
	action_panel.offset_top = -190
	action_panel.offset_bottom = -72
	action_panel.visible = false
	root.add_child(action_panel)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 2)
	action_panel.add_child(action_box)

func _show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: banner.visible = false)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

# ---------------------------------------------------------------- 시작/페이즈

func _intro() -> void:
	st = St.INTRO
	var intro: Dictionary = bdef.get("intro", {})
	if intro.has("lines") and not (intro["lines"] as Array).is_empty():
		Events.dialog_requested.emit(intro.get("speaker", ""), intro["lines"])
		await Events.dialog_finished
	_start_player_phase()

func _alive(side: String) -> Array:
	var out: Array = []
	for u in units:
		if u["side"] == side and int(u["hp"]) > 0:
			out.append(u)
	return out

func _start_player_phase() -> void:
	turn_label.text = "Turn %d · 아군 턴" % turn
	_show_banner("아군 턴")
	# 독 틱
	for u in _alive("p"):
		if int(u["poison"]) > 0:
			_poison_tick(u)
	if _alive("p").is_empty():
		_defeat()
		return
	for u in units:
		if u["side"] == "p":
			u["done"] = false
			if int(u["hp"]) > 0:
				u["node"].modulate = Color.WHITE
	st = St.SELECT
	_clear_hl()
	var first := _alive("p")
	if not first.is_empty():
		cursor = first[0]["grid"]
	cursor_node.position = Vector2(cursor.x * TS, cursor.y * TS)
	_update_info()

func _end_player_turn() -> void:
	_enemy_phase()

func _enemy_phase() -> void:
	st = St.ENEMY
	_clear_hl()
	_close_action_menu()
	sel = {}
	turn_label.text = "Turn %d · 적 턴" % turn
	_show_banner("적 턴")
	await _wait(0.5)
	for u in _alive("e"):
		if int(u["poison"]) > 0:
			_poison_tick(u)
	await _wait(0.2)
	for u in _alive("e"):
		for i in int(u.get("actions", 1)):
			if int(u["hp"]) <= 0 or _alive("p").is_empty():
				break
			await _ai_act(u)
			await _wait(0.15)
	if _alive("p").is_empty():
		_defeat()
		return
	turn += 1
	_start_player_phase()

# ---------------------------------------------------------------- 이동/범위

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H

func _unit_at(p: Vector2i) -> Variant:
	for u in units:
		if int(u["hp"]) > 0 and u["grid"] == p:
			return u
	return null

func _mdist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func reachable(u: Dictionary) -> Dictionary:
	var out := {}
	var frontier: Array = [[u["grid"], int(u["mov"])]]
	out[u["grid"]] = true
	while not frontier.is_empty():
		var cur: Array = frontier.pop_front()
		var p: Vector2i = cur[0]
		var r: int = cur[1]
		if r <= 0:
			continue
		for d in DIRS4:
			var np: Vector2i = p + d
			if not _in_bounds(np) or blocked.has(np) or out.has(np):
				continue
			var occ = _unit_at(np)
			if occ != null and occ["side"] == "e":
				continue
			out[np] = true
			frontier.append([np, r - 1])
	for k in out.keys():
		var occ2 = _unit_at(k)
		if occ2 != null and occ2 != u:
			out.erase(k)
	return out

func _targets_from(u: Dictionary, from: Vector2i, side: String, rng: int = -1) -> Array:
	var r := int(u["rng"]) if rng < 0 else rng
	var out: Array = []
	for t in units:
		if t["side"] == side and int(t["hp"]) > 0 and _mdist(from, t["grid"]) <= r:
			out.append(t)
	return out

func _clear_hl() -> void:
	for c in hl_root.get_children():
		c.queue_free()

func _hl_tile(p: Vector2i, color: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _white
	s.centered = false
	s.scale = Vector2(2, 2)
	s.position = Vector2(p.x * TS, p.y * TS)
	s.modulate = color
	hl_root.add_child(s)

func _show_move_hl() -> void:
	_clear_hl()
	for p in move_range:
		_hl_tile(p, Color(UIKit.COL_MOVE, 0.32))

func _show_target_hl(side: String) -> void:
	_clear_hl()
	for t in targets:
		_hl_tile(t["grid"], Color(UIKit.COL_ATK if side == "e" else UIKit.COL_HEAL, 0.4))

# ---------------------------------------------------------------- 데미지/회복

func calc_damage(a: Dictionary, d: Dictionary, power: float, pierce := 0.0) -> int:
	var def_v := float(d["def"]) * (1.0 - pierce)
	var raw := (float(a["atk"]) - def_v * 0.5) * power
	return maxi(1, int(round(raw)))

func _heal_amount(u: Dictionary, skill: Dictionary) -> int:
	var heal := int(skill.get("power", 0))
	if u.has("member"):
		heal += GameState._equip_bonus(u["member"], "heal")
	return heal

func _popup(u: Dictionary, text: String, color: Color) -> void:
	var l := UIKit.label(text, 13, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 50
	l.position = _grid_px(u["grid"]) + Vector2(-10, -TS - 14)
	world.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func _flash(u: Dictionary) -> void:
	var spr: Node2D = u["spr"]
	spr.modulate = Color(1, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color.WHITE, 0.2)

func _apply_damage(a: Dictionary, d: Dictionary, power: float, pierce := 0.0, hits := 1, fixed := -1) -> void:
	for i in hits:
		if int(d["hp"]) <= 0:
			break
		var dmg := 0
		if fixed >= 0:
			dmg = fixed
		else:
			dmg = calc_damage(a, d, power, pierce)
			dmg = int(round(dmg * randf_range(0.9, 1.1)))
			if randf() < 0.05:
				dmg = int(round(dmg * 1.5))
				_popup(d, "치명타!", Color("ffd24a"))
		d["hp"] = maxi(0, int(d["hp"]) - dmg)
		_popup(d, str(dmg), Color("ff6a5a") if d["side"] == "p" else Color.WHITE)
		Audio.play_sfx("attack" if a["side"] == "p" else "hit")
		_flash(d)
		_update_bar(d)
		_update_info()
		await _wait(0.28)
		if int(d["hp"]) <= 0:
			_on_death(d, a)
	# 독 부여
	if int(d["hp"]) > 0 and int(a.get("poison_chance", 0)) > 0 and randi() % 100 < int(a["poison_chance"]):
		d["poison"] = 3
		Audio.play_sfx("poison")
		Events.notify_requested.emit("%s는 독에 걸렸다!" % d["name"])

func _poison_tick(u: Dictionary) -> void:
	u["poison"] = int(u["poison"]) - 1
	u["hp"] = maxi(0, int(u["hp"]) - 3)
	_popup(u, "독 -3", Color("9aff6a"))
	Audio.play_sfx("poison")
	_update_bar(u)
	if int(u["hp"]) <= 0:
		_on_death(u, {})

func _on_death(d: Dictionary, killer: Dictionary) -> void:
	Events.notify_requested.emit("%s 쓰러짐" % d["name"])
	var spr: Node2D = d["spr"]
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.15, 0.4)
	if d["side"] == "e":
		battle_exp += int(d.get("exp", 0))
		if killer.has("side") and killer["side"] == "p":
			_give_exp(killer, int(d.get("exp", 0)))
		# 나머지 아군에게 절반 공유 — 파티 레벨 편차 방지
		for u in _alive("p"):
			if u != killer:
				_give_exp(u, int(int(d.get("exp", 0)) * 0.5))
		if int(d.get("gold", 0)) > 0:
			GameState.add_gold(int(d["gold"]))
	else:
		var bar: Node2D = d["node"]
		bar.modulate = Color(1, 1, 1, 0.4)

func _give_exp(u: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var leveled: Array = GameState.gain_exp(u["member"], amount)
	Events.notify_requested.emit("%s EXP +%d" % [u["name"], amount])
	u["lv"] = int(u["member"]["level"])
	for nm in leveled:
		Audio.play_sfx("levelup")
		Events.notify_requested.emit("%s 레벨 업! (Lv%d)" % [nm, int(u["member"]["level"])])
		for sk in GameState.known_skills(u["member"]):
			if not (u["skills"] as Array).has(sk):
				u["skills"].append(sk)
				Events.notify_requested.emit("%s 스킬 습득: %s" % [nm, DB.skill(sk).get("name", sk)])

# ---------------------------------------------------------------- 유닛 이동/액션 실행

func _move_unit(u: Dictionary, to: Vector2i) -> void:
	u["grid"] = to
	var n: Node2D = u["node"]
	n.z_index = 10 + to.y
	var tw := create_tween()
	tw.tween_property(n, "position", _grid_px(to), 0.18)
	await tw.finished

func _exec_attack(a: Dictionary, d: Dictionary) -> void:
	st = St.ANIM
	_clear_hl()
	await _apply_damage(a, d, 1.0)

func _exec_skill(u: Dictionary, skill_id: String, target) -> void:
	st = St.ANIM
	_clear_hl()
	var sk: Dictionary = DB.skill(skill_id)
	u["skill_uses"][skill_id] = int(u["skill_uses"].get(skill_id, 0)) + 1
	Audio.play_sfx("magic")
	if sk["kind"] == "heal":
		var amount := _heal_amount(u, sk)
		if sk.has("aoe"):
			for al in _targets_from(u, u["grid"], "p", int(sk["aoe"])):
				var before := int(al["hp"])
				al["hp"] = mini(int(al["hp"]) + amount, int(al["max_hp"]))
				if sk.has("cure"):
					al["poison"] = 0
				_popup(al, "+%d" % (int(al["hp"]) - before), Color("6aff9a"))
				_update_bar(al)
			Audio.play_sfx("heal")
		else:
			var before2 := int(target["hp"])
			target["hp"] = mini(int(target["hp"]) + amount, int(target["max_hp"]))
			if sk.has("cure"):
				target["poison"] = 0
			_popup(target, "+%d" % (int(target["hp"]) - before2), Color("6aff9a"))
			Audio.play_sfx("heal")
			_update_bar(target)
	else:
		var hits := int(sk.get("hits", 1))
		for i in hits:
			if int(target["hp"]) <= 0:
				break
			await _apply_damage(u, target, float(sk.get("power", 1.0)), float(sk.get("pierce_def", 0.0)), 1)
			if hits > 1 and i < hits - 1:
				await _wait(0.12)
	await _wait(0.1)

func _exec_item(u: Dictionary, item_id: String, target) -> void:
	st = St.ANIM
	_clear_hl()
	var it: Dictionary = DB.item(item_id)
	GameState.remove_item(item_id, 1)
	match it.get("kind", ""):
		"heal":
			var before := int(target["hp"])
			target["hp"] = mini(int(target["hp"]) + int(it.get("power", 0)), int(target["max_hp"]))
			_popup(target, "+%d" % (int(target["hp"]) - before), Color("6aff9a"))
			Audio.play_sfx("heal")
			_update_bar(target)
		"revive":
			target["hp"] = int(int(target["max_hp"]) * float(it.get("power", 0.5)))
			target["spr"].modulate = Color.WHITE
			target["node"].modulate = Color.WHITE
			_popup(target, "부활!", Color("6aff9a"))
			Audio.play_sfx("heal")
			_update_bar(target)
		"cure":
			target["poison"] = 0
			_popup(target, "독 치료", Color("6aff9a"))
			Audio.play_sfx("heal")
		"damage":
			await _apply_damage(u, target, 1.0, 0.0, 1, int(it.get("power", 10)))
	await _wait(0.1)

func _finish_player_action() -> void:
	if not sel.is_empty():
		sel["done"] = true
		if int(sel["hp"]) > 0:
			sel["node"].modulate = Color(0.55, 0.55, 0.6)
	sel = {}
	_close_action_menu()
	_clear_hl()
	if _check_end():
		return
	var remaining: Array = []
	for u in _alive("p"):
		if not u["done"]:
			remaining.append(u)
	if remaining.is_empty():
		_enemy_phase()
	else:
		st = St.SELECT
		cursor = remaining[0]["grid"]
		_update_info()

func _check_end() -> bool:
	if _alive("e").is_empty():
		_victory()
		return true
	if _alive("p").is_empty():
		_defeat()
		return true
	return false

# ---------------------------------------------------------------- 승패

func _victory() -> void:
	st = St.END
	_clear_hl()
	_close_action_menu()
	Audio.play_sfx("victory")
	turn_label.text = "승리!"
	# HP 동기화 (쓰러진 멤버는 HP 1로 복귀)
	for u in units:
		if u["side"] == "p":
			u["member"]["hp"] = maxi(1, int(u["hp"]))
	GameState.battles_won += 1
	# 필드 적 제거 기록
	if pending_context.has("map") and pending_context.has("fe_idx"):
		var mid: String = pending_context["map"]
		var arr: Array = GameState.defeated_field_enemies.get(mid, []).duplicate()
		arr.append(str(int(pending_context["fe_idx"])))
		GameState.defeated_field_enemies[mid] = arr
	pending_context = {}
	await _wait(0.6)
	var outro: Dictionary = bdef.get("outro", {})
	if outro.has("lines") and not (outro["lines"] as Array).is_empty():
		Events.dialog_requested.emit(outro.get("speaker", ""), outro["lines"])
		await Events.dialog_finished
	Events.battle_finished.emit("win")

func _defeat() -> void:
	st = St.END
	_clear_hl()
	_close_action_menu()
	turn_label.text = "패배..."
	Events.battle_finished.emit("lose")

# ---------------------------------------------------------------- 적 AI

func _min_dist_to_players(from: Vector2i) -> int:
	var best := 9999
	for p in _alive("p"):
		best = mini(best, _mdist(from, p["grid"]))
	return best

func _best_target_from(u: Dictionary, from: Vector2i) -> Variant:
	var rng := int(u["rng"])
	if not (u["skills"] as Array).is_empty():
		var sk: Dictionary = DB.skill(u["skills"][0])
		rng = maxi(rng, int(sk.get("range", 1)))
	var best = null
	for p in _alive("p"):
		if _mdist(from, p["grid"]) <= rng:
			var dmg := calc_damage(u, p, 1.0)
			if best == null or dmg > int(best["dmg"]) or (dmg == int(best["dmg"]) and int(p["hp"]) < int(best["u"]["hp"])):
				best = {"u": p, "dmg": dmg}
	return best

func _ai_attack(u: Dictionary, t: Dictionary) -> void:
	if not (u["skills"] as Array).is_empty():
		var sk: Dictionary = DB.skill(u["skills"][0])
		await _exec_skill(u, u["skills"][0], t)
	else:
		await _exec_attack(u, t)

func _ai_act(u: Dictionary) -> void:
	if _alive("p").is_empty():
		return
	# 후퇴 성향: HP 낮으면 도망
	if u.get("ai", "") == "coward" and int(u["hp"]) <= int(u["max_hp"]) * 0.3:
		var reach := reachable(u)
		var best_tile: Vector2i = u["grid"]
		var best_d := _min_dist_to_players(u["grid"])
		for t in reach:
			var d := _min_dist_to_players(t)
			if d > best_d:
				best_d = d
				best_tile = t
		if best_tile != u["grid"]:
			await _move_unit(u, best_tile)
		return
	# 현재 위치에서 공격 가능한가
	var t = _best_target_from(u, u["grid"])
	if t != null:
		await _ai_attack(u, t["u"])
		return
	# 이동 후 공격 시도 / 접근
	var reach2 := reachable(u)
	var best_tile2 = null
	var best_score := -999999
	for tile in reach2:
		var bt = _best_target_from(u, tile)
		var score := 0
		var dmin := _min_dist_to_players(tile)
		if bt != null:
			score = 1000 + int(bt["dmg"]) - dmin
		else:
			score = -dmin * 10
		if score > best_score:
			best_score = score
			best_tile2 = tile
	if best_tile2 != null and best_tile2 != u["grid"]:
		await _move_unit(u, best_tile2)
	var t2 = _best_target_from(u, u["grid"])
	if t2 != null:
		await _ai_attack(u, t2["u"])

# ---------------------------------------------------------------- UI 갱신

func _update_info() -> void:
	var u = null
	if not sel.is_empty():
		u = sel
	else:
		u = _unit_at(cursor)
	if u == null:
		info_name.text = ""
		info_sub.text = ""
		info_hp_text.text = ""
		forecast_label.text = ""
		hint_label.text = "방향키: 커서  Z: 선택  Tab: 턴 종료" if st == St.SELECT else ""
		var fill: ColorRect = info_hp_bar.get_child(1)
		fill.size = Vector2(0, 8)
		return
	info_name.text = "%s%s" % [u["name"], ("  Lv%d" % u["lv"]) if u["side"] == "p" else ""]
	info_sub.text = "공격 %d   방어 %d   이동 %d   사거리 %d%s" % [
		u["atk"], u["def"], u["mov"], u["rng"], "  [행동 완료]" if u.get("done", false) else ""]
	info_hp_text.text = "HP %d / %d" % [int(u["hp"]), int(u["max_hp"])]
	var fill2: ColorRect = info_hp_bar.get_child(1)
	var ratio := float(u["hp"]) / maxf(1.0, float(u["max_hp"]))
	fill2.size = Vector2(int(120 * ratio), 8)
	fill2.color = UIKit.COL_HP if ratio > 0.3 else UIKit.COL_HP_LOW
	if int(u["poison"]) > 0:
		info_sub.text += "  [독 %d]" % int(u["poison"])

func _render_action_menu() -> void:
	for c in action_box.get_children():
		c.queue_free()
	for i in action_opts.size():
		var o: Dictionary = action_opts[i]
		var l := UIKit.label(("▶ " if i == action_idx else "  ") + o["label"], 12,
			Color("ffc857") if i == action_idx else (Color.WHITE if o["ok"] else Color(1, 1, 1, 0.35)))
		action_box.add_child(l)
	action_panel.visible = true

func _close_action_menu() -> void:
	action_panel.visible = false

func _set_hint(t: String) -> void:
	hint_label.text = t

# ---------------------------------------------------------------- 입력

func _unhandled_input(event: InputEvent) -> void:
	if Dialog.active or st == St.END or st == St.INTRO:
		return
	match st:
		St.SELECT:
			_input_select(event)
		St.MOVE:
			_input_move(event)
		St.ACTION:
			_input_action(event)
		St.SKILL, St.ITEM:
			_input_list(event)
		St.TARGET:
			_input_target(event)
		St.ANIM, St.ENEMY:
			pass

func _cursor_move(event: InputEvent) -> bool:
	var d := Vector2i.ZERO
	if event.is_action_pressed("move_up"):
		d = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):
		d = Vector2i(0, 1)
	elif event.is_action_pressed("move_left"):
		d = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		d = Vector2i(1, 0)
	if d != Vector2i.ZERO:
		cursor = Vector2i(clampi(cursor.x + d.x, 0, W - 1), clampi(cursor.y + d.y, 0, H - 1))
		Audio.play_sfx("cursor")
		cursor_node.position = Vector2(cursor.x * TS, cursor.y * TS)
		_update_info()
		return true
	return false

func _input_select(event: InputEvent) -> void:
	if _cursor_move(event):
		return
	if event.is_action_pressed("confirm"):
		var u = _unit_at(cursor)
		if u != null and u["side"] == "p" and not u["done"]:
			Audio.play_sfx("confirm")
			sel = u
			sel_origin = u["grid"]
			move_range = reachable(u)
			st = St.MOVE
			_show_move_hl()
			_set_hint("이동할 타일을 선택  (X: 취소)")
			_update_info()
	elif event.is_action_pressed("menu"):
		Audio.play_sfx("confirm")
		_end_player_turn()

func _input_move(event: InputEvent) -> void:
	if _cursor_move(event):
		return
	if event.is_action_pressed("confirm"):
		if move_range.has(cursor):
			Audio.play_sfx("confirm")
			st = St.ANIM
			_clear_hl()
			await _move_unit(sel, cursor)
			_open_action_menu()
		else:
			Audio.play_sfx("cancel")
	elif event.is_action_pressed("cancel"):
		Audio.play_sfx("cancel")
		sel = {}
		_clear_hl()
		st = St.SELECT
		_set_hint("")
		_update_info()

func _open_action_menu() -> void:
	var atk_targets := _targets_from(sel, sel["grid"], "e")
	var usable := _usable_items()
	action_opts = [
		{"id": "attack", "label": "공격", "ok": not atk_targets.is_empty()},
		{"id": "skill", "label": "스킬", "ok": (sel["skills"] as Array).size() > 0},
		{"id": "item", "label": "아이템", "ok": not usable.is_empty()},
		{"id": "wait", "label": "대기", "ok": true},
	]
	action_idx = 0
	while action_idx < action_opts.size() and not action_opts[action_idx]["ok"]:
		action_idx += 1
	if action_idx >= action_opts.size():
		action_idx = action_opts.size() - 1
	st = St.ACTION
	_render_action_menu()
	_update_info()
	_set_hint("행동을 선택  (X: 이동 취소)")

func _undo_move() -> void:
	Audio.play_sfx("cancel")
	sel["grid"] = sel_origin
	sel["node"].position = _grid_px(sel_origin)
	sel["node"].z_index = 10 + sel_origin.y
	_show_move_hl()
	st = St.MOVE
	_set_hint("이동할 타일을 선택  (X: 취소)")

func _input_action(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		var i := action_idx
		while true:
			i = (i + action_opts.size() - 1) % action_opts.size()
			if action_opts[i]["ok"] or i == action_idx:
				break
		action_idx = i
		Audio.play_sfx("cursor")
		_render_action_menu()
	elif event.is_action_pressed("move_down"):
		var i := action_idx
		while true:
			i = (i + 1) % action_opts.size()
			if action_opts[i]["ok"] or i == action_idx:
				break
		action_idx = i
		Audio.play_sfx("cursor")
		_render_action_menu()
	elif event.is_action_pressed("cancel"):
		_undo_move()
	elif event.is_action_pressed("confirm"):
		var o: Dictionary = action_opts[action_idx]
		if not o["ok"]:
			Audio.play_sfx("cancel")
			return
		Audio.play_sfx("confirm")
		match o["id"]:
			"attack":
				targets = _targets_from(sel, sel["grid"], "e")
				cur_action = "attack"
				_enter_target()
			"skill":
				_open_skill_list()
			"item":
				_open_item_list()
			"wait":
				_finish_player_action()

func _open_skill_list() -> void:
	list_items = []
	for sk_id in sel["skills"]:
		var sk: Dictionary = DB.skill(sk_id)
		var used := int(sel["skill_uses"].get(sk_id, 0))
		var max_uses := int(sk.get("uses", -1))
		var ok := max_uses < 0 or used < max_uses
		list_items.append({"id": sk_id, "label": "%s%s" % [sk.get("name", sk_id), "" if max_uses < 0 else " (%d/%d)" % [used, max_uses]], "ok": ok})
	list_idx = 0
	while list_idx < list_items.size() and not list_items[list_idx]["ok"]:
		list_idx += 1
	st = St.SKILL
	_render_list("스킬")

func _usable_items() -> Array:
	var out: Array = []
	for id in GameState.inventory.keys():
		var it: Dictionary = DB.item(id)
		if it.is_empty():
			continue
		if it.get("kind", "") in ["heal", "revive", "cure", "damage"]:
			out.append(id)
	out.sort()
	return out

func _open_item_list() -> void:
	list_items = []
	for id in _usable_items():
		var it: Dictionary = DB.item(id)
		list_items.append({"id": id, "label": "%s ×%d" % [it.get("name", id), GameState.item_count(id)], "ok": true})
	list_idx = 0
	st = St.ITEM
	_render_list("아이템")

func _render_list(title: String) -> void:
	for c in action_box.get_children():
		c.queue_free()
	action_box.add_child(UIKit.label(title, 12, UIKit.COL_ACCENT))
	for i in list_items.size():
		var o: Dictionary = list_items[i]
		action_box.add_child(UIKit.label(("▶ " if i == list_idx else "  ") + o["label"], 11,
			Color("ffc857") if i == list_idx else (Color.WHITE if o["ok"] else Color(1, 1, 1, 0.35))))
	action_panel.visible = true
	_set_hint("Z: 선택  X: 돌아가기")

func _input_list(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		list_idx = wrapi(list_idx - 1, 0, maxi(1, list_items.size()))
		Audio.play_sfx("cursor")
		_render_list("스킬" if st == St.SKILL else "아이템")
	elif event.is_action_pressed("move_down"):
		list_idx = wrapi(list_idx + 1, 0, maxi(1, list_items.size()))
		Audio.play_sfx("cursor")
		_render_list("스킬" if st == St.SKILL else "아이템")
	elif event.is_action_pressed("cancel"):
		Audio.play_sfx("cancel")
		st = St.ACTION
		_render_action_menu()
	elif event.is_action_pressed("confirm"):
		if list_items.is_empty() or list_idx >= list_items.size():
			return
		var o: Dictionary = list_items[list_idx]
		if not o["ok"]:
			Audio.play_sfx("cancel")
			return
		Audio.play_sfx("confirm")
		if st == St.SKILL:
			pending_skill = o["id"]
			var sk: Dictionary = DB.skill(pending_skill)
			if sk["kind"] == "heal" and sk.has("aoe"):
				await _exec_skill(sel, pending_skill, null)
				await _finish_player_action()
			elif sk["kind"] == "heal":
				targets = _targets_from(sel, sel["grid"], "p", int(sk["range"]))
				if targets.is_empty():
					Events.notify_requested.emit("사거리 내 대상이 없다.")
					return
				cur_action = "skill"
				_enter_target()
			else:
				targets = _targets_from(sel, sel["grid"], "e", int(sk["range"]))
				if targets.is_empty():
					Events.notify_requested.emit("사거리 내 대상이 없다.")
					return
				cur_action = "skill"
				_enter_target()
		else:
			pending_item = o["id"]
			var it: Dictionary = DB.item(pending_item)
			if it.get("kind", "") == "damage":
				targets = _targets_from(sel, sel["grid"], "e", int(it.get("range", 3)))
			else:
				targets = _targets_from(sel, sel["grid"], "p", 1)
				if it.get("kind", "") == "revive":
					targets = []
					for u in units:
						if u["side"] == "p" and int(u["hp"]) <= 0 and _mdist(sel["grid"], u["grid"]) <= 1:
							targets.append(u)
			if targets.is_empty():
				Events.notify_requested.emit("사거리 내 대상이 없다.")
				return
			cur_action = "item"
			_enter_target()

func _enter_target() -> void:
	tsel = 0
	st = St.TARGET
	_show_target_hl("e" if _target_side() == "e" else "p")
	cursor = targets[tsel]["grid"]
	cursor_node.position = Vector2(cursor.x * TS, cursor.y * TS)
	_update_forecast()
	_set_hint("대상 선택 (방향키)  Z: 실행  X: 취소")

func _target_side() -> String:
	if cur_action == "attack":
		return "e"
	if cur_action == "skill":
		return "e" if DB.skill(pending_skill)["kind"] == "attack" else "p"
	return "e" if DB.item(pending_item).get("kind", "") == "damage" else "p"

func _update_forecast() -> void:
	if targets.is_empty() or tsel >= targets.size():
		forecast_label.text = ""
		return
	var t: Dictionary = targets[tsel]
	if cur_action == "attack":
		forecast_label.text = "%s → %s  예상 피해 %d" % [sel["name"], t["name"], calc_damage(sel, t, 1.0)]
	elif cur_action == "skill":
		var sk: Dictionary = DB.skill(pending_skill)
		if sk["kind"] == "heal":
			forecast_label.text = "%s → %s  회복 %d" % [sel["name"], t["name"], _heal_amount(sel, sk)]
		else:
			forecast_label.text = "%s → %s  예상 피해 %d" % [sel["name"], t["name"], calc_damage(sel, t, float(sk.get("power", 1.0)), float(sk.get("pierce_def", 0.0)))]
	else:
		var it: Dictionary = DB.item(pending_item)
		if it.get("kind", "") == "damage":
			forecast_label.text = "%s → %s  피해 %d" % [sel["name"], t["name"], int(it.get("power", 10))]
		else:
			forecast_label.text = "%s → %s" % [sel["name"], t["name"]]

func _input_target(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		tsel = wrapi(tsel - 1, 0, targets.size())
		Audio.play_sfx("cursor")
		cursor = targets[tsel]["grid"]
		cursor_node.position = Vector2(cursor.x * TS, cursor.y * TS)
		_update_forecast()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		tsel = wrapi(tsel + 1, 0, targets.size())
		Audio.play_sfx("cursor")
		cursor = targets[tsel]["grid"]
		cursor_node.position = Vector2(cursor.x * TS, cursor.y * TS)
		_update_forecast()
	elif event.is_action_pressed("cancel"):
		Audio.play_sfx("cancel")
		st = St.ACTION
		_clear_hl()
		_render_action_menu()
		forecast_label.text = ""
	elif event.is_action_pressed("confirm"):
		var t: Dictionary = targets[tsel]
		forecast_label.text = ""
		if cur_action == "attack":
			await _exec_attack(sel, t)
			await _finish_player_action()
		elif cur_action == "skill":
			await _exec_skill(sel, pending_skill, t)
			await _finish_player_action()
		else:
			await _exec_item(sel, pending_item, t)
			await _finish_player_action()

func _process(delta: float) -> void:
	_cursor_t += delta
	cursor_node.modulate.a = 0.7 + sin(_cursor_t * 6.0) * 0.3
