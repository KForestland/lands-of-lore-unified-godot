# Player combat and health foundation

Base: r19-work d5da60a. Structure only; no balance, refusal, target dispatch,
clock ownership, save key or per-area save version changes. Not Thursday's r19.

The migration follows Fable's Plan1, with Kimi K85 items1–5 included:

- The direct writer checklist has ten families. In addition to the original
  seven, it includes guardian windups (`hive_warriors`), the live executioner
  (`hive_executioner_live`) and Morgan's orb heal (`monastery_rooms`).
- The facade has23 executable invocation sites in20 files:22 ordinary/local
  calls and one `magic.call("set_health", ...)` in `dark_halls_crates`.
  A raw name search finds21 files because `hive_review.executioner_set_health`
  is a different adapter, not an invocation of this facade. The full d5 source
  census is pinned in tests/fixtures/player_health_callers_d5da60a.json.
- Four independent player cooldown clocks remain separate. Three are saved:
  Cave `roach.strike_remaining`, dinosaur `strike_remaining`, and Hive
  `quests.hive_encounter.cooldown`. The shared population clock is not saved.
  Frozen d5 fixtures compare all three saved clocks, including Hive0.375s.
- Cave disk health is `roach.player_health`. `_completion_state().health`
  belongs to the Cave-to-Museum transfer packet, not to the quicksave.
  The fixture contract checks both representations separately.
- Melee rewards execute inside the existing receivers at sites1,3,4,6.
  They stay outside the shared after-hit presentation/item-effect tail.
  Actual site1/3 hit, kill, corpse refusal, RNG and disk rollback are pinned by
  foundation_melee_reward_owners_test; existing Cave/Hive reward tests remain.

The owner's unchanged-behaviour requirement also corrects Plan1's initial clamp
proposal: the old facade stores raw integers, including46 and-3. The new owner
must preserve that. Bounds stay with callers, save validators, `lose` and `heal`.
The reward progression's maximum is a separate, currently unintegrated model.

Baseline tests37c21f1 passed on unchanged d5 gameplay before production edits.
K85 tests are added before health ownership changes; the three raw writers and
indirect crate path still match d5 at their initial qualification. Tests using
spy receivers, supplied inventory/positions or health top-ups declare those
source sites. Local real-click tests do not claim earned campaign routes.

Health binding is early enough for every existing load path: scene bases construct
one data node, attach it in `_ready`, and legacy aliases forward immediately.
The Cave roach binds during setup; the optional-roach legacy-load branch binds
its replacement model and resets the same owner. Hive pre-tree alias assignments
are promoted on tree entry. Unentered scene previews dispose their unattached
owner on deletion. The standalone encounter model remains usable by pure tests
and the legacy prototype review, preserving that review's existing facade quirks;
the five playable host families are covered by mutual-alias and fixture tests.

No root `health` key is added to the Cave disk format, and no per-area version is
changed. Frozen d5 saves stay immutable. The facade invocation census is pinned
for review: a future feature adding a caller should update that inventory
intentionally, rather than silently dropping the dynamic-call check.

The final fast source guard rejects new conventional player damage tables,
melee-damage calls (including dynamic calls), copied named strike constants,
unowned health fields, raw/deferred health writers and private-store writes.
It scans whole source files, including nested callbacks. Ten in-memory mutation
probes exercise rejection. Legacy loader assignments still use forwarding aliases.
The only non-damage strike-reach declaration exempted is the exact pre-existing
L19 sewer bar/region reach96; changing that declaration requires review. Colour
and animation constants are outside this player-combat policy. This is a static
maintenance guard, supplemented by the runtime tests and source review.
