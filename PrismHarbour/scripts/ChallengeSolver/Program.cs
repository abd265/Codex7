// Offline exhaustive gesture solver. No solver executable is shipped in the iOS app.
// Compatible with the Windows .NET Framework compiler and modern .NET SDKs.
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Diagnostics;

public class Cell { public int x; public int y; }
public class Piece { public int id; public string color; public Cell[] cells; public Cell origin; }
public class Gate { public string color; public string side; public int start; public int span; }
public class Move { public int pieceID; public string direction; public int steps; }
public class Board {
    public int seed; public int id; public string title;
    public int columns = 6; public int rows = 8;
    public Piece[] pieces; public Gate[] gates; public Cell[] blocked;
    public Move[] solution;
}
public struct Edge {
    public byte target, direction, steps;
    public ulong swept;
    public Edge(int t, int d, int s, ulong mask) { target=(byte)t;direction=(byte)d;steps=(byte)s;swept=mask; }
}
public struct Node {
    public ulong state; public int g,h,parent,piece; public Edge edge;
    public Node(ulong s,int cost,int estimate,int previous,int p,Edge action) { state=s;g=cost;h=estimate;parent=previous;piece=p;edge=action; }
}
public class Heap {
    List<int> heap = new List<int>(); List<Node> nodes;
    public Heap(List<Node> n) { nodes=n; }
    public int Count { get {return heap.Count;} }
    bool Less(int a,int b) { Node x=nodes[a],y=nodes[b]; int xf=x.g+x.h,yf=y.g+y.h; return xf<yf || (xf==yf && (x.h<y.h || (x.h==y.h && a<b))); }
    public void Push(int value) { int k=heap.Count;heap.Add(value);while(k>0){int p=(k-1)/2;if(!Less(value,heap[p]))break;heap[k]=heap[p];k=p;}heap[k]=value; }
    public int Pop() { int first=heap[0],last=heap[heap.Count-1];heap.RemoveAt(heap.Count-1);if(heap.Count==0)return first;int k=0;while(k*2+1<heap.Count){int c=k*2+1;if(c+1<heap.Count && Less(heap[c+1],heap[c]))c++;if(!Less(heap[c],last))break;heap[k]=heap[c];k=c;}heap[k]=last;return first; }
}
public class Result {
    public bool solved; public bool optimal; public int moves; public int states; public double seconds; public Move[] solution;
}
public class Solver {
    static string[] names={"up","right","down","left"};
    static int[] dx={0,1,0,-1},dy={-1,0,1,0};
    Board board; int n,cols,rows; ulong walls,goal;
    public ulong initial;
    ulong[][] masks; List<Edge>[][] edges; int[][] distances;
    public Solver(Board b) {
        board=b;n=b.pieces.Length;cols=b.columns;rows=b.rows;
        if(n>10 || cols*rows>63)throw new Exception("Packed solver requires <=10 pieces and <=63 cells");
        foreach(Cell c in b.blocked)walls |= 1UL << (c.x+c.y*cols);
        masks=new ulong[n][];edges=new List<Edge>[n][];distances=new int[n][];
        for(int p=0;p<n;p++) {
            initial |= (ulong)(b.pieces[p].origin.x+b.pieces[p].origin.y*cols) << (p*6);
            goal |= 63UL << (p*6);
            masks[p]=new ulong[64];edges[p]=new List<Edge>[64];distances[p]=Enumerable.Repeat(999,64).ToArray();
            for(int pos=0;pos<64;pos++)edges[p][pos]=new List<Edge>();
            for(int pos=0;pos<cols*rows;pos++) {
                ulong mask; bool outside,wrong;
                Shape(p,pos%cols,pos/cols,0,out mask,out outside,out wrong);
                if(!outside && (mask & walls)==0)masks[p][pos]=mask;
            }
            for(int pos=0;pos<cols*rows;pos++)if(masks[p][pos]!=0)BuildEdges(p,pos);
            // Reverse breadth-first distances with fixed walls and no other pieces.
            List<int>[] reverse=new List<int>[64];for(int j=0;j<64;j++)reverse[j]=new List<int>();
            for(int pos=0;pos<64;pos++)foreach(Edge e in edges[p][pos])reverse[e.target].Add(pos);
            Queue<int> q=new Queue<int>();q.Enqueue(63);distances[p][63]=0;
            while(q.Count>0){int at=q.Dequeue();foreach(int prev in reverse[at])if(distances[p][prev]>distances[p][at]+1){distances[p][prev]=distances[p][at]+1;q.Enqueue(prev);}}
        }
        ulong all=walls;for(int p=0;p<n;p++){int pos=Position(initial,p);if(masks[p][pos]==0 || (all&masks[p][pos])!=0)throw new Exception("Invalid initial board");all|=masks[p][pos];}
    }
    int Position(ulong key,int p){return (int)((key>>(p*6))&63);}
    ulong Set(ulong key,int p,int position){return (key & ~(63UL<<(p*6))) | ((ulong)position<<(p*6));}
    void Shape(int p,int x,int y,int d,out ulong mask,out bool outside,out bool wrong) {
        mask=0;outside=false;wrong=false;
        foreach(Cell c in board.pieces[p].cells) {
            int cx=x+c.x,cy=y+c.y;
            if(cx>=0 && cx<cols && cy>=0 && cy<rows)mask|=1UL<<(cx+cy*cols);else outside=true;
            if(d==0 && (cx<0||cx>=cols||cy>=rows) || d==1 && (cy<0||cy>=rows||cx<0) || d==2 && (cx<0||cx>=cols||cy<0) || d==3 && (cy<0||cy>=rows||cx>=cols))wrong=true;
        }
    }
    bool GateFits(int p,int x,int y,int d) {
        int low=999,high=-999;
        foreach(Cell c in board.pieces[p].cells){int value=d%2==0?x+c.x:y+c.y;low=Math.Min(low,value);high=Math.Max(high,value);}
        return board.gates.Any(g=>g.color==board.pieces[p].color && g.side==names[d] && low>=g.start && high<g.start+g.span);
    }
    void BuildEdges(int p,int pos) {
        int x=pos%cols,y=pos/cols;
        for(int d=0;d<4;d++) {
            ulong swept=0;
            for(int step=1;step<=Math.Max(cols,rows)+5;step++) {
                int nx=x+dx[d]*step,ny=y+dy[d]*step;ulong mask;bool outside,wrong;
                Shape(p,nx,ny,d,out mask,out outside,out wrong);swept|=mask;
                if(wrong || (swept & walls)!=0)break;
                if(!outside){edges[p][pos].Add(new Edge(nx+ny*cols,d,step,swept));continue;}
                if(!GateFits(p,x,y,d))break;
                bool valid=true;
                for(int extra=step+1;mask!=0 && extra<=Math.Max(cols,rows)+8;extra++) {
                    Shape(p,x+dx[d]*extra,y+dy[d]*extra,d,out mask,out outside,out wrong);swept|=mask;
                    if(wrong || (swept & walls)!=0){valid=false;break;}
                }
                if(valid && mask==0)edges[p][pos].Add(new Edge(63,d,step,swept));
                break;
            }
        }
    }
    ulong Occupancy(ulong state){ulong mask=0;for(int p=0;p<n;p++)mask|=masks[p][Position(state,p)];return mask;}
    int Heuristic(ulong state,bool firstOnly) {
        int value=firstOnly?999:0;
        for(int p=0;p<n;p++){int pos=Position(state,p);if(firstOnly && pos==63)return 0;int h=distances[p][pos];value=firstOnly?Math.Min(value,h):value+h;}
        return value;
    }
    bool IsGoal(ulong state,bool firstOnly){if(!firstOnly)return state==goal;for(int p=0;p<n;p++)if(Position(state,p)==63)return true;return false;}
    public Result Search(bool firstOnly,int limit) {
        Stopwatch watch=Stopwatch.StartNew();List<Node> nodes=new List<Node>();Heap open=new Heap(nodes);Dictionary<ulong,int> costs=new Dictionary<ulong,int>();
        nodes.Add(new Node(initial,0,Heuristic(initial,firstOnly),-1,-1,new Edge()));open.Push(0);costs[initial]=0;int end=-1;
        while(open.Count>0 && costs.Count<=limit) {
            int index=open.Pop();Node node=nodes[index];if(costs[node.state]!=node.g)continue;
            if(IsGoal(node.state,firstOnly)){end=index;break;}
            ulong occupied=Occupancy(node.state);bool forced=false;
            // Exiting an already removable piece cannot make any remaining move harder.
            // It costs one compulsory gesture, so commuting this exit forward preserves optimality.
            for(int p=0;p<n && !forced;p++) {
                int pos=Position(node.state,p);if(pos==63)continue;ulong other=occupied ^ masks[p][pos];
                foreach(Edge e in edges[p][pos])if(e.target==63 && (e.swept&other)==0){Add(node,index,p,e,firstOnly,costs,nodes,open);forced=true;break;}
            }
            if(forced)continue;
            for(int p=0;p<n;p++) {
                int pos=Position(node.state,p);if(pos==63)continue;ulong other=occupied ^ masks[p][pos];
                foreach(Edge e in edges[p][pos])if((e.swept&other)==0)Add(node,index,p,e,firstOnly,costs,nodes,open);
            }
        }
        List<Move> moves=new List<Move>();
        if(end>=0){for(int at=end;nodes[at].parent>=0;at=nodes[at].parent){Node node=nodes[at];moves.Add(new Move{pieceID=board.pieces[node.piece].id,direction=names[node.edge.direction],steps=node.edge.steps});}moves.Reverse();}
        return new Result{solved=end>=0,optimal=end>=0,moves=end>=0?moves.Count:-1,states=costs.Count,seconds=Math.Round(watch.Elapsed.TotalSeconds,3),solution=moves.ToArray()};
    }
    void Add(Node node,int parent,int p,Edge edge,bool firstOnly,Dictionary<ulong,int> costs,List<Node> nodes,Heap open) {
        ulong key=Set(node.state,p,edge.target);int g=node.g+1,prior;
        if(costs.TryGetValue(key,out prior) && prior<=g)return;
        int h=Heuristic(key,firstOnly);if(h>=999)return;
        costs[key]=g;nodes.Add(new Node(key,g,h,parent,p,edge));open.Push(nodes.Count-1);
    }
    public bool Greedy() {
        ulong state=initial;
        while(state!=goal) {
            ulong occupied=Occupancy(state);bool found=false;
            for(int p=0;p<n && !found;p++) {
                int start=Position(state,p);if(start==63)continue;ulong other=occupied ^ masks[p][start];
                Queue<int> q=new Queue<int>();q.Enqueue(start);bool[] seen=new bool[64];seen[start]=true;
                while(q.Count>0 && !found){int pos=q.Dequeue();foreach(Edge e in edges[p][pos])if(!seen[e.target] && (other&e.swept)==0){if(e.target==63){state=Set(state,p,63);found=true;break;}seen[e.target]=true;q.Enqueue(e.target);}}
            }
            if(!found)return false;
        }
        return true;
    }
}
public class Analysis {
    public int seed; public Board board; public Result firstExit; public Result complete; public bool greedySolved;
}
public class Program {
    public static void Main(string[] args) {
        JavaScriptSerializer json=new JavaScriptSerializer();json.MaxJsonLength=Int32.MaxValue;
        Board[] boards=json.Deserialize<Board[]>(File.ReadAllText(args[0]));
        int limit=args.Length>2?Int32.Parse(args[2]):500000;List<Analysis> report=new List<Analysis>();
        foreach(Board b in boards) {
            Solver solver=new Solver(b);bool greedy=solver.Greedy();Result first=solver.Search(true,Math.Min(limit,150000));
            Result full=first.solved?solver.Search(false,limit):new Result{solved=false,moves=-1,solution=new Move[0]};
            Analysis a=new Analysis{seed=b.seed,board=b,firstExit=first,complete=full,greedySolved=greedy};report.Add(a);
            File.WriteAllText(args[1]+".tmp",json.Serialize(report));if(File.Exists(args[1]))File.Delete(args[1]);File.Move(args[1]+".tmp",args[1]);
            Console.WriteLine("Seed "+b.seed+" first="+first.moves+" optimal="+full.moves+" greedy="+greedy+" states="+full.states+" sec="+full.seconds);
        }
    }
}
