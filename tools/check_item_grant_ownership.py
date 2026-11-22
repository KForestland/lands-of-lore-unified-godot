#!/usr/bin/env python3
"""F08 live-store ownership guard. Copies and serializers are not live stores.

Census pins remain separate: this guard follows live local aliases, API preload
names and pack arguments; erase-only owners are reported until optional I01.
"""
import argparse,ast,hashlib,importlib.util,json,re,warnings
from pathlib import Path
spec=importlib.util.spec_from_file_location('census',Path(__file__).with_name('check_item_grant_census.py'))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
ADD={'append','append_array','push_back','push_front','insert','assign','clear','resize','set','set_deferred'}
REMOVE={'erase','remove_at','pop_at','pop_back','pop_front'}
READ={'size','is_empty','has','find','rfind','count','duplicate','slice','filter','map','all','any','hash','pick_random','front','back','get','keys','values'}
ROOTS={'carried_collected':'array','carried_inventory':'dict'}
OPEN={'(':')','[':']','{':'}'}
def pairs(ts):
 stack=[];out={}
 for i,v in enumerate(ts):
  if v in OPEN:stack.append(i)
  elif v in OPEN.values() and stack:
   start=stack.pop();out[start]=i;out[i]=start
 return out

def split(ts,sep=','):
 out=[];part=[];depth=0
 for v in ts:
  if v==sep and depth==0:out.append(part);part=[];continue
  part.append(v)
  if v in OPEN:depth+=1
  elif v in OPEN.values():depth-=1
 out.append(part);return out

def literal(ts):
 try:
  value=''.join(v for v in ts if v!='&')
  with warnings.catch_warnings():
   warnings.simplefilter('ignore',SyntaxWarning)
   return ast.literal_eval(value) if len(value)>1 and value[0] in ['\"',"'"] else None
 except (ValueError,SyntaxError):return None

def chain_start(ts,end):
 """Start of a property/call chain ending immediately before end."""
 if end<=0:return end
 match=pairs(ts);i=end-1
 if ts[i] in [')',']'] and i in match:
  i=match[i]
  if ts[i]=='(' and i>0 and re.fullmatch(r'[A-Za-z_]\w*',ts[i-1]):i-=1
  elif ts[i]=='[' and i>0:i=chain_start(ts,i)
 elif not re.fullmatch(r'[A-Za-z_]\w*',ts[i]):return end
 while i>=2 and ts[i-1]=='.':i=chain_start(ts,i-1)
 return i

def state(ts,aliases,modules):
 if not ts:return ''
 # Ignore casts/type annotations, not get(...)/StringName strings.
 if 'as' in ts:ts=ts[:ts.index('as')]
 match=pairs(ts)
 while ts and ts[0]=='(' and match.get(0)==len(ts)-1:
  ts=ts[1:-1];match=pairs(ts)
 if not ts:return ''
 depth=0
 for token in ts:
  if depth==0 and token in ['in','not','and','or','==','!=','+','-','if','else','return']:return ''
  if token in OPEN:depth+=1
  elif token in OPEN.values():depth-=1
 if len(ts)==1:return ROOTS.get(ts[0],aliases.get(ts[0],''))
 if ts[0] in ['{','['] and match.get(0)==len(ts)-1:
  for part in split(ts[1:-1]):
   if ts[0]=='{':
    bits=split(part,':');part=bits[-1]
   if state(part,aliases,modules):return 'wrapper'
  return ''
 # A property at the end. A shallow dictionary copy shares its array only.
 if len(ts)>=3 and ts[-2]=='.':
  base=state(ts[:-2],aliases,modules);field=ts[-1]
  if field in ROOTS:return ROOTS[field]
  if field=='collected' and base in ['dict','shallow']:return 'array'
  return ''
 if ts[-1]==']' and len(ts)-1 in match:
  opening=match[len(ts)-1];field=literal(ts[opening+1:-1]);base=state(ts[:opening],aliases,modules)
  if field in ROOTS:return ROOTS[field]
  if field=='collected' and base in ['dict','shallow']:return 'array'
  if base=='array':return 'element'
  return ''
 if ts[-1]!=')' or len(ts)-1 not in match:return ''
 opening=match[len(ts)-1]
 if opening<1:return ''
 method=ts[opening-1];prefix=ts[:opening-1];args=split(ts[opening+1:-1]);receiver=prefix[:-1] if prefix and prefix[-1]=='.' else []
 if method=='get':
  field=literal(args[0]);base=state(receiver,aliases,modules)
  if field in ROOTS:return ROOTS[field]
  if field=='collected' and base in ['dict','shallow']:return 'array'
 if method=='carried':return 'array'
 if method=='pack' and ((len(receiver)==1 and modules.get(receiver[0],'').endswith('/item_grants.gd')) or (not receiver and modules.get('_self','').endswith('/item_grants.gd'))):return 'array'
 if method=='duplicate':
  base=state(receiver,aliases,modules)
  return 'shallow' if base in ['dict','shallow'] and (not args[0] or args[0]!=['true']) else ''
 return ''

def preload_modules(source):
 return {m[1]:m[2].removeprefix('res://') for m in re.finditer(r'(?:const|var)\s+(\w+)\s*(?::\s*\w+)?\s*(?::=|=)\s*(?:preload|load)\(\s*["\'](res://[^"\']+)["\']\s*\)',source)}

