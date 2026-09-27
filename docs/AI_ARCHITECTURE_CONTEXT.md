# Veyra AI Architecture Context

This file is the compact architectural memory supplied to coding agents. It is intentionally smaller than the repository. The repository remains the source of truth; when this document conflicts with code, inspect the code and treat the code as authoritative.

## Runtime
- Godot 4.7.2.
- Android/mobile-first, Compatibility renderer, target roughly 4 GB RAM.
- Third-person player. Deterministic default world seed 47291. World day cycle is 600 seconds.
- Do not modify project.godot or secrets from the AI agent.

## Authority and state
- GameManager is the world initialization/seed/save coordinator.
- SaveManager owns persistence to user://veyra_world.json and explicit versioned sanitization/deserialization.
- SettlementManager owns settlement name, population, stocks, buildings and villagers.
- ResourceNode is the authority for resource-node interaction/gathering state.
- BuildingManager/BuildingInstance own building placement/instances; BuildingCatalog is the data catalog.
- CraftingManager/CraftingCatalog own transactional crafting.
- Inventory is authoritative for carried resources/items; current alpha weight cap is intentionally generous (400).
- Future multiplayer rule: client requests actions; host validates/mutates authoritative state; state/events replicate; presentation is not authoritative.

## Existing gameplay systems
- Player: scenes/player.tscn + scripts/player.gd.
- Interaction: scripts/interaction.gd. It uses direct ray, screen-space fallback, nearby assist, eligibility, obstruction/LOS and hysteresis. Do not replace this with huge interaction radii.
- Resource catalog/node: scripts/resource_node.gd and the resource catalog. Known resource IDs are case-sensitive and include Stone, Wood, Metal, Vitreous Lux, Echo-Stone.
- Tools/items: item catalog, hands, stone axe, stone pick; equipped tool/viewmodel lives with the player.
- Buildings: scripts/building_catalog.gd, building_manager.gd, building_instance.gd. Town Hall is B05_TOWNHALL and is the civic expansion anchor for future town systems.
- NPC foundation: npc_definition.gd, npc_state.gd, npc_simulation.gd, npc_job_simulation.gd; controller/presentation is still evolving.
- Tests live under tests/ and core_test.gd is the main regression entry point.

## Performance rules
- Prefer deterministic generation and bounded simulation.
- Avoid per-frame work for distant/static systems.
- Reuse meshes/materials and instance repeated geometry.
- Avoid unnecessary node counts, unique materials, dynamic allocations and physics bodies.
- Keep water/ecology visually convincing without requiring full fluid simulation.
- Do not create a second catalog or parallel authority when an existing system can own the state.
- Do not turn GameManager into a catch-all.

## World/environment direction
- Veyra is a stylized atmospheric 3D sandbox/exploration/resource game.
- Streams/lakes should be represented as deterministic world features integrated with terrain, not as an unrelated minigame.
- Water should expose clean boundaries/interfaces for future ecology, wildlife, gathering and settlement systems.
- Wildlife/workers should use data-driven definitions and bounded simulation; presentation should be separable from simulation.

## Change discipline
1. Inspect the relevant existing code and tests.
2. Reuse existing interfaces before adding new ones.
3. Make the smallest complete change that satisfies the task.
4. Add/extend regression tests for contracts and deterministic behavior.
5. Never silently change save semantics, resource IDs, interaction authority or multiplayer boundaries.
6. Never claim a feature is correct merely because code parses; validation and human device testing are separate states.
