# Jungle missing pickups — private work in progress

Hosts61 previously absent original rows through the existing Jungle world-item
controller and saved collection history. Together with its13 previous rows,
that controller now has74 sprites. The separate dagger and seven river-dam
pickups keep their owners, accounting for82 of the original88 rows.

The remaining six rows stay explicit: elevated58–62 require original populated
support evidence; row82 retains flag0x402 and requires its semantic check.
The staged candidate manifest includes row82, but the runtime catalog excludes it.
No existing elevated pickup was lowered. All new positions match original
isolated item settling and the loaded port floor collision. This is not proof
of original populated-support physics or earned player reachability.

The added rows have flags2 and no existing row-specific pickup owner in the
port. Distinct world rows retain distinct identities, even when their definition
matches a room reward. Rendered/contextual duplicate review remains pending.
Already implemented Aloe and Ancient Stone uses are selected by original
source definition. Other unimplemented item effects remain separate work.

Row15 Guard Shield uses the same offhand behavior and pinned definition37
(defense5 and descriptors) as the Cave shields. Equipment tests reproduced its
missing registration before the fix. Source defense data regenerate from the
original definition rather than a new balance constant.

Headless tests cover74 actors,61 supplied carried identities, one-shot history
migration, actual disk save/load, fresh-process restart, five malformed packet
rejections without live-state changes, and Jungle/Hive save/load/return.
Guard Shield defense persists. These are supplied-state tests, not earned routes.
The rendered pickup test is expanded to all74 actors and removes carried entries
as needed to stay below64 capacity while preserving history; it is not yet run.

Media staging: run prepare_jungle_missing_items.py with explicit original game,
all88 native settling receipt and its reviewed SHA256, and a fresh output root.
Copy its generated/jungle_missing_items folder into the private project's assets;
never overwrite another worktree's shared generated media. Source commits exclude
original assets and the isolated test profile. This branch is not release-ready.

New row2 Ancient Stone and encoded-height row78 Aloe are also checked through
the actual host item controller: charge1/pendingheal5, spent history, duplicate
use refusal, disk restore without respawn, and atomic rejection when the pickup
receipt is missing. The negative fixture filters integer-normalized JSON rows;
Array.erase(int) did not remove JSON float rows in the initial test attempt.
