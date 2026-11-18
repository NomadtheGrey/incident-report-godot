class_name HouseData
extends RefCounted

# The house's facts as data, ported from the React build
# (zoneAt() in ModelWalk.tsx). One canonical home for the
# numbers every system reads: zones here, the door spec here,
# the stair ramps in house.gd where the collision is built.

# Rects are [x0, x1, z0, z1, name]; the smallest containing
# rect wins, exactly as in the React build.
const ZONES_UPSTAIRS: Array = [
	[-6.0, -1.0, -4.5, -0.5, "Bedroom 1"],
	[-6.0, -1.0, -0.5, 4.5, "Bedroom 2"],
	[-1.0, 1.0, -1.7, 0.7, "Hall"],
	[1.0, 2.0, -0.5, 0.5, "Hall Closet"],
	[1.0, 6.0, -1.7, 0.8, "Stairs"],
	[-1.0, 6.0, -4.5, -1.7, "Bathroom"],
	[-1.0, 6.0, 0.7, 4.5, "Master Bedroom"],
]

const ZONES_MAIN: Array = [
	[-6.0, -1.0, -4.5, 0.5, "Dining Room"],
	[-6.0, -1.0, 0.5, 4.5, "Living Room"],
	[-1.0, 1.0, -4.5, 4.5, "Hall / Entry"],
	[1.0, 6.0, -1.7, 0.8, "Stairs"],
	[1.0, 6.0, -4.5, 0.5, "Kitchen"],
	[1.0, 6.0, 0.5, 4.5, "East Room"],
]

const ZONES_BASEMENT: Array = [
	[-6.0, -1.1, 0.5, 4.5, "Basement Room"],
]

# The floor band decides the table, as in the React build:
# ground below -1.2 is the basement, below 1.3 the main floor,
# anything higher is upstairs.
static func zone_at(x: float, z: float, ground_y: float) -> String:
	var table: Array = ZONES_MAIN
	var fallback: String = "Main Floor"
	if ground_y < -1.2:
		table = ZONES_BASEMENT
		fallback = "Basement"
	if ground_y >= 1.3:
		table = ZONES_UPSTAIRS
		fallback = "Upstairs"
	var best: String = fallback
	var best_area: float = INF
	for rect in table:
		var r: Array = rect
		var x0: float = r[0]
		var x1: float = r[1]
		var z0: float = r[2]
		var z1: float = r[3]
		if x < x0 or x > x1 or z < z0 or z > z1:
			continue
		var area: float = (x1 - x0) * (z1 - z0)
		if area < best_area:
			best_area = area
			best = r[4]
	return best

# The one door in the house so far (Adam's pin, 2026-11-12):
# the top of the basement flight, closing only the south lane.
# The pivot is the hinge, at the shaft-wall jamb (z -1.6).
const DOOR_SPEC: Dictionary = {
	"id": "basement-stairs",
	"name": "Basement Door",
	"pivot": Vector3(2.0, 0.1, -1.60),
	"centre": Vector3(2.0, 0.1, -1.05),
	"width": 1.1,
	"floor_y": 0.1,
	"inside_sign": -1.0,
	"open_angle": -1.75,
}

