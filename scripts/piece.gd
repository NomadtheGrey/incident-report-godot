class_name Piece
extends Node3D

# One furniture piece, ported from the React FURNITURE
# loader: the root sits at (cx, y, cz) turned by yaw; the
# model rides inside at scale 16, offset by its local
# centre, exactly as the React loader placed it. Collision
# comes from the spec (an auto box, or the explicit boxes
# some pieces carry), never from the model's triangles.
# Every piece also carries a look body on layer 4 — the
# player ray reads it for the centre-screen tag; it blocks
# nothing (the player's mask never includes 4).

var spec: Dictionary = {}
var file: String = ""
var display_name: String = ""

var _inner: Node3D = null
var _look_body: StaticBody3D = null
var _look_shapes: Array = []

func setup(p_spec: Dictionary) -> void:
	spec = p_spec
	file = spec["file"]
	display_name = spec["name"]
	name = file if file != "" else spec["name"]
	if spec.has("local_pos"):
		position = spec["local_pos"]
	if spec.has("cx"):
		position = Vector3(spec["cx"], spec["y"], spec["cz"])
	rotation.y = spec.get("yaw", 0.0)
	# A wall-leaning prop (the shovel): Godot's rotation
	# order is YXZ, the same order the React loader set.
	if spec.has("lean"):
		rotation.x = spec["lean"]

func _ready() -> void:
	if file != "":
		var packed: PackedScene = load("res://assets/models/furniture/" + file + ".gltf")
		_inner = packed.instantiate() as Node3D
		_inner.scale = Vector3(16, 16, 16)
		var lc: Vector2 = spec["lc"]
		_inner.position = Vector3(-lc.x * 16.0, 0, -lc.y * 16.0)
		add_child(_inner)
		if file == "curio-cabinet":
			_make_curio_glass()
	_build_collider()
	_build_look()

