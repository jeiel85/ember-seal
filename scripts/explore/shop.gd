extends CanvasLayer
## Shop — 상점 UI. 구매 전용, 키보드 조작.

signal closed

var _root: Control
var _title: Label
var _list_box: VBoxContainer
var _desc_label: Label
var _gold_label: Label
var _stock: Array = []
var _sel := 0
var _shop_id := ""

func _ready() -> void:
	layer = 46
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	_title = UIKit.label("", 13, UIKit.COL_ACCENT)
	vb.add_child(_title)
	vb.add_child(UIKit.hline())
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 2)
	vb.add_child(_list_box)
	vb.add_child(UIKit.vspace(4))
	_desc_label = UIKit.label("", 10, UIKit.COL_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, 30)
	vb.add_child(_desc_label)
	_gold_label = UIKit.label("", 11, Color("ffc857"))
	vb.add_child(_gold_label)
	vb.add_child(UIKit.label("Z: 구매   X: 나가기", 10, UIKit.COL_DIM))

func open(id: String) -> void:
	_shop_id = id
	var shop: Dictionary = DB.shop(id)
	_title.text = shop.get("name", "상점")
	_stock = (shop.get("stock", []) as Array).duplicate()
	_sel = 0
	visible = true
	_render()

func _render() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	for i in _stock.size():
		var id: String = _stock[i]
		var it: Dictionary = DB.item(id)
		var eq: Dictionary = DB.equip(id)
		var nm: String = it.get("name", eq.get("name", id))
		var price := int(it.get("price", eq.get("price", 0)))
		var owned := GameState.item_count(id)
		var line := "%s %-14s %4d G%s" % ["▶" if i == _sel else " ", nm, price, ("  (보유 %d)" % owned) if owned > 0 else ""]
		_list_box.add_child(UIKit.label(line, 11, Color("ffc857") if i == _sel else Color.WHITE))
	_gold_label.text = "소지 골드: %d G" % GameState.gold
	if not _stock.is_empty() and _sel < _stock.size():
		var sid: String = _stock[_sel]
		_desc_label.text = DB.item(sid).get("desc", DB.equip(sid).get("desc", ""))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if _stock.is_empty():
		if event.is_action_pressed("cancel") or event.is_action_pressed("confirm"):
			visible = false
			closed.emit()
		return
	if event.is_action_pressed("move_up"):
		_sel = wrapi(_sel - 1, 0, _stock.size())
		Audio.play_sfx("cursor")
		_render()
	elif event.is_action_pressed("move_down"):
		_sel = wrapi(_sel + 1, 0, _stock.size())
		Audio.play_sfx("cursor")
		_render()
	elif event.is_action_pressed("cancel"):
		Audio.play_sfx("cancel")
		visible = false
		closed.emit()
	elif event.is_action_pressed("confirm"):
		_buy()

func _buy() -> void:
	var id: String = _stock[_sel]
	var it: Dictionary = DB.item(id)
	var eq: Dictionary = DB.equip(id)
	var price := int(it.get("price", eq.get("price", 0)))
	if GameState.gold < price:
		Audio.play_sfx("cancel")
		Events.notify_requested.emit("골드가 부족하다.")
		return
	GameState.add_gold(-price)
	GameState.add_item(id, 1)
	Audio.play_sfx("item")
	var nm: String = it.get("name", eq.get("name", id))
	Events.notify_requested.emit("%s 구매" % nm)
	_render()
