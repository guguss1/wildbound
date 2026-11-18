using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

public static class Geo {
    // ---------------- data ----------------
    public const double W = -260, E = 860, H = 260;
    public static double S = 0.6; // M1 kit scale
    public class P { public string id; public double x, z, r; public string kind; public P(string i,double a,double b,double c=0,string k=""){id=i;x=a;z=b;r=c;kind=k;} }
    public static List<double[]> River = new List<double[]>();
    public static double[] Pool; public static double PoolR = 20;
    public static double[] Fall;
    public static double[] M1;
    public static List<double[]> Lake = new List<double[]>();
    public static List<P> Islands = new List<P>();
    public static Dictionary<string, List<double[]>> Routes = new Dictionary<string, List<double[]>>();
    public static List<string> RouteOrder = new List<string>();
    public class Br { public string id, route; public double[] from, to; public double at, length, width=15, deck=12.5, ramp=28; public double x,z,ux,uz; public bool gaps=false; }
    public static List<Br> Bridges = new List<Br>();
    public class Dock { public string id; public double sx, sz, tx, tz; }
    public static List<Dock> Docks = new List<Dock>();
    public static List<P> Nests = new List<P>();
    public static List<P> Posts = new List<P>();
    public static List<P> Traps = new List<P>();
    public static List<P> Houses = new List<P>();
    public static List<P> Mountains = new List<P>();
    public static List<P> Hills = new List<P>();
    public static List<P> Platforms = new List<P>();
    public static List<P> Keep = new List<P>();
    public static double[] Torta = { 748.2, 0 }; public static double TortaR = 42, Plaza = 58, Terr = 76;
    public static double[] Portal = { -31.2, 0 }, Entrance = { -260, 0 }, Junction = {0,0};
    public static double[] Lic = { -161.2, 0 }; public static double LicScale = 0.8;
    public static double[] Cake = { -195, 145.6 };

    // ---------------- geometry ----------------
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
    public static double Liquid(double x,double z){
        double best=RiverDist(x,z);
        best=Math.Min(best, Flat(x,z,Pool[0],Pool[1])-PoolR);
        foreach(var d in Lake) best=Math.Min(best, Flat(x,z,d[0],d[1])-d[2]);
        return Math.Max(best, -IslandDist(x,z));
    }
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

