extends Node
## 자동 테스트 러너 — 데이터 무결성 / 맵 검증 / 성장 / 세이브 / 전투 시뮬레이션 / 스토리 전체 플레이스루.
## 실행: godot --headless --path . res://test/test_runner.tscn
## 종료 코드: 실패 수 (0 = 통과)

var failures := 0
var _battle_queue: Array = []
var _ending_reached := false
var _battle_result := ""
var _current_scene: Node = null

func _ready() -> void:
	print("=== 잿불의 인장 자동 테스트 ===")
	_test_data_integrity()
	_test_maps()
	_test_progression()
	_test_save_roundtrip()
	await _test_all_battles()
	await _test_story_flow()
	print("=== 테스트 종료: 실패 %d건 ===" % failures)
	get_tree().quit(failures)

func _fail(msg: String) -> void:
	failures += 1
	print("  [FAIL] " + msg)

func _ok(msg: String) -> void:
	print("  [ok] " + msg)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok(msg)
	else:
		_fail(msg)

func _process(_delta: float) -> void:
	# 대화 자동 스킵
	if Dialog.active:
		Dialog._advance()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _switch(path: String) -> Node:
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null
	var ps: PackedScene = load(path)
	_current_scene = ps.instantiate()
	add_child(_current_scene)
	return _current_scene

func _clear_scene() -> void:
	if _current_scene != null:
		_current_scene.queue_free()
		_current_scene = null

func _on_test_battle(battle_id: String) -> void:
	_battle_queue.append(battle_id)

# ---------------------------------------------------------------- 데이터 무결성

func _test_data_integrity() -> void:
	print("-- 데이터 무결성")
	for cid in DB.characters:
		var c: Dictionary = DB.characters[cid]
		for lv in c.get("skills", {}):
			if not DB.skills.has(c["skills"][lv]):
				_fail("캐릭터 %s 스킬 없음: %s" % [cid, c["skills"][lv]])
		for key in ["hp", "atk", "def", "mov", "rng"]:
			if not c.get("base", {}).has(key):
				_fail("캐릭터 %s base.%s 누락" % [cid, key])
	_ok("캐릭터 %d종 검사" % DB.characters.size())
	for eid in DB.enemies:
		var e: Dictionary = DB.enemies[eid]
		if not PixelArt.ENEMY_ART.has(e.get("sprite", "")):
			_fail("적 %s 스프라이트 없음: %s" % [eid, e.get("sprite")])
		if e.has("skill") and not DB.skills.has(e["skill"]):
			_fail("적 %s 스킬 없음: %s" % [eid, e["skill"]])
	_ok("적 %d종 검사" % DB.enemies.size())
	for bid in DB.battles:
		var b: Dictionary = DB.battles[bid]
		var rows: Array = b.get("tiles", [])
		if rows.is_empty():
			_fail("전투 %s 타일 누락" % bid)
			continue
		var w: int = (rows[0] as String).length()
		for r in rows:
			if (r as String).length() != w:
				_fail("전투 %s 행 길이 불일치" % bid)
				break
		for e in b.get("enemies", []):
			if not DB.enemies.has(e["enemy"]):
				_fail("전투 %s 적 없음: %s" % [bid, e["enemy"]])
	_ok("전투 %d종 검사" % DB.battles.size())
	for sid in DB.shops:
		for item in DB.shops[sid].get("stock", []):
			if not DB.items.has(item) and not DB.equipment.has(item):
				_fail("상점 %s 상품 없음: %s" % [sid, item])
	_ok("상점 %d종 검사" % DB.shops.size())
	var table: Array = DB.levels.get("exp_table", [])
	for i in range(1, table.size()):
		if int(table[i]) <= int(table[i - 1]):
			_fail("경험치 테이블 단조 증가 아님 (idx %d)" % i)
	_ok("경험치 테이블 %d단계" % table.size())

# ---------------------------------------------------------------- 맵 검증

