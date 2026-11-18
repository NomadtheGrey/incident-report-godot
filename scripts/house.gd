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
	_add_stair_ramps()

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
func _add_collision(mesh: ArrayMesh, mesh_name: String) -> void:
	var faces := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
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