    public static void Build(){
        // M1 at the south-west corner, facing RIVER[2]
        M1 = new double[]{ -228, -228 };
        double[] r2 = { -125, -221 };
        double yaw = FaceYaw(M1[0],M1[1],r2[0],r2[1]);
        Pool = KitPoint(M1[0],M1[1],yaw,S,0.5653,-60);
        Fall = KitPoint(M1[0],M1[1],yaw,S,0.5653,-31);
        var outlet = KitPoint(M1[0],M1[1],yaw,S,0.5653,-86.7);
        Note(string.Format("M1 yaw {0:F4}; pool ({1:F2},{2:F2}); waterfall ({3:F2},{4:F2}); outlet ({5:F2},{6:F2})", yaw, Pool[0],Pool[1],Fall[0],Fall[1],outlet[0],outlet[1]));
        River.Add(new double[]{ Math.Round(outlet[0],2), Math.Round(outlet[1],2), 30 });
        foreach(var p in new double[][]{
            new double[]{-125,-221,50}, new double[]{-60,-225,64}, new double[]{40,-224,64}, new double[]{140,-225,64},
            new double[]{240,-224,64}, new double[]{330,-218,64}, new double[]{400,-210,60}, new double[]{445,-200,60},
            new double[]{470,-175,60}, new double[]{470,175,60}, new double[]{510,205,90}, new double[]{575,200,110},
            new double[]{650,198,120}, new double[]{760,196,120}, new double[]{860,194,120} }) River.Add(p);
        Lake.Add(new double[]{670,170,52}); Lake.Add(new double[]{580,172,34}); Lake.Add(new double[]{-160,-222,20}); Lake.Add(new double[]{240,-222,24}); Lake.Add(new double[]{815,170,32});
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
        AddBridge("Top","north",new double[]{320,125},new double[]{620,125},150,64);
        AddBridge("Main","main",new double[]{0,0},new double[]{690.2,0},470,64);
        AddBridge("Bottom","south",new double[]{320,-125},new double[]{640,-125},150,64);
        Docks.Add(new Dock{id="A",sx=-160,sz=-187,tx=-160,tz=-210});
        Docks.Add(new Dock{id="B",sx=240,sz=-186,tx=240,tz=-208});
        Docks.Add(new Dock{id="C",sx=670,sz=104,tx=670,tz=128});
        Docks.Add(new Dock{id="D",sx=815,sz=124,tx=815,tz=148});
        // nests
        string[] ns = {
         "C1,Comun,-208,-23.4","C2,Comun,-182,31.2","C3,Comun,-117,-171.6","C4,Comun,-80.6,169","C5,Comun,78,197.6",
         "R1,Rara,-101.4,-39","R2,Rara,-101.4,44.2","R3,Rara,-58.5,-120.9","R4,Rara,-26,123.5","E1,Epica,-44.2,-26","E2,Epica,-44.2,31.2",
         "L1,Legendaria,46.8,-28.6","C6,Comun,13,-166","C7,Comun,6.5,184.6","C8,Comun,110,-178","C9,Comun,-175.5,-80.6","C10,Comun,-40,-166",
         "R5,Rara,114.4,145.6","R6,Rara,124.8,-158.6","R7,Rara,-150.8,75.4","E3,Epica,0,46.8","R8,Rara,-143,123.5","R9,Rara,-78,91",
         "R10,Rara,-13,-58.5","R11,Rara,46.8,96.2","C11,Comun,-39,195","C12,Comun,-169,-130","C13,Comun,150,-172",
         // v9 new
         "C14,Comun,340,-164","C15,Comun,350,166","R12,Rara,280,-80","R13,Rara,280,80","R14,Rara,400,-150","R15,Rara,410,150","E4,Epica,370,38",
         "C16,Comun,530,-170","C17,Comun,620,-172","C18,Comun,700,-215","C19,Comun,575,-172","R16,Rara,600,-75","R17,Rara,660,-95",
         "R18,Rara,560,95","R19,Rara,530,-80","E5,Epica,580,40","E6,Epica,650,-40" };
        foreach(var s in ns){ var f=s.Split(','); Nests.Add(new P(f[0],double.Parse(f[2],System.Globalization.CultureInfo.InvariantCulture),double.Parse(f[3],System.Globalization.CultureInfo.InvariantCulture),0,f[1])); }
        string[] ps = {
         "candyNest,-214,-17.4","candyNestR1,-93.4,-47","candyNestC3,-129,-179.6","bossHome,698.2,0","bossTerritory,748.2,0",
         "candyNestC2,-188,44.2","candyNestR2,-96.4,56.2","candyNestR3,-46.5,-110.9","candyNestR4,84,211.6","candyNestC4,-88.6,181",
         "candyPostC7,13.5,175.6","candyPostR6,131.8,-153.6","candyPostC8,105,-166","candyPostC9,-164.5,-76.6","candyPostR7,-160.8,83.4",
         "candyPostR5,122.4,155.6","candyPostC6,3,-158","candyPostC10,-28,-158","candyPostE3,-12,46.8","candyPostR8,-131,123.5",
         "candyPostR9,-66,91","candyPostR10,-4,-50.5","candyPostC11,-39,183","candyPostC12,-157,-130","candyPostC13,138,-171","candyPostR11,37.8,98.2",
         "candyPostE4,382,38","candyPostR16,588,-75","candyPostE5,592,40","candyPostR12,292,-80","candyPostC16,530,-158",
         "candyPostR13,292,80","candyPostC18,688,-215","candyPostR15,398,150" };
        foreach(var s in ps){ var f=s.Split(','); Posts.Add(new P(f[0],double.Parse(f[1],System.Globalization.CultureInfo.InvariantCulture),double.Parse(f[2],System.Globalization.CultureInfo.InvariantCulture))); }
        Traps.Add(new P("riverside",-126.1,-71.5)); Traps.Add(new P("path",-93.6,8)); Traps.Add(new P("rareNest",-109.4,-30));
        Houses.Add(new P("H1",-192.4,215.8,28,"CV3_SweetHouse")); Houses.Add(new P("H2",-130,227.5,15,"CV3_CaramelTower"));
        Houses.Add(new P("H3",-10,-118,22.4,"CV3_ChocoHouse")); Houses.Add(new P("H4",231.4,130,20,"CV3_SweetHouse"));
        Houses.Add(new P("H5",-218.4,-106.6,21,"CV3_CaramelTower")); Houses.Add(new P("H6",45,-125,16,"CV3_ChocoHouse"));
        Houses.Add(new P("H7",143,231.4,20,"CV3_SweetHouse")); Houses.Add(new P("H8",380,-60,20,"CV3_SweetHouse"));
        Houses.Add(new P("H9",600,-200,16,"CV3_ChocoHouse")); Houses.Add(new P("H10",530,70,15,"CV3_CaramelTower"));
        Mountains.Add(new P("M1",M1[0],M1[1],54*S)); Mountains.Add(new P("M2",234,-117,14.2)); Mountains.Add(new P("M3",98.8,243.1,13.1));
        Mountains.Add(new P("M4",214.5,-156,13.1)); Mountains.Add(new P("M5",800,-236,13.1)); Mountains.Add(new P("M6",-243.1,243.1,13.1));
        Mountains.Add(new P("M7",790,-170,24.3)); Mountains.Add(new P("M8",300,230,14.2));
        Hills.Add(new P("Hill_1",858,-247,17.75)); Hills.Add(new P("Hill_2",858,-190,16)); Hills.Add(new P("Hill_3",858,-125,17.75));
        Hills.Add(new P("Hill_4",858,-60,16)); Hills.Add(new P("Hill_5",858,60,16)); Hills.Add(new P("Hill_6",858,105,9.94));
        Keep.Add(new P("pond",214.5,195,26)); Keep.Add(new P("hive",-78,240.5,10));
    }
    static void AddBridge(string id,string route,double[] from,double[] to,double at,double length){
        var B=new Br{id=id,route=route,from=from,to=to,at=at,length=length};
        double dx=to[0]-from[0], dz=to[1]-from[1], L=Math.Sqrt(dx*dx+dz*dz);
        B.ux=dx/L; B.uz=dz/L; B.x=from[0]+B.ux*at; B.z=from[1]+B.uz*at; Bridges.Add(B); }

