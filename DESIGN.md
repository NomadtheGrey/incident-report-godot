# Incident Report — design record (Godot edition)

Carried over from the React build's docs. PINNED means Adam
settled it; DRAFT means it waits for his pin pass.

## PINNED

- **The Frying Pan Test (the one law):** every solution must
  work in the real world; everything behaves like itself. The
  skillet works. No escalation gimmicks.
- **Structure:** stupidly long opening credits, ~30 seconds of
  incident, stupidly long closing credits interrupted by the
  epilogue if the player elects it, closing grade = the Report.
- **First person.** Camera **72° vertical FOV**, fenced.
- **House:** upstairs, main floor, basement. Every door
  lockable from the inside, standard privacy locks.
- **The intruder** spawns in a random eligible room (Kitchen,
  Dining Room, Living Room, Basement — basement weighted low),
  creeps, examines the household goodies, carries a pillowcase.
  Knocked down, he tries to crawl away. A dispatched intruder
  stays dispatched until police arrive.
- **Everything is optional for the player** — the phone
  included. Nothing is a forced pickup.
- **Item placements:** claw hammer in the kitchen junk drawer;
  shovel hanging on the wall in the basement stairs; extension
  cord plugged into a lamp (at least one lamp in the living
  room); extension cord is garden green and stays green.
- **Basement-stair door:** at the top of the basement flight,
  accessed from the kitchen. It closes only the south lane,
  locks from the room side, and swings INTO the room — never
  out over the flight. No doors at the up-stairs.
- **Night:** the house is dark but not pitch black; lights are
  real placed sources the player switches on; window spill
  from streetlights.
- **Bedroom names in game UI:** Master Bedroom, Bedroom 1,
  Bedroom 2, Master Closet.

## Port notes (this repo)

- The house model is Adam's Blockbench export, coloured by the
  React pipeline's colour pass. His convention: 1 Blockbench
  unit = 1 m, exported ÷16. The loader holder transform is
  scale (−16, 16, 16), rotation Y +90°, position (0, 0, 0.5) —
  the same transform the React build uses; game coordinates
  are identical between the two builds.
- Stairs: the model's flights are discrete step boxes. The
  walker rides invisible wedge ramps laid over each flight's
  nosing line (standard practice; the steps you see are the
  model's own).
- All dimensions in metres. Walker: radius 0.22, height 1.6,
  eye 1.62, walk 2.9 m/s, run 4.6 m/s — ported numbers.
