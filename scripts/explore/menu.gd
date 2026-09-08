extends CanvasLayer
## Menu — 탐험 중 메뉴 (아이템/장비/상태/기록/타이틀). 키보드 전용.

signal closed

var _root: Control
var _menu_list: VBoxContainer
var _content: PanelContainer
var _content_box: VBoxContainer
var _options := ["아이템", "장비", "상태", "기록", "타이틀로", "닫기"]
var _sel := 0
var _mode := "root"  # root / items / item_target / equip_member / equip_slot / equip_pick / status_member
var _sub_sel := 0
var _sub_data: Array = []
var _pending_item := ""
var _pending_member := {}
var _pending_slot := ""
var _status_detail := false

func _ready() -> void:
	layer = 45
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var menu_panel := PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	menu_panel.position = Vector2(12, 12)
	menu_panel.custom_minimum_size = Vector2(120, 0)
	_root.add_child(menu_panel)
	_menu_list = VBoxContainer.new()
	_menu_list.add_theme_constant_override("separation", 3)
	menu_panel.add_child(_menu_list)

	_content = PanelContainer.new()
	_content.add_theme_stylebox_override("panel", UIKit.panel_style())
	_content.anchor_left = 0.22
	_content.anchor_right = 0.98
	_content.anchor_top = 0.04
	_content.anchor_bottom = 0.96
	_root.add_child(_content)
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 3)
	_content.add_child(_content_box)

func open() -> void:
	visible = true
	_mode = "root"
	_sel = 0
	_render()

func close() -> void:
	visible = false
	closed.emit()

func _render() -> void:
	_status_detail = false
	for c in _menu_list.get_children():
		c.queue_free()
	for i in _options.size():
		var l := UIKit.label(("▶ " if i == _sel and _mode == "root" else "  ") + _options[i], 12)
		if i == _sel and _mode == "root":
			l.add_theme_color_override("font_color", Color("ffc857"))
		_menu_list.add_child(l)
	for c in _content_box.get_children():
		c.queue_free()
	match _mode:
		"root":
			_render_root_info()
		"items":
			_render_items()
		"item_target":
			_render_item_target()
		"equip_member":
			_render_equip_member()
		"equip_slot":
			_render_equip_slot()
		"equip_pick":
			_render_equip_pick()
		"status_member":
			_render_status()