func _map_walkable(mdef: Dictionary, x: int, y: int) -> bool:
	var rows: Array = mdef["tiles"]
	if y < 0 or y >= rows.size():
		return false
	var row: String = rows[y]
	if x < 0 or x >= row.length():
		return false
	return not (mdef["blocked"] as String).contains(row[x])

func _test_maps() -> void:
	print("-- 맵 검증")
	for mid in DB.maps:
		var m: Dictionary = DB.maps[mid]
		var rows: Array = m.get("tiles", [])
		var w: int = (rows[0] as String).length()
		for r in rows:
			if (r as String).length() != w:
				_fail("맵 %s 행 길이 불일치" % mid)
				break
		var ps: Dictionary = m["player_start"]
		if not _map_walkable(m, int(ps["x"]), int(ps["y"])):
			_fail("맵 %s 시작점이 막힘" % mid)
		for npc in m.get("npcs", []):
			if not _map_walkable(m, int(npc["x"]), int(npc["y"])):
				_fail("맵 %s NPC %s 위치 막힘" % [mid, npc.get("id")])
			for entry in npc.get("dialog", []):
				if entry.has("join") and not DB.characters.has(entry["join"]):
					_fail("맵 %s 합류 캐릭터 없음: %s" % [mid, entry["join"]])
				if entry.has("give_equip") and not DB.equipment.has(entry["give_equip"]):
					_fail("맵 %s 장비 없음: %s" % [mid, entry["give_equip"]])
				if entry.has("give_item") and not DB.items.has(entry["give_item"]):
					_fail("맵 %s 아이템 없음: %s" % [mid, entry["give_item"]])
				if entry.has("take_item") and not DB.items.has(entry["take_item"]):
					_fail("맵 %s 아이템 없음: %s" % [mid, entry["take_item"]])
		for ch in m.get("chests", []):
			if not _map_walkable(m, int(ch["x"]), int(ch["y"])):
				_fail("맵 %s 상자 위치 막힘" % mid)
			if ch.has("item") and not DB.items.has(ch["item"]) and not DB.equipment.has(ch["item"]):
				_fail("맵 %s 상자 아이템 없음: %s" % [mid, ch["item"]])
		for fe in m.get("field_enemies", []):
			if not _map_walkable(m, int(fe["x"]), int(fe["y"])):
				_fail("맵 %s 필드적 위치 막힘" % mid)
			if not DB.battles.has(fe["battle"]):
				_fail("맵 %s 전투 없음: %s" % [mid, fe["battle"]])
		for ex in m.get("exits", []):
			if not _map_walkable(m, int(ex["x"]), int(ex["y"])):
				_fail("맵 %s 출구 위치 막힘 (%d,%d)" % [mid, int(ex["x"]), int(ex["y"])])
			var to: String = ex["to"]
			if not DB.maps.has(to):
				_fail("맵 %s → 존재하지 않는 맵: %s" % [mid, to])
				continue
			var tm: Dictionary = DB.maps[to]
			if not _map_walkable(tm, int(ex["tx"]), int(ex["ty"])):
				_fail("맵 %s → %s 도착점 막힘 (%d,%d)" % [mid, to, int(ex["tx"]), int(ex["ty"])])
		for ev in m.get("events", []):
			if ev.has("x") and not _map_walkable(m, int(ev["x"]), int(ev["y"])):
				_fail("맵 %s 이벤트 %s 위치 막힘" % [mid, ev.get("id")])
			if ev.has("tiles"):
				for t in ev["tiles"]:
					if not _map_walkable(m, int(t[0]), int(t[1])):
						_fail("맵 %s 이벤트 %s 타일 막힘" % [mid, ev.get("id")])
			if ev.has("battle") and not DB.battles.has(ev["battle"]):
				_fail("맵 %s 이벤트 전투 없음: %s" % [mid, ev["battle"]])
	_ok("맵 %d개 검사" % DB.maps.size())
	var required_chain := {
		"village1": ["field1", "lighthouse_out"],
		"field1": ["village1", "field2"],
		"village2": ["field2"],
		"field2": ["village2", "dungeon", "field1"],
		"dungeon": ["field2"],
		"lighthouse_out": ["village1", "lighthouse_top"],
		"lighthouse_top": ["lighthouse_out"],
	}
	for mid in required_chain:
		var dests: Array = []
		for ex in DB.maps[mid].get("exits", []):
			dests.append(ex["to"])
		for d in required_chain[mid]:
			if not dests.has(d):
				_fail("맵 %s에 %s로 가는 출구 없음" % [mid, d])
	_ok("지역 연결성 검사")

