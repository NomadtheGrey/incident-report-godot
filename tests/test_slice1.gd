extends SceneTree

# Slice 1 proof, headless: the house loads, the player spawns
# in the Master Bedroom, the basement door blocks when locked
# and opens when not, the full descent (south lane, landing,
# north lane) walks to the basement floor, and the door locks
# from the room side only. Run:
#   godot --headless --script tests/test_slice1.gd

var failures: Array = []
var main_node: Node = null
var player: CharacterBody3D = null
var door: Node = null

func _initialize() -> void:
	_run()

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS ", label)
	if not cond:
		failures.append(label)
		print("  FAIL ", label)

func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

func teleport(pos: Vector3, dir: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw_for(dir)

func walk(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame
	Input.action_release(action)

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	main_node = packed.instantiate()
	root.add_child(main_node)
	await physics_frame
	await physics_frame
	player = main_node.get("player")
	door = main_node.get("door")

	print("T1 boot + spawn")
	for i in 30:
		await physics_frame
	check(player != null and door != null, "player and door exist")
	var spawn_pos: Vector3 = player.global_position
	check(spawn_pos.y > 2.5 and spawn_pos.y < 2.75, "player rests on the upstairs floor (y=%.2f)" % spawn_pos.y)
	var zone: String = HouseData.zone_at(spawn_pos.x, spawn_pos.z, spawn_pos.y)
	check(zone == "Master Bedroom", "spawn zone is Master Bedroom (got %s)" % zone)

	print("T2 locked door blocks from the stair side")
	door.set("locked", true)
	teleport(Vector3(2.75, 0.35, -1.05), Vector3(-1, 0, 0))
	await walk("move_forward", 90)
	check(player.global_position.x > 2.15, "walker stopped west of nothing — held east of the leaf (x=%.2f)" % player.global_position.x)
	check(float(door.get("open01")) < 0.1, "locked leaf stayed shut (open01=%.2f)" % float(door.get("open01")))

	print("T3 unlocked door opens and lets him through")
	door.set("locked", false)
	teleport(Vector3(2.75, 0.35, -1.05), Vector3(-1, 0, 0))
	await walk("move_forward", 200)
	check(player.global_position.x < 1.8, "walker passed into the room side (x=%.2f)" % player.global_position.x)

	print("T4 the descent: door, south lane, landing, north lane, basement floor")
	teleport(Vector3(1.05, 0.35, -1.05), Vector3(1, 0, 0))
	Input.action_press("move_forward")
	var landed: bool = false
	for i in 40:
		for j in 30:
			await physics_frame
		if player.global_position.y < -0.95 and player.global_position.y > -1.3 and player.global_position.x > 3.4:
			landed = true
			break
	Input.action_release("move_forward")
	check(landed, "reached the landing (pos=%s)" % str(player.global_position))
	teleport(Vector3(4.6, -0.85, -1.05), Vector3(0, 0, 1))
	await walk("move_forward", 150)
	check(player.global_position.z > -0.25, "crossed the landing to the north lane (z=%.2f)" % player.global_position.z)
	teleport(Vector3(player.global_position.x, -0.85, player.global_position.z), Vector3(-1, 0, 0))
	Input.action_press("move_forward")
	var basement: bool = false
	for i in 40:
		for j in 30:
			await physics_frame
		if player.global_position.y < -2.25:
			basement = true
			break
	Input.action_release("move_forward")
	check(basement, "reached the basement floor (pos=%s)" % str(player.global_position))

	print("T5 lock works from the room side only")
	teleport(Vector3(1.15, 0.35, -1.05), Vector3(1, 0, 0))
	var locked_ok: bool = door.try_toggle_lock(player.global_position)
	check(locked_ok and bool(door.get("locked")), "E locked it from the room side")
	teleport(Vector3(2.75, 0.35, -1.05), Vector3(-1, 0, 0))
	var locked_from_stairs: bool = door.try_toggle_lock(player.global_position)
	check(not locked_from_stairs and bool(door.get("locked")), "no lock/unlock from the stair side")
	await walk("move_forward", 90)
	check(player.global_position.x > 2.15, "locked leaf blocks the stair-side approach (x=%.2f)" % player.global_position.x)

	if failures.is_empty():
		print("SLICE1: ALL PASS")
	if not failures.is_empty():
		print("SLICE1: %d FAILURES" % failures.size())
	quit(0 if failures.is_empty() else 1)
