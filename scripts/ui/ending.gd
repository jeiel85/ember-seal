extends Node2D
## Ending — 엔딩 크레딧 스크롤. Z로 빨리감기, 끝나면 타이틀로.

var _lines := [
	"",
	"잿불검이 화로에 꽂히자,",
	"봉인의 심장이 새로운 불이 되어 타올랐다.",
	"",
	"재의 군주는 다시 잠들지 않았다.",
	"태워 없어졌으니까.",
	"",
	"골짜기에 백 년 묵은 순환이 끝났다.",
	"",
	"— 잿불마을 —",
	"룬은 대장간을 다시 열었다.",
	"이제 검을 벼리는 소리가 마을을 채운다.",
	"",
	"세라는 아버지의 등불을 받아",
	"새 등대 지기가 되었다.",
	"등대의 불은 이제 누구도 먹이지 않는,",
	"그저 밝은 불이다.",
	"",
	"— 여울마을 —",
	"아이리는 골짜기의 전승을 책으로 남겼다.",
	"「우리는 봉인하지 않는다. 우리는 함께 산다.」",
	"",
	"카일은 다시 여행을 떠났다.",
	"언젠가 세라의 등대에 들르겠다고.",
	"",
	"",
	"= THE END =",
	"",
	"잿불의 인장 — The Ember Seal",
	"",
	"기획 · 프로그래밍 · 그래픽 · 사운드",
	"OpenGame Project",
	"",
	"Engine: Godot 4 / GDScript",
	"모든 그래픽과 사운드는 런타임 절차 생성입니다.",
	"",
	"플레이해 주셔서 감사합니다.",
	"",
]

var _scroll: Control
var _speed := 22.0
var _done := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c0a14")
	bg.size = Vector2(640, 360)
	add_child(bg)

	_scroll = Control.new()
	_scroll.position = Vector2(0, 360)
	add_child(_scroll)
	var y := 0.0
	for line in _lines:
		var is_title: bool = line.begins_with("= THE END") or line.begins_with("잿불의 인장")
		var l := UIKit.label(line, 15 if is_title else 12, Color("ffc857") if is_title else Color("d8d0c8"))
		l.size = Vector2(640, 24)
		l.position = Vector2(0, y)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scroll.add_child(l)
		y += 26.0 if not line.is_empty() else 14.0
	y += 40.0
	var hint := UIKit.label("Z: 빨리감기", 10, Color(1, 1, 1, 0.4))
	hint.position = Vector2(560, 344)
	add_child(hint)
	_scroll.set_meta("height", y)

func _process(delta: float) -> void:
	if _done:
		return
	_scroll.position.y -= _speed * delta
	var total: float = _scroll.get_meta("height")
	if _scroll.position.y < -total + 200.0:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("cancel"):
		if _speed < 200.0:
			_speed = 260.0
			Audio.play_sfx("cursor")
		else:
			_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	Audio.stop_bgm()
	Events.request_title.emit()