# ---------------------------------------------------------------- 성장/스탯

func _test_progression() -> void:
	print("-- 성장/스탯")
	GameState.new_game()
	var rune: Dictionary = GameState.party[0]
	if GameState.max_hp(rune) != 30 + 2:
		_fail("룬 초기 HP 계산 오류: %d" % GameState.max_hp(rune))
	if GameState.atk(rune) != 8 + 2:
		_fail("룬 초기 공격력 계산 오류: %d" % GameState.atk(rune))
	var leveled := GameState.gain_exp(rune, 30)
	if int(rune["level"]) != 2 or leveled.is_empty():
		_fail("레벨업 실패: lv=%d" % int(rune["level"]))
	GameState.gain_exp(rune, 40)  # 누적 70 → lv3
	if not GameState.known_skills(rune).has("power_swing"):
		_fail("Lv3 스킬 power_swing 미습득")
	GameState.gain_exp(rune, 10000)
	if int(rune["level"]) != DB.max_level():
		_fail("만렙 도달 실패: %d" % int(rune["level"]))
	GameState.add_item("potion", 2)
	GameState.remove_item("potion", 1)
	if GameState.item_count("potion") != 4:  # 초기 3 + 2 - 1
		_fail("아이템 수량 오류: %d" % GameState.item_count("potion"))
	if GameState.remove_item("potion", 5):
		_fail("부족 수량 제거가 거부되지 않음")
	var old := GameState.equip_item(rune, "w_ember_sword")
	if old != "w_old_sword":
		_fail("장비 교체 반환 오류: %s" % old)
	var expected_atk := 8 + int(round(1.6 * 9)) + 4
	if GameState.atk(rune) != expected_atk:
		_fail("만렙 공격력 계산: %d (기대 %d)" % [GameState.atk(rune), expected_atk])
	_ok("성장/스탯/아이템/장비")

# ---------------------------------------------------------------- 세이브

func _test_save_roundtrip() -> void:
	print("-- 세이브 왕복")
	GameState.new_game()
	GameState.stage = 4
	GameState.set_flag("test_flag")
	GameState.add_item("hi_potion", 3)
	GameState.add_gold(500)
	GameState.add_member("sera", 2)
	GameState.current_map = "field1"
	GameState.player_pos = Vector2i(12, 8)
	GameState.opened_chests["field1"] = ["0"]
	GameState.defeated_field_enemies["field1"] = ["0"]
	GameState.objective = "테스트 목표"
	if not SaveManager.save_game():
		_fail("세이브 저장 실패")
		return
	GameState.new_game()
	if not SaveManager.load_game():
		_fail("세이브 로드 실패")
		return
	_check(GameState.stage == 4, "stage 복원")
	_check(GameState.has_flag("test_flag"), "플래그 복원")
	_check(GameState.item_count("hi_potion") == 3, "아이템 복원")
	_check(GameState.gold == 620, "골드 복원 (초기 120 + 500)")
	_check(GameState.has_member("sera"), "파티 복원")
	_check(GameState.current_map == "field1" and GameState.player_pos == Vector2i(12, 8), "위치 복원")
	_check((GameState.opened_chests.get("field1", []) as Array).size() == 1, "상자 기록 복원")
	_check(GameState.objective == "테스트 목표", "목표 복원")
	var rune: Dictionary = GameState.member("rune")
	_check(int(rune["level"]) == 1, "멤버 레벨 복원")
	_ok("세이브/로드 왕복")

# ---------------------------------------------------------------- 전투 시뮬레이션

