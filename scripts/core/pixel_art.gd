class_name PixelArt
## 픽셀 그래픽 팩토리 — 모든 스프라이트/타일/아이콘을 문자열 아트 + 팔레트로 생성.
## 외부 이미지 에셋이 전혀 없어도 통일된 픽셀 룩을 제공한다.

static var _tile_cache: Dictionary = {}
static var _enemy_cache: Dictionary = {}
static var _icon_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}

# ================================================================ 저수준

static func tex_from_rows(rows: Array, pal: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w := (rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

static func mirror_rows(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		var s: String = r
		var rev := ""
		for i in range(s.length() - 1, -1, -1):
			rev += s[i]
		out.append(rev)
	return out

static func _speckle_tex(base: Color, dark: Color, light: Color, seed_v: int, dark_p: float = 0.14, light_p: float = 0.08) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in 16:
		for x in 16:
			var r := rng.randf()
			var c := base
			if r < dark_p:
				c = dark
			elif r > 1.0 - light_p:
				c = light
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# ================================================================ 캐릭터 (16x16, 4방향 x 2프레임)

const CHAR_DOWN_0 := [
	"................",
	".....HHHHHH.....",
	"....HHHHHHHH....",
	"....HHSSSSHH....",
	"....HSSSSSSH....",
	"....SSESSESS....",
	"....SSSSSSSS....",
	".....SSSSSS.....",
	"....CCCCCCCC....",
	"...CCCCCCCCCC...",
	"...C.CCCCCC.C...",
	"...S.CCCCCC.S...",
	".....CCCCCC.....",
	".....cc..cc.....",
	".....BB..BB.....",
	"................",
]
const CHAR_DOWN_1 := [
	"................",
	".....HHHHHH.....",
	"....HHHHHHHH....",
	"....HHSSSSHH....",
	"....HSSSSSSH....",
	"....SSESSESS....",
	"....SSSSSSSS....",
	".....SSSSSS.....",
	"....CCCCCCCC....",
	"...CCCCCCCCCC...",
	"...C.CCCCCC.C...",
	"...S.CCCCCC.S...",
	".....CCCCCC.....",
	"....cc....cc....",
	"....BB....BB....",
	"................",
]
const CHAR_UP_0 := [
	"................",
	".....HHHHHH.....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	".....HHHHHH.....",
	"....CCCCCCCC....",
	"...CCCCCCCCCC...",
	"...C.CCCCCC.C...",
	"...S.CCCCCC.S...",
	".....CCCCCC.....",
	".....cc..cc.....",
	".....BB..BB.....",
	"................",
]
const CHAR_UP_1 := [
	"................",
	".....HHHHHH.....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	"....HHHHHHHH....",
	".....HHHHHH.....",
	"....CCCCCCCC....",
	"...CCCCCCCCCC...",
	"...C.CCCCCC.C...",
	"...S.CCCCCC.S...",
	".....CCCCCC.....",
	"....cc....cc....",
	"....BB....BB....",
	"................",
]
const CHAR_LEFT_0 := [
	"................",
	"....HHHHHH......",
	"...HHHHHHHH.....",
	"...SSSSHHHH.....",
	"...SSSSSHHH.....",
	"...SESSSHHH.....",
	"...SSSSSHH......",
	"....SSSS........",
	"....CCCCCC......",
	"...CCCCCCCC.....",
	"...C.CCCCC......",
	"...S.CCCC.......",
	".....CCCC.......",
	".....cc.cc......",
	".....BB.BB......",
	"................",
]
const CHAR_LEFT_1 := [
	"................",
	"....HHHHHH......",
	"...HHHHHHHH.....",
	"...SSSSHHHH.....",
	"...SSSSSHHH.....",
	"...SESSSHHH.....",
	"...SSSSSHH......",
	"....SSSS........",
	"....CCCCCC......",
	"...CCCCCCCC.....",
	"...C.CCCCC......",
	"...S.CCCC.......",
	".....CCCC.......",
	"....cc...cc.....",
	"....BB...BB.....",
	"................",
]

## pal 키: H 머리, S 피부, E 눈, C 옷, c 옷그림자, B 신발
static func char_frames(pal: Dictionary) -> Dictionary:
	var key := str(pal)
	if _frames_cache.has(key):
		return _frames_cache[key]
	var out := {
		"down_0": tex_from_rows(CHAR_DOWN_0, pal),
		"down_1": tex_from_rows(CHAR_DOWN_1, pal),
		"up_0": tex_from_rows(CHAR_UP_0, pal),
		"up_1": tex_from_rows(CHAR_UP_1, pal),
		"left_0": tex_from_rows(CHAR_LEFT_0, pal),
		"left_1": tex_from_rows(CHAR_LEFT_1, pal),
		"right_0": tex_from_rows(mirror_rows(CHAR_LEFT_0), pal),
		"right_1": tex_from_rows(mirror_rows(CHAR_LEFT_1), pal),
	}
	_frames_cache[key] = out
	return out

static func make_sprite_frames(pal: Dictionary) -> SpriteFrames:
	var texs := char_frames(pal)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for dir: String in ["down", "up", "left", "right"]:
		var anim: String = "walk_" + dir
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 4.0)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, texs[dir + "_0"])
		sf.add_frame(anim, texs[dir + "_1"])
		var idle: String = "idle_" + dir
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 1.0)
		sf.set_animation_loop(idle, true)
		sf.add_frame(idle, texs[dir + "_0"])
	return sf

