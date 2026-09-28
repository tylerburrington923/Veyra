# Veyra Alpha Improvement Backlog

Updated: 2026-09-27

This is the active engineering review list. Items are observations from source/code review unless explicitly marked as device-verified. Preserve existing save compatibility, Hotspot/LAN multiplayer, legacy IDs, and mobile performance while addressing these.

## P0 — Fix before next serious phone test

- [x] NPC animation pivots — Villager arms/legs currently animate by rotating MeshInstance3D nodes around their own centers. Introduce lightweight shoulder/hip pivot Node3D parents so gait reads naturally without adding a skeletal rig.
- [ ] First-person hand/tool grip pass — Recheck actual hand-to-handle contact, tool angle, scale, and camera placement for axe/pick. Current geometry is improved but still primitive/interim.
- [ ] NPC visual polish — Refine silhouette, proportions, face readability, clothing shapes, and color/material separation while keeping the low-poly/mobile budget.
- [ ] Interaction HUD final pass — Verify the compact HUD against the smallest supported Android viewport, including target/no-target transitions, long names, requirements, and multiplayer targets.
- [ ] Town Hall doorway/collision decision — Current Town Hall has solid body collision and outside interaction. Decide whether alpha Town Hall should remain exterior-only or receive a true doorway/interior collision layout.

## P1 — Alpha quality / systems

- [x] Building placement concurrency — NetworkManager.request_build() uses shared BuildingManager placement state (select_building → evaluate_placement → confirm_build). Audit for two remote build requests arriving close together; server placement state should be request-local or explicitly serialized.
- [ ] Building placement validation — Add explicit server-side validation for building footprint, distance, duplicate civic structures, and final position rather than relying on transient shared preview state.
- [x] Multiplayer interaction line-of-sight — Server currently validates target existence/group and distance, but not line-of-sight. Decide whether walls/closed doors should block remote interaction.
- [ ] Multiplayer craft/build feedback — Audit client feedback when a remote craft/build request fails due to resources, placement, or stale state.
- [ ] NPC network presentation — Verify remote NPC interpolation and local/host ownership under Hotspot latency, especially while NPCs change jobs/behavior.
- [ ] Wildlife combat loop — Animals can simulate health/death and drop Meat/Hide, but the complete player attack/targeting loop should be audited end-to-end.
- [ ] Wildlife respawn/population policy — Current beta wildlife is a fixed five-creature spawn. Define lightweight respawn/despawn rules before increasing population.
- [ ] Town Hall civic loop — Expand from functional dashboard/deposit into a clear settlement anchor: population, water, stock, available building unlocks, and expansion progress should all be understandable from one compact screen.
- [ ] Well/water gameplay — Verify the Well interaction, water deposit/withdrawal behavior, settlement stock changes, and water-cycle consumption on device and multiplayer host/client.
- [ ] Save/load restoration audit — Test a populated settlement with buildings, doors, storage, villagers, water, player inventory, tool durability, resonance, and world time across save/reload.
- [ ] Save compatibility guardrails — Maintain current world/settlement versions and explicitly tolerate older saves when new fields are introduced.

## P1 — World/visual quality

- [ ] Terrain visual pass — Improve ground readability without adding expensive texture/shader complexity.
- [ ] Water pass — Current lake/stream geometry is deliberately cheap, but the stream path is not hydrologically simulated and should be checked for terrain clipping/floating.
- [ ] Resource presentation — Refine stone/metal/Lux silhouettes and material differentiation; keep the stick-on-ground wood treatment.
- [ ] Echo-Stone placement — Continue validating all anomaly placement against generated terrain and save restoration.
- [ ] Floating/test asset sweep — Repeat runtime visual sweep after each world-generation change; source search alone cannot prove there are no visually misplaced instances.
- [ ] Lighting/night readability — Lunar HUD and dark-world readability should be tuned together so terrain, resources, NPCs, buildings, and tools remain readable without excessive brightness.

## P2 — Performance hardening

- [ ] NPC mesh-instance count — Current NPC visuals use many individual MeshInstance3D parts. Profile before scaling villager population; consider shared meshes/materials or MultiMesh for repeated parts if population rises.
- [ ] Wildlife actor cost — Profile simulation/visual updates with the intended 2–4-player beta population plus wildlife.
- [ ] Terrain collision cost — Current terrain uses a ConcavePolygonShape3D generated from the full terrain mesh. Confirm mobile physics cost and interaction/build placement ray performance.
- [ ] Resource collision count — Audit the number of StaticBody3D resource nodes and whether harvesting/movement collisions can be simplified.
- [ ] Foliage harvesting architecture — Current MultiMesh foliage is efficient visually but creates individual harvest physics bodies. Profile at higher tree counts.
- [ ] World draw distance — Tune foliage/camera/fog distances against actual device FPS rather than desktop appearance.
- [ ] UI allocation churn — Building/crafting UI clears and recreates child controls. Confirm this is only modal/occasional and does not occur every frame.

## P2 — Controls / polish

- [ ] Joystick robustness — Existing release fix is good; test cancellation, finger-up outside the joystick region, simultaneous look + movement, and Android system gesture edges.
- [ ] Camera feel — Recheck first-person pitch/yaw smoothing and tool sway after visual changes; do not alter movement values without evidence of a bug.
- [ ] Punch animation — Verify hands/arms visibly punch and return to neutral on physical device, including rapid repeated presses.
- [ ] Tool durability UX — Ensure tool breakage cleanly switches to Hands and gives clear but unobtrusive feedback.
- [ ] Hotbar readability — Check selected state, tool names, durability, and touch targets on smaller Android screens.
- [ ] Menu layering — Recheck pause/settings/multiplayer/crafting/inventory modal ownership so no panel opens underneath another or traps the player.

## P3 — Alpha expansion candidates

- [ ] Villager jobs — Turn Trader/Builder/Unassigned into visible, useful settlement roles.
- [ ] NPC schedules — Lightweight home/work/rest behavior rather than constant wandering.
- [ ] Animal behavior differentiation — Grazers flee, predators pursue, and species receive distinct movement silhouettes.
- [ ] Settlement construction progression — Town Hall unlocks/requirements should create a meaningful build progression.
- [ ] Environmental resonance events — Use the existing resonance/lunar foundation for small deterministic world events without adding heavy runtime simulation.
- [ ] Interior/door improvements — Make House, Town Hall, storage and utility buildings feel physically coherent once exterior systems are stable.

## Validation gates

1. Godot 4.7.2 project validation passes.
2. Core regression passes.
3. Resonance regression passes.
4. Android export succeeds.
5. Exact APK artifact is inspected and hashed.
6. Hotspot host → client join works on two physical Android devices.
7. Host/client movement and disconnect behavior are tested.
8. Interaction/building/crafting/resource/save systems are tested on device.
9. Visual review specifically checks NPCs, tools, HUD, Town Hall, terrain, water and floating geometry.
10. No completion claim is made from CI alone when a physical-device behavior is required.

## Current review notes

The current main branch is structurally healthy enough that this backlog should be handled as targeted alpha hardening, not a rewrite. The highest-value remaining visual issue is NPC animation/presentation. The highest-value systems issue found in review is shared server-side building placement state during multiplayer requests.