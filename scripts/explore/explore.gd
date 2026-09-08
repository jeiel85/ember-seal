extends Node2D
## Explore — 탑다운 그리드 탐험 씬. 이동/NPC/대화/맵이동/상자/필드전투/이벤트/상점.

const TILE := 16           # 그리드 논리 크기
const TS := 32             # 렌더 타일 크기 (16px 아트 × 2, 픽셀 퍼펙트)
const MOVE_TIME := 0.13
const DIRS := {
	"up": Vector2i(0, -1), "down": Vector2i(0, 1),
	"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
}

var map_id := ""
var map_def: Dictionary = {}
var W := 0
var H := 0
var walkable: Array = []
var world: Node2D
var woff := Vector2.ZERO  # 맵이 화면보다 작을 때 중앙 정렬 오프셋
var water_nodes: Array = []
var water_frame := 0
var water_timer := 0.0

var player: Node2D
var psprite: AnimatedSprite2D
var pgrid := Vector2i.ZERO
var pfacing := "down"
var moving := false
var busy := false

var npcs := {}        # Vector2i -> npc def
var npc_nodes := {}   # Vector2i -> AnimatedSprite2D
var chests := {}      # Vector2i -> {"idx": int, "def": Dictionary}
var chest_nodes := {} # Vector2i -> Sprite2D
var fes := {}         # Vector2i -> {"idx": int, "def": Dictionary}
var fe_nodes := {}    # Vector2i -> Node2D
var exits := {}       # Vector2i -> exit def
var camera: Camera2D
var hud: CanvasLayer
var menu_layer: CanvasLayer
var shop_layer: CanvasLayer
var fade: ColorRect
var act_label: Label
var _fe_time := 0.0

func _ready() -> void:
	# 어두운 배경 (맵 밖 공간)
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Color("0c0a14")
	bg.size = Vector2(640, 360)
	bg_layer.add_child(bg)
	add_child(bg_layer)
	_build_fade()
	hud = preload("res://scripts/explore/hud.gd").new()
	add_child(hud)
	menu_layer = preload("res://scripts/explore/menu.gd").new()
	menu_layer.closed.connect(func() -> void: busy = false)
	add_child(menu_layer)
	shop_layer = preload("res://scripts/explore/shop.gd").new()
	shop_layer.closed.connect(func() -> void: busy = false)
	add_child(shop_layer)

	var start_map := GameState.current_map
	var sx := GameState.player_pos.x
	var sy := GameState.player_pos.y
	if start_map == "" or DB.map(start_map).is_empty():
		start_map = "village1"
		var md: Dictionary = DB.map(start_map)
		sx = int(md["player_start"]["x"])
		sy = int(md["player_start"]["y"])
		GameState.current_map = start_map
	_load_map(start_map, sx, sy)
	_fade_in()
	_after_map_enter()

# ---------------------------------------------------------------- 맵 구축

func _load_map(id: String, px: int, py: int) -> void:
	if world != null:
		world.queue_free()
	world = Node2D.new()
	world.z_index = 0
	add_child(world)

	npcs.clear(); npc_nodes.clear(); chests.clear(); chest_nodes.clear()
	fes.clear(); fe_nodes.clear(); exits.clear(); water_nodes.clear()

	map_id = id
	map_def = DB.map(id)
	var rows: Array = map_def["tiles"]
	H = rows.size()
	W = (rows[0] as String).length()
	var tmap: Dictionary = map_def["tilemap"]
	var blocked_chars: String = map_def["blocked"]
	walkable = []
	woff = Vector2(maxf(0.0, (640.0 - W * TS) / 2.0), maxf(0.0, (360.0 - H * TS) / 2.0))
	world.position = woff

	for y in H:
		var row: String = rows[y]
		var wrow: Array = []
		for x in W:
			var ch := row[x]
			var kind: String = tmap.get(ch, "grass")
			var s := Sprite2D.new()
			s.texture = PixelArt.tile_texture(kind)
			s.centered = false
			s.scale = Vector2(2, 2)
			s.position = Vector2(x * TS, y * TS)
			world.add_child(s)
			if kind == "water":
				water_nodes.append(s)
			wrow.append(not blocked_chars.contains(ch))
		walkable.append(wrow)

	# NPC
	for npc in map_def.get("npcs", []):
		var pos := Vector2i(int(npc["x"]), int(npc["y"]))
		npcs[pos] = npc
		var n := AnimatedSprite2D.new()
		n.sprite_frames = PixelArt.make_sprite_frames(npc["palette"])
		n.scale = Vector2(2, 2)
		n.position = Vector2(pos.x * TS + TS / 2.0, pos.y * TS + TS / 2.0)
		n.play("idle_down")
		world.add_child(n)
		npc_nodes[pos] = n

	# 상자
	var opened: Array = GameState.opened_chests.get(id, [])
	var chest_list: Array = map_def.get("chests", [])
	for i in chest_list.size():
		var ch: Dictionary = chest_list[i]
		var pos := Vector2i(int(ch["x"]), int(ch["y"]))
		chests[pos] = {"idx": i, "def": ch}
		var s := Sprite2D.new()
		s.centered = false
		s.scale = Vector2(2, 2)
		s.position = Vector2(pos.x * TS, pos.y * TS)
		s.texture = PixelArt.tile_texture("chest_open" if str(i) in opened else "chest_closed")
		world.add_child(s)
		chest_nodes[pos] = s

	# 필드 적
	var defeated: Array = GameState.defeated_field_enemies.get(id, [])
	var fe_list: Array = map_def.get("field_enemies", [])
	for i in fe_list.size():
		if str(i) in defeated:
			continue
		var fe: Dictionary = fe_list[i]
		if not _cond_ok(fe.get("cond", {})):
			continue
		var pos := Vector2i(int(fe["x"]), int(fe["y"]))
		fes[pos] = {"idx": i, "def": fe}
		var en := Node2D.new()
		var sp := Sprite2D.new()
		var edef: Dictionary = DB.enemy(fe["enemy"])
		sp.texture = PixelArt.enemy_texture(edef["sprite"])
		var sz := int(PixelArt.enemy_size(edef["sprite"])) * 2
		sp.centered = false
		sp.scale = Vector2(2, 2)
		sp.position = Vector2(TS / 2.0 - sz, TS - sz * 2)
		en.add_child(sp)
		en.position = Vector2(pos.x * TS + TS / 2.0, pos.y * TS + TS / 2.0)
		world.add_child(en)
		fe_nodes[pos] = en

	# 출구
	for ex in map_def.get("exits", []):
		exits[Vector2i(int(ex["x"]), int(ex["y"]))] = ex

	# 이벤트 스프라이트(표지판 등)
	for ev in map_def.get("events", []):
		if ev.get("sprite", "") != "" and ev.has("x"):
			var pos := Vector2i(int(ev["x"]), int(ev["y"]))
			var s := Sprite2D.new()
			s.texture = PixelArt.tile_texture(ev["sprite"])
			s.centered = false
			s.scale = Vector2(2, 2)
			s.position = Vector2(pos.x * TS, pos.y * TS)
			world.add_child(s)

	# 플레이어
	pgrid = Vector2i(px, py)
	pfacing = GameState.player_dir
	if player == null:
		player = Node2D.new()
		player.z_index = 10
		psprite = AnimatedSprite2D.new()
		psprite.sprite_frames = PixelArt.make_sprite_frames(DB.char("rune")["palette"])
		psprite.scale = Vector2(2, 2)
		player.add_child(psprite)
		add_child(player)
	player.position = _gpx(pgrid)
	_play_anim("idle_" + pfacing)

	# 카메라
	if camera == null:
		camera = Camera2D.new()
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 10.0
		add_child(camera)
	camera.make_current()
	camera.limit_left = int(-woff.x)
	camera.limit_top = int(-woff.y)
	camera.limit_right = int(W * TS + woff.x)
	camera.limit_bottom = int(H * TS + woff.y)
	camera.position = player.position
	camera.reset_smoothing()

func _gpx(g: Vector2i) -> Vector2:
	return Vector2(g.x * TS + TS / 2.0 + woff.x, g.y * TS + TS / 2.0 + woff.y)

