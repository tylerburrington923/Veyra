# Veyra AI Development Protocol

This document defines the engineering workflow for AI-assisted development of Veyra.

## 1. Repository safety

- Treat `main` as the stable integration branch.
- Preserve existing gameplay functionality unless the task explicitly removes it.
- Preserve legacy IDs, save compatibility, network contracts, and public data schemas.
- Never replace an entire source file to make a small fix.
- Prefer the smallest possible diff.
- Before modifying a file, inspect the relevant surrounding code and callers.
- After modifying a file, inspect the resulting diff for accidental deletion or unrelated changes.

## 2. Change-before-code analysis

For every non-trivial change, identify:

1. The requested behavior.
2. The authoritative owner of the state.
3. Callers and dependencies.
4. Save/load implications.
5. Multiplayer/replication implications.
6. UI/gameplay implications.
7. Test coverage that should change.
8. Android/export implications.
9. Performance implications.

If the change crosses several of these boundaries, perform a broader audit before editing.

## 3. Implementation rules

- Use explicit GDScript types in critical systems where inference can become ambiguous.
- Avoid unsafe dynamic access when a typed interface or validated lookup is practical.
- Do not refactor unrelated code while implementing a feature.
- Do not rename IDs or silently change serialized keys.
- Keep server-authoritative logic server-side.
- Keep client presentation separate from authoritative state.
- Do not introduce per-frame work when an event-driven or throttled update is sufficient.
- Do not optimize by guesswork; profile first when performance is the concern.

## 4. Verification loop

Every meaningful implementation follows:

**Inspect → trace → minimal patch → parse/static validation → targeted tests → full regression suite → Android validation → diff audit → final verification.**

A failed check is not evidence that the previous code was correct. Fix the failure, then rerun the relevant checks.

After a build/test failure:

1. Read the actual failure.
2. Identify the smallest root cause.
3. Patch only that cause.
4. Re-run the failing validation.
5. Re-run broader validation.
6. Inspect the final diff.

## 5. Tests

Tests must validate behavior and contracts, not merely function existence.

Prefer scenarios of the form:

**Given state X → perform action Y → authoritative result is Z → persistence/replication preserves Z.**

High-value regression coverage includes:

- inventory/crafting
- tools/resource gates
- health/death/respawn
- save/load
- settlement/building placement
- NPC/wildlife behavior
- multiplayer authority and snapshots
- progression/discovery
- mobile UI contracts
- performance-sensitive simulation cadence

When fixing a regression, add or strengthen a test when practical so the same failure is less likely to return.

## 6. Multiplayer audit

For every stateful multiplayer feature explicitly determine:

- Who owns the state?
- Who is allowed to mutate it?
- What is replicated?
- At what cadence?
- What happens to late joiners?
- What happens after disconnect/reconnect?
- Is persistence authoritative?
- Can a client forge the action?

Never assume a feature is multiplayer-safe because it works in a local test.

## 7. Save compatibility

Before changing persistent state:

- inspect the current save version;
- inspect sanitization and load paths;
- preserve existing IDs/keys;
- provide defaults for newly introduced fields;
- test populated save data, not only empty/new saves.

## 8. Android evidence standard

An APK is only considered ready when all of these are established:

- the exact source commit is known;
- validation passes for that commit;
- Android export succeeds for that commit;
- the expected APK artifact exists;
- the artifact belongs to that build;
- no later source commit has invalidated the artifact.

Never provide an older APK as though it represents the current source.

## 9. Performance standard

Target the intended low-end Android baseline, not the strongest development phone.

Prioritize:

1. excessive update frequency;
2. excessive active object count;
3. unnecessary physics;
4. excessive draw calls/material complexity;
5. unnecessary network traffic;
6. memory allocations in hot paths;
7. expensive NPC/pathfinding work.

Do not sacrifice Veyra's visual/gameplay identity until these sources of cost have been measured.

## 10. Final audit

Before declaring a task complete, answer internally:

- Did I change only what was necessary?
- Did I accidentally delete or replace unrelated functionality?
- Did I preserve save compatibility?
- Did I preserve legacy IDs?
- Did I preserve multiplayer authority?
- Did I add/adjust regression coverage where appropriate?
- Did the exact commit pass validation?
- Is the claimed artifact actually from that commit?
- Are there unresolved warnings or failures?
- Is there anything I am claiming that has not been verified?

If evidence is missing, report it as missing rather than inferring success.

## 11. Veyra-specific priority

The project is moving toward alpha. Work should be decisive rather than artificially broken into tiny cosmetic steps, but speed never overrides repository integrity.

Use this pattern:

**large coherent implementation pass → rigorous automated validation → forensic code/diff audit → targeted fixes → full validation → device test when available.**

The goal is to increase development velocity by reducing regressions, not by reducing verification.
