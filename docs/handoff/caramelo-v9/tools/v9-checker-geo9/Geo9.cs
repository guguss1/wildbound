using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Globalization;

// v9 final design checker: a port of WildboundCandyV3Layout / WildboundCandyLayout geometry plus the suite rules
// (V3-2..V3-17, Layout_Test nest rules incl. CH3 syrup, Nests_Test CH1 incl. posts 30 apart, BeastSites T4/CC4/S7,
// Life CL3/CL5, Island IS1, the v9 rules). Plot-local; world = local + (672, -3).
public static class Geo {
    public const double W = -260, E = 860, H = 260;
    public static double S = 0.75; // M1 kit scale
    public class P { public string id; public double x, z, r; public string kind; public P(string i,double a,double b,double c=0,string k=""){id=i;x=a;z=b;r=c;kind=k;} }
    public static List<double[]> River = new List<double[]>();
    public static double[] Pool; public static double PoolR;
    public static double[] Fall; public static double[] M1; public static double M1R, M1H;
    public static List<double[]> Lake = new List<double[]>();
    public static List<P> Islands = new List<P>();
    public static Dictionary<string, List<double[]>> Routes = new Dictionary<string, List<double[]>>();
    public static List<string> RouteOrder = new List<string>();
    public class Br { public string id, route; public double[] from, to; public double at, length, width=15, deck=12.5, ramp=28; public double x,z,ux,uz; }
    public static List<Br> Bridges = new List<Br>();
    public class Dock { public string id; public double sx, sz, tx, tz; }
    public static List<Dock> Docks = new List<Dock>();
    public static List<P> Nests = new List<P>();
    public class Post { public string id, creature, kind, nest; public double x, z; }
    public static List<Post> Posts = new List<Post>();
    public static List<P> Traps = new List<P>();
    public static List<P> Houses = new List<P>();
    public static List<P> Mountains = new List<P>();
    public static List<P> Hills = new List<P>();
    public static List<P> Platforms = new List<P>();
    public static List<P> Keep = new List<P>();
    public static List<P> Syrup = new List<P>();
    public static double[] Torta = { 748.2, 0 }; public static double TortaR = 42, Plaza = 58, Terr = 76, Perc = 36, Whip = 22;
    public static double[] Portal = { -31.2, 0 }, Entrance = { -260, 0 }, Junction = {0,0}, EastFork = {300,0};
    public static double[] Lic = { -161.2, 0 }; public static double LicScale = 0.8;
    public static double[] Cake = { -195, 145.6 };
    // creature tuning: wake, leash, reach (leash + attack radius/width + push), perception
    public static Dictionary<string,double[]> T = new Dictionary<string,double[]>{
        {"Gomibu",new double[]{40,30,30,24}}, {"Flanfuria",new double[]{40,16,16,20}}, {"Tortidragon",new double[]{40,35,35,22}},
        {"Mochimiau",new double[]{45,34,46,40}}, {"Canelin",new double[]{45,36,49,40}}, {"Flanin",new double[]{42,32,48,38}},
        {"Mielita",new double[]{48,38,50,42}}, {"GatoRepartidor",new double[]{40,30,40,34}} };
    static readonly CultureInfo IC = CultureInfo.InvariantCulture;
    static double D(string s){ return double.Parse(s, IC); }

