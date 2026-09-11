import unittest
from interior_spans import exposed
class ExposureTests(unittest.TestCase):
 def test_identical_opening(self):
  self.assertEqual(exposed(((0,0),(10,10)),((0,0),(10,10))),[])
 def test_opening_not_filled(self):
  spans=exposed(((0,0),(10,10)),((2,2),(8,8)))
  self.assertEqual([(p['low'],p['high']) for p in spans],[([0.,0.],[2.,2.]),([8.,8.],[10.,10.])])
 def test_crossing_slopes_and_disjoint_ranges(self):
  for a,b in [(((0,4),(10,12)),((4,0),(8,14))),(((0,0),(10,10)),((12,12),(20,20))),(((0,0),(10,10)),((-20,-20),(-5,-5)))]:
   spans=exposed(a,b)
   for t in [.13,.37,.63,.87]:
    lerp=lambda line:line[0]+(line[1]-line[0])*t
    for z in [i*.25-.125 for i in range(-80,100)]:
     expected=lerp(a[0])<z<lerp(a[1]) and not lerp(b[0])<=z<=lerp(b[1])
     found=False
     for p in spans:
      l,r=p['t']
      if l<t<r:
       u=(t-l)/(r-l);low=p['low'][0]*(1-u)+p['low'][1]*u;high=p['high'][0]*(1-u)+p['high'][1]*u;found |= low<z<high
     self.assertEqual(found,expected,(t,z,a,b))
if __name__=='__main__':unittest.main()
