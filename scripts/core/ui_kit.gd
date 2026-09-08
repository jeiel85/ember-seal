class_name UIKit
## UI 공통 스타일 헬퍼 — 픽셀 감성의 패널/라벨 생성.

const COL_BORDER := Color("e8e0d0")
const COL_ACCENT := Color("ff9a3c")
const COL_DIM := Color("b8b0a8")
const COL_HP := Color("5ac86a")
const COL_HP_LOW := Color("e05a5a")
const COL_MOVE := Color("4a8aff")
const COL_ATK := Color("ff5a4a")
const COL_HEAL := Color("5aff9a")

## 小字用 9px 位图字体，其余用 11px 位图字体；字号对齐到设计尺寸的整数倍，
## 保证最近邻缩放不破坏像素字形（11→22→33）。
const FONT_SMALL := "res://fonts/galmuri9_bmp.fnt"
const FONT_MAIN := "res://fonts/galmuri11_bmp.fnt"

static func panel_style(border: Color = COL_BORDER, bg: Color = Color(0.07, 0.06, 0.11, 0.94)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	return sb

static func label(text: String, size: int = 11, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	if size <= 10:
		l.add_theme_font_override("font", load(FONT_SMALL))
		l.add_theme_font_size_override("font_size", 9)
	elif size <= 16:
		l.add_theme_font_override("font", load(FONT_MAIN))
		l.add_theme_font_size_override("font_size", 11)
	elif size <= 27:
		l.add_theme_font_override("font", load(FONT_MAIN))
		l.add_theme_font_size_override("font_size", 22)
	else:
		l.add_theme_font_override("font", load(FONT_MAIN))
		l.add_theme_font_size_override("font_size", 33)
	l.add_theme_color_override("font_color", color)
	return l

static func vspace(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c

static func hline(color: Color = Color(1, 1, 1, 0.25)) -> Control:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, 1)
	return c

static func hp_bar(width: int, height: int, ratio: float) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(width, height)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = Vector2(width, height)
	root.add_child(bg)
	var fill := ColorRect.new()
	fill.color = COL_HP if ratio > 0.3 else COL_HP_LOW
	fill.size = Vector2(maxi(1, int(width * clampf(ratio, 0.0, 1.0))), height)
	root.add_child(fill)
	return root
