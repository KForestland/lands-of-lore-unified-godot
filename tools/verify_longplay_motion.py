#!/usr/bin/env python3
"""Deterministic measurement checks, invoked by the registered headless test."""
import tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from measure_longplay_motion import phase_shift, measure, depth_from_ground

def main():
    assert abs(depth_from_ground(50,96,64,128,90)-100)<1e-6
    rng=np.random.default_rng(311026)
    a=rng.random((96,96));b=np.roll(a,(3,6),(0,1));r=phase_shift(a,b)
    assert r['dx']==6 and r['dy']==3 and r['residual']<1e-8,r
    assert phase_shift(np.zeros((32,32)),np.zeros((32,32)))['confidence']==0
    with tempfile.TemporaryDirectory() as folder:
        root=Path(folder);samples=[];left=rng.integers(0,256,(96,96),dtype=np.uint8);right=rng.integers(0,256,(96,96),dtype=np.uint8)
        for i in range(5):
            image=np.zeros((128,256),dtype=np.uint8)
            image[16:112,8:104]=np.roll(left,i*2,axis=1)
            image[16:112,144:240]=np.roll(right,i*6,axis=1)
            path=root/f'f_{i:03}.png';Image.fromarray(image).save(path);samples.append((i*.25,path))
        m=measure(samples,[152,24,80,80],[16,24,80,80],depth=100,vfov=90)
        assert m['valid_pairs']==4 and m['active_pairs']==4,m
        assert abs(m['median_pixels_per_second']-16)<1e-6,m
        assert abs(m['median_image_plane_units_per_second']-25)<1e-6,m
        assert len(m['episodes'])==1 and m['episodes'][0]['start']==0 and m['episodes'][0]['end']==1,m
        sparse=measure([(i*30,p) for i,(_,p) in enumerate(samples)],[152,24,80,80],camera_static=True)
        assert sparse['valid_pairs']==0 and sparse['median_pixels_per_second'] is None
        uncontrolled=measure(samples,[152,24,80,80]);assert uncontrolled['valid_pairs']==0
        unscaled=measure(samples,[152,24,80,80],[16,24,80,80]);assert unscaled['median_image_plane_units_per_second'] is None
        paused=[]
        for i,shift in enumerate([0,2,4,4,4,6,8]):
            image=np.roll(left,shift,axis=1);path=root/f'pause_{i:03}.png';Image.fromarray(image).save(path);paused.append((i*.25,path))
        episodes=measure(paused,[8,8,80,80],camera_static=True)['episodes']
        assert [(e['start'],e['end']) for e in episodes]==[(0.,.5),(1.,1.5)],episodes
        cut=root/'cut.png';Image.fromarray(rng.integers(0,256,(96,96),dtype=np.uint8)).save(cut)
        rejected=measure([(0.,paused[0][1]),(.25,cut)],[8,8,80,80],camera_static=True)
        assert rejected['valid_pairs']==0,rejected
        try:measure(samples,[250,0,80,80])
        except ValueError:pass
        else:raise AssertionError('out-of-frame box admitted')
    print('PASS longplay motion: known translation, camera compensation, exact temporal bounds, calibrated scale, sparse/uncontrolled refusal, unscaled null, separate episodes, cut refusal and invalid box')
if __name__=='__main__':main()
