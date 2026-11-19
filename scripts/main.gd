extends Node3D

# Bootstrap and wiring only (separation of concerns): the
# environment, the house, the player, the door, the kitchen
# pieces, the HUD. Each system owns its logic in its own
# script; this file only connects them and routes the
# contextual E key the way the React build did:
# pick up / swap -> fixture -> searchable -> door lock ->
# put down.

const HouseScript: GDScript = preload("res://scripts/house.gd")
const HudScript: GDScript = preload("res://scripts/hud.gd")
const TrimScript: GDScript = preload("res://scripts/trim.gd")

var trim: Trim = null
var mirror: Mirror = null

var player: Player = null
var door: DoorLeaf = null  # the basement-stairs leaf (kept named for the suites)
var doors: Array = []
var held: ItemPiece = null

var _hud: CanvasLayer = null
var _zone_now: String = ""
var _look_piece: Piece = null
var _door_was_shut: Array = []
var _wall_tris: Array = []

func _ready() -> void:
	_build_environment()
	var house: Node3D = HouseScript.new()
	add_child(house)
	trim = TrimScript.new()
	add_child(trim)
	trim.build(house.get("floor_tris"), house.get("wall_tris"))
	_wall_tris = house.get("wall_tris")
	player = Player.new()
	player.position = Vector3(4.6, 2.65, 1.6)
	player.rotation.y = -PI / 2.0  # spawn faces east, as in the React build
	add_child(player)
	for dspec in HouseData.DOORS:
		var leaf := DoorLeaf.new()
		leaf.setup(dspec)
		add_child(leaf)
		leaf.player = player
		doors.append(leaf)
		_door_was_shut.append(true)
		if dspec["id"] == "basement-stairs":
			door = leaf
	_build_pieces()
	_hud = HudScript.new()
	add_child(_hud)

func _build_pieces() -> void:
	var circuits: Dictionary = {}
	var plates: Array = []
	var drawer: SearchableDrawer = null
	for spec in HouseData.PIECES:
		var piece: Piece = null
		match spec["kind"]:
			"item":
				piece = ItemPiece.new()
			"fan", "hood", "plate", "lamp":
				piece = FixturePiece.new()
			"drawer":
				piece = SearchableDrawer.new()
				drawer = piece as SearchableDrawer
			_:
				piece = Piece.new()
		piece.setup(spec)
		# Wall-mounted pieces snap their backs onto the
		# wall face (their registry seats were eyeballed;
		# see Piece.snap_to_wall). Before add_child, so
		# the collider and look body build at the seat.
		if spec["kind"] == "plate":
			piece.snap_to_wall(_wall_tris, 0.012)
		if spec["file"] == "coat-hooks":
			piece.snap_to_wall(_wall_tris, 0.0)
		add_child(piece)
		if piece is FixturePiece:
			var fx: FixturePiece = piece as FixturePiece
			if fx.spec["kind"] == "plate":
				plates.append(fx)
			if fx.spec["kind"] != "plate" and fx.group_name != "":
				if not circuits.has(fx.group_name):
					circuits[fx.group_name] = []
				circuits[fx.group_name].append(fx)
	# The code-built fixtures (dome, vanity bar, basement
	# bulbs) ride the same circuit system.
	for pspec in HouseData.PROPS:
		var prop := FixturePiece.new()
		prop.setup({
			"file": "", "name": pspec["name"], "kind": "prop", "group": pspec["group"],
			"lc": Vector2.ZERO, "w": 0.2, "d": 0.2, "h": 0.0, "box": false, "no_look": true,
			"cx": pspec["at"].x, "y": pspec["at"].y, "cz": pspec["at"].z, "yaw": 0.0,
			"light_at": pspec["light_at"], "energy": pspec["energy"], "range": pspec["range"],
			"visual": pspec["visual"],
		})
		add_child(prop)
		if not circuits.has(pspec["group"]):
			circuits[pspec["group"]] = []
		circuits[pspec["group"]].append(prop)
	for plate in plates:
		(plate as FixturePiece).circuit = circuits.get((plate as FixturePiece).group_name, [])
	# The bathroom mirror reflects for real (see mirror.gd).
	for child in get_children():
		if child is Piece and (child as Piece).file == "mirror":
			mirror = Mirror.new()
			add_child(mirror)
			mirror.attach(player, child as Piece)
	# The claw hammer starts inside the junk drawer, sealed
	# until the drawer opens (see drawer.gd).
	var hammer: ItemPiece = ItemPiece.new()
	hammer.setup(HouseData.HAMMER_SPEC)
	drawer.add_child(hammer)
	drawer.content = hammer
	hammer.set_sealed(true)

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
		_interact()
	if event.is_action_pressed("fan_cord"):
		if _look_piece is FixturePiece and _look_piece.spec["kind"] == "fan":
			(_look_piece as FixturePiece).toggle_spin()
	if event.is_action_pressed("toggle_view"):
		player.set_view_tp(not player.view_tp)
		_seat_held()
	if event is InputEventMouseButton and player.view_tp:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			player.set_tp_dist(player.tp_dist - 0.35)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			player.set_tp_dist(player.tp_dist + 0.35)