func _render_root_info() -> void:
	_content_box.add_child(UIKit.label("잿불의 인장", 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	var t := "골드: %d G\n플레이 시간: %s\n\n방향키: 선택    Z: 결정    X: 취소\nTab: 메뉴 닫기" % [
		GameState.gold, SaveManager.play_time_text()]
	var l := UIKit.label(t, 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_box.add_child(l)
	_content_box.add_child(UIKit.vspace(6))
	_content_box.add_child(UIKit.label("목표: " + (GameState.objective if GameState.objective != "" else "이야기를 따라가라"), 10, UIKit.COL_DIM))
	_content_box.add_child(UIKit.vspace(6))
	_content_box.add_child(UIKit.label("진행 단계: %d / 파티 %d명" % [GameState.stage, GameState.party.size()], 10, UIKit.COL_DIM))

func _render_items() -> void:
	_content_box.add_child(UIKit.label("아이템", 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	_sub_data.clear()
	var ids := GameState.inventory.keys()
	ids.sort()
	if ids.is_empty():
		_content_box.add_child(UIKit.label("가진 아이템이 없다.", 11, UIKit.COL_DIM))
		return
	for i in ids.size():
		var id: String = ids[i]
		var it: Dictionary = DB.item(id)
		var en: Dictionary = DB.equip(id)
		var nm: String = it.get("name", en.get("name", id))
		var line := "%s %s ×%d" % ["▶" if i == _sub_sel else " ", nm, int(GameState.inventory[id])]
		var l := UIKit.label(line, 11, Color("ffc857") if i == _sub_sel else Color.WHITE)
		_content_box.add_child(l)
		_sub_data.append(id)
	if not _sub_data.is_empty():
		var sel_id: String = _sub_data[_sub_sel]
		var d: String = DB.item(sel_id).get("desc", DB.equip(sel_id).get("desc", ""))
		_content_box.add_child(UIKit.vspace(4))
		var dl := UIKit.label(d, 10, UIKit.COL_DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_box.add_child(dl)

func _render_item_target() -> void:
	var it: Dictionary = DB.item(_pending_item)
	_content_box.add_child(UIKit.label("%s — 대상 선택" % it.get("name", ""), 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	_sub_data.clear()
	for i in GameState.party.size():
		var m: Dictionary = GameState.party[i]
		var usable := true
		match it.get("kind", ""):
			"revive":
				usable = int(m["hp"]) <= 0
			"cure":
				usable = false  # 탐험 중 독 없음(전투 전용) — 안내만
			_:
				usable = int(m["hp"]) > 0 and int(m["hp"]) < GameState.max_hp(m)
		var line := "%s %s  HP %d/%d%s" % ["▶" if i == _sub_sel else " ", GameState.name_of(m), int(m["hp"]), GameState.max_hp(m), "" if usable else " (불필요)"]
		_content_box.add_child(UIKit.label(line, 11, Color("ffc857") if i == _sub_sel else Color.WHITE))
		_sub_data.append(m)

func _render_equip_member() -> void:
	_content_box.add_child(UIKit.label("장비 — 누구?", 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	_sub_data.clear()
	for i in GameState.party.size():
		var m: Dictionary = GameState.party[i]
		var line := "%s %s  Lv%d" % ["▶" if i == _sub_sel else " ", GameState.name_of(m), int(m["level"])]
		_content_box.add_child(UIKit.label(line, 11, Color("ffc857") if i == _sub_sel else Color.WHITE))
		_sub_data.append(m)

func _render_equip_slot() -> void:
	_content_box.add_child(UIKit.label("%s의 장비" % GameState.name_of(_pending_member), 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	var slots := [["weapon", "무기"], ["armor", "방어구"], ["trinket", "장신구"]]
	_sub_data.clear()
	for i in slots.size():
		var slot: String = slots[i][0]
		var eid: String = _pending_member["equips"].get(slot, "")
		var ename: String = DB.equip(eid).get("name", "없음") if eid != "" else "없음"
		var line := "%s %s: %s" % ["▶" if i == _sub_sel else " ", slots[i][1], ename]
		_content_box.add_child(UIKit.label(line, 11, Color("ffc857") if i == _sub_sel else Color.WHITE))
		_sub_data.append(slot)

func _render_equip_pick() -> void:
	_content_box.add_child(UIKit.label("무엇을 장비할까?", 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	_sub_data.clear()
	var cur: String = _pending_member["equips"].get(_pending_slot, "")
	if cur != "":
		_content_box.add_child(UIKit.label("  해제", 11, Color("ffc857") if _sub_sel == 0 else Color.WHITE))
		_sub_data.append("")
	var ids := GameState.inventory.keys()
	ids.sort()
	for id in ids:
		var eq: Dictionary = DB.equip(id)
		if eq.is_empty() or eq.get("slot", "") != _pending_slot:
			continue
		var i := _sub_data.size()
		var line := "%s %s" % ["▶" if i == _sub_sel else " ", eq.get("name", id)]
		_content_box.add_child(UIKit.label(line, 11, Color("ffc857") if i == _sub_sel else Color.WHITE))
		_sub_data.append(id)
	if _sub_data.is_empty():
		_content_box.add_child(UIKit.label("장비할 수 있는 것이 없다.", 11, UIKit.COL_DIM))

func _render_status() -> void:
	_content_box.add_child(UIKit.label("상태 — 누구?", 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	_sub_data.clear()
	for i in GameState.party.size():
		var m: Dictionary = GameState.party[i]
		var line := "%s %s  Lv%d  HP %d/%d" % ["▶" if i == _sub_sel else " ", GameState.name_of(m), int(m["level"]), int(m["hp"]), GameState.max_hp(m)]
		_content_box.add_child(UIKit.label(line, 11, Color("ffc857") if i == _sub_sel else Color.WHITE))
		_sub_data.append(m)

func _render_status_detail(m: Dictionary) -> void:
	for c in _content_box.get_children():
		c.queue_free()
	_content_box.add_child(UIKit.label("%s  Lv%d  %s" % [GameState.name_of(m), int(m["level"]), DB.char(m["id"]).get("role", "")], 13, UIKit.COL_ACCENT))
	_content_box.add_child(UIKit.hline())
	var exp_now := int(m["exp"])
	var exp_next := DB.exp_for_level(mini(int(m["level"]) + 1, DB.max_level()))
	var t := "HP %d/%d\n공격 %d   방어 %d\n이동 %d   사거리 %d\n경험치 %d / 다음 %d" % [
		int(m["hp"]), GameState.max_hp(m), GameState.atk(m), GameState.def_(m),
		GameState.mov(m), GameState.rng(m), exp_now, exp_next]
	_content_box.add_child(UIKit.label(t, 11))
	_content_box.add_child(UIKit.vspace(4))
	_content_box.add_child(UIKit.label("장비: %s / %s / %s" % [
		DB.equip(m["equips"].get("weapon", "")).get("name", "없음"),
		DB.equip(m["equips"].get("armor", "")).get("name", "없음"),
		DB.equip(m["equips"].get("trinket", "")).get("name", "엄음")], 10, UIKit.COL_DIM))
	_content_box.add_child(UIKit.vspace(4))
	_content_box.add_child(UIKit.label("스킬:", 11, UIKit.COL_ACCENT))
	for sk in GameState.known_skills(m):
		var s: Dictionary = DB.skill(sk)
		_content_box.add_child(UIKit.label("· %s — %s" % [s.get("name", sk), s.get("desc", "")], 10))
	var cdesc: String = DB.char(m["id"]).get("desc", "")
	if cdesc != "":
		_content_box.add_child(UIKit.vspace(4))
		var dl := UIKit.label(cdesc, 10, UIKit.COL_DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_box.add_child(dl)
	_content_box.add_child(UIKit.vspace(4))
	_content_box.add_child(UIKit.label("X: 돌아가기", 10, UIKit.COL_DIM))

# ---------------------------------------------------------------- 입력

func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("menu"):
		if _mode == "root":
			close()
		else:
			_mode = "root"
			_render()
		return
	match _mode:
		"root":
			_input_root(event)
		"items", "item_target", "equip_member", "equip_slot", "equip_pick", "status_member":
			_input_sub(event)

func _input_root(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_sel = (_sel + _options.size() - 1) % _options.size()
		Audio.play_sfx("cursor")
		_render()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % _options.size()
		Audio.play_sfx("cursor")
		_render()
	elif event.is_action_pressed("confirm"):
		Audio.play_sfx("confirm")
		match _sel:
			0:
				_mode = "items"; _sub_sel = 0; _render()
			1:
				_mode = "equip_member"; _sub_sel = 0; _render()
			2:
				_mode = "status_member"; _sub_sel = 0; _render()
			3:
				if SaveManager.save_game():
					Audio.play_sfx("confirm")
					Events.notify_requested.emit("기록을 저장했다.")
				_render()
			4:
				close()
				Events.request_title.emit()
			5:
				close()

func _sub_max() -> int:
	return maxi(0, _sub_data.size() - 1)

func _input_sub(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		if _sub_data.is_empty():
			return
		var d := -1 if event.is_action_pressed("move_up") else 1
		_sub_sel = wrapi(_sub_sel + d, 0, _sub_data.size())
		Audio.play_sfx("cursor")
		_render()
	elif event.is_action_pressed("cancel"):
		Audio.play_sfx("cancel")
		if _mode == "status_member" and _status_detail:
			_status_detail = false
			_render()
			return
		match _mode:
			"item_target":
				_mode = "items"
			"equip_slot":
				_mode = "equip_member"
			"equip_pick":
				_mode = "equip_slot"
			_:
				_mode = "root"
		_sub_sel = 0
		_status_detail = false
		_render()
	elif event.is_action_pressed("confirm"):
		_confirm_sub()

func _confirm_sub() -> void:
	if _sub_data.is_empty() or _sub_sel >= _sub_data.size():
		return
	Audio.play_sfx("confirm")
	match _mode:
		"items":
			_pending_item = _sub_data[_sub_sel]
			var it: Dictionary = DB.item(_pending_item)
			if it.is_empty():
				Events.notify_requested.emit("장비는 장비 메뉴에서 바꿀 수 있다.")
				return
			if it.get("kind", "") == "quest":
				Events.notify_requested.emit("여기서는 사용할 수 없다.")
				return
			if it.get("kind", "") == "cure":
				Events.notify_requested.emit("독은 전투 중에만 치료한다.")
				return
			_mode = "item_target"
			_sub_sel = 0
			_render()
		"item_target":
			var m: Dictionary = _sub_data[_sub_sel]
			_use_item_on(_pending_item, m)
		"equip_member":
			_pending_member = _sub_data[_sub_sel]
			_mode = "equip_slot"
			_sub_sel = 0
			_render()
		"equip_slot":
			_pending_slot = _sub_data[_sub_sel]
			_mode = "equip_pick"
			_sub_sel = 0
			_render()
		"equip_pick":
			var pick: String = _sub_data[_sub_sel]
			if pick == "":
				var old: String = GameState.unequip(_pending_member, _pending_slot)
				if old != "":
					GameState.add_item(old, 1)
				Events.notify_requested.emit("장비를 해제했다.")
			else:
				var old2: String = GameState.equip_item(_pending_member, pick)
				GameState.remove_item(pick, 1)
				if old2 != "":
					GameState.add_item(old2, 1)
				Events.notify_requested.emit("%s 장비했다." % DB.equip(pick).get("name", ""))
			_mode = "equip_slot"
			_sub_sel = 0
			_render()
		"status_member":
			_status_detail = true
			_render_status_detail(_sub_data[_sub_sel])

func _use_item_on(item_id: String, m: Dictionary) -> void:
	var it: Dictionary = DB.item(item_id)
	match it.get("kind", ""):
		"heal":
			if int(m["hp"]) <= 0:
				Events.notify_requested.emit("쓰러진 멤버에는 부활 깃털이 필요하다.")
				return
			var before := int(m["hp"])
			m["hp"] = mini(before + int(it.get("power", 0)), GameState.max_hp(m))
			GameState.remove_item(item_id, 1)
			Audio.play_sfx("heal")
			Events.notify_requested.emit("%s의 HP가 %d 회복되었다" % [GameState.name_of(m), int(m["hp"]) - before])
		"revive":
			if int(m["hp"]) > 0:
				Events.notify_requested.emit("쓰러져 있지 않다.")
				return
			m["hp"] = int(GameState.max_hp(m) * float(it.get("power", 0.5)))
			GameState.remove_item(item_id, 1)
			Audio.play_sfx("heal")
			Events.notify_requested.emit("%s가 일어났다!" % GameState.name_of(m))
		_:
			Events.notify_requested.emit("여기서는 사용할 수 없다.")
	_mode = "items"
	_sub_sel = 0
	_render()
