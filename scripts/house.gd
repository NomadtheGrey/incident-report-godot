extends Node3D

# The house itself: Adam's Blockbench model, imported whole.
#
# The transform from his file space to game space is the
# React build's holder matrix — scale (-16, 16, 16), rotation
# Y +90 degrees, position (0, 0, 0.5) — so game coordinates
# are identical between the two builds and every measured
# number in the React docs stays true here.
#
# The matrix MIRRORS (negative determinant), and a mirrored
# trimesh collides one-way: the first headless route test
# fell through every floor and landed inside the slabs.
# So the transform is BAKED into the geometry at load —
# positions and normals transformed, triangle winding
# reversed to cancel the mirror — and the scene graph stays
# at identity, where physics behaves.

const MODEL_PATH: String = "res://assets/models/all-floors.gltf"
const WINDOW_NAMES: Array = ["Window1", "Window2", "Window3", "Window4"]

# The file-to-game matrix, as a basis: file x maps to game
# +z, file z maps to game +x, everything x16.
const FILE_TO_GAME: Basis = Basis(
	Vector3(0, 0, 16), Vector3(0, 16, 0), Vector3(16, 0, 0)
)
const FILE_ORIGIN: Vector3 = Vector3(0, 0, 0.5)

# The four window reference blocks are skipped; since
# slice 4 the window PIECES fill their openings (and carry
# their own colliders), so the house no longer blocks them.

# The window OPENINGS were never cut in Adam's model — the
# Window1-4 blocks mark where the units go, but the walls
# behind them are solid, so the glass read as a painted panel
# (Adam's playtest, 2026-11-18: "window glass is opaque" —
# proven here by a ray that hits ExteriorWalls at the
# opening's centre, and a render with the unit hidden: a
# flat, unbroken wall). The bake cuts the four openings
# itself: any baked triangle crossing a cut box is clipped
# against the box and its inside part dropped — the same
# bake-corrects-the-model shape as the slab-lip rule below.
# The cut sits inside the unit's frame on every side, so
# the frame hides the cut edge. If Adam cuts the openings
# in Blockbench later, there is simply nothing left to clip.
const WINDOW_CUTS: Array = [
	AABB(Vector3(-6.05, 1.11, -2.99), Vector3(0.35, 0.95, 1.98)),
	AABB(Vector3(-6.05, 1.11, 1.51), Vector3(0.35, 0.95, 1.98)),
	AABB(Vector3(-2.49, 1.11, 4.24), Vector3(1.98, 0.95, 0.35)),
	AABB(Vector3(5.70, 1.11, 1.51), Vector3(0.35, 0.95, 1.98)),
]

# The two exterior doorways stay blocked for now: there is
# no outside yet (no yard, no exterior leaves — both are
# Adam's/model work to come), and a physics walker who
# steps out falls forever. Adam found exactly that on his
# first walkthrough (2026-11-18). [centre, size]
const DOORWAY_BLOCKERS: Array = [
	[Vector3(3.5, 1.25, 4.42), Vector3(0.95, 2.3, 0.2)],
	[Vector3(3.5, 1.25, -4.42), Vector3(0.85, 2.3, 0.2)],
]

# Stair ramps: the model's flights are discrete step boxes,
# which a capsule walker cannot climb. Invisible wedges lie
# over each flight's nosing line and the walker rides those;
# the steps you see are the model's own. Each wedge is a THIN
# SLOPED SLAB (0.3 under its top line, parallel to it): the
# first build used flat-bottomed prisms, whose undersides
# hung into the headroom of the flight below — the stacked
# stairs share one shaft, and a walker on the lower flight
# wears the upper flight's slab as a hat. The top line is
# the flight's NOSING LINE + 0.03, measured off the model
# itself (every flight: 0.20 rise per 0.333 run, slope 0.60;
# the second build's lines sat under the tread tops, so the
# walker rode the treads and met every riser as a wall).
# Each line is extended to meet its landing flush, and cut
# short at the first riser so its end cap never walls the
# doorway. Entries: [x0, x1, z0, z1, top y at x0, top y at x1].
const STAIR_RAMPS: Array = [
	[2.30, 4.33, -1.58, -0.52, 0.148, -1.07],  # basement flight, south lane, down eastward
	[1.85, 4.00, -0.38, 0.68, -2.36, -1.07],   # basement flight, north lane, down westward
	[1.85, 4.02, -0.48, 0.73, 0.142, 1.444],   # up flight, north lane, up eastward
	[2.30, 4.33, -1.68, -0.52, 2.648, 1.43],   # up flight, south lane, up westward
]

