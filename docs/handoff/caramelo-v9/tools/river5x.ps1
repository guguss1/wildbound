$S = 1.3
$H = 260
$v7 = @(
 @(-8.36,154.08,12),@(-12,138,19),@(-10,131,19.5),@(-9,124,24),@(-3,104,24),@(5,82,24),@(11,62,24),@(13,54,24),
 @(12,50,16),@(12,44,10),@(11.25,30.07,10),@(19.06,23.82,10),@(27.49,13.21,10),@(30.5,0,10),@(27.57,-13.06,10),
 @(19.31,-23.6,10),@(11.57,-29.93,10),@(12,-42,14),@(17,-58,20),@(14,-90,24),@(24,-125,24),@(27,-140,24),@(29,-170,24),@(30,-200,24))
$R = @()
for ($i=0; $i -lt $v7.Count; $i++) {
  $p = $v7[$i]; $x = $p[0]*$S; $z = $p[1]*$S
  if ($i -le 1) { $x = $p[0] - 1.2; $z = $p[1] + 60 }
  elseif ($i -eq 3) { $z = 156 + 4 }
  elseif ($i -eq $v7.Count-1) { $z = -$H }
  $R += ,@($x,$z,$p[2])
}
function SegD($x,$z,$ax,$az,$bx,$bz){ $dx=$bx-$ax;$dz=$bz-$az;$l2=$dx*$dx+$dz*$dz;$t=0; if($l2 -gt 0){$t=(($x-$ax)*$dx+($z-$az)*$dz)/$l2; if($t -lt 0){$t=0}; if($t -gt 1){$t=1}}; $qx=$ax+$dx*$t;$qz=$az+$dz*$t; [math]::Sqrt(($x-$qx)*($x-$qx)+($z-$qz)*($z-$qz)) }
function RivD($x,$z,$k){ $best=1e9; for($i=0;$i -lt $R.Count-1;$i++){ $a=$R[$i];$b=$R[$i+1]; $d=(SegD $x $z $a[0] $a[1] $b[0] $b[1]) - [math]::Max($a[2],$b[2])*$k/2; if($d -lt $best){$best=$d} }; $best }
"RIVER v8:"
$len=0
for($i=0;$i -lt $R.Count;$i++){ $p=$R[$i]; $depth = $H - [math]::Max([math]::Abs($p[0]),[math]::Abs($p[1])); if($i -gt 0){$q=$R[$i-1]; $len += [math]::Sqrt(($p[0]-$q[0])*($p[0]-$q[0])+($p[1]-$q[1])*($p[1]-$q[1]))}
  "{0,2} ({1,8:N2},{2,8:N2}) w {3,5} w5 {4,5} depth {5,6:N1} depth-w5/2 {6,6:N1}" -f ($i+1),$p[0],$p[1],$p[2],($p[2]*5),$depth,($depth-$p[2]*5/2) }
"length {0:N1}" -f $len
$items = @()
function Add($kind,$id,$x,$z,$r,$need){ $script:items += ,@($kind,$id,$x,$z,$r,$need) }
$nests = @(@("C1",-160,-18),@("C2",-140,24),@("C3",-90,-132),@("C4",-62,130),@("C5",60,152),@("R1",-78,-30),@("R2",-78,34),@("R3",-45,-93),@("R4",-20,95),@("E1",-34,-20),@("E2",-34,24),@("L1",36,-22),@("C6",10,-162),@("C7",5,142),@("C8",60,-170),@("C9",-135,-62),@("C10",-60,-162),@("R5",88,112),@("R6",96,-122),@("R7",-116,58),@("E3",0,36),@("R8",-110,95),@("R9",-60,70),@("R10",-10,-45),@("R11",36,74),@("C11",-30,150),@("C12",-130,-100),@("C13",100,-150))
foreach($n in $nests){ Add "nest" $n[0] ($n[1]*$S) ($n[2]*$S) 0 6 }
Add "nest" "T1" 148.2 9.4 0 6
$posts = @{candyNest=@(458,-20.4);candyNestR1=@(578.6,-50);candyNestC3=@(543,-182.6);bossHome=@(770.2,-3);bossTerritory=@(820.2,-3);candyNestC2=@(484,41.2);candyNestR2=@(575.6,53.2);candyNestR3=@(625.5,-113.9);candyNestR4=@(756,208.6);candyNestC4=@(583.4,178);candyPostC7=@(685.5,172.6);candyPostR6=@(803.8,-156.6);candyPostC8=@(745,-212);candyPostC9=@(507.5,-79.6);candyPostR7=@(511.2,80.4);candyPostR5=@(794.4,152.6);candyPostC6=@(675,-205.6);candyPostC10=@(606,-205.6);candyPostE3=@(660,43.8);candyPostR8=@(541,120.5);candyPostR9=@(606,88);candyPostR10=@(668,-53.5);candyPostC11=@(633,180);candyPostC12=@(515,-133);candyPostC13=@(790,-197);candyPostR11=@(709.8,101.2)}
foreach($k in $posts.Keys){ $p=$posts[$k]; Add "post" $k ($p[0]-672) ($p[1]+3) 0 8 }
$houses=@(@("H1",-148,166,28),@("H2",-100,175,15),@("H3",-158,-150,22.4),@("H4",178,100,20),@("H5",-168,-82,21),@("H6",150,-170,16),@("H7",110,178,20))
foreach($h in $houses){ Add "house" $h[0] ($h[1]*$S) ($h[2]*$S) $h[3] 0 }
Add "mountain" "M1" -5.2 236 24.3 0
Add "mountain" "M2" 234 -117 14.2 0
Add "mountain" "M3" 98.8 243.1 13.1 0
Add "mountain" "M4" 214.5 -156 13.1 0
Add "dock" "A.stand" -42.2 -150.2 3 0
Add "dock" "A.tip" -26.2 -148.2 0 0
Add "dock" "B.stand" 50.4 -133.4 3 0
Add "dock" "B.tip" 34.4 -131.4 0 0
Add "island" "I1" 18.9 -102.4 6 0
Add "trap" "riverside" -126.1 -71.5 0 10
Add "trap" "path" -93.6 8 0 10
Add "trap" "rareNest" -109.4 -30 0 10
Add "keep" "pond" 214.5 195 26 0
Add "keep" "hive" -78 240.5 10 0
Add "portal" "Portal" -31.2 0 0 16
Add "boss" "territory" 148.2 0 76 0
Add "route" "junction" 0 0 0 0
Add "route" "fork" -143 0 0 0
Add "route" "entrance" -260 0 0 28
Add "cake" "CakeBase" -195 145.6 18 0
Add "licorice" "arch" -161.2 0 0 0
$flocks=@(@("F1",-120,40,26),@("F2",-80,-50,24),@("F3",60,150,22),@("F4",130,-110,22),@("F5",-80,-160,20),@("F6",150,120,20))
foreach($f in $flocks){ Add "flock" $f[0] ($f[1]*$S) ($f[2]*$S) $f[3] 10 }
""
"ITEM                     today   x5   (value = river distance minus item radius minus its required clearance; <0 = violates)"
foreach($it in $items){ $d1=(RivD $it[2] $it[3] 1)-$it[4]-$it[5]; $d5=(RivD $it[2] $it[3] 5)-$it[4]-$it[5]; $flag=""; if($d5 -lt 0){$flag="  <-- x5 FAIL"}; "{0,-8} {1,-14} ({2,7:N1},{3,7:N1}) {4,7:N1} {5,7:N1}{6}" -f $it[0],$it[1],$it[2],$it[3],$d1,$d5,$flag }
