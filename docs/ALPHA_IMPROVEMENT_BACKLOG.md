# Veyra Alpha Improvement Backlog

Updated: 2026-09-28

This is the active engineering review list. Items are observations from source/code review unless explicitly marked as device-verified. Preserve existing save compatibility, Hotspot/LAN multiplayer, legacy IDs, and mobile performance while addressing these.

## P0 — Fix before next serious phone test

- [x] NPC animation pivots — Villager arms/legs currently animate by rotating MeshInstance3D nodes around their own centers. Introduce lightweight shoulder/hip pivot Node3D parents so gait reads naturally without adding a skeletal rig.
- [ ] First-person hand/tool grip pass — Recheck actual hand-to-handle contact, tool angle, scale, and camera placement for axe/pick. Current geometry is improved but still primitive/interim.
- [ ] NPC visual polish — Refine silhouette, proportions, face readability, clothing shapes, and color/material separation while keeping the low-poly/mobile budget.
- [ ] Interaction HUD final pass — Verify the compact HUD against the smallest supported Android viewport, including target/no-target transitions, long names, requirements, and multiplayer targets.
- [ ] Town Hall doorway/collision decision — Current Town Hall has solid body collision and outside interaction. Decide whether alpha Town Hall should remain exterior-only or receive a true doorway/interior collision layout.

## P1 — Settlement economy integration

- [x] Data-driven production definitions — Existing ProductionDefinition/ProductionState/ProductionManager now own transactional inputs, outputs, progress, worker assignment, cancellation/refund, and active-state persistence.
- [x] Villager job execution contract — Existing JobDefinition/NPCJobSimulation now have explicit movement/work speeds and serialize those parameters without replacing the NPC state architecture.
- [x] NPC → job → production integration — NPCManager now delegates settlement villagers into the existing job simulation and settlement production flow; host-side NPC simulation remains authoritative.
- [x] Storage → production → storage loop — Campfire cooking consumes Meat + Wood from settlement storage and produces Food; Blacksmith refining consumes Metal + Wood and produces Refined Metal; Lumberjacks replenish Wood through the same production pipeline.
- [x] Villager needs consume production — Villagers consume settlement Food/Water; produced Food can be consumed directly from settlement storage when reserve Food is empty.
- [x] Settlement production persistence — Active jobs and production states are serialized, sanitized, restored, and orphaned/corrupt active production is cancelled with input refund when possible.
- [x] Regression coverage — Targeted tests cover job definition serialization, NPC job execution, integrated NPC production, Food storage output, and settlement save sanitization.
- [ ] Physical-device verification — The integrated economy loop has not yet been verified on two physical Android devices or under real Hotspot latency.

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

- [x] NPC simulation allocation churn — Reuse the NPC typed-state scratch buffer instead of allocating a new Array every simulation tick.
- [ ] NPC mesh-instance count — Current NPC visuals use many individual MeshInstance3D parts. Profile before scaling villager population; consider shared meshes/materials or MultiMesh for repeated parts if population rises.
- [x] Wildlife resource duplication — Wildlife now shares mesh/material resources within the manager instead of creating duplicate geometry/material resources per creature.
- [ ] Wildlife actor cost — Profile simulation/visual updates with the intended 2–4-player beta population plus wildlife.
- [ ] Terrain collision cost — Current terrain uses a ConcavePolygonShape3D generated from the full terrain mesh. Confirm mobile physics cost and interaction/build placement ray performance.
- [ ] Resource collision count — Audit the number of StaticBody3D resource nodes and whether harvesting/movement collisions can be simplified.
- [ ] Foliage harvesting architecture — Current MultiMesh foliage is efficient visually but creates individual harvest physics bodies. Profile at higher tree counts.
- [x] Terrain runtime sampling — Cache generated terrain heights and provide fast bilinear sampling for actor/foliage runtime queries; exact noise remains authoritative for mesh generation.
- [x] Terrain lighting cost — Terrain moved from per-pixel to per-vertex material shading; geometry/texture quality is unchanged.
- [x] Foliage shadow cost — Foliage MultiMesh instances no longer cast dynamic shadows; scene lighting remains intact while removing an expensive mobile shadow pass.
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

## Performance research findings

Sources: Godot 4.7 rendering, MultiMesh, LOD, and occlusion-culling documentation; Android Developers game optimization guidance; GDC 2023 session on mobile occlusion culling in Life After.

- Godot's Compatibility renderer remains the intended low-end/mobile path for Veyra. It has a low base rendering cost, while its scaling cost makes object count, draw calls, overdraw and expensive lighting especially important.
- Godot MultiMesh is the correct mechanism for repeated simple environmental geometry, but large spatially spread MultiMeshes should be split into chunks because individual instances cannot be frustum/occlusion culled.
- Godot LOD/visibility ranges and occlusion culling are complementary. Occlusion is most valuable where level geometry actually creates occlusion opportunities; blindly enabling it in open terrain can add CPU/setup cost without benefit.
- Android's game-performance guidance emphasizes reducing geometry, draw calls, unnecessary attachments, and using LOD/culling; ASTC texture compression can substantially reduce texture memory. Veyra already has ETC2/ASTC import enabled, so the next gains should come from runtime object/shadow/CPU budgets rather than adding larger textures.
- Mobile/tile-based GPUs are especially sensitive to expensive shader, viewport-texture and post-processing work, reinforcing Veyra's Compatibility + simple-material approach.
- A useful external benchmark for the direction is NetEase's *Life After*: its mobile occlusion solution reportedly reduced draw calls by about 65% on low-end phones, illustrating the scale available from visibility management when a world has enough occlusion structure. This is research context, not a claim about Veyra's current performance.

## Current review notes

The current main branch is structurally healthy enough that this backlog should be handled as targeted alpha hardening, not a rewrite. The highest-value remaining visual issue is NPC animation/presentation. The first settlement-economy integration cycle is now CI-verified and remains device-unverified. The next systems priority is server-side building placement validation plus NPC/network presentation under Hotspot conditions.