param([string]$Mode = "check")
# v9 least-churn geometry checker (plot-local: world = local + (672, -3))
$ErrorActionPreference = "Stop"
function Flat([double]$ax,[double]$az,[double]$bx,[double]$bz){ [math]::Sqrt(($ax-$bx)*($ax-$bx)+($az-$bz)*($az-$bz)) }
function SegD([double]$x,[double]$z,[double]$ax,[double]$az,[double]$bx,[double]$bz){ $dx=$bx-$ax;$dz=$bz-$az;$l2=$dx*$dx+$dz*$dz;$t=0; if($l2 -gt 0){$t=(($x-$ax)*$dx+($z-$az)*$dz)/$l2; if($t -lt 0){$t=0}; if($t -gt 1){$t=1}}; Flat $x $z ($ax+$dx*$t) ($az+$dz*$t) }
$MINX=-260;$MAXX=860;$MINZ=-260;$MAXZ=260
function Depth([double]$x,[double]$z){ [math]::Min([math]::Min($x-$MINX,$MAXX-$x),[math]::Min($z-$MINZ,$MAXZ-$z)) }

# ---------------- M1 (source) and its kit water ----------------
$M1 = @{x=-232; z=-226; r=24.3; faceX=-180; faceZ=-220}
function KitPoint([double]$px,[double]$pz,[double]$yaw,[double]$s,[double]$KX,[double]$KZ){ $KX=$KX*$s;$KZ=$KZ*$s; @(($px+$KX*[math]::Cos($yaw)+$KZ*[math]::Sin($yaw)), ($pz-$KX*[math]::Sin($yaw)+$KZ*[math]::Cos($yaw))) }
$yaw=[math]::Atan2(-($M1.faceX-$M1.x), -($M1.faceZ-$M1.z))
$outlet = KitPoint $M1.x $M1.z $yaw 0.45 0.5653 -49.6671
$pool = KitPoint $M1.x $M1.z $yaw 0.45 0.5653 -37.6671
$wf = KitPoint $M1.x $M1.z $yaw 0.45 0.5653 (-37.6671 + 3/0.45)
$POOL=@{x=$pool[0];z=$pool[1];r=4.95}

# ---------------- river ----------------
$RIVER = @(
 @($outlet[0],$outlet[1],12),
 @(-190,-222.5,24),
 @(-165,-223,40),
 @(-130,-225,60),
 @(-70,-227,60),
 @(0,-223,60),
 @(70,-226,60),
 @(140,-222,60),
 @(200,-224,60),
 @(260,-212,70),
 @(325,-188,80),
 @(390,-150,80),
 @(460,-110,90),
 @(530,-85,90),
 @(610,-65,100),
 @(690,-55,100),
 @(750,-35,80),
 @(805,-5,80),
 @(860,-5,80)
)
$LAKE = @(@{x=610;z=-70;r=64}, @{x=655;z=-118;r=40})
$ISL = @(@{id="I1";x=640;z=-95;r=7;flat=5;foot=10.9})
function RiverD($x,$z){ $b=1e9; for($i=0;$i -lt $RIVER.Count-1;$i++){ $a=$RIVER[$i];$c=$RIVER[$i+1]; $d=(SegD $x $z $a[0] $a[1] $c[0] $c[1]) - [math]::Max($a[2],$c[2])/2; if($d -lt $b){$b=$d} }; $b }
function IslandD($x,$z){ $b=1e9; foreach($i in $ISL){ $d=(Flat $x $z $i.x $i.z)-$i.r; if($d -lt $b){$b=$d} }; $b }
function LiquidRaw($x,$z){ $b=RiverD $x $z; $p=(Flat $x $z $POOL.x $POOL.z)-$POOL.r; if($p -lt $b){$b=$p}; foreach($d in $LAKE){ $q=(Flat $x $z $d.x $d.z)-$d.r; if($q -lt $b){$b=$q} }; [math]::Max($b, -(IslandD $x $z)) }
# v9: outside the plot is dry (clip): liquid = max(raw, -depth)
function Liquid($x,$z){ [math]::Max((LiquidRaw $x $z), -(Depth $x $z)) }

# ---------------- routes ----------------
$S=1.3
$ROUTES = [ordered]@{
 main = @(@(-260,0),@(-143,0),@(0,0),@(90.2,0));
 left = @(@(-143,0),@(-130,-104),@(-65,-182),@(65,-182),@(117,-143),@(0,0));
 right = @(@(-143,0),@(-117,91),@(-52,156),@(52,156),@(104,130),@(0,0));
 deep = @(@(0,0),@(-31.2,0));
 east = @(@(104,130),@(200,96),@(320,96),@(420,150),@(620,150),@(760,55));
 south = @(@(117,-143),@(195,-86),@(300,-40),@(520,0),@(650,25),@(760,55));
 far = @(@(520,0),@(520,-225),@(760,-225),@(760,55))
}
function RouteD($x,$z){ $b=1e9; foreach($k in $ROUTES.Keys){ $r=$ROUTES[$k]; for($i=0;$i -lt $r.Count-1;$i++){ $d=SegD $x $z $r[$i][0] $r[$i][1] $r[$i+1][0] $r[$i+1][1]; if($d -lt $b){$b=$d} } }; $b }

