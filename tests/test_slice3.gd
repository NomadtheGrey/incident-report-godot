extends SceneTree

# Slice 3 headless suite: the homeowner. Run with:
#   Godot --headless --script tests/test_slice3.gd
# Checks the assembled model, the layered animation split,
# locomotion, one-shots, the view toggle with its boom, and
# where a held item rides in each view.

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

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	await settle(10)
	_player = _main.get("player")
	var rig: Node = _player.get("_rig")
	var legs: AnimationPlayer = rig.get("_legs")
	var upper: AnimationPlayer = rig.get("_upper")

	print("C1 the man himself")
	check(rig != null and legs != null and upper != null, "rig and both animation layers built")
	check(_player.hand_anchor() != null, "WeaponR hand anchor exists")
	var legs_lib: AnimationLibrary = legs.get_animation_library("")
	var upper_lib: AnimationLibrary = upper.get_animation_library("")
	check(legs_lib.get_animation_list().size() == 3, "legs library holds the 3 locomotion clips (got %s)" % str(legs_lib.get_animation_list()))
	check(upper_lib.get_animation_list().size() == 9, "upper library holds all 9 clips (got %d)" % upper_lib.get_animation_list().size())
	check(legs.current_animation == "Idle" and upper.current_animation == "Idle", "idle at spawn")

	print("C2 locomotion follows the stick")
	Input.action_press("move_forward")
	await settle(30)
	check(legs.current_animation == "Walk", "walk clip while walking (got %s)" % legs.current_animation)
	Input.action_press("run")
	await settle(30)
	check(legs.current_animation == "Run", "run clip while running (got %s)" % legs.current_animation)
	Input.action_release("run")
	Input.action_release("move_forward")
	await settle(30)
	check(legs.current_animation == "Idle", "back to idle (got %s)" % legs.current_animation)

	print("C3 a one-shot plays on the upper body only")
	_player.play_oneshot("Use _ press")
	await settle(3)
	check(upper.current_animation == "Use _ press", "upper plays the one-shot (got %s)" % upper.current_animation)
	check(legs.current_animation == "Idle", "legs keep locomotion during it")
	var resumed: bool = false
	for i in 300:
		await physics_frame
		if upper.current_animation == "Idle":
			resumed = true
			break
	check(resumed, "upper returns to locomotion when the one-shot ends")

	print("C4 the view toggle and the boom")
	check(not _player.view_tp and _player.get_camera().current, "first person at spawn")
	# The head stays on in both views (Adam rejected the
	# shrunken head); the FP eye rides 0.28 ahead of a
	# pitch pivot that itself sits 0.14 ahead of the axis
	# (0.42 in all — the forward pivot is what keeps the
	# eye out of the chest at steep down-pitch), and the
	# eye pulls in when a wall is closer.
	var skel: Skeleton3D = rig.get("_skel")
	var head_i: int = skel.find_bone("Head")
	await settle(5)
	var fp_scale: float = skel.get_bone_global_pose(head_i).basis.get_scale().x
	check(fp_scale > 0.9, "FP: the head is on (scale=%.3f)" % fp_scale)
	check(absf(_player.get_camera().position.z + 0.28) < 0.02, "FP: the eye rides 0.28 ahead of the pivot in the open (z=%.2f)" % _player.get_camera().position.z)
	var ev := InputEventAction.new()
	ev.action = "toggle_view"
	ev.pressed = true
	_main.call("_unhandled_input", ev)
	await settle(3)
	check(_player.view_tp and _player.get_tp_camera().current, "V switched to third person")
	await settle(5)
	var tp_scale: float = skel.get_bone_global_pose(head_i).basis.get_scale().x
	check(tp_scale > 0.9, "TP: the head is on (scale=%.3f)" % tp_scale)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_main.call("_unhandled_input", wheel)
	check(absf(_player.tp_dist - 3.35) < 0.01, "wheel trimmed the boom (dist=%.2f)" % _player.tp_dist)
	_main.call("_unhandled_input", ev)
	await settle(3)
	check(not _player.view_tp and _player.get_camera().current, "V switched back to first person")
	# Face the east wall: the pivot is 0.14 ahead of the
	# axis, so the wall is ~0.16 from the pivot and the
	# eye pulls in off its 0.28 ride to just short of it.
	_player.global_position = Vector3(5.6, 2.65, 1.6)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = -PI / 2.0
	await settle(30)
	check(_player.get_camera().position.z > -0.20, "FP: the eye pulls in at a wall (z=%.2f)" % _player.get_camera().position.z)

	print("C5 a held item rides the camera in FP, the hand in TP")
	var skillet: Piece = null
	for child in _main.get_children():
		if child is Piece and (child as Piece).file == "skillet":
			skillet = child
	_player.global_position = Vector3(2.6, 0.1, -3.35)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_pitch(-0.72)
	await settle(5)
	_main.call("_interact")
	check(_main.get("held") == skillet, "skillet picked up")
	check(skillet.get_parent() == _player.get_camera(), "FP: skillet rides the camera")
	_main.call("_unhandled_input", ev)
	await settle(3)
	check(skillet.get_parent() == _player.hand_anchor(), "TP: skillet rides the WeaponR hand")
	_main.call("_unhandled_input", ev)
	await settle(3)
	check(skillet.get_parent() == _player.get_camera(), "FP again: skillet back on the camera")

	print("C6 opening the door plays its one-shot")
	_player.global_position = Vector3(1.05, 0.35, -1.05)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = -PI / 2.0
	_player.set_pitch(0.0)
	var saw_open_door: bool = false
	for i in 150:
		await physics_frame
		if upper.current_animation == "Open door":
			saw_open_door = true
			break
	check(saw_open_door, "upper body played Open door as the leaf swung")

	if _failures == 0:
		print("SLICE3: ALL PASS")
	if _failures > 0:
		print("SLICE3: ", _failures, " FAILURES")
	quit(1 if _failures > 0 else 0)
