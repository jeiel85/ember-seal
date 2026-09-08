extends CanvasLayer
## Dialog — 전역 대화창 (autoload). 이름 + 대사 + 타이핑 효과 + 다음 안내.

var _panel: PanelContainer
var _name_label: Label
var _text: Label
var _arrow: Label
var _lines: Array = []
var _idx := 0
var _shown := 0.0
var _typing := false
var active := false

func _ready() -> void:
	layer = 60
	visible = false
	_build()
	Events.dialog_requested.connect(_on_dialog_requested)

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
	_panel.anchor_left = 0.04
	_panel.anchor_right = 0.96
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -96
	_panel.offset_bottom = -8
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_name_label = UIKit.label("", 11, UIKit.COL_ACCENT)
	_text = UIKit.label("", 11)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 44)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arrow = UIKit.label("▼", 11, UIKit.COL_DIM)
	var arrow_wrap := HBoxContainer.new()
	arrow_wrap.alignment = BoxContainer.ALIGNMENT_END
	arrow_wrap.add_child(_arrow)
	vb.add_child(_name_label)
	vb.add_child(_text)
	vb.add_child(arrow_wrap)
	_panel.add_child(vb)
	add_child(_panel)

func _on_dialog_requested(speaker: String, lines: Array, _portrait: String = "") -> void:
	_lines = lines
	_idx = 0
	active = true
	visible = true
	_name_label.text = speaker
	_name_label.visible = speaker != ""
	_show_line()

func _show_line() -> void:
	_text.text = str(_lines[_idx])
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_arrow.visible = false

func _process(delta: float) -> void:
	if not active or not _typing:
		return
	_shown += delta * 40.0
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _text.text.length():
		_text.visible_characters = -1
		_typing = false
		_arrow.visible = true

func _advance() -> void:
	if _typing:
		_text.visible_characters = -1
		_typing = false
		_arrow.visible = true
		return
	_idx += 1
	if _idx >= _lines.size():
		active = false
		visible = false
		Events.dialog_finished.emit()
	else:
		_show_line()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_advance()
