extends SceneTree
## Dev tool (not a test). Milestone 3.1: measures how enemies could find their way (open item A6) before anything is built.
## Compares movement strategies on a real mission (default `x2_outskirts`: 64x48 map, two spawns, scenery, water), see MODES:
##   A  waypoints  today's rule: straight segments between the mission's waypoints plus a fixed random lane offset
##   B  flow       one distance field from the core over walkable, scenery-free cells; each enemy steers down it
##                 (bilinear blend of the four nearest cells' directions, or the nearest cell's; recomputed every tick or every 4th)
##   C  flow+sep   B plus separation: a counting-sort spatial hash (1-tile cells), pushes only from the first 8 neighbours
##                 (recomputed every tick or every 2nd)
## It reports (1) the cost of the movement step alone per tick for N enemies alive (compare with the 16.7 ms tick budget
## and with `tools/perf_sim.gd`, which measures the whole step), (2) route facts per spawn, (3) how many moving enemies
## overlap, and how many do not progress. Prototype classes live here on purpose: they move to scripts/ in increment 3.2
## only if the decision (ADR-012) is to use them. Nothing here changes the game.
## Enemies appear at `--rate` per second (default 25; the shipped waves peak at about 20-40) until `count` are alive, and
## the cost window is the 20 s after the last one appeared. Stopped enemies stay alive (worst case for cost).
## Run: godot --headless --path . --script tools/perf_flow.gd -- [--mission=x2_outskirts] [--counts=250,500,1000,2000] [--seed=1] [--rate=25] [--modes=0,1,2]

const DT: float = 1.0 / 60.0
const SPAWN_JITTER: float = 1.0
const LANE_JITTER: float = 0.9
const WINDOW_S: float = 20.0        # seconds measured after the last enemy appeared
const OVERLAP_AT_S: float = 30.0    # when the overlap / not-progressing counts are taken
const STOP_MIN: float = 1.5         # an enemy stops this far from the core centre ...
const STOP_SPREAD: float = 3.0      # ... plus up to this much (stand-off differs per enemy: melee 1, spitter 4.5)
const SEP_STRENGTH: float = 1.5     # of the enemy's own speed, at zero distance
const SPEED_BY_TYPE: Array[float] = [1.2, 2.6, 0.7]      # shambler, runner, brute (data/enemies)
const RADIUS_BY_TYPE: Array[float] = [0.3, 0.25, 0.45]
## flow: false = waypoints. every: ticks between direction refreshes (per agent, staggered). nearest: the nearest cell's
## direction instead of the bilinear blend. lane: sample the field at the position plus a fixed per-enemy offset, so a
## column spreads sideways at no extra cost. sep: 0 = none, else ticks between separation refreshes. hash: ticks between
## spatial-hash rebuilds. cap: neighbours looked at per enemy.
const MODES: Array[Dictionary] = [
	{"name": "A waypoints", "flow": false, "every": 1, "nearest": false, "lane": false, "sep": 0, "hash": 1, "cap": 8},
	{"name": "B1 flow bilinear/1", "flow": true, "every": 1, "nearest": false, "lane": false, "sep": 0, "hash": 1, "cap": 8},
	{"name": "B2 flow bilinear/4", "flow": true, "every": 4, "nearest": false, "lane": false, "sep": 0, "hash": 1, "cap": 8},
	{"name": "B3 flow nearest/1", "flow": true, "every": 1, "nearest": true, "lane": false, "sep": 0, "hash": 1, "cap": 8},
	{"name": "C1 B2 + sep/1", "flow": true, "every": 4, "nearest": false, "lane": false, "sep": 1, "hash": 1, "cap": 8},
	{"name": "C2 B2 + sep/2", "flow": true, "every": 4, "nearest": false, "lane": false, "sep": 2, "hash": 1, "cap": 8},
	{"name": "B4 B2 + lane", "flow": true, "every": 4, "nearest": false, "lane": true, "sep": 0, "hash": 1, "cap": 8},
	{"name": "C3 B4 + sep/4 hash/4", "flow": true, "every": 4, "nearest": false, "lane": true, "sep": 4, "hash": 4, "cap": 8},
	{"name": "C4 C3, cap 4", "flow": true, "every": 4, "nearest": false, "lane": true, "sep": 4, "hash": 4, "cap": 4},
]


