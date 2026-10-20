extends Node2D
## 타이틀 화면 — 새 게임 / 이어하기 / 종료.

const REPO_URL := "https://github.com/jeiel85/ember-seal"

var _options: Array = []
var _sel := 0
var _labels: Array = []
var _save_exists := false
var _flame: ColorRect
var _flame_core: ColorRect
var _t := 0.0

func _ready() -> void:
	_save_exists = SaveManager.has_save()
	_build()
	_refresh()

func _build() -> void:
	# 배경: 어두운 밤하늘 + 등대 실루엣
	var bg := ColorRect.new()
	bg.color = Color("141020")
	bg.size = Vector2(640, 360)
	add_child(bg)

	var stars := Node2D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var s := ColorRect.new()
		s.color = Color(1, 1, 1, rng.randf_range(0.2, 0.8))
		var sz := 1 if rng.randf() > 0.2 else 2
		s.size = Vector2(sz, sz)
		s.position = Vector2(rng.randf_range(4, 636), rng.randf_range(4, 300))
		stars.add_child(s)
	add_child(stars)

	# 등대 장식
	var deco := Node2D.new()
	deco.position = Vector2(0, 0)
	add_child(deco)
	var ground := ColorRect.new()
	ground.color = Color("241a30")
	ground.position = Vector2(430, 296)
	ground.size = Vector2(200, 12)
	deco.add_child(ground)
	var tower := Sprite2D.new()
	tower.texture = PixelArt.title_lighthouse()
	tower.centered = false
	tower.scale = Vector2(4, 4)
	tower.position = Vector2(478, 130)
	deco.add_child(tower)
	var flame := ColorRect.new()
	flame.color = Color("ff9a3c")
	flame.position = Vector2(524, 146)
	flame.size = Vector2(16, 16)
	deco.add_child(flame)
	_flame = flame
	var flame_core := ColorRect.new()
	flame_core.color = Color("fff3b0")
	flame_core.position = Vector2(530, 154)
	flame_core.size = Vector2(6, 6)
	deco.add_child(flame_core)
	_flame_core = flame_core

	# 타이틀
	var title := UIKit.label("잿불의 인장", 32, Color("ffc857"))
	title.add_theme_color_override("font_outline_color", Color("3a1a08"))
	title.add_theme_constant_override("outline_size", 6)
	title.size = Vector2(640, 44)
	title.position = Vector2(0, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := UIKit.label("- The Ember Seal -", 12, UIKit.COL_DIM)
	sub.size = Vector2(640, 20)
	sub.position = Vector2(0, 112)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# 메뉴
	var menu_box := VBoxContainer.new()
	menu_box.position = Vector2(270, 170)
	menu_box.add_theme_constant_override("separation", 6)
	_options = ["새 게임", "이어하기", "종료"]
	for opt in _options:
		var l := UIKit.label("  " + opt, 14)
		menu_box.add_child(l)
		_labels.append(l)
	add_child(menu_box)

	var hint := UIKit.label("방향키: 선택   Z: 결정", 10, UIKit.COL_DIM)
	hint.size = Vector2(640, 16)
	hint.position = Vector2(0, 330)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	var ver := UIKit.label("v1.0 · Godot 4", 9, Color(1, 1, 1, 0.35))
	ver.position = Vector2(8, 342)
	add_child(ver)

	# 저장소 링크(마우스 클릭 전용, 키보드 메뉴 포커스에는 끼어들지 않음)
	var repo := LinkButton.new()
	repo.text = "GitHub"
	repo.uri = REPO_URL
	repo.tooltip_text = "GitHub 저장소 열기"
	repo.focus_mode = Control.FOCUS_NONE
	repo.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	repo.add_theme_font_override("font", load(UIKit.FONT_SMALL))
	repo.add_theme_font_size_override("font_size", 9)
	repo.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	repo.add_theme_color_override("font_hover_color", UIKit.COL_ACCENT)
	repo.add_theme_color_override("font_pressed_color", UIKit.COL_ACCENT)
	add_child(repo)
	repo.position = Vector2(640 - 8 - repo.get_combined_minimum_size().x, 340)

func _process(delta: float) -> void:
	_t += delta
	if _flame != null:
		var s := 1.0 + sin(_t * 5.0) * 0.18
		_flame.scale = Vector2(s, s)
		_flame.position = Vector2(532, 154) - Vector2(8, 8) * s
		_flame_core.position = Vector2(533, 157) - Vector2(3, 3) * s

func _refresh() -> void:
	for i in _labels.size():
		var l: Label = _labels[i]
		if i == _sel:
			l.text = "▶ " + _options[i]
			l.add_theme_color_override("font_color", Color("ffc857"))
		else:
			l.text = "  " + _options[i]
			l.add_theme_color_override("font_color", Color.WHITE if i != 1 or _save_exists else Color(1, 1, 1, 0.35))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_sel = (_sel + _options.size() - 1) % _options.size()
		Audio.play_sfx("cursor")
		_refresh()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % _options.size()
		Audio.play_sfx("cursor")
		_refresh()
	elif event.is_action_pressed("confirm"):
		_confirm()

func _confirm() -> void:
	var main := get_parent()
	match _sel:
		0:
			Audio.play_sfx("confirm")
			GameState.new_game()
			main.goto_explore()
		1:
			if not _save_exists:
				Audio.play_sfx("cancel")
				return
			Audio.play_sfx("confirm")
			SaveManager.load_game()
			main.goto_explore()
		2:
			get_tree().quit()
