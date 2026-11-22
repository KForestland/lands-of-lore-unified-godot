#!/usr/bin/env python3
"""F-08 commit 0: pin item-related source sites, including copies and histories.

This is a census, not commit 9's live-pack ownership guard. Builders, loaders,
serializers and rule parameters are deliberately included and classified by the
reviewed fixture. Tokenize strings/comments separately; track local aliases;
record passing a pack to another function as well as direct mutations.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re

TOKEN = re.compile(r'''(?P<comment>\#[^\n]*)|(?P<string>"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27)|(?P<id>[A-Za-z_]\w*)|(?P<number>0x[0-9a-fA-F]+|\d+(?:\.\d+)?)|(?P<op>==|!=|<=|>=|:=|\+=|-=|\S)''')
FUNCTION = re.compile(r'^([ \t]*)(?:static\s+)?func\s+(\w+)\s*\(', re.M)
ROOTS = {'carried_collected', 'carried_inventory', 'inventory', 'carried',
         'collected', 'pack', 'bag', 'items', 'carried_items'}
MUTATORS = {'append', 'append_array', 'push_back', 'push_front', 'insert',
            'erase', 'remove_at', 'pop_at', 'pop_back', 'pop_front', 'resize', 'assign', 'clear',
            'set', 'set_deferred'}
ASSIGN = {'=', ':=', '+='}
KINDS = {'add', 'rule', 'transaction', 'builder', 'cave', 'reader', 'remove',
         'loader', 'serializer', 'validator'}


def tokens(source):
    return [(m.lastgroup, m[0]) for m in TOKEN.finditer(source) if m.lastgroup != 'comment']


def functions(source):
    matches=list(FUNCTION.finditer(source))
    out={}
    for index,match in enumerate(matches):
        indent=len(match[1].expandtabs(4))
        end=len(source)
        # A method ends at the next nonempty line outside its indentation, so
        # inner-class engine callbacks are included without swallowing a class.
        body_start=source.find('\n',match.start())
        if body_start<0:body_start=len(source)
        for line in re.finditer(r'(?m)^([^\n]*)',source[body_start+1:]):
            text=line[1]
            if not text.strip() or text.lstrip().startswith('#'):continue
            prefix=text[:len(text)-len(text.lstrip())]
            if len(prefix.expandtabs(4)) <= indent:
                end=body_start+1+line.start();break
        name=match[2]
        # Qualify inner classes from the lexical class declaration path.
        classes=[]
        for line in source[:match.start()].splitlines():
            c=re.match(r'^([ \t]*)class\s+(\w+)',line)
            if c:
                level=len(c[1].expandtabs(4))
                classes=[x for x in classes if x[0]<level]+[(level,c[2])]
        if indent:name='.'.join(c[1] for c in classes if c[0]<indent)+'.'+name
        if name in out:raise ValueError('ambiguous method: '+name)
        out[name]=source[match.start():end]
    return out


def statements(body):
    rows=[];current=[];depth=0;end=0
    for match in TOKEN.finditer(body):
        if match.lastgroup=='comment':continue
        if '\n' in body[end:match.start()] and depth==0 and current and current[-1][1]!='\\':
            rows.append(current);current=[]
        kind,value=match.lastgroup,match[0]
        if value==';' and kind=='op' and depth==0:
            if current:rows.append(current);current=[]
        else:
            current.append((kind,value))
            if kind=='op':
                if value in ('(','[','{'):depth+=1
                elif value in (')',']','}'):depth-=1
        end=match.end()
    if current:rows.append(current)
    return rows


def array_reference(expr, names):
    """A binding to an array, not a scalar computed from an array argument."""
    if not expr:return False
    if expr[0][1] in ('{','[') and expr[-1][1] in ('}',']'):
        # Containers can carry a live array to way-B rules. Inspect each value,
        # not dictionary key names, so {"collected": []} is not a live alias.
        depth=0;parts=[];part=[]
        for token in expr[1:-1]:
            kind,value=token
            if kind=='op' and value==',' and depth==0:
                parts.append(part);part=[];continue
            part.append(token)
            if kind=='op':
                if value in ('(','[','{'):depth+=1
                elif value in (')',']','}'):depth-=1
        if part:parts.append(part)
        for part in parts:
            if expr[0][1]=='{':
                depth=0
                for i,(kind,value) in enumerate(part):
                    if kind=='op' and value==':' and depth==0:part=part[i+1:];break
                    if kind=='op':
                        if value in ('(','[','{'):depth+=1
                        elif value in (')',']','}'):depth-=1
            if array_reference(part,names):return True
        return False
    if expr[-1][1] in names and expr[-1][0]=='id':
        # Bare local or final property; a comparison/read expression isn't a binding.
        return not any(v in ('in','not','and','or','==','!=','+','-','*','/') for _,v in expr)
    if expr[-1][1]==']' and len(expr)>=3 and expr[-2][0]=='string':
        return expr[-2][1].strip('"\'') in names
    if expr[-1][1]!=')':return False
    depth=1;opening=None
    for i in range(len(expr)-2,-1,-1):
        if expr[i][1]==')':depth+=1
        elif expr[i][1]=='(':depth-=1
        if depth==0:opening=i;break
    if opening is None:return False
    if opening==0:return array_reference(expr[1:-1],names)
    call=expr[opening-1][1]
    if call in ('carried','carried_items','pack'):return True
    if call=='get':return any(k=='string' and v.strip('"\'') in names for k,v in expr[opening+1:-1])
    if call in ('duplicate','filter','map') and opening>=2 and expr[opening-2][1]=='.':
        return array_reference(expr[:opening-2],names)
    return False


def operation_sites(body):
    aliases=set(ROOTS)
    live={'carried_collected','carried_inventory','carried_items'}
    # Unknown parameter names are potential container receivers, not evidence
    # that scalar results of calls using them are aliases.
    ts=tokens(body);parameters=set();depth=0;want_name=False
    for kind,value in ts[ts.index(('op','('))+1:]:
        if depth==0 and value==')':break
        if depth==0 and (want_name or not parameters) and kind=='id':
            parameters.add(value);want_name=False
        if kind=='op':
            if value in ('(','[','{'):depth+=1
            elif value in (')',']','}'):depth-=1
            elif value==',' and depth==0:want_name=True
    # Copies stay tainted here: the fixture distinguishes builders from live
    # writers. A renamed local must not make a known source site disappear.
    rows=statements(body)
    for _ in range(len(rows)+1):
        before=(set(aliases),set(live),set(parameters))
        for row in rows:
            assignments=[i for i,(k,v) in enumerate(row) if k=='op' and v in ASSIGN]
            for i in assignments:
                declarations=[j for j,(k,v) in enumerate(row[:i]) if v=='var']
                name=row[declarations[-1]+1][1] if declarations else (row[i-1][1] if i and row[i-1][0]=='id' and (i<2 or row[i-2][1]!='.') else '')
                rhs=row[i+1:]
                if name and array_reference(rhs,aliases):aliases.add(name)
                if name and array_reference(rhs,live):live.add(name)
                if name and array_reference(rhs,parameters):parameters.add(name)
        if (aliases,live,parameters)==before:break
    found=[]
    for row in rows:
        # Ignore comments, quoted code, declarations without mutations, and
        # comparisons. Keep literal values in real calls for get/set spellings.
        if not row:continue
        roots=any(k=='id' and v in aliases or k=='string' and v.strip('"\'') in ROOTS for k,v in row)
        if not roots and not any(k=='id' and v in parameters for k,v in row):continue
        def relevant(expr):
            return any(k=='id' and v in aliases or k=='string' and v.strip('"\'') in ROOTS for k,v in expr)
        mutation=False
        for i,(kind,value) in enumerate(row):
            if kind=='op' and value in ASSIGN:
                lhs=row[:i]
                if any(v=='var' for k,v in lhs):continue  # A local binding is not a pack write.
                colons=[j for j,(k,v) in enumerate(lhs) if v==':']
                if colons:lhs=lhs[colons[-1]+1:]
                mutation |= relevant(lhs)
            if kind=='id' and value in MUTATORS|{'call','call_deferred'} and i+1<len(row) and row[i+1][1]=='(' and (value in ('call','call_deferred') or i>0 and row[i-1][1]=='.'):
                receiver=row[:i-1] if i>0 and row[i-1][1]=='.' else []
                cuts=[j for j,(k,v) in enumerate(receiver) if v in ('=',':=',';',':')]
                if cuts:receiver=receiver[cuts[-1]+1:]
                if value in MUTATORS:mutation |= relevant(receiver) or any(k=='id' and v in parameters for k,v in receiver)
                if value in ('call','call_deferred'):
                    target=row[i+2][1].strip('"\'') if i+2<len(row) and row[i+2][0]=='string' else ''
                    # A dynamic method on a container may be a writer.
                    if not target or target in MUTATORS:mutation |= relevant(receiver) or any(k=='id' and v in parameters for k,v in receiver)
                    if target in ('set','set_deferred'):mutation |= any(k=='string' and v.strip('"\'') in ROOTS for k,v in row[i+3:])
                if value in ('set','set_deferred'):
                    mutation |= any(k=='string' and v.strip('"\'') in ROOTS for k,v in row[i+2:])
        # Passing a live store/alias must stay visible even if the callee's
        # parameter has an unrelated name. Read calls are explicitly classified.
        passing=False
        for i,(kind,value) in enumerate(row):
            if kind!='op' or value!='(' or i==0 or row[i-1][0]!='id' or row[i-1][1] in ('get','has','has_method','if','and','or','not','while','return','match'):continue
            if i>=2 and row[i-2][1]=='func':continue
            depth=1
            for j,(k,v) in enumerate(row[i+1:],i+1):
                if k=='op' and v=='(':depth+=1
                if k=='op' and v==')':depth-=1
                if depth==0:break
                if k=='id' and (v in live or v=='carried' and j+1<len(row) and row[j+1][1]=='('):passing=True
        if mutation or passing:
            # A normalized token spelling is independent of whitespace/lines.
            found.append(' '.join(v for _,v in row))
    return sorted(found)


def scan(root):
    all_functions={};actual={}
    for path in sorted((root/'scripts/lol2').rglob('*.gd')):
        name=path.relative_to(root).as_posix()
        for function,body in functions(path.read_text()).items():
            key=name+'::'+function
            all_functions[key]=body
            sites=operation_sites(body)
            if sites:actual[key]=sites
    return actual,all_functions


def references_module(source, module):
    ts=tokens(source);name=Path(module).name
    def value(text):
        try:return ast.literal_eval(text)
        except (ValueError,SyntaxError):return text.strip('"\'')
    for i,(kind,text) in enumerate(ts):
        if kind!='string':continue
        combined=value(text)
        if name in combined:return True
        j=i+1
        while j+1<len(ts) and ts[j]==('op','+') and ts[j+1][0]=='string':
            combined+=value(ts[j+1][1])
            if name in combined:return True
            j+=2
    return False


def check(root, fixture):
    actual,all_functions=scan(root)
    expected={}
    failures=[]
    for row in fixture['functions']:
        key=row['file']+'::'+row['function']
        if key in expected:failures.append('duplicate fixture row '+key)
        if row['kind'] not in KINDS:failures.append('unknown kind '+key)
        if key not in all_functions:failures.append('missing function '+key)
        if row.get('semantic_sha256') and key in all_functions:
            digest=hashlib.sha256(json.dumps(tokens(all_functions[key]),separators=(',',':')).encode()).hexdigest()
            if digest!=row['semantic_sha256']:failures.append('pinned derived/reader function changed '+key)
        if row.get('sites'):expected[key]=sorted(row['sites'])
        if row.get('history'):
            h=row['history']
            if h.get('guard') not in ('always','once') or not h.get('packet'):failures.append('history spelling missing '+key)
    for key in sorted(set(actual)|set(expected)):
        if actual.get(key)!=expected.get(key):failures.append('source sites changed '+key)
    if sum('history' in r for r in fixture['functions'])!=24:failures.append('all 24 history spellings are required')
    by_key={r['file']+'::'+r['function']:r for r in fixture['functions']}
    for key in fixture['must_remain_builders']:
        if by_key.get(key,{}).get('kind')!='builder':failures.append('pure builder misclassified '+key)
    goldens=fixture['existing_goldens']
    path=root/goldens['manifest']
    if hashlib.sha256(path.read_bytes()).hexdigest()!=goldens['sha256']:failures.append('golden save manifest changed')
    for area,row in json.loads(path.read_text())['areas'].items():
        if hashlib.sha256((path.parent/(area+'.json')).read_bytes()).hexdigest()!=row['sha256']:failures.append('golden save bytes changed '+area)
    for row in goldens.get('extra_files',[]):
        path=root/row['path']
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:
            failures.append('additional golden save bytes changed '+row['path'])
    baselines=fixture.get('runtime_baselines',{})
    if not baselines.get('files'):failures.append('runtime baseline fixture inventory missing')
    for row in baselines.get('files',[]):
        path=root/row['path']
        if not path.is_file():failures.append('runtime baseline missing '+row['path'])
        elif hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:failures.append('runtime baseline changed '+row['path'])
    if fixture.get('module_path',fixture.get('unused_module')):
        module=fixture.get('module_path',fixture.get('unused_module'))
        admitted=set(fixture.get('allowed_module_users',[]))
        seen=set()
        for directory in ('scripts','scenes'):
            for path in (root/directory).rglob('*'):
                if path.suffix not in ('.gd','.tscn','.tres') or path.relative_to(root).as_posix()==module:continue
                # Include relative paths, scenes and constant string fragments.
                if references_module(path.read_text(),module):
                    relative=path.relative_to(root).as_posix()
                    seen.add(relative)
                    if relative not in admitted:failures.append('unlisted production module user '+relative)
        for missing in sorted(admitted-seen):failures.append('pinned production module user missing '+missing)
    return failures


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--fixture',type=Path)
    args=parser.parse_args()
    path=args.fixture or args.root/'tests/fixtures/item_grant_census_742dcab.json'
    fixture=json.loads(path.read_text())
    failures=check(args.root,fixture)
    for failure in failures:print('FAIL item grant census: '+failure)
    if not failures:print('PASS item grant census: %d classified functions; complete production scan, aliases/copies/history included'%len(fixture['functions']))
    return bool(failures)


if __name__=='__main__':raise SystemExit(main())
