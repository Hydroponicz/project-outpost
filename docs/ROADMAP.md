# Project Outpost: Roadmap

**Core loop:** Survive and build by hand at first, then recruit workers who take
over the repetitive jobs, so your time moves from gathering to managing and exploring.

Rule: every new idea must support this loop. If it doesn't, it goes to "Later, maybe".

## Decisions so far
- Engine: Godot 4.7, GDScript
- Gray-box art until systems are proven
- Valheim-style camera: always follows the mouse, character turns to face movement
- Gamepad supported from day one (every action has a keyboard and a gamepad binding)
- Goal: commercially viable 1.0
- Resources do not regrow by themselves; trees are replanted by the player (later)
- Dropped items are separate pieces, auto-vacuumed into the player when in range
- Crafting is instant and done by the player; timed processing (smelting etc.) is for workers
- Trees need an axe and rocks a pickaxe; first materials come from forage (branches, loose stones) which respawns
- Tools wear out; repair is free at a workbench; the top inventory row is the hotbar

## Systems (built in order, each one finished before the next)
1. [x] Player controller: movement, camera, jump, sprint
2. [x] Interaction: look at a thing, press a key
3. [x] Resources and gathering
4. [x] Inventory
5. [x] Crafting: recipes by hand and at stations (test workbench placed in the level)
6. [ ] Tools: hotbar, axe/pickaxe required for trees/rocks, durability with free repair, forage  ← current
7. [ ] Building (the workbench becomes buildable here)
8. [ ] Survival pressure (health, hunger, stamina)
9. [ ] Workers v1: one worker gathers into a chest
10. [ ] Production chains: workers run timed processing stations
11. [ ] Recruitment

## Later, maybe (not now)
- Replanting trees from saplings/seeds (trees never regrow on their own; also a worker job)
- Combat, enemies, bosses
- Biomes
- Multiplayer
- Animations, crouch, swim, climb, step-up on stairs
- Settings menu (sensitivity, key rebinding)