## Distance field from a goal cell over open cells (8-neighbour, no corner cutting) and a per-cell steering direction.
class Field:
	var w: int = 0
	var h: int = 0
	var open: PackedByteArray = PackedByteArray()
	var dist: PackedFloat32Array = PackedFloat32Array()
	var dir: PackedVector2Array = PackedVector2Array()
	var _hk: PackedFloat32Array = PackedFloat32Array()
	var _hv: PackedInt32Array = PackedInt32Array()

	const NB: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

	func is_open(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and open[y * w + x] == 1

	func reachable(x: int, y: int) -> bool:
		return is_open(x, y) and dist[y * w + x] < 1.0e8

	## True if stepping from (x, y) by `d` is allowed (target open, and for diagonals both side cells open).
	func can_step(x: int, y: int, d: Vector2i) -> bool:
		if not is_open(x + d.x, y + d.y):
			return false
		if d.x != 0 and d.y != 0:
			return is_open(x + d.x, y) and is_open(x, y + d.y)
		return true

	func build(p_w: int, p_h: int, p_open: PackedByteArray, goal: Vector2i) -> void:
		w = p_w
		h = p_h
		open = p_open
		dist = PackedFloat32Array()
		dist.resize(w * h)
		dist.fill(1.0e9)
		dir = PackedVector2Array()
		dir.resize(w * h)
		_hk.clear()
		_hv.clear()
		dist[goal.y * w + goal.x] = 0.0
		_push(0.0, goal.y * w + goal.x)
		while not _hv.is_empty():
			var top_d := _hk[0]
			var cur := _pop()
			if top_d > dist[cur]:
				continue
			var cx := cur % w
			var cy := cur / w
			for d in NB:
				if not can_step(cx, cy, d):
					continue
				var nd := top_d + (1.41421356 if d.x != 0 and d.y != 0 else 1.0)
				var ni := (cy + d.y) * w + cx + d.x
				if nd < dist[ni]:
					dist[ni] = nd
					_push(nd, ni)
		for y in h:
			for x in w:
				var i := y * w + x
				if dist[i] >= 1.0e8 or dist[i] == 0.0:
					continue
				var sum := Vector2.ZERO
				for d in NB:
					if not can_step(x, y, d):
						continue
					var gain := dist[i] - dist[(y + d.y) * w + x + d.x]
					if gain > 1.0e-4:
						sum += Vector2(d).normalized() * gain
				dir[i] = sum.normalized()

	## Steering direction at a ground position: bilinear blend of the four nearest cell centres' directions.
	func sample(p: Vector2) -> Vector2:
		var gx := p.x - 0.5
		var gy := p.y - 0.5
		var ix := floori(gx)
		var iy := floori(gy)
		var tx := gx - ix
		var ty := gy - iy
		var acc := Vector2.ZERO
		for dy in 2:
			for dx in 2:
				var cx := ix + dx
				var cy := iy + dy
				if reachable(cx, cy):
					acc += dir[cy * w + cx] * ((tx if dx == 1 else 1.0 - tx) * (ty if dy == 1 else 1.0 - ty))
		if acc.length_squared() < 1.0e-6:
			var c := Vector2i(floori(p.x), floori(p.y))
			return dir[c.y * w + c.x] if reachable(c.x, c.y) else Vector2.ZERO
		return acc.normalized()

	func _push(k: float, v: int) -> void:
		_hk.append(k)
		_hv.append(v)
		var i := _hk.size() - 1
		while i > 0:
			var p := (i - 1) / 2
			if _hk[p] <= _hk[i]:
				break
			var tk := _hk[p]
			var tv := _hv[p]
			_hk[p] = _hk[i]
			_hv[p] = _hv[i]
			_hk[i] = tk
			_hv[i] = tv
			i = p

	func _pop() -> int:
		var out := _hv[0]
		var last := _hk.size() - 1
		_hk[0] = _hk[last]
		_hv[0] = _hv[last]
		_hk.resize(last)
		_hv.resize(last)
		var i := 0
		var n := last
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < n and _hk[l] < _hk[m]:
				m = l
			if r < n and _hk[r] < _hk[m]:
				m = r
			if m == i:
				break
			var tk := _hk[m]
			var tv := _hv[m]
			_hk[m] = _hk[i]
			_hv[m] = _hv[i]
			_hk[i] = tk
			_hv[i] = tv
			i = m
		return out


## A crowd of agents with the arrays a real implementation would use (no nodes, no drawing).
class Crowd:
	var pos: PackedVector2Array = PackedVector2Array()
	var speed: PackedFloat32Array = PackedFloat32Array()
	var radius: PackedFloat32Array = PackedFloat32Array()
	var stop_at: PackedFloat32Array = PackedFloat32Array()
	var arrived: PackedByteArray = PackedByteArray()
	var wp: PackedInt32Array = PackedInt32Array()
	var lane: PackedVector2Array = PackedVector2Array()
	var ref_pos: PackedVector2Array = PackedVector2Array()  # position 5 s before the sample, for the "does not progress" count
	var cdir: PackedVector2Array = PackedVector2Array()     # cached steering direction
	var cpush: PackedVector2Array = PackedVector2Array()    # cached separation push
	var head: PackedInt32Array = PackedInt32Array()
	var nxt: PackedInt32Array = PackedInt32Array()

	func size() -> int:
		return pos.size()


var _field: Field
var _w: int = 0
var _h: int = 0
var _open: PackedByteArray = PackedByteArray()
var _mission: MissionDefinition
var _waypoints: Array[Vector2] = []
var _core: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rate: float = 25.0


func _init() -> void:
	var mission_id := "x2_outskirts"
	var counts: Array[int] = [250, 500, 1000, 2000]
	var seed_value := 1
	var modes: Array[int] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mission="):
			mission_id = a.substr(10)
		elif a.begins_with("--counts="):
			counts = []
			for c in a.substr(9).split(","):
				counts.append(int(c))
		elif a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--rate="):
			_rate = float(a.substr(7))
		elif a.begins_with("--modes="):
			for m in a.substr(8).split(","):
				modes.append(int(m))
	if modes.is_empty():
		for i in MODES.size():
			modes.append(i)
	var db := ContentDb.load_from()
	_mission = db.mission(mission_id)
	if _mission == null:
		print("ERROR | unknown mission '%s'" % mission_id)
		quit(1)
		return
	_prepare(db)
	print("ENV | mission=%s map=%dx%d spawns=%d waypoints=%d core=%s (other processes may share this CPU)" % [
		mission_id, _w, _h, _mission.spawn_cells.size(), _waypoints.size(), str(_mission.core_cell)])
	_report_build_cost()
	_report_routes()
	for n in counts:
		for mode in modes:
			_run(mode, n, seed_value)
	quit()


func _prepare(db: ContentDb) -> void:
	var m := _mission.map
	_w = m.width()
	_h = m.height()
	_open = PackedByteArray()
	_open.resize(_w * _h)
	for y in _h:
		for x in _w:
			_open[y * _w + x] = 1 if m.is_walkable(Vector2i(x, y)) else 0
	for p in m.placements():
		var def := db.scenery(p.scenery_id)
		for c in def.cells_at(p.cell):
			if m.in_bounds(c):
				_open[c.y * _w + c.x] = 0
	_field = Field.new()
	_field.build(_w, _h, _open, _mission.core_cell)
	_waypoints.clear()
	for c in _mission.path_cells:
		_waypoints.append(IsoProjection.cell_center(c))
	_core = IsoProjection.cell_center(_mission.core_cell)


func _report_build_cost() -> void:
	var t0 := Time.get_ticks_usec()
	var f := Field.new()
	for i in 5:
		f.build(_w, _h, _open, _mission.core_cell)
	var map_ms := float(Time.get_ticks_usec() - t0) / 5000.0
	var big := PackedByteArray()
	big.resize(128 * 128)
	big.fill(1)
	t0 = Time.get_ticks_usec()
	f.build(128, 128, big, Vector2i(10, 10))
	var big_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var reach := 0
	var open_n := 0
	for i in _w * _h:
		if _open[i] == 1:
			open_n += 1
			if _field.dist[i] < 1.0e8:
				reach += 1
	print("RESULT | field build: %.1f ms for %dx%d (open cells %d, reachable from core %d), %.0f ms for an empty 128x128 (the largest allowed map); done once at setup" % [map_ms, _w, _h, open_n, reach, big_ms])


func _report_routes() -> void:
	for si in _mission.spawn_cells.size():
		var s := _mission.spawn_cells[si]
		var from := IsoProjection.cell_center(s)
		var wp_len := 0.0
		var prev := from
		for wp in _waypoints:
			wp_len += prev.distance_to(wp)
			prev = wp
		var straight := from.distance_to(_core)
		var straight_ok := _line_open(from, _core)
		var p := from
		var walked := 0.0
		var steps := 0
		while steps < 60 * 600 and p.distance_to(_core) > 1.5:
			var d := _field.sample(p)
			if d == Vector2.ZERO:
				break
			var np := p + d * 1.2 * DT
			walked += p.distance_to(np)
			p = np
			steps += 1
		print("RESULT | spawn %s: waypoint route %.1f tiles, straight line to core %.1f tiles (%s), flow route %.1f tiles (%s)" % [
			str(s), wp_len, straight, "open" if straight_ok else "BLOCKED by terrain or scenery", walked,
			"reached the core" if p.distance_to(_core) <= 1.5 else "STUCK at " + str(p)])


func _line_open(a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, ceili(a.distance_to(b) / 0.2))
	for i in n + 1:
		if not _cell_open(a.lerp(b, float(i) / n)):
			return false
	return true


func _cell_open(p: Vector2) -> bool:
	var x := floori(p.x)
	var y := floori(p.y)
	return x >= 0 and y >= 0 and x < _w and y < _h and _open[y * _w + x] == 1


func _jitter(radius: float) -> Vector2:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * radius
	return Vector2(cos(a), sin(a)) * r


func _spawn(c: Crowd, i: int, mode: int) -> void:
	var kind := 0 if i % 10 < 6 else (1 if i % 10 < 9 else 2)  # 60 % shamblers, 30 % runners, 10 % brutes
	var s := _mission.spawn_cells[i % _mission.spawn_cells.size()]
	var p := IsoProjection.cell_center(s) + _jitter(SPAWN_JITTER)
	if not _cell_open(p):
		p = IsoProjection.cell_center(s)
	c.pos.append(p)
	c.ref_pos.append(p)
	c.speed.append(SPEED_BY_TYPE[kind])
	c.radius.append(RADIUS_BY_TYPE[kind])
	c.stop_at.append(STOP_MIN + _rng.randf() * STOP_SPREAD)
	c.arrived.append(0)
	c.wp.append(0)
	c.lane.append(_jitter(LANE_JITTER) if (not MODES[mode]["flow"] or MODES[mode]["lane"]) else Vector2.ZERO)
	c.cdir.append(Vector2.ZERO)
	c.cpush.append(Vector2.ZERO)
	c.nxt.append(-1)


## One movement tick for the whole crowd (`tick` staggers the refreshes of cached steering and pushes).
func _tick(c: Crowd, mode: int, tick: int) -> void:
	var cfg: Dictionary = MODES[mode]
	var flow: bool = cfg["flow"]
	var every: int = cfg["every"]
	var nearest: bool = cfg["nearest"]
	var sep_every: int = cfg["sep"]
	var cap: int = cfg["cap"]
	var lane_on: bool = cfg["lane"]
	var n := c.size()
	if sep_every > 0 and tick % int(cfg["hash"]) == 0:
		c.head.fill(-1)
		for i in n:
			var cell := clampi(floori(c.pos[i].y), 0, _h - 1) * _w + clampi(floori(c.pos[i].x), 0, _w - 1)
			c.nxt[i] = c.head[cell]
			c.head[cell] = i
	for i in n:
		if c.arrived[i] == 1:
			continue
		var p := c.pos[i]
		if p.distance_squared_to(_core) < c.stop_at[i] * c.stop_at[i]:
			c.arrived[i] = 1
			continue
		var sp := c.speed[i]
		var v := Vector2.ZERO
		if not flow:
			if c.wp[i] >= _waypoints.size():
				continue
			var target := _waypoints[c.wp[i]] + c.lane[i]
			var to := target - p
			var d := to.length()
			if sp * DT >= d:
				c.pos[i] = target
				c.wp[i] += 1
				continue
			v = to / d * sp
		else:
			if (tick + i) % every == 0:
				if nearest:
					var cx0 := floori(p.x)
					var cy0 := floori(p.y)
					c.cdir[i] = _field.dir[cy0 * _w + cx0] if _field.reachable(cx0, cy0) else Vector2.ZERO
				else:
					var dir := _field.sample(p + c.lane[i] if lane_on else p)
					if lane_on and dir == Vector2.ZERO:  # the offset point is inside a wall: use the agent's own cell
						dir = _field.sample(p)
					c.cdir[i] = dir
			v = c.cdir[i] * sp
			if sep_every > 0:
				if (tick + i) % sep_every == 0:
					var push := Vector2.ZERO
					var cx := clampi(floori(p.x), 0, _w - 1)
					var cy := clampi(floori(p.y), 0, _h - 1)
					var seen := 0
					for oy in range(maxi(cy - 1, 0), mini(cy + 2, _h)):
						for ox in range(maxi(cx - 1, 0), mini(cx + 2, _w)):
							var j := c.head[oy * _w + ox]
							while j != -1 and seen < cap:
								if j != i:
									var off := p - c.pos[j]
									var min_d := c.radius[i] + c.radius[j]
									var d2 := off.length_squared()
									if d2 < min_d * min_d:
										var d := sqrt(d2)
										push += (off / d if d > 1.0e-4 else Vector2.RIGHT) * ((min_d - d) / min_d)
									seen += 1
								j = c.nxt[j]
					c.cpush[i] = push * (sp * SEP_STRENGTH)
				v += c.cpush[i]
		var np := p + v * DT
		if _cell_open(np):
			c.pos[i] = np
		elif _cell_open(Vector2(np.x, p.y)):
			c.pos[i] = Vector2(np.x, p.y)
		elif _cell_open(Vector2(p.x, np.y)):
			c.pos[i] = Vector2(p.x, np.y)


func _run(mode: int, count: int, seed_value: int) -> void:
	_rng.seed = seed_value
	var c := Crowd.new()
	c.head.resize(_w * _h)
	var times: Array[int] = []
	var spawn_end_s := float(count) / _rate
	var ticks := int((maxf(spawn_end_s, OVERLAP_AT_S) + WINDOW_S) / DT)
	var spawned := 0
	var res: Array = [0.0, 0.0, 0]
	var stuck := 0
	for t in ticks:
		var now := float(t) * DT
		var due := mini(count, int(floor(now * _rate)) + 1)
		while spawned < due:
			_spawn(c, spawned, mode)
			spawned += 1
		var t0 := Time.get_ticks_usec()
		_tick(c, mode, t)
		var dt_us := Time.get_ticks_usec() - t0
		if now >= spawn_end_s:
			times.append(dt_us)
		if t == int(OVERLAP_AT_S / DT) - 300:
			c.ref_pos = c.pos.duplicate()
		if t == int(OVERLAP_AT_S / DT):
			res = _overlap(c)
			stuck = _count_stuck(c)
	var sorted := times.duplicate()
	sorted.sort()
	var sum := 0
	for x in times:
		sum += x
	var arrived := 0
	for i in c.size():
		arrived += c.arrived[i]
	print("RESULT | %-18s N=%4d rate=%.0f/s  movement step: avg %7.1f us  p99 %7d us  max %7d us (avg = %.1f%% of a 16.7 ms tick) | at %.0f s: %d moving, %.1f%% have a neighbour closer than half the footprints, %.1f%% touching, %d not progressing | stopped at the end: %d" % [
		MODES[mode]["name"], count, _rate, float(sum) / maxi(times.size(), 1), sorted[int(sorted.size() * 0.99)], sorted[-1],
		float(sum) / maxi(times.size(), 1) / 16667.0 * 100.0, OVERLAP_AT_S, int(res[2]), res[0], res[1], stuck, arrived])


## Of the moving agents: share with another moving agent closer than half the sum of their radii, share that are touching
## (closer than the sum of radii), and how many are moving. Returns [near %, touching %, moving].
func _overlap(c: Crowd) -> Array:
	var grid: Dictionary = {}
	var moving: Array[int] = []
	for i in c.size():
		if c.arrived[i] == 0:
			moving.append(i)
			var key := Vector2i(floori(c.pos[i].x), floori(c.pos[i].y))
			if not grid.has(key):
				grid[key] = [] as Array[int]
			grid[key].append(i)
	var near := 0
	var touching := 0
	for i in moving:
		var k := Vector2i(floori(c.pos[i].x), floori(c.pos[i].y))
		var is_near := false
		var is_touch := false
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var cell: Array = grid.get(k + Vector2i(ox, oy), [])
				for j in cell:
					if j == i:
						continue
					var d: float = c.pos[i].distance_to(c.pos[j])
					var rs: float = c.radius[i] + c.radius[j]
					if d < 0.5 * rs:
						is_near = true
					if d < rs:
						is_touch = true
		if is_near:
			near += 1
		if is_touch:
			touching += 1
	var m := maxi(moving.size(), 1)
	return [100.0 * near / m, 100.0 * touching / m, moving.size()]


## Moving agents that covered less than half a tile in the last 5 simulated seconds (the slowest brute covers 3.5).
func _count_stuck(c: Crowd) -> int:
	var n := 0
	for i in c.size():
		if c.arrived[i] == 0 and c.pos[i].distance_to(c.ref_pos[i]) < 0.5:
			n += 1
	return n
