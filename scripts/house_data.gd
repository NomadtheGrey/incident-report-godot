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
# The six leaves, ported from MODEL_DOORS (centres and
# widths re-measured on Adam's de-dupe export). wall_axis is
# the wall's PLANE: 'x' = the wall sits at constant x and the
# leaf spans z; 'z' the reverse. swing defaults to
# inside_sign; the basement-stairs leaf overrides it — it
# locks from the room side but swings INTO the room, because
# a real basement door never swings out over the flight.
const DOORS: Array = [
	{"id": "bedroom-1", "name": "Bedroom 1 door", "cx": -1.07, "cz": -1.0,
		"floor_y": 2.6, "width": 0.9, "wall_axis": "x", "inside_sign": -1.0},
	{"id": "bedroom-2", "name": "Bedroom 2 door", "cx": -1.07, "cz": 0.13,
		"floor_y": 2.6, "width": 0.95, "wall_axis": "x", "inside_sign": -1.0},
	{"id": "bathroom", "name": "Bathroom door", "cx": 0.5, "cz": -1.65,
		"floor_y": 2.6, "width": 0.9, "wall_axis": "z", "inside_sign": -1.0},
	{"id": "master", "name": "Master Bedroom door", "cx": 0.48, "cz": 0.75,
		"floor_y": 2.6, "width": 0.85, "wall_axis": "z", "inside_sign": 1.0},
	{"id": "basement-stairs", "name": "Basement Stairs door", "cx": 2.0, "cz": -1.05,
		"floor_y": 0.1, "width": 1.1, "wall_axis": "x", "inside_sign": -1.0, "swing": 1.0},
	{"id": "basement-room", "name": "Basement Room door", "cx": -1.1, "cz": 3.0,
		"floor_y": -2.4, "width": 1.0, "wall_axis": "x", "inside_sign": -1.0},
]

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
	# --- Slice 4: the rest of the wired house -------------
	# Fans, lamps and plates for every room (React placements
	# verbatim), and the four window units in their openings.
	{"file": "ceiling-fan", "name": "Ceiling Fan", "kind": "fan", "group": "living",
		"lc": Vector2(0.00275, 0.0), "w": 1.3, "d": 1.3, "h": 0.0,
		"cx": -3.0, "cz": 2.5, "yaw": 0.0, "y": 2.5, "box": false},
	{"file": "ceiling-fan", "name": "Ceiling Fan", "kind": "fan", "group": "dining",
		"lc": Vector2(0.00275, 0.0), "w": 1.3, "d": 1.3, "h": 0.0,
		"cx": -3.0, "cz": -2.0, "yaw": 0.0, "y": 2.5, "box": false},
	{"file": "ceiling-fan", "name": "Ceiling Fan", "kind": "fan", "group": "master",
		"lc": Vector2(0.00275, 0.0), "w": 1.3, "d": 1.3, "h": 0.0,
		"cx": 2.5, "cz": 2.5, "yaw": 0.0, "y": 5.0, "box": false},
	{"file": "ceiling-fan", "name": "Ceiling Fan", "kind": "fan", "group": "bed1",
		"lc": Vector2(0.00275, 0.0), "w": 1.3, "d": 1.3, "h": 0.0,
		"cx": -3.5, "cz": -2.5, "yaw": 0.0, "y": 5.0, "box": false},
	{"file": "ceiling-fan", "name": "Ceiling Fan", "kind": "fan", "group": "bed2",
		"lc": Vector2(0.00275, 0.0), "w": 1.3, "d": 1.3, "h": 0.0,
		"cx": -3.5, "cz": 2.5, "yaw": 0.0, "y": 5.0, "box": false},
	{"file": "table-lamp", "name": "Lamp", "kind": "lamp", "group": "master",
		"lc": Vector2(0.0, 0.0), "w": 0.21, "d": 0.21, "h": 0.45,
		"cx": 3.28, "cz": 4.16, "yaw": 0.0, "y": 3.21, "box": false},
	{"file": "table-lamp", "name": "Lamp", "kind": "lamp", "group": "bed1",
		"lc": Vector2(0.0, 0.0), "w": 0.21, "d": 0.21, "h": 0.45,
		"cx": -2.8, "cz": -4.16, "yaw": 0.0, "y": 3.21, "box": false},
	{"file": "table-lamp", "name": "Lamp", "kind": "lamp", "group": "bed2",
		"lc": Vector2(0.0, 0.0), "w": 0.21, "d": 0.21, "h": 0.45,
		"cx": -5.66, "cz": 2.85, "yaw": 0.0, "y": 3.21, "box": false},
	{"file": "floor-lamp", "name": "Floor Lamp", "kind": "lamp", "group": "living",
		"lc": Vector2(0.0, 0.0), "w": 0.36, "d": 0.36, "h": 1.62,
		"cx": -5.55, "cz": 4.05, "yaw": 0.0, "y": 0.1, "box": true},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "bath",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 1.05, "cz": -1.71, "yaw": PI, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "master",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 1.05, "cz": 0.81, "yaw": 0.0, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "master",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 3.12, "cz": 0.81, "yaw": 0.0, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "bed2",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": -1.18, "cz": -0.45, "yaw": -PI / 2.0, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "bed2",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": -1.18, "cz": 0.7, "yaw": -PI / 2.0, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "bed1",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": -1.18, "cz": -1.55, "yaw": -PI / 2.0, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "living",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": -2.85, "cz": 0.61, "yaw": 0.0, "y": 1.3, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "dining",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": -2.85, "cz": 0.49, "yaw": PI, "y": 1.3, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "hall",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 0.16, "cz": -0.55, "yaw": PI / 2.0, "y": 1.3, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "hall",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 0.2, "cz": -1.59, "yaw": 0.0, "y": 3.8, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "basement",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": -1.21, "cz": 3.55, "yaw": -PI / 2.0, "y": -1.2, "box": false},
	{"file": "switch-plate", "name": "Light Switch", "kind": "plate", "group": "basement",
		"lc": Vector2(0.0, 0.00075), "w": 0.075, "d": 0.02, "h": 0.0,
		"cx": 2.35, "cz": -1.76, "yaw": PI, "y": 1.3, "box": false},
	{"file": "window", "name": "Window", "kind": "static",
		"lc": Vector2(0.0, 0.00375), "w": 2.06, "d": 0.12, "h": 1.03,
		"cx": -5.84, "cz": -2.0, "yaw": PI / 2.0, "y": 1.1, "box": true},
	{"file": "window", "name": "Window", "kind": "static",
		"lc": Vector2(0.0, 0.00375), "w": 2.06, "d": 0.12, "h": 1.03,
		"cx": -5.84, "cz": 2.5, "yaw": PI / 2.0, "y": 1.1, "box": true},
	{"file": "window", "name": "Window", "kind": "static",
		"lc": Vector2(0.0, 0.00375), "w": 2.06, "d": 0.12, "h": 1.03,
		"cx": -1.5, "cz": 4.34, "yaw": PI, "y": 1.1, "box": true},
	{"file": "window", "name": "Window", "kind": "static",
		"lc": Vector2(0.0, 0.00375), "w": 2.06, "d": 0.12, "h": 1.03,
		"cx": 5.84, "cz": 2.5, "yaw": -PI / 2.0, "y": 1.1, "box": true},
	# --- Slice 5: the lived-in house (transcribed from the
	# React FURNITURE table by script, not by hand) ---------
	{"file": "vanity", "name": "Vanity", "kind": "static", "lc": Vector2(0.028, 0.017), "w": 0.93, "d": 0.57, "h": 1.06, "cx": 0.62, "cz": -4.115, "yaw": 0, "y": 2.6, "box": true},
	{"file": "mirror", "name": "Mirror", "kind": "static", "lc": Vector2(0.0255, 0.001), "w": 0.82, "d": 0.03, "h": 0, "cx": 0.62, "cz": -4.385, "yaw": 0, "y": 2.6, "box": false},
	{"file": "toilet", "name": "Toilet", "kind": "static", "lc": Vector2(0.0155, 0.021), "w": 0.53, "d": 0.7, "h": 0.83, "cx": 1.62, "cz": -4.05, "yaw": 0, "y": 2.6, "box": true},
	{"file": "bathtub", "name": "Bathtub", "kind": "static", "lc": Vector2(0.053, 0.0235), "w": 1.7, "d": 0.75, "h": 0.75, "cx": 5, "cz": -4.025, "yaw": 3.14159, "y": 2.6, "box": true},
	{"file": "bed-king", "name": "Bed", "kind": "static", "lc": Vector2(0.062, 0.068), "w": 1.98, "d": 2.18, "h": 1.1, "cx": 2, "cz": 3.31, "yaw": 3.14159, "y": 2.6, "box": true},
	{"file": "nightstand", "name": "Nightstand", "kind": "static", "lc": Vector2(0.0175, 0.014), "w": 0.59, "d": 0.48, "h": 0.61, "cx": 0.72, "cz": 4.16, "yaw": 3.14159, "y": 2.6, "box": true},
	{"file": "nightstand", "name": "Nightstand", "kind": "static", "lc": Vector2(0.0175, 0.014), "w": 0.59, "d": 0.48, "h": 0.61, "cx": 3.28, "cz": 4.16, "yaw": 3.14159, "y": 2.6, "box": true},
	{"file": "dresser", "name": "Dresser", "kind": "static", "lc": Vector2(0.0465, 0.0155), "w": 1.52, "d": 0.52, "h": 0.9, "cx": 5.64, "cz": 2.2, "yaw": -1.5708, "y": 2.6, "box": true},
	{"file": "bed-full", "name": "Bed", "kind": "static", "lc": Vector2(0.0445, 0.0645), "w": 1.42, "d": 2.06, "h": 0.99, "cx": -3.89, "cz": -3.37, "yaw": 0, "y": 2.6, "box": true},
	{"file": "nightstand", "name": "Nightstand", "kind": "static", "lc": Vector2(0.0175, 0.014), "w": 0.59, "d": 0.48, "h": 0.61, "cx": -2.8, "cz": -4.16, "yaw": 0, "y": 2.6, "box": true},
	{"file": "dresser", "name": "Dresser", "kind": "static", "lc": Vector2(0.0465, 0.0155), "w": 1.52, "d": 0.52, "h": 0.9, "cx": -3.6, "cz": -0.76, "yaw": 3.14159, "y": 2.6, "box": true},
	{"file": "bed-full", "name": "Bed", "kind": "static", "lc": Vector2(0.0445, 0.0645), "w": 1.42, "d": 2.06, "h": 0.99, "cx": -4.87, "cz": 1.7, "yaw": 1.5708, "y": 2.6, "box": true},
	{"file": "nightstand", "name": "Nightstand", "kind": "static", "lc": Vector2(0.0175, 0.014), "w": 0.59, "d": 0.48, "h": 0.61, "cx": -5.66, "cz": 2.85, "yaw": 1.5708, "y": 2.6, "box": true},
	{"file": "dresser", "name": "Dresser", "kind": "static", "lc": Vector2(0.0465, 0.0155), "w": 1.52, "d": 0.52, "h": 0.9, "cx": -3.9, "cz": -0.14, "yaw": 0, "y": 2.6, "box": true},
	{"file": "dining-table", "name": "Dining Table", "kind": "static", "lc": Vector2(0, 0), "w": 3, "d": 1.5, "h": 0.76, "cx": -3.6, "cz": -2.25, "yaw": 0, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -2.45, "cz": -3.15, "yaw": 0, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -3.45, "cz": -3.15, "yaw": 0, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -4.45, "cz": -3.15, "yaw": 0, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -2.45, "cz": -1.35, "yaw": 3.14159, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -3.45, "cz": -1.35, "yaw": 3.14159, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -4.45, "cz": -1.35, "yaw": 3.14159, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -5.25, "cz": -2.25, "yaw": 1.5708, "y": 0.1, "box": true},
	{"file": "dining-chair", "name": "Dining Chair", "kind": "static", "lc": Vector2(0, 0.01405), "w": 0.45, "d": 0.45, "h": 0.95, "cx": -1.95, "cz": -2.25, "yaw": -1.5708, "y": 0.1, "box": true},
	{"file": "couch-3seat", "name": "Couch", "kind": "static", "lc": Vector2(0, 0.0297), "w": 2.3, "d": 0.95, "h": 0.92, "cx": -5.425, "cz": 2.55, "yaw": 1.5708, "y": 0.1, "box": true},
	{"file": "couch-2seat", "name": "Couch", "kind": "static", "lc": Vector2(0, 0.0297), "w": 1.7, "d": 0.95, "h": 0.92, "cx": -1.45, "cz": 3.925, "yaw": 3.14159, "y": 0.1, "box": true},
	{"file": "entertainment-center", "name": "Entertainment Center", "kind": "static", "lc": Vector2(0, 0.01515), "w": 1.94, "d": 0.49, "h": 0.55, "cx": -1.45, "cz": 0.85, "yaw": 0, "y": 0.1, "box": true},
	{"file": "tv", "name": "TV", "kind": "static", "lc": Vector2(0, 0.01515), "w": 1.4, "d": 0.26, "h": 0.91, "cx": -1.45, "cz": 0.85, "yaw": 0, "y": 0.65, "box": false},
	{"file": "curio-cabinet", "name": "Curio Cabinet", "kind": "static", "lc": Vector2(0, 0.0119), "w": 0.9, "d": 0.4, "h": 1.96, "cx": -0.2, "cz": -2.95, "yaw": -1.5708, "y": 0.1, "box": true},
	{"file": "claw-hammer", "name": "Claw Hammer", "kind": "static", "lc": Vector2(0, 0.01015), "w": 0.05, "d": 0.33, "h": 0.07, "cx": 1.43, "cz": -3.8, "yaw": 0, "y": 0.8, "box": false},
	{"file": "duct-tape", "name": "Duct Tape", "kind": "static", "lc": Vector2(0, 0.003), "w": 0.15, "d": 0.24, "h": 0.05, "cx": 1.9, "cz": -4.09, "yaw": 0.4, "y": 1.01, "box": false},
	{"file": "extension-cord", "name": "Extension Cord", "kind": "static", "lc": Vector2(0, 0), "w": 0.35, "d": 0.31, "h": 0.06, "cx": -5.05, "cz": 4.05, "yaw": 0, "y": 0.1, "box": false},
	{"file": "ashtray", "name": "Ashtray", "kind": "static", "lc": Vector2(0, 0), "w": 0.13, "d": 0.13, "h": 0.05, "cx": -4.7, "cz": -2.6, "yaw": 0, "y": 0.86, "box": false},
	{"file": "phone", "name": "Phone", "kind": "static", "lc": Vector2(0, 0), "w": 0.08, "d": 0.21, "h": 0.06, "cx": 0.72, "cz": 4.16, "yaw": 0, "y": 3.21, "box": false},
	{"file": "clothes-iron", "name": "Clothes Iron", "kind": "static", "lc": Vector2(0, 0.0017), "w": 0.12, "d": 0.36, "h": 0.15, "cx": 5.64, "cz": 2.2, "yaw": -1.5708, "y": 3.5, "box": false},
	{"file": "baseball-bat", "name": "Baseball Bat", "kind": "static", "lc": Vector2(0, 0.02535), "w": 0.36, "d": 0.91, "h": 0.07, "cx": 3.18, "cz": 3.2, "yaw": 0, "y": 2.6, "box": false},
	{"file": "plunger", "name": "Plunger", "kind": "static", "lc": Vector2(0, 0), "w": 0.16, "d": 0.16, "h": 0.58, "cx": 2.05, "cz": -4.15, "yaw": 0, "y": 2.6, "box": false},
	{"file": "shovel", "name": "Shovel", "kind": "static", "lc": Vector2(0, 0.0325), "w": 0.22, "d": 1.3, "h": 0.07, "cx": 5.48, "cz": -1, "yaw": 1.5708, "y": -1.1, "box": false, "lean": -1.31},
	{"file": "smoke-detector", "name": "Smoke Detector", "kind": "static", "lc": Vector2(0, 0), "w": 0.18, "d": 0.18, "h": 0, "cx": 0.5, "cz": -1.25, "yaw": 0, "y": 5, "box": false},
	{"file": "smoke-detector", "name": "Smoke Detector", "kind": "static", "lc": Vector2(0, 0), "w": 0.18, "d": 0.18, "h": 0, "cx": 0.5, "cz": -0.5, "yaw": 0, "y": 2.5, "box": false},
	{"file": "smoke-detector", "name": "Smoke Detector", "kind": "static", "lc": Vector2(0, 0), "w": 0.18, "d": 0.18, "h": 0, "cx": 3.5, "cz": -4.05, "yaw": 0, "y": 2.5, "box": false},
	{"file": "smoke-detector", "name": "Smoke Detector", "kind": "static", "lc": Vector2(0, 0), "w": 0.18, "d": 0.18, "h": 0, "cx": 0.5, "cz": -2, "yaw": 0, "y": 0, "box": false},
	{"file": "curtains", "name": "Curtains", "kind": "static", "lc": Vector2(0, 0), "w": 2.36, "d": 0.11, "h": 0, "cx": -5.84, "cz": -2, "yaw": 1.5708, "y": 0.1, "box": false},
	{"file": "curtains", "name": "Curtains", "kind": "static", "lc": Vector2(0, 0), "w": 2.36, "d": 0.11, "h": 0, "cx": -5.84, "cz": 2.5, "yaw": 1.5708, "y": 0.1, "box": false},
	{"file": "curtains", "name": "Curtains", "kind": "static", "lc": Vector2(0, 0), "w": 2.36, "d": 0.11, "h": 0, "cx": -1.5, "cz": 4.34, "yaw": 3.14159, "y": 0.1, "box": false},
	{"file": "curtains", "name": "Curtains", "kind": "static", "lc": Vector2(0, 0), "w": 2.36, "d": 0.11, "h": 0, "cx": 5.84, "cz": 2.5, "yaw": -1.5708, "y": 0.1, "box": false},
	{"file": "coffee-table", "name": "Coffee Table", "kind": "static", "lc": Vector2(0, 0.0172), "w": 1.1, "d": 0.55, "h": 0.42, "cx": -4.3, "cz": 2.55, "yaw": 1.5708, "y": 0.1, "box": true},
	{"file": "book-stack", "name": "Books", "kind": "static", "lc": Vector2(0, 0), "w": 0.26, "d": 0.2, "h": 0.14, "cx": -4.3, "cz": 2.25, "yaw": 0.4, "y": 0.52, "box": false},
	{"file": "tv-remote", "name": "TV Remote", "kind": "static", "lc": Vector2(0, 0), "w": 0.06, "d": 0.17, "h": 0.02, "cx": -4.22, "cz": 2.85, "yaw": -0.3, "y": 0.52, "box": false},
	# DIVERGES from the React table on purpose (Adam's playtest,
	# 2026-11-18): at (0.85, 1.1) and (1.95, 1.1) the pair plugged
	# the hall/archway mouth and he got completely stuck. They now
	# sit along the East Room's south wall, east of the archway.
	# A re-transcription must keep these two where they are.
	{"file": "armchair", "name": "Armchair", "kind": "static", "lc": Vector2(0, 0.0275), "w": 0.95, "d": 0.88, "h": 0.95, "cx": 2.9, "cz": 1.05, "yaw": 0, "y": 0.1, "box": true},
	{"file": "armchair", "name": "Armchair", "kind": "static", "lc": Vector2(0, 0.0275), "w": 0.95, "d": 0.88, "h": 0.95, "cx": 4.0, "cz": 1.05, "yaw": 0, "y": 0.1, "box": true},
	{"file": "table-plant", "name": "Potted Plant", "kind": "static", "lc": Vector2(0, 0), "w": 0.46, "d": 0.48, "h": 0.61, "cx": -3.6, "cz": -2.25, "yaw": 0, "y": 0.86, "box": false},
	{"file": "fruit-bowl", "name": "Fruit Bowl", "kind": "static", "lc": Vector2(0, 0), "w": 0.25, "d": 0.25, "h": 0.14, "cx": -4.4, "cz": -1.8, "yaw": 0, "y": 0.86, "box": false},
	{"file": "hanging-plant", "name": "Hanging Plant", "kind": "static", "lc": Vector2(0, 0), "w": 0.27, "d": 0.24, "h": 0, "cx": -5.7, "cz": -2, "yaw": 0, "y": 2.32, "box": false},
	{"file": "hanging-plant", "name": "Hanging Plant", "kind": "static", "lc": Vector2(0, 0), "w": 0.27, "d": 0.24, "h": 0, "cx": -1.5, "cz": 4.2, "yaw": 0, "y": 2.32, "box": false},
	{"file": "hanging-plant", "name": "Hanging Plant", "kind": "static", "lc": Vector2(0, 0), "w": 0.27, "d": 0.24, "h": 0, "cx": 5.7, "cz": 2.5, "yaw": 0, "y": 2.32, "box": false},
	{"file": "mail-pile", "name": "Mail", "kind": "static", "lc": Vector2(0, 0), "w": 0.25, "d": 0.15, "h": 0.02, "cx": 2.3, "cz": -4.05, "yaw": 0.2, "y": 1, "box": false},
	{"file": "mugs", "name": "Mugs", "kind": "static", "lc": Vector2(0, 0), "w": 0.25, "d": 0.08, "h": 0.09, "cx": 5.5, "cz": -2.55, "yaw": 0.3, "y": 1.01, "box": false},
	{"file": "coat-hooks", "name": "Coats", "kind": "static", "lc": Vector2(0, 0), "w": 1.07, "d": 0.11, "h": 0, "cx": 0.14, "cz": -1.2, "yaw": 1.5708, "y": 0.1, "box": false},
	{"file": "shoes", "name": "Shoes", "kind": "static", "lc": Vector2(0, 0), "w": 0.25, "d": 0.32, "h": 0.12, "cx": 0.42, "cz": -1.2, "yaw": 1.9708, "y": 0.1, "box": false},
	{"file": "dog-bowls", "name": "Dog Bowls", "kind": "static", "lc": Vector2(0, 0), "w": 0.56, "d": 0.34, "h": 0.06, "cx": 3.5, "cz": -3.5, "yaw": 0, "y": 0.1, "box": false},
	{"file": "trash-can", "name": "Trash Can", "kind": "static", "lc": Vector2(0, 0), "w": 0.26, "d": 0.26, "h": 0.31, "cx": 1.35, "cz": -3.45, "yaw": 0, "y": 0.1, "box": false},
	{"file": "toiletries", "name": "Toiletries", "kind": "static", "lc": Vector2(0, 0), "w": 0.19, "d": 0.1, "h": 0.22, "cx": 0.33, "cz": -4.28, "yaw": 0, "y": 3.5, "box": false},
	{"file": "trash-can", "name": "Trash Can", "kind": "static", "lc": Vector2(0, 0), "w": 0.26, "d": 0.26, "h": 0.31, "cx": 1.38, "cz": -4.1, "yaw": 0, "y": 2.6, "box": false},
	{"file": "clothes-pile-a", "name": "Clothes Pile", "kind": "static", "lc": Vector2(0, 0), "w": 0.55, "d": 0.44, "h": 0.11, "cx": 2.3, "cz": -3.55, "yaw": 0.7, "y": 2.6, "box": false},
	{"file": "clothes-pile-b", "name": "Clothes Pile", "kind": "static", "lc": Vector2(0, 0), "w": 0.55, "d": 0.44, "h": 0.11, "cx": 4.35, "cz": 2.85, "yaw": 0.2, "y": 2.6, "box": false},
	{"file": "clothes-pile-c", "name": "Clothes Pile", "kind": "static", "lc": Vector2(0, 0), "w": 0.55, "d": 0.44, "h": 0.11, "cx": -2.05, "cz": -3.3, "yaw": 1.1, "y": 2.6, "box": false},
	{"file": "clothes-pile-a", "name": "Clothes Pile", "kind": "static", "lc": Vector2(0, 0), "w": 0.55, "d": 0.44, "h": 0.11, "cx": -3.25, "cz": 2.95, "yaw": 0.5, "y": 2.6, "box": false},
	{"file": "poster-bedroom-1", "name": "Poster", "kind": "static", "lc": Vector2(0, 0), "w": 0.66, "d": 0.01, "h": 0, "cx": -3.89, "cz": -4.38, "yaw": 0, "y": 4.35, "box": false},
	{"file": "poster-bedroom-2", "name": "Poster", "kind": "static", "lc": Vector2(0, 0), "w": 0.66, "d": 0.01, "h": 0, "cx": -5.88, "cz": 1.7, "yaw": 1.5708, "y": 4.35, "box": false},
	{"file": "book-stack", "name": "Books", "kind": "static", "lc": Vector2(0, 0), "w": 0.26, "d": 0.2, "h": 0.14, "cx": 5.64, "cz": 2.05, "yaw": -0.5, "y": 3.5, "box": false},
	{"file": "picture-frame-1", "name": "Picture Frame", "kind": "static", "lc": Vector2(0, 0), "w": 0.34, "d": 0.02, "h": 0, "cx": -1.95, "cz": 4.38, "yaw": 3.14159, "y": 1.95, "box": false},
	{"file": "picture-frame-2", "name": "Picture Frame", "kind": "static", "lc": Vector2(0, 0), "w": 0.26, "d": 0.02, "h": 0, "cx": -1.38, "cz": 4.38, "yaw": 3.14159, "y": 1.88, "box": false},
	{"file": "picture-frame-3", "name": "Picture Frame", "kind": "static", "lc": Vector2(0, 0), "w": 0.19, "d": 0.02, "h": 0, "cx": -0.95, "cz": 4.38, "yaw": 3.14159, "y": 1.98, "box": false},
	{"file": "picture-frame-2", "name": "Picture Frame", "kind": "static", "lc": Vector2(0, 0), "w": 0.26, "d": 0.02, "h": 0, "cx": 5.88, "cz": 2.2, "yaw": -1.5708, "y": 4.3, "box": false},
	{"file": "curio-contents", "name": "The Good China", "kind": "static", "lc": Vector2(0, 0.0119), "w": 0.62, "d": 0.16, "h": 0, "cx": -0.2, "cz": -2.95, "yaw": -1.5708, "y": 0.1, "box": false},
	{"file": "laundry-basket", "name": "Laundry Basket", "kind": "static", "lc": Vector2(0.0172, 0.0125), "w": 0.57, "d": 0.41, "h": 0.55, "cx": 1.45, "cz": 3.35, "yaw": 0.15, "y": -2.4, "box": true},
	{"file": "furnace", "name": "Furnace", "kind": "static", "lc": Vector2(0, 0.0233), "w": 0.7, "d": 0.746, "h": 1.6, "cx": 2.5, "cz": 4.03, "yaw": 3.14159, "y": -2.4, "box": true},
	{"file": "water-heater", "name": "Water Heater", "kind": "static", "lc": Vector2(0, 0), "w": 0.82, "d": 0.82, "h": 1.61, "cx": 3.55, "cz": 3.98, "yaw": 0, "y": -2.4, "box": true},
	{"file": "towel-rail", "name": "Towel Rail", "kind": "static", "lc": Vector2(0, 0.0025), "w": 0.6, "d": 0.08, "h": 0, "cx": -0.55, "cz": -4.36, "yaw": 0, "y": 2.6, "box": false},
	{"file": "thermostat", "name": "Thermostat", "kind": "static", "lc": Vector2(0, 0.00105), "w": 0.14, "d": 0.03, "h": 0, "cx": 0.12, "cz": 0.15, "yaw": 1.5708, "y": 1.5, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": 3.6, "cz": 4.39, "yaw": 3.14159, "y": 2.9, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": 5.89, "cz": 1.2, "yaw": -1.5708, "y": 2.9, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -3.4, "cz": -4.39, "yaw": 0, "y": 2.9, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -5.89, "cz": -2.4, "yaw": 1.5708, "y": 2.9, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -5.89, "cz": 2.2, "yaw": 1.5708, "y": 2.9, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -3.2, "cz": -0.41, "yaw": 0, "y": 2.9, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": 1.15, "cz": -4.39, "yaw": 0, "y": 3.72, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -5.89, "cz": 1.2, "yaw": 1.5708, "y": 0.4, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -2.6, "cz": 4.39, "yaw": 3.14159, "y": 0.4, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -1.6, "cz": 0.61, "yaw": 0, "y": 0.4, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -5.89, "cz": -2.2, "yaw": 1.5708, "y": 0.4, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": -3.4, "cz": -4.39, "yaw": 0, "y": 0.4, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": 2.2, "cz": -4.39, "yaw": 0, "y": 1.22, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": 5.89, "cz": -3.4, "yaw": -1.5708, "y": 1.22, "box": false},
	{"file": "outlet-plate", "name": "Outlet", "kind": "static", "lc": Vector2(0, 0.00045), "w": 0.075, "d": 0.015, "h": 0, "cx": 0.5, "cz": 4.39, "yaw": 3.14159, "y": -2.1, "box": false},
]

