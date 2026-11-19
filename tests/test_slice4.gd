extends SceneTree

# Slice 4 headless suite: the whole wired house. Run with:
#   Godot --headless --script tests/test_slice4.gd
# Checks the six doors (one locks from its own inside), the
# 28-fixture census (React's count), three circuits end to
# end, and a window unit blocking its opening.

var _failures: int = 0
var _main: Node = null
var _player: CharacterBody3D = null

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS ", label)
	if not cond:
		_failures += 1
		print("  FAIL ", label)

func settle(frames: int) -> void:
	for i in frames:
		await physics_frame

func _initialize() -> void:
	_run()

func _fixtures() -> Array:
	var out: Array = []
	for child in _main.get_children():
		if child is FixturePiece:
			out.append(child)
	return out

func _plate_at(group_name: String, near: Vector3) -> FixturePiece:
	for fx in _fixtures():
		var f: FixturePiece = fx
		if f.spec["kind"] == "plate" and f.group_name == group_name:
			if Vector2(f.global_position.x - near.x, f.global_position.z - near.z).length() < 0.3:
				return f
	return null

func _door(id: String) -> DoorLeaf:
	for d in _main.get("doors"):
		if (d as DoorLeaf).spec["id"] == id:
			return d
	return null

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	await settle(10)
	_player = _main.get("player")

	print("D1 the six doors")
	check((_main.get("doors") as Array).size() == 6, "six leaves built (got %d)" % (_main.get("doors") as Array).size())
	check((_main.get("door") as DoorLeaf).spec["id"] == "basement-stairs", "main.door is the basement-stairs leaf")

	print("D2 Bedroom 1 locks from its own inside")
	var bed1: DoorLeaf = _door("bedroom-1")
	_player.global_position = Vector3(-1.6, 2.65, -1.0)
	_player.velocity = Vector3.ZERO
	await settle(3)
	_main.call("_interact")
	check(bed1.locked, "E inside the room locked it")
	_player.global_position = Vector3(-0.4, 2.65, -1.0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = PI / 2.0
	await settle(3)
	Input.action_press("move_forward")
	await settle(120)
	Input.action_release("move_forward")
	check(_player.global_position.x > -0.95, "locked leaf bars the hall side (x=%.2f)" % _player.global_position.x)
	check(bed1.open01 < 0.1, "and never swung for the outsider")
	_player.global_position = Vector3(-1.6, 2.65, -1.0)
	_player.velocity = Vector3.ZERO
	await settle(3)
	_main.call("_interact")
	check(not bed1.locked, "E inside unlocked it again")
	await settle(60)
	check(bed1.open01 > 0.5, "unlocked, it swings for the insider")

	print("F1 the fixture census")
	var kinds: Dictionary = {}
	for fx in _fixtures():
		var k: String = (fx as FixturePiece).spec["kind"]
		kinds[k] = int(kinds.get(k, 0)) + 1
	check(_fixtures().size() == 28, "28 fixtures in the house (got %d)" % _fixtures().size())
	check(int(kinds.get("fan", 0)) == 6 and int(kinds.get("plate", 0)) == 13, "6 fans, 13 plates (got %s)" % str(kinds))
	check(int(kinds.get("lamp", 0)) == 4 and int(kinds.get("prop", 0)) == 4 and int(kinds.get("hood", 0)) == 1, "4 lamps, 4 props, 1 hood")

	print("F2 the hall plate runs the dome")
	var hall_plate: FixturePiece = _plate_at("hall", Vector3(0.16, 0, -0.55))
	check(hall_plate != null and hall_plate.circuit.size() == 1, "hall circuit is the dome alone")
	hall_plate.interact()
	check((hall_plate.circuit[0] as FixturePiece).light_on, "dome lit")
	hall_plate.interact()
	check(not (hall_plate.circuit[0] as FixturePiece).light_on, "dome dark again")

	print("F3 one basement plate runs both bulbs")
	var bs_plate: FixturePiece = _plate_at("basement", Vector3(2.35, 0, -1.76))
	check(bs_plate != null and bs_plate.circuit.size() == 2, "basement circuit holds both bulbs (got %d)" % (bs_plate.circuit.size() if bs_plate != null else -1))
	bs_plate.interact()
	var both_on: bool = true
	for m in bs_plate.circuit:
		if not (m as FixturePiece).light_on:
			both_on = false
	check(both_on, "both bulbs lit together")

	print("F4 the master plate runs fan and lamp")
	var m_plate: FixturePiece = _plate_at("master", Vector3(1.05, 0, 0.81))
	check(m_plate != null and m_plate.circuit.size() == 2, "master circuit is fan + lamp (got %d)" % (m_plate.circuit.size() if m_plate != null else -1))
	m_plate.interact()
	var master_on: bool = true
	for m in m_plate.circuit:
		if not (m as FixturePiece).light_on:
			master_on = false
	check(master_on, "fan and lamp lit together")

	print("W1 a window unit blocks its opening")
	var windows: int = 0
	for child in _main.get_children():
		if child is Piece and (child as Piece).file == "window":
			windows += 1
	check(windows == 4, "four window units placed")
	# The east window: the living-room one's approach is
	# blocked by the couch since the dressing landed (the
	# couch backs onto that wall, as couches do).
	_player.global_position = Vector3(5.0, 0.1, 2.5)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = -PI / 2.0
	await settle(3)
	Input.action_press("move_forward")
	await settle(90)
	Input.action_release("move_forward")
	check(_player.global_position.x < 5.66 and _player.global_position.x > 5.3, "the walker stopped at the glass (x=%.2f)" % _player.global_position.x)

	print("W2 the bake cuts the window openings")
	# The model's walls are solid behind the units (see
	# house.gd WINDOW_CUTS); the bake clips the openings.
	# Physics rays with the units' own colliders excluded:
	# through the living-room opening the ray leaves the
	# house; a metre south the same wall still stops it.
	var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	# The units' colliders are world-space siblings of the
	# pieces (and their node names get uniquified on add, so
	# match by position, not name).
	for child in _main.get_children():
		if child is StaticBody3D:
			for other in _main.get_children():
				if other is Piece and (other as Piece).file == "window":
					var bp: Vector3 = (child as StaticBody3D).global_position
					var pp: Vector3 = (other as Piece).global_position
					if Vector2(bp.x, bp.z).distance_to(Vector2(pp.x, pp.z)) < 0.6:
						exclude.append((child as StaticBody3D).get_rid())
	var q_open := PhysicsRayQueryParameters3D.create(Vector3(-4.2, 1.62, 2.5), Vector3(-9.0, 1.62, 2.5))
	q_open.collision_mask = 1
	q_open.exclude = exclude
	var hit_open: Dictionary = space.intersect_ray(q_open)
	check(hit_open.is_empty() or (hit_open["position"] as Vector3).x < -6.1, "the ray through the window opening leaves the house")
	var q_ctrl := PhysicsRayQueryParameters3D.create(Vector3(-4.2, 1.62, 0.9), Vector3(-9.0, 1.62, 0.9))
	q_ctrl.collision_mask = 1
	q_ctrl.exclude = exclude
	var hit_ctrl: Dictionary = space.intersect_ray(q_ctrl)
	check(not hit_ctrl.is_empty() and absf((hit_ctrl["position"] as Vector3).x + 5.9) < 0.05, "the same wall is intact a metre south (control ray)")

	print("M1 the bathroom mirror reflects")
	var mirror: Node = _main.get("mirror")
	check(mirror != null, "the mirror rig exists")
	_player.global_position = Vector3(0.617, 2.6, -2.6)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_pitch(0.0)
	await settle(3)
	await process_frame
	await process_frame
	var mcam: Camera3D = mirror.get("_cam")
	check(mcam != null, "the mirror camera exists")
	var mo: Vector3 = mcam.global_transform.origin
	# The mirror camera is the FP eye reflected across the
	# rig's own glass plane: same x and y, z mirrored.
	# Computed from the live eye and plane so the check
	# survives eye geometry changes (it baked 0.40-ahead
	# constants once and broke when the pivot moved).
	var eye: Vector3 = _player.get_camera().global_transform.origin
	var plane_z: float = (mirror.get("_plane_point") as Vector3).z
	check(absf(mo.x - eye.x) < 0.02 and absf(mo.y - eye.y) < 0.02 and absf(mo.z - (2.0 * plane_z - eye.z)) < 0.02, "the mirror camera sits mirrored behind the glass (at %.2f, %.2f, %.2f)" % [mo.x, mo.y, mo.z])
	var mf: Vector3 = -mcam.global_transform.basis.z
	check(mf.distance_to(Vector3(0, 0, 1)) < 0.02, "the mirror camera looks back into the room")

	print("W3 the walkthrough seats (fan, plates, coats)")
	var kfan: FixturePiece = null
	for fx in _fixtures():
		if (fx as FixturePiece).spec["kind"] == "fan" and (fx as FixturePiece).group_name == "kitchen":
			kfan = fx as FixturePiece
	check(kfan != null and absf(kfan.global_position.z + 2.75) < 0.01, "the kitchen fan hangs mid-kitchen (z=%.2f)" % (kfan.global_position.z if kfan != null else 0.0))
	check(kfan != null and kfan.global_position.z + 0.65 < -1.70, "its blades clear the stair wall (reach z=%.2f)" % ((kfan.global_position.z + 0.65) if kfan != null else 0.0))
	var kp: FixturePiece = _plate_at("kitchen", Vector3(3.0, 0, -1.7))
	check(kp != null and absf(kp.global_position.z + 1.712) < 0.01, "the kitchen plate sits on its wall (z=%.3f)" % (kp.global_position.z if kp != null else 0.0))
	var bp: FixturePiece = _plate_at("bed1", Vector3(-1.0, 0, -1.55))
	check(bp != null and absf(bp.global_position.x + 1.087) < 0.01, "the Bedroom 1 plate sits on its wall (x=%.3f)" % (bp.global_position.x if bp != null else 0.0))
	var hp2: FixturePiece = _plate_at("hall", Vector3(-0.2, 0, -1.59))
	check(hp2 != null and absf(hp2.global_position.x + 0.2) < 0.01 and absf(hp2.global_position.z + 1.588) < 0.01, "the upstairs hall plate hangs west of the bathroom door, on the wall (at %.2f, %.3f)" % [(hp2.global_position.x if hp2 != null else 0.0), (hp2.global_position.z if hp2 != null else 0.0)])
	var rack: Piece = null
	for child in _main.get_children():
		if child is Piece and (child as Piece).file == "coat-hooks":
			rack = child as Piece
	check(rack != null and absf(rack.global_position.x + 0.95) < 0.01, "the coat rack hangs on the hall's west wall (x=%.3f)" % (rack.global_position.x if rack != null else 0.0))

	if _failures == 0:
		print("SLICE4: ALL PASS")
	if _failures > 0:
		print("SLICE4: ", _failures, " FAILURES")
	quit(1 if _failures > 0 else 0)
