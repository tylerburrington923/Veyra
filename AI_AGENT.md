# Veyra Gemini Backend Engineer

This repository has a controlled Gemini implementation agent.

## Role
Gemini is a secondary implementation worker. The lead developer remains responsible for architecture, integration, audit, and merge decisions.

## Context strategy
The agent does **not** dump the whole repository into every Gemini request.

It uses:
1. `docs/AI_ARCHITECTURE_CONTEXT.md` as compact persistent architecture memory.
2. The requested scope.
3. Task-keyword relevance scoring to select supporting files.
4. A hard context budget so repository growth does not automatically consume the entire model context.
5. Regression tests and Godot validation after generation.

The repository itself remains authoritative. The architecture context is deliberately compact and must be updated when major architectural contracts change.

## Operating rules
- Godot 4.7.2, Compatibility renderer, Android/mobile-first, approximately 4 GB RAM target.
- Prefer deterministic, bounded, data-driven systems.
- Avoid per-frame work for distant entities.
- Reuse meshes/materials and instance repeated world content.
- Keep save/load authoritative and explicit.
- Keep future multiplayer compatible: authoritative state, action requests, replicated events/state.
- Do not modify project.godot, credentials, secrets, or unrelated systems.
- Every generated change must pass Godot import, headless smoke, core regression tests, and git diff validation.
- The agent creates a branch and pull request rather than merging its own work.
- A generated PR is not proof of gameplay correctness; device testing remains required.

## Good tasks
- Implement performant streams/lakes using existing terrain/world architecture.
- Add deterministic water bodies with shore boundaries, shallow/deep visual states, cheap collision, save compatibility, and regression tests.
- Audit deer spawning/movement for mobile performance and implement a scoped improvement.
- Add worker behaviors using existing NPC simulation/state authorities.

## Secret
The workflow expects a GitHub Actions repository secret named GEMINI_API_KEY. The key is never committed to the repository.
