class_name ItemPiece
extends Piece

# A pickupable household item (the React PICKUPABLE set).
# One item in hand at a time; E on another item swaps. The
# grip poses are the React GRIP_FP numbers. A sealed item
# (the hammer inside the shut drawer) has its look target
# disabled — the centre ray passes through to whatever is
# behind it, exactly as the React sealed flag behaved.

var sealed: bool = false
var held: bool = false

func set_sealed(on: bool) -> void:
	sealed = on
	set_look_enabled(not on and not held)

func look_prompt(held_item: Piece) -> String:
	if held_item == self:
		return ""
	if held_item != null:
		return "E — Swap for " + display_name
	return "E — Pick up " + display_name

func attach_to_camera(camera: Camera3D) -> void:
	held = true
	set_look_enabled(false)
	reparent(camera, false)
	var grip: Array = HouseData.GRIPS[file]
	position = grip[0]
	rotation = grip[1]

func detach_to_world(world_parent: Node, at: Vector3, facing_yaw: float) -> void:
	held = false
	reparent(world_parent, false)
	global_position = at
	rotation = Vector3(0, facing_yaw, 0)
	set_look_enabled(not sealed)
