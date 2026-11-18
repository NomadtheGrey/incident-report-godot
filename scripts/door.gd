class_name DoorLeaf
extends Node3D

# One swinging, lockable door leaf, ported from the React
# build's ModelDoor system. The node sits at the hinge pivot;
# the panel extends +z from it when closed.
#
# The basement-stair door (the first instance) locks from the
# room side but swings INTO the room, never out over the
# flight — Adam's pin, and the reason open_angle is decoupled
# from inside_sign. The sign: rotation.y = -1.75 swings the
# panel west, into the room. (The React build's swing sign
# lands it over the flight instead — flagged to Adam
# 2026-11-18; this build follows the pin.)

var door_name: String = "Door"
var centre: Vector3 = Vector3.ZERO
var floor_y: float = 0.0
var inside_sign: float = -1.0
var open_angle: float = -1.75
var width: float = 1.1
var open01: float = 0.0
var locked: bool = false
var player: Node3D = null

var _body: StaticBody3D = null
var _shape: CollisionShape3D = null

const DOOR_H: float = 2.3
const OPEN_RATE: float = 2.4
const OPEN_RANGE: float = 1.35
const LOCK_RANGE: float = 1.3

func setup(spec: Dictionary) -> void:
	door_name = spec["name"]
	centre = spec["centre"]
	floor_y = spec["floor_y"]
	inside_sign = spec["inside_sign"]
	open_angle = spec["open_angle"]
	width = spec["width"]
	position = spec["pivot"]

func _ready() -> void:
	add_to_group("doors")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.43, 0.31, 0.18)
	mat.roughness = 0.85
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, DOOR_H, width)
	box.material = mat
	mesh.mesh = box
	mesh.position = Vector3(0, DOOR_H / 2.0, width / 2.0)
	add_child(mesh)
	_body = StaticBody3D.new()
	_body.collision_layer = 2
	_body.collision_mask = 0
	_shape = CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = Vector3(0.05, DOOR_H, width)
	_shape.shape = shape_box
	_shape.position = Vector3(0, DOOR_H / 2.0, width / 2.0)
	_body.add_child(_shape)
	add_child(_body)

func body() -> StaticBody3D:
	return _body

func is_inside(pos: Vector3) -> bool:
	var off: float = pos.x - centre.x
	if off == 0.0:
		return true
	return signf(off) == inside_sign

func _dist2d(pos: Vector3) -> float:
	return Vector2(pos.x - centre.x, pos.z - centre.z).length()

func _same_floor(pos: Vector3) -> bool:
	return absf(pos.y - floor_y) < 1.0

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var target: float = 0.0
	if _same_floor(player.global_position) and _dist2d(player.global_position) < OPEN_RANGE:
		if not locked or is_inside(player.global_position):
			target = 1.0
	var step: float = OPEN_RATE * delta
	open01 = clampf(open01 + clampf(target - open01, -step, step), 0.0, 1.0)
	var s: float = open01 * open01 * (3.0 - 2.0 * open01)
	rotation.y = open_angle * s
	_shape.disabled = open01 > 0.45

# E near the door, from the inside only (the React rule):
# privacy locks are worked from the room they protect.
func try_toggle_lock(player_pos: Vector3) -> bool:
	if not _same_floor(player_pos):
		return false
	if _dist2d(player_pos) >= LOCK_RANGE:
		return false
	if not is_inside(player_pos):
		return false
	locked = not locked
	return true

func lock_prompt(player_pos: Vector3) -> String:
	if not _same_floor(player_pos):
		return ""
	if _dist2d(player_pos) >= LOCK_RANGE:
		return ""
	if not is_inside(player_pos):
		return ""
	if locked:
		return "E — Unlock the door"
	return "E — Lock the door"