# The curio's door glass ships opaque — a flat panel the
# good china would never be seen through. Make it real
# glass, as the React loader did.
func _make_curio_glass() -> void:
	for node in _inner.find_children("", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat == null or mat.resource_name != "screen_glass":
				continue
			var dup: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color.a = 0.25
			dup.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			mi.set_surface_override_material(s, dup)

# Wall-mounted pieces (the switch plates, the coat hooks)
# were seated by eye in the React registry, and the eyes
# were off by up to 0.12 — Adam's walkthroughs found
# plates floating off walls and one buried in the plaster.
# Snap the piece's back onto the wall face behind it: the
# house's walls are axis planes, so the snap is a slide
# along the facing axis to the closest wall tri that both
# faces the piece (its outward normal runs with the
# facing, so the far side of the same wall never wins)
# and contains the piece's centre. back_offset is how far
# behind the origin the model's back sits (the plate
# model is centred on its origin: 0.012; back-at-zero
# models pass 0). Returns false when no wall is in reach
# — the piece keeps its registry seat and the caller can
# hear about it.
func snap_to_wall(walls: Array, back_offset: float) -> bool:
	var f := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var back_off: float = position.dot(f) - back_offset
	# The baked wall tris' winding points their normals
	# INTO the solid (measured across the house), so the
	# face on the piece's side of a box wall has n·f ≈ -1;
	# a flat plane wall's single face can point either
	# way. Prefer the inward-facing candidates; fall back
	# to the others only when no inward face is in reach.
	var best_in: float = INF
	var best_out: float = INF
	# Containment is probed at three heights: a plate's
	# origin is its centre, but a floor-standing piece's
	# origin is at its feet (the coat hooks' origin sits
	# below the partition they hang on).
	for probe_y in [position.y, position.y + 0.65, position.y + 1.3]:
		for t in walls:
			var a: Vector3 = t["a"]
			var b: Vector3 = t["b"]
			var c: Vector3 = t["c"]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length() < 0.0001:
				continue
			n = n.normalized()
			var facing: float = n.dot(f)
			if absf(facing) < 0.9:
				continue
			var delta: float = a.dot(f) - back_off
			if delta < -0.45 or delta > 0.06:
				continue
			var p: Vector3 = position + f * delta
			p.y = probe_y
			if not _in_tri(p, a, b, c):
				continue
			if facing < 0.0 and absf(delta) < absf(best_in):
				best_in = delta
			if facing > 0.0 and absf(delta) < absf(best_out):
				best_out = delta
	var best: float = best_in if best_in != INF else best_out
	if best == INF:
		return false
	position += f * best
	return true

# Barycentric point-in-triangle with a small margin, so a
# piece near a tri's diagonal edge still counts its wall.
func _in_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0: Vector3 = b - a
	var v1: Vector3 = c - a
	var v2: Vector3 = p - a
	var d00: float = v0.dot(v0)
	var d01: float = v0.dot(v1)
	var d11: float = v1.dot(v1)
	var d20: float = v2.dot(v0)
	var d21: float = v2.dot(v1)
	var den: float = d00 * d11 - d01 * d01
	if absf(den) < 0.000001:
		return false
	var v: float = (d11 * d20 - d01 * d21) / den
	var w: float = (d00 * d21 - d01 * d20) / den
	return v >= -0.05 and w >= -0.05 and v + w <= 1.05

func _build_collider() -> void:
	var boxes: Array = spec.get("boxes", [])
	var has_auto: bool = spec.get("box", false)
	if boxes.is_empty() and not has_auto:
		return
	var body := StaticBody3D.new()
	body.name = file + "_col"
	body.collision_layer = 1
	body.collision_mask = 0
	get_parent().add_child(body)
	var h: float = spec["h"]
	if not boxes.is_empty():
		# Explicit boxes are world-space rects [x0, x1, z0, z1]
		# spanning the spec height from the piece's floor.
		for rect in boxes:
			var r: Array = rect
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(r[1] - r[0], h, r[3] - r[2])
			cs.shape = box
			cs.position = Vector3((r[0] + r[1]) / 2.0, spec["y"] + h / 2.0, (r[2] + r[3]) / 2.0)
			body.add_child(cs)
		return
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(spec["w"], h, spec["d"])
	cs.shape = box
	body.add_child(cs)
	body.global_transform = global_transform * Transform3D(Basis(), Vector3(0, h / 2.0, 0))

func _build_look() -> void:
	if spec.get("no_look", false):
		return
	_look_body = StaticBody3D.new()
	_look_body.name = file + "_look"
	_look_body.collision_layer = 4
	_look_body.collision_mask = 0
	_look_body.set_meta("piece", self)
	add_child(_look_body)
	_add_look_shapes(_look_body)

# The default look box: the LOOK_Y span when the file has
# one, else the spec height, else the model's own bounds
# (wall cabinets and other height-less pieces).
func _add_look_shapes(body: StaticBody3D) -> void:
	if spec.has("boxes"):
		var h: float = spec["h"]
		for rect in spec["boxes"]:
			var r: Array = rect
			var centre := Vector3((r[0] + r[1]) / 2.0, spec["y"] + h / 2.0, (r[2] + r[3]) / 2.0)
			var local: Vector3 = global_transform.affine_inverse() * centre
			_add_look_box(body, local, Vector3(r[1] - r[0], h, r[3] - r[2]))
		return
	if HouseData.LOOK_Y.has(file):
		var span: Vector2 = HouseData.LOOK_Y[file]
		var size := Vector3(maxf(spec["w"], 0.14), span.y - span.x, maxf(spec["d"], 0.10))
		_add_look_box(body, Vector3(0, (span.x + span.y) / 2.0, 0), size)
		return
	if spec["h"] > 0.0:
		var size := Vector3(maxf(spec["w"], 0.16), maxf(spec["h"], 0.12), maxf(spec["d"], 0.16))
		_add_look_box(body, Vector3(0, size.y / 2.0, 0), size)
		return
	var aabb: AABB = _geometry_aabb()
	if aabb.size.length() > 0.01:
		_add_look_box(body, aabb.get_center(), aabb.size)

func _add_look_box(body: StaticBody3D, centre: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = centre
	body.add_child(cs)
	_look_shapes.append(cs)
	return cs

func _geometry_aabb() -> AABB:
	if _inner == null:
		return AABB()
	var inv: Transform3D = global_transform.affine_inverse()
	var out := AABB()
	var first: bool = true
	for node in _inner.find_children("", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var local: AABB = inv * (mi.global_transform * mi.get_aabb())
		if first:
			out = local
			first = false
		if not first:
			out = out.merge(local)
	return out

func set_look_enabled(on: bool) -> void:
	for cs in _look_shapes:
		(cs as CollisionShape3D).disabled = not on

func look_name() -> String:
	return display_name

func look_prompt(_held: Piece) -> String:
	return ""

func interact() -> void:
	pass
