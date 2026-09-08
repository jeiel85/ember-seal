extends Node
## 字体映射对照测试 — 字符串从 data/texts.json 读取，避免源码污染。

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("141020")
	bg.size = Vector2(640, 360)
	add_child(bg)
	var s1: String = str(DB.texts.get("new_game", ""))          # 새 게임
	var s2: String = str(DB.texts.get("act1", ""))              # 제1장 · 꺼진 봉화
	var s3: String = str(DB.texts.get("how_to_move", ""))       # 방향키/WASD: 이동 ...
	var rows := [
		["BMP:", s1, 11, "res://fonts/galmuri11_bmp.fnt"],
		["BMP2:", s2, 11, "res://fonts/galmuri11_bmp.fnt"],
		["TTF:", s1, 11, "res://fonts/Galmuri11.ttf"],
		["TTF44:", s1, 44, "res://fonts/Galmuri11.ttf"],
		["BMP3:", s3, 11, "res://fonts/galmuri11_bmp.fnt"],
	]
	var y := 14.0
	for r in rows:
		var tag := UIKit.label(str(r[0]), 9, Color(0.6, 0.6, 0.7))
		tag.position = Vector2(10, y)
		add_child(tag)
		var l := UIKit.label(str(r[1]), int(r[2]))
		l.position = Vector2(90, y)
		add_child(l)
		y += 62
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shots/font_test.png")
	print("font test saved")
	get_tree().quit()
