extends CanvasLayer
## HUD — 탐험 중 파티 HP/골드/목표/지역명 표시.

var _party_box: VBoxContainer
var _gold_label: Label
var _objective_label: Label
var _location_label: Label
var _loc_timer := 0.0

func _ready() -> void:
	layer = 40
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.COL_BORDER, Color(0.07, 0.06, 0.11, 0.75)))
	panel.position = Vector2(6, 6)
	panel.custom_minimum_size = Vector2(150, 0)
	root.add_child(panel)
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 2)
	panel.add_child(_party_box)
	_gold_label = UIKit.label("", 11, Color("ffc857"))
	_party_box.add_child(_gold_label)

	_objective_label = UIKit.label("", 11, Color("fff3b0"))
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_objective_label.add_theme_constant_override("outline_size", 3)
	_objective_label.anchor_left = 1.0
	_objective_label.anchor_right = 1.0
	_objective_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_label.position = Vector2(-6, 6)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_objective_label)

	_location_label = UIKit.label("", 16, Color.WHITE)
	_location_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_location_label.add_theme_constant_override("outline_size", 4)
	_location_label.anchor_left = 0.0
	_location_label.anchor_right = 1.0
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location_label.anchor_top = 0.12
	_location_label.anchor_bottom = 0.12
	_location_label.visible = false
	root.add_child(_location_label)

	refresh()
	GameState.party_changed.connect(refresh)
	GameState.gold_changed.connect(refresh)
	GameState.inventory_changed.connect(refresh)

func refresh() -> void:
	for c in _party_box.get_children():
		if c != _gold_label:
			c.queue_free()
	for m in GameState.party:
		var row := HBoxContainer.new()
		var nm := UIKit.label(GameState.name_of(m), 10)
		nm.custom_minimum_size = Vector2(52, 0)
		row.add_child(nm)
		var ratio := float(m["hp"]) / maxf(1.0, float(GameState.max_hp(m)))
		row.add_child(UIKit.hp_bar(56, 6, ratio))
		var hp := UIKit.label("%d/%d" % [int(m["hp"]), GameState.max_hp(m)], 9, UIKit.COL_DIM)
		row.add_child(hp)
		_party_box.add_child(row)
	_gold_label.text = "%d G" % GameState.gold
	_objective_label.text = GameState.objective

func show_location(text: String) -> void:
	_location_label.text = text
	_location_label.visible = true
	_location_label.modulate.a = 1.0
	_loc_timer = 2.2

func _process(delta: float) -> void:
	if _loc_timer > 0.0:
		_loc_timer -= delta
		if _loc_timer < 0.6:
			_location_label.modulate.a = maxf(0.0, _loc_timer / 0.6)
		if _loc_timer <= 0.0:
			_location_label.visible = false
