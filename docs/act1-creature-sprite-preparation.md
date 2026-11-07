# Act One creature sprite inputs

The published `prepare_museum_creature_sprites.py` command also prepares these Cave and Jungle sprite sets. First decode the area's original texture with `decode_level_texture.py`; then pass the area archive, freshly decoded texture and every listed definition:

```sh
python3 -S tools/decode_level_texture.py --game "$GAME" --area L1_DC --output "$FRESH_TEXTURE"
python3 tools/prepare_museum_creature_sprites.py --game "$GAME" --archive DAT/L1_DC.MIX --texture "$FRESH_TEXTURE/texture.bin" --definition 0 --definition 1 --definition 2 --output "$FRESH_ASSEMBLY/assets/lol2/generated/cave_guard_sprites"
```

Each output directory must be fresh. The table's destinations are relative to `assets/lol2/generated/`; use the corresponding archive and texture for each row. Requires Pillow, plus system `liblzo2` for texture decoding. These explicit sprite commands use repository readers and do not need an RE checkout.

| Area | Definitions | Destination | Verified files |
| --- | --- | --- | --- |
| L1_DC | 0, 1, 2 | `cave_guard_sprites` | 983 |
| L1_DC | 6 | `cave_lurking_roach_sprites` | 100 |
| L1_DC | 4, 5 | `cave_roach_audio_sprites` | 100 |
| L1_DC | 7 | `cave_scenic_guard` | 109 |
| L1_DC | 5 | `cave_wild_roach_sprites` | 100 |
| L4_HJ | 1 | `jungle_actor62/sprites` | 763 |
| L4_HJ | 9 | `jungle_exit_guard_sprites` | 302 |
| L4_HJ | 6 | `jungle_exit_woman_media/l4ww_sprites` | 164 |
| L4_HJ | 7 | `jungle_kelsrick/sprites` | 285 |
| L4_HJ | 0, 1, 2, 3 | `jungle_villager_sprites` | 763 |
| L3_DH | 0, 1, 2 | `museum_creature_sprites` | 835 |

An isolated run with published tools, original archives and newly decoded textures reproduced all 4,504 files byte-for-byte, including each palette and sprite manifest. Existing unsupported-resource entries are retained exactly; this does not add support for movie-backed poses or establish native animation fidelity. Audio, encounter configuration and movies remain separate inputs. `cave_scenic_guard` additionally needs `prop_617.png`; prepare it with the Cave prop exporter as shown below. `cave_roach_audio_sprites` is a preparation input and is not claimed to be an additional live encounter.

The generic command is insufficient for Cave eyes: use [their existing sequence expansion and sound recipe](cave-eyes-media-preparation.md). Both Dawn encounters also need their dialogue packs; use [complete Dawn media preparation](dawn-media-preparation.md). Bacatta recipes already combine dialogue and creature sprites. Hive warrior/executioner/worm and Jungle dinosaur manifests use different schemas and are outside this table. Never replace a complete encounter directory with only the sprite outputs when that would remove other required files.

For the scenic guard, run the existing prop exporter against the original Cave archive, with fresh output, then copy the one required indexed still alongside the already prepared creature sprites:

```sh
python3 tools/lol2/map_props.py export --game-root "$GAME" --area L1_DC --out "$FRESH_PROPS"
cp --no-clobber "$FRESH_PROPS/sprites/prop_617_index.png" "$FRESH_ASSEMBLY/assets/lol2/generated/cave_scenic_guard/prop_617.png"
```

The fresh prop rows for placements 223 and 574, their selector fallback and indexed-image hash match the tracked `scripts/lol2/cave_scenic_guard_source.json`. Combining that image with the 109 shared sprite files reproduced the complete 110-file directory byte-for-byte. No historical prop capture is needed. The tracked scene configuration and separately prepared movies remain separate inputs.