# Code-built fixtures (no model file): the hall dome, the
# bathroom vanity bar, and the two basement bulbs — positions
# and light numbers from the React build. light_at is the
# light's position relative to the fixture root; the glow
# mesh is built to match the visual kind.
const PROPS: Array = [
	{"id": "hall-dome", "name": "Hall Light", "group": "hall", "visual": "dome",
		"at": Vector3(0.5, 0.1, -0.5), "light_at": Vector3(0, 2.05, 0),
		"energy": 1.5, "range": 8.0},
	{"id": "bath-bar", "name": "Vanity Light", "group": "bath", "visual": "bar",
		"at": Vector3(0.62, 2.6, -4.34), "light_at": Vector3(0, 2.28, 0),
		"energy": 1.5, "range": 5.5},
	{"id": "basement-bulb-a", "name": "Basement Bulb", "group": "basement", "visual": "bulb",
		"at": Vector3(-0.5, -2.4, 1.2), "light_at": Vector3(0, 2.05, 0),
		"energy": 1.6, "range": 10.0},
	{"id": "basement-bulb-b", "name": "Basement Bulb", "group": "basement", "visual": "bulb",
		"at": Vector3(-3.5, -2.4, 2.5), "light_at": Vector3(0, 2.05, 0),
		"energy": 1.6, "range": 10.0},
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
	"smoke-detector": Vector2(-0.12, 0.02),
	"mirror": Vector2(1.02, 2.14),
	"towel-rail": Vector2(0.7, 1.48),
	"kitchen-wall-south": Vector2(1.75, 2.45),
	"kitchen-wall-east": Vector2(1.75, 2.45),
	"switch-plate": Vector2(-0.09, 0.09),
	"outlet-plate": Vector2(-0.06, 0.06),
	"range-hood": Vector2(1.5, 1.83),
	"thermostat": Vector2(-0.09, 0.09),
	"curtains": Vector2(0.9, 2.3),
	"hanging-plant": Vector2(-0.55, 0.05),
	"picture-frame-1": Vector2(-0.28, 0.28),
	"picture-frame-2": Vector2(-0.28, 0.28),
	"picture-frame-3": Vector2(-0.28, 0.28),
	"poster-bedroom-1": Vector2(-0.35, 0.35),
	"poster-bedroom-2": Vector2(-0.35, 0.35),
	"water-heater": Vector2(0.0, 1.35),
	"furnace": Vector2(0.0, 1.5),
	"shovel": Vector2(-0.65, 0.65),
	"phone": Vector2(0.0, 0.22),
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
