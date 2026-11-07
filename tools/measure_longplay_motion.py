#!/usr/bin/env python3
"""Measure a longplay ROI with NumPy phase correlation; no guessed world scale.

Frame timestamps = time_origin + (filename_index - first_index) * frame_step.
Use a stationary background box to remove camera translation, or explicitly assert
--camera-static. Camera rotation, depth parallax, cuts and occlusion can invalidate
this approximation. A sparse 30-second index is useful for finding a scene, not
for measuring mover timing. --depth + --vfov calibrates only image-plane motion;
camera height/FOV alone does not determine an arbitrary object's depth.
"""
import argparse, hashlib, json, math, re
from pathlib import Path
import numpy as np
from PIL import Image


def phase_shift(a, b):
    """Translation from a to b; confidence and overlap residual flag bad matches."""
    a=np.asarray(a,dtype=float); b=np.asarray(b,dtype=float)
    if a.shape!=b.shape or min(a.shape)<8: raise ValueError('matching boxes at least 8 pixels wide/high required')
    if a.std()<1e-5 or b.std()<1e-5: return dict(dx=0.,dy=0.,confidence=0.,residual=1.)
    window=np.outer(np.hanning(a.shape[0]),np.hanning(a.shape[1]))
    fa=np.fft.fft2((a-a.mean())*window); fb=np.fft.fft2((b-b.mean())*window)
    cross=fb*np.conj(fa); cross/=np.maximum(np.abs(cross),1e-12)
    corr=np.abs(np.fft.ifft2(cross)); y,x=np.unravel_index(np.argmax(corr),corr.shape)
    confidence=float(corr[y,x]/max(float(corr.mean()),1e-12))
    dx=int(x if x<=a.shape[1]//2 else x-a.shape[1]); dy=int(y if y<=a.shape[0]//2 else y-a.shape[0])
    x0=max(0,-dx); x1=min(a.shape[1],a.shape[1]-dx)
    y0=max(0,-dy); y1=min(a.shape[0],a.shape[0]-dy)
    aa=a[y0:y1,x0:x1];bb=b[y0+dy:y1+dy,x0+dx:x1+dx]
    residual=float(np.mean(np.abs((aa-aa.mean())-(bb-bb.mean())))) if aa.size else 1.
    return dict(dx=float(dx),dy=float(dy),confidence=confidence,residual=residual)


def crop(image,box):
    x,y,w,h=box
    if min(x,y)<0 or min(w,h)<8 or x+w>image.shape[1] or y+h>image.shape[0]: raise ValueError('box outside image or smaller than 8 pixels')
    return image[y:y+h,x:x+w]


def measure(samples,box,background=None,camera_static=False,max_interval=.5,min_speed=2.,depth=None,vfov=None):
    if depth is not None and (depth<=0 or vfov is None or not 0<vfov<180): raise ValueError('positive depth and vertical FOV in (0,180) required')
    if max_interval<=0 or min_speed<0: raise ValueError('invalid interval/speed threshold')
    pairs=[];last=None
    for time,path in samples:
        image=np.asarray(Image.open(path).convert('L'),dtype=float)/255.
        crop(image,box)
        if last is not None:
            old_time,old_path,old=last;dt=time-old_time
            if dt<=0: raise ValueError('frame timestamps must increase')
            if old.shape!=image.shape: raise ValueError('image size changed')
            motion=phase_shift(crop(old,box),crop(image,box));bg=phase_shift(crop(old,background),crop(image,background)) if background else None
            dx=motion['dx']-(bg['dx'] if bg else 0.);dy=motion['dy']-(bg['dy'] if bg else 0.)
            reasons=[]
            if dt>max_interval: reasons.append('sampling too sparse for mover timing')
            if not background and not camera_static: reasons.append('camera motion not controlled')
            for label,m in [('object',motion)]+([('background',bg)] if bg else []):
                if m['confidence']<8: reasons.append(label+' correlation ambiguous')
                if m['residual']>.20: reasons.append(label+' cut/occlusion/nontranslation residual')
            speed=math.hypot(dx,dy)/dt
            scale=None if depth is None else depth/(image.shape[0]/(2*math.tan(math.radians(vfov)/2)))
            pairs.append(dict(start=old_time,end=time,first=str(old_path),last=str(path),raw=motion,background=bg,
                compensated_dx=dx,compensated_dy=dy,pixels_per_second=speed,speed_quantization_pixels_per_second=1.0/dt,valid=not reasons,reasons=reasons,
                active=not reasons and speed>=min_speed,image_plane_units_per_second=None if scale is None or reasons else speed*scale))
        last=(time,path,image)
    active=[p for p in pairs if p['active']];valid=[p for p in pairs if p['valid']]
    # Separate episodes instead of treating the pause between two movements as motion.
    episodes=[]
    for p in pairs:
        if not p['active']: continue
        if episodes and episodes[-1]['end']==p['start']: episodes[-1]['end']=p['end'];episodes[-1]['last']=p['last']
        else: episodes.append(dict(start=p['start'],end=p['end'],first=p['first'],last=p['last']))
    return dict(method='NumPy phase correlation, integer-pixel ROI translation minus optional background translation',
        grade='MEASURED SCREEN MOTION; original object identity and world interpretation require independent evidence',
        displacement_resolution_pixels=1,automatic_adapter_replacement_allowed=False,
        frame_count=len(samples),valid_pairs=len(valid),active_pairs=len(active),episodes=episodes,
        median_pixels_per_second=float(np.median([p['pixels_per_second'] for p in active])) if active else None,
        median_image_plane_units_per_second=float(np.median([p['image_plane_units_per_second'] for p in active])) if active and depth is not None else None,
        calibration=dict(depth=depth,vertical_fov=vfov,scope='Image-plane translation only. Camera height/FOV alone is insufficient; rotation/parallax may defeat background subtraction.'),
        timing_uncertainty_seconds=max([p['end']-p['start'] for p in pairs],default=None),
        eligible_for_manual_calibration_review=bool(active),pairs=pairs)


def depth_from_ground(camera_height, ground_y, horizon_y, image_height, vfov):
    """Conditional calibration: level camera, flat ground, known object contact row."""
    if camera_height<=0 or ground_y<=horizon_y or not 0<vfov<180:
        raise ValueError("ground calibration needs positive height, a contact below the horizon, and valid vertical FOV")
    focal=image_height/(2*math.tan(math.radians(vfov)/2))
    return camera_height*focal/(ground_y-horizon_y)


def main():
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--frames',type=Path,required=True);p.add_argument('--pattern',default='*.jpg')
    p.add_argument('--time-origin',type=float,required=True);p.add_argument('--frame-step',type=float,required=True)
    p.add_argument('--first-index',type=int,default=1);p.add_argument('--window',nargs=2,type=float,required=True)
    p.add_argument('--box',nargs=4,type=int,required=True,metavar=('X','Y','WIDTH','HEIGHT'))
    p.add_argument('--background-box',nargs=4,type=int);p.add_argument('--camera-static',action='store_true')
    p.add_argument('--max-interval',type=float,default=.5);p.add_argument('--min-speed',type=float,default=2.)
    p.add_argument('--depth',type=float);p.add_argument('--vfov',type=float)
    p.add_argument('--camera-height',type=float);p.add_argument('--ground-y',type=float);p.add_argument('--horizon-y',type=float)
    p.add_argument('--level-camera',action='store_true',help='assert level camera and flat ground for ground-contact calibration')
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    if a.frame_step<=0 or a.window[0]>a.window[1]: p.error('positive frame step and ordered window required')
    samples=[]
    for path in a.frames.glob(a.pattern):
        match=re.search(r'(\d+)$',path.stem)
        if not match: continue
        t=a.time_origin+(int(match.group(1))-a.first_index)*a.frame_step
        if a.window[0]<=t<=a.window[1]: samples.append((t,path))
    samples.sort()
    if len(samples)<2: p.error('need at least two indexed frames in the window')
    depth=a.depth
    if a.camera_height is not None:
        if depth is not None or not a.level_camera or a.ground_y is None or a.horizon_y is None or a.vfov is None:
            p.error('ground calibration needs --level-camera, --ground-y, --horizon-y and --vfov, without --depth')
        with Image.open(samples[0][1]) as image: image_height=image.height
        depth=depth_from_ground(a.camera_height,a.ground_y,a.horizon_y,image_height,a.vfov)
    result=measure(samples,a.box,a.background_box,a.camera_static,a.max_interval,a.min_speed,depth,a.vfov)
    result['input']={k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()}
    result['frame_sha256']={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for _,path in samples}
    a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['frame_count','valid_pairs','active_pairs','episodes','median_pixels_per_second','median_image_plane_units_per_second','eligible_for_manual_calibration_review']}))
if __name__=='__main__':main()
