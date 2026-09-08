extends Node2D
## GameOver — 패배 화면. 마지막 기록에서 재시작 또는 타이틀.

var _options: Array = []
var _sel := 0
var _labels: Array = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0a0810")
	bg.size = Vector2(640, 360)
	add_child(bg)

	var t := UIKit.label("파티는 쓰러졌다...", 22, Color("e05a5a"))
	t.size = Vector2(640, 30)
	t.position = Vector2(0, 110)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(t)

	var has_save := SaveManager.has_save()
	_options = []
	if has_save:
		_options.append("마지막 기록에서 다시")
	_options.append("타이틀로")

	var box := VBoxContainer.new()
	box.position = Vector2(270, 190)
	box.add_theme_constant_override("separation", 6)
	for opt in _options:
		var l := UIKit.label("  " + opt, 13)
		box.add_child(l)
		_labels.append(l)
	add_child(box)

	var hint := UIKit.label("방향키: 선택   Z: 결정", 10, UIKit.COL_DIM)
	hint.size = Vector2(640, 16)
	hint.position = Vector2(0, 300)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_refresh()

func _refresh() -> void:
	for i in _labels.size():
		var l: Label = _labels[i]
		if i == _sel:
			l.text = "▶ " + _options[i]
			l.add_theme_color_override("font_color", Color("ffc857"))
		else:
			l.text = "  " + _options[i]
			l.add_theme_color_override("font_color", Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_sel = wrapi(_sel - 1, 0, _options.size())
		Audio.play_sfx("cursor")
		_refresh()
	elif event.is_action_pressed("move_down"):
		_sel = wrapi(_sel + 1, 0, _options.size())
		Audio.play_sfx("cursor")
		_refresh()
	elif event.is_action_pressed("confirm"):
		var main := get_parent()
		if _options[_sel] == "마지막 기록에서 다시":
			Audio.play_sfx("confirm")
			SaveManager.load_game()
			main.goto_explore()
		else:
			Audio.play_sfx("confirm")
			main.goto_title()
