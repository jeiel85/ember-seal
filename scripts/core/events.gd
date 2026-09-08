extends Node
## 전역 이벤트 버스 — 씬/시스템 간 통신의 유일한 통로.

signal dialog_requested(speaker: String, lines: Array, portrait: String)
signal dialog_finished
signal notify_requested(text: String)
signal battle_requested(battle_id: String)
signal battle_finished(result: String) # "win" | "lose"
signal map_change_requested(map_id: String, x: int, y: int)
signal gold_changed
signal inventory_changed
signal party_changed
signal menu_requested
signal open_menu
signal request_title
signal request_ending
signal request_gameover