func _ready() -> void:
	var packed: PackedScene = load(MODEL_PATH)
	var inst: Node = packed.instantiate()
	_bake_node(inst, Transform3D.IDENTITY)
	inst.queue_free()
	_add_doorway_blockers()
	_add_stair_ramps()

func _add_doorway_blockers() -> void:
	for entry in DOORWAY_BLOCKERS:
		var e: Array = entry
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = e[1]
		shape.shape = box
		body.add_child(shape)
		body.position = e[0]
		add_child(body)

func _bake_node(n: Node, parent_xform: Transform3D) -> void:
	var local: Transform3D = Transform3D.IDENTITY
	if n is Node3D:
		local = (n as Node3D).transform
	var xform: Transform3D = parent_xform * local
	var node_name: String = String(n.name)
	if node_name == "Locators" or node_name.ends_with("Loc"):
		return  # his locator markers: not geometry we keep
	if WINDOW_NAMES.has(node_name):
		return  # reference blocks; the window pieces fill these openings
	if n is MeshInstance3D:
		_bake_mesh(n as MeshInstance3D, xform)
	for child in n.get_children():
		_bake_node(child, xform)

func _bake_mesh(src: MeshInstance3D, node_xform: Transform3D) -> void:
	var world: Transform3D = Transform3D(FILE_TO_GAME, FILE_ORIGIN) * node_xform
	var flip: bool = world.basis.determinant() < 0.0
	var normal_xform: Basis = world.basis.inverse().transposed()
	var baked := ArrayMesh.new()
	var src_mesh: Mesh = src.mesh
	for s in src_mesh.get_surface_count():
		var arrays: Array = src_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			verts[i] = world * verts[i]
		if normals.size() == verts.size():
			for i in normals.size():
				normals[i] = (normal_xform * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		if flip:
			_flip_winding(arrays, src.name)
		arrays = _cut_openings(arrays)
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = src_mesh.surface_get_material(s)
		if mat is BaseMaterial3D:
			# Interior faces show in a house of thin walls;
			# the React build rendered DoubleSide throughout.
			(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		baked.surface_set_material(baked.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = src.name
	mi.mesh = baked
	add_child(mi)
	_add_collision(baked, src.name)

# --- The window-opening cut ---------------------------------
# A vertex record is [position, normal, uv, colour]; edge
# crossings lerp all four (the model's faces are flat, so a
# fragment keeps its parent triangle's normal honestly).

func _cut_openings(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return arrays
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var raw_uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var uvs: PackedVector2Array = raw_uv if raw_uv != null else PackedVector2Array()
	var raw_c: Variant = arrays[Mesh.ARRAY_COLOR]
	var colors: PackedColorArray = raw_c if raw_c != null else PackedColorArray()
	var raw_i: Variant = arrays[Mesh.ARRAY_INDEX]
	var index: PackedInt32Array = raw_i if raw_i != null else PackedInt32Array()
	var tris: Array = []
	if index.size() >= 3:
		var i: int = 0
		while i + 2 < index.size():
			tris.append([index[i], index[i + 1], index[i + 2]])
			i += 3
	else:
		var j: int = 0
		while j + 2 < verts.size():
			tris.append([j, j + 1, j + 2])
			j += 3
	var out_v: PackedVector3Array = []
	var out_n: PackedVector3Array = []
	var out_uv: PackedVector2Array = []
	var out_c: PackedColorArray = []
	var changed: bool = false
	for t in tris:
		var poly: Array = []
		for k in 3:
			var idx: int = t[k]
			poly.append([
				verts[idx],
				normals[idx] if idx < normals.size() else Vector3.UP,
				uvs[idx] if idx < uvs.size() else Vector2.ZERO,
				colors[idx] if idx < colors.size() else Color.WHITE,
			])
		var pieces: Array = [poly]
		for box in WINDOW_CUTS:
			if not _poly_touches(poly, box):
				continue
			changed = true
			var next: Array = []
			for piece in pieces:
				next.append_array(_subtract_box(piece, box))
			pieces = next
			if pieces.is_empty():
				break
		for piece in pieces:
			for f in range(1, piece.size() - 1):
				for rec in [piece[0], piece[f], piece[f + 1]]:
					out_v.append(rec[0])
					out_n.append(rec[1])
					out_uv.append(rec[2])
					out_c.append(rec[3])
	if not changed:
		return arrays
	arrays[Mesh.ARRAY_VERTEX] = out_v
	if normals.size() > 0:
		arrays[Mesh.ARRAY_NORMAL] = out_n
	if uvs.size() > 0:
		arrays[Mesh.ARRAY_TEX_UV] = out_uv
	if colors.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = out_c
	# An identity index keeps the surface indexed like every
	# other surface in the project — an empty index reads back
	# as null from surface_get_arrays, and a typed read of it
	# aborts _add_collision (the wall lost its collision body
	# entirely on the first cut build; the suites' walker
	# never noticed because the window colliders still stood).
	var identity := PackedInt32Array()
	identity.resize(out_v.size())
	for i in out_v.size():
		identity[i] = i
	arrays[Mesh.ARRAY_INDEX] = identity
	# Tangents (and any skinning arrays) are sized for the
	# ORIGINAL vertex count; left in place they no longer
	# match the rebuilt vertices and the surface is rejected
	# wholesale ("array.size() != vertex count * 4" — the
	# second cut build lost the whole ExteriorWalls surface
	# this way). The house's flat colours use none of them.
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	return arrays

func _poly_touches(poly: Array, box: AABB) -> bool:
	var lo: Vector3 = poly[0][0]
	var hi: Vector3 = poly[0][0]
	for rec in poly:
		lo = lo.min(rec[0])
		hi = hi.max(rec[0])
	return AABB(lo, hi - lo).intersects(box)

# The part of a convex polygon that lies OUTSIDE the box, as
# a list of convex polygons: walk the six planes; at each
# plane, what is outside is finished, what is inside goes on
# to be cut by the next plane. What survives all six is the
# box's interior — dropped.
func _subtract_box(poly: Array, box: AABB) -> Array:
	var result: Array = []
	var remaining: Array = [poly]
	var planes: Array = [
		[0, box.position.x, true], [0, box.position.x + box.size.x, false],
		[1, box.position.y, true], [1, box.position.y + box.size.y, false],
		[2, box.position.z, true], [2, box.position.z + box.size.z, false],
	]
	for pl in planes:
		var next: Array = []
		for piece in remaining:
			var outside: Array = _clip_half(piece, pl[0], pl[1], pl[2])
			var inside: Array = _clip_half(piece, pl[0], pl[1], not pl[2])
			if outside.size() >= 3:
				result.append(outside)
			if inside.size() >= 3:
				next.append(inside)
		remaining = next
		if remaining.is_empty():
			break
	return result

func _clip_half(poly: Array, axis: int, value: float, keep_below: bool) -> Array:
	var out: Array = []
	if poly.is_empty():
		return out
	for i in poly.size():
		var cur: Array = poly[i]
		var prev: Array = poly[(i + poly.size() - 1) % poly.size()]
		var cur_in: bool = (cur[0][axis] <= value) if keep_below else (cur[0][axis] >= value)
		var prev_in: bool = (prev[0][axis] <= value) if keep_below else (prev[0][axis] >= value)
		if cur_in:
			if not prev_in:
				out.append(_crossing(prev, cur, axis, value))
			out.append(cur)
		elif prev_in:
			out.append(_crossing(prev, cur, axis, value))
	return out

func _crossing(a: Array, b: Array, axis: int, value: float) -> Array:
	var t: float = (value - a[0][axis]) / (b[0][axis] - a[0][axis])
	return [
		a[0].lerp(b[0], t),
		a[1].lerp(b[1], t).normalized(),
		a[2].lerp(b[2], t),
		a[3].lerp(b[3], t),
	]

# Collision is built by hand from the baked triangles, not
# via create_trimesh_collision, because the model's slab
# LIPS have to be left out: the ExteriorWalls node carries
# 0.1-tall edge ribbons at y 0..0.1 hanging over the stair
# shaft (z -1.4 and z -0.4) — the main slab jutting over the
# lanes instead of ending flush at the wall faces. At a
# walker's head height over the basement landing they wall
# off the crossing; the React build's point-walker mostly
# ignored them, and the lip is on Adam's model-fix list.
# Rule: a vertical triangle no taller than 0.12, sitting in
# the slab band (y -0.02..0.12) over the shaft, is a lip,
# not a wall. The visual mesh keeps every triangle.
# The baked triangles, classified as the React extractor
# classified them (|normal.y| > 0.5 is a floor, everything
# else a wall). The trim generator (trim.gd) derives
# baseboards from these, so a future model export re-trims
# itself the same way.
var floor_tris: Array = []
var wall_tris: Array = []

func _add_collision(mesh: ArrayMesh, mesh_name: String) -> void:
	var faces := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_i: Variant = arrays[Mesh.ARRAY_INDEX]
		var index: PackedInt32Array = raw_i if raw_i != null else PackedInt32Array()
		var tri_count: int = index.size() / 3
		if index.size() == 0:
			tri_count = verts.size() / 3
		for t in tri_count:
			var a: Vector3
			var b: Vector3
			var c: Vector3
			if index.size() > 0:
				a = verts[index[t * 3]]
				b = verts[index[t * 3 + 1]]
				c = verts[index[t * 3 + 2]]
			if index.size() == 0:
				a = verts[t * 3]
				b = verts[t * 3 + 1]
				c = verts[t * 3 + 2]
			_collect_tri(a, b, c)
			if _is_slab_lip(a, b, c):
				continue
			faces.append(a)
			faces.append(b)
			faces.append(c)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = mesh_name + "_col"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _collect_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	var len: float = n.length()
	if len < 1e-10:
		return
	var tri: Dictionary = {
		"a": a, "b": b, "c": c,
		"min_x": minf(a.x, minf(b.x, c.x)), "max_x": maxf(a.x, maxf(b.x, c.x)),
		"min_y": minf(a.y, minf(b.y, c.y)), "max_y": maxf(a.y, maxf(b.y, c.y)),
		"min_z": minf(a.z, minf(b.z, c.z)), "max_z": maxf(a.z, maxf(b.z, c.z)),
	}
	if absf(n.y / len) > 0.5:
		floor_tris.append(tri)
		return
	wall_tris.append(tri)

func _is_slab_lip(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var min_y: float = minf(a.y, minf(b.y, c.y))
	var max_y: float = maxf(a.y, maxf(b.y, c.y))
	if max_y - min_y > 0.12:
		return false
	if min_y < -0.02 or max_y > 0.12:
		return false
	# vertical face: x or z nearly constant across the tri
	var flat_x: bool = maxf(a.x, maxf(b.x, c.x)) - minf(a.x, minf(b.x, c.x)) < 0.02
	var flat_z: bool = maxf(a.z, maxf(b.z, c.z)) - minf(a.z, minf(b.z, c.z)) < 0.02
	if not flat_x and not flat_z:
		return false
	# over the stair shaft only
	var mid_x: float = (a.x + b.x + c.x) / 3.0
	var mid_z: float = (a.z + b.z + c.z) / 3.0
	if mid_x < 1.9 or mid_x > 6.0:
		return false
	if mid_z < -1.7 or mid_z > 0.8:
		return false
	return true

# Reversing each triangle's vertex order cancels the mirror:
# front faces point the way they did in his file. Blockbench
# glTF surfaces are indexed; a non-indexed surface would need
# its per-vertex arrays reordered instead — warn loudly if
# one ever shows up rather than flipping it halfway.
func _flip_winding(arrays: Array, mesh_name: String) -> void:
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.size() == 0:
		push_warning("house: non-indexed surface on %s — winding not flipped" % mesh_name)
		return
	for t in range(0, index.size(), 3):
		var tmp: int = index[t + 1]
		index[t + 1] = index[t + 2]
		index[t + 2] = tmp
	arrays[Mesh.ARRAY_INDEX] = index



func _add_stair_ramps() -> void:
	for entry in STAIR_RAMPS:
		var e: Array = entry
		var x0: float = e[0]
		var x1: float = e[1]
		var z0: float = e[2]
		var z1: float = e[3]
		var yt0: float = e[4]
		var yt1: float = e[5]
		var yb0: float = yt0 - 0.3
		var yb1: float = yt1 - 0.3
		var wedge := ConvexPolygonShape3D.new()
		wedge.points = PackedVector3Array([
			Vector3(x0, yb0, z0), Vector3(x1, yb1, z0),
			Vector3(x1, yb1, z1), Vector3(x0, yb0, z1),
			Vector3(x0, yt0, z0), Vector3(x1, yt1, z0),
			Vector3(x1, yt1, z1), Vector3(x0, yt0, z1),
		])
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = wedge
		body.add_child(shape)
		add_child(body)
