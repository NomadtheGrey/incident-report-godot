class_name DoorLeaf
extends Node3D

# One interior door, built from its HouseData.DOORS spec.
# The leaf hangs on a pivot at one jamb and swings into its
# room (open_angle follows the spec's swing, defaulting to
# inside_sign, with Godot's mirrored sign convention). It
# opens by proximity when unlocked — or always from inside —
# and locks only from inside, like the privacy knobs in the
# real house (Adam's pin). The basement-stairs leaf is the
# special case: it locks from the room side but swings into
# the room too (its spec carries swing apart from
# inside_sign), because a real basement door never swings
# out over the flight. (Its React twin still swings the
# wrong way — a one-line fix flagged to Adam 2026-11-18.)

const DOOR_H: float = 2.3
const OPEN_RATE: float = 2.4
const OPEN_DIST: float = 1.35
const LOCK_DIST: float = 1.3

var spec: Dictionary = {}
var door_name: String = "Door"
var open01: float = 0.0
var locked: bool = false
var player: Node3D = null

var _pivot: Node3D = null
var _body: StaticBody3D = null
var _shape: CollisionShape3D = null
var _centre: Vector3 = Vector3.ZERO
var _open_angle: float = 0.0

func setup(p_spec: Dictionary) -> void:
	spec = p_spec
	door_name = spec["name"]
	var cx: float = spec["cx"]
	var cz: float = spec["cz"]
	var fy: float = spec["floor_y"]
	var width: float = spec["width"]
	_centre = Vector3(cx, fy, cz)
	var swing: float = spec.get("swing", spec["inside_sign"])
	_pivot = Node3D.new()
	var panel_size: Vector3
	var panel_pos: Vector3
	if spec["wall_axis"] == "x":
		_pivot.position = Vector3(cx, fy, cz - width / 2.0)
		panel_size = Vector3(0.05, DOOR_H, width)
		panel_pos = Vector3(0, DOOR_H / 2.0, width / 2.0)
		_open_angle = -swing * 1.75
	if spec["wall_axis"] == "z":
		_pivot.position = Vector3(cx - width / 2.0, fy, cz)
		panel_size = Vector3(width, DOOR_H, 0.05)
		panel_pos = Vector3(width / 2.0, DOOR_H / 2.0, 0)
		_open_angle = swing * 1.75
	add_child(_pivot)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = panel_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.43, 0.31, 0.18)
	mat.roughness = 0.85
	box.material = mat
	mesh.mesh = box
	mesh.position = panel_pos
	_pivot.add_child(mesh)
	_body = StaticBody3D.new()
	_body.collision_layer = 2
	_body.collision_mask = 0
	_body.set_meta("door", self)
	_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = panel_size
	_shape.shape = shape
	_shape.position = panel_pos
	_body.add_child(_shape)
	_pivot.add_child(_body)

func body() -> StaticBody3D:
	return _body

func _inside(p: Vector3) -> bool:
	if spec["wall_axis"] == "x":
		return signf(p.x - _centre.x) == float(spec["inside_sign"])
	return signf(p.z - _centre.z) == float(spec["inside_sign"])

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var p: Vector3 = player.global_position
	var near: bool = Vector2(p.x - _centre.x, p.z - _centre.z).length() < OPEN_DIST and absf(p.y - _centre.y) < 1.0
	var should_open: bool = near and (not locked or _inside(p))
	var target: float = 1.0 if should_open else 0.0
	var step: float = OPEN_RATE * delta
	if open01 < target:
		open01 = minf(target, open01 + step)
	if open01 > target:
		open01 = maxf(target, open01 - step)
	var o: float = open01
	_pivot.rotation.y = _open_angle * (o * o * (3.0 - 2.0 * o))
	_shape.disabled = open01 > 0.45

func lock_prompt(p: Vector3) -> String:
	if Vector2(p.x - _centre.x, p.z - _centre.z).length() >= LOCK_DIST or absf(p.y - _centre.y) >= 1.0:
		return ""
	if not _inside(p):
		return ""
	if locked:
		return "E — Unlock the " + door_name
	return "E — Lock the " + door_name

func try_toggle_lock(p: Vector3) -> bool:
	if lock_prompt(p) == "":
		return false
	locked = not locked
	return true
