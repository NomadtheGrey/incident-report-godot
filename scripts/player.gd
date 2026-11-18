class_name Player
extends CharacterBody3D

# The walker, ported numbers-first from the React build:
# capsule radius 0.22, height 1.6, eye 1.62, walk 2.9 m/s,
# run 4.6 m/s, camera 72 degrees vertical (Adam's pin — the
# FOV is fenced, do not tune it). The body's origin sits at
# the feet, so global_position.y IS the ground the walker
# stands on; zones and door floor-gates read it directly.

const WALK_SPEED: float = 2.9
const RUN_SPEED: float = 4.6
const EYE_HEIGHT: float = 1.62
const GRAVITY: float = 22.0
const MOUSE_SENS: float = 0.0022

var _head: Node3D = null
var _camera: Camera3D = null
var _ray: RayCast3D = null
var _pitch: float = 0.0
var _rig: CharacterRig = null
var _spring: SpringArm3D = null
var _tp_camera: Camera3D = null

var view_tp: bool = false
var tp_dist: float = 3.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 3  # world (1) + door leaves (2)
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	_head = Node3D.new()
	_head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(_head)
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.near = 0.05
	_camera.far = 120.0
	# The eye sits 0.16 ahead of the head axis (the React FP
	# body fix): the whole head stays behind the near plane,
	# so looking down shows his own torso, and the mirror
	# shows the whole man.
	_camera.position = Vector3(0, 0, -0.16)
	_head.add_child(_camera)
	# Third person: a spring arm off the head — the boom
	# shortens against walls and ceilings on its own, which
	# is what keeps the ceiling out of the TP camera.
	_spring = SpringArm3D.new()
	_spring.spring_length = tp_dist
	_spring.collision_mask = 1
	_spring.margin = 0.1
	_head.add_child(_spring)
	_tp_camera = Camera3D.new()
	_tp_camera.fov = 72.0
	_tp_camera.near = 0.05
	_tp_camera.far = 120.0
	_spring.add_child(_tp_camera)
	_rig = CharacterRig.new()
	add_child(_rig)
	_ray = RayCast3D.new()
	_ray.enabled = true
	_ray.target_position = Vector3(0, 0, -2.75)
	_ray.collision_mask = 6  # door leaves (2) + piece look targets (4)
	_camera.add_child(_ray)

func look_collider() -> Object:
	if _ray == null:
		return null
	if not _ray.is_colliding():
		return null
	return _ray.get_collider()

# Up to three hits along the centre ray, nearest first.
# The look resolution in main.gd needs more than the first
# hit: the React build gave search targets a small distance
# bias because the counter's fat box occludes the drawer
# front recessed inside it — with only the nearest hit the
# drawer could never win its own ray.
func look_hits() -> Array:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z
	var hits: Array = []
	var exclude: Array[RID] = []
	for i in 3:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2.75)
		q.collision_mask = 6
		q.exclude = exclude
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		hits.append(hit)
		exclude.append(hit["rid"])
	return hits

func get_camera() -> Camera3D:
	return _camera

func get_tp_camera() -> Camera3D:
	return _tp_camera

func set_view_tp(on: bool) -> void:
	view_tp = on
	if on:
		_tp_camera.current = true
	if not on:
		_camera.current = true

func set_tp_dist(d: float) -> void:
	tp_dist = clampf(d, 1.2, 4.5)
	_spring.spring_length = tp_dist

func hand_anchor() -> BoneAttachment3D:
	if _rig == null:
		return null
	return _rig.hand_anchor

func play_oneshot(clip: String) -> void:
	if _rig != null:
		_rig.play_oneshot(clip)

# Tests and touch look set the pitch directly; mouse look
# keeps it clamped in _unhandled_input.
func set_pitch(p: float) -> void:
	_pitch = clampf(p, -1.45, 1.45)
	_head.rotation.x = _pitch

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mm.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - mm.relative.y * MOUSE_SENS, -1.45, 1.45)
		_head.rotation.x = _pitch
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var ix: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var iz: float = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var wish: Vector3 = transform.basis * Vector3(ix, 0, iz)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var speed: float = WALK_SPEED
	if Input.is_action_pressed("run"):
		speed = RUN_SPEED
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if is_on_floor():
		velocity.y = -0.5
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	# Locomotion reads the INTENDED speed, captured before
	# the slide: move_and_slide rewrites velocity to the
	# slid result, which reads ~0 when he pushes on a wall.
	var wish_speed: float = Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	if _rig != null:
		_rig.set_locomotion(wish_speed)
