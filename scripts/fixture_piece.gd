class_name FixturePiece
extends Piece

# A switchable light fixture, ported from the React batch-2
# system: fixtures start OFF (the night pin), E toggles the
# one you are looking at, and a switch plate toggles its
# whole circuit (on if any member is off, else all off).
# Off lights are invisible — Godot excludes them from
# rendering entirely, the same trick the React build used.
# The fan has two cords: E pulls the light cord, F the fan
# cord (React's mapping).

var group_name: String = ""
var circuit: Array = []  # the group's light fixtures (plates read this)

var light_on: bool = false
var spin_on: bool = false

var _light: OmniLight3D = null
var _spinner: Node3D = null
var _glow: Array = []  # [MeshInstance3D, StandardMaterial3D] pairs

func setup(p_spec: Dictionary) -> void:
	super.setup(p_spec)
	group_name = spec.get("group", "")

func _ready() -> void:
	super._ready()
	if spec["kind"] == "fan":
		_light = _make_light(Vector3(0, -0.52, 0), Color(1.0, 0.85, 0.63), 1.6, 8.0)
		_build_spinner()
		_find_glow()
	if spec["kind"] == "hood":
		_light = _make_light(Vector3(0, 1.5, 0.35), Color(1.0, 0.90, 0.72), 1.1, 3.2)

func _make_light(at: Vector3, colour: Color, energy: float, range_m: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = range_m
	light.visible = false
	add_child(light)
	return light

func _build_spinner() -> void:
	var blades: Array = []
	for node in _inner.find_children("", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.name.begins_with("blade_"):
			blades.append(mi)
	if blades.is_empty():
		return
	_spinner = Node3D.new()
	_spinner.name = "Spinner"
	_inner.add_child(_spinner)
	_spinner.position = Vector3(0, (blades[0] as MeshInstance3D).position.y, 0)
	for blade in blades:
		(blade as Node3D).reparent(_spinner, true)

func _find_glow() -> void:
	for node in _inner.find_children("", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not mi.name.begins_with("light_dome"):
			continue
		var mat: Material = mi.get_surface_override_material(0)
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0)
		if mat == null:
			continue
		var dup: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		mi.set_surface_override_material(0, dup)
		_glow.append([mi, dup])

func set_light(on: bool) -> void:
	light_on = on
	if _light != null:
		_light.visible = on
	for pair in _glow:
		var mat: StandardMaterial3D = pair[1]
		mat.emission_enabled = on
		if on:
			mat.emission = Color(1.0, 0.79, 0.48)
			mat.emission_energy_multiplier = 1.4

func toggle_spin() -> void:
	spin_on = not spin_on

func interact() -> void:
	if spec["kind"] == "plate":
		var any_off: bool = false
		for member in circuit:
			if not (member as FixturePiece).light_on:
				any_off = true
		for member in circuit:
			(member as FixturePiece).set_light(any_off)
		return
	set_light(not light_on)

func look_prompt(_held: Piece) -> String:
	if spec["kind"] == "plate":
		return "E — Lights"
	if spec["kind"] == "fan":
		return "E — Light cord · F — Fan cord"
	return "E — Light"

func _physics_process(delta: float) -> void:
	if spin_on and _spinner != null:
		_spinner.rotation.y -= delta * 7.5
