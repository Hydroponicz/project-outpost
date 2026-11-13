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
- Building uses the hammer and Valheim-style snap points; no workbench needed nearby; removing refunds fully
- Chests (16 slots) open next to your inventory; a chest with items in it can't be removed

## Systems (built in order, each one finished before the next)
1. [x] Player controller: movement, camera, jump, sprint
2. [x] Interaction: look at a thing, press a key
3. [x] Resources and gathering
4. [x] Inventory
5. [x] Crafting: recipes by hand and at stations (test workbench placed in the level)
6. [x] Tools: hotbar, axe/pickaxe required for trees/rocks, durability with free repair, forage
7. [x] Building: hammer, snap-point placement, workbench/floor/wall, then a chest
8. [x] Saving and loading: title screen, pause menu, autosave every 5 min and on quit
9. [ ] Survival pressure (health, hunger, stamina)  ← next
10. [ ] Workers v1: one worker gathers into a chest
11. [ ] Production chains: workers run timed processing stations
12. [ ] Recruitment

## Later, maybe (not now)
- Replanting trees from saplings/seeds (trees never regrow on their own; also a worker job)
- Combat, enemies, bosses
- Biomes
- Multiplayer
- Animations (incl. tool swings; held tool is a static placeholder), crouch, swim, climb, step-up on stairs
- Settings menu (sensitivity, key rebinding)