# --- Slice 2: the kitchen -----------------------------------
# Piece specs ported from the React FURNITURE table (same
# numbers, same meaning): lc is the model's local centre in
# file units, (cx, cz) the game-space home, y the floor the
# piece stands on, w/d/h the footprint for the auto box.
# kind: static | item | fan | hood | plate | drawer.
# group names the light circuit a fixture belongs to.
const PIECES: Array = [
	{"file": "kitchen-run-south", "name": "Kitchen Counter", "kind": "static",
		"lc": Vector2(0.13125, 0.0203), "w": 4.24, "d": 0.65, "h": 0.905,
		"cx": 3.25, "cz": -4.075, "yaw": 0.0, "y": 0.1, "box": true,
		"boxes": [[1.11, 3.0, -4.42, -3.73], [4.76, 5.39, -4.42, -3.73]]},
	{"file": "kitchen-run-east", "name": "Kitchen Counter", "kind": "static",
		"lc": Vector2(0.09005, 0.0194), "w": 2.92, "d": 0.62, "h": 1.16,
		"cx": 5.59, "cz": -3.06, "yaw": -PI / 2.0, "y": 0.1, "box": true},
	{"file": "kitchen-wall-east", "name": "Kitchen Cabinets", "kind": "static",
		"lc": Vector2(0.1547, 0.01195), "w": 0.85, "d": 0.38, "h": 0.0,
		"cx": 5.71, "cz": -2.03, "yaw": -PI / 2.0, "y": 0.1, "box": false},
	{"file": "kitchen-wall-south", "name": "Kitchen Cabinets", "kind": "static",
		"lc": Vector2(0.10315, 0.01195), "w": 3.32, "d": 0.38, "h": 0.0,
		"cx": 2.79, "cz": -4.21, "yaw": 0.0, "y": 0.1, "box": false},
	{"file": "fridge", "name": "Fridge", "kind": "static",
		"lc": Vector2(0.0, 0.02765), "w": 0.91, "d": 0.885, "h": 1.8,
		"cx": 0.6, "cz": -3.96, "yaw": 0.0, "y": 0.1, "box": true},
	{"file": "range", "name": "Range", "kind": "static",
		"lc": Vector2(0.0, 0.0206), "w": 0.76, "d": 0.66, "h": 0.92,
		"cx": 4.37, "cz": -4.07, "yaw": 0.0, "y": 0.1, "box": true},
	{"file": "ceiling-fan", "name": "Ceiling Fan", "kind": "fan", "group": "kitchen",
		"lc": Vector2(0.00275, 0.0), "w": 1.3, "d": 1.3, "h": 0.0,
		"cx": 3.5, "cz": -2.0, "yaw": 0.0, "y": 2.5, "box": false},
	{"file": "range-hood", "name": "Range Hood", "kind": "hood", "group": "kitchen",
		"lc": Vector2(0.0, 0.0), "w": 0.82, "d": 0.5, "h": 0.0,
		"cx": 4.37, "cz": -4.42, "yaw": 0.0, "y": 0.1, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "kitchen",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 3.0, "cz": -1.76, "yaw": PI, "y": 1.3, "box": false},
	{"file": "skillet", "name": "Cast Iron Skillet", "kind": "item",
		"lc": Vector2(0.0, 0.00525), "w": 0.35, "d": 0.51, "h": 0.06,
		"cx": 2.6, "cz": -4.09, "yaw": 0.5, "y": 1.01, "box": false},
	{"file": "pot", "name": "Pot", "kind": "item",
		"lc": Vector2(0.0, 0.0), "w": 0.35, "d": 0.32, "h": 0.27,
		"cx": 4.37, "cz": -4.07, "yaw": 0.0, "y": 0.92, "box": false},
	{"file": "fire-extinguisher", "name": "Fire Extinguisher", "kind": "item",
		"lc": Vector2(0.0, 0.0), "w": 0.18, "d": 0.16, "h": 0.51,
		"cx": 5.02, "cz": -4.08, "yaw": 0.0, "y": 1.01, "box": false},
	{"file": "junk-drawer", "name": "Junk Drawer", "kind": "drawer",
		"lc": Vector2(0.13125, 0.0203), "w": 0.54, "d": 0.53, "h": 0.21,
		"cx": 3.25, "cz": -4.075, "yaw": 0.0, "y": 0.1, "box": false},
]

# The claw hammer lives in the junk drawer (React spec:
# world (1.43, 0.80, -3.80)); main.gd parents it to the
# drawer root, so its home here is drawer-local.
const HAMMER_SPEC: Dictionary = {
	"file": "claw-hammer", "name": "Claw Hammer", "kind": "item",
	"lc": Vector2(0.0, 0.01015), "w": 0.05, "d": 0.33, "h": 0.07,
	"local_pos": Vector3(-1.82, 0.70, 0.275), "yaw": 0.0, "box": false,
}

# Look-target y spans (relative to the piece root), ported
# from LOOK_Y. Pieces not listed use their spec height, or
# their geometry's own bounds when the height is 0.
const LOOK_Y: Dictionary = {
	"ceiling-fan": Vector2(-0.66, 0.02),
	"switch-plate": Vector2(-0.09, 0.09),
	"range-hood": Vector2(1.5, 1.83),
}

# First-person grip poses, ported from GRIP_FP (position,
# rotation) — tuned by eye in the React build.
const GRIPS: Dictionary = {
	"skillet": [Vector3(0.27, -0.25, -0.5), Vector3(0.25, 0.1, 0.1)],
	"pot": [Vector3(0.3, -0.3, -0.55), Vector3(0.1, 0.0, 0.0)],
	"claw-hammer": [Vector3(0.26, -0.24, -0.45), Vector3(0.5, 0.0, -0.35)],
	"fire-extinguisher": [Vector3(0.3, -0.32, -0.5), Vector3(0.0, 0.0, 0.0)],
}

# Third-person grip rotations, ported from GRIP_TP — in TP
# the held item snaps to the WeaponR bone (position is the
# bone's own origin; only the rotation carries over).
const GRIPS_TP: Dictionary = {
	"skillet": Vector3(1.35, 0.0, 0.55),
	"pot": Vector3(0.3, 0.0, 0.0),
	"claw-hammer": Vector3(1.1, 0.0, 0.2),
	"fire-extinguisher": Vector3(0.2, 0.0, 0.0),
}