# ---------------- bridges (raised) ----------------
$BB=@{width=15;deck=13;ramp=28}
$BROWS=@(
 @{id="Top"; route="far"; leg=3; at=$null; length=$null},
 @{id="Bottom"; route="far"; leg=1; at=$null; length=$null}
)
$BRIDGES=@()
function NearBridgeRaft($x,$z){ $false }
function BridgeFrame($B,$x,$z){ $dx=$x-$B.x;$dz=$z-$B.z; @(($dx*$B.ux+$dz*$B.uz), (-$dx*$B.uz+$dz*$B.ux)) }
function NearBridge($x,$z,$reach){ foreach($B in $script:BRIDGES){ $f=BridgeFrame $B $x $z; if([math]::Abs($f[1]) -le $B.width/2+$reach -and [math]::Abs($f[0]) -le $B.length/2+$B.ramp+$reach){return $B} }; $null }
function OnBridge($x,$z,$deckOnly){ foreach($B in $script:BRIDGES){ $f=BridgeFrame $B $x $z; $ext= if($deckOnly){0}else{$B.ramp}; if([math]::Abs($f[1]) -le $B.width/2 -and [math]::Abs($f[0]) -le $B.length/2+$ext){return $B} }; $null }
# auto-size each bridge on its leg: find the wet stretch of the leg (liquid < 7 at the centreline or edges), deck = wet + 2
foreach($row in $BROWS){
 $r=$ROUTES[$row.route]; $a=$r[$row.leg-1]; $b=$r[$row.leg]
 $L=Flat $a[0] $a[1] $b[0] $b[1]; $ux=($b[0]-$a[0])/$L; $uz=($b[1]-$a[1])/$L
 $first=$null;$last=$null
 for($s=0;$s -le $L;$s+=0.5){ $px=$a[0]+$ux*$s;$pz=$a[1]+$uz*$s; $wet=$false
   foreach($off in @(-7.5,-3.75,0,3.75,7.5)){ $qx=$px-$uz*$off; $qz=$pz+$ux*$off; if((Liquid $qx $qz) -lt 1){$wet=$true} }
   if($wet){ if($first -eq $null){$first=$s}; $last=$s } }
 $deck=[math]::Ceiling(($last-$first)+2); $at=($first+$last)/2
 $B=@{id=$row.id;route=$row.route;from=$a;to=$b;at=$at;length=$deck;ux=$ux;uz=$uz;x=$a[0]+$ux*$at;z=$a[1]+$uz*$at;width=$BB.width;ramp=$BB.ramp;deck=$BB.deck;legLength=$L}
 $BRIDGES+= ,$B
}

