#!/usr/bin/env python3
"""Independent Python audit of the Swift campaign algorithm; not a native test."""
from __future__ import annotations
from dataclasses import dataclass, replace
from datetime import date, timedelta
import argparse, hashlib, json, time
from pathlib import Path
COLS,ROWS,MASK=6,8,(1<<64)-1
DIR=((0,-1),(1,0),(0,1),(-1,0))
@dataclass(frozen=True)
class Piece:
    id:int
    color:int
    cells:tuple
    x:int
    y:int
    def world(self):return tuple((x+self.x,y+self.y) for x,y in self.cells)
    def shifted(self,d,n=1):return replace(self,x=self.x+DIR[d][0]*n,y=self.y+DIR[d][1]*n)
@dataclass(frozen=True)
class Gate:
    color:int
    side:int
    start:int
    span:int=2
class Random:
    def __init__(self,seed):self.state=seed&MASK
    def next(self,bound):
        if bound<=1:return 0
        self.state=(self.state+0x9E3779B97F4A7C15)&MASK
        value=self.state
        value=((value^(value>>30))*0xBF58476D1CE4E5B9)&MASK
        value=((value^(value>>27))*0x94D049BB133111EB)&MASK
        return (value^(value>>31))%bound
def inside(c):return 0<=c[0]<COLS and 0<=c[1]<ROWS
def move(pieces,gates,blocked,action):
    identity,d,steps=action
    index=next((i for i,p in enumerate(pieces) if p.id==identity),None)
    if index is None or steps<=0:return pieces,'blocked'
    original=piece=pieces[index]
    occupied=set(blocked)
    for other in pieces:
        if other.id!=identity:occupied.update(other.world())
    for _ in range(min(steps,9)):
        next_piece=piece.shifted(d)
        cells=next_piece.world()
        if all(inside(c) for c in cells):
            if occupied.intersection(cells):break
            piece=next_piece
            continue
        transverse=[c[0 if d%2==0 else 1] for c in piece.world()]
        permitted=any(g.color==piece.color and g.side==d and g.start<=min(transverse) and max(transverse)<g.start+g.span for g in gates)
        if not permitted:break
        exited=False
        for distance in range(1,14):
            swept=piece.shifted(d,distance).world()
            if occupied.intersection(swept):break
            wrong=((lambda x,y:x<0 or x>=COLS or y>=ROWS),(lambda x,y:y<0 or y>=ROWS or x<0),(lambda x,y:x<0 or x>=COLS or y<0),(lambda x,y:y<0 or y>=ROWS or x>=COLS))[d]
            if any(wrong(x,y) for x,y in swept):break
            if all(not inside(c) for c in swept):exited=True;break
        if exited:return pieces[:index]+pieces[index+1:],'exited'
        break
    if piece==original:return pieces,'blocked'
    result=list(pieces);result[index]=piece
    return result,'moved'
GATES=(((0,0,0),(1,0,4),(2,3,1),(3,1,1),(4,3,5),(5,1,5)),((0,0,2),(1,2,0),(2,2,4),(3,3,1),(4,1,3),(5,3,5)),((0,0,0),(1,0,4),(2,2,0),(3,2,4),(4,3,3),(5,1,3)))
BLOCKED=(((2,3),),((3,4),),((1,3),(4,4)),((2,2),(3,5)),((2,3),(3,4)),((1,4),(4,3),(2,6)))
SHAPES=(((0,0),(0,1)),((0,0),(1,0)),((0,0),(0,1),(1,1)),((0,0),(1,0),(0,1),(1,1)),((0,0),(0,1),(0,2),(1,2)),((0,0),(1,0),(1,1),(1,2)))
class Draft:
    def __init__(self,gates,blocked):self.gates,self.blocked,self.pieces,self.undo=gates,blocked,[],[]
    def insert(self,piece,gate):
        occupied=set(self.blocked)
        for other in self.pieces:occupied.update(other.world())
        if not all(inside(c) and c not in occupied for c in piece.world()):return False
        if move(self.pieces+[piece],self.gates,self.blocked,(piece.id,gate.side,1))[1]!='exited':return False
        self.pieces.append(piece);self.undo.append((piece.id,gate.side,1));return True
    def translate(self,identity,d,steps):
        index=next(i for i,p in enumerate(self.pieces) if p.id==identity)
        occupied=set(self.blocked)
        for other in self.pieces:
            if other.id!=identity:occupied.update(other.world())
        candidate=self.pieces[index]
        for _ in range(steps):
            candidate=candidate.shifted(d)
            if not all(inside(c) and c not in occupied for c in candidate.world()):return False
        self.pieces[index]=candidate;self.undo.append((identity,(d+2)%4,steps));return True
    def shuffle(self,random):
        if not self.pieces:return False
        start=random.next(len(self.pieces));direction_start=random.next(4)
        for offset in range(len(self.pieces)):
            identity=self.pieces[(start+offset)%len(self.pieces)].id
            for doffset in range(4):
                direction=(direction_start+doffset)%4
                if self.undo and self.undo[-1][:2]==(identity,direction):continue
                for distance in range(1+random.next(3),0,-1):
                    if self.translate(identity,direction,distance):return True
        return False
    def direct_exits(self):return sum(any(move(self.pieces,self.gates,self.blocked,(p.id,g.side,9))[1]=='exited' for g in self.gates if g.color==p.color) for p in self.pieces)
    def solution(self):
        proof=list(self.pieces)
        for action in reversed(self.undo):
            proof,outcome=move(proof,self.gates,self.blocked,action)
            assert outcome!='blocked',('invalid construction',action)
        assert not proof,'construction incomplete'
        state=list(self.pieces);result=[]
        for undo in reversed(self.undo):
            while True:
                action=next(((p.id,g.side,9) for p in reversed(state) for g in self.gates if g.color==p.color and move(state,self.gates,self.blocked,(p.id,g.side,9))[1]=='exited'),None)
                if action is None:break
                state,_=move(state,self.gates,self.blocked,action);result.append(action)
            if not state:break
            if any(p.id==undo[0] for p in state):
                candidate,outcome=move(state,self.gates,self.blocked,undo)
                if outcome!='blocked':state=candidate;result.append(undo)
        assert not state,'shortcut incomplete'
        return result
