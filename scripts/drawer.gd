class_name SearchableDrawer
extends Piece

# The junk drawer, the first SEARCHABLE (React, 2026-11-14):
# built in the south run's own local frame, so this root
# carries the run's transform and the drawer slides true.
# It ships 0.035 ajar; the game starts it SHUT. What sits
# inside only becomes takeable once the drawer is open —
# the content's look target stays sealed below open01 0.7,
# and past 0.7 this drawer's own target shrinks to the pull
# band so the prize can win the centre ray.

const CLOSED_OFFSET: float = -0.035
const SLIDE: float = 0.34
const SLIDE_SECONDS: float = 0.45

var open01: float = 0.0
var content: ItemPiece = null

var _target: float = 0.0
var _base: Vector3 = Vector3.ZERO
var _front_shape: CollisionShape3D = null
var _band_shape: CollisionShape3D = null

func _ready() -> void:
	super._ready()
	_base = position
	position = _base + _slide_dir() * CLOSED_OFFSET

func _slide_dir() -> Vector3:
	return Vector3(sin(rotation.y), 0, cos(rotation.y))

# The React drawer's replacement target: the front panel's
# box, and (when open) only its top pull band.
func _add_look_shapes(body: StaticBody3D) -> void:
	_front_shape = _add_look_box(body, Vector3(-1.80, 0.735, 0.27), Vector3(0.58, 0.21, 0.08))
	_band_shape = _add_look_box(body, Vector3(-1.80, 0.80, 0.27), Vector3(0.58, 0.08, 0.08))
	_band_shape.disabled = true

func _physics_process(delta: float) -> void:
	if open01 < _target:
		open01 = minf(_target, open01 + delta / SLIDE_SECONDS)
	if open01 > _target:
		open01 = maxf(_target, open01 - delta / SLIDE_SECONDS)
	position = _base + _slide_dir() * (CLOSED_OFFSET + open01 * SLIDE)
	var open_now: bool = open01 > 0.7
	if _front_shape != null:
		_front_shape.disabled = open_now
		_band_shape.disabled = not open_now
	if content != null and content.get_parent() == self:
		content.set_sealed(open01 < 0.7)

func is_open() -> bool:
	return _target > 0.5

func interact() -> void:
	_target = 0.0 if is_open() else 1.0

func look_prompt(_held: Piece) -> String:
	if is_open():
		return "E — Close the drawer"
	return "E — Open the junk drawer"