# ---------------- nests ----------------
function N($id,$r,[double]$x,[double]$z){ @{id=$id;rarity=$r;x=$x;z=$z} }
$NESTS=@(
 (N C1 Comun -208 -23.4),(N C2 Comun -182 31.2),(N C3 Comun -117 -171.6),(N C4 Comun -80.6 169),(N C5 Comun 78 197.6),
 (N R1 Rara -101.4 -39),(N R2 Rara -101.4 44.2),(N R3 Rara -58.5 -120.9),(N R4 Rara -26 123.5),
 (N E1 Epica -44.2 -26),(N E2 Epica -44.2 31.2),(N L1 Legendaria 46.8 -28.6),
 (N C6 Comun 13 -164),(N C7 Comun 6.5 184.6),(N C8 Comun 100 -185),(N C9 Comun -175.5 -80.6),(N C10 Comun -50 -163),
 (N R5 Rara 114.4 145.6),(N R6 Rara 124.8 -158.6),(N R7 Rara -150.8 75.4),
 (N E3 Epica 0 46.8),(N R8 Rara -143 123.5),(N R9 Rara -78 91),(N R10 Rara -13 -58.5),(N R11 Rara 46.8 96.2),
 (N C11 Comun -39 195),(N C12 Comun -169 -130),(N C13 Comun 140 -182),
 # east (new)
 (N C14 Comun 360 170),(N C15 Comun 480 195),(N C16 Comun 600 195),(N C17 Comun 785 90),
 (N C18 Comun 600 -185),(N C19 Comun 480 -200),(N C20 Comun 740 -180),(N C21 Comun 800 -100),
 (N R12 Rara 300 130),(N R13 Rara 470 110),(N R14 Rara 650 100),(N R15 Rara 720 130),(N R16 Rara 560 -150),(N R17 Rara 720 -120),
 (N E4 Epica 400 20),(N E5 Epica 600 40)
)
# ---------------- posts (plot-local) ----------------
function P($id,[double]$x,[double]$z){ @{id=$id;x=$x;z=$z} }
$POSTS=@(
 (P candyNest -214 -17.4),(P candyNestR1 -93.4 -47),(P candyNestC3 -129 -179.6),(P bossHome 98.2 0),(P bossTerritory 148.2 0),
 (P candyNestC2 -188 44.2),(P candyNestR2 -96.4 56.2),(P candyNestR3 -46.5 -110.9),(P candyNestR4 84 211.6),(P candyNestC4 -88.6 181),
 (P candyPostC7 13.5 175.6),(P candyPostR6 131.8 -153.6),(P candyPostC8 95 -173),(P candyPostC9 -164.5 -76.6),(P candyPostR7 -160.8 83.4),
 (P candyPostR5 122.4 155.6),(P candyPostC6 3 -156),(P candyPostC10 -38 -155),(P candyPostE3 -12 46.8),(P candyPostR8 -131 123.5),
 (P candyPostR9 -66 91),(P candyPostR10 -4 -50.5),(P candyPostC11 -39 183),(P candyPostC12 -157 -130),(P candyPostC13 128 -181),(P candyPostR11 37.8 104.2),
 # east extra posts (third copy of each creature)
 (P candyPostR13 470 122),(P candyPostE5 594 30),(P candyPostR16 548 -150),(P candyPostC14 360 158),
 (P candyPostC16 600 183),(P candyPostR14 640 93),(P candyPostC18 600 -197),(P candyPostC21 788 -100)
)
# ---------------- pieces ----------------
$MOUNTAINS=@(
 @{id="M1";x=$M1.x;z=$M1.z;r=24.3;src=$true},
 @{id="M2";x=234;z=-117;r=14.2},@{id="M3";x=98.8;z=243.1;r=13.1},@{id="M4";x=214.5;z=-156;r=13.1},
 @{id="M5";x=-5.2;z=236;r=13.1},@{id="M6";x=-243.1;z=243.1;r=13.1},
 @{id="M7";x=560;z=246;r=14.2},@{id="M8";x=420;z=-247;r=13.1}
)
$HOUSES=@(
 @{id="H1";x=-192.4;z=215.8;r=28},@{id="H2";x=-130;z=227.5;r=15},@{id="H3";x=-200;z=-160;r=22.4},
 @{id="H4";x=231.4;z=130;r=20},@{id="H5";x=-218.4;z=-106.6;r=21},@{id="H6";x=183;z=-170;r=16},@{id="H7";x=143;z=231.4;r=20},
 @{id="H8";x=700;z=205;r=20},@{id="H9";x=690;z=-180;r=16}
)
$DOCKS=@(
 @{id="A";standX=-150;standZ=-185;tipX=-150;tipZ=-201},
 @{id="B";standX=250;standZ=-169;tipX=250;tipZ=-185},
 @{id="C";standX=680;standZ=0;tipX=680;tipZ=-16},
 @{id="D";standX=655;standZ=-163;tipX=655;tipZ=-147}
)
$PLATFORMS=@(@{a="CookieM";x=625;z=-128;r=6.7},@{a="CookieL";x=595;z=-25;r=11.7},@{a="CookieS";x=632;z=-24;r=3.9},@{a="CookieS";x=585;z=-118;r=3.9})
$TRAPS=@(@{key="riverside";x=-126.1;z=-71.5},@{key="path";x=-93.6;z=8},@{key="rareNest";x=-109.4;z=-30})
$KEEP=@(@{x=214.5;z=195;r=26;why="pond"},@{x=-78;z=240.5;r=10;why="hive"})
$BOSS=@{x=148.2;z=0;t=76;plaza=58}
$PORTAL=@{x=-31.2;z=0}; $ENTR=@{x=-260;z=0}
$HILLS=@(@{id="Hill_1";x=858;z=-247;r=17.75},@{id="Hill_2";x=858;z=-162.5;r=16},@{id="Hill_3";x=858;z=-78;r=17.75},@{id="Hill_4";x=858;z=78;r=17.75},@{id="Hill_5";x=858;z=162.5;r=9.94},@{id="Hill_6";x=858;z=247;r=17.75})
# licorice feet and cake
$LIC=@(); foreach($f in @(@(20.6,5.7),@(34.8,4.5))){ foreach($sd in @(-1,1)){ $LIC+=@{id="Lic";x=-161.2;z=$sd*$f[0]*0.8;r=$f[1]*0.8} } }
$CAKE=@(@{id="CakeBase";x=-195;z=145.6;r=18})
function DockPts($d){ $dx=$d.tipX-$d.standX;$dz=$d.tipZ-$d.standZ;$L=[math]::Sqrt($dx*$dx+$dz*$dz);$ux=$dx/$L;$uz=$dz/$L;$de=$L-5
 @(@{x=$d.standX-$ux*10;z=$d.standZ-$uz*10}, @{x=$d.standX+$ux*$de/2;z=$d.standZ+$uz*$de/2}, $L) }
$PIECES=@()
foreach($m in $MOUNTAINS){ $PIECES+=@{kind="mountain";id=$m.id;x=$m.x;z=$m.z;r=$m.r;src=$m.src} }
foreach($h in $HOUSES){ $PIECES+=@{kind="house";id=$h.id;x=$h.x;z=$h.z;r=$h.r} }
foreach($d in $DOCKS){ $p=DockPts $d; $PIECES+=@{kind="dock";id=$d.id;x=$d.standX;z=$d.standZ;r=3}; $PIECES+=@{kind="dock";id=$d.id+"Ramp";x=$p[0].x;z=$p[0].z;r=3.5}; $PIECES+=@{kind="dock";id=$d.id+"Deck";x=$p[1].x;z=$p[1].z;r=3} }
foreach($l in $LIC){ $PIECES+=@{kind="licorice";id="Foot";x=$l.x;z=$l.z;r=$l.r} }
$PIECES+=@{kind="cake";id="Base";x=-195;z=145.6;r=18}
# cake ramp disc: faces (-195,0): yaw from base toward -z; mid=(18+38.5)/2=28.25 toward (-195,0)
$PIECES+=@{kind="cake";id="Ramp";x=-195;z=(145.6-28.25);r=((38.5-18)/2+2)}