# ================================================================ 적 스프라이트

const ENEMY_ART := {
	"sprout": [
		"................",
		"................",
		"......LL........",
		".....LLLL.......",
		"....gggggg......",
		"...gggggggg.....",
		"..gggggggggg....",
		"..ggGggggGgg....",
		"..ggEggggEgg....",
		"..gggggggggg....",
		"..gggGGGGggg....",
		"...gggggggg.....",
		"....gg..gg......",
		"...ggg..ggg.....",
		"................",
		"................",
	],
	"scorpion": [
		"................",
		"................",
		"................",
		"................",
		"..CC........CC..",
		"...CC......CC...",
		"....CCCCCCCC....",
		"...CcccccccC....",
		"....CEcccEC.....",
		"....ccccccccTT..",
		".....cccccc.TT..",
		"....cc....cc.T..",
		"....cc....cc....",
		"................",
		"................",
		"................",
	],
	"wolf": [
		"................",
		"................",
		"................",
		"...........FF...",
		"..........FFFF..",
		".FF........FFFF.",
		".FFF..FFFFFFFE..",
		"..FFFFFFFFFFF...",
		"..FFFFFFFFFFFF..",
		"...FFfFFfFFF....",
		"...FFFFFFFFFF...",
		"....FF....FF....",
		"....FF....FF....",
		"...BBB...BBB....",
		"................",
		"................",
	],
	"bat": [
		"................",
		"................",
		"................",
		"................",
		".WW..........WW.",
		".WWW........WWW.",
		"..WWWWWWWWWWWW..",
		"...WWWWWWWWWW...",
		"....WWEWWEWW....",
		".....WWWWWW.....",
		"......W..W......",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	"knight": [
		"................",
		".....KKKKKK.....",
		"....KKKKKKKK....",
		"....KKVVVVKK....",
		"....KVRRRRVK....",
		"....KVRVVRVK....",
		"....KKVVVVKK....",
		".....VVVVVV.....",
		"....AAAAAAAA....",
		"...AAAAAAAAAA.S.",
		"...A.AAAAAA.A.S.",
		"...K.AAAAAA.K.S.",
		".....AAAAAA.....",
		".....AA..AA.....",
		".....KK..KK.....",
		"................",
	],
	"golem": [
		"........................",
		"........RRRRRRRR........",
		".......RRRRRRRRRR.......",
		".......RRVVVVVVRR.......",
		".......RRVEEVVERR.......",
		".......RRVVVVVVRR.......",
		"....RR..RRRRRRRR..RR....",
		"...RRRR.RRRRRRRR.RRRR...",
		"...RRRRRRRRRRRRRRRRRR...",
		"...RRRRRRGGGGRRRRRRRR...",
		"..RRRRRRGGGGGGRRRRRRRR..",
		"..RRRRRRGGEEGGRRRRRRRR..",
		"..RRRRRRGGGGGGRRRRRRRR..",
		"..RRRRRRRGGGGRRRRRRRRR..",
		"..RRRRRRRRRRRRRRRRRRRR..",
		"...RRRRRRRRRRRRRRRRRR...",
		"...RRRRR.RRRRRR.RRRRR...",
		"...RRRR..RRRRRR..RRRR...",
		"...RRRR..RRRRRR..RRRR...",
		"..RRRRR..RRRRRR..RRRRR..",
		"..RRRRR..RRRRRR..RRRRR..",
		".RRRRRR..RRRRRR..RRRRRR.",
		".RRRRR....RRRR....RRRRR.",
		"........................",
	],
	"apostle": [
		"........................",
		"..........PPPP..........",
		".........PPPPPP.........",
		"........PPPPPPPP........",
		"........PPDDDDPP........",
		"........PDDDDDDP........",
		"........PDVDDVDP........",
		"........PDDDDDDP........",
		".........DDDDDD.........",
		"........PPPPPPPP........",
		".......PPPPPPPPPP.......",
		"......PPPPPPPPPPPP......",
		"......PPPPPPPPPPPP......",
		".....PPPPPPPPPPPPPP.....",
		".....PPPPPPPPPPPPPP.....",
		"....PPPPPPPPPPPPPPPP....",
		"....PPPPPPPPPPPPPPPP....",
		"....PPPPPPPPPPPPPPPP....",
		"...PPPP.PPPPPPPP.PPPP...",
		"...PPP...PPPPPP...PPP...",
		"...PP....PPPPPP....PP...",
		"..PP.....PP..PP.....PP..",
		"..P......P....P......P..",
		"........................",
	],
	"ashlord": [
		"........................",
		"......F...FF...F........",
		"......FFFFFFFFF.........",
		".....AAAAAAAAAAA........",
		".....AAAAAAAAAAA........",
		".....AAEAAAEAAA.........",
		".....AAAAAAAAAAA........",
		"......AAAAAAAAA.........",
		"....CCAAAAAAAAACC.......",
		"...CCCAAAAAAAAACCC......",
		"...CCAAAAAAAAAAACC......",
		"..CCCAAAAAAAAAAACC......",
		"..CCAAAAAAAAAAAAACC.....",
		"..CCAAAAAAAAAAAAACC.....",
		"..CCAAAAAAAAAAAAACC.....",
		"..CCAAAAAAAAAAAAACC.....",
		"...CCAAAAAAAAAAACC......",
		"...CCAAAAAAAAAAACC......",
		"....CCAAAAAAAAAACC......",
		"....CC.AAAAAAAA.CC......",
		"....CC.AAAAAAAA.CC......",
		".....C..AA..AA..C.......",
		"........AA..AA..........",
		"........................",
	],
}

const ENEMY_PAL := {
	"sprout": {"g": Color("8aa86a"), "G": Color("5a7a4a"), "L": Color("d88a4a"), "E": Color("1a1a24")},
	"scorpion": {"C": Color("a87a4a"), "c": Color("7a5a32"), "T": Color("d85a2a"), "E": Color("ffd24a")},
	"wolf": {"F": Color("9a9aa6"), "f": Color("6a6a76"), "E": Color("ff5a3a"), "B": Color("4a4a56")},
	"bat": {"W": Color("6a5a8a"), "E": Color("ffd24a")},
	"knight": {"K": Color("3a3a44"), "V": Color("5a5a68"), "R": Color("ff6a3a"), "A": Color("6a6a78"), "S": Color("d8d8e0")},
	"golem": {"R": Color("7a6a52"), "V": Color("5a4a38"), "G": Color("ff8a3a"), "E": Color("ffd24a")},
	"apostle": {"P": Color("3a2a4a"), "D": Color("1a1024"), "V": Color("a8e8ff")},
	"ashlord": {"A": Color("5a5a66"), "F": Color("ff8a3a"), "E": Color("ffd24a"), "C": Color("3a3a44")},
}

static func enemy_texture(kind: String) -> ImageTexture:
	if _enemy_cache.has(kind):
		return _enemy_cache[kind]
	var art: Array = ENEMY_ART.get(kind, ENEMY_ART["sprout"])
	var pal: Dictionary = ENEMY_PAL.get(kind, ENEMY_PAL["sprout"])
	var t := tex_from_rows(art, pal)
	_enemy_cache[kind] = t
	return t

static func enemy_size(kind: String) -> int:
	return (ENEMY_ART.get(kind, ENEMY_ART["sprout"])[0] as String).length()

# ================================================================ 타일

static func tile_texture(kind: String, frame: int = 0) -> ImageTexture:
	var ck := kind + "_" + str(frame)
	if _tile_cache.has(ck):
		return _tile_cache[ck]
	var t: ImageTexture
	match kind:
		"grass":
			t = _speckle_tex(Color("5a8a4a"), Color("4a7a3a"), Color("6a9a5a"), 11)
		"grass_dark":
			t = _speckle_tex(Color("4a7a3e"), Color("3e6a34"), Color("5a8a4a"), 12)
		"path":
			t = _speckle_tex(Color("b89868"), Color("a88858"), Color("c8a878"), 13)
		"sand":
			t = _speckle_tex(Color("c8b080"), Color("b8a070"), Color("d8c090"), 14)
		"ashen":
			t = _speckle_tex(Color("5a5258"), Color("4a4248"), Color("6a6268"), 15, 0.18, 0.06)
		"water":
			t = _water_tex(frame)
		"dfloor":
			t = _speckle_tex(Color("4a4450"), Color("3a3440"), Color("5a5460"), 16)
		"tree":
			t = _over_grass(TILE_TREE, {"T": Color("3a6a2a"), "t": Color("6a4a2a")})
		"rock":
			t = _over_grass(TILE_ROCK, {"R": Color("8a8a96"), "r": Color("6a6a76")})
		"cliff":
			t = tex_from_rows(TILE_CLIFF, {"W": Color("5a8a4a"), "R": Color("7a6a5a"), "r": Color("5a4a3a")})
		"roof":
			t = tex_from_rows(TILE_ROOF, {"R": Color("a85a3a"), "r": Color("8a4428")})
		"wall":
			t = tex_from_rows(TILE_WALL, {"w": Color("6a4a2a"), "W": Color("d8c8a0")})
		"door":
			t = tex_from_rows(TILE_DOOR, {"w": Color("6a4a2a"), "W": Color("d8c8a0"), "D": Color("4a3220")})
		"window":
			t = tex_from_rows(TILE_WINDOW, {"w": Color("6a4a2a"), "W": Color("d8c8a0"), "B": Color("7ab0d8")})
		"bridge":
			t = tex_from_rows(TILE_BRIDGE, {"b": Color("6a4a2a"), "B": Color("8a6a42")})
		"reeds":
			t = _over_grass(TILE_REEDS, {"g": Color("8a9a5a")})
		"flowers":
			t = _over_grass(TILE_FLOWERS, {"F": Color("e8a8c8")})
		"dwall":
			t = tex_from_rows(TILE_DWALL, {"D": Color("3a3440"), "d": Color("2a2430")})
		"crack":
			t = tex_from_rows(TILE_CRACK, {"P": Color("7a4ac8"), "V": Color("c8a8ff")})
		"lighthouse":
			t = tex_from_rows(TILE_LIGHT, {"L": Color("8a8a96"), "W": Color("e8e8f0")})
		"chest_closed":
			t = tex_from_rows(TILE_CHEST_CLOSED, {"w": Color("6a4a2a"), "W": Color("8a6a42"), "B": Color("c8a838")})
		"chest_open":
			t = tex_from_rows(TILE_CHEST_OPEN, {"w": Color("6a4a2a"), "W": Color("8a6a42"), "B": Color("c8a838")})
		"sign":
			t = _over_grass(TILE_SIGN, {"w": Color("6a4a2a"), "W": Color("b89868")})
		_:
			t = _speckle_tex(Color("5a8a4a"), Color("4a7a3a"), Color("6a9a5a"), 11)
	_tile_cache[ck] = t
	return t

static func _water_tex(frame: int) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base := Color("3a6a9a")
	var light := Color("5a8aba")
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, base)
	var rows := [[3, 4], [10, 11]] if frame == 0 else [[5, 6], [12, 13]]
	for r in rows:
		for x in 16:
			if (x + int(r[0])) % 8 < 5:
				img.set_pixel(x, int(r[0]), light)
				img.set_pixel(x, int(r[1]), light)
	return ImageTexture.create_from_image(img)

