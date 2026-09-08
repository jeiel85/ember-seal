extends Node
## 스크린샷 캡처 러너 — 주요 화면을 렌더링해 PNG로 저장 (시각 검증 + README 용).
## 실행: godot --path . res://test/screenshot.tscn

const OUT_DIR := "res://shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _run()
	get_tree().quit()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _switch(path: String) -> Node:
	for c in get_children():
		c.queue_free()
	var ps: PackedScene = load(path)
	var n: Node = ps.instantiate()
	add_child(n)
	return n

func _shot(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "/" + fname))
	print("shot: " + fname)

func _run() -> void:
	# 1. 타이틀
	_switch("res://scenes/ui/title.tscn")
	await _wait(0.6)
	await _shot("01_title.png")

	# 2. 마을 탐험
	GameState.new_game()
	var ex: Node = _switch("res://scenes/explore/explore.tscn")
	await _wait(1.2)
	await _shot("02_village.png")

	# 3. 대화창
	Events.dialog_requested.emit("장로 하란", ["등대의 봉화가 꺼졌다. 백 년 동안 한 번도 꺼진 적이 없던 불이 말이야."])
	await _wait(0.9)
	await _shot("03_dialog.png")
	while Dialog.active:
		Dialog._advance()
	await _wait(0.2)

	# 4. 메뉴
	ex.menu_layer.open()
	await _wait(0.4)
	await _shot("04_menu.png")
	ex.menu_layer.close()
	await _wait(0.2)

	# 5. 전투 (보스) — 인트로 대화 상태
	GameState.add_member("sera", 3)
	Battle.pending_battle_id = "b_boss1"
	Battle.pending_context = {}
	var b: Node = _switch("res://scenes/battle/battle.tscn")
	await _wait(0.8)
	await _shot("05_battle_intro.png")
	var guard := 0
	while Dialog.active and guard < 20:
		Dialog._advance()
		guard += 1
		await _wait(0.1)
	await _wait(0.5)
	await _shot("06_battle.png")

	# 6. 이동 범위 표시 상태
	if is_instance_valid(b) and b.st == Battle.St.SELECT:
		var u = b._alive("p")[0]
		b.cursor = u["grid"]
		b.cursor_node.position = Vector2(u["grid"].x * 32, u["grid"].y * 32)
		b.sel = u
		b.sel_origin = u["grid"]
		b.move_range = b.reachable(u)
		b.st = Battle.St.MOVE
		b._show_move_hl()
		await _wait(0.3)
		await _shot("07_battle_move.png")

	# 7. 엔딩
	_switch("res://scenes/ui/ending.tscn")
	await _wait(0.6)
	await _shot("08_ending.png")