$fails=New-Object System.Collections.ArrayList
function F($m){ [void]$fails.Add($m) }
function Mn($tag,$val,$min){ if($val -lt $min){ F ("{0}: {1:N2} < {2}" -f $tag,$val,$min) } }

if($Mode -eq "print"){
 "M1 yaw(deg)={0:N1} outlet=({1:N2},{2:N2}) pool=({3:N2},{4:N2}) waterfall=({5:N2},{6:N2})" -f ($yaw*180/[math]::PI),$outlet[0],$outlet[1],$pool[0],$pool[1],$wf[0],$wf[1]
 foreach($B in $BRIDGES){ "bridge {0} route {1} at {2:N2} deck {3} centre ({4:N2},{5:N2}) u=({6:N4},{7:N4}) leg {8:N1} span {9:N1}..{10:N1}" -f $B.id,$B.route,$B.at,$B.length,$B.x,$B.z,$B.ux,$B.uz,$B.legLength,($B.at-$B.length/2-$B.ramp),($B.at+$B.length/2+$B.ramp) }
 $len=0; for($i=0;$i -lt $RIVER.Count-1;$i++){ $len+=Flat $RIVER[$i][0] $RIVER[$i][1] $RIVER[$i+1][0] $RIVER[$i+1][1] }; "river length {0:N1}" -f $len
 foreach($d in $DOCKS){ $p=DockPts $d; "dock {0}: stand liquid {1:N2} tip liquid {2:N2} foot liquid {3:N2} len {4:N1} foot route {5:N1}" -f $d.id,(Liquid $d.standX $d.standZ),(Liquid $d.tipX $d.tipZ),(Liquid $p[0].x $p[0].z),$p[2],(RouteD $p[0].x $p[0].z) }
}

