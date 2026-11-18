# Incident Report — the Godot edition

Adam's game, ported from the React/Three.js build
([NomadtheGrey/IncidentReport](https://github.com/NomadtheGrey/IncidentReport))
to Godot 4.7. Same house, same pins, same joke — a new engine,
because new game work lives in Godot's court now (Adam's ruling,
2026-11-18).

## The game

A scary game whose solutions would work in a real house. A man
breaks in at 2 a.m. with a knife and a pillowcase. You are the
homeowner, and the house is full of ordinary objects that behave
like themselves — starting with a cast iron skillet.

The structure is *Bambi vs. Godzilla*: stupidly long pompous
credits, about thirty seconds of incident, stupidly long joke
credits, and a closing grade — the Incident Report itself.

**The Frying Pan Test is the one law:** every solution must work
in the real world. No escalation gimmicks, no movie logic. A
dispatched intruder stays dispatched. Tying him up with an
extension cord is legitimate play.

## The port

What exists in the React build is the *stage*, not the game:
a four-level Blockbench house you can walk, with locking doors,
a searchable junk drawer, working light circuits, and pickups.
The incident loop (the intruder, the swing, the Report card) is
not built in either stack yet — which is exactly why the port
happens now, before it would have to be done twice.

Everything transfers as data: the models (glTF is Godot's native
format), the house measurements, the design pins, the credits
copy. The code is a rebuild, system by system, slice by slice.

## Slices

1. **Foundation** — the house imported and walkable end to end,
   the basement-stair door leaf working (locks from the kitchen
   side, swings into the room, never over the flight), the
   basement descent proven.
2. **Kitchen systems** — the junk drawer (searchable, hammer
   inside), the skillet pickup, one light circuit, look tags.
3. **The homeowner** — the Goodguy walking, the house zoned
   and labelled.

Then the rest of the furniture, room by room — and the
intruder, when Adam calls him.

## Working rules

- `WIP` is the staging branch; `main` changes only through a
  merge, on Adam's word.
- Design pins live in `DESIGN.md`. Numbers stay draft until
  Adam's pin pass.
- The React build stays live as the playable archive.