## 장식 타일(나무/바위 등)을 잔디 배경 위에 합성
static func _over_grass(art: Array, pal: Dictionary) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base := Color("5a8a4a")
	var dark := Color("4a7a3a")
	var light := Color("6a9a5a")
	for y in 16:
		for x in 16:
			var r := rng.randf()
			var c := base
			if r < 0.14:
				c = dark
			elif r > 0.92:
				c = light
			img.set_pixel(x, y, c)
	for y in art.size():
		var row: String = art[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

## 타이틀 화면용 등대 (24×22)
const TITLE_LIGHTHOUSE := [
	"........................",
	"............FF..........",
	"...........FFFF.........",
	"..........FFFFFF........",
	"..........CCCCCC........",
	".........LLLLLLLL.......",
	".........LWWWWWWL.......",
	".........LWWWWWWL.......",
	".........LLLLLLLL.......",
	".........LWWWWWWL.......",
	".........LRRRRRRL.......",
	".........LRRRRRRL.......",
	".........LWWWWWWL.......",
	".........LWWWWWWL.......",
	".........LRRRRRRL.......",
	".........LRRRRRRL.......",
	".........LWWWWWWL.......",
	".........LWWWWWWL.......",
	"........LLLLLLLLLL......",
	"........LLLLLLLLLL......",
	"........LLLLLLLLLL......",
	"........................",
]

static func title_lighthouse() -> ImageTexture:
	return tex_from_rows(TITLE_LIGHTHOUSE, {
		"F": Color("ff9a3c"), "C": Color("3a3a46"), "L": Color("8a8a96"),
		"W": Color("e8e8f0"), "R": Color("c85a4a"),
	})

const TILE_TREE := [
	"................",
	"....TTTTTTTT....",
	"...TTTTTTTTTT...",
	"..TTTTTTTTTTTT..",
	"..TTtTTTTtTTTT..",
	".TTTTTTTTTTTTTT.",
	".TTtTTTTTTtTTTT.",
	".TTTTTTtTTTTTTT.",
	"..TTTTTTTTTTTT..",
	"..TTtTTTTtTTTT..",
	"...TTTTTTTTTT...",
	"....TTTTTTTT....",
	"......tttt......",
	"......tttt......",
	".....tttttt.....",
	"................",
]
const TILE_ROCK := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"......RRRR......",
	".....RRRRRR.....",
	"....RRrRRRRR....",
	"...RRRRRRRrRR...",
	"...RrRRRRRRRR...",
	"..RRRRRRrRRRRR..",
	"..RRRRRRRRRRRR..",
	"..rrrrrrrrrrrr..",
	"................",
	"................",
]
const TILE_CLIFF := [
	"WWWWWWWWWWWWWWWW",
	"WWWWWWWWWWWWWWWW",
	"rrrrrrrrrrrrrrrr",
	"RRRRRRRRRRRRRRRR",
	"RRRRRRRRRRRRRRRR",
	"RRrRRRRRRRrRRRRR",
	"RRRRRRrRRRRRRRRR",
	"RRRRRRRRRRRrRRRR",
	"RrRRRRRRRRRRRRRR",
	"RRRRRRrRRRRRRRRR",
	"RRRRRRRRRRRRRRRR",
	"rrrrrrrrrrrrrrrr",
	"RRRRRRRRRRRRRRRR",
	"RRRRRRRRRRRRRRRR",
	"rrrrrrrrrrrrrrrr",
	"rrrrrrrrrrrrrrrr",
]
const TILE_ROOF := [
	"RRRRRRRRRRRRRRRR",
	"rRRrRRrRRrRRrRRr",
	"RRRRRRRRRRRRRRRR",
	"RRrRRrRRrRRrRRrR",
	"RRRRRRRRRRRRRRRR",
	"rRRrRRrRRrRRrRRr",
	"RRRRRRRRRRRRRRRR",
	"RRrRRrRRrRRrRRrR",
	"RRRRRRRRRRRRRRRR",
	"rRRrRRrRRrRRrRRr",
	"RRRRRRRRRRRRRRRR",
	"RRrRRrRRrRRrRRrR",
	"RRRRRRRRRRRRRRRR",
	"rRRrRRrRRrRRrRRr",
	"RRRRRRRRRRRRRRRR",
	"rRRrRRrRRrRRrRRr",
]
const TILE_WALL := [
	"wwwwwwwwwwwwwwww",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wWWWWWWWWWWWWWWw",
	"wwwwwwwwwwwwwwww",
	"................",
]
const TILE_DOOR := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"wwwwwwwwwwwwwwww",
	"wWWWWDDDDWWWWWWw",
	"wWWWWDDDDWWWWWWw",
	"wWWWWDDDDWWWWWWw",
	"wWWWWDDDDWWWWWWw",
	"wwwwwwwwwwwwwwww",
	"................",
]
const TILE_WINDOW := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"wwwwwwwwwwwwwwww",
	"wWWWBBBBBBWWWWWw",
	"wWWWBBBBBBWWWWWw",
	"wWWWBBBBBBWWWWWw",
	"wWWWBBBBBBWWWWWw",
	"wwwwwwwwwwwwwwww",
	"................",
]
const TILE_BRIDGE := [
	"................",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"bbbbbbbbbbbbbbbb",
	"bBBBBBBBBBBBBBBb",
	"................",
]
const TILE_REEDS := [
	"................",
	"................",
	"..g...g....g....",
	"..g..g....g.....",
	".gg..g...gg..g..",
	"..g.gg...g..gg..",
	"..g.g....g...g..",
	".ggg....gg..gg..",
	"..g..g...g...g..",
	".gg.gg..gg..gg..",
	"..g.g....g..g...",
	".gggg...gg.gg...",
	"..gg.....ggg....",
	"................",
	"................",
	"................",
]
const TILE_FLOWERS := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....F..........",
	"....FFF...F.....",
	".....F....FFF...",
	"...........F....",
	"................",
	"..F........F....",
	".FFF..F...FFF...",
	"..F..FFF...F....",
	"................",
]
const TILE_DWALL := [
	"DDDDDDDDDDDDDDDD",
	"DddDDddDDddDDddD",
	"DddDDddDDddDDddD",
	"DDDDDDDDDDDDDDDD",
	"dddddddddddddddd",
	"DddDDddDDddDDddD",
	"DddDDddDDddDDddD",
	"DDDDDDDDDDDDDDDD",
	"dddddddddddddddd",
	"DddDDddDDddDDddD",
	"DddDDddDDddDDddD",
	"DDDDDDDDDDDDDDDD",
	"dddddddddddddddd",
	"DddDDddDDddDDddD",
	"DddDDddDDddDDddD",
	"DDDDDDDDDDDDDDDD",
]
const TILE_CRACK := [
	"................",
	"................",
	"................",
	"......P.........",
	".....PPP....P...",
	"....PPPP...PP...",
	"...PPPPPP.PPP...",
	"....PPPPPPPP....",
	".....PPVPPP.....",
	"....PPPVPPP.....",
	"...PPPPVPPPP....",
	"....PPPPPPP.....",
	".....PPPPP......",
	"......PPP.......",
	"................",
	"................",
]
const TILE_LIGHT := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"....LLLLLLLL....",
	"....LWWWWWWL....",
	"....LWWWWWWL....",
	"....LWWWWWWL....",
	"....LWWWWWWL....",
	"....LLLLLLLL....",
	"................",
]
const TILE_CHEST_CLOSED := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"....wwwwwwww....",
	"...wWWWWWWWWw...",
	"...wWWBBBBWWw...",
	"...wWWWWWWWWw...",
	"...wWWWWWWWWw...",
	"...wwwwwwwwww...",
	"................",
]
const TILE_CHEST_OPEN := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"....wwwwwwww....",
	"...w........w...",
	"...w........w...",
	"...wWWWWWWWWw...",
	"...wWWWWWWWWw...",
	"...wwwwwwwwww...",
	"................",
]
const TILE_SIGN := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"..wwwwwwwwwwww..",
	"..wWWWWWWWWWWw..",
	"..wwwwwwwwwwww..",
	"......ww........",
	"......ww........",
	".....wwww.......",
	"................",
]