func _is_walkable(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
		return false
	return walkable[p.y][p.x]

func _occupied(p: Vector2i) -> bool:
	return npcs.has(p) or chests.has(p) or fes.has(p) or p == pgrid

# ---------------------------------------------------------------- 페이드/연출

func _build_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(640, 360)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.add_child(fade)
	add_child(layer)
	act_label = UIKit.label("", 20, Color("ffc857"))
	act_label.add_theme_color_override("font_outline_color", Color("3a1a08"))
	act_label.add_theme_constant_override("outline_size", 5)
	act_label.anchor_left = 0.0
	act_label.anchor_right = 1.0
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act_label.anchor_top = 0.4
	act_label.anchor_bottom = 0.4
	act_label.visible = false
	var l2 := CanvasLayer.new()
	l2.layer = 81
	l2.add_child(act_label)
	add_child(l2)

func _fade_to_black(t := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, t)
	await tw.finished

func _fade_in(t := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, t)
	await tw.finished

func _show_act_title(text: String) -> void:
	act_label.text = text
	act_label.visible = true
	act_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(act_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.6)
	tw.tween_property(act_label, "modulate:a", 0.0, 0.5)
	await tw.finished
	act_label.visible = false

# ---------------------------------------------------------------- 진입 처리

func _after_map_enter() -> void:
	busy = true
	hud.show_location(map_def.get("name", ""))
	Audio.play_bgm(map_def.get("bgm", "field"))
	SaveManager.save_game()  # 지역 진입 자동 저장
	for ev in map_def.get("events", []):
		if ev.get("trigger", "") == "auto" and _cond_ok(ev.get("cond", {})):
			await run_actions(ev.get("actions", []))
	# 재개 액션(전투 후 이어받기)
	if not GameState.resume_actions.is_empty():
		var acts: Array = GameState.resume_actions
		GameState.resume_actions = []
		await run_actions(acts)
	busy = false

# ---------------------------------------------------------------- 이벤트 처리

func _cond_ok(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	if cond.has("stage_min") and GameState.stage < int(cond["stage_min"]):
		return false
	if cond.has("stage_max") and GameState.stage > int(cond["stage_max"]):
		return false
	if cond.has("flag") and not GameState.has_flag(cond["flag"]):
		return false
	if cond.has("not_flag") and GameState.has_flag(cond["not_flag"]):
		return false
	if cond.has("has_item") and GameState.item_count(cond["has_item"]) <= 0:
		return false
	if cond.has("member_not") and GameState.has_member(cond["member_not"]):
		return false
	return true

## 액션 실행기 — 대사/보상/전투/플래그 등을 순서대로 처리.
func run_actions(actions: Array) -> void:
	busy = true
	for i in actions.size():
		var a: Dictionary = actions[i]
		match a.get("type", ""):
			"dialog":
				Events.dialog_requested.emit(a.get("speaker", ""), a.get("lines", []))
				await Events.dialog_finished
			"set_stage":
				GameState.stage = int(a["value"])
			"set_flag":
				GameState.set_flag(a["flag"])
			"give_item":
				GameState.add_item(a["item"], int(a.get("count", 1)))
				var iname: String = DB.item(a["item"]).get("name", a["item"])
				Audio.play_sfx("item")
				Events.notify_requested.emit("%s ×%d 얻었다" % [iname, int(a.get("count", 1))])
			"take_item":
				GameState.remove_item(a["item"], int(a.get("count", 1)))
			"give_gold":
				GameState.add_gold(int(a["amount"]))
				Events.notify_requested.emit("%d 골드를 얻었다" % int(a["amount"]))
			"give_equip":
				GameState.add_item(a["equip"], 1)
				var ename: String = DB.equip(a["equip"]).get("name", a["equip"])
				Audio.play_sfx("item")
				Events.notify_requested.emit("%s 얻었다" % ename)
			"join":
				GameState.add_member(a["char"], int(a.get("level", 1)))
				var jname: String = DB.char(a["char"]).get("name", a["char"])
				Audio.play_sfx("join")
				Events.notify_requested.emit("%s가 파티에 합류했다!" % jname)
			"battle":
				GameState.resume_actions = actions.slice(i + 1)
				Events.battle_requested.emit(a["battle"])
				return
			"heal":
				GameState.full_heal()
				Events.notify_requested.emit("파티의 상태가 회복되었다")
			"move_map":
				await _do_move_map(a["to"], int(a["x"]), int(a["y"]))
			"ending":
				Events.request_ending.emit()
				return
			"sfx":
				Audio.play_sfx(a["id"])
			"act_title":
				await _show_act_title(a["text"])
			"set_objective":
				GameState.objective = a["text"]
				hud.refresh()
			"shop":
				await _open_shop(a["id"])
	busy = false

func _do_move_map(to: String, x: int, y: int) -> void:
	await _fade_to_black()
	GameState.current_map = to
	_load_map(to, x, y)
	await _fade_in()
	await _after_map_enter()

# ---------------------------------------------------------------- 입력/이동

func _process(delta: float) -> void:
	water_timer += delta
	if water_timer > 0.6:
		water_timer = 0.0
		water_frame = 1 - water_frame
		for s in water_nodes:
			s.texture = PixelArt.tile_texture("water", water_frame)
	_fe_time += delta
	for k in fe_nodes:
		var n: Node2D = fe_nodes[k]
		n.position.y = _gpx(k).y + sin(_fe_time * 4.0 + k.x) * 2.0
	if camera != null and player != null:
		camera.position = player.position
	if busy or moving or Dialog.active or menu_layer.visible or shop_layer.visible:
		return
	var dir := _input_dir()
	if dir != "":
		_try_move(dir)

func _input_dir() -> String:
	for d in ["up", "down", "left", "right"]:
		if Input.is_action_pressed("move_" + d):
			return d
	return ""

func _try_move(dir: String) -> void:
	if pfacing != dir:
		pfacing = dir
		_play_anim("idle_" + dir)
	var target: Vector2i = pgrid + DIRS[dir]
	# 필드 적에게 접촉하면 전투 시작 (이동하지 않음)
	if fes.has(target):
		_start_field_battle(target)
		return
	if not _is_walkable(target) or _occupied(target):
		return
	moving = true
	_play_anim("walk_" + dir)
	var tw := create_tween()
	tw.tween_property(player, "position", _gpx(target), MOVE_TIME)
	await tw.finished
	pgrid = target
	GameState.player_pos = pgrid
	GameState.player_dir = pfacing
	moving = false
	_play_anim("idle_" + dir)
	_on_arrived()

func _play_anim(anim: String) -> void:
	if psprite.sprite_frames != null and psprite.sprite_frames.has_animation(anim):
		psprite.play(anim)

func _on_arrived() -> void:
	if exits.has(pgrid):
		var ex: Dictionary = exits[pgrid]
		if _cond_ok(ex.get("cond", {})):
			_do_move_map(ex["to"], int(ex["tx"]), int(ex["ty"]))
			return
		elif ex.has("locked_lines"):
			busy = true
			Events.dialog_requested.emit("", ex["locked_lines"])
			await Events.dialog_finished
			busy = false
			return
	if fes.has(pgrid):
		_start_field_battle(pgrid)
		return
	for ev in map_def.get("events", []):
		if ev.get("trigger", "") == "step" and _cond_ok(ev.get("cond", {})):
			var hit := false
			if ev.has("tiles"):
				for t in ev["tiles"]:
					if Vector2i(int(t[0]), int(t[1])) == pgrid:
						hit = true
						break
			elif ev.has("x") and Vector2i(int(ev["x"]), int(ev["y"])) == pgrid:
				hit = true
			if hit:
				await run_actions(ev.get("actions", []))
				return

func _unhandled_input(event: InputEvent) -> void:
	if busy or Dialog.active or menu_layer.visible or shop_layer.visible:
		return
	if event.is_action_pressed("menu"):
		Audio.play_sfx("confirm")
		busy = true
		menu_layer.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_interact()
		get_viewport().set_input_as_handled()

func _interact() -> void:
	var front: Vector2i = pgrid + DIRS[pfacing]
	if npcs.has(front):
		_talk_to(front)
	elif chests.has(front):
		_open_chest(front)
	else:
		for ev in map_def.get("events", []):
			if ev.get("trigger", "") == "interact" and _cond_ok(ev.get("cond", {})):
				if ev.has("x") and Vector2i(int(ev["x"]), int(ev["y"])) == front:
					run_actions(ev.get("actions", []))
					return

# ---------------------------------------------------------------- NPC/상자/전투

func _talk_to(pos: Vector2i) -> void:
	var npc: Dictionary = npcs[pos]
	var face := "down"
	match pfacing:
		"up": face = "down"
		"down": face = "up"
		"left": face = "right"
		"right": face = "left"
	var node: AnimatedSprite2D = npc_nodes[pos]
	if node.sprite_frames.has_animation("idle_" + face):
		node.play("idle_" + face)
	Audio.play_sfx("confirm")
	for entry in npc.get("dialog", []):
		if not _cond_ok(entry.get("cond", {})):
			continue
		var actions: Array = [{"type": "dialog", "speaker": npc["name"], "lines": entry.get("lines", [])}]
		if entry.has("join"):
			actions.append({"type": "join", "char": entry["join"], "level": int(entry.get("join_level", 1))})
		if entry.has("set_flag"):
			actions.append({"type": "set_flag", "flag": entry["set_flag"]})
		if entry.has("take_item"):
			actions.append({"type": "take_item", "item": entry["take_item"], "count": int(entry.get("take_count", 1))})
		if entry.has("give_item"):
			actions.append({"type": "give_item", "item": entry["give_item"], "count": int(entry.get("give_count", 1))})
		if entry.has("give_equip"):
			actions.append({"type": "give_equip", "equip": entry["give_equip"]})
		if entry.has("give_gold"):
			actions.append({"type": "give_gold", "amount": int(entry["give_gold"])})
		if entry.has("set_stage"):
			actions.append({"type": "set_stage", "value": int(entry["set_stage"])})
		if npc.has("shop"):
			actions.append({"type": "shop", "id": npc["shop"]})
		await run_actions(actions)
		hud.refresh()
		break

func _open_chest(pos: Vector2i) -> void:
	var c: Dictionary = chests[pos]
	var idx := int(c["idx"])
	var opened: Array = GameState.opened_chests.get(map_id, [])
	if str(idx) in opened:
		Events.notify_requested.emit("상자는 비어 있다.")
		return
	Audio.play_sfx("chest")
	chest_nodes[pos].texture = PixelArt.tile_texture("chest_open")
	var def: Dictionary = c["def"]
	var arr: Array = opened.duplicate()
	arr.append(str(idx))
	GameState.opened_chests[map_id] = arr
	if def.has("item"):
		GameState.add_item(def["item"], int(def.get("count", 1)))
		var iname: String = DB.item(def["item"]).get("name", "")
		if iname == "":
			iname = DB.equip(def["item"]).get("name", str(def["item"]))
		Events.notify_requested.emit("%s ×%d 얻었다" % [iname, int(def.get("count", 1))])
	if def.has("gold"):
		GameState.add_gold(int(def["gold"]))
		Events.notify_requested.emit("%d 골드를 얻었다" % int(def["gold"]))

func _start_field_battle(pos: Vector2i) -> void:
	var fe: Dictionary = fes[pos]
	var fedef: Dictionary = fe["def"]
	var bdef: Dictionary = DB.battle(fedef["battle"])
	busy = true
	var intro: Dictionary = bdef.get("intro", {})
	if intro.has("lines") and not (intro["lines"] as Array).is_empty():
		Events.dialog_requested.emit(intro.get("speaker", ""), intro["lines"])
		await Events.dialog_finished
	Battle.pending_context = {"map": map_id, "fe_idx": int(fe["idx"])}
	GameState.resume_actions = (bdef.get("on_win", []) as Array).duplicate()
	Events.battle_requested.emit(fedef["battle"])

func _open_shop(id: String) -> void:
	shop_layer.open(id)
	await shop_layer.closed