# V3-2
for($i=0;$i -lt $RIVER.Count;$i++){ $p=$RIVER[$i]; if($p[2] -lt 10){F "w<10 at $i"}; if($i -lt $RIVER.Count-1){ Mn ("V3-2 point "+($i+1)+" depth-w/2") ((Depth $p[0] $p[1]) - $p[2]/2) 2 } }
if([math]::Abs((Depth $RIVER[-1][0] $RIVER[-1][1])) -gt 0.01){ F "last point not on the edge" }
Mn "pool-outlet" (5.95 - (Flat $RIVER[0][0] $RIVER[0][1] $POOL.x $POOL.z)) 0
# V3-4 routes vs chocolate
$half=7
foreach($k in $ROUTES.Keys){ $r=$ROUTES[$k]; for($i=0;$i -lt $r.Count-1;$i++){ $a=$r[$i];$b=$r[$i+1];$L=Flat $a[0] $a[1] $b[0] $b[1]; $n=[math]::Max(1,[math]::Ceiling($L/2)); for($s=0;$s -le $n;$s++){ $x=$a[0]+($b[0]-$a[0])*$s/$n;$z=$a[1]+($b[1]-$a[1])*$s/$n; $d=Liquid $x $z; if($d -le 0 -and -not (OnBridge $x $z $true)){ F ("V3-4 {0} wades at {1:N1},{2:N1}" -f $k,$x,$z) }; if($d -lt $half -and -not (OnBridge $x $z $false)){ F ("V3-4 {0} edge wades at {1:N1},{2:N1} d={3:N1}" -f $k,$x,$z,$d) } } } }
foreach($B in $BRIDGES){ $lo=$B.at-$B.length/2-$B.ramp; $hi=$B.at+$B.length/2+$B.ramp; if($lo -lt 0 -or $hi -gt $B.legLength){ F ("bridge {0} off its leg {1:N1}..{2:N1} of {3:N1}" -f $B.id,$lo,$hi,$B.legLength) }
 if((Liquid $B.x $B.z) -ge 0){F "bridge $($B.id) not over chocolate"}
 # raised: ramps on dry land (liquid >= 0.5 across the ramp footprint)
 foreach($sg in @(-1,1)){ for($al=$B.length/2; $al -le $B.length/2+$B.ramp; $al+=1){ foreach($ac in @(-7.5,-3.75,0,3.75,7.5)){ $x=$B.x+$B.ux*$sg*$al-$B.uz*$ac; $z=$B.z+$B.uz*$sg*$al+$B.ux*$ac; $d=Liquid $x $z; if($d -lt 0.5){ F ("bridge {0} ramp wet at along {1} across {2}: {3:N2}" -f $B.id,($sg*$al),$ac,$d) } } } }
 # tightest dry-margin of the ramps
 $mn=1e9; foreach($sg in @(-1,1)){ foreach($ac in @(-7.5,0,7.5)){ $al=$B.length/2; $x=$B.x+$B.ux*$sg*$al-$B.uz*$ac; $z=$B.z+$B.uz*$sg*$al+$B.ux*$ac; $mn=[math]::Min($mn,(Liquid $x $z)) } }
 if($Mode -eq "print"){ "  bridge {0}: ramp-foot-of-deck min liquid {1:N2}" -f $B.id,$mn }
}
# V3-5
foreach($n in $NESTS){ Mn ("V3-5 nest "+$n.id) (Liquid $n.x $n.z) 6 }
Mn "summit" (Liquid 148.2 9.4) 0.01
foreach($p in $POSTS){ Mn ("V3-5 post "+$p.id) (Liquid $p.x $p.z) 8 }
foreach($t in $TRAPS){ Mn ("V3-5 trap "+$t.key) (Liquid $t.x $t.z) 10 }
Mn "boss" (Liquid $BOSS.x $BOSS.z) 76
Mn "stair (plaza ring+10)" ((Liquid $BOSS.x $BOSS.z) - 58) 10
Mn "portal" (Liquid $PORTAL.x $PORTAL.z) 16
Mn "entrance" (Liquid $ENTR.x $ENTR.z) 28
foreach($k in $KEEP){ Mn ("keep "+$k.why) (Liquid $k.x $k.z) $k.r }
# V3-6
foreach($p in $PIECES){ $lab=$p.kind+" "+$p.id
 foreach($n in $NESTS){ Mn ("V3-6 $lab vs nest "+$n.id) ((Flat $p.x $p.z $n.x $n.z)-$p.r) 8 }
 foreach($q in $POSTS){ Mn ("V3-6 $lab vs post "+$q.id) ((Flat $p.x $p.z $q.x $q.z)-$p.r) 6 }
 foreach($t in $TRAPS){ Mn ("V3-6 $lab vs trap") ((Flat $p.x $p.z $t.x $t.z)-$p.r) 10 }
 Mn ("V3-6 $lab vs route") ((RouteD $p.x $p.z)-$p.r-7) 3
 Mn ("V3-6 $lab vs boss") ((Flat $p.x $p.z $BOSS.x $BOSS.z)-$p.r) 76
 Mn ("V3-6 $lab vs portal") ((Flat $p.x $p.z $PORTAL.x $PORTAL.z)-$p.r) 16
 Mn ("V3-6 $lab vs entrance") ((Flat $p.x $p.z $ENTR.x $ENTR.z)-$p.r) 28
 foreach($k in $KEEP){ Mn ("V3-6 $lab vs "+$k.why) ((Flat $p.x $p.z $k.x $k.z)-$p.r-$k.r) 2 }
 if($p.kind -eq "mountain"){ Mn ("V3-6 $lab depth") ((Depth $p.x $p.z)-$p.r) (-0.5) } else { Mn ("V3-6 $lab depth") ((Depth $p.x $p.z)-$p.r) 2 }
 if(-not $p.src -and $p.kind -ne "dock"){ Mn ("V3-6 $lab vs chocolate") ((Liquid $p.x $p.z)-$p.r) 2 }
 if($p.kind -ne "dock" -and (NearBridge $p.x $p.z $p.r)){ F "V3-6 $lab on a bridge" }
}
for($i=0;$i -lt $PIECES.Count;$i++){ for($j=$i+1;$j -lt $PIECES.Count;$j++){ $a=$PIECES[$i];$b=$PIECES[$j]; if($a.kind -eq "cake" -and $b.kind -eq "cake"){continue}; if($a.kind -eq "dock" -and $b.kind -eq "dock" -and $a.id.Substring(0,1) -eq $b.id.Substring(0,1)){continue}; Mn ("V3-6 "+$a.kind+" "+$a.id+" touches "+$b.kind+" "+$b.id) ((Flat $a.x $a.z $b.x $b.z)-$a.r-$b.r) 2 } }
# V3-7 doors
foreach($h in $HOUSES){ $tw = ($h.id -eq "H2" -or $h.id -eq "H5"); $yaw=[math]::Atan2(-(0-$h.x),-(0-$h.z)); if($tw){$yaw+= [math]::PI}; $lx=-[math]::Sin($yaw);$lz=-[math]::Cos($yaw); $dx=$h.x+$lx*($h.r+4);$dz=$h.z+$lz*($h.r+4)
 Mn ("V3-7 "+$h.id+" door depth") (Depth $dx $dz) 5; Mn ("V3-7 "+$h.id+" door chocolate") (Liquid $dx $dz) 4
 foreach($p in $PIECES){ if(-not ($p.kind -eq "house" -and $p.id -eq $h.id)){ Mn ("V3-7 "+$h.id+" door vs "+$p.kind+" "+$p.id) ((Flat $dx $dz $p.x $p.z)-$p.r) 4 } } }
