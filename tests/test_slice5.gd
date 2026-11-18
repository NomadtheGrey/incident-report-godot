extends SceneTree

# Slice 5 headless suite: the lived-in house and the trim.
# Run with:
#   Godot --headless --script tests/test_slice5.gd
# Checks the full furniture census against the spec table,
# spot placements (the dining set, the leaning shovel), a
# couch that blocks, and the generated trim.

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

func _pieces() -> Array:
	var out: Array = []
	for child in _main.get_children():
		if child is Piece:
			out.append(child)
	return out

func _by_file(file: String) -> Array:
	var out: Array = []
	for p in _pieces():
		if (p as Piece).file == file:
			out.append(p)
	return out

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	await settle(10)
	_player = _main.get("player")

	print("P1 the census")
	check(_pieces().size() == HouseData.PIECES.size() + HouseData.PROPS.size(), "every spec in the table stands in the house (%d pieces + %d props)" % [HouseData.PIECES.size(), HouseData.PROPS.size()])
	check(_by_file("dining-chair").size() == 8, "eight dining chairs around the table")
	check(_by_file("bed-king").size() == 1 and _by_file("couch-3seat").size() == 1, "the king bed and the big couch are in")
	check(_by_file("outlet-plate").size() == 15 and _by_file("curtains").size() == 4, "outlets and curtains placed")

	print("P2 the shovel leans on the stair wall")
	var shovels: Array = _by_file("shovel")
	check(shovels.size() == 1, "one shovel")
	if shovels.size() == 1:
		var sh: Piece = shovels[0]
		check(absf(sh.rotation.x - (-1.31)) < 0.01, "leaning at its pinned angle (rx=%.2f)" % sh.rotation.x)
		check(absf(sh.global_position.y - (-1.1)) < 0.01, "hanging at the stair height")

	print("P3 the couch is solid")
	var couch: Piece = _by_file("couch-3seat")[0]
	_player.global_position = Vector3(couch.global_position.x + 1.8, 0.1, couch.global_position.z)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = PI / 2.0
	await settle(3)
	Input.action_press("move_forward")
	await settle(90)
	Input.action_release("move_forward")
	check(_player.global_position.x > couch.global_position.x + 0.3, "the walker stopped at the couch (x=%.2f vs couch %.2f)" % [_player.global_position.x, couch.global_position.x])

	print("P4 the East Room can be entered (the armchair fix)")
	# Through the archway mouth at z 1.1, then the open lane
	# at z 2.2 — at the old spots the chairs plugged both.
	_player.global_position = Vector3(0.0, 0.1, 1.1)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = -PI / 2.0
	await settle(3)
	Input.action_press("move_forward")
	await settle(60)
	Input.action_release("move_forward")
	check(_player.global_position.x > 1.6, "through the archway mouth (x=%.2f)" % _player.global_position.x)
	_player.global_position = Vector3(1.6, 0.1, 2.2)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = -PI / 2.0
	await settle(3)
	Input.action_press("move_forward")
	await settle(110)
	Input.action_release("move_forward")
	check(_player.global_position.x > 4.0, "the East Room's open lane (x=%.2f)" % _player.global_position.x)

	print("T1 the trim")
	var trim: Trim = _main.get("trim")
	check(trim.casing_count == 48, "48 casing pieces around the nine openings (got %d)" % trim.casing_count)
	check(trim.baseboard_count > 40, "baseboards run the rooms (%d runs)" % trim.baseboard_count)

	if _failures == 0:
		print("SLICE5: ALL PASS")
	if _failures > 0:
		print("SLICE5: ", _failures, " FAILURES")
	quit(1 if _failures > 0 else 0)