func _interact() -> void:
	if _look_piece != null:
		if _look_piece is ItemPiece:
			_pick_up(_look_piece as ItemPiece)
			return
		if _look_piece is FixturePiece or _look_piece is SearchableDrawer:
			_look_piece.interact()
			player.play_oneshot("Use _ press")
			return
	for leaf in doors:
		if (leaf as DoorLeaf).try_toggle_lock(player.global_position):
			player.play_oneshot("Use _ press")
			return
	if held != null:
		_drop_held()

func _pick_up(item: ItemPiece) -> void:
	if held != null:
		_drop_held()
	held = item
	_seat_held()
	player.play_oneshot("Pick up (ground)")

func _seat_held() -> void:
	if held == null:
		return
	if player.view_tp and player.hand_anchor() != null:
		held.attach_to_hand(player.hand_anchor())
		return
	held.attach_to_camera(player.get_camera())

func _drop_held() -> void:
	var facing: Vector3 = -player.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var at: Vector3 = player.global_position + facing * 0.45
	held.detach_to_world(self, at, player.rotation.y)
	held = null
	player.play_oneshot("Put down _ drop (ground)")

func _physics_process(_delta: float) -> void:
	# A door swinging open from shut gets its one-shot,
	# as in the React build.
	for i in doors.size():
		var leaf: DoorLeaf = doors[i]
		if _door_was_shut[i] and leaf.open01 >= 0.02:
			player.play_oneshot("Open door")
		_door_was_shut[i] = leaf.open01 < 0.02
	var zone: String = HouseData.zone_at(player.global_position.x, player.global_position.z, player.global_position.y)
	if zone != _zone_now:
		_zone_now = zone
		_hud.set_zone(zone)
	_look_piece = null
	var tag: String = ""
	var prompt: String = ""
	# The nearest hit wins, with the React build's one
	# correction: a searchable's target gets a 0.12 distance
	# bias, because the counter's box front sits proud of the
	# drawer front recessed inside it. The open drawer earns
	# a stronger bias the other way: aiming into the open
	# box, the counter's look box (which spans the run,
	# over the cavity) otherwise out-draws the drawer Adam
	# is looking into — his walkthrough got "Kitchen
	# Counter" staring at the hammer. The drawer's content
	# shares the bias, so the hammer still wins its own aim.
	var best: Dictionary = {}
	var best_dist: float = INF
	for hit in player.look_hits():
		var dist: float = player.get_camera().global_position.distance_to(hit["position"])
		var collider: Object = hit["collider"]
		if collider is StaticBody3D and (collider as StaticBody3D).has_meta("piece"):
			var p: Piece = (collider as StaticBody3D).get_meta("piece")
			if p is SearchableDrawer and (p as SearchableDrawer).open01 < 0.7:
				dist -= 0.12
			if p is SearchableDrawer and (p as SearchableDrawer).open01 >= 0.7:
				dist -= 0.35
			if p is ItemPiece and (p as ItemPiece).get_parent() is SearchableDrawer and ((p as ItemPiece).get_parent() as SearchableDrawer).open01 >= 0.7:
				dist -= 0.35
		if dist < best_dist:
			best_dist = dist
			best = hit
	var hit_body: Object = best.get("collider", null)
	var hit_door: DoorLeaf = null
	if hit_body is StaticBody3D and (hit_body as StaticBody3D).has_meta("door"):
		hit_door = (hit_body as StaticBody3D).get_meta("door") as DoorLeaf
		tag = hit_door.door_name
		if hit_door.locked and hit_door.open01 < 0.5:
			tag += " — Locked"
	if hit_body is StaticBody3D and (hit_body as StaticBody3D).has_meta("piece"):
		_look_piece = (hit_body as StaticBody3D).get_meta("piece") as Piece
		tag = _look_piece.look_name()
		prompt = _look_piece.look_prompt(held)
	if prompt == "" and hit_door != null:
		prompt = hit_door.lock_prompt(player.global_position)
	if prompt == "":
		for leaf in doors:
			prompt = (leaf as DoorLeaf).lock_prompt(player.global_position)
			if prompt != "":
				break
	if prompt == "" and held != null:
		prompt = "E — Put down " + held.display_name
	_hud.set_tag(tag)
	_hud.set_prompt(prompt)