# V3-8 docks
foreach($d in $DOCKS){ Mn ("V3-8 stand "+$d.id) (Liquid $d.standX $d.standZ) 0.01; if((Liquid $d.tipX $d.tipZ) -gt -6){ F ("V3-8 tip "+$d.id+" "+(Liquid $d.tipX $d.tipZ)) }; if(NearBridge $d.tipX $d.tipZ 6){F "tip $($d.id) by a bridge"}; $p=DockPts $d; Mn ("V3-13 foot "+$d.id) (Liquid $p[0].x $p[0].z) 0.01 }
# V3-9 platforms
for($i=0;$i -lt $PLATFORMS.Count;$i++){ $pl=$PLATFORMS[$i]; $in=$false; foreach($d in $LAKE){ if((Flat $pl.x $pl.z $d.x $d.z)+$pl.r -le $d.r){$in=$true} }; if(-not $in){F "platform $i leaves the lake"}; if(NearBridge $pl.x $pl.z $pl.r){F "platform $i on bridge"}; for($j=$i+1;$j -lt $PLATFORMS.Count;$j++){ $o=$PLATFORMS[$j]; Mn "platforms $i $j" ((Flat $pl.x $pl.z $o.x $o.z)-$pl.r-$o.r) 2 }
 # platforms off the island and off docks
 foreach($is in $ISL){ Mn "platform $i vs island" ((Flat $pl.x $pl.z $is.x $is.z)-$pl.r-$is.foot) 3 }
 foreach($d in $DOCKS){ Mn "platform $i vs dock tip $($d.id)" ((Flat $pl.x $pl.z $d.tipX $d.tipZ)-$pl.r) 12 }
}
# V3-15 hills
foreach($h in $HILLS){ foreach($n in $NESTS){ Mn ("V3-15 "+$h.id+" nest "+$n.id) ((Flat $h.x $h.z $n.x $n.z)-$h.r) 8 }; foreach($q in $POSTS){ Mn ("V3-15 "+$h.id+" post") ((Flat $h.x $h.z $q.x $q.z)-$h.r) 6 }; Mn ("V3-15 "+$h.id+" route") ((RouteD $h.x $h.z)-$h.r-7) 3; Mn ("V3-15 "+$h.id+" choc") ((LiquidRaw $h.x $h.z)-$h.r) 2; foreach($p in $PIECES){ Mn ("V3-15 "+$h.id+" piece "+$p.id) ((Flat $h.x $h.z $p.x $p.z)-$h.r-$p.r) 2 } }
# Layout_Test nests
$ring=@{Comun=@(0,97.5);Rara=@(97.5,208);Epica=@(208,260);Legendaria=@(208,260)}
for($i=0;$i -lt $NESTS.Count;$i++){ $n=$NESTS[$i]; $rd=RouteD $n.x $n.z; $tt=Flat $n.x $n.z 148.2 0
 Mn ("nest "+$n.id+" off path") $rd 11; if($rd -gt 52 -and $tt -gt 58){ F ("nest {0} unreachable {1:N1}" -f $n.id,$rd) }; Mn ("nest "+$n.id+" torta") $tt 48
 $dp=Depth $n.x $n.z; $bd=$ring[$n.rarity]; if($dp -lt $bd[0] -or $dp -gt $bd[1]){ F ("ring {0} {1} depth {2:N1}" -f $n.id,$n.rarity,$dp) }
 foreach($k in $KEEP){ Mn ("nest "+$n.id+" keep "+$k.why) ((Flat $n.x $n.z $k.x $k.z)-$k.r) 20 }
 for($j=$i+1;$j -lt $NESTS.Count;$j++){ $o=$NESTS[$j]; Mn ("nests "+$n.id+"/"+$o.id) (Flat $n.x $n.z $o.x $o.z) 20 }
 if($n.x -gt 260 -or @("C6","C8","C10","C13") -contains $n.id){ Mn ("new nest "+$n.id+" boss") (Flat $n.x $n.z 148.2 0) 96; Mn ("new nest "+$n.id+" entrance") (Flat $n.x $n.z -260 0) 80 }
 # nests vs bridges footprint
 if(NearBridge $n.x $n.z 4){ F ("nest "+$n.id+" on a bridge") }
 # nests vs docks/platforms/islands
 foreach($is in $ISL){ Mn ("nest "+$n.id+" island") ((Flat $n.x $n.z $is.x $is.z)-$is.foot) 6 }
}
# posts: bind radius 20 to nearest nest for the new east posts, and route distance <= 45 (wake)
foreach($q in $POSTS){ $best=1e9;$bid=""; foreach($n in $NESTS){ $d=Flat $q.x $q.z $n.x $n.z; if($d -lt $best){$best=$d;$bid=$n.id} }; if($q.id -like "candyPost*" -and $q.x -gt 260){ if($best -gt 20){F ("post {0} nearest nest {1} at {2:N1}" -f $q.id,$bid,$best)}; if($Mode -eq "print"){ "post {0}: nest {1} at {2:N1}, route {3:N1}, liquid {4:N1}" -f $q.id,$bid,$best,(RouteD $q.x $q.z),(Liquid $q.x $q.z) } }
 if(NearBridge $q.x $q.z 6){ F ("post "+$q.id+" by a bridge") }
 # posts apart: east posts at least 85 from any other east post? (kitten rule) report only
}
# routes: return-like keep-out from boss territory and depth >= 20
foreach($k in @("east","south","far")){ $r=$ROUTES[$k]; for($i=0;$i -lt $r.Count-1;$i++){ $a=$r[$i];$b=$r[$i+1];$L=Flat $a[0] $a[1] $b[0] $b[1]; $n=[math]::Ceiling($L/2); for($s=0;$s -le $n;$s++){ $x=$a[0]+($b[0]-$a[0])*$s/$n;$z=$a[1]+($b[1]-$a[1])*$s/$n; Mn ("route $k boss") (Flat $x $z 148.2 0) 83; Mn ("route $k depth") (Depth $x $z) 20 } } }
# island
foreach($is in $ISL){ $inside=$false; foreach($d in $LAKE){ if((Flat $is.x $is.z $d.x $d.z)+$is.foot+6 -le $d.r+40){$inside=$true} };
 # hull channel all round: points at foot+3+... must float (liquid <= -3) on a ring at r = foot+4
 $bad=0; for($a=0;$a -lt 360;$a+=10){ $x=$is.x+[math]::Cos($a*[math]::PI/180)*($is.r+4); $z=$is.z+[math]::Sin($a*[math]::PI/180)*($is.r+4); if((Liquid $x $z) -gt -3 -or (NearBridge $x $z 3)){$bad++} }; if($bad -gt 0){F "island channel blocked at $bad angles"}
 foreach($d in $DOCKS){ Mn ("island vs tip "+$d.id) ((Flat $is.x $is.z $d.tipX $d.tipZ)-$is.foot) 15; Mn ("island vs stand "+$d.id) ((Flat $is.x $is.z $d.standX $d.standZ)) 20 } }
