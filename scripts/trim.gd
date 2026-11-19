class_name Trim
extends Node3D

# Baseboards and door casings, code-generated — Adam left
# the trim to DEV (2026-11-14), sized off the door beside
# him: interior casing ~3 in wide, baseboards ~5 in tall,
# entry doors more substantial. Ported from the React
# build: casings come from the measured-openings table;
# baseboards are derived from the house's baked wall/floor
# triangles, so a future model export re-trims itself.

const OPENINGS: Array = [
	{"axis": "x", "faces": [-1.08, -0.97], "centre": -1.025, "a": -1.45, "b": -0.55, "fy": 2.6, "entry": false},
	{"axis": "x", "faces": [-1.08, -0.97], "centre": -1.025, "a": -0.35, "b": 0.60, "fy": 2.6, "entry": false},
	{"axis": "z", "faces": [-1.70, -1.60], "centre": -1.65, "a": 0.05, "b": 0.95, "fy": 2.6, "entry": false},
	{"axis": "z", "faces": [0.70, 0.80], "centre": 0.75, "a": 0.05, "b": 0.90, "fy": 2.6, "entry": false},
	{"axis": "z", "faces": [0.50, 0.60], "centre": 0.55, "a": -5.0, "b": -3.0, "fy": 0.1, "entry": false},
	{"axis": "x", "faces": [0.00, 0.10], "centre": 0.05, "a": -1.5, "b": -0.5, "fy": 0.1, "entry": false},
	{"axis": "x", "faces": [-1.10, -1.00], "centre": -1.05, "a": 2.5, "b": 3.5, "fy": -2.4, "entry": false},
	{"axis": "z", "faces": [-4.40], "centre": -4.45, "a": 3.10, "b": 3.90, "fy": 0.1, "entry": true},
	{"axis": "z", "faces": [4.40], "centre": 4.45, "a": 3.05, "b": 3.95, "fy": 0.1, "entry": true},
]

const CUTS: Array = [
	["x", -1.08, -1.45, -0.55, 2.6], ["x", -0.97, -1.45, -0.55, 2.6],
	["x", -1.08, -0.35, 0.60, 2.6], ["x", -0.97, -0.35, 0.60, 2.6],
	["z", -1.70, 0.05, 0.95, 2.6], ["z", -1.60, 0.05, 0.95, 2.6],
	["z", 0.70, 0.05, 0.90, 2.6], ["z", 0.80, 0.05, 0.90, 2.6],
	["z", 0.50, -5.0, -3.0, 0.1], ["z", 0.60, -5.0, -3.0, 0.1],
	["x", 0.00, -1.5, -0.5, 0.1], ["x", 0.10, -1.5, -0.5, 0.1],
	["x", -1.10, 2.5, 3.5, -2.4], ["x", -1.00, 2.5, 3.5, -2.4],
	["z", -4.40, 3.10, 3.90, 0.1],
	["z", 4.40, 3.05, 3.95, 0.1],
]

const FLOOR_TOPS: Array = [-2.4, 0.1, 2.6]

var casing_count: int = 0
var baseboard_count: int = 0

var _mat: StandardMaterial3D = null

func _box(size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat
	mi.mesh = box
	mi.position = at
	add_child(mi)

func build(floors: Array, walls: Array) -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.914, 0.894, 0.847)
	_mat.roughness = 0.85
	_build_casings()
	_build_baseboards(floors, walls)

func _build_casings() -> void:
	const H: float = 2.3
	for o in OPENINGS:
		var w: float = 0.115 if o["entry"] else 0.076
		var t: float = 0.024 if o["entry"] else 0.018
		var fy: float = o["fy"]
		for face in o["faces"]:
			var dir: float = 1.0 if face > o["centre"] else -1.0
			var off: float = face + dir * (t / 2.0 + 0.001)
			if o["axis"] == "x":
				_box(Vector3(t, H, w), Vector3(off, fy + H / 2.0, o["a"] - w / 2.0))
				_box(Vector3(t, H, w), Vector3(off, fy + H / 2.0, o["b"] + w / 2.0))
				_box(Vector3(t, w, o["b"] - o["a"] + 2.0 * w), Vector3(off, fy + H + w / 2.0, (o["a"] + o["b"]) / 2.0))
			if o["axis"] == "z":
				_box(Vector3(w, H, t), Vector3(o["a"] - w / 2.0, fy + H / 2.0, off))
				_box(Vector3(w, H, t), Vector3(o["b"] + w / 2.0, fy + H / 2.0, off))
				_box(Vector3(o["b"] - o["a"] + 2.0 * w, w, t), Vector3((o["a"] + o["b"]) / 2.0, fy + H + w / 2.0, off))
			casing_count += 3