func _setup_party(levels: Array, member_count: int) -> void:
	GameState.new_game()
	var ids := ["rune", "sera", "iris", "kale"]
	GameState.party[0]["level"] = levels[0]
	GameState.party[0]["exp"] = DB.exp_for_level(levels[0])
	for i in range(1, member_count):
		GameState.add_member(ids[i], levels[i])
	GameState.full_heal()

func _test_all_battles() -> void:
	print("-- 전투 시뮬레이션 (실제 씬 + AI)")
	var cases := [
		["b_tutorial", [2], 1],
		["b_field1a", [3, 3], 2],
		["b_boss1", [3, 3], 2],
		["b_field2a", [4, 4], 2],
		["b_field2b", [5, 5], 2],
		["b_dungeon_a", [5, 5, 5, 5], 4],
		["b_dungeon_b", [5, 5, 5, 5], 4],
		["b_midboss", [6, 6, 6, 6], 4],
		["b_act3a", [7, 7, 7, 7], 4],
		["b_act3b", [7, 7, 7, 7], 4],
		["b_final", [8, 8, 8, 8], 4],
	]
	for c in cases:
		_setup_party(c[1], c[2])
		var res := await _sim_core(c[0])
		_check(res == "win", "%s 승리 (파티 %s, 결과 %s)" % [c[0], str(c[1]), res])
	_clear_scene()

func _sim_core(battle_id: String) -> String:
	_battle_result = ""
	var cb := func(r: String) -> void: _battle_result = r
	Events.battle_finished.connect(cb)
	Battle.pending_battle_id = battle_id
	var b: Battle = _switch("res://scenes/battle/battle.tscn")
	await _wait(0.3)
	var elapsed := 0.0
	while _battle_result == "" and elapsed < 240.0:
		await _wait(0.1)
		elapsed += 0.1
		if is_instance_valid(b) and b.st == Battle.St.SELECT:
			await _sim_player_turn(b)
	Events.battle_finished.disconnect(cb)
	if _battle_result == "":
		return "timeout"
	return _battle_result

func _sim_player_turn(b: Battle) -> void:
	var u = null
	for p in b._alive("p"):
		if not p["done"]:
			u = p
			break
	if u == null:
		b._end_player_turn()
		await _wait(0.1)
		return
	b.sel = u
	b.sel_origin = u["grid"]
	b.move_range = b.reachable(u)
	var enemies := b._alive("e")
	if enemies.is_empty():
		return
	var best_tile: Vector2i = u["grid"]
	var best_d := 9999
	for t in b.move_range:
		var dmin := 9999
		for e in enemies:
			dmin = mini(dmin, b._mdist(t, e["grid"]))
		if dmin < best_d:
			best_d = dmin
			best_tile = t
	await b._move_unit(u, best_tile)
	var targets := b._targets_from(u, u["grid"], "e")
	if not targets.is_empty():
		var target = targets[0]
		var used_skill := false
		for sk_id in u["skills"]:
			var sk: Dictionary = DB.skill(sk_id)
			var used := int(u["skill_uses"].get(sk_id, 0))
			if sk["kind"] == "attack" and (int(sk.get("uses", -1)) < 0 or used < int(sk["uses"])):
				if b._mdist(u["grid"], target["grid"]) <= int(sk["range"]):
					await b._exec_skill(u, sk_id, target)
					used_skill = true
					break
		if not used_skill:
			await b._exec_attack(u, target)
	b._finish_player_action()
	await _wait(0.05)

# ---------------------------------------------------------------- 스토리 전체 플레이스루

func _wait_explore(ex: Node, timeout := 40.0) -> bool:
	var t := 0.0
	while t < timeout:
		if is_instance_valid(ex) and ex.get("busy") != null and not ex.busy and not Dialog.active:
			return true
		await _wait(0.1)
		t += 0.1
	_fail("탐험 대기 시간 초과")
	return false

