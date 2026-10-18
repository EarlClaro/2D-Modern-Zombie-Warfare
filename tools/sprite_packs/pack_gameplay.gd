extends RefCounted
## Sprite pack: pieces of the card game itself that had no art, only code-drawn placeholders (docs/specs/art-gaps.md):
## the Barracks, the Combat Drone, the mine of the Minefield card and the beacon of the Noise Lure card.
## Loaded by tools/gen_sprites.gd; contract in pack_nature.gd. Material prefix `g_`.
## Models: +x is the front, about 0.9 across for a 1x1 piece.

const Base = preload("res://tools/gen_sprites.gd")
const Prim = Base.Prim

const MATS := {
	"g_roof": ["2b3a22", "415632", "5a7344"],
	"g_wall": ["4a5238", "66714c", "818e63"],
	"g_door": ["1a1713", "2a251d", "3b342a"],
	"g_flag": ["7a1612", "b32a22", "e0503f"],
	"g_led": ["6a1410", "d23a2e", "ff9a85"],
	"g_shell": ["30383b", "4a565a", "6c7c82"],
}

const FOUR: Array = ["se", "nw", "sw", "ne"]
const ALL: Array = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const SE_ONLY: Array = ["se"]


static func specs() -> Array:
	return [
		# the Barracks: frames 0-3 alive (the flag flutters, smoke drifts from the chimney), 4 damaged, 5-6 burning (two flicker
		# poses), 7 ruin
		{"dir": "unit_barracks", "name": "Barracks", "cat": "unit", "auto": true, "k": 1.25, "frames": 8, "columns": 2, "ss": 2, "facings": FOUR, "foot": Vector2i(1, 1)},
		# the Combat Drone: eight frames, the rotor blades turned between odd and even ones, the status light on for the first four
		{"dir": "combat_drone", "name": "Combat Drone", "cat": "unit", "auto": true, "k": 1.5, "frames": 8, "columns": 2, "ss": 2, "facings": ALL, "foot": Vector2i(1, 1)},
		{"dir": "field_mine", "name": "Mine", "cat": "unit", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": SE_ONLY, "foot": Vector2i(1, 1)},
		{"dir": "field_beacon", "name": "Noise Lure Beacon", "cat": "unit", "auto": true, "k": 1.6, "frames": 1, "columns": 1, "ss": 2, "facings": SE_ONLY, "foot": Vector2i(1, 1)},
	]


static func build(_host: Object, m: Array[Prim], unit: String, frame: int) -> bool:
	match unit:
		"unit_barracks":
			_barracks(m, frame)
		"combat_drone":
			_drone(m, frame)
		"field_mine":
			_mine(m)
		"field_beacon":
			_beacon(m)
		_:
			return false
	return true


static func _disc(m: Array[Prim], c: Vector3, r: float, mat: String, hz: float = 0.012) -> void:
	Base._cy(m, c + Vector3(0, 0, hz), r, hz, mat)


## A pitched roof slab: its ridge runs along y, `side` -1 or 1 is the half it covers.
static func _slab(list: Array[Prim], side: float, mat: String, drop: float = 0.0, lean: float = 0.0) -> void:
	var tilt := 0.46 * side
	list.append(Prim.new(Base.BOX, Vector3(0.2 * -side * -1.0, 0.0, 0.385 - drop), Vector3(0.27, 0.31, 0.015), mat, 0.0, 0.0, tilt + lean))


static func _barracks(m: Array[Prim], frame: int) -> void:
	# state: 0 alive (frames 0-3, `phase` is the animation step), 1 damaged, 2 burning (`flick` 0 or 1), 3 ruin
	var state := 0 if frame <= 3 else (1 if frame == 4 else (2 if frame <= 6 else 3))
	var phase := frame if frame <= 3 else 0
	var flick := 1 if frame == 6 else 0
	var ground: Array[Prim] = []
	var list: Array[Prim] = []
	var fx: Array[Prim] = []
	_disc(ground, Vector3(0, 0, 0), 0.6, "dirt")
	Base._bx(ground, Vector3(0, 0, 0.012), Vector3(0.5, 0.36, 0.012), "base")  # concrete pad
	if state <= 2:
		var wall := "g_wall"
		Base._bx(list, Vector3(0, 0, 0.17), Vector3(0.42, 0.28, 0.15), wall)  # the hut
		Base._bx(list, Vector3(0, 0, 0.045), Vector3(0.435, 0.295, 0.03), "base")  # foundation course
		Base._bx(list, Vector3(0.432, 0.0, 0.11), Vector3(0.006, 0.075, 0.1), "g_door")  # door
		Base._bx(list, Vector3(0.436, 0.0, 0.215), Vector3(0.006, 0.09, 0.012), "steel")  # lintel
		for s: float in [1.0, -1.0]:
			Base._bx(list, Vector3(0.43, 0.18 * s, 0.2), Vector3(0.007, 0.05, 0.045), "glass")  # windows, front and sides
			Base._bx(list, Vector3(-0.1, 0.285 * s, 0.2), Vector3(0.05, 0.007, 0.045), "glass")
			Base._bx(list, Vector3(0.12, 0.285 * s, 0.2), Vector3(0.05, 0.007, 0.045), "glass")
			Base._bx(list, Vector3(0.5, 0.17 * s, 0.045), Vector3(0.05, 0.06, 0.04), "sand", 0.2 * s)  # sandbags by the door
		Base._cy(list, Vector3(-0.34, -0.22, 0.34), 0.012, 0.28, "steel")  # flag pole
		if state == 0:  # the flag: a stiff part at the pole and a tip that swings with the breeze
			var sway: float = [0.0, 0.5, 0.0, -0.5][phase]
			Base._bx(list, Vector3(-0.34, -0.12, 0.58), Vector3(0.005, 0.04, 0.045), "g_flag")
			Base._bx(list, Vector3(-0.34 - 0.03 * sway, -0.2, 0.575 - 0.01 * absf(sway)), Vector3(0.005, 0.04, 0.04), "g_flag", sway * 0.6)
		else:
			Base._bx(list, Vector3(-0.34, -0.15, 0.58), Vector3(0.005, 0.07, 0.045), "g_flag")
		Base._cy(list, Vector3(-0.2, 0.2, 0.55), 0.008, 0.07, "steel")  # radio mast
	if state <= 1:  # the chimney, and smoke rising from it while the hut stands
		Base._bx(list, Vector3(0.16, -0.1, 0.43), Vector3(0.035, 0.035, 0.07), "base")
		for k in 3:
			var t := fposmod(float(phase) / 4.0 + float(k) / 3.0, 1.0) if state == 0 else float(k) / 3.0
			Base._blob(fx, Vector3(0.16 - 0.05 * t, -0.1 - 0.04 * t, 0.52 + 0.3 * t), 0.022 + 0.035 * t, "smoke")
	match state:
		0:
			list.append(Prim.new(Base.BOX, Vector3(-0.2, 0.0, 0.385), Vector3(0.27, 0.31, 0.015), "g_roof", 0.0, 0.0, 0.46))
			list.append(Prim.new(Base.BOX, Vector3(0.2, 0.0, 0.385), Vector3(0.27, 0.31, 0.015), "g_roof", 0.0, 0.0, -0.46))
			Base._bx(list, Vector3(0, 0, 0.36), Vector3(0.05, 0.28, 0.09), wall_mat())
		1:  # one roof half knocked down, the front scorched
			list.append(Prim.new(Base.BOX, Vector3(-0.2, 0.0, 0.385), Vector3(0.27, 0.31, 0.015), "g_roof", 0.0, 0.0, 0.46))
			list.append(Prim.new(Base.BOX, Vector3(0.27, 0.05, 0.22), Vector3(0.27, 0.31, 0.015), "g_roof", 0.15, 0.0, -0.12))
			Base._bx(list, Vector3(0, 0, 0.36), Vector3(0.05, 0.28, 0.09), wall_mat())
			Base._bx(ground, Vector3(0.45, 0.1, 0.027), Vector3(0.16, 0.2, 0.004), "dirt")
			Base._blob(fx, Vector3(0.1, 0.05, 0.42), 0.06, "smoke")
		2:  # the roof gone, burning inside
			Base._bx(list, Vector3(-0.15, -0.08, 0.34), Vector3(0.22, 0.2, 0.012), "g_roof", 0.5)
			var f2 := float(flick)
			Base._blob(fx, Vector3(0.0, 0.0, 0.4 + 0.03 * f2), 0.15 - 0.03 * f2, "fire")
			Base._blob(fx, Vector3(-0.15 + 0.06 * f2, 0.1 - 0.05 * f2, 0.36), 0.1 + 0.03 * f2, "fire")
			Base._blob(fx, Vector3(0.12 - 0.08 * f2, -0.12 + 0.04 * f2, 0.38 + 0.08 * f2), 0.09 - 0.02 * f2, "flash")
			Base._blob(fx, Vector3(0.02, 0.02 + 0.03 * f2, 0.58 + 0.06 * f2), 0.08 + 0.02 * f2, "smoke")
			Base._scorch(list)
		_:  # a heap of rubble
			Base._bx(list, Vector3(-0.1, 0.06, 0.07), Vector3(0.3, 0.22, 0.07), "g_wall", 0.2)
			Base._bx(list, Vector3(0.18, -0.12, 0.05), Vector3(0.14, 0.16, 0.05), "g_wall", -0.4)
			Base._bx(list, Vector3(-0.2, -0.18, 0.1), Vector3(0.22, 0.015, 0.1), "g_roof", 0.3)
			Base._bx(list, Vector3(0.05, 0.2, 0.04), Vector3(0.2, 0.012, 0.04), "g_roof", -0.2)
			Base._scorch(list)
			Base._blob(fx, Vector3(0.0, 0.0, 0.22), 0.09, "smoke")
			Base._blob(fx, Vector3(0.05, 0.04, 0.38), 0.07, "smoke")
	m.append_array(ground)
	m.append_array(list)
	m.append_array(fx)


static func wall_mat() -> String:
	return "g_wall"


static func _drone(m: Array[Prim], frame: int) -> void:
	Base._sp(m, Vector3(0, 0, 0.15), Vector3(0.085, 0.07, 0.03), "g_shell")  # body
	Base._sp(m, Vector3(0.03, 0, 0.17), Vector3(0.04, 0.04, 0.018), "heli")
	Base._sp(m, Vector3(0.07, 0, 0.12), Vector3(0.02, 0.02, 0.02), "glass")  # camera eye under the nose
	Base._sp(m, Vector3(-0.05, 0, 0.18), Vector3(0.012, 0.012, 0.012), "g_led" if frame < 4 else "g_shell")  # status light, blinking
	for sx: float in [1.0, -1.0]:
		for sy: float in [1.0, -1.0]:
			var yaw := atan2(sy, sx)
			Base._bx(m, Vector3(0.07 * sx, 0.07 * sy, 0.15), Vector3(0.075, 0.009, 0.007), "steel", yaw)  # arm
			var tip := Vector3(0.135 * sx, 0.135 * sy, 0.165)
			Base._cy(m, tip + Vector3(0, 0, -0.02), 0.014, 0.02, "steel")  # motor
			var blade := float(frame % 2) * 0.8 + (0.0 if sx * sy > 0.0 else 0.4)  # blades turned between odd and even frames
			Base._bx(m, tip + Vector3(0, 0, 0.012), Vector3(0.075, 0.007, 0.003), "rotor", blade)
			Base._bx(m, tip + Vector3(0, 0, 0.012), Vector3(0.075, 0.007, 0.003), "rotor", blade + 1.5708)


static func _mine(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.2, "dirt", 0.006)  # a patch of turned earth
	Base._cy(m, Vector3(0, 0, 0.028), 0.15, 0.028, "g_shell")  # the casing
	Base._cy(m, Vector3(0, 0, 0.065), 0.1, 0.012, "steel")
	Base._sp(m, Vector3(0, 0, 0.075), Vector3(0.05, 0.05, 0.022), "gun")
	Base._sp(m, Vector3(0, 0, 0.098), Vector3(0.018, 0.018, 0.016), "g_led")  # the arming light
	for i in 3:
		var a := TAU * float(i) / 3.0
		Base._bx(m, Vector3(cos(a) * 0.15, sin(a) * 0.15, 0.03), Vector3(0.012, 0.03, 0.016), "steel", a)  # carrying lugs


static func _beacon(m: Array[Prim]) -> void:
	_disc(m, Vector3(0, 0, 0), 0.14, "steel", 0.014)  # base plate
	Base._cy(m, Vector3(0, 0, 0.14), 0.012, 0.12, "steel")  # mast
	Base._bx(m, Vector3(0.0, 0, 0.3), Vector3(0.07, 0.06, 0.07), "g_shell")  # speaker box
	Base._bx(m, Vector3(0.071, 0, 0.3), Vector3(0.004, 0.045, 0.05), "gun")
	Base._sp(m, Vector3(0.076, 0, 0.3), Vector3(0.03, 0.03, 0.03), "steel")  # the cone
	Base._cy(m, Vector3(-0.03, 0.0, 0.43), 0.006, 0.07, "steel")  # aerial
	Base._sp(m, Vector3(-0.03, 0.0, 0.5), Vector3(0.016, 0.016, 0.016), "g_led")
	for a in [0.0, 2.1, 4.2]:  # three legs
		Base._bx(m, Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.06), Vector3(0.05, 0.008, 0.008), "steel", a)
