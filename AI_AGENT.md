# Veyra Gemini Backend Engineer

This repository has a controlled Gemini engineering agent.

## Role
Gemini is a secondary implementation/review agent. The lead developer remains responsible for architecture, integration, final review, and merge decisions.

## Operating rules
- Work from the checked-out repository; do not invent repository state.
- Godot 4.7.2, Compatibility renderer, Android/mobile-first, approximately 4 GB RAM target.
- Prefer deterministic, bounded, data-driven systems.
- Avoid per-frame work for distant entities.
- Reuse meshes/materials and instance repeated world content.
- Keep save/load authoritative and explicit.
- Keep future multiplayer compatible: authoritative state, action requests, replicated events/state.
- Do not modify project.godot, credentials, secrets, or unrelated systems.
- Every generated change must pass Godot import, headless smoke, core regression tests, and git diff validation.
- The agent creates a branch and pull request rather than merging its own work.

## Good tasks
- Design and implement performant streams and lakes using the existing terrain/world architecture.
- Add deterministic water bodies with shore boundaries, shallow/deep visual states, cheap collision, save compatibility, and regression tests.
- Audit deer spawning and movement for mobile performance and prepare a scoped implementation.

## Secret
The workflow expects a GitHub Actions repository secret named GEMINI_API_KEY. The key is never committed to the repository.