# raft: centreline from the first 30+ wide point to the last-but-one floats a hull and is never near a (non-raised) bridge
$bad=0; for($i=1;$i -lt $RIVER.Count-1;$i++){ $a=$RIVER[$i];$b=$RIVER[$i+1]; $L=Flat $a[0] $a[1] $b[0] $b[1]; for($s=0;$s -le $L;$s+=2){ $x=$a[0]+($b[0]-$a[0])*$s/$L; $z=$a[1]+($b[1]-$a[1])*$s/$L; if((Depth $x $z) -lt 3.01){continue}; if((Liquid $x $z) -gt -3){ $bad++; if($Mode -eq "print"){ "raft dry at {0:N1},{1:N1} {2:N2}" -f $x,$z,(Liquid $x $z) } } } }
if($bad -gt 0){ F "raft centreline dry at $bad samples" }

"FAILS: " + $fails.Count
$fails | Select-Object -First 80





# ---------------- Life: fish and flocks ----------------
$FISH=@(
 @{id="River_W1";x=-130;z=-225;h=0},@{id="River_W2";x=-40;z=-223;h=0},@{id="River_W3";x=60;z=-224;h=0},@{id="River_W4";x=170;z=-224;h=0.1},
 @{id="River_E1";x=330;z=-184;h=0.52},@{id="River_E2";x=430;z=-127;h=0.52},
 @{id="Lake_1";x=600;z=-52;h=0.24},@{id="Lake_2";x=665;z=-72;h=0.12},@{id="Lake_3";x=650;z=-125;h=-0.3},
 @{id="River_E3";x=800;z=-19;h=0.35}
)
foreach($s in $FISH){ foreach($u in @(0,0.25,0.5,0.75,1)){ $x=$s.x+[math]::Cos($s.h)*7*$u; $z=$s.z+[math]::Sin($s.h)*7*$u; if((Liquid $x $z) -gt -3){F ("fish {0} not 3 inside at u {1}: {2:N2}" -f $s.id,$u,(Liquid $x $z))}; if(NearBridge $x $z 0){F "fish $($s.id) under a bridge"}; foreach($pl in $PLATFORMS){ Mn ("fish "+$s.id+" platform") ((Flat $x $z $pl.x $pl.z)-$pl.r) 3 }; foreach($d in $DOCKS){ Mn ("fish "+$s.id+" dock "+$d.id) (Flat $x $z $d.tipX $d.tipZ) 8 }; foreach($is in $ISL){ Mn ("fish "+$s.id+" island") ((Flat $x $z $is.x $is.z)-$is.foot) 2 } } }
$FLOCKS=@(
 @{id="F1";x=-156;z=52;r=26},@{id="F2";x=-104;z=-65;r=24},@{id="F3";x=78;z=195;r=22},@{id="F4";x=150;z=-115;r=22},@{id="F5";x=-104;z=-150;r=20},@{id="F6";x=195;z=156;r=20},
 @{id="F7";x=420;z=60;r=24},@{id="F8";x=560;z=175;r=22},@{id="F9";x=640;z=-215;r=20}
)
foreach($k in $FLOCKS){ Mn ("flock "+$k.id+" chocolate") ((LiquidRaw $k.x $k.z)-$k.r) 10; foreach($h in $HOUSES){ Mn ("flock "+$k.id+" house "+$h.id) ((Flat $k.x $k.z $h.x $h.z)-$k.r-$h.r) 0 }; Mn ("flock "+$k.id+" torta") ((Flat $k.x $k.z 148.2 0)-$k.r-42) 10; Mn ("flock "+$k.id+" depth") ((Depth $k.x $k.z)-$k.r) 5 }
"FAILS after life: " + $fails.Count
$fails | Select-Object -Skip 0 -First 40
# world coords dump
if($Mode -eq "print"){
 "--- river world ---"; foreach($p in $RIVER){ "{0:N2},{1:N2} w{2} -> world {3:N2},{4:N2}" -f $p[0],$p[1],$p[2],($p[0]+672),($p[1]-3) }
 "--- liquid at selected ---"
 foreach($n in $NESTS){ if(@("C3","C6","C8","C10","C13","R6","C12","R3") -contains $n.id){ "nest {0} liquid {1:N2} route {2:N2} depth {3:N2}" -f $n.id,(Liquid $n.x $n.z),(RouteD $n.x $n.z),(Depth $n.x $n.z) } }
 foreach($p in $POSTS){ if(@("candyNestC3","candyPostC6","candyPostC8","candyPostC10","candyPostC13","candyPostR6","candyPostC12") -contains $p.id){ "post {0} liquid {1:N2}" -f $p.id,(Liquid $p.x $p.z) } }
 "route left bottom leg centre liquid at (0,-182): {0:N2}" -f (Liquid 0 -182)
 "boss liquid {0:N2}; M4 edge liquid {1:N2}; H3 {2:N2}; H6 {3:N2}" -f (Liquid 148.2 0),((Liquid 214.5 -156)-13.1),((Liquid -200 -160)-22.4),((Liquid 183 -170)-16)
}



