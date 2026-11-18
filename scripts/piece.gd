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

func _ready() -> void:
	if file != "":
		var packed: PackedScene = load("res://assets/models/furniture/" + file + ".gltf")
		_inner = packed.instantiate() as Node3D
		_inner.scale = Vector3(16, 16, 16)
		var lc: Vector2 = spec["lc"]
		_inner.position = Vector3(-lc.x * 16.0, 0, -lc.y * 16.0)
		add_child(_inner)
	_build_collider()
	_build_look()

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
