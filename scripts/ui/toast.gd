extends CanvasLayer
## Toast — 화면 상단에 짧은 알림을 표시 (아이템 획득, 레벨업 등).

var _label: Label
var _queue: Array = []
var _timer := 0.0

func _ready() -> void:
	layer = 70
	_label = UIKit.label("", 11, Color("fff3b0"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 3)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_top = 10
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_label.visible = false
	Events.notify_requested.connect(show_toast)

func show_toast(text: String) -> void:
	_queue.append(text)

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			_label.visible = false
	elif not _queue.is_empty():
		_label.text = _queue.pop_front()
		_label.visible = true
		_timer = 1.8
