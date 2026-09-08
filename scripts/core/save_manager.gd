extends Node
## SaveManager — user://save.json 에 게임 상태를 저장/복원.

const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	GameState.play_time = _elapsed()
	var d := GameState.to_dict()
	d["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("세이브 실패: " + str(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("party"):
		GameState.from_dict(parsed)
		return true
	push_error("세이브 로드 실패")
	return false

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func save_info() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

# 플레이 시간 누적(세션)
var _session_start := 0.0

func _ready() -> void:
	_session_start = Time.get_ticks_msec() / 1000.0

func _elapsed() -> float:
	return GameState.play_time + (Time.get_ticks_msec() / 1000.0 - _session_start)

func play_time_text() -> String:
	var t := int(_elapsed())
	return "%d:%02d" % [t / 3600, (t % 3600) / 60]