    public static double Flat(double ax,double az,double bx,double bz){ return Math.Sqrt((ax-bx)*(ax-bx)+(az-bz)*(az-bz)); }
    public static double Seg(double x,double z,double ax,double az,double bx,double bz){
        double dx=bx-ax, dz=bz-az, l2=dx*dx+dz*dz, t=0;
        if(l2>0){ t=((x-ax)*dx+(z-az)*dz)/l2; if(t<0)t=0; if(t>1)t=1; }
        return Flat(x,z,ax+dx*t,az+dz*t);
    }
    public static double Depth(double x,double z){ return Math.Min(Math.Min(x-W, E-x), H-Math.Abs(z)); }
    public static double RiverDist(double x,double z){
        double best=double.MaxValue;
        for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1];
            best=Math.Min(best, Seg(x,z,a[0],a[1],b[0],b[1]) - Math.Max(a[2],b[2])/2); }
        return best;
    }
    public static double IslandDist(double x,double z){ double b=double.MaxValue; foreach(var i in Islands) b=Math.Min(b, Flat(x,z,i.x,i.z)-i.r); return b; }
    public static double Raw(double x,double z){
        double best=RiverDist(x,z);
        best=Math.Min(best, Flat(x,z,Pool[0],Pool[1])-PoolR);
        foreach(var d in Lake) best=Math.Min(best, Flat(x,z,d[0],d[1])-d[2]);
        return Math.Max(best, -IslandDist(x,z));
    }
    // v9: the plot clip, nothing outside the plot is chocolate
    public static double Liquid(double x,double z){ return Math.Max(Raw(x,z), -Depth(x,z)); }
    public static void Frame(Br B,double x,double z,out double along,out double across){ double dx=x-B.x, dz=z-B.z; along=dx*B.ux+dz*B.uz; across=-dx*B.uz+dz*B.ux; }
    public static Br OnBridge(double x,double z,bool deckOnly){
        foreach(var B in Bridges){ double a,c; Frame(B,x,z,out a,out c); if(Math.Abs(c)<=B.width/2 && Math.Abs(a)<=B.length/2+(deckOnly?0:B.ramp)) return B; }
        return null; }
    public static bool NearBridge(double x,double z,double reach){
        foreach(var B in Bridges){ double a,c; Frame(B,x,z,out a,out c); if(Math.Abs(c)<=B.width/2+reach && Math.Abs(a)<=B.length/2+B.ramp+reach) return true; }
        return false; }
    public static double RouteDist(double x,double z){
        double best=double.MaxValue;
        foreach(var k in RouteOrder){ var pts=Routes[k]; for(int i=0;i<pts.Count-1;i++) best=Math.Min(best, Seg(x,z,pts[i][0],pts[i][1],pts[i+1][0],pts[i+1][1])); }
        return best; }
    public static double[] KitPoint(double x,double z,double yaw,double s,double X,double Z){
        X*=s; Z*=s; return new double[]{ x + X*Math.Cos(yaw) + Z*Math.Sin(yaw), z - X*Math.Sin(yaw) + Z*Math.Cos(yaw) }; }
    public static double FaceYaw(double x,double z,double tx,double tz){ return Math.Atan2(-(tx-x), -(tz-z)); }

    public static List<P> Pieces(){
        var list=new List<P>();
        foreach(var m in Mountains) list.Add(new P(m.id,m.x,m.z,m.r,"mountain"));
        foreach(var h in Houses) list.Add(new P(h.id,h.x,h.z,h.r,"house"));
        foreach(var d in Docks){
            double dx=d.tx-d.sx, dz=d.tz-d.sz, L=Math.Sqrt(dx*dx+dz*dz), ux=dx/L, uz=dz/L, deckEnd=L-5;
            list.Add(new P(d.id,d.sx,d.sz,3,"dock"));
            list.Add(new P(d.id+"Ramp",d.sx-ux*10,d.sz-uz*10,3.5,"dock"));
            list.Add(new P(d.id+"Deck",d.sx+ux*deckEnd/2,d.sz+uz*deckEnd/2,3,"dock"));
        }
        foreach(var f in new double[][]{ new double[]{20.6,5.7}, new double[]{34.8,4.5} })
            foreach(int s in new int[]{-1,1}) list.Add(new P("Foot",Lic[0],Lic[1]+s*f[0]*LicScale,f[1]*LicScale,"licorice"));
        list.Add(new P("Base",Cake[0],Cake[1],18,"cake"));
        double yaw=FaceYaw(Cake[0],Cake[1],-195,0); double mid=(18+38.5)/2;
        list.Add(new P("Ramp",Cake[0]-Math.Sin(yaw)*mid,Cake[1]-Math.Cos(yaw)*mid,(38.5-18)/2+2,"cake"));
        return list; }

    public static StringBuilder Out = new StringBuilder();
    public static int Fails=0;
    public static void Check(bool ok,string msg){ if(!ok){ Fails++; Out.AppendLine("FAIL "+msg);} }
    public static void Note(string msg){ Out.AppendLine(msg); }
    static string F2(double v){ return v.ToString("F2", IC); }
    static string F1(double v){ return v.ToString("F1", IC); }

    public static double[] Outlet;
    public static void Build(){
        M1R = 54*S; M1H = 90.431*S;
        M1 = new double[]{ W + M1R - 0.3, -H + M1R - 0.3 };
        double[] r2 = { -150, -224 };
        double yaw = FaceYaw(M1[0],M1[1],r2[0],r2[1]);
        Pool = KitPoint(M1[0],M1[1],yaw,S,0.5653,-37.6671); PoolR = 11*S;
        Fall = KitPoint(M1[0],M1[1],yaw,S,0.5653,-31.0);
        Outlet = KitPoint(M1[0],M1[1],yaw,S,0.5653,-49.6671);
        Note(string.Format(IC,"M1 ({0:F2},{1:F2}) r {2:F2} h {3:F2} yaw {4:F4}; pool ({5:F2},{6:F2}) r {7:F2}; waterfall ({8:F2},{9:F2}) width {10:F2} top {11:F2}; outlet ({12:F2},{13:F2}) w {14:F2}",
            M1[0],M1[1],M1R,M1H,yaw,Pool[0],Pool[1],PoolR,Fall[0],Fall[1],7/0.45*S,33.72*S,Outlet[0],Outlet[1],12/0.45*S));
        River.Add(new double[]{ Outlet[0], Outlet[1], 12/0.45*S });
        foreach(var p in new double[][]{
            new double[]{-150,-224,50}, new double[]{-60,-225,64}, new double[]{40,-224,64}, new double[]{140,-225,64},
            new double[]{240,-224,64}, new double[]{330,-218,64}, new double[]{400,-210,60}, new double[]{445,-200,60},
            new double[]{470,-175,60}, new double[]{470,175,60}, new double[]{510,200,90}, new double[]{575,195,110},
            new double[]{650,195,120}, new double[]{760,195,120}, new double[]{860,195,120} }) River.Add(p);
        Lake.Add(new double[]{670,170,52}); Lake.Add(new double[]{580,172,34}); Lake.Add(new double[]{-150,-222,20}); Lake.Add(new double[]{240,-222,24}); Lake.Add(new double[]{815,170,32});
        Islands.Add(new P("I1",690,150,6));
        Platforms.Add(new P("CookieM",580,170,6.7)); Platforms.Add(new P("CookieL",650,180,11.7));
        Platforms.Add(new P("CookieS",700,185,3.9)); Platforms.Add(new P("CookieS",630,150,3.9));
        Routes["main"]=new List<double[]>{ new double[]{-260,0}, new double[]{-143,0}, new double[]{0,0}, new double[]{690.2,0} };
        Routes["left"]=new List<double[]>{ new double[]{-143,0}, new double[]{-130,-104}, new double[]{-65,-182}, new double[]{65,-182}, new double[]{117,-143}, new double[]{0,0} };
        Routes["right"]=new List<double[]>{ new double[]{-143,0}, new double[]{-117,91}, new double[]{-52,156}, new double[]{52,156}, new double[]{104,130}, new double[]{0,0} };
        Routes["deep"]=new List<double[]>{ new double[]{0,0}, new double[]{-31.2,0} };
        Routes["south"]=new List<double[]>{ new double[]{300,0}, new double[]{320,-125}, new double[]{640,-125}, new double[]{670,-200} };
        Routes["north"]=new List<double[]>{ new double[]{300,0}, new double[]{320,125}, new double[]{620,125} };
        RouteOrder.AddRange(new string[]{"main","left","right","deep","south","north"});
        AddBridge("Top","north",new double[]{320,125},new double[]{620,125},150,68);
        AddBridge("Main","main",new double[]{0,0},new double[]{690.2,0},470,68);
        AddBridge("Bottom","south",new double[]{320,-125},new double[]{640,-125},150,68);
        Docks.Add(new Dock{id="A",sx=-150,sz=-187,tx=-150,tz=-210});
        Docks.Add(new Dock{id="B",sx=240,sz=-186,tx=240,tz=-208});
        Docks.Add(new Dock{id="C",sx=670,sz=104,tx=670,tz=128});
        Docks.Add(new Dock{id="D",sx=815,sz=124,tx=815,tz=148});
        string[] ns = {
         "C1,Comun,-208,-23.4","C2,Comun,-182,31.2","C3,Comun,-117,-171.6","C4,Comun,-80.6,169","C5,Comun,78,197.6",
         "R1,Rara,-101.4,-39","R2,Rara,-101.4,44.2","R3,Rara,-58.5,-120.9","R4,Rara,-26,123.5","E1,Epica,-44.2,-26","E2,Epica,-44.2,31.2",
         "L1,Legendaria,46.8,-28.6","C6,Comun,55,-168","C7,Comun,6.5,184.6","C8,Comun,105,-183","C9,Comun,-175.5,-80.6","C10,Comun,-52,-167",
         "R5,Rara,114.4,145.6","R6,Rara,124.8,-158.6","R7,Rara,-150.8,75.4","E3,Epica,0,46.8","R8,Rara,-143,123.5","R9,Rara,-78,91",
         "R10,Rara,-13,-58.5","R11,Rara,46.8,96.2","C11,Comun,-39,195","C12,Comun,-169,-130","C13,Comun,35,190",
         "C14,Comun,340,-166","C15,Comun,350,166","R12,Rara,280,-80","R13,Rara,280,80","R14,Rara,400,-150","R15,Rara,410,150","E4,Epica,560,-40",
         "C16,Comun,530,-170","C17,Comun,620,-172","C18,Comun,700,-215","C19,Comun,575,-172","R16,Rara,600,-80","R17,Rara,660,-95",
         "R18,Rara,560,95","R19,Rara,530,-80","E5,Epica,580,40","E6,Epica,640,-40" };
        foreach(var s in ns){ var f=s.Split(','); Nests.Add(new P(f[0],D(f[2]),D(f[3]),0,f[1])); }
        // posts: id, creature, kind (home/extra), nest it stands by, x, z
        string[] ps = {
         "candyNest,Gomibu,home,C1,-214,-17.4","candyNestR1,Flanfuria,home,R1,-93.4,-47","candyNestC3,Tortidragon,home,C3,-129,-179.6",
         "candyNestC2,GatoRepartidor,home,C2,-188,44.2","candyNestR2,Mochimiau,home,R2,-96.4,56.2","candyNestR3,Canelin,home,R3,-46.5,-110.9",
         "candyNestR4,Flanin,home,C5,84,211.6","candyNestC4,Mielita,home,C4,-88.6,181",
         "candyPostC7,Gomibu,extra,C7,13.5,175.6","candyPostR6,Flanfuria,extra,R6,131.8,-153.6","candyPostC8,Tortidragon,extra,C8,97,-174",
         "candyPostC9,Mochimiau,extra,C9,-164.5,-76.6","candyPostR7,Canelin,extra,R7,-160.8,83.4","candyPostR5,GatoRepartidor,extra,R5,122.4,155.6",
         "candyPostC6,Mielita,extra,C6,55,-156","candyPostC10,Flanin,extra,C10,-40,-159",
         "candyPostE3,Gomibu,extra,E3,-12,46.8","candyPostR8,Flanfuria,extra,R8,-131,123.5","candyPostR9,Tortidragon,extra,R9,-66,91",
         "candyPostR10,Mochimiau,extra,R10,-4,-50.5","candyPostC11,Canelin,extra,C11,-39,183","candyPostR11,GatoRepartidor,extra,R11,37.8,104.2",
         "candyPostC13,Mielita,extra,C13,45,198","candyPostC12,Flanin,extra,C12,-157,-130",
         "candyPostE4,Gomibu,extra,E4,560,-28","candyPostR16,Flanfuria,extra,R16,600,-92","candyPostE5,Tortidragon,extra,E5,580,28",
         "candyPostR12,Mochimiau,extra,R12,292,-80","candyPostC16,Canelin,extra,C16,530,-158","candyPostR13,GatoRepartidor,extra,R13,292,80",
         "candyPostC18,Mielita,extra,C18,688,-215","candyPostR15,Flanin,extra,R15,398,150" };
        foreach(var s in ps){ var f=s.Split(','); Posts.Add(new Post{id=f[0],creature=f[1],kind=f[2],nest=f[3],x=D(f[4]),z=D(f[5])}); }
        Posts.Add(new Post{id="bossHome",creature="DonGlaseon",kind="boss",x=698.2,z=0});
        Posts.Add(new Post{id="bossTerritory",creature="DonGlaseon",kind="boss",x=748.2,z=0});
        Traps.Add(new P("riverside",-126.1,-71.5)); Traps.Add(new P("path",-93.6,8)); Traps.Add(new P("rareNest",-109.4,-30));
        Houses.Add(new P("H1",-192.4,215.8,28,"CV3_SweetHouse")); Houses.Add(new P("H2",-130,227.5,15,"CV3_CaramelTower"));
        Houses.Add(new P("H3",-10,-118,22.4,"CV3_ChocoHouse")); Houses.Add(new P("H4",231.4,130,20,"CV3_SweetHouse"));
        Houses.Add(new P("H5",-218.4,-106.6,21,"CV3_CaramelTower")); Houses.Add(new P("H6",45,-125,16,"CV3_ChocoHouse"));
        Houses.Add(new P("H7",143,231.4,20,"CV3_SweetHouse")); Houses.Add(new P("H8",380,-60,20,"CV3_SweetHouse"));
        Houses.Add(new P("H9",600,-200,16,"CV3_ChocoHouse")); Houses.Add(new P("H10",530,70,15,"CV3_CaramelTower"));
        Mountains.Add(new P("M1",M1[0],M1[1],M1R)); Mountains.Add(new P("M2",234,-117,14.2)); Mountains.Add(new P("M3",98.8,243.1,13.1));
        Mountains.Add(new P("M4",214.5,-156,13.1)); Mountains.Add(new P("M5",800,-236,13.1)); Mountains.Add(new P("M6",-243.1,243.1,13.1));
        Mountains.Add(new P("M7",790,-170,24.3)); Mountains.Add(new P("M8",300,230,14.2));
        Hills.Add(new P("Hill_1",858,-247,17.75)); Hills.Add(new P("Hill_2",858,-190,16)); Hills.Add(new P("Hill_3",858,-125,17.75));
        Hills.Add(new P("Hill_4",858,-60,16)); Hills.Add(new P("Hill_5",858,60,16)); Hills.Add(new P("Hill_6",858,105,9.94));
        Keep.Add(new P("pond",214.5,195,26)); Keep.Add(new P("hive",-78,240.5,10));
        Syrup.Add(new P("s1",0,-162,24)); Syrup.Add(new P("s2",26,-176,16)); Syrup.Add(new P("s3",-26,-176,16));
    }
    static void AddBridge(string id,string route,double[] from,double[] to,double at,double length){
        var B=new Br{id=id,route=route,from=from,to=to,at=at,length=length};
        double dx=to[0]-from[0], dz=to[1]-from[1], L=Math.Sqrt(dx*dx+dz*dz);
        B.ux=dx/L; B.uz=dz/L; B.x=from[0]+B.ux*at; B.z=from[1]+B.uz*at; Bridges.Add(B); }

    public static string Run(){
        Build();
        double half=7;
        double len=0; for(int i=0;i<River.Count-1;i++) len+=Flat(River[i][0],River[i][1],River[i+1][0],River[i+1][1]);
        Note("river length "+F1(len)+", points "+River.Count);
        // V3-2
        double r1pool=Flat(River[0][0],River[0][1],Pool[0],Pool[1]);
        Check(r1pool<=PoolR+1, "river starts in pool: "+F2(r1pool)); Note("RIVER[1] to pool "+F2(r1pool)+" (<= "+F2(PoolR+1)+")");
        var last=River[River.Count-1]; Check(Math.Abs(Depth(last[0],last[1]))<0.01 && last[0]>0, "ends on east edge");
        double minMargin=1e9; int minI=0;
        for(int i=0;i<River.Count;i++){ var p=River[i]; if(i>0) Check(p[2]>=50,"width pt "+(i+1));
            if(i<River.Count-1){ double m=Depth(p[0],p[1])-p[2]/2; Check(m>=2,"pt "+(i+1)+" leaves plot "+m); if(m<minMargin){minMargin=m;minI=i+1;}
                Note(string.Format(IC,"  pt {0}: ({1:F2},{2:F2}) w {3:F2} depth-w/2 {4:F2}; joint drum r {5:F1}", i+1, p[0],p[1],p[2], m, JointR(i))); } }
        Note("tightest point-in-plot margin: pt "+minI+" = "+F2(minMargin));
        Check(Flat(Fall[0],Fall[1],M1[0],M1[1])<M1R, "fall on mountain"); Check(Flat(Fall[0],Fall[1],Pool[0],Pool[1])<PoolR, "fall in pool");
        Check(33.72*S>=15 && 33.72*S<M1H, "waterfall top");
        Note("fall to pool "+F2(Flat(Fall[0],Fall[1],Pool[0],Pool[1]))+"; fall to M1 "+F2(Flat(Fall[0],Fall[1],M1[0],M1[1]))+"; M1 depth "+F2(Depth(M1[0],M1[1]))+" vs r-0.5 "+F2(M1R-0.5));
        Check(Depth(M1[0],M1[1])>=M1R-0.5,"M1 leaves plot");
        for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1]; int n=(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])/2);
            for(int s=0;s<n;s++){ double t=(double)s/n, x=a[0]+(b[0]-a[0])*t, z=a[1]+(b[1]-a[1])*t; if(Depth(x,z)>0.5) Check(Liquid(x,z)<0 || IslandDist(x,z)<=0, "gap at "+F1(x)+","+F1(z));} }
        // V3-4 routes
        foreach(var k in RouteOrder){ var pts=Routes[k];
            for(int i=0;i<pts.Count-1;i++){ var a=pts[i]; var b=pts[i+1]; int n=Math.Max(1,(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])/2));
                for(int s=0;s<=n;s++){ double x=a[0]+(b[0]-a[0])*s/n, z=a[1]+(b[1]-a[1])*s/n; double d=Liquid(x,z);
                    if(d<=0) Check(OnBridge(x,z,true)!=null, k+" wades at "+F1(x)+","+F1(z));
                    if(d<half) Check(OnBridge(x,z,false)!=null, k+" edge wades at "+F1(x)+","+F1(z)); } } }
        foreach(var B in Bridges){
            Check(Math.Atan2(B.deck,B.ramp)*180/Math.PI<=25,"ramp "+B.id);
            double legL=Flat(B.from[0],B.from[1],B.to[0],B.to[1]);
            Check(B.at-B.length/2-B.ramp>=-1e-6 && B.at+B.length/2+B.ramp<=legL+1e-6,"on leg "+B.id);
            Check(Liquid(B.x,B.z)<0,"over choc "+B.id);
            int lo=(int)Math.Floor(B.length/2)+9; double maxWet=-1;
            for(int s=-lo;s<=lo;s++){ double x=B.x+B.ux*s, z=B.z+B.uz*s; if(Liquid(x,z)<=1){ if(Math.Abs(s)>B.length/2) Check(false,B.id+" choc past deck "+s); maxWet=Math.Max(maxWet,Math.Abs(s)); } }
            double endL=Math.Min(Liquid(B.x+B.ux*B.length/2,B.z+B.uz*B.length/2),Liquid(B.x-B.ux*B.length/2,B.z-B.uz*B.length/2));
            double under=B.deck-0.4-3.5;
            Check(under>=8,"clearance "+B.id);
            // piers: 2x2 under the deck corners at along +-(L/2-1), across +-(width/2-1)
            double pierMin=1e9;
            foreach(int sa in new int[]{-1,1}) foreach(int sc in new int[]{-1,1}){
                double al=sa*(B.length/2-1), ac=sc*(B.width/2-1);
                double px=B.x+B.ux*al-B.uz*ac, pz=B.z+B.uz*al+B.ux*ac;
                // footprint corners
                foreach(int da in new int[]{-1,1}) foreach(int dc in new int[]{-1,1}){ double qx=px+B.ux*da-B.uz*dc, qz=pz+B.uz*da+B.ux*dc; pierMin=Math.Min(pierMin,Liquid(qx,qz)); } }
            Check(pierMin>=0.5,"pier wet "+B.id+" "+F2(pierMin));
            Note(string.Format(IC,"bridge {0} centre ({1:F1},{2:F1}) world ({3:F1},{4:F1}): wet(<=1) to |along| {5} of deck half {6}; deck-end liquid {7:F2}; underside over surface {8:F1}; pier footprint min liquid {9:F2}; footprint along leg {10:F1}..{11:F1} of {12:F1}",
                B.id,B.x,B.z,B.x+672,B.z-3,maxWet,B.length/2,endL,under,pierMin,B.at-B.length/2-B.ramp,B.at+B.length/2+B.ramp,legL));
        }
        // V3-5
        foreach(var n in Nests){ double d=Liquid(n.x,n.z); Check(d>=6,"nest "+n.id+" liquid "+F2(d)); }
        foreach(var p in Posts){ double d=Liquid(p.x,p.z); Check(d>=8,"post "+p.id+" liquid "+F2(d)); }
        foreach(var t in Traps){ Check(Liquid(t.x,t.z)>=10,"trap "+t.id); }
        Check(Liquid(Torta[0],Torta[1])>=Terr,"boss terr liquid");
        Note("boss centre liquid "+F2(Liquid(Torta[0],Torta[1]))+" (>= 76); plaza edge to chocolate "+F2(Liquid(Torta[0],Torta[1])-Plaza));
        Check(Liquid(Portal[0],Portal[1])>=16,"portal"); Check(Liquid(Entrance[0],Entrance[1])>=28,"entrance");
        foreach(var k in Keep) Check(Liquid(k.x,k.z)>=k.r,"keep "+k.id);
        // V3-6
        var pieces=Pieces();
        foreach(var p in pieces){ string L=p.kind+" "+p.id;
            foreach(var n in Nests) Check(Flat(p.x,p.z,n.x,n.z)-p.r>=8, L+" on nest "+n.id+" "+F2(Flat(p.x,p.z,n.x,n.z)-p.r));
            foreach(var q in Posts) Check(Flat(p.x,p.z,q.x,q.z)-p.r>=6, L+" on post "+q.id+" "+F2(Flat(p.x,p.z,q.x,q.z)-p.r));
            foreach(var t in Traps) Check(Flat(p.x,p.z,t.x,t.z)-p.r>=10, L+" on trap");
            Check(RouteDist(p.x,p.z)-p.r-half>=3, L+" on route "+F2(RouteDist(p.x,p.z)-p.r-half));
            Check(Flat(p.x,p.z,Torta[0],Torta[1])-p.r>=Terr, L+" in boss terr");
            Check(Flat(p.x,p.z,Portal[0],Portal[1])-p.r>=16, L+" portal");
            Check(Flat(p.x,p.z,Entrance[0],Entrance[1])-p.r>=28, L+" entrance");
            foreach(var k in Keep) Check(Flat(p.x,p.z,k.x,k.z)-p.r-k.r>=2, L+" on "+k.id);
            if(p.kind=="mountain") Check(Depth(p.x,p.z)>=p.r-0.5, L+" leaves plot "+Depth(p.x,p.z));
            else Check(Depth(p.x,p.z)-p.r>=2, L+" by edge "+(Depth(p.x,p.z)-p.r));
            bool source = p.kind=="mountain" && p.id=="M1";
            if(!source && p.kind!="dock") Check(Liquid(p.x,p.z)-p.r>=2, L+" in choc "+F2(Liquid(p.x,p.z)-p.r));
            if(p.kind!="dock") Check(!NearBridge(p.x,p.z,p.r), L+" on bridge");
        }
        for(int i=0;i<pieces.Count;i++) for(int j=i+1;j<pieces.Count;j++){ var a=pieces[i]; var b=pieces[j];
            bool same = a.kind=="dock" && b.kind=="dock" && a.id.Substring(0,1)==b.id.Substring(0,1);
            if(!(a.kind=="cake"&&b.kind=="cake") && !same) Check(Flat(a.x,a.z,b.x,b.z)-a.r-b.r>=2, a.kind+" "+a.id+" touches "+b.kind+" "+b.id); }
        // V3-7 doors and quarters
        var quarters=new HashSet<string>();
        foreach(var h in Houses){ double yaw=FaceYaw(h.x,h.z,0,0)+(h.kind=="CV3_CaramelTower"?Math.PI:0);
            double lx=-Math.Sin(yaw), lz=-Math.Cos(yaw); double dx=h.x+lx*(h.r+4), dz=h.z+lz*(h.r+4);
            Check(Depth(dx,dz)>=5, h.id+" door edge"); Check(Liquid(dx,dz)>=4, h.id+" door choc "+F2(Liquid(dx,dz)));
            foreach(var p in pieces) if(!(p.kind=="house"&&p.id==h.id)) Check(Flat(dx,dz,p.x,p.z)-p.r>=4, h.id+" door faces "+p.id);
            quarters.Add((h.x>0?"E":"W")+(h.z>0?"N":"S"));
            Note(string.Format(IC,"  house {0} ({1},{2}) r {3}: liquid-r {4:F1}, route-r-7 {5:F1}, door ({6:F1},{7:F1}) liquid {8:F1} depth {9:F1}",h.id,h.x,h.z,h.r,Liquid(h.x,h.z)-h.r,RouteDist(h.x,h.z)-h.r-7,dx,dz,Liquid(dx,dz),Depth(dx,dz))); }
        Check(quarters.Count==4,"house quarters "+string.Join(",",quarters));
        // V3-8 docks
        foreach(var d in Docks){ Check(Liquid(d.sx,d.sz)>0,"stand "+d.id+" "+F2(Liquid(d.sx,d.sz))); Check(Liquid(d.tx,d.tz)<=-6,"tip "+d.id+" "+F2(Liquid(d.tx,d.tz)));
            Check(!NearBridge(d.tx,d.tz,6),"tip by bridge "+d.id);
            double dx=d.tx-d.sx, dz=d.tz-d.sz, L=Math.Sqrt(dx*dx+dz*dz);
            Check(Liquid(d.sx-dx/L*10,d.sz-dz/L*10)>0, "ramp foot "+d.id);
            double inDisc=-1e9; foreach(var dd in Lake) inDisc=Math.Max(inDisc, dd[2]-Flat(d.tx,d.tz,dd[0],dd[1]));
            Check(inDisc>=8,"tip "+d.id+" not 8 inside a lake disc "+F2(inDisc));
            var fl=Flow(d.tx,d.tz);
            Note(string.Format(IC,"dock {0}: stand ({1},{2}) world ({3},{4}) liquid {5:F2}; tip ({6},{7}) world ({8},{9}) liquid {10:F2}; ramp foot liquid {11:F2}; tip inside its disc by {12:F1}; current {13:F3}; nearest route {14:F1}",
                d.id,d.sx,d.sz,d.sx+672,d.sz-3,Liquid(d.sx,d.sz),d.tx,d.tz,d.tx+672,d.tz-3,Liquid(d.tx,d.tz),Liquid(d.sx-dx/L*10,d.sz-dz/L*10),inDisc,Math.Sqrt(fl[0]*fl[0]+fl[1]*fl[1]),RouteDist(d.sx,d.sz))); }
        for(int i=0;i<Docks.Count;i++) for(int j=i+1;j<Docks.Count;j++){ double t=Flat(Docks[i].tx,Docks[i].tz,Docks[j].tx,Docks[j].tz); Check(t>=50,"docks apart "+Docks[i].id+Docks[j].id+" "+F1(t)); }
        // basins inside the river band (discs 3..5)
        for(int i=2;i<Lake.Count;i++){ var dd=Lake[i]; double worst=-1e9; for(int a=0;a<72;a++){ double ang=a*Math.PI/36, x=dd[0]+Math.Cos(ang)*dd[2], z=dd[1]+Math.Sin(ang)*dd[2]; worst=Math.Max(worst,RiverDist(x,z)); } Check(worst<=0,"basin "+(i+1)+" leaves the river band "+F2(worst)); Note("basin "+(i+1)+" rim max river distance "+F2(worst)); }
        // V3-9 platforms
        foreach(var pl in Platforms){ bool inside=false; foreach(var d in Lake.Take(2)) if(Flat(pl.x,pl.z,d[0],d[1])+pl.r<=d[2]) inside=true; Check(inside,"platform "+pl.id+" leaves lake"); Check(!NearBridge(pl.x,pl.z,pl.r),"platform on bridge"); }
        for(int i=0;i<Platforms.Count;i++) for(int j=i+1;j<Platforms.Count;j++) Check(Flat(Platforms[i].x,Platforms[i].z,Platforms[j].x,Platforms[j].z)-Platforms[i].r-Platforms[j].r>=2,"platforms touch");
        foreach(var isl in Islands){ foreach(var pl in Platforms) Check(Flat(isl.x,isl.z,pl.x,pl.z)-9.9-pl.r>=4,"island vs platform "+pl.id);
            Check(Flat(isl.x,isl.z,Lake[0][0],Lake[0][1])+9.9<=Lake[0][2],"island in disc 1");
            foreach(var d in Docks){ Check(Flat(isl.x,isl.z,d.tx,d.tz)-9.9>=15,"island vs tip "+d.id); Check(Flat(isl.x,isl.z,d.sx,d.sz)-9.9>=20,"island vs stand "+d.id);}
            for(int a=0;a<72;a++){ double ang=a*Math.PI/36, x=isl.x+Math.Cos(ang)*(9.9+3), z=isl.z+Math.Sin(ang)*(9.9+3); Check(Liquid(x,z)<=-3,"island channel at "+a); }
            // IS1: foot >= 4 HULL from the tip-to-tip line of docks 1 and 2
            Check(Seg(isl.x,isl.z,Docks[0].tx,Docks[0].tz,Docks[1].tx,Docks[1].tz)-9.9>=12,"island by the A-B line"); }
        // V3-15 hills
        foreach(var h in Hills){ foreach(var n in Nests) Check(Flat(h.x,h.z,n.x,n.z)-h.r>=8,h.id+" nest"); foreach(var q in Posts) Check(Flat(h.x,h.z,q.x,q.z)-h.r>=6,h.id+" post");
            Check(RouteDist(h.x,h.z)-h.r-half>=3,h.id+" route"); Check(Flat(h.x,h.z,Torta[0],Torta[1])-h.r>=Terr,h.id+" boss");
            foreach(var k in Keep) Check(Flat(h.x,h.z,k.x,k.z)-h.r-k.r>=2,h.id+" keep");
            foreach(var p in pieces) Check(Flat(h.x,h.z,p.x,p.z)-h.r-p.r>=2,h.id+" on "+p.kind+" "+p.id);
            Check(Raw(h.x,h.z)-h.r>=2,h.id+" choc "+F2(Raw(h.x,h.z)-h.r)); Check(h.x-h.r<E && h.x+h.r>E, h.id+" straddles");
            Note(string.Format(IC,"  hill {0} z {1}: liquid-r {2:F1}, boss-r {3:F1}", h.id,h.z,Raw(h.x,h.z)-h.r,Flat(h.x,h.z,Torta[0],Torta[1])-h.r)); }
        for(int i=0;i<Hills.Count;i++) for(int j=i+1;j<Hills.Count;j++) Check(Flat(Hills[i].x,Hills[i].z,Hills[j].x,Hills[j].z)-Hills[i].r-Hills[j].r>=2,"hills touch");
        // Layout_Test nests
        var ring=new Dictionary<string,double[]>{{"Comun",new double[]{0,97.5}},{"Rara",new double[]{97.5,208}},{"Epica",new double[]{208,260}},{"Legendaria",new double[]{208,260}}};
        int nearEntrance=0;
        foreach(var n in Nests){ double dep=Depth(n.x,n.z); var b=ring[n.kind]; Check(dep>=b[0]&&dep<=b[1],"ring "+n.id+" "+dep);
            double rd=RouteDist(n.x,n.z), tt=Flat(n.x,n.z,Torta[0],Torta[1]);
            Check(rd>=11,"nest blocks path "+n.id+" "+F1(rd)); Check(rd<=52||tt<=Plaza,"unreachable "+n.id+" "+F1(rd));
            Check(tt>=TortaR+6,"in torta"); Check(n.x<Torta[0],"behind torta "+n.id);
            foreach(var k in Keep) Check(Flat(n.x,n.z,k.x,k.z)>=k.r+20,"nest "+n.id+" on "+k.id);
            foreach(var s in Syrup) Check(Flat(n.x,n.z,s.x,s.z)>=s.r+6,"nest "+n.id+" in the syrup "+s.id+" "+F2(Flat(n.x,n.z,s.x,s.z)));
            Check(Flat(n.x,n.z,Portal[0],Portal[1])>=16,"nest on portal");
            double de=Flat(n.x,n.z,Entrance[0],Entrance[1]);
            Check(de>=39,"nest crowds entrance"); if(de<=91){ Check(n.kind=="Comun",n.id+" near entrance not Comun"); nearEntrance++; } }
        Check(nearEntrance>=2,"first nests");
        for(int i=0;i<Nests.Count;i++) for(int j=i+1;j<Nests.Count;j++) Check(Flat(Nests[i].x,Nests[i].z,Nests[j].x,Nests[j].z)>=20, Nests[i].id+" touches "+Nests[j].id+" "+F1(Flat(Nests[i].x,Nests[i].z,Nests[j].x,Nests[j].z)));
        var newIds=new HashSet<string>{"C14","C15","C16","C17","C18","C19","R12","R13","R14","R15","R16","R17","R18","R19","E4","E5","E6","C6","C8","C10","C13"};
        foreach(var n in Nests) if(newIds.Contains(n.id)){
            Check(Flat(n.x,n.z,Torta[0],Torta[1])>=Terr+20,"new nest in boss terr "+n.id); Check(Flat(n.x,n.z,Entrance[0],Entrance[1])>=80,"new nest by entrance "+n.id); }
        foreach(var k in RouteOrder) foreach(var p in Routes[k]) Check(p[0]<Torta[0], "route point behind torta "+k);
        // S4 / GT
        foreach(var k in new string[]{"left","right"}) foreach(var pt in Samples(k)){ Check(Flat(pt[0],pt[1],Torta[0],Torta[1])>=Terr+half,k+" in terr"); Check(Depth(pt[0],pt[1])>=20,k+" leaves plot"); }
        Check(Depth(Torta[0]+Plaza,0)<=60,"plaza by the east edge "+Depth(Torta[0]+Plaza,0));
        Check(Depth(Torta[0]+Terr,0)>=10 && Depth(Torta[0],Terr)>=10,"territory in plot");
        foreach(var sp in new double[][]{Entrance,new double[]{-143,0},Junction,EastFork}) Check(Flat(sp[0],sp[1],Torta[0],Torta[1])>=Terr+Perc,"safe point in boss sight");
        Note("east fork (300,0) to boss "+F1(Flat(300,0,Torta[0],Torta[1]))+" (>= 112); plaza edge depth "+F1(Depth(Torta[0]+Plaza,0))+"; territory edge depth "+F1(Depth(Torta[0]+Terr,0)));
        // rarity lean (new nests)
        var sums=new Dictionary<string,double[]>();
        foreach(var n in Nests) if(newIds.Contains(n.id) && !(n.id=="C6"||n.id=="C8"||n.id=="C10"||n.id=="C13")){ if(!sums.ContainsKey(n.kind)) sums[n.kind]=new double[2]; sums[n.kind][0]+=n.x; sums[n.kind][1]+=1; }
        foreach(var kv in sums) Note("new "+kv.Key+" count "+kv.Value[1]+" mean x "+F1(kv.Value[0]/kv.Value[1]));
        var cnt=new Dictionary<string,int>(); foreach(var n in Nests){ if(!cnt.ContainsKey(n.kind)) cnt[n.kind]=0; cnt[n.kind]++; }
        Note("nest counts: "+string.Join(", ",cnt.Select(kv=>kv.Key+" "+kv.Value))+"; total "+Nests.Count);
        Posts_();
        Barrier(); Raft(); CurrentSmooth(); Life(); Hives(); Report();
        return Out.ToString();
    }
    static double JointR(int i){ double w=River[i][2]; if(i>0) w=Math.Max(w,River[i-1][2]); if(i<River.Count-1) w=Math.Max(w,River[i+1][2]); return w/2; }
    static List<double[]> Samples(string k){ var pts=Routes[k]; var o=new List<double[]>(); for(int i=0;i<pts.Count-1;i++){ var a=pts[i]; var b=pts[i+1]; int n=Math.Max(1,(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])/2)); for(int s=0;s<=n;s++) o.Add(new double[]{a[0]+(b[0]-a[0])*s/n, a[1]+(b[1]-a[1])*s/n}); } return o; }

    static void Posts_(){
        var homeOf=new Dictionary<string,Post>(); foreach(var p in Posts) if(p.kind=="home") homeOf[p.creature]=p;
        var nestOf=new Dictionary<string,string>(); var per=new Dictionary<string,int>();
        foreach(var p in Posts){ if(p.kind=="boss") continue; var t=T[p.creature];
            double best=1e9; string bid=null; foreach(var n in Nests){ double d=Flat(p.x,p.z,n.x,n.z); if(d<best){best=d;bid=n.id;} }
            double rd=RouteDist(p.x,p.z);
            if(p.kind=="extra"){
                if(!per.ContainsKey(p.creature)) per[p.creature]=0; per[p.creature]++;
                Check(best>=8&&best<=16,"CH1 "+p.id+" nearest nest "+bid+" "+F2(best));
                Check(bid==p.nest,"CH1 "+p.id+" nearest nest is "+bid+" not "+p.nest);
                Check(!nestOf.ContainsKey(bid),"CH1 "+p.id+" shares nest "+bid); nestOf[bid]=p.id;
                Check(rd>=11,"CH1 "+p.id+" on a path "+F2(rd)); Check(rd<=t[0],"CH1 "+p.id+" route "+F2(rd)+" > wake "+t[0]);
                Check(Depth(p.x,p.z)>=t[1],"CH1 "+p.id+" leash leaves plot");
                double tb=Flat(p.x,p.z,Torta[0],Torta[1]); Check(tb>=Terr+t[2],"CH1 "+p.id+" boss "+F1(tb));
                Check(Flat(p.x,p.z,Entrance[0],Entrance[1])>=30+t[2],"CH1 "+p.id+" entrance");
                foreach(var s in Syrup) Check(Flat(p.x,p.z,s.x,s.z)>=s.r+2,"CH1 "+p.id+" in the syrup "+s.id+" "+F2(Flat(p.x,p.z,s.x,s.z)));
                foreach(var k in Keep) Check(Flat(p.x,p.z,k.x,k.z)>=k.r,"CH1 "+p.id+" keep");
                var hp=homeOf[p.creature]; Check(Flat(p.x,p.z,hp.x,hp.z)>=100,"CH1 "+p.id+" near home "+F1(Flat(p.x,p.z,hp.x,hp.z)));
            } else {
                Check(best>=8&&best<=16,"T4/CC4 home "+p.id+" nearest nest "+bid+" "+F2(best));
                Check(Depth(p.x,p.z)>=t[1],"home leash plot "+p.id);
                Check(Flat(p.x,p.z,Torta[0],Torta[1])>=Terr+t[2],"home boss "+p.id);
            }
            Note(string.Format(IC,"POST {0,-14} {1,-14} {2,-5} local ({3},{4}) world ({5},{6}) nearest {7} {8:F1}; route {9:F1} (wake {10}); liquid {11:F1}; depth {12:F1}; boss {13:F1} (need {14}); home {15:F1}",
                p.id,p.creature,p.kind,p.x,p.z,p.x+672,p.z-3,bid,best,rd,t[0],Liquid(p.x,p.z),Depth(p.x,p.z),Flat(p.x,p.z,Torta[0],Torta[1]),Terr+t[2],p.kind=="extra"?Flat(p.x,p.z,homeOf[p.creature].x,homeOf[p.creature].z):0));
        }
        foreach(var kv in per) Check(kv.Value==3,"PER "+kv.Key+" "+kv.Value);
        Check(per.Count==8,"8 creatures");
        var all=Posts.Where(p=>p.kind!="boss").ToList(); Check(all.Count==32,"32 posts: "+all.Count);
        double minApart=1e9; string pair="";
        for(int i=0;i<all.Count;i++) for(int j=i+1;j<all.Count;j++){ double d=Flat(all[i].x,all[i].z,all[j].x,all[j].z); Check(d>=30,"posts "+all[i].id+" "+all[j].id+" "+F1(d)); if(d<minApart){minApart=d;pair=all[i].id+"/"+all[j].id;} }
        Note("closest posts "+pair+" "+F1(minApart));
        // guardians bind
        var G=new HashSet<string>{"Gomibu","Flanfuria","Tortidragon"};
        foreach(var p in Posts){ if(!G.Contains(p.creature)) continue; double best=1e9; string bid=null; foreach(var n in Nests){ double d=Flat(p.x,p.z,n.x,n.z); if(d<best){best=d;bid=n.id;} }
            Check(best<=20,"bind "+p.id); Note("  guard "+p.id+" binds "+bid+" at "+F1(best)); }
        // CA2/CC4: home posts leashes apart (unchanged posts)
        // S7 pond/hive
        double nube=60, abeja=35;
        double np=1e9, nh=1e9; foreach(var n in Nests){ np=Math.Min(np,Flat(n.x,n.z,Keep[0].x,Keep[0].z)); nh=Math.Min(nh,Flat(n.x,n.z,Keep[1].x,Keep[1].z)); }
        Check(RouteDist(Keep[0].x,Keep[0].z)>=nube+7,"pond route"); Check(np>=nube+8,"pond nest "+F1(np));
        Check(RouteDist(Keep[1].x,Keep[1].z)>=abeja+7,"hive route"); Check(nh>=abeja+8,"hive nest "+F1(nh));
        Note("pond: route "+F1(RouteDist(Keep[0].x,Keep[0].z))+" nearest nest "+F1(np)+"; hive: route "+F1(RouteDist(Keep[1].x,Keep[1].z))+" nearest nest "+F1(nh));
    }

    static void Life(){
        double minAlt=Math.Ceiling(M1H+4);
        Note("MIN_ALT >= "+F2(M1H+4)+" -> "+minAlt);
        double[][] fl = { new double[]{-156,52,26,76}, new double[]{-104,-65,24,79}, new double[]{78,195,22,75}, new double[]{169,-143,22,78},
            new double[]{-90,-140,20,76}, new double[]{195,156,20,80}, new double[]{380,-110,24,77}, new double[]{620,-50,22,79} };
        int k=0; foreach(var f in fl){ k++; Check(Liquid(f[0],f[1])>=10, "flock F"+k+" over choc");
            foreach(var h in Houses) Check(Flat(f[0],f[1],h.x,h.z)>=h.r+5, "flock F"+k+" on house "+h.id);
            double reach=f[2]+2.5; Check(f[0]-reach>=W+5 && f[0]+reach<=E-5 && Math.Abs(f[1])+reach<=H-5, "flock F"+k+" leaves plot");
            Check(f[3]-1.5>=minAlt && f[3]+2.4+1.5<=minAlt+20,"flock F"+k+" altitude "+f[3]);
            Note(string.Format(IC,"flock F{0} ({1},{2}) r {3} alt {4}: liquid {5:F1}", k,f[0],f[1],f[2],f[3],Liquid(f[0],f[1]))); }
        object[][] fish = { new object[]{"River_W1",-100.0,-224.0,0.0}, new object[]{"River_W2",60.0,-226.0,0.0}, new object[]{"River_W3",300.0,-220.0,0.07},
            new object[]{"River_M1",470.0,-60.0,1.5708}, new object[]{"River_M2",470.0,60.0,1.5708}, new object[]{"Lake_1",600.0,160.0,0.2},
            new object[]{"Lake_2",655.0,140.0,0.0}, new object[]{"Lake_3",700.0,215.0,0.0}, new object[]{"Lake_4",620.0,205.0,-0.2}, new object[]{"River_E1",780.0,190.0,0.0} };
        foreach(var f in fish){ string id=(string)f[0]; double x0=(double)f[1], z0=(double)f[2], h=(double)f[3]; double worst=-1e9;
            for(int s=0;s<=20;s++){ double u=s/20.0, x=x0+Math.Cos(h)*7*u, z=z0+Math.Sin(h)*7*u; worst=Math.Max(worst,Liquid(x,z));
                Check(Liquid(x,z)<=-3, id+" leaves choc");
                foreach(var B in Bridges){ double a,c; Frame(B,x,z,out a,out c); Check(Math.Abs(c)>B.width/2+3 || Math.Abs(a)>B.length/2+B.ramp+3, id+" under bridge "+B.id); }
                foreach(var p in Platforms) Check(Flat(x,z,p.x,p.z)>=p.r+3, id+" into cookie");
                foreach(var d in Docks) Check(Flat(x,z,d.tx,d.tz)>=8, id+" at dock "+d.id);
                foreach(var isl in Islands) Check(Flat(x,z,isl.x,isl.z)>=isl.r+3, id+" at island"); }
            Note("  fish "+id+" worst liquid "+F2(worst)); }
        foreach(var d in Docks){ var fl2=Flow(d.tx,d.tz); Note("current at dock "+d.id+" tip "+F2(Math.Sqrt(fl2[0]*fl2[0]+fl2[1]*fl2[1]))); }
        for(int i=0;i<Lake.Count;i++){ var fl3=Flow(Lake[i][0],Lake[i][1]); Note(string.Format(IC,"current at lake disc {0} centre {1:F3} dir ({2:F2},{3:F2})", i+1, Math.Sqrt(fl3[0]*fl3[0]+fl3[1]*fl3[1]), fl3[0], fl3[1])); }
        int open=0; for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1]; double mx=(a[0]+b[0])/2, mz=(a[1]+b[1])/2; double ld=double.MaxValue; foreach(var dd in Lake) ld=Math.Min(ld,Flat(mx,mz,dd[0],dd[1])-dd[2]); if(ld>=0 && Liquid(mx,mz)<=-2) open++; }
        Note("CU2 open legs (midpoint off every disc) "+open);
        // CU3 dry points
        foreach(var p in new double[][]{ new double[]{-150,0}, new double[]{150,100}, new double[]{100,-50}, new double[]{-100,-50}, new double[]{60,150} }) Check(Liquid(p[0],p[1])>0,"CU3 dry point "+p[0]+","+p[1]);
        Check(Liquid(-84.5,123.5)>=3,"flower W"); Check(Liquid(78,143)>=3,"flower E");
    }
    static void Hives(){
        int cand=0, wet=0, valid=0;
        foreach(var k in RouteOrder){ var pts=Routes[k];
            for(int i=0;i<pts.Count-1;i++){ var a=pts[i]; var b=pts[i+1]; double dx=b[0]-a[0], dz=b[1]-a[1], L=Math.Sqrt(dx*dx+dz*dz); double nx=-dz/L, nz=dx/L; int n=Math.Max(1,(int)Math.Floor(L/12));
                for(int s=0;s<n;s++){ double t=(s+0.5)/n, px=a[0]+dx*t, pz=a[1]+dz*t;
                    foreach(int sg in new int[]{1,-1}){ double x=px+sg*nx*16, z=pz+sg*nz*16; cand++;
                        bool ok = Depth(x,z)>=15 && Flat(x,z,Entrance[0],Entrance[1])>=40 && Flat(x,z,Torta[0],Torta[1])>=Plaza+12 && Flat(x,z,Portal[0],Portal[1])>=45;
                        foreach(var kk in Keep) if(Flat(x,z,kk.x,kk.z)<kk.r+12) ok=false;
                        foreach(var nn in Nests) if(Flat(x,z,nn.x,nn.z)<15) ok=false;
                        foreach(var q in Posts) if(Flat(x,z,q.x,q.z)<15) ok=false;
                        double rd=RouteDist(x,z); if(rd<10||rd>22) ok=false;
                        if(ok){ valid++; if(Liquid(x,z)<4) wet++; } } } } }
        Note("hive candidates "+cand+", valid by today's rules "+valid+", of which in or within 4 of the chocolate (the new rule rejects them) "+wet);
    }
    static void Barrier(){
        double step=2; int nx=(int)((E-W)/step), nz=(int)((2*H)/step);
        var dry=new bool[nx,nz]; var seen=new bool[nx,nz];
        for(int i=0;i<nx;i++) for(int j=0;j<nz;j++){ double x=W+1+i*step, z=-H+1+j*step; bool solid = Flat(x,z,M1[0],M1[1])<=M1R; dry[i,j]= Liquid(x,z)>=0 && !solid; }
        int si=0, sj=(int)((Entrance[1]+H-1)/step);
        var q=new Queue<int[]>(); q.Enqueue(new int[]{si,sj}); seen[si,sj]=true; int count=0;
        while(q.Count>0){ var c=q.Dequeue(); count++; foreach(var d in new int[][]{new int[]{1,0},new int[]{-1,0},new int[]{0,1},new int[]{0,-1}}){ int a=c[0]+d[0], b=c[1]+d[1]; if(a<0||b<0||a>=nx||b>=nz) continue; if(seen[a,b]||!dry[a,b]) continue; seen[a,b]=true; q.Enqueue(new int[]{a,b}); } }
        int ti=(int)((Torta[0]-W-1)/step), tj=(int)((Torta[1]+H-1)/step);
        Check(!seen[ti,tj], "BARRIER: the Torta is reachable dry from the entrance");
        Note("barrier: entrance-bank dry cells "+count+"; torta reached: "+seen[ti,tj]);
        var bank=new List<string>();
        foreach(var n in Nests){ int a=(int)Math.Round((n.x-W-1)/step), b=(int)Math.Round((n.z+H-1)/step); if(n.x>250) bank.Add(n.id+":"+(seen[a,b]?"E":"C")); }
        foreach(var d in Docks){ int a=(int)Math.Round((d.sx-W-1)/step), b=(int)Math.Round((d.sz+H-1)/step); bank.Add("dock"+d.id+":"+(seen[a,b]?"E":"C")); }
        Note("  banks (E entrance, C cake): "+string.Join(" ",bank));
    }
    static void Raft(){
        double step=2; int nx=(int)((E-W)/step)+1, nz=(int)((2*H)/step)+1; var ok=new bool[nx,nz]; var seen=new bool[nx,nz];
        int cells=0;
        for(int i=0;i<nx;i++) for(int j=0;j<nz;j++){ double x=W+i*step, z=-H+j*step; ok[i,j]= Liquid(x,z)<=-3; if(ok[i,j]) cells++; }
        var a=Docks[0]; int si=(int)Math.Round((a.tx-W)/step), sj=(int)Math.Round((a.tz+H)/step);
        var q=new Queue<int[]>(); q.Enqueue(new int[]{si,sj}); seen[si,sj]=true; int n=0;
        while(q.Count>0){ var c=q.Dequeue(); n++; foreach(var d in new int[][]{new int[]{1,0},new int[]{-1,0},new int[]{0,1},new int[]{0,-1}}){ int u=c[0]+d[0], v=c[1]+d[1]; if(u<0||v<0||u>=nx||v>=nz) continue; if(seen[u,v]||!ok[u,v]) continue; seen[u,v]=true; q.Enqueue(new int[]{u,v}); } }
        Note("raft hull cells (2-stud grid, liquid <= -3) "+cells+", reachable from dock A "+n);
        Check(n==cells,"some hull water is cut off");
        foreach(var d in Docks){ int u=(int)Math.Round((d.tx-W)/step), v=(int)Math.Round((d.tz+H)/step); Check(seen[u,v],"raft cannot reach dock "+d.id); }
        int pu=(int)Math.Round((Pool[0]-W)/step), pv=(int)Math.Round((Pool[1]+H)/step); Note("raft reaches pool: "+seen[pu,pv]);
        double minx=1e9,maxx=-1e9; for(int i=0;i<nx;i++) for(int j=0;j<nz;j++) if(seen[i,j]){ minx=Math.Min(minx,W+i*step); maxx=Math.Max(maxx,W+i*step);}
        Note("raft x range "+minx+".."+maxx);
        // one-stud open hull cells over the whole plot (V3-17 v9 pin)
        int open=0; for(int x=(int)W; x<(int)E; x++) for(int z=(int)-H; z<(int)H; z++) if(Liquid(x+0.5,z+0.5)<=-3) open++;
        Note("open hull one-stud cells "+open);
        // wet area and share
        int wet=0; for(int x=(int)W; x<(int)E; x+=2) for(int z=(int)-H; z<(int)H; z+=2) if(Liquid(x+1,z+1)<0) wet+=4;
        Note("wet area "+wet+" sq studs, share "+F1(100.0*wet/(1120*520))+"%");
        // every x column meets chocolate (except under M1)
        int dryCols=0; for(int x=(int)W+2; x<=(int)E-2; x+=2){ bool hit=false; for(int z=(int)-H+1; z<(int)H; z+=2) if(Liquid(x,z)<0){hit=true;break;} if(!hit && Math.Abs(x-M1[0])>M1R) dryCols++; }
        Check(dryCols==0,"dry x columns "+dryCols);
        // centreline sails for a hull
        int bad=0; for(int i=1;i<River.Count-1;i++){ var p=River[i]; if(!(Liquid(p[0],p[1])<=-3)) bad++; } Check(bad==0,"river points that do not float a hull "+bad);
    }
    static double[] Flow(double x,double z){
        double liquid=Liquid(x,z); if(liquid>=0) return new double[]{0,0};
        double best=double.MaxValue; for(int i=0;i<River.Count-1;i++) best=Math.Min(best,Seg(x,z,River[i][0],River[i][1],River[i+1][0],River[i+1][1]));
        double vx=0,vz=0; for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1]; double share=1-(Seg(x,z,a[0],a[1],b[0],b[1])-best)/6; double dx=b[0]-a[0], dz=b[1]-a[1], L=Math.Sqrt(dx*dx+dz*dz); if(share>0&&L>0){ double w=share*share; vx+=w*dx/L; vz+=w*dz/L; } }
        double norm=Math.Sqrt(vx*vx+vz*vz); if(norm<1e-6) return new double[]{0,0};
        double lake=double.MaxValue; foreach(var d in Lake) lake=Math.Min(lake,Flat(x,z,d[0],d[1])-d[2]);
        double inLake=Math.Max(0,Math.Min(1,-lake/8)); double speed=4+(1.5-4)*inLake; speed*=Math.Max(0,Math.Min(1,-liquid/2));
        return new double[]{vx/norm*speed, vz/norm*speed}; }
    static void CurrentSmooth(){
        double worst=0; double wx=0,wz=0; int checks=0;
        for(double x=W; x<=E; x+=1) for(double z=-H; z<=H; z+=1){ var f=Flow(x,z); if(Math.Sqrt(f[0]*f[0]+f[1]*f[1])<0.5) continue; foreach(var d in new double[][]{new double[]{1,0},new double[]{0,1}}){ var g=Flow(x+d[0],z+d[1]); if(Math.Sqrt(g[0]*g[0]+g[1]*g[1])<0.5) continue; double a=Math.Atan2(f[1],f[0]), b=Math.Atan2(g[1],g[0]); double dd=Math.Abs(a-b); if(dd>Math.PI) dd=2*Math.PI-dd; dd*=180/Math.PI; checks++; if(dd>worst){worst=dd; wx=x; wz=z;} } }
        Note("current: worst direction change "+F2(worst)+" deg/stud at ("+wx+","+wz+") over "+checks+" checks");
        Check(worst<=15, "current turns too fast");
    }
    static void Report(){
        foreach(var n in Nests) Note(string.Format(IC,"NEST {0,-4} {1,-10} local ({2},{3}) world ({4},{5}) depth {6:F1} route {7:F1} liquid {8:F1} boss {9:F1} nearest-piece-r {10:F1}", n.id, n.kind, n.x, n.z, 672+n.x, -3+n.z, Depth(n.x,n.z), RouteDist(n.x,n.z), Liquid(n.x,n.z), Flat(n.x,n.z,Torta[0],Torta[1]), Pieces().Min(p=>Flat(p.x,p.z,n.x,n.z)-p.r)));
        foreach(var p in Pieces()) Note(string.Format(IC,"PIECE {0} {1} ({2:F1},{3:F1}) r {4:F2}: liquid-r {5:F1}, route-r-7 {6:F1}, depth-r {7:F1}, boss-r {8:F1}", p.kind,p.id,p.x,p.z,p.r,Liquid(p.x,p.z)-p.r,RouteDist(p.x,p.z)-p.r-7,Depth(p.x,p.z)-p.r,Flat(p.x,p.z,Torta[0],Torta[1])-p.r));
        foreach(var k in RouteOrder){ var pts=Routes[k]; double mn=1e9; double mx=0, mz=0;
            for(int i=0;i<pts.Count-1;i++){ var a=pts[i]; var b=pts[i+1]; int n=Math.Max(1,(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])));
                for(int s=0;s<=n;s++){ double x=a[0]+(b[0]-a[0])*s/n, z=a[1]+(b[1]-a[1])*s/n; if(OnBridge(x,z,false)!=null) continue; double d=Liquid(x,z); if(d<mn){mn=d;mx=x;mz=z;} } }
            double len=0; for(int i=0;i<pts.Count-1;i++) len+=Flat(pts[i][0],pts[i][1],pts[i+1][0],pts[i+1][1]);
            Note("route "+k+": length "+F1(len)+"; min liquid off bridges "+F2(mn)+" at ("+F1(mx)+","+F1(mz)+")"); }
        // tightest slacks
        var rows=new List<Tuple<double,string>>();
        foreach(var n in Nests) rows.Add(Tuple.Create(Liquid(n.x,n.z)-6, "nest "+n.id+" liquid "+F2(Liquid(n.x,n.z))+" (>= 6)"));
        foreach(var p in Posts) rows.Add(Tuple.Create(Liquid(p.x,p.z)-8, "post "+p.id+" liquid "+F2(Liquid(p.x,p.z))+" (>= 8)"));
        foreach(var p in Pieces()) if(p.kind!="dock" && p.id!="M1") rows.Add(Tuple.Create(Liquid(p.x,p.z)-p.r-2, p.kind+" "+p.id+" liquid-r "+F2(Liquid(p.x,p.z)-p.r)+" (>= 2)"));
        foreach(var n in Nests) rows.Add(Tuple.Create(Math.Min(RouteDist(n.x,n.z)-11, 52-RouteDist(n.x,n.z)), "nest "+n.id+" route "+F2(RouteDist(n.x,n.z))+" (11..52)"));
        foreach(var p in Pieces()) rows.Add(Tuple.Create(RouteDist(p.x,p.z)-p.r-7-3, p.kind+" "+p.id+" route-r-7 "+F2(RouteDist(p.x,p.z)-p.r-7)+" (>= 3)"));
        var ring=new Dictionary<string,double[]>{{"Comun",new double[]{0,97.5}},{"Rara",new double[]{97.5,208}},{"Epica",new double[]{208,260}},{"Legendaria",new double[]{208,260}}};
        foreach(var n in Nests){ var b=ring[n.kind]; double d=Depth(n.x,n.z); rows.Add(Tuple.Create(Math.Min(d-b[0],b[1]-d),"nest "+n.id+" depth "+F1(d)+" ring "+b[0]+".."+b[1])); }
        foreach(var p in Pieces()){ foreach(var n in Nests) rows.Add(Tuple.Create(Flat(p.x,p.z,n.x,n.z)-p.r-8, p.kind+" "+p.id+" to nest "+n.id+" "+F2(Flat(p.x,p.z,n.x,n.z)-p.r)+" (>= 8)"));
            foreach(var q in Posts) rows.Add(Tuple.Create(Flat(p.x,p.z,q.x,q.z)-p.r-6, p.kind+" "+p.id+" to post "+q.id+" "+F2(Flat(p.x,p.z,q.x,q.z)-p.r)+" (>= 6)")); }
        foreach(var n in Nests) foreach(var s in Syrup) rows.Add(Tuple.Create(Flat(n.x,n.z,s.x,s.z)-s.r-6,"nest "+n.id+" syrup "+s.id+" "+F2(Flat(n.x,n.z,s.x,s.z))+" (>= "+(s.r+6)+")"));
        foreach(var p in Posts.Where(q=>q.kind=="extra")) { foreach(var s in Syrup) rows.Add(Tuple.Create(Flat(p.x,p.z,s.x,s.z)-s.r-2,"post "+p.id+" syrup "+s.id+" "+F2(Flat(p.x,p.z,s.x,s.z))+" (>= "+(s.r+2)+")"));
            rows.Add(Tuple.Create(T[p.creature][0]-RouteDist(p.x,p.z),"post "+p.id+" route "+F2(RouteDist(p.x,p.z))+" (<= wake "+T[p.creature][0]+")")); }
        rows.Add(Tuple.Create(Depth(M1[0],M1[1])-(M1R-0.5),"M1 depth "+F2(Depth(M1[0],M1[1]))+" (>= r-0.5 "+F2(M1R-0.5)+")"));
        foreach(var r in rows.OrderBy(t=>t.Item1).Take(40)) Note(string.Format(IC,"  slack {0,7:F2}  {1}", r.Item1, r.Item2));
    }
}

