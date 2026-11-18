class_name CharacterRig
extends Node3D

# The homeowner himself. The model ships as base64 parts
# (the push route is text-only — the same trick the React
# build used) and is assembled at load; a local raw GLB is
# the fallback. He faces +Z in his own file, so the rig
# turns him PI to face the player's forward.
#
# Animation is LAYERED, as in the React build: every clip
# is split at load into a legs version and an upper-body
# version, each with its own AnimationPlayer. The legs
# always play locomotion; the upper body plays locomotion
# too, except while a one-shot (pick up, use, open door)
# runs — then only the arms and spine act it out.

const LEG_BONES: Array = [
	"Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "LeftToe_End",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase", "RightToe_End",
]
const LOCOMOTION: Array = ["Idle", "Walk", "Run"]

var hand_anchor: BoneAttachment3D = null

var _legs: AnimationPlayer = null
var _upper: AnimationPlayer = null
var _oneshot_active: bool = false

func _ready() -> void:
	rotation.y = PI
	var scene_root: Node = _assemble()
	if scene_root == null:
		push_warning("CharacterRig: the Goodguy model could not be loaded")
		return
	add_child(scene_root)
	_build_layers(scene_root)
	_build_hand_anchor(scene_root)

func _assemble() -> Node:
	var dir: String = "res://assets/models/characters/"
	var parts: Array = []
	var access: DirAccess = DirAccess.open(dir)
	if access != null:
		for f in access.get_files():
			if f.begins_with("goodguy-part-") and f.ends_with(".b64"):
				parts.append(f)
	parts.sort()
	if not parts.is_empty():
		# Decode per part, then join the BYTES: the chunk size
		# is not a multiple of 3, so each part's base64 carries
		# its own padding and the strings cannot be joined
		# first (the React build's parts had the same shape).
		var bytes: PackedByteArray = PackedByteArray()
		for f in parts:
			bytes.append_array(Marshalls.base64_to_raw(FileAccess.get_file_as_string(dir + f)))
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_buffer(bytes, dir, state) == OK:
			return doc.generate_scene(state)
		push_warning("CharacterRig: GLB assembly from parts failed")
	var packed: PackedScene = load("res://assets/models/Goodguy.glb")
	if packed == null:
		return null
	return packed.instantiate()

func _build_layers(scene_root: Node) -> void:
	var imported: AnimationPlayer = null
	for node in scene_root.find_children("", "AnimationPlayer", true, false):
		imported = node as AnimationPlayer
	if imported == null:
		return
	var src_lib: AnimationLibrary = imported.get_animation_library("")
	_legs = AnimationPlayer.new()
	_legs.name = "LegsPlayer"
	_upper = AnimationPlayer.new()
	_upper.name = "UpperPlayer"
	scene_root.add_child(_legs)
	scene_root.add_child(_upper)
	var legs_lib := AnimationLibrary.new()
	var upper_lib := AnimationLibrary.new()
	for clip in src_lib.get_animation_list():
		var src: Animation = src_lib.get_animation(clip)
		if LOCOMOTION.has(clip):
			legs_lib.add_animation(clip, _split(src, true))
		upper_lib.add_animation(clip, _split(src, false))
	_legs.add_animation_library("", legs_lib)
	_upper.add_animation_library("", upper_lib)
	_upper.animation_finished.connect(_on_upper_finished)
	_legs.play("Idle")
	_upper.play("Idle")

# One half of a clip: the legs version keeps the leg bones
# (and any non-skeleton track — root motion belongs to
# locomotion); the upper version keeps everything else.
func _split(src: Animation, legs: bool) -> Animation:
	var out: Animation = src.duplicate() as Animation
	var i: int = out.get_track_count() - 1
	while i >= 0:
		var path: NodePath = out.track_get_path(i)
		var is_leg_track: bool = true
		if path.get_subname_count() > 0 and path.get_name(path.get_name_count() - 1) == "Skeleton3D":
			is_leg_track = LEG_BONES.has(String(path.get_subname(0)))
		if is_leg_track != legs:
			out.remove_track(i)
		i -= 1
	return out

func _build_hand_anchor(scene_root: Node) -> void:
	for node in scene_root.find_children("", "Skeleton3D", true, false):
		var skel: Skeleton3D = node as Skeleton3D
		hand_anchor = BoneAttachment3D.new()
		hand_anchor.bone_name = "WeaponR"
		skel.add_child(hand_anchor)
		return

func set_locomotion(speed: float) -> void:
	if _legs == null:
		return
	var want: String = "Idle"
	if speed >= 3.7:
		want = "Run"
	if speed >= 0.1 and speed < 3.7:
		want = "Walk"
	if _legs.current_animation != want:
		_legs.play(want, 0.25)
	if _oneshot_active:
		return
	if _upper.current_animation != want:
		_upper.play(want, 0.25)
		_upper.seek(_legs.current_animation_position, true)

func play_oneshot(clip: String) -> void:
	if _upper == null:
		return
	if not _upper.has_animation(clip):
		return
	var anim: Animation = _upper.get_animation(clip)
	if anim.get_track_count() == 0:
		return
	_oneshot_active = true
	_upper.play(clip, 0.15)

func _on_upper_finished(_clip: StringName) -> void:
	_oneshot_active = false
