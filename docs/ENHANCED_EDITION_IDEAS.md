# LoL2 Enhanced Edition: ideas backlog

Classic stays faithful to the original. These are changes that alter game dynamics, kept for a later Enhanced
Edition (owner decision, 2026-10-21). Each needs a design pass and balancing before it is built.

## Curse control (owner, 2026-10-21)

- **Problem:** the curse is an annoyance for most players.
- **Idea:** a skill tree with "Curse Control" points. Possible effects:
  - shorter involuntary transformations;
  - lower chance at curse spots;
  - earlier access to free transforming;
  - longer voluntary forms.
- **Hook:** every curse request already goes through `scripts/lol2/player_curse.gd`, so a policy layer there can
  change spot durations and chances, and the transform-key rules, in one place.
- **Classic reference:**
  - Cave spots: 60–90 s, plus the region631 hold until a human-return spot.
  - Jungle spots: 45–60, 120–180 and 210–285 s.
  - Original transform keys: 60 s, gated by admission bit 0x10 (sub 0x24 sets it, 0x25 clears it).

## Edition vision (owner, 2026-10-21)

The Enhanced Edition is a separate, later project. Classic comes first. It should include:
- many gameplay changes and modernized maps;
- compatibility across Lands of Lore 1–3 Enhanced (shared systems, saves and characters, to be designed);
- story plots from the unified "Chronicles of Time" woven in;
- ancient ruins from before and during the time of the Ancients, scattered around the world.

## World structure (owner question, 2026-10-21: "one plane like Abiotic Factor, or separate?")

- **Classic:** keep the original separate areas (L1_DC, L3_DH, L4_HJ…). All native evidence is per area: coordinates,
  region/object ids and scripts. The tested handoff contract carries the player between areas.
- **Polish (fine for Classic too):** load the next area in the background near an exit for near-instant transitions,
  keeping the original transition points.
- **Enhanced:** a shared world-map layer above the separate areas, for linking LoL 1–3, modernized maps, Chronicles
  of Time plots and Ancient ruins. One merged map is not planned: it would renumber all native ids and hurt testing
  and performance.

## Form control as abilities (owner, 2026-10-21; not in Classic)

- **Idea:** the player chooses human/beast/lizard, the form is held until changed, a short cooldown applies, only
  curse-driven morphs restore health, and changes are blocked where the original blocks the curse (admission bit
  0x10).
- **Forms as Metroid-style tools:** lizard is tiny and fits small passages; beast is strong.
- **Parked draft (not applied):** keys 3/4/5 and a 10 s cooldown in player_curse.gd; the draft and its test were kept
  in the 2026-10-21 session scratchpad.
- **Native reference:** the action switch at D24B1 has cases 0x1A/0x1B/0x1C (human/lizard/beast, 60 s); their input
  source is not yet found.