    public static string Run(){
        Build();
        var C = new { nest=6.0, post=8.0, pNest=8.0, pPost=6.0, pRoute=3.0, apart=2.0, trap=10.0, edge=2.0 };
        double half=7;
        // V3-2 river
        double len=0; for(int i=0;i<River.Count-1;i++) len+=Flat(River[i][0],River[i][1],River[i+1][0],River[i+1][1]);
        Note(string.Format("river length {0:F1}, points {1}", len, River.Count));
        Check(Flat(River[0][0],River[0][1],Pool[0],Pool[1])<=PoolR+1, "river starts in pool: "+Flat(River[0][0],River[0][1],Pool[0],Pool[1]));
        var last=River[River.Count-1]; Check(Math.Abs(Depth(last[0],last[1]))<0.01 && last[0]>0, "ends on east edge");
        double minMargin=1e9; int minI=0;
        for(int i=0;i<River.Count;i++){ var p=River[i]; if(i>0) Check(p[2]>=50,"width pt "+(i+1));
            if(i<River.Count-1){ double m=Depth(p[0],p[1])-p[2]/2; Check(m>=2,"pt "+(i+1)+" leaves plot "+m); if(m<minMargin){minMargin=m;minI=i+1;} } }
        Note(string.Format("tightest point-in-plot margin: pt {0} = {1:F2}", minI, minMargin));
        // V3-3
        Check(Flat(Fall[0],Fall[1],M1[0],M1[1])<54*S, "fall on mountain"); Check(Flat(Fall[0],Fall[1],Pool[0],Pool[1])<PoolR, "fall in pool "+Flat(Fall[0],Fall[1],Pool[0],Pool[1]));
        Note(string.Format("fall to pool {0:F2} (< {1}); M1 depth {2:F2} vs r {3:F2}", Flat(Fall[0],Fall[1],Pool[0],Pool[1]), PoolR, Depth(M1[0],M1[1]), 54*S));
        // samples gap
        for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1]; int n=(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])/2);
            for(int s=0;s<n;s++){ double t=(double)s/n, x=a[0]+(b[0]-a[0])*t, z=a[1]+(b[1]-a[1])*t; Check(Liquid(x,z)<0 || IslandDist(x,z)<=0, "gap at "+x+","+z);} }
        // V3-4 routes
        foreach(var k in RouteOrder){ var pts=Routes[k];
            for(int i=0;i<pts.Count-1;i++){ var a=pts[i]; var b=pts[i+1]; int n=Math.Max(1,(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])/2));
                for(int s=0;s<=n;s++){ double x=a[0]+(b[0]-a[0])*s/n, z=a[1]+(b[1]-a[1])*s/n; double d=Liquid(x,z);
                    if(d<=0) Check(OnBridge(x,z,true)!=null, k+" wades at "+x.ToString("F1")+","+z.ToString("F1"));
                    if(d<half) Check(OnBridge(x,z,false)!=null, k+" edge wades at "+x.ToString("F1")+","+z.ToString("F1")); } } }
        foreach(var B in Bridges){
            Check(Math.Atan2(B.deck,B.ramp)*180/Math.PI<=25,"ramp "+B.id);
            Check(B.at-B.length/2-B.ramp>=-1e-6 && B.at+B.length/2+B.ramp<=Flat(B.from[0],B.from[1],B.to[0],B.to[1])+1e-6,"on leg "+B.id);
            Check(Liquid(B.x,B.z)<0,"over choc "+B.id);
            int lo=(int)Math.Floor(B.length/2)+9; double maxWetPast=-1;
            for(int s=-lo;s<=lo;s++){ double x=B.x+B.ux*s, z=B.z+B.uz*s; if(Liquid(x,z)<=1){ if(Math.Abs(s)>B.length/2) Check(false,B.id+" choc past deck "+s); maxWetPast=Math.Max(maxWetPast,Math.Abs(s)); } }
            Note(string.Format("bridge {0} centre ({1:F1},{2:F1}) wet(<=1) to |along| {3} of deck half {4}", B.id,B.x,B.z,maxWetPast,B.length/2));
            // ramp ends on land
            foreach(int sgn in new int[]{-1,1}){ double x=B.x+B.ux*sgn*(B.length/2), z=B.z+B.uz*sgn*(B.length/2); Note(string.Format("  {0} deck end {1}: liquid {2:F2}", B.id, sgn, Liquid(x,z))); }
        }
        // V3-5
        foreach(var n in Nests){ double d=Liquid(n.x,n.z); Check(d>=C.nest,"nest "+n.id+" liquid "+d.ToString("F2")); }
        foreach(var p in Posts){ double d=Liquid(p.x,p.z); Check(d>=C.post,"post "+p.id+" liquid "+d.ToString("F2")); }
        foreach(var t in Traps){ Check(Liquid(t.x,t.z)>=C.trap,"trap "+t.id); }
        Check(Liquid(Torta[0],Torta[1])>=Terr,"boss terr liquid "+Liquid(Torta[0],Torta[1]));
        Note(string.Format("boss centre liquid {0:F2} (>= 76)", Liquid(Torta[0],Torta[1])));
        Check(Liquid(Portal[0],Portal[1])>=16,"portal"); Check(Liquid(Entrance[0],Entrance[1])>=28,"entrance "+Liquid(Entrance[0],Entrance[1]));
        foreach(var k in Keep) Check(Liquid(k.x,k.z)>=k.r,"keep "+k.id+" "+Liquid(k.x,k.z));
        // V3-6
        var pieces=Pieces();
        foreach(var p in pieces){ string L=p.kind+" "+p.id;
            foreach(var n in Nests) Check(Flat(p.x,p.z,n.x,n.z)-p.r>=C.pNest, L+" on nest "+n.id+" "+(Flat(p.x,p.z,n.x,n.z)-p.r).ToString("F2"));
            foreach(var q in Posts) Check(Flat(p.x,p.z,q.x,q.z)-p.r>=C.pPost, L+" on post "+q.id+" "+(Flat(p.x,p.z,q.x,q.z)-p.r).ToString("F2"));
            foreach(var t in Traps) Check(Flat(p.x,p.z,t.x,t.z)-p.r>=C.trap, L+" on trap");
            Check(RouteDist(p.x,p.z)-p.r-half>=C.pRoute, L+" on route "+(RouteDist(p.x,p.z)-p.r-half).ToString("F2"));
            Check(Flat(p.x,p.z,Torta[0],Torta[1])-p.r>=Terr, L+" in boss terr");
            Check(Flat(p.x,p.z,Portal[0],Portal[1])-p.r>=16, L+" portal");
            Check(Flat(p.x,p.z,Entrance[0],Entrance[1])-p.r>=28, L+" entrance");
            foreach(var k in Keep) Check(Flat(p.x,p.z,k.x,k.z)-p.r-k.r>=C.apart, L+" on "+k.id);
            if(p.kind=="mountain") Check(Depth(p.x,p.z)>=p.r-0.5, L+" leaves plot "+Depth(p.x,p.z));
            else Check(Depth(p.x,p.z)-p.r>=C.edge, L+" by edge "+(Depth(p.x,p.z)-p.r));
            bool source = p.kind=="mountain" && p.id=="M1";
            if(!source && p.kind!="dock") Check(Liquid(p.x,p.z)-p.r>=C.apart, L+" in choc "+(Liquid(p.x,p.z)-p.r).ToString("F2"));
            if(p.kind!="dock") Check(!NearBridge(p.x,p.z,p.r), L+" on bridge");
        }
        for(int i=0;i<pieces.Count;i++) for(int j=i+1;j<pieces.Count;j++){ var a=pieces[i]; var b=pieces[j];
            bool same = a.kind=="dock" && b.kind=="dock" && a.id.Substring(0,1)==b.id.Substring(0,1);
            if(!(a.kind=="cake"&&b.kind=="cake") && !same) Check(Flat(a.x,a.z,b.x,b.z)-a.r-b.r>=C.apart, a.kind+" "+a.id+" touches "+b.kind+" "+b.id); }
        // V3-7 doors
        foreach(var h in Houses){ double yaw=FaceYaw(h.x,h.z,0,0)+(h.kind=="CV3_CaramelTower"?Math.PI:0);
            double lx=-Math.Sin(yaw), lz=-Math.Cos(yaw); double dx=h.x+lx*(h.r+4), dz=h.z+lz*(h.r+4);
            Check(Depth(dx,dz)>=5, h.id+" door edge"); Check(Liquid(dx,dz)>=4, h.id+" door choc "+Liquid(dx,dz));
            foreach(var p in pieces) if(!(p.kind=="house"&&p.id==h.id)) Check(Flat(dx,dz,p.x,p.z)-p.r>=4, h.id+" door faces "+p.id); }
        // V3-8 docks
        foreach(var d in Docks){ Check(Liquid(d.sx,d.sz)>0,"stand "+d.id+" "+Liquid(d.sx,d.sz)); Check(Liquid(d.tx,d.tz)<=-6,"tip "+d.id+" "+Liquid(d.tx,d.tz));
            Check(!NearBridge(d.tx,d.tz,6),"tip by bridge "+d.id);
            double dx=d.tx-d.sx, dz=d.tz-d.sz, L=Math.Sqrt(dx*dx+dz*dz);
            Check(Liquid(d.sx-dx/L*10,d.sz-dz/L*10)>0, "ramp foot "+d.id);
            Note(string.Format("dock {0}: stand liquid {1:F2}, tip liquid {2:F2}, ramp foot liquid {3:F2}", d.id, Liquid(d.sx,d.sz), Liquid(d.tx,d.tz), Liquid(d.sx-dx/L*10,d.sz-dz/L*10))); }
        for(int i=0;i<Docks.Count;i++) for(int j=i+1;j<Docks.Count;j++) Check(Flat(Docks[i].tx,Docks[i].tz,Docks[j].tx,Docks[j].tz)>12,"docks apart");
        // V3-9 platforms
        foreach(var pl in Platforms){ bool inside=false; foreach(var d in Lake) if(Flat(pl.x,pl.z,d[0],d[1])+pl.r<=d[2]) inside=true; Check(inside,"platform "+pl.id+" leaves lake"); Check(!NearBridge(pl.x,pl.z,pl.r),"platform on bridge"); }
        for(int i=0;i<Platforms.Count;i++) for(int j=i+1;j<Platforms.Count;j++) Check(Flat(Platforms[i].x,Platforms[i].z,Platforms[j].x,Platforms[j].z)-Platforms[i].r-Platforms[j].r>=2,"platforms touch");
        foreach(var isl in Islands){ foreach(var pl in Platforms) Check(Flat(isl.x,isl.z,pl.x,pl.z)-9.9-pl.r>=4,"island vs platform "+pl.id);
            bool inDisc=false; foreach(var d in Lake) if(Flat(isl.x,isl.z,d[0],d[1])+9.9<=d[2]) inDisc=true; Check(inDisc,"island in disc");
            foreach(var d in Docks){ Check(Flat(isl.x,isl.z,d.tx,d.tz)-9.9>=15,"island vs tip "+d.id); Check(Flat(isl.x,isl.z,d.sx,d.sz)-9.9>=20,"island vs stand "+d.id);} }
        // V3-15 hills
        foreach(var h in Hills){ foreach(var n in Nests) Check(Flat(h.x,h.z,n.x,n.z)-h.r>=8,h.id+" nest"); foreach(var q in Posts) Check(Flat(h.x,h.z,q.x,q.z)-h.r>=6,h.id+" post");
            Check(RouteDist(h.x,h.z)-h.r-half>=3,h.id+" route"); Check(Flat(h.x,h.z,Torta[0],Torta[1])-h.r>=Terr,h.id+" boss");
            foreach(var k in Keep) Check(Flat(h.x,h.z,k.x,k.z)-h.r-k.r>=2,h.id+" keep");
            foreach(var p in pieces) Check(Flat(h.x,h.z,p.x,p.z)-h.r-p.r>=2,h.id+" on "+p.kind+" "+p.id+" "+(Flat(h.x,h.z,p.x,p.z)-h.r-p.r).ToString("F2"));
            Check(Liquid(h.x,h.z)-h.r>=2,h.id+" choc "+(Liquid(h.x,h.z)-h.r).ToString("F2")); Check(h.x-h.r<E && h.x+h.r>E, h.id+" straddles"); }
        for(int i=0;i<Hills.Count;i++) for(int j=i+1;j<Hills.Count;j++) Check(Flat(Hills[i].x,Hills[i].z,Hills[j].x,Hills[j].z)-Hills[i].r-Hills[j].r>=2,"hills touch "+Hills[i].id+Hills[j].id);
        // Layout tests: nests
        var ring=new Dictionary<string,double[]>{{"Comun",new double[]{0,97.5}},{"Rara",new double[]{97.5,208}},{"Epica",new double[]{208,260}},{"Legendaria",new double[]{208,260}}};
        foreach(var n in Nests){ double dep=Depth(n.x,n.z); var b=ring[n.kind]; Check(dep>=b[0]&&dep<=b[1],"ring "+n.id+" "+dep);
            double rd=RouteDist(n.x,n.z), tt=Flat(n.x,n.z,Torta[0],Torta[1]);
            Check(rd>=11,"nest blocks path "+n.id+" "+rd.ToString("F1")); Check(rd<=52||tt<=Plaza,"unreachable "+n.id+" "+rd.ToString("F1"));
            Check(tt>=TortaR+6,"in torta"); Check(n.x<Torta[0],"behind torta "+n.id);
            foreach(var k in Keep) Check(Flat(n.x,n.z,k.x,k.z)>=k.r+20,"nest "+n.id+" on "+k.id);
            Check(Flat(n.x,n.z,Portal[0],Portal[1])>=16,"nest on portal");
            Check(Flat(n.x,n.z,Entrance[0],Entrance[1])>=39,"nest crowds entrance"); }
        for(int i=0;i<Nests.Count;i++) for(int j=i+1;j<Nests.Count;j++) Check(Flat(Nests[i].x,Nests[i].z,Nests[j].x,Nests[j].z)>=20, Nests[i].id+" touches "+Nests[j].id+" "+Flat(Nests[i].x,Nests[i].z,Nests[j].x,Nests[j].z).ToString("F1"));
        int num;
        foreach(var n in Nests) if(int.TryParse(n.id.Substring(1),out num) &&((n.id[0]=='C'&&num>=14)||(n.id[0]=='R'&&num>=12)||(n.id[0]=='E'&&num>=4))){
            Check(Flat(n.x,n.z,Torta[0],Torta[1])>=Terr+20,"new nest in boss terr "+n.id); Check(Flat(n.x,n.z,Entrance[0],Entrance[1])>=80,"new nest by entrance"); }
        // route points west of torta; routes out of boss sight for return routes
        foreach(var k in RouteOrder) foreach(var p in Routes[k]) Check(p[0]<Torta[0], "route point behind torta "+k);
        // houses in quarters
        // barrier: flood fill dry cells from entrance; torta must not be reached
        Barrier();
        // raft connectivity
        Raft();
        // current smoothness
        CurrentSmooth();
        // tight spots report
        Tight();
        Life();
        Hives();
        Extra();
        return Out.ToString();
    }

    static void Life(){
        // flocks: id, x, z, r, alt
        double[][] fl = { new double[]{-156,52,26,63}, new double[]{-104,-65,24,66}, new double[]{78,195,22,62}, new double[]{169,-143,22,65},
            new double[]{-90,-140,20,63}, new double[]{195,156,20,67}, new double[]{380,-110,24,64}, new double[]{620,-50,22,66} };
        int k=0; foreach(var f in fl){ k++; Check(Liquid(f[0],f[1])>=10, "flock F"+k+" over choc "+Liquid(f[0],f[1]).ToString("F1"));
            foreach(var h in Houses) Check(Flat(f[0],f[1],h.x,h.z)>=h.r+5, "flock F"+k+" on house "+h.id);
            double reach=f[2]+2.5; Check(f[0]-reach>=W+5 && f[0]+reach<=E-5 && Math.Abs(f[1])+reach<=H-5, "flock F"+k+" leaves plot");
            Check(Flat(f[0],f[1],Torta[0],Torta[1])-reach>=14+6, "flock F"+k+" torta");
            Note(string.Format("flock F{0} liquid {1:F1}", k, Liquid(f[0],f[1]))); }
        // fish: id x z heading
        object[][] fish = { new object[]{"River_W1",-100.0,-224.0,0.0}, new object[]{"River_W2",60.0,-226.0,0.0}, new object[]{"River_W3",300.0,-220.0,0.07},
            new object[]{"River_M1",470.0,-60.0,1.5708}, new object[]{"River_M2",470.0,60.0,1.5708}, new object[]{"Lake_1",600.0,160.0,0.2},
            new object[]{"Lake_2",655.0,140.0,0.0}, new object[]{"Lake_3",700.0,215.0,0.0}, new object[]{"Lake_4",620.0,205.0,-0.2}, new object[]{"River_E1",780.0,190.0,0.0} };
        int inLake=0;
        foreach(var f in fish){ string id=(string)f[0]; double x0=(double)f[1], z0=(double)f[2], h=(double)f[3];
            for(int s=0;s<=20;s++){ double u=s/20.0, x=x0+Math.Cos(h)*7*u, z=z0+Math.Sin(h)*7*u;
                Check(Liquid(x,z)<=-3, id+" leaves choc at "+u+" "+Liquid(x,z).ToString("F2"));
                foreach(var B in Bridges){ double a,c; Frame(B,x,z,out a,out c); Check(Math.Abs(c)>B.width/2+3 || Math.Abs(a)>B.length/2+B.ramp+3, id+" under bridge "+B.id); }
                foreach(var p in Platforms) Check(Flat(x,z,p.x,p.z)>=p.r+3, id+" into cookie");
                foreach(var d in Docks) Check(Flat(x,z,d.tx,d.tz)>=8, id+" at dock "+d.id);
                foreach(var isl in Islands) Check(Flat(x,z,isl.x,isl.z)>=isl.r+3, id+" at island"); }
            bool lake=false; foreach(var d in Lake) if(Flat(x0,z0,d[0],d[1])<d[2]) lake=true; if(lake) inLake++; }
        Note("fish in lake "+inLake+" of "+fish.Length);
        foreach(var d in Docks){ var fl2=Flow(d.tx,d.tz); Note(string.Format("current at dock {0} tip {1:F3}", d.id, Math.Sqrt(fl2[0]*fl2[0]+fl2[1]*fl2[1]))); }
        for(int i=0;i<Lake.Count;i++){ var fl3=Flow(Lake[i][0],Lake[i][1]); Note(string.Format("current at lake disc {0} centre {1:F3} dir ({2:F2},{3:F2})", i+1, Math.Sqrt(fl3[0]*fl3[0]+fl3[1]*fl3[1]), fl3[0], fl3[1])); }
        int open=0; for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1]; double mx=(a[0]+b[0])/2, mz=(a[1]+b[1])/2; double ld=double.MaxValue; foreach(var dd in Lake) ld=Math.Min(ld,Flat(mx,mz,dd[0],dd[1])-dd[2]); if(ld>=0 && Liquid(mx,mz)<=-2) open++; }
        Note("CU2 open legs "+open);
        // flowers
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
                        if(ok){ valid++; if(Liquid(x,z)<4){ wet++; Note(string.Format("  hive candidate in/by choc at ({0:F0},{1:F0}) liquid {2:F1}", x,z,Liquid(x,z))); } } } } } }
        Note("hive candidates "+cand+", valid "+valid+", in or within 4 of the chocolate "+wet);
    }
    static void Extra(){
        // islands: raft channel all round (hull 3) at foot+3
        foreach(var isl in Islands){ for(int a=0;a<36;a++){ double ang=a*Math.PI/18, x=isl.x+Math.Cos(ang)*(9.9+3), z=isl.z+Math.Sin(ang)*(9.9+3); Check(Liquid(x,z)<=-3,"island channel at "+a); } }
        // min hull band per river sample (w-6) and depth of every point
        // posts nearest nests for bind (new guardian posts)
        foreach(var id in new string[]{"candyPostE4","candyPostR16","candyPostE5"}){ var p=Posts.First(q=>q.id==id); var n=Nests.OrderBy(m=>Flat(m.x,m.z,p.x,p.z)).First(); Note(id+" binds "+n.id+" at "+Flat(n.x,n.z,p.x,p.z).ToString("F1")); }
        // posts apart (nearest other post)
        foreach(var p in Posts.Where(q=>q.id.StartsWith("candyPost") && (q.x>250))){ var o=Posts.Where(q=>q!=p).OrderBy(q=>Flat(q.x,q.z,p.x,p.z)).First(); Note(string.Format("  {0} nearest post {1} {2:F1}", p.id, o.id, Flat(o.x,o.z,p.x,p.z))); }
        // ambush reach: distance from bossTerritory
        // stair: torta steps far from liquid (min distance of the plaza disc)
        Note(string.Format("plaza edge to chocolate {0:F1}", Liquid(Torta[0],Torta[1])-Plaza));
        // houses: door points
        foreach(var h in Houses){ double yaw=FaceYaw(h.x,h.z,0,0)+(h.kind=="CV3_CaramelTower"?Math.PI:0); double dx=h.x-Math.Sin(yaw)*(h.r+4), dz=h.z-Math.Cos(yaw)*(h.r+4); Note(string.Format("  {0} door point ({1:F1},{2:F1}) liquid {3:F1} depth {4:F1}", h.id,dx,dz,Liquid(dx,dz),Depth(dx,dz))); }
        foreach(var k in RouteOrder){ var pts=Routes[k]; double mn=1e9; double mx=0, mz=0;
            for(int i=0;i<pts.Count-1;i++){ var a=pts[i]; var b=pts[i+1]; int n=Math.Max(1,(int)Math.Ceiling(Flat(a[0],a[1],b[0],b[1])/1));
                for(int s=0;s<=n;s++){ double x=a[0]+(b[0]-a[0])*s/n, z=a[1]+(b[1]-a[1])*s/n; if(OnBridge(x,z,false)!=null) continue; double d=Liquid(x,z); if(d<mn){mn=d;mx=x;mz=z;} } }
            Note(string.Format("route {0}: min liquid off bridges {1:F2} at ({2:F1},{3:F1})", k, mn, mx, mz)); }
        foreach(var n in Nests) Note(string.Format("NEST {0} {1} local ({2},{3}) world ({4},{5}) depth {6:F1} route {7:F1} liquid {8:F1}", n.id, n.kind, n.x, n.z, 672+n.x, -3+n.z, Depth(n.x,n.z), RouteDist(n.x,n.z), Liquid(n.x,n.z)));
        foreach(var p in Posts) Note(string.Format("POST {0} local ({1},{2}) world ({3},{4}) liquid {5:F1}", p.id, p.x, p.z, 672+p.x, -3+p.z, Liquid(p.x,p.z)));
        Note(string.Format("M1 to west edge {0:F2}, to -z edge {1:F2}, r {2:F2}", M1[0]-W, M1[1]+H, 54*S));
        foreach(var d in Docks){ double L=Flat(d.sx,d.sz,d.tx,d.tz); Note(string.Format("dock {0} stand-tip {1:F1}, deck {2:F1}, world stand ({3},{4}) tip ({5},{6})", d.id, L, L-5, 672+d.sx, -3+d.sz, 672+d.tx, -3+d.tz)); }
        // river samples min band per leg
        for(int i=0;i<River.Count-1;i++){ var a=River[i]; var b=River[i+1]; Note(string.Format("  leg {0}-{1}: ({2},{3})->({4},{5}) w {6} length {7:F1}", i+1,i+2,a[0],a[1],b[0],b[1],Math.Max(a[2],b[2]),Flat(a[0],a[1],b[0],b[1]))); }
    }

    static void Barrier(){
        double step=2; int nx=(int)((E-W)/step)+1, nz=(int)((2*H)/step)+1;
        var dry=new bool[nx,nz]; var seen=new bool[nx,nz];
        for(int i=0;i<nx;i++) for(int j=0;j<nz;j++){ double x=W+i*step, z=-H+j*step; bool solid = Flat(x,z,M1[0],M1[1])<=54*S; dry[i,j]= Liquid(x,z)>=0 && !solid; }
        int si=(int)((Entrance[0]+1-W)/step), sj=(int)((Entrance[1]+H)/step); si=1;
        var q=new Queue<int[]>(); q.Enqueue(new int[]{si,sj}); seen[si,sj]=true; int count=0;
        while(q.Count>0){ var c=q.Dequeue(); count++; foreach(var d in new int[][]{new int[]{1,0},new int[]{-1,0},new int[]{0,1},new int[]{0,-1}}){ int a=c[0]+d[0], b=c[1]+d[1]; if(a<0||b<0||a>=nx||b>=nz) continue; if(seen[a,b]||!dry[a,b]) continue; seen[a,b]=true; q.Enqueue(new int[]{a,b}); } }
        int ti=(int)((Torta[0]-W)/step), tj=(int)((Torta[1]+H)/step);
        Check(!seen[ti,tj], "BARRIER: the Torta is reachable dry from the entrance");
        Note("barrier: entrance-bank dry cells "+count+"; torta reached: "+seen[ti,tj]);
        // which banks are the new nests on
        foreach(var n in Nests){ int a=(int)Math.Round((n.x-W)/step), b=(int)Math.Round((n.z+H)/step); if(n.x>250) Note("  bank of "+n.id+": "+(seen[a,b]?"entrance":"cake")); }
        foreach(var d in Docks){ int a=(int)Math.Round((d.sx-W)/step), b=(int)Math.Round((d.sz+H)/step); Note("  bank of dock "+d.id+": "+(seen[a,b]?"entrance":"cake")); }
    }

    static bool Plot(double x,double z,double r){ return Depth(x,z)>=r; }
    static void Raft(){
        double step=2; int nx=(int)((E-W)/step)+1, nz=(int)((2*H)/step)+1; var ok=new bool[nx,nz]; var seen=new bool[nx,nz];
        int cells=0;
        for(int i=0;i<nx;i++) for(int j=0;j<nz;j++){ double x=W+i*step, z=-H+j*step; ok[i,j]= Liquid(x,z)<=-3 && Plot(x,z,3); if(ok[i,j]) cells++; }
        var a=Docks[0]; int si=(int)Math.Round((a.tx-W)/step), sj=(int)Math.Round((a.tz+H)/step);
        var q=new Queue<int[]>(); q.Enqueue(new int[]{si,sj}); seen[si,sj]=true; int n=0;
        while(q.Count>0){ var c=q.Dequeue(); n++; foreach(var d in new int[][]{new int[]{1,0},new int[]{-1,0},new int[]{0,1},new int[]{0,-1}}){ int u=c[0]+d[0], v=c[1]+d[1]; if(u<0||v<0||u>=nx||v>=nz) continue; if(seen[u,v]||!ok[u,v]) continue; seen[u,v]=true; q.Enqueue(new int[]{u,v}); } }
        Note("raft hull cells "+cells+", reachable from dock A "+n);
        foreach(var d in Docks){ int u=(int)Math.Round((d.tx-W)/step), v=(int)Math.Round((d.tz+H)/step); Check(seen[u,v],"raft cannot reach dock "+d.id); }
        int pu=(int)Math.Round((Pool[0]-W)/step), pv=(int)Math.Round((Pool[1]+H)/step); Note("raft reaches pool: "+seen[pu,pv]);
        // westmost and eastmost reachable x
        double minx=1e9,maxx=-1e9; for(int i=0;i<nx;i++) for(int j=0;j<nz;j++) if(seen[i,j]){ minx=Math.Min(minx,W+i*step); maxx=Math.Max(maxx,W+i*step);}
        Note(string.Format("raft x range {0}..{1}", minx, maxx));
        // narrowest hull band along the river (min over samples of the distance to bank)
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
        Note(string.Format("current: worst direction change {0:F2} deg/stud at ({1},{2}) over {3} checks", worst, wx, wz, checks));
        Check(worst<=15, "current turns too fast");
    }
    static void Tight(){
        var rows=new List<Tuple<double,string>>();
        foreach(var n in Nests) rows.Add(Tuple.Create(Liquid(n.x,n.z)-6, "nest "+n.id+" liquid "+Liquid(n.x,n.z).ToString("F2")+" (>=6)"));
        foreach(var p in Posts) rows.Add(Tuple.Create(Liquid(p.x,p.z)-8, "post "+p.id+" liquid "+Liquid(p.x,p.z).ToString("F2")+" (>=8)"));
        foreach(var p in Pieces()) if(p.kind!="dock" && !(p.id=="M1")) rows.Add(Tuple.Create(Liquid(p.x,p.z)-p.r-2, p.kind+" "+p.id+" liquid-r "+(Liquid(p.x,p.z)-p.r).ToString("F2")+" (>=2)"));
        foreach(var n in Nests) rows.Add(Tuple.Create(Math.Min(RouteDist(n.x,n.z)-11, 52-RouteDist(n.x,n.z)), "nest "+n.id+" route "+RouteDist(n.x,n.z).ToString("F2")+" (11..52)"));
        foreach(var p in Pieces()) rows.Add(Tuple.Create(RouteDist(p.x,p.z)-p.r-7-3, p.kind+" "+p.id+" route-r-7 "+(RouteDist(p.x,p.z)-p.r-7).ToString("F2")+" (>=3)"));
        var ring=new Dictionary<string,double[]>{{"Comun",new double[]{0,97.5}},{"Rara",new double[]{97.5,208}},{"Epica",new double[]{208,260}},{"Legendaria",new double[]{208,260}}};
        foreach(var n in Nests){ var b=ring[n.kind]; double d=Depth(n.x,n.z); rows.Add(Tuple.Create(Math.Min(d-b[0],b[1]-d),"nest "+n.id+" depth "+d.ToString("F1")+" ring "+b[0]+".."+b[1])); }
        foreach(var p in Pieces()){ foreach(var n in Nests) rows.Add(Tuple.Create(Flat(p.x,p.z,n.x,n.z)-p.r-8, p.kind+" "+p.id+" to nest "+n.id+" "+(Flat(p.x,p.z,n.x,n.z)-p.r).ToString("F2")+" (>=8)"));
            foreach(var q in Posts) rows.Add(Tuple.Create(Flat(p.x,p.z,q.x,q.z)-p.r-6, p.kind+" "+p.id+" to post "+q.id+" "+(Flat(p.x,p.z,q.x,q.z)-p.r).ToString("F2")+" (>=6)")); }
        foreach(var r in rows.OrderBy(t=>t.Item1).Take(28)) Note(string.Format("  slack {0,7:F2}  {1}", r.Item1, r.Item2));
    }
}