# ================================================================ 아이콘 (16x16)

const ICON_ART := {
	"potion": [
		"................",
		"................",
		"......WW........",
		"......WW........",
		".....WWWW.......",
		"....W....W......",
		"...W......W.....",
		"..W........W....",
		"..W.RRRRRR.W....",
		"..W.RRRRRR.W....",
		"..WRRRRRRRRW....",
		"...WRRRRRRW.....",
		"....WWWWWW......",
		"................",
		"................",
		"................",
	],
	"hi_potion": [
		"................",
		"......WW........",
		"......WW........",
		".....WWWW.......",
		"....W....W......",
		"...W......W.....",
		"..W........W....",
		".W..........W...",
		".W.RRRRRRRR.W...",
		".W.RRRRRRRR.W...",
		".WRRRRRRRRRRW...",
		".WRRRRRRRRRRW...",
		"..WRRRRRRRRW....",
		"...WWWWWWWW.....",
		"................",
		"................",
	],
	"antidote": [
		"................",
		"................",
		"......WW........",
		"......WW........",
		".....WWWW.......",
		"....W....W......",
		"...W......W.....",
		"..W........W....",
		"..W.GGGGGG.W....",
		"..W.GGGGGG.W....",
		"..WGGGGGGGGW....",
		"...WGGGGGGW.....",
		"....WWWWWW......",
		"................",
		"................",
		"................",
	],
	"revive": [
		"................",
		"..........FF....",
		".........FFFF...",
		"........FFFFFF..",
		".......FFFFFFF..",
		"......FFFFFFF...",
		".....FFFFFFF....",
		"....FFFFFFF.....",
		"...FFFFFFF......",
		"..FFFFFFF.......",
		"..sFFFFFF.......",
		"...sFFF.........",
		"....ss..........",
		"................",
		"................",
		"................",
	],
	"bomb": [
		"................",
		"................",
		"........f.......",
		".......f........",
		"......f.........",
		"....BBBB........",
		"...BBBBBB.......",
		"..BBBBBBBB......",
		"..BBbBBbBB......",
		"..BBBBBBBB......",
		"..BBbBBbBB......",
		"...BBBBBB.......",
		"....BBBB........",
		"................",
		"................",
		"................",
	],
	"herb": [
		"................",
		"................",
		"................",
		".......s........",
		"......ss........",
		".....GLLs.......",
		"....GLLLLs......",
		"...GLLLLLLs.....",
		"...GLLLLLLs.....",
		"....GLLLLs......",
		".....GLLs.......",
		"......ss........",
		"................",
		"................",
		"................",
		"................",
	],
	"scroll": [
		"................",
		"................",
		"..PPPPPPPPPP....",
		"..P........P....",
		"..P.wwwwww.P....",
		"..P........P....",
		"..P.wwwwww.P....",
		"..P........P....",
		"..P.wwwwww.P....",
		"..P........P....",
		"..PPPPPPPPPP....",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	"charm": [
		"................",
		".......ss.......",
		"......s..s......",
		"......s..s......",
		".....RRRRRR.....",
		"....RRRRRRRR....",
		"....RRFFFFRR....",
		"....RRFFFFRR....",
		"....RRRRRRRR....",
		".....RRRRRR.....",
		"......RRRR......",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	"sword": [
		"................",
		"..........SS....",
		".........SSS....",
		"........SSS.....",
		".......SSS......",
		"......SSS.......",
		".....SSS........",
		"....SSS.........",
		"...gSS..........",
		"..gggg..........",
		".gg.ggg.........",
		"gg...gg.........",
		"................",
		"................",
		"................",
		"................",
	],
	"bow": [
		"................",
		".......BB.......",
		"......B..B......",
		".....B....B.....",
		"....B......B....",
		"....B.......s...",
		"....B........s..",
		"....B.......s...",
		"....B......B....",
		".....B....B.....",
		"......B..B......",
		".......BB.......",
		"................",
		"................",
		"................",
		"................",
	],
	"staff": [
		"................",
		".......GG.......",
		"......GGGG......",
		"......GGGG......",
		".......GG.......",
		".......w........",
		".......w........",
		".......w........",
		".......w........",
		".......w........",
		".......w........",
		".......w........",
		"................",
		"................",
		"................",
		"................",
	],
	"blade": [
		"................",
		"..........SS....",
		".........SSS....",
		"........SSS.....",
		".......SSS......",
		"......SSS.......",
		".....SSS........",
		"....SSS.........",
		"...rSS..........",
		"..rrrr..........",
		".rr.rrr.........",
		"rr...rr.........",
		"................",
		"................",
		"................",
		"................",
	],
	"armor": [
		"................",
		"................",
		"................",
		"................",
		"....AAAAAA......",
		"...AAAAAAAA.....",
		"..AAAAAAAAAA....",
		"..A.AAAAAA.A....",
		"..A.AAAAAA.A....",
		"...AAAAAAAA.....",
		"...AAAAAAAA.....",
		"....AAAAAA......",
		"................",
		"................",
		"................",
		"................",
	],
	"ring": [
		"................",
		"................",
		"................",
		"................",
		"......GGGG......",
		".....G....G.....",
		"....G......G....",
		"....G......G....",
		"....G......G....",
		".....G....G.....",
		"......GGGG......",
		".......gg.......",
		"................",
		"................",
		"................",
		"................",
	],
}

const ICON_PAL := {
	"W": Color("d8d8e0"), "R": Color("e05a5a"), "G": Color("5ac86a"),
	"F": Color("f0f0f8"), "s": Color("8a6a4a"), "B": Color("3a3a44"),
	"b": Color("5a5a68"), "P": Color("c8a860"), "w": Color("f0e8d0"),
	"S": Color("c8c8d4"), "g": Color("8a8a96"), "r": Color("8a5a2a"),
	"A": Color("9a9aa6"), "L": Color("7ac86a"), "f2": Color("ff8a3a"),
}

static func icon_texture(kind: String) -> ImageTexture:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var art: Array = ICON_ART.get(kind, ICON_ART["scroll"])
	var pal := ICON_PAL.duplicate()
	if kind == "bomb":
		pal["B"] = Color("3a3a44")
		pal["b"] = Color("5a5a68")
		pal["f"] = Color("ff8a3a")
	var t := tex_from_rows(art, pal)
	_icon_cache[kind] = t
	return t

## 아이템/장비 → 아이콘 종류 매핑
static func icon_for_item(id: String) -> ImageTexture:
	var it := DB.item(id)
	if not it.is_empty():
		return icon_texture(it.get("icon", "scroll"))
	var eq := DB.equip(id)
	if not eq.is_empty():
		match eq.get("slot", ""):
			"weapon":
				return icon_texture(eq.get("icon", "sword"))
			"armor":
				return icon_texture("armor")
			"trinket":
				return icon_texture("ring")
	return icon_texture("scroll")
