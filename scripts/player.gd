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
var _ray: RayCast3D = null
var _pitch: float = 0.0

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
	var camera := Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 120.0
	_head.add_child(camera)
	_ray = RayCast3D.new()
	_ray.enabled = true
	_ray.target_position = Vector3(0, 0, -2.75)
	_ray.collision_mask = 2  # door leaves for now; items join later
	camera.add_child(_ray)

func look_collider() -> Object:
	if _ray == null:
		return null
	if not _ray.is_colliding():
		return null
	return _ray.get_collider()

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
	move_and_slide()
