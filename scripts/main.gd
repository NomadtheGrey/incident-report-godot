extends Node3D

# Bootstrap and wiring only (separation of concerns): the
# environment, the house, the player, the one door, the HUD.
# Each system owns its own logic in its own script.

const HouseScript: GDScript = preload("res://scripts/house.gd")
const HudScript: GDScript = preload("res://scripts/hud.gd")

var player: Player = null
var door: DoorLeaf = null

var _hud: CanvasLayer = null
var _zone_now: String = ""

func _ready() -> void:
	_build_environment()
	var house: Node3D = HouseScript.new()
	add_child(house)
	player = Player.new()
	player.position = Vector3(4.6, 2.65, 1.6)
	player.rotation.y = -PI / 2.0  # spawn faces east, as in the React build
	add_child(player)
	door = DoorLeaf.new()
	door.setup(HouseData.DOOR_SPEC)
	add_child(door)
	door.player = player
	_hud = HudScript.new()
	add_child(_hud)

func _build_environment() -> void:
	# Night (Adam's pin): dark but not pitch black — a low
	# ambient and a whisper of moonlight; real light comes
	# from fixtures the player switches on.
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.010, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.48)
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.68, 0.77, 1.0)
	moon.light_energy = 0.15
	moon.rotation_degrees = Vector3(-50, -30, 0)
	add_child(moon)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		door.try_toggle_lock(player.global_position)

func _physics_process(_delta: float) -> void:
	var zone: String = HouseData.zone_at(player.global_position.x, player.global_position.z, player.global_position.y)
	if zone != _zone_now:
		_zone_now = zone
		_hud.set_zone(zone)
	var tag: String = ""
	var hit: Object = player.look_collider()
	if hit != null and hit == door.body():
		tag = door.door_name
		if door.locked and door.open01 < 0.5:
			tag += " — Locked"
	_hud.set_tag(tag)
	_hud.set_prompt(door.lock_prompt(player.global_position))
