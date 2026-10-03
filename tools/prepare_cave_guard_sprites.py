#!/usr/bin/env python3
"""Stage L1_DC GGCAPT (definition0) and GGUARD (definitions1/2) frames via the shared creature preparer."""
from pathlib import Path
from prepare_museum_creature_sprites import stage,ROOT
from lol2_cache_named_wall_fixture import load_named
from lol2_extract_cave_materials import ASSET,HASH
import hashlib
GAME=Path('/home/bob/lol2_out/museum_capture_20260913/game')
def main():
    _,blob,_,_=load_named(GAME,ASSET);assert hashlib.sha256(blob).hexdigest()==HASH
    stage('DAT/L1_DC.MIX',blob,[0,1,2],ROOT/'assets/lol2/generated/cave_guard_sprites')
if __name__=='__main__':main()