def generated(difficulty,seed):
    gates=[Gate(*entry) for entry in GATES[difficulty%3]]
    blocked=() if difficulty<7 else BLOCKED[(difficulty//3)%6]
    target=min(9,4+(difficulty-3)//5);best=None
    for attempt in range(8):
        random=Random(seed+attempt*104729);draft=Draft(gates,blocked)
        for identity in range(1,target+1):
            inserted=False
            for _ in range(40):
                starting=random.next(len(gates))
                for offset in range(len(gates)):
                    gate=gates[(starting+offset)%len(gates)]
                    raw=SHAPES[random.next(4 if difficulty<10 else 6)]
                    cells=raw if gate.side%2==0 else tuple((y,x) for x,y in raw)
                    width,height=max(x for x,y in cells)+1,max(y for x,y in cells)+1
                    alignment=gate.start+random.next(gate.span-(width if gate.side%2==0 else height)+1)
                    origin=((alignment,0),(COLS-width,alignment),(alignment,ROWS-height),(0,alignment))[gate.side]
                    if draft.insert(Piece(identity,gate.color,cells,*origin),gate):
                        inserted=True;draft.translate(identity,(gate.side+2)%4,1+random.next(3));break
                if inserted:break
                if not draft.shuffle(random):break
            if not inserted:break
            for _ in range(1+difficulty//12):draft.shuffle(random)
        for _ in range(3+difficulty//6):draft.shuffle(random)
        solution=draft.solution();score=len(draft.pieces)*100+min(len(solution),target*4)*3-draft.direct_exits()*14
        if best is None or score>best[0]:best=score,draft.pieces,solution
    return best[1],gates,blocked,best[2]
def introduction(number):
    if number==1:return [Piece(1,0,((0,0),(0,1)),0,3),Piece(2,2,((0,0),(1,0)),4,4),Piece(3,1,((0,0),(1,0),(1,1)),2,1)],[Gate(0,0,0),Gate(2,2,4),Gate(1,1,1)],(),[(1,0,4),(2,2,4),(3,1,3)]
    return [Piece(1,0,((0,0),(0,1)),2,3),Piece(2,1,((0,0),(1,0),(0,1),(1,1)),0,1),Piece(3,2,((0,0),(1,0)),3,6)],[Gate(0,0,0),Gate(1,3,1),Gate(2,2,4)],(),[(2,3,1),(1,3,2),(1,0,4),(3,1,1),(3,2,2)]
def validate(board):
    pieces,gates,blocked,solution=board
    assert pieces and len({p.id for p in pieces})==len(pieces),'empty/duplicate pieces'
    occupied=set(blocked)
    assert all(inside(c) for c in occupied),'obstacle outside'
    for g in gates:assert g.span>0 and g.start>=0 and g.start+g.span<=(COLS if g.side%2==0 else ROWS),'gate outside'
    for p in pieces:
        assert p.cells and len(set(p.cells))==len(p.cells),'empty/duplicate shape'
        assert any(g.color==p.color for g in gates),'missing gate'
        assert all(inside(c) for c in p.world()),'piece outside'
        assert not occupied.intersection(p.world()),'overlap'
        occupied.update(p.world())
    state=list(pieces)
    for action in solution:
        state,outcome=move(state,gates,blocked,action)
        assert outcome!='blocked',('blocked solution',action)
        assert all(inside(c) for p in state for c in p.world()),'partial exit'
    assert not state,'incomplete solution'
    canonical={'pieces':[(p.id,p.color,p.cells,p.x,p.y) for p in pieces],'gates':[(g.color,g.side,g.start,g.span) for g in gates],'blocked':blocked,'solution':solution}
    return {'pieces':len(pieces),'moves':len(solution),'fingerprint':hashlib.sha256(json.dumps(canonical,separators=(',',':')).encode()).hexdigest(),'board':canonical}
def daily_seed(key):
    value=14695981039346656037
    for byte in key.encode():value=((value^byte)*1099511628211)&MASK
    return value
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--days',type=int,default=365);parser.add_argument('--start',default='2026-09-26');parser.add_argument('--output',default='artifacts/campaign-audit.json');args=parser.parse_args()
    begin=time.monotonic();campaign={};daily={}
    for number in range(1,37):campaign[str(number)]=validate(introduction(number) if number<=2 else generated(number,number*7919+0x505249534D))
    print(f'PASS: all 36 campaign boards and solutions; {time.monotonic()-begin:.1f}s',flush=True)
    for offset in range(args.days):
        key=(date.fromisoformat(args.start)+timedelta(days=offset)).isoformat();seed=daily_seed(key)
        result=validate(generated(27+seed%10,seed));result.pop('board');daily[key]=result
        if (offset+1)%25==0:print(f'PASS: {offset+1}/{args.days} daily boards; {time.monotonic()-begin:.1f}s',flush=True)
    report={'audit':'Independent Python construction/geometry model. Native Swift execution is separate.','campaign':campaign,'daily':daily,'durationSeconds':round(time.monotonic()-begin,3)}
    output=Path(args.output);output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f'PASS: 36 campaign + {args.days} daily boards. Report: {output}',flush=True)
if __name__=='__main__':main()
