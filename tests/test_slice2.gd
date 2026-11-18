extends SceneTree

# Slice 2 headless suite: the kitchen systems. Run with:
#   Godot --headless --script tests/test_slice2.gd
# Aims are staged from the React drive geometry (eye 1.72,
# centre ray): drawer from (1.45, -2.72), plate from
# (3.0, -2.62), fan from (3.5, -3.4).

var _failures: int = 0
var _main: Node = null
var _player: CharacterBody3D = null

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS ", label)
	if not cond:
		_failures += 1
		print("  FAIL ", label)

func find_piece(file_name: String) -> Piece:
	for child in _main.get_children():
		if child is Piece and (child as Piece).file == file_name:
			return child as Piece
	return null

func aim(pos: Vector3, yaw: float, pitch: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	_player.set_pitch(pitch)
	for i in 4:
		await physics_frame

func wait_until(callable: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if callable.call():
			return true
		await physics_frame
	return callable.call()

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	await physics_frame
	await physics_frame
	_player = _main.get("player")
	var drawer: SearchableDrawer = find_piece("junk-drawer") as SearchableDrawer
	var hammer: ItemPiece = drawer.content
	var skillet: ItemPiece = find_piece("skillet") as ItemPiece
	var pot: ItemPiece = find_piece("pot") as ItemPiece
	var fan: FixturePiece = find_piece("ceiling-fan") as FixturePiece
	var hood: FixturePiece = find_piece("range-hood") as FixturePiece
	var plate: FixturePiece = find_piece("switch-plate") as FixturePiece

	print("S1 pieces present, drawer starts shut and sealed")
	check(drawer != null and skillet != null and fan != null and plate != null, "kitchen pieces built")
	check(drawer.open01 == 0.0, "drawer open01 is 0")
	check(absf(drawer.position.z - (-4.11)) < 0.01, "drawer sits at the closed offset (z=%.3f)" % drawer.position.z)
	check(hammer.sealed, "hammer starts sealed")

	print("S2 open the junk drawer")
	await aim(Vector3(1.45, 0.1, -2.72), 0.0, -0.66)
	check(_main.get("_look_piece") == drawer, "look target is the drawer")
	check(drawer.look_prompt(null) == "E — Open the junk drawer", "prompt offers to open")
	_main.call("_interact")
	var opened: bool = await wait_until(func() -> bool: return drawer.open01 > 0.95, 120)
	check(opened, "drawer slid open (open01=%.2f)" % drawer.open01)
	check(not hammer.sealed, "hammer unsealed once open")

	print("S3 take the hammer")
	await aim(Vector3(1.45, 0.1, -2.72), 0.0, -0.85)
	check(_main.get("_look_piece") == hammer, "look target is the hammer (got %s)" % str(_main.get("_look_piece")))
	_main.call("_interact")
	check(_main.get("held") == hammer, "hammer is held")
	check(hammer.get_parent() == _player.get_camera(), "hammer rides the camera")

	print("S4 close the drawer by its pull band")
	await aim(Vector3(1.45, 0.1, -2.72), 0.0, -0.81)
	check(_main.get("_look_piece") == drawer, "look target is the drawer band")
	_main.call("_interact")
	var closed: bool = await wait_until(func() -> bool: return drawer.open01 < 0.05, 120)
	check(closed, "drawer closed again (open01=%.2f)" % drawer.open01)

	print("S5 swap the hammer for the skillet")
	await aim(Vector3(2.6, 0.1, -3.35), 0.0, -0.72)
	check(_main.get("_look_piece") == skillet, "look target is the skillet (got %s)" % str(_main.get("_look_piece")))
	check(skillet.look_prompt(hammer) == "E — Swap for Cast Iron Skillet", "swap prompt")
	_main.call("_interact")
	check(_main.get("held") == skillet, "skillet is held")
	check(hammer.get_parent() == _main, "hammer was dropped in the swap")
	var dx: float = hammer.global_position.x - _player.global_position.x
	var dz: float = hammer.global_position.z - _player.global_position.z
	check(sqrt(dx * dx + dz * dz) < 1.0, "hammer dropped at the player's feet")

	print("S6 put the skillet down")
	await aim(Vector3(2.6, 0.1, -3.35), PI, 1.2)
	check(_main.get("_look_piece") == null, "looking at nothing (got %s)" % str(_main.get("_look_piece")))
	_main.call("_interact")
	check(_main.get("held") == null, "hands empty after put-down")
	check(skillet.get_parent() == _main, "skillet back in the world")

	print("S7 the plate runs the kitchen circuit")
	await aim(Vector3(3.0, 0.1, -2.62), PI, -0.45)
	check(_main.get("_look_piece") == plate, "look target is the plate (got %s)" % str(_main.get("_look_piece")))
	_main.call("_interact")
	check(fan.light_on and hood.light_on, "plate turned the fan and hood lights on")
	_main.call("_interact")
	check(not fan.light_on and not hood.light_on, "plate turned them off again")

	print("S8 the fan's own cords")
	await aim(Vector3(3.5, 0.1, -3.4), PI, 0.32)
	check(_main.get("_look_piece") == fan, "look target is the fan (got %s)" % str(_main.get("_look_piece")))
	_main.call("_interact")
	check(fan.light_on and not hood.light_on, "E lit only the fan")
	var ev := InputEventAction.new()
	ev.action = "fan_cord"
	ev.pressed = true
	_main.call("_unhandled_input", ev)
	check(fan.spin_on, "F started the fan motor")
	var before: float = (fan.get("_spinner") as Node3D).rotation.y
	for i in 30:
		await physics_frame
	var after: float = (fan.get("_spinner") as Node3D).rotation.y
	check(absf(after - before) > 0.5, "blades turn (%.2f -> %.2f)" % [before, after])

	print("S9 the pot comes off the range")
	await aim(Vector3(4.37, 0.1, -3.3), 0.0, -0.71)
	check(_main.get("_look_piece") == pot, "look target is the pot (got %s)" % str(_main.get("_look_piece")))
	_main.call("_interact")
	check(_main.get("held") == pot, "pot is held")

	if _failures == 0:
		print("SLICE2: ALL PASS")
	if _failures > 0:
		print("SLICE2: ", _failures, " FAILURES")
	quit(1 if _failures > 0 else 0)
