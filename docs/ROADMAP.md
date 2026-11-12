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

## Systems (built in order, each one finished before the next)
1. [x] Player controller: movement, camera, jump, sprint
2. [x] Interaction: look at a thing, press a key
3. [x] Resources and gathering
4. [ ] Inventory  ← current
5. [ ] Crafting (by hand, then at stations)
6. [ ] Building
7. [ ] Survival pressure (health, hunger, stamina)
8. [ ] Workers v1: one worker gathers into a chest
9. [ ] Production chains: workers run stations
10. [ ] Recruitment

## Later, maybe (not now)
- Replanting trees from saplings/seeds (trees never regrow on their own; also a worker job)
- Weight limit on carried items (with inventory or survival)
- Combat, enemies, bosses
- Biomes
- Multiplayer
- Animations, crouch, swim, climb, step-up on stairs
- Settings menu (sensitivity, key rebinding)
