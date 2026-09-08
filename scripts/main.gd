extends Node
## Main — 씬 전환 관리자. 타이틀/탐험/전투/엔딩/게임오버를 교체한다.

var current: Node = null

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://fonts/galmuri11_bmp.fnt")
	theme.default_font_size = 11
	get_window().theme = theme

	Events.battle_requested.connect(_on_battle_requested)
	Events.battle_finished.connect(_on_battle_finished)
	Events.request_title.connect(goto_title)
	Events.request_ending.connect(goto_ending)
	Events.request_gameover.connect(goto_gameover)
	goto_title()

func _switch(path: String) -> void:
	if current != null:
		current.queue_free()
		current = null
	var ps: PackedScene = load(path)
	current = ps.instantiate()
	add_child(current)

func goto_title() -> void:
	Audio.play_bgm("title")
	_switch("res://scenes/ui/title.tscn")

func goto_explore() -> void:
	_switch("res://scenes/explore/explore.tscn")

func goto_ending() -> void:
	Audio.play_bgm("ending")
	_switch("res://scenes/ui/ending.tscn")

func goto_gameover() -> void:
	Audio.play_bgm("gameover")
	_switch("res://scenes/ui/game_over.tscn")

func _on_battle_requested(battle_id: String) -> void:
	Battle.pending_battle_id = battle_id
	_switch("res://scenes/battle/battle.tscn")

func _on_battle_finished(result: String) -> void:
	if result == "win":
		goto_explore()
	else:
		goto_gameover()
