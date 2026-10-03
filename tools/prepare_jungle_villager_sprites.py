#!/usr/bin/env python3
"""Stage L4_HJ Huline villager frames (TIG_ROG/MAL/FEM/CUB, definitions0-3) via the shared preparer."""
import hashlib
from pathlib import Path
from prepare_museum_creature_sprites import stage,ROOT
TEXTURE=Path('/home/bob/lol2_out/jungle_geometry_20260914/texture.bin')
def main():
    stage('DAT/L4_HJ.MIX',TEXTURE.read_bytes(),[0,1,2,3],ROOT/'assets/lol2/generated/jungle_villager_sprites')
if __name__=='__main__':main()
