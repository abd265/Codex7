#!/usr/bin/env python3
"""Independent all-pieces-exit challenge candidate lab; construction proofs, never shortest claims."""
from __future__ import annotations
import argparse, json, random, time, sys
from itertools import combinations
from pathlib import Path
from collections import deque
sys.path.insert(0,str(Path(__file__).resolve().parent))
import audit_campaign as audit
W,H=6,8
DIR=((0,-1),(1,0),(0,1),(-1,0))
COLORS=('coral','amber','mint','sky','violet','rose')
DNAMES=('up','right','down','left')
SHAPES=(((0,0),(0,1)),((0,0),(1,0)),((0,0),(0,1),(1,1)),((0,0),(1,0),(0,1),(1,1)),((0,0),(0,1),(0,2)),((0,0),(1,0),(1,1)),((0,0),(0,1),(0,2),(1,2)),((0,0),(1,0),(1,1),(1,2)),((0,0),(1,0),(0,1),(1,1)))
class Kernel:
 def __init__(self,pieces,gates,blocked):
  self.pieces=pieces;self.gates=gates;self.blocked=blocked;self.wall=sum(1<<(x+y*W) for x,y in blocked);self.masks=[];self.edge=[];self.steps=[]
  for p in pieces:
   masks={};edges={};steps={}
   for y in range(H):
    for x in range(W):
     cells=[(x+a,y+b) for a,b in p.cells]
     if any(a<0 or a>=W or b<0 or b>=H for a,b in cells):continue
     mask=sum(1<<(a+b*W) for a,b in cells)
     if mask&self.wall:continue
     pos=x+y*W;masks[pos]=mask
   for pos,mask in masks.items():
    x,y=pos%W,pos//W
    for d,(dx,dy) in enumerate(DIR):
     dest=[]
     for n in range(1,9):
      nx,ny=x+dx*n,y+dy*n;np=nx+ny*W
      if not(0<=nx<W and 0<=ny<H) or np not in masks:break
      dest.append((np,masks[np],n))
     steps[pos,d]=dest
     cells=[(x+a,y+b) for a,b in p.cells]
     nextcells=[(a+dx,b+dy) for a,b in cells]
     if all(0<=a<W and 0<=b<H for a,b in nextcells):continue
     trans=[a if d%2==0 else b for a,b in cells]
     if not any(g.color==p.color and g.side==d and g.start<=min(trans) and max(trans)<g.start+g.span for g in gates):continue
     sweep=0
     for n in range(1,14):
      moved=[(a+dx*n,b+dy*n) for a,b in cells]
      inside=[(a,b) for a,b in moved if 0<=a<W and 0<=b<H]
      sweep|=sum(1<<(a+b*W) for a,b in inside)
      if not inside:break
     if not sweep&self.wall:edges[pos,d]=sweep
   self.masks.append(masks);self.edge.append(edges);self.steps.append(steps)
 def occ(self,state):
  v=self.wall
  for i,p in enumerate(state):
   if p>=0:v|=self.masks[i][p]
  return v
 def actions(self,state,exit=True):
  occ=self.occ(state)
  for i,pos in enumerate(state):
   if pos<0:continue
   other=occ^self.masks[i][pos]
   for d in range(4):
    at=pos;distance=0
    for np,mask,n in self.steps[i][pos,d]:
     if mask&other:break
     at=np;distance=n
     s=list(state);s[i]=np;yield tuple(s),(self.pieces[i].id,d,n)
    if exit and (at,d) in self.edge[i] and not self.edge[i][at,d]&other:
     s=list(state);s[i]=-1;yield tuple(s),(self.pieces[i].id,d,distance+1)
 def single_exit_path(self,state,index):
  pos=state[index];other=self.occ(state)^self.masks[index][pos];q=deque([(pos,[])]);seen={pos}
  while q:
   at,path=q.popleft()
   for d in range(4):
    end=at;distance=0
    for np,mask,n in self.steps[index][at,d]:
     if mask&other:break
     end=np;distance=n
     if np not in seen:seen.add(np);q.append((np,path+[(self.pieces[index].id,d,n)]))
    if (end,d) in self.edge[index] and not self.edge[index][end,d]&other:
     return path+[(self.pieces[index].id,d,distance+1)]
  return None
 def removable(self,state):return [i for i,p in enumerate(state) if p>=0 and self.single_exit_path(state,i)]
 def first_exit(self,state,budget=20000):
  q=deque([(state,[])]);seen={state}
  while q:
   s,path=q.popleft()
   for ns,a in self.actions(s):
    if ns.count(-1)>state.count(-1):return path+[a],len(seen)
    if ns not in seen:
     seen.add(ns);q.append((ns,path+[a]))
     if len(seen)>=budget:return None,len(seen)
  return None,len(seen)

