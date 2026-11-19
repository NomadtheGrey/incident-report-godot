class_name Mirror
extends Node3D

# The bathroom mirror's real reflection. The React build used
# a three.js Reflector; the Godot port shipped the mirror as
# a pale blank until Adam's playtest called it (2026-11-18).
# The standard planar trick: a SubViewport camera mirrors the
# player's active camera across the glass plane each frame,
# and the viewport's texture rides a quad laid over the glass.
# The quad lives on visual layer 2 and the mirror camera's
# cull mask excludes layer 2, so the mirror never renders
# itself. The viewport renders only while its texture is on
# screen, so it costs nothing outside the bathroom.
#
# Known trade (flagged to Adam): in first person the homeowner's
# head rides along in both views (the FP camera sits
# clear of the body on Adam's ruling), so the reflection
# is the whole man, as React's was.

var _vp: SubViewport = null
var _cam: Camera3D = null
var _player: Player = null
var _plane_point: Vector3 = Vector3.ZERO
var _plane_normal: Vector3 = Vector3(0, 0, 1)

# Find the piece's mirror_glass surface and build the rig on
# it. Returns false (and builds nothing) if there is no glass.
func attach(player: Player, piece: Piece) -> bool:
	var glass: AABB = _glass_aabb(piece)
	if glass.size == Vector3.ZERO:
		return false
	_player = player
	_plane_point = Vector3(glass.get_center().x, glass.get_center().y, glass.position.z + glass.size.z)
	_vp = SubViewport.new()
	_vp.size = Vector2i(384, 512)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	_vp.world_3d = get_world_3d()
	_cam = Camera3D.new()
	_cam.cull_mask = 0xFFFFF & ~2
	_vp.add_child(_cam)
	_cam.current = true
	var quad := MeshInstance3D.new()
	quad.name = "MirrorSurface"
	var qm := QuadMesh.new()
	qm.size = Vector2(glass.size.x, glass.size.y)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _vp.get_texture()
	quad.set_surface_override_material(0, mat)
	quad.layers = 2
	quad.position = _plane_point + Vector3(0, 0, 0.002)
	add_child(quad)
	return true

func _glass_aabb(piece: Piece) -> AABB:
	var found: AABB
	var has: bool = false
	var stack: Array = [piece]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m != null and m.resource_name == "mirror_glass":
					var w: AABB = mi.global_transform * mi.get_aabb()
					if has:
						found = found.merge(w)
					else:
						found = w
						has = true
		for c in n.get_children():
			stack.append(c)
	if has:
		return found
	return AABB()

func _process(_dt: float) -> void:
	if _player == null or _cam == null:
		return
	var eye: Camera3D = _player.get_camera()
	if eye == null:
		return
	_cam.global_transform = _reflect(eye.global_transform)
	_cam.fov = eye.fov
	# The mirrored camera sits behind the wall the mirror
	# hangs on; without a near plane pushed out to the glass,
	# the wall fills the reflection. The near plane is
	# perpendicular to the view (not the glass), so at very
	# oblique angles a sliver of the room's reflection near
	# one edge can clip — the standard cheap-mirror trade,
	# invisible at a vanity.
	var dist: float = absf((eye.global_transform.origin - _plane_point).dot(_plane_normal))
	_cam.near = dist + 0.05
	_cam.far = eye.far

# Reflect a transform across the mirror plane. The reflected
# basis is left-handed; negating its x column restores a
# right-handed basis and flips the image the way a mirror does.
func _reflect(t: Transform3D) -> Transform3D:
	var n: Vector3 = _plane_normal
	var d: float = (t.origin - _plane_point).dot(n)
	var o: Vector3 = t.origin - 2.0 * d * n
	var b: Basis = t.basis
	var rx: Vector3 = b.x - 2.0 * b.x.dot(n) * n
	var ry: Vector3 = b.y - 2.0 * b.y.dot(n) * n
	var rz: Vector3 = b.z - 2.0 * b.z.dot(n) * n
	return Transform3D(Basis(-rx, ry, rz), o)