func _build_baseboards(floors: Array, walls: Array) -> void:
	const H: float = 0.127  # 5 in, Adam's measurement
	const T: float = 0.014
	# Raw segments from the wall triangles: a wall earns a
	# segment when it stands on a floor top with a real room
	# floor beside its face (stair treads fail the area test).
	var raw: Array = []
	for t in walls:
		var a: Vector3 = t["a"]
		var b: Vector3 = t["b"]
		var c: Vector3 = t["c"]
		var x_flat: bool = maxf(a.x, maxf(b.x, c.x)) - minf(a.x, minf(b.x, c.x)) < 0.01
		var z_flat: bool = maxf(a.z, maxf(b.z, c.z)) - minf(a.z, minf(b.z, c.z)) < 0.01
		if not x_flat and not z_flat:
			continue
		var fy: float = INF
		for f in FLOOR_TOPS:
			# Adam's walls run slab-underside to slab-underside,
			# so a wall's bottom sits 0.1 BELOW its floor top
			# (measured: partitions 2.50 under the 2.6 floor).
			# The React window (-0.03) was too tight for that
			# and silently dropped every partition wall.
			if t["min_y"] >= f - 0.13 and t["min_y"] <= f + 0.07:
				fy = f
		if fy == INF:
			continue
		# The wall must STAND on the floor along a level
		# bottom edge — two of its verts in the window, and
		# a real wall's height above it. Stair-shaft walls
		# fail this on purpose: their bottoms climb with
		# the flight, and a level box drawn from a sloped
		# tri floats across the stairwell (Adam's
		# walkthrough: trim "doesn't need to try to follow
		# stairs"). Landings are floors, so their walls
		# still earn trim; the flights earn none.
		var low: int = 0
		for v in [a, b, c]:
			if v.y >= fy - 0.13 and v.y <= fy + 0.07:
				low += 1
		if low < 2:
			continue
		if t["max_y"] < fy + 0.5:
			continue
		var axis: String = "x" if x_flat else "z"
		var face: float = a.x if x_flat else a.z
		var from: float = minf(a.z, minf(b.z, c.z)) if x_flat else minf(a.x, minf(b.x, c.x))
		var to: float = maxf(a.z, maxf(b.z, c.z)) if x_flat else maxf(a.x, maxf(b.x, c.x))
		if to - from < 0.05:
			continue
		var dirs: Array = []
		for fl in floors:
			if absf(fl["min_y"] - fy) > 0.04 or absf(fl["max_y"] - fy) > 0.04:
				continue
			var area: float = (fl["max_x"] - fl["min_x"]) * (fl["max_z"] - fl["min_z"])
			if area < 0.4:
				continue
			var f_from: float = fl["min_z"] if axis == "x" else fl["min_x"]
			var f_to: float = fl["max_z"] if axis == "x" else fl["max_x"]
			if f_to < from - 0.02 or f_from > to + 0.02:
				continue
			var f_min: float = fl["min_x"] if axis == "x" else fl["min_z"]
			var f_max: float = fl["max_x"] if axis == "x" else fl["max_z"]
			var d_min: float = f_min - face
			var d_max: float = f_max - face
			if d_min < -0.02 and d_max > 0.02:
				dirs = [-1.0, 1.0]
				break
			if d_max > 0.02 and d_min >= -0.36:
				dirs = [1.0]
				break
			if d_min < -0.02 and d_max <= 0.36:
				dirs = [-1.0]
				break
		for dir in dirs:
			raw.append({"axis": axis, "face": face, "dir": dir, "from": from, "to": to, "fy": fy})
	# Merge collinear segments.
	var by_key: Dictionary = {}
	for s in raw:
		var k: String = "%s|%.2f|%s|%s" % [s["axis"], s["face"], str(s["dir"]), str(s["fy"])]
		if not by_key.has(k):
			by_key[k] = []
		by_key[k].append(s)
	var merged: Array = []
	for k in by_key:
		var list: Array = by_key[k]
		list.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["from"] < q["from"])
		var cur: Dictionary = {}
		for s in list:
			if not cur.is_empty() and s["from"] <= cur["to"] + 0.04:
				cur["to"] = maxf(cur["to"], s["to"])
			else:
				if not cur.is_empty():
					merged.append(cur)
				cur = s.duplicate()
		if not cur.is_empty():
			merged.append(cur)
	# Cut the doorways, emit the boxes.
	for s in merged:
		var spans: Array = [[s["from"], s["to"]]]
		for cut in CUTS:
			if cut[0] != s["axis"] or cut[4] != s["fy"] or absf(cut[1] - s["face"]) > 0.13:
				continue
			var next: Array = []
			for span in spans:
				var p: float = span[0]
				var q: float = span[1]
				if cut[3] <= p or cut[2] >= q:
					next.append([p, q])
					continue
				if cut[2] > p:
					next.append([p, cut[2]])
				if cut[3] < q:
					next.append([cut[3], q])
			spans = next
		for span in spans:
			var p: float = span[0]
			var q: float = span[1]
			if q - p < 0.05:
				continue
			var len_m: float = q - p
			var mid: float = (p + q) / 2.0
			var off: float = s["face"] + s["dir"] * (T / 2.0 + 0.001)
			if s["axis"] == "x":
				_box(Vector3(T, H, len_m), Vector3(off, s["fy"] + H / 2.0, mid))
			if s["axis"] == "z":
				_box(Vector3(len_m, H, T), Vector3(mid, s["fy"] + H / 2.0, off))
			baseboard_count += 1