def placements(shape,gate):
 width=max(x for x,y in shape)+1;height=max(y for x,y in shape)+1
 for align in range(gate.start,gate.start+gate.span-(width if gate.side%2==0 else height)+1):
  yield ((align,0),(W-width,align),(align,H-height),(0,align))[gate.side]

def proof_shortcut(pieces,gates,blocked,proof):
 state=list(pieces);states=[tuple((p.id,p.x,p.y) for p in state)];seen={states[0]:0};actions=[]
 for action in reversed(proof):
  if not any(p.id==action[0] for p in state):continue
  ns,result=audit.move(state,gates,blocked,action)
  if result=='blocked':continue
  state=ns;key=tuple((p.id,p.x,p.y) for p in state)
  if key in seen:
   idx=seen[key]
   for k in states[idx+1:]:seen.pop(k,None)
   states=states[:idx+1];actions=actions[:idx]
  else:
   actions.append(action);seen[key]=len(states);states.append(key)
 assert not state
 # Merge consecutive moves of the same piece and direction.
 result=[]
 for a in actions:
  if result and result[-1][:2]==a[:2]:result[-1]=(a[0],a[1],result[-1][2]+a[2])
  else:result.append(a)
 return result

def expert_geometry(seed):
 rng=random.Random(seed^0xC0FFEE)
 # Nonoverlapping two-cell gates, sampled from all four shores.
 slots=[(d,start) for d in range(4) for start in range(0,W if d%2==0 else H,2)]
 if seed>=2600:
  sides=((0,0,2,2,1,3),(0,2,1,1,3,3),(0,0,2,1,1,3),(0,2,2,1,3,3))[seed%4];chosen=[]
  for side in range(4):
   starts=rng.sample(list(range(0,W if side%2==0 else H,2)),sides.count(side));chosen.extend((side,start) for start in starts)
  rng.shuffle(chosen)
 else:chosen=rng.sample(slots,6)
 gates=[audit.Gate(color,d,start,2) for color,(d,start) in enumerate(chosen)]
 clusters=(((0,0),(0,1)),((0,0),(1,0)),((0,0),(1,0),(0,1)),((0,0),(1,0),(1,1)),((0,0),(0,1),(0,2)),((0,0),(1,0),(2,0)))
 wall=set()
 for _ in range(2+seed%2):
  cluster=rng.choice(clusters);x=rng.randrange(1,4);y=rng.randrange(2,5)
  wall.update((x+a,y+b) for a,b in cluster if x+a<5 and y+b<6)
 if seed>=2600:
  shape=(((0,0),(1,0),(0,1),(1,1)),((0,0),(1,0),(1,1)),((0,0),(0,1),(1,1)),((0,0),(0,1),(1,2),(1,3)),((0,0),(1,0)),((0,0),(0,1)))[seed%6]
  x=rng.choice((1,2,3));y=rng.choice((2,3,4));wall={(x+a,y+b) for a,b in shape if x+a<5 and y+b<7}
 return gates,tuple(sorted(wall))

