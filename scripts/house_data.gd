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