func _drain_battles() -> void:
	while not _battle_queue.is_empty():
		var bid: String = _battle_queue.pop_front()
		var res := await _sim_core(bid)
		_check(res == "win", "스토리 전투 %s → %s" % [bid, res])
		if res != "win":
			return
		# 현실적인 플레이 모델: 전투 사이에 파티를 정비한다
		GameState.full_heal()
		var ex: Node = _switch("res://scenes/explore/explore.tscn")
		await _wait_explore(ex)

func _find_event(ex: Node, id: String) -> Dictionary:
	for ev in ex.map_def.get("events", []):
		if ev.get("id", "") == id:
			return ev
	return {}

func _test_story_flow() -> void:
	print("-- 스토리 전체 플레이스루 (새 게임 → 엔딩)")
	Events.battle_requested.connect(_on_test_battle)
	Events.request_ending.connect(func() -> void: _ending_reached = true)
	GameState.new_game()
	var ex: Node = _switch("res://scenes/explore/explore.tscn")
	await _wait_explore(ex)
	_check(GameState.stage == 0, "프롤로그 이벤트 실행 (stage 0)")

	# ACT 1 — 장로 대화 → stage 1
	await ex._talk_to(Vector2i(4, 5))
	await _wait_explore(ex)
	_check(GameState.stage == 1, "장로 대화 → stage 1")

	# field1 진입 → 세라 합류 + 튜토리얼 전투
	await ex._do_move_map("field1", 12, 14)
	await _wait_explore(ex)
	await _drain_battles()
	ex = _current_scene
	_check(GameState.has_member("sera"), "세라 합류")
	_check(GameState.stage == 2, "튜토리얼 후 stage 2")

	# 필드 적 (재식물)
	await ex._start_field_battle(Vector2i(12, 8))
	await _drain_battles()
	ex = _current_scene
	_check(GameState.battles_won == 2, "필드 전투 승리 누적")

	# 보스 (흙 파수꾼) → 유서 → stage 3
	await ex._start_field_battle(Vector2i(12, 3))
	await _drain_battles()
	ex = _current_scene
	_check(GameState.stage == 3, "보스 격파 → stage 3")
	_check(GameState.item_count("old_lantern") == 1, "오랜 등불 획득")

	# 마을 복귀 → 장로 보고 → 잿불검 → stage 4
	await ex._do_move_map("village1", 10, 14)
	await _wait_explore(ex)
	await ex._talk_to(Vector2i(4, 5))
	await _wait_explore(ex)
	_check(GameState.stage == 4, "장로 보고 → stage 4")
	_check(GameState.item_count("w_ember_sword") == 1, "잿불검 획득")

	# 상점 구매 테스트
	var gold_before := GameState.gold
	ex.shop_layer.open("v1_store")
	ex.shop_layer._buy()
	_check(GameState.gold < gold_before, "상점 구매 처리")
	ex.shop_layer.visible = false
	ex.shop_layer.closed.emit()

	# field1 → field2 → village2
	await ex._do_move_map("field1", 12, 14)
	await _wait_explore(ex)
	await ex._do_move_map("field2", 12, 15)
	await _wait_explore(ex)
	await ex._do_move_map("village2", 10, 14)
	await _wait_explore(ex)

	# ACT 2 — 아이리 합류 (stage 5) + 카일 합류
	await ex._talk_to(Vector2i(13, 5))
	await _wait_explore(ex)
	_check(GameState.has_member("iris"), "아이리 합류")
	_check(GameState.stage == 5, "아이리 합류 → stage 5")
	_check(GameState.has_flag("quest_herb"), "약초 퀘스트 수주")
	await ex._talk_to(Vector2i(12, 11))
	await _wait_explore(ex)
	_check(GameState.has_member("kale"), "카일 합류")

	# 귀걸이 퀘스트 수주 (수안)
	await ex._talk_to(Vector2i(5, 7))
	await _wait_explore(ex)
	_check(GameState.has_flag("quest_earring"), "귀걸이 퀘스트 수주")

	# field2로 이동 — 약초 채집 + 귀걸이 상자 + 늑대 전투
	await ex._do_move_map("field2", 12, 14)
	await _wait_explore(ex)
	var herb_ev := _find_event(ex, "moon_herb")
	_check(not herb_ev.is_empty(), "약초 이벤트 존재")
	await ex.run_actions(herb_ev["actions"])
	await _wait_explore(ex)
	_check(GameState.item_count("moon_herb") == 1, "달빛 약초 채집")
	await ex._open_chest(Vector2i(22, 10))
	_check(GameState.item_count("lost_earring") == 1, "귀걸이 발견")
	await ex._start_field_battle(Vector2i(12, 8))
	await _drain_battles()
	ex = _current_scene

	# village2 복귀 — 퀘스트 완료 보고
	await ex._do_move_map("village2", 10, 14)
	await _wait_explore(ex)
	await ex._talk_to(Vector2i(13, 5))
	await _wait_explore(ex)
	_check(GameState.has_flag("quest_herb_done"), "약초 퀘스트 완료")
	_check(GameState.item_count("hi_potion") >= 2, "퀘스트 보상 지급")
	await ex._talk_to(Vector2i(5, 7))
	await _wait_explore(ex)
	_check(GameState.has_flag("quest_earring_done"), "귀걸이 퀘스트 완료")
	_check(GameState.item_count("t_power_ring") == 1, "힘의 반지 보상")

	# 던전 진입
	await ex._do_move_map("field2", 12, 14)
	await _wait_explore(ex)
	await ex._do_move_map("dungeon", 10, 17)
	await _wait_explore(ex)
	await ex._start_field_battle(Vector2i(10, 12))
	await _drain_battles()
	ex = _current_scene

	# 던전 상자 (은빛 지팡이)
	await ex._open_chest(Vector2i(2, 10))
	_check(GameState.item_count("w_silver_staff") == 1, "은빛 지팡이 획득")

	# 중간 보스 → 진실 공개 → stage 7
	var mid_ev := _find_event(ex, "midboss")
	_check(not mid_ev.is_empty(), "중간보스 이벤트 존재")
	await ex.run_actions(mid_ev["actions"])
	await _drain_battles()
	ex = _current_scene
	_check(GameState.stage == 7, "중간보스 후 stage 7")

	# ACT 3 — field2 → field1(서쪽 연결) → village1 → 등대
	await ex._do_move_map("field2", 12, 1)
	await _wait_explore(ex)
	await ex._do_move_map("field1", 24, 8)
	await _wait_explore(ex)
	await ex._do_move_map("village1", 10, 1)
	await _wait_explore(ex)
	await ex._do_move_map("lighthouse_out", 12, 12)
	await _wait_explore(ex)

	# 재의 기사
	await ex._start_field_battle(Vector2i(12, 8))
	await _drain_battles()
	ex = _current_scene

	# 등대 상자
	await ex._open_chest(Vector2i(20, 3))
	_check(GameState.item_count("a_ash_mantle") == 1, "잿불 망토 획득")

	# 등대 정상 → 최종보스 → 엔딩
	await ex._do_move_map("lighthouse_top", 7, 9)
	await _wait_explore(ex)
	var fin_ev := _find_event(ex, "final")
	_check(not fin_ev.is_empty(), "최종 이벤트 존재")
	await ex.run_actions(fin_ev["actions"])
	await _drain_battles()
	ex = _current_scene
	await _wait_explore(ex)
	_check(_ending_reached, "엔딩 도달")

	# 최종 상태 점검
	var lv := int(GameState.member("rune")["level"])
	print("  최종 파티: ")
	for m in GameState.party:
		print("    %s Lv%d HP %d/%d" % [GameState.name_of(m), int(m["level"]), int(m["hp"]), GameState.max_hp(m)])
	_check(lv >= 6 and lv <= 9, "주인공 엔딩 레벨 적정 (%d)" % lv)
	_check(GameState.battles_won >= 8, "전투 횟수 적정 (%d)" % GameState.battles_won)
	Events.battle_requested.disconnect(_on_test_battle)
	_clear_scene()