EXPERT_SHAPES=(((0,0),(0,1),(0,2),(1,2)),((0,0),(1,0),(1,1),(1,2)),((0,0),(0,1),(1,1),(1,2)),((1,0),(0,1),(1,1),(0,2)),((0,0),(0,1),(1,1),(0,2)),((0,0),(1,0),(0,1),(1,1)),((0,0),(1,0),(0,1),(1,1)),((0,0),(0,1),(0,2)),((0,0),(0,1)),((0,0),(0,1),(1,1)))

def create(seed,target=10,expert=False):
 rng=random.Random(seed);layout=seed%3
 gates=[audit.Gate(*x) for x in audit.GATES[layout]]
 walls=[((2,2),(3,2),(2,5),(3,5)),((2,3),(3,3),(2,4),(3,4)),((1,3),(2,3),(3,4),(4,4)),((2,2),(2,3),(3,4),(3,5)),((2,3),(3,3)),((2,2),(3,5))][seed%6]
 if expert:gates,walls=expert_geometry(seed)
 pieces=[];state=();proof=[];kernel=None
 for identity in range(1,target+1):
  added=False
  for attempt in range(120):
   g=rng.choice(gates);raw=rng.choice(EXPERT_SHAPES if expert else SHAPES)
   if expert and g.side%2:raw=tuple((y,x) for x,y in raw)
   for x,y in placements(raw,g):
    p=audit.Piece(identity,g.color,raw,x,y);k=Kernel(pieces+[p],gates,walls)
    pos=x+y*W
    if pos not in k.masks[-1] or k.masks[-1][pos]&k.occ(state):continue
    if (pos,g.side) not in k.edge[-1] or k.edge[-1][pos,g.side]&k.occ(state):continue
    pieces.append(p);state=state+(pos,);kernel=k;proof.append((identity,g.side,1));added=True;break
   if added:break
   if kernel:
    choices=list(kernel.actions(state,exit=False))
    if choices:
     state,a=rng.choice(choices);proof.append((a[0],(a[1]+2)%4,a[2]))
  if not added:break
  for _ in range(35):
   choices=list(kernel.actions(state,exit=False))
   if not choices:break
   state,a=rng.choice(choices);proof.append((a[0],(a[1]+2)%4,a[2]))
 if len(pieces)<8:return None
 best=None;recent=deque(maxlen=100);recent.append(state)
 for tick in range(1600):
  choices=list(kernel.actions(state,exit=False))
  if not choices:break
  unseen=[c for c in choices if c[0] not in recent]
  state,a=rng.choice(unseen or choices);recent.append(state);proof.append((a[0],(a[1]+2)%4,a[2]))
  if tick%30!=0:continue
  if kernel.removable(state):continue
  path,visited=kernel.first_exit(state,12000)
  depth=len(path) if path else 99
  score=depth*100+len(pieces)
  if best is None or score>best[0]:best=(score,state,proof[:],depth,visited)
  if depth>=8:break
 if best is None:return None
 _,state,proof,depth,visited=best
 final=[audit.Piece(p.id,p.color,p.cells,pos%W,pos//W) for p,pos in zip(pieces,state)]
 solution=proof_shortcut(final,gates,walls,proof)
 audit.validate((final,gates,walls,solution))
 return {'seed':seed,'firstExitGestures':None if depth==99 else depth,'firstExitStates':visited,'individualRemovable':0,'proofMoves':len(solution),'densityCells':sum(len(p.cells) for p in final),'columns':W,'rows':H,'pieces':[{'id':p.id,'color':COLORS[p.color],'cells':[{'x':x,'y':y} for x,y in p.cells],'origin':{'x':p.x,'y':p.y}} for p in final],'gates':[{'color':COLORS[g.color],'side':DNAMES[g.side],'start':g.start,'span':g.span} for g in gates],'blocked':[{'x':x,'y':y} for x,y in walls],'solution':[{'pieceID':p,'direction':DNAMES[d],'steps':n} for p,d,n in solution]}

def minimum_actors(kernel,state,max_size=3,per_subset_budget=50000):
 active=[i for i,p in enumerate(state) if p>=0];tested=0
 for size in range(1,max_size+1):
  for subset in combinations(active,size):
   identities={kernel.pieces[i].id for i in subset};seen={state};q=deque([state]);aborted=False
   while q:
    s=q.popleft()
    for ns,a in kernel.actions(s):
     if a[0] not in identities:continue
     if ns.count(-1)>state.count(-1):return {'minimumActors':size,'actorIDs':sorted(identities),'states':tested+len(seen),'exhaustive':True}
     if ns not in seen:
      seen.add(ns);q.append(ns)
      if len(seen)>per_subset_budget:aborted=True;break
    if aborted:break
   tested+=len(seen)
   if aborted:return {'minimumActors':None,'provenLowerBound':size,'states':tested,'exhaustive':False}
 return {'minimumActors':None,'provenLowerBound':max_size+1,'states':tested,'exhaustive':True}

def analyze_candidate(data,budget=150000):
 pieces=[audit.Piece(p['id'],COLORS.index(p['color']),tuple((c['x'],c['y']) for c in p['cells']),p['origin']['x'],p['origin']['y']) for p in data['pieces']]
 gates=[audit.Gate(COLORS.index(g['color']),DNAMES.index(g['side']),g['start'],g['span']) for g in data['gates']]
 walls=tuple((c['x'],c['y']) for c in data['blocked']);kernel=Kernel(pieces,gates,walls);state=tuple(p.x+p.y*W for p in pieces);solution=[];stages=[]
 while any(p>=0 for p in state):
  solo=[kernel.single_exit_path(state,i) for i,p in enumerate(state) if p>=0]
  solo=[p for p in solo if p]
  if solo:path=min(solo,key=len);visited=0
  else:path,visited=kernel.first_exit(state,budget)
  if not path:return None
  stages.append({'remaining':sum(p>=0 for p in state),'needsCooperation':not bool(solo),'firstExitGestures':len(path),'searchStates':visited,'pieceIDsUsed':sorted(set(a[0] for a in path))})
  for a in path:
   found=False
   for ns,na in kernel.actions(state):
    if na==a:state=ns;found=True;break
   assert found,a
  solution+=path
 audit.validate((pieces,gates,walls,solution))
 data=dict(data);data['baselineStages']=stages;data['cooperationStages']=sum(s['needsCooperation'] for s in stages);data['baselineMoves']=len(solution);data['solution']=[{'pieceID':p,'direction':DNAMES[d],'steps':n} for p,d,n in solution];return data

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--start',type=int,default=1300);parser.add_argument('--count',type=int,default=100);parser.add_argument('--expert',action='store_true');args=parser.parse_args();out=Path('artifacts/challenge-lab');out.mkdir(parents=True,exist_ok=True);start=time.monotonic();found=0
 for seed in range(args.start,args.start+args.count):
  r=create(seed,expert=args.expert)
  if r:
   found+=1;(out/f'candidate-{seed}.json').write_text(json.dumps(r,indent=2)); candidates=[json.loads(p.read_text()) for p in sorted(out.glob('candidate-*.json')) if len(json.loads(p.read_text())['pieces'])<=10 and ((int(p.stem.split('-')[1])>=2000)==args.expert) and ((int(p.stem.split('-')[1])>=2600)==(args.start>=2600))]; name=('expert-varied-candidates' if args.start>=2600 else 'expert-candidates') if args.expert else 'candidates';tmp=out/(name+'.tmp');tmp.write_text(json.dumps(candidates,indent=2));tmp.replace(out/(name+'.json')); print('CANDIDATE',seed,'pieces',len(r['pieces']),'density',r['densityCells'],'first',r['firstExitGestures'],'proof',r['proofMoves'],round(time.monotonic()-start,1),flush=True)
  elif seed%5==0:print('progress',seed,round(time.monotonic()-start,1),flush=True)
 print('DONE',found,round(time.monotonic()-start,1),flush=True)
if __name__=='__main__':main()
