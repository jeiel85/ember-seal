extends Node
## Audio — 외부 에셋 없이 런타임에서 효과음/BGM을 합성한다.
## 모든 사운드는 22050Hz 16bit 모노 WAV로 절차 생성.

const SR := 22050

var _sfx: Dictionary = {}
var _bgm: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _current_bgm: String = ""
var master_volume: float = 0.8

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -6.0
	add_child(_bgm_player)
	_build_sfx()
	_build_bgm()
	_apply_volume()

func _apply_volume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(idx, master_volume <= 0.001)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()

# ---------------------------------------------------------------- 효과음

func play_sfx(id: String) -> void:
	if not _sfx.has(id):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _sfx[id]
	p.volume_db = -4.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

# ---------------------------------------------------------------- BGM

func play_bgm(id: String) -> void:
	if _current_bgm == id and _bgm_player.playing:
		return
	_current_bgm = id
	if not _bgm.has(id):
		_bgm_player.stop()
		return
	_bgm_player.stream = _bgm[id]
	_bgm_player.play()

func stop_bgm() -> void:
	_current_bgm = ""
	_bgm_player.stop()

# ---------------------------------------------------------------- 합성 코어

func _alloc(seconds: float) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(int(seconds * SR) * 2)
	return buf

func _tone(buf: PackedByteArray, start_s: float, dur_s: float, freq: float, wave: int, vol: float, slide_to: float = -1.0) -> void:
	var start := int(start_s * SR)
	var n := int(dur_s * SR)
	if n <= 0 or start >= buf.size() / 2:
		return
	var attack := mini(int(0.004 * SR), n / 2)
	var release := mini(int(0.03 * SR), n / 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var f := freq
		if slide_to > 0.0:
			f = lerpf(freq, slide_to, float(i) / n)
		phase += f * TAU / SR
		var v := 0.0
		match wave:
			0: v = signf(sin(phase))            # square
			1: v = 2.0 / PI * asin(sin(phase))  # triangle
			2: v = sin(phase)                   # sine
			3: v = randf() * 2.0 - 1.0          # noise
		var env := 1.0
		if i < attack:
			env = float(i) / maxf(attack, 1)
		elif i > n - release:
			env = float(n - i) / maxf(release, 1)
		var idx := (start + i) * 2
		if idx + 1 < buf.size():
			var s := int(clampf(v * vol * env, -1.0, 1.0) * 32000.0)
			buf[idx] = s & 0xFF
			buf[idx + 1] = (s >> 8) & 0xFF

func _mix(buf: PackedByteArray, add: PackedByteArray) -> void:
	for i in mini(buf.size(), add.size()):
		var a := int(buf[i]) - (256 if buf[i] > 127 else 0)
		var b := int(add[i]) - (256 if add[i] > 127 else 0)
		var s := clampi(a + b, -32000, 32000)
		buf[i] = s & 0xFF

func _wav(buf: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = buf
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size() / 2
	return w

func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

# ---------------------------------------------------------------- 효과음 정의

func _build_sfx() -> void:
	# 커서 이동
	var b := _alloc(0.06)
	_tone(b, 0, 0.05, 920, 0, 0.25)
	_sfx["cursor"] = _wav(b, false)
	# 확인
	b = _alloc(0.12)
	_tone(b, 0, 0.05, 660, 0, 0.25)
	_tone(b, 0.05, 0.07, 990, 0, 0.25)
	_sfx["confirm"] = _wav(b, false)
	# 취소
	b = _alloc(0.12)
	_tone(b, 0, 0.05, 660, 0, 0.25)
	_tone(b, 0.05, 0.07, 440, 0, 0.25)
	_sfx["cancel"] = _wav(b, false)
	# 공격(베기)
	b = _alloc(0.16)
	_tone(b, 0, 0.10, 300, 0, 0.30, 90)
	_tone(b, 0, 0.08, 0, 3, 0.22)
	_sfx["attack"] = _wav(b, false)
	# 피격
	b = _alloc(0.14)
	_tone(b, 0, 0.12, 0, 3, 0.35)
	_tone(b, 0, 0.10, 180, 1, 0.25, 70)
	_sfx["hit"] = _wav(b, false)
	# 회복
	b = _alloc(0.35)
	_tone(b, 0, 0.10, 523, 1, 0.28)
	_tone(b, 0.10, 0.10, 659, 1, 0.28)
	_tone(b, 0.20, 0.14, 784, 1, 0.28)
	_sfx["heal"] = _wav(b, false)
	# 아이템 획득
	b = _alloc(0.30)
	_tone(b, 0, 0.07, 784, 0, 0.22)
	_tone(b, 0.08, 0.07, 988, 0, 0.22)
	_tone(b, 0.16, 0.14, 1319, 0, 0.22)
	_sfx["item"] = _wav(b, false)
	# 상자 열기
	b = _alloc(0.25)
	_tone(b, 0, 0.08, 392, 1, 0.25)
	_tone(b, 0.10, 0.15, 587, 1, 0.25)
	_sfx["chest"] = _wav(b, false)
	# 승리 팡파레
	b = _alloc(1.1)
	_tone(b, 0.00, 0.14, 523, 0, 0.26)
	_tone(b, 0.14, 0.14, 523, 0, 0.26)
	_tone(b, 0.28, 0.14, 523, 0, 0.26)
	_tone(b, 0.42, 0.30, 659, 0, 0.26)
	_tone(b, 0.72, 0.36, 784, 0, 0.28)
	_tone(b, 0.72, 0.36, 523, 1, 0.18)
	_sfx["victory"] = _wav(b, false)
	# 레벨업
	b = _alloc(0.8)
	var seq := [60, 64, 67, 72, 76, 79]
	for i in seq.size():
		_tone(b, i * 0.09, 0.16, _midi(seq[i]), 0, 0.24)
	_sfx["levelup"] = _wav(b, false)
	# 독
	b = _alloc(0.3)
	_tone(b, 0, 0.12, 220, 1, 0.25, 160)
	_tone(b, 0.14, 0.12, 180, 1, 0.22, 120)
	_sfx["poison"] = _wav(b, false)
	# 보스 등장 포효
	b = _alloc(0.7)
	_tone(b, 0, 0.6, 90, 0, 0.4, 45)
	_tone(b, 0, 0.55, 0, 3, 0.25)
	_sfx["roar"] = _wav(b, false)
	# 마법/스킬
	b = _alloc(0.4)
	_tone(b, 0, 0.3, 400, 2, 0.25, 1200)
	_tone(b, 0.05, 0.3, 600, 0, 0.15, 1500)
	_sfx["magic"] = _wav(b, false)
	# 문/이동
	b = _alloc(0.2)
	_tone(b, 0, 0.16, 500, 1, 0.2, 250)
	_sfx["door"] = _wav(b, false)
	# 파티 합류
	b = _alloc(0.6)
	_tone(b, 0.0, 0.12, 587, 0, 0.24)
	_tone(b, 0.12, 0.12, 698, 0, 0.24)
	_tone(b, 0.24, 0.12, 880, 0, 0.24)
	_tone(b, 0.36, 0.22, 1175, 0, 0.26)
	_sfx["join"] = _wav(b, false)

# ---------------------------------------------------------------- BGM 정의
# melody/bass: [midi(0=쉼), beats] 시퀀스. 루프 길이는 멜로디 총 박자.

func _build_bgm() -> void:
	# 타이틀 — 서정적 (A minor)
	_bgm["title"] = _song(
		[[69,1],[72,1],[76,1.5],[74,0.5],[72,2],[69,1],[71,1],[72,1.5],[69,0.5],[67,2],[0,1],
		 [69,1],[72,1],[77,1.5],[76,0.5],[74,2],[72,1],[74,1],[76,2],[72,2],[69,2],[0,2]],
		[[45,2],[52,2],[41,2],[48,2],[43,2],[50,2],[45,2],[52,2],
		 [41,2],[48,2],[43,2],[50,2],[45,2],[52,2],[40,2],[45,2]],
		88.0, 1, 1, 0.16, 0.13, false)
	# 마을 — 따뜻한 왈츠 (C major)
	_bgm["village"] = _song(
		[[72,1],[76,1],[79,1],[76,1],[77,1],[81,1],[79,2],[76,1],[74,1],[77,1],[76,1],[72,2],[0,2],
		 [72,1],[76,1],[81,1],[79,1],[77,1],[76,1],[74,2],[72,1],[74,1],[76,2],[72,2],[0,2]],
		[[48,2],[55,1],[48,2],[53,1],[52,2],[55,1],[48,2],[43,1],
		 [45,2],[52,1],[48,2],[43,1],[50,2],[55,1],[48,2],[43,1]],
		100.0, 1, 1, 0.15, 0.12, false)
	# 필드 — 모험 (G major)
	_bgm["field"] = _song(
		[[67,0.5],[69,0.5],[71,1],[74,1],[71,1],[69,0.5],[71,0.5],[72,1],[71,1],[69,1],[67,2],
		 [62,1],[64,1],[67,2],[69,0.5],[71,0.5],[74,1],[76,1],[74,1],[72,0.5],[74,0.5],[71,1],[69,1],[67,1],[62,2],[0,2]],
		[[55,2],[50,2],[55,2],[57,2],[50,2],[55,2],[43,2],[47,2],
		 [55,2],[50,2],[55,2],[57,2],[52,2],[50,2],[43,2],[47,2]],
		112.0, 0, 1, 0.13, 0.12, true)
	# 전투 — 빠름 (A minor)
	_bgm["battle"] = _song(
		[[69,0.5],[72,0.5],[76,1],[75,0.5],[76,0.5],[72,1],[69,1],[67,0.5],[69,0.5],[72,1],[71,0.5],[72,0.5],[69,1],[64,1],[0,2],
		 [69,0.5],[72,0.5],[77,1],[76,0.5],[77,0.5],[72,1],[69,1],[71,0.5],[72,0.5],[76,1],[74,0.5],[72,0.5],[71,1],[64,1],[0,2]],
		[[45,1],[45,1],[48,1],[45,1],[43,1],[43,1],[40,1],[43,1],
		 [45,1],[45,1],[48,1],[45,1],[41,1],[41,1],[40,1],[40,1]],
		140.0, 0, 1, 0.13, 0.13, true)
	# 보스 — 긴장 (D minor)
	_bgm["boss"] = _song(
		[[62,1],[65,1],[68,1],[65,1],[62,1],[61,1],[62,2],[0,1],[62,1],[65,1],[68,1],[70,1],[68,1],[65,1],[61,2],[0,1],
		 [62,1],[62,1],[65,1],[68,1],[70,1],[68,1],[65,1],[61,1],[62,2],[0,2]],
		[[38,1],[38,1],[41,1],[38,1],[37,1],[37,1],[34,1],[37,1],
		 [38,1],[38,1],[41,1],[38,1],[34,1],[34,1],[33,1],[33,1]],
		132.0, 0, 0, 0.14, 0.14, true)
	# 던전 — 어두움 (E minor)
	_bgm["dungeon"] = _song(
		[[64,2],[67,1],[71,2],[67,1],[64,2],[62,1],[64,3],[0,1],
		 [65,2],[69,1],[72,2],[69,1],[67,2],[64,1],[62,3],[0,1]],
		[[40,4],[36,4],[40,4],[36,4],[41,4],[37,4],[40,4],[35,4]],
		84.0, 1, 1, 0.14, 0.13, false)
	# 등대(최종 지역) — 웅장 (F major)
	_bgm["lighthouse"] = _song(
		[[65,1],[69,1],[72,2],[74,1],[72,1],[69,2],[65,1],[67,1],[69,2],[70,1],[69,1],[67,2],
		 [65,1],[69,1],[74,2],[77,1],[76,1],[74,2],[72,1],[74,1],[76,2],[72,2],[69,2],[0,2]],
		[[53,2],[60,2],[50,2],[57,2],[53,2],[60,2],[48,2],[55,2],
		 [53,2],[60,2],[50,2],[57,2],[55,2],[53,2],[50,2],[53,2]],
		104.0, 0, 1, 0.14, 0.12, true)
	# 엔딩 — 잔잔 (C major)
	_bgm["ending"] = _song(
		[[72,1.5],[74,0.5],[76,2],[79,1.5],[76,0.5],[74,2],[72,1],[76,1],[74,2],[71,2],
		 [72,1.5],[74,0.5],[76,2],[81,1.5],[79,0.5],[76,2],[74,1],[76,1],[72,4],[0,2]],
		[[48,4],[52,4],[45,4],[43,4],[48,4],[52,4],[41,4],[48,4]],
		76.0, 2, 1, 0.15, 0.11, false)
	# 게임오버
	_bgm["gameover"] = _song(
		[[69,2],[68,2],[67,2],[64,4],[0,4],[62,2],[61,2],[60,2],[57,4],[0,4]],
		[[45,4],[44,4],[43,4],[40,4],[38,4],[37,4],[36,4],[33,4]],
		70.0, 1, 1, 0.14, 0.12, false)

func _song(melody: Array, bass: Array, bpm: float, wave_m: int, wave_b: int, vol_m: float, vol_b: float, drums: bool) -> AudioStreamWAV:
	var spb := 60.0 / bpm
	var total_beats := 0.0
	for n in melody:
		total_beats += n[1]
	var total := int(total_beats * spb * SR)
	var buf := PackedByteArray()
	buf.resize(total * 2)
	_track(buf, melody, spb, wave_m, vol_m)
	_track(buf, bass, spb, wave_b, vol_b)
	if drums:
		var beat := 0.0
		while beat < total_beats - 0.01:
			var accent := fmod(beat, 4.0) < 0.01
			_tone(buf, beat * spb, 0.09 if accent else 0.05, 0, 3, 0.10 if accent else 0.06)
			beat += 1.0
	return _wav(buf, true)

func _track(buf: PackedByteArray, notes: Array, spb: float, wave: int, vol: float) -> void:
	var t := 0.0
	var bi := 0
	while t * SR < buf.size() / 2 - 1:
		var n: Array = notes[bi % notes.size()]
		bi += 1
		if n[0] > 0:
			_tone(buf, t, n[1] * spb * 0.92, _midi(n[0]), wave, vol)
		t += n[1] * spb