if($Mode -eq "sum"){
 $m=@(); foreach($n in $NESTS){ $m+=[pscustomobject]@{id=$n.id;liq=[math]::Round((Liquid $n.x $n.z),2);route=[math]::Round((RouteD $n.x $n.z),1);depth=[math]::Round((Depth $n.x $n.z),1)} }
 "nest liquid min:"; $m | Sort-Object liq | Select-Object -First 6 | Format-Table -AutoSize | Out-String
 "nest route max:"; $m | Sort-Object route -Descending | Select-Object -First 5 | Format-Table -AutoSize | Out-String
 $q=@(); foreach($p in $POSTS){ $q+=[pscustomobject]@{id=$p.id;liq=[math]::Round((Liquid $p.x $p.z),2)} }; "post liquid min:"; $q | Sort-Object liq | Select-Object -First 5 | Format-Table -AutoSize | Out-String
 $mn=1e9;$who=""; for($i=0;$i -lt $NESTS.Count;$i++){ for($j=$i+1;$j -lt $NESTS.Count;$j++){ $d=Flat $NESTS[$i].x $NESTS[$i].z $NESTS[$j].x $NESTS[$j].z; if($d -lt $mn){$mn=$d;$who=$NESTS[$i].id+"/"+$NESTS[$j].id} } }; "closest nests {0} {1:N1}" -f $who,$mn
 $pc=@(); foreach($p in $PIECES){ $pc+=[pscustomobject]@{id=$p.kind+" "+$p.id;route=[math]::Round((RouteD $p.x $p.z)-$p.r-7,2);liq=[math]::Round((Liquid $p.x $p.z)-$p.r,2)} }
 "piece route min:"; $pc | Sort-Object route | Select-Object -First 5 | Format-Table -AutoSize | Out-String
 "piece liquid min:"; $pc | Sort-Object liq | Select-Object -First 8 | Format-Table -AutoSize | Out-String
 foreach($h in $HILLS){ "{0} liquid-r {1:N1} route-r-7 {2:N1}" -f $h.id,((LiquidRaw $h.x $h.z)-$h.r),((RouteD $h.x $h.z)-$h.r-7) }
 foreach($d in $DOCKS){ $p=DockPts $d; "dock {0} foot ({1:N1},{2:N1}) mid ({3:N1},{4:N1}) footRoute-3.5-7 {5:N1}" -f $d.id,$p[0].x,$p[0].z,$p[1].x,$p[1].z,((RouteD $p[0].x $p[0].z)-10.5) }
 # open water cells (hull) in the whole plot, and per half
 $open=0;$openE=0; for($x=-256;$x -le 856;$x+=8){ for($z=-256;$z -le 256;$z+=8){ if((Liquid $x $z) -le -3 -and -not (NearBridgeRaft $x $z)){ $open+=64; if($x -gt 260){$openE+=64} } } }; "hull open area {0} (east {1})" -f $open,$openE
 $wet=0; for($x=-256;$x -le 856;$x+=8){ for($z=-256;$z -le 256;$z+=8){ if((Liquid $x $z) -lt 0){ $wet+=64 } } }; "wet area {0} share {1:P1}" -f $wet,($wet/(1120*520))
 # V3-14 replacement: every x line from -150 to 850 meets chocolate
 $dry=0; for($x=-200;$x -le 856;$x+=8){ $hit=$false; for($z=-258;$z -le 258;$z+=2){ if((Liquid $x $z) -lt 0){$hit=$true;break} }; if(-not $hit){$dry++} }; "dry x-lines from -180: $dry"
 # island ring min liquid
 foreach($is in $ISL){ $mx=-1e9; for($a=0;$a -lt 360;$a+=5){ $x=$is.x+[math]::Cos($a*[math]::PI/180)*($is.r+4); $z=$is.z+[math]::Sin($a*[math]::PI/180)*($is.r+4); $mx=[math]::Max($mx,(Liquid $x $z)) }; "island ring worst liquid {0:N2}" -f $mx }
}
function NearBridgeRaft($x,$z){ $false }


