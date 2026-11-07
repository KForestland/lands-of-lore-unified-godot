# Classic Edition: completion target

Updated by Bob, 2026-10-07: exact mechanical replication is not required; modernize when better or faster. This supersedes the earlier 1:1 mechanics requirement.

## Original game, new engine

Recreate the complete original Lands of Lore 2 campaign in Godot. Preserve its content, story, progression, recognizable encounters, forms, presentation and audio. Act 1 remains the first playable demo milestone; the full Classic game remains the product goal.

Bob explicitly authorizes modern mechanics and implementation when they are better or faster. Exact native timing, AI scheduling, collision quirks, damage arithmetic and internal engine behavior are not release gates. Use the verified components where useful; choose clear, maintainable Godot behavior for remaining gaps. Record material gameplay differences and tune them through playtesting, without requesting approval for every routine implementation choice.

Prioritize complete playable encounters, reliable progression, save/return behavior, reproducible builds and Bob's acceptance. Reverse engineer only when a concrete unresolved behavior blocks those outcomes. Do not delay delivery to exhaustively prove hidden mechanics. This authorization does not remove original content or permit claiming unfinished encounters complete.

## Definition of done

- All original areas and content are accounted for in the [coverage inventory](game-coverage.md).
- A continuous original start-to-finish playthrough works without debug shortcuts.
- Required encounters, quests, puzzles, forms and transitions are complete and preserve campaign progression.
- Combat and interactions are playable, coherent and provide clear feedback; modern timing and mechanics are allowed.
- Saves, loads, deaths and retries preserve/recover the correct state across areas.
- Original presentation, interface behavior, audio and dialogue are checked.
- Authored mechanics are tested in actual play, centrally tunable and documented where materially different.
- Bob has playtested each level/area and confirmed fixes for reported discrepancies.
- Remaining defects and intentional differences are explicit; exact mechanics parity is not required under Bob’s 2026-10-07 direction.

Functional work comes first. Original interface/presentation matching is part of
completion, even though its final pass is deferred. UI problems that block movement,
interaction, reading essential information or saving are functional blockers now.

## QA responsibilities

Bob supplies level-by-level playtest notes, especially on feel, visual/audio details,
original behavior and anything surprising. Informal notes are sufficient; the agent
organizes them into reproducible issues and asks targeted follow-ups only when needed.

The agent owns automated checks, source comparisons, reproduction, fixes, regressions
and honest coverage reporting. Bob should not have to discover preventable save,
progression or crash defects. Automated passes do not substitute for his acceptance.
Use [the QA board](level-qa.md) for notes and [the active plan](restoration-plan.md)
for the current implementation milestone.
