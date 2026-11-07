# Item icon preparation

The existing key-lock helper now exposes `definitions(game=...)` and `icon(definition, path, game=...)` with explicit original-game paths. Icon decoding uses the published local MIX, material and creature-row readers plus Pillow. It does not import the Hive research helper or native audit modules.

With `tools` on `PYTHONPATH`, an isolated extraction can use:

```python
from pathlib import Path
from prepare_museum_key_locks import definitions, icon

game = Path('/path/to/original/game')
out = Path('/path/to/fresh/item-icons')
if out.exists():
    raise FileExistsError(out)
blob, base, count, names = definitions(game=game)
assert names[107] == '105-Ivory chip'
icon(107, out / 'ivory.png', game=game)
```

The GLOBAL definitions payload is hash-pinned. Entry lookup requires exactly one matching entry, and item-definition bounds are checked. LOCAL graphics are decoded with the existing descriptor and sprite-row rules; this helper does not claim to hash-pin the whole LOCAL archive. Resource IDs, palette, transparency for indices 0/1 and PNG writer are unchanged. Use ordinary Python without `-O` so assertion-based source checks remain enabled.

Independent verification reproduced 14 current item icons byte for byte: Ivory Chip, skull key, SS1, Ancient Stone, Manafoil, Net of Exile, Reaver, Amber, Aloe, Ironwood sap, blood, Prism, Dampen and Long Arm. Three invalid-definition controls failed before output. The default-game icon and definitions also matched the explicit-path results. The import closure contains no RE checkout, Capstone or Unicorn modules.

Existing two-argument icon calls and no-argument definitions retain their historical defaults. The library icon writer still replaces its requested file; use a fresh extraction root as above. Full key-lock source/passage generation retains its research dependencies, now imported only when that entry point runs. This change does not make complete encounter packs portable, rerun their native audits or change gameplay.
