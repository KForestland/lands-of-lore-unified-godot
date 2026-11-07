# Read original area sources for preparation

`verify_actor_item_grants.source_area` reads an original area without loading native replay, Capstone or companion-RE modules. It uses the published geometry profiles and existing local owner/command readers. It returns the same six-part tuple: area record, archive bytes, MIX entry, geometry bytes, event owners and command streams.

From a source checkout:

```sh
LOL2_GAME_ROOT=/path/to/original/game PYTHONPATH=tools \
python3 -S -c 'from verify_actor_item_grants import source_area; print(source_area("L1_DC")[0]["source"])'
```

Python callers can instead pass `source_area("L1_DC", game=Path("/path/to/original/game"))`. An explicit argument takes precedence over the environment. Without either, the historical local default remains. An explicitly empty `LOL2_GAME_ROOT` is rejected rather than treating the current directory as a game root. `ROOT`, `GAME` and `u32` remain available to existing callers.

The area record contains id, level, name, pinned source identities and counts for vertices, regions, actors and props. The last two counts are read from bounded tables in the pinned geometry. It omits the old unpublished inventory's unrelated research/status/quest fields. All current source-area callers were checked for consumed fields before this substitution.

Independent verification compared all fifteen areas against the old reader: consumed fields, archive/geometry hashes, MIX entries, event owners and command streams match exactly. The new reader ran with `python3 -S`, no source inventory and an empty external-helper checkout. A changed original archive was rejected; an empty game-root override was reproduced and then rejected by the new guard. Do not run with `python -O`, which disables the existing assertion-based identity checks.

This removes dependencies from source parsing only. Running the module's native-verification `main()` still imports its original replay dependencies. Preparers can also have separate native, media or fixed-path dependencies of their own; successful source reading does not prove a complete clean asset build.