def resolve_callee(file,method,receiver,modules):
 if not receiver:return file+'::'+method
 if len(receiver)==1 and receiver[0] in modules:return modules[receiver[0]]+'::'+method
 if len(receiver)==4 and receiver[0] in ['preload','load'] and receiver[1]=='(' and receiver[3]==')':
  path=literal(receiver[2:3])
  if isinstance(path,str) and path.startswith('res://'):return path.removeprefix('res://')+'::'+method
 if len(receiver)>=3 and receiver[0] in modules:
  path=modules[receiver[0]]
  for part in receiver[1:]:
   if part=='.':continue
   target=Path(modules['_root'])/path
   path=preload_modules(target.read_text()).get(part,'') if target.is_file() else ''
  if path:return path+'::'+method
 return ''.join(receiver)+'::'+method

def inspect_function(file,name,body,modules):
 aliases={};found=[]
 for raw in c.statements(body):
  ts=[v for _,v in raw];match=pairs(ts)
  # Alias bindings follow source order, including reassignment to a fresh copy.
  for i,v in enumerate(ts):
   if v not in ['=',':='] or any(start<i<end for start,end in match.items() if start<end):continue
   start=chain_start(ts,i)
   if 'var' in ts[:i]:
    var=ts.index('var');local=ts[var+1];aliases[local]=state(ts[i+1:],aliases,modules)
   elif i and re.fullmatch(r'\w+',ts[i-1]) and (i<2 or ts[i-2]!='.'):
    aliases[ts[i-1]]=state(ts[i+1:],aliases,modules)
   lhs=ts[start:i]
   shallow_field = len(lhs)>2 and lhs[-2:]==['.','collected'] and state(lhs[:-2],aliases,modules)=='shallow'
   if 'var' not in ts[:i] and not shallow_field and state(lhs,aliases,modules) in ['array','dict','element']:
    found.append({'kind':'write','callee':'=','source':' '.join(ts)})
  # += writes are never local bindings.
  for i,v in enumerate(ts):
   if v=='+=' and state(ts[chain_start(ts,i):i],aliases,modules) in ['array','dict']:found.append({'kind':'write','callee':'+=','source':' '.join(ts)})
  for i,v in enumerate(ts):
   if v!='(' or i<1 or not re.fullmatch(r'[A-Za-z_]\w*',ts[i-1]) or i not in match or ts[i-1] in ['if','not','and','or','while','match','return']:continue
   method=ts[i-1]
   if i>=2 and ts[i-2]=='func':continue
   receiver=ts[chain_start(ts,i-2):i-2] if i>=2 and ts[i-2]=='.' else []
   target=state(receiver,aliases,modules)
   args=split(ts[i+1:match[i]])
   if target in ['array','dict'] and method in ADD|REMOVE:
    found.append({'kind':'remove' if method in REMOVE else 'write','callee':method,'source':' '.join(ts)})
   if method in ['set','set_deferred'] and args and literal(args[0]) in ROOTS:
    found.append({'kind':'write','callee':method,'source':' '.join(ts)})
   if any(state(arg,aliases,modules) for arg in args):
    callee=resolve_callee(file,method,receiver,modules)
    found.append({'kind':'argument','callee':callee,'source':' '.join(ts)})
 return found

def scan(root):
 result={}
 for path in sorted((root/'scripts/lol2').rglob('*.gd')):
  source=path.read_text();file=path.relative_to(root).as_posix();modules=preload_modules(source);modules['_self']=file;modules['_root']=str(root)
  for name,body in c.functions(source).items():
   found=inspect_function(file,name,body,modules)
   if found:result[file+'::'+name]=found
 return result

def check(root,policy,enforce_removals=False):
 found=scan(root);failures=[];removals=[]
 writers=set(policy['allowed_writers']);callees=set(policy['allowed_callees'])
 for key,sites in found.items():
  for site in sites:
   if key in writers:continue
   if site['kind']=='remove' and not enforce_removals:removals.append((key,site));continue
   if site['kind']=='argument' and (site['callee'] in callees or {'caller':key,**site} in policy.get('allowed_dynamic_calls',[])):continue
   failures.append((key,site))
 bodies={p.relative_to(root).as_posix()+'::'+n:b for p in (root/'scripts/lol2').rglob('*.gd') for n,b in c.functions(p.read_text()).items()};all_keys=set(bodies)
 for key,digest in policy.get('callee_semantic_sha256',{}).items():
  if key not in bodies or hashlib.sha256(json.dumps(c.tokens(bodies[key]),separators=(',',':')).encode()).hexdigest()!=digest:failures.append((key,{'kind':'audited callee changed'}))
 for key in policy['must_remain_clean']:
  # Parameter/local builders have no live roots. History normalizers can read
  # live inventory but may only pass it to an explicitly audited read/rule.
  if key not in all_keys:failures.append((key,{'kind':'missing must-stay-clean function'}))
  for site in found.get(key,[]):
   if site['kind']=='write':failures.append((key,site))
 return failures,removals,found

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--policy',type=Path);p.add_argument('--enforce-removals',action='store_true');a=p.parse_args()
 policy=json.loads((a.policy or a.root/'tools/item_grant_ownership_policy.json').read_text());failures,removals,found=check(a.root,policy,a.enforce_removals)
 for key,site in failures:print('FAIL live-pack ownership:',key,site)
 for key,site in removals:print('DEFER I01 removal:',key,site['callee'])
 if not failures:print('PASS live-pack ownership: %d functions with live references; %d removal source sites disclosed'%(len(found),len(removals)))
 return bool(failures)
if __name__=='__main__':raise SystemExit(main())
