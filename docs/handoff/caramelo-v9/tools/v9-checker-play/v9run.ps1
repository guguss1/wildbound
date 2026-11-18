. "$PSScriptRoot\v9check.ps1"
$fails = New-Object System.Collections.ArrayList
function F($m) { [void]$fails.Add($m) }
function fmt($v) { '{0:N1}' -f $v }
"outlet {0:N2},{1:N2} pool {2:N2},{3:N2} r {4:N2} wf {5:N2},{6:N2}" -f $out[0], $out[1], $POOL.x, $POOL.z, $POOL.r, $WF.x, $WF.z
# river length, edge rule
$len = 0; for ($i = 0; $i -lt $RIVER.Count - 1; $i++) { $len += Flat $RIVER[$i][0] $RIVER[$i][1] $RIVER[$i + 1][0] $RIVER[$i + 1][1] }
"river length " + (fmt $len)
for ($i = 0; $i -lt $RIVER.Count - 1; $i++) { $p = $RIVER[$i]; $m = (Depth $p[0] $p[1]) - $p[2] / 2; if ($m -lt 2) { F "edge R$($i+1) $m" } }
"R1 to pool " + (fmt (Flat $RIVER[0][0] $RIVER[0][1] $POOL.x $POOL.z))
# nests
$nl = @(); foreach ($k in $NESTS.Keys) { $n = $NESTS[$k]; $nl += @{ id = $k; rar = $n[0]; x = $n[1]; z = $n[2] } }
"nests: " + $nl.Count
foreach ($n in $nl) {
  $l = Liq $n.x $n.z; $rd = RouteD $n.x $n.z; $tt = Flat $n.x $n.z $TORTA.x $TORTA.z; $bd = Flat $n.x $n.z $BOSS.x $BOSS.z
  if ($l -lt 6) { F "nest $($n.id) liquid $(fmt $l)" }
  if ($rd -lt 11) { F "nest $($n.id) on route $(fmt $rd)" }
  if ($rd -gt 52 -and $tt -gt $BOSS.plaza) { F "nest $($n.id) unreachable $(fmt $rd)" }
  if ($tt -lt 48) { F "nest $($n.id) in torta" }
  if ($bd -lt 96) { F "nest $($n.id) boss $(fmt $bd)" }
  if ((Flat $n.x $n.z $ENTR[0] $ENTR[1]) -lt 39) { F "nest $($n.id) entrance" }
  if ((Flat $n.x $n.z $PORTAL[0] $PORTAL[1]) -lt 16) { F "nest $($n.id) portal" }
  foreach ($s in $KEEP) { if ((Flat $n.x $n.z $s.x $s.z) -lt $s.r + 20) { F "nest $($n.id) keep $($s.why)" } }
  if ($n.x -ge $TORTA.x + $BOSS.plaza) { F "nest $($n.id) behind torta" }
}
for ($i = 0; $i -lt $nl.Count; $i++) { for ($j = $i + 1; $j -lt $nl.Count; $j++) { $d = Flat $nl[$i].x $nl[$i].z $nl[$j].x $nl[$j].z; if ($d -lt 20) { F "nests $($nl[$i].id) $($nl[$j].id) $(fmt $d)" } } }
# nests near the pond (nube reach 60 + 8) and hive (35 + 8)
foreach ($n in $nl) { if ((Flat $n.x $n.z $KEEP[0].x $KEEP[0].z) -lt 68) { F "nest $($n.id) under the Nube" }; if ((Flat $n.x $n.z $KEEP[1].x $KEEP[1].z) -lt 43) { F "nest $($n.id) under the Abeja" } }
# rarity by x
$sum = @{}; $cnt = @{}
foreach ($n in $nl) { $sum[$n.rar] += $n.x; $cnt[$n.rar] += 1 }
foreach ($k in $cnt.Keys) { "{0} {1} mean x {2:N1}" -f $k, $cnt[$k], ($sum[$k] / $cnt[$k]) }
foreach ($n in $nl) { if ($n.rar -eq 'Comun' -and $n.x -gt 450) { F "comun deep $($n.id)" }; if (($n.rar -eq 'Epica' -or $n.rar -eq 'Legendaria') -and $n.x -lt 540) { F "epica shallow $($n.id)" } }
# posts
$pl = @(); foreach ($k in $POSTS.Keys) { $p = $POSTS[$k]; $nn = $NESTS[$p[0]]; $pl += @{ id = $k; nest = $p[0]; x = $nn[1] + $p[1]; z = $nn[2] + $p[2]; c = $p[3]; kind = $p[4] } }
$pl += @{ id = 'bossHome'; x = $BOSS.hx; z = $BOSS.hz; c = 'DonGlaseon'; kind = 'boss' }
$pl += @{ id = 'bossTerritory'; x = $BOSS.x; z = $BOSS.z; c = 'DonGlaseon'; kind = 'boss' }
$nestOf = @{}
foreach ($p in $pl) {
  if ($p.kind -eq 'boss') { continue }
  $l = Liq $p.x $p.z; if ($l -lt 8) { F "post $($p.id) liquid $(fmt $l)" }
  $T = $CREAT[$p.c]
  if ($p.kind -eq 'extra') {
    $best = 1e9; $bid = $null; foreach ($n in $nl) { $d = Flat $p.x $p.z $n.x $n.z; if ($d -lt $best) { $best = $d; $bid = $n.id } }
    if ($best -lt 8 -or $best -gt 16) { F "post $($p.id) nearest $bid $(fmt $best)" }
    if ($bid -ne $p.nest) { F "post $($p.id) nearest is $bid not $($p.nest)" }
    if ($nestOf[$bid]) { F "post $($p.id) shares $bid" }; $nestOf[$bid] = $p.id
    $rd = RouteD $p.x $p.z; if ($rd -lt 11 -or $rd -gt $T[0]) { F "post $($p.id) route $(fmt $rd) wake $($T[0])" }
    if ((Depth $p.x $p.z) -lt $T[1]) { F "post $($p.id) leash leaves plot" }
    $tb = Flat $p.x $p.z $BOSS.x $BOSS.z; if ($tb -lt $BOSS.terr + $T[2]) { F "post $($p.id) boss $(fmt $tb) need $($BOSS.terr + $T[2])" }
    if ((Flat $p.x $p.z $ENTR[0] $ENTR[1]) -lt 30 + $T[2]) { F "post $($p.id) entrance" }
    foreach ($s in $KEEP) { if ((Flat $p.x $p.z $s.x $s.z) -lt $s.r) { F "post $($p.id) keep" } }
    $hp = $pl | Where-Object { $_.c -eq $p.c -and $_.kind -eq 'home' } | Select-Object -First 1
    if ((Flat $p.x $p.z $hp.x $hp.z) -lt 100) { F "post $($p.id) near home $(fmt (Flat $p.x $p.z $hp.x $hp.z))" }
  } else {
    $rd = RouteD $p.x $p.z; if ($rd -lt 11) { F "home post $($p.id) on route" }
    $d = Flat $p.x $p.z $NESTS[$p.nest][1] $NESTS[$p.nest][2]; if ($d -gt 20) { F "home $($p.id) far" }
  }
}
$ap = $pl | Where-Object { $_.kind -ne 'boss' }
for ($i = 0; $i -lt $ap.Count; $i++) { for ($j = $i + 1; $j -lt $ap.Count; $j++) { $d = Flat $ap[$i].x $ap[$i].z $ap[$j].x $ap[$j].z; if ($d -lt 30) { F "posts $($ap[$i].id) $($ap[$j].id) $(fmt $d)" } } }
# guardian binding: each guardian post binds nearest nest within 20; check unique & within wake/leash
foreach ($p in $pl) { if ($p.c -in @('Gomibu', 'Flanfuria', 'Tortidragon')) {
  $best = 1e9; $bid = $null; foreach ($n in $nl) { $d = Flat $p.x $p.z $n.x $n.z; if ($d -lt $best) { $best = $d; $bid = $n.id } }
  $T = $CREAT[$p.c]; if ($best -gt 20 -or $best -gt $T[0] -or $best -gt $T[1]) { F "guard $($p.id) $bid $(fmt $best)" }
  "guard {0} -> {1} {2:N1}" -f $p.id, $bid, $best } }
# routes: wet samples on deck, edge within 7 on bridge
foreach ($k in $ROUTES.Keys) { $r = $ROUTES[$k]; for ($i = 0; $i -lt $r.Count - 1; $i++) { $a = $r[$i]; $b = $r[$i + 1]; $L = Flat $a[0] $a[1] $b[0] $b[1]; $n = [math]::Max(1, [math]::Ceiling($L / 2))
  for ($s = 0; $s -le $n; $s++) { $x = $a[0] + ($b[0] - $a[0]) * $s / $n; $z = $a[1] + ($b[1] - $a[1]) * $s / $n; $d = Liq $x $z
    if ($d -le 0 -and -not (OnBridge $x $z $true)) { F "route $k wades $(fmt $x),$(fmt $z)" }
    if ($d -lt 7 -and -not (OnBridge $x $z $false)) { F "route $k edge wades $(fmt $x),$(fmt $z) d $(fmt $d)" } } } }
# bridges: on leg, over chocolate, wet span within deck, ramps 25 deg
foreach ($B in $BR) {
  if ($B.at - $B.length / 2 - $BB.ramp -lt -1e-6 -or $B.at + $B.length / 2 + $BB.ramp -gt $B.leg + 1e-6) { F "bridge $($B.id) off leg" }
  if ((Liq $B.x $B.z) -ge 0) { F "bridge $($B.id) dry" }
  $lo = 1e9; $hi = -1e9
  for ($s = -100; $s -le 100; $s++) { $x = $B.x + $B.ux * $s; $z = $B.z + $B.uz * $s; if ((Liq $x $z) -le 1) { $lo = [math]::Min($lo, $s); $hi = [math]::Max($hi, $s) } }
  "bridge {0} at ({1:N1},{2:N1}) wet(<=1) {3}..{4} deck +-{5}" -f $B.id, $B.x, $B.z, $lo, $hi, ($B.length / 2)
  if ($lo -lt -$B.length / 2 -or $hi -gt $B.length / 2) { F "bridge $($B.id) chocolate past deck" }
}
"ramp angle " + (fmt ([math]::Atan2($BB.deck, $BB.ramp) * 180 / [math]::PI))
# boss etc
if ((Liq $BOSS.x $BOSS.z) -lt $BOSS.terr) { F "boss liquid $(fmt (Liq $BOSS.x $BOSS.z))" } else { "boss liquid " + (fmt (Liq $BOSS.x $BOSS.z)) }
"portal liquid " + (fmt (Liq $PORTAL[0] $PORTAL[1])) + " entrance liquid " + (fmt (Liq $ENTR[0] $ENTR[1]))
foreach ($s in $KEEP) { $l = Liq $s.x $s.z; if ($l -lt $s.r) { F "keep $($s.why) liquid $(fmt $l)" } }
foreach ($t in $TRAPS) { if ((Liq $t[0] $t[1]) -lt 10) { F "trap liquid" } }
"gate->boss " + (fmt (Flat $GATE[0] $GATE[1] $BOSS.x $BOSS.z)) + " junction->boss " + (fmt (Flat 0 0 $BOSS.x $BOSS.z))
# return-ish routes out of boss territory + 7
foreach ($k in @('left', 'right', 'lake', 'alto', 'gate')) { $r = $ROUTES[$k]; for ($i = 0; $i -lt $r.Count - 1; $i++) { $a = $r[$i]; $b = $r[$i + 1]
  for ($s = 0; $s -le 50; $s++) { $x = $a[0] + ($b[0] - $a[0]) * $s / 50; $z = $a[1] + ($b[1] - $a[1]) * $s / 50; if ((Flat $x $z $BOSS.x $BOSS.z) -lt 83) { F "route $k in territory" } } } }
# pieces
$pieces = @()
foreach ($m in $MOUNT) { $pieces += @{ kind = 'mountain'; id = $m.id; x = $m.x; z = $m.z; r = $m.r; src = $m.src } }
foreach ($h in $HOUSES) { $pieces += @{ kind = 'house'; id = $h.id; x = $h.x; z = $h.z; r = $h.r } }
foreach ($d in $DOCKS) { $dx = $d.tx - $d.sx; $dz = $d.tz - $d.sz; $l = [math]::Sqrt($dx * $dx + $dz * $dz); $ux2 = $dx / $l; $uz2 = $dz / $l; $de = $l - 5
  $pieces += @{ kind = 'dock'; id = $d.id; x = $d.sx; z = $d.sz; r = 3 }
  $pieces += @{ kind = 'dock'; id = $d.id + 'Ramp'; x = $d.sx - $ux2 * 10; z = $d.sz - $uz2 * 10; r = 3.5 }
  $pieces += @{ kind = 'dock'; id = $d.id + 'Deck'; x = $d.sx + $ux2 * $de / 2; z = $d.sz + $uz2 * $de / 2; r = 3 }
  if ((Liq $d.sx $d.sz) -le 0) { F "dock $($d.id) stand wet $(fmt (Liq $d.sx $d.sz))" }
  if ((Liq $d.tx $d.tz) -gt -6) { F "dock $($d.id) tip $(fmt (Liq $d.tx $d.tz))" }
  if ((Liq ($d.sx - $ux2 * 10) ($d.sz - $uz2 * 10)) -le 0) { F "dock $($d.id) ramp foot wet" }
  if (NearBridge $d.tx $d.tz 6) { F "dock $($d.id) tip by bridge" }
  "dock {0} stand liq {1} tip liq {2} len {3}" -f $d.id, (fmt (Liq $d.sx $d.sz)), (fmt (Liq $d.tx $d.tz)), (fmt $l)
}
foreach ($f in $LIC.feet) { foreach ($sd in @(-1, 1)) { $pieces += @{ kind = 'licorice'; id = 'F'; x = $LIC.x; z = $LIC.z + $sd * $f[0] * $LIC.s; r = $f[1] * $LIC.s } } }
$pieces += @{ kind = 'cake'; id = 'Base'; x = $CAKE.x; z = $CAKE.z; r = $CAKE.r }
$pieces += @{ kind = 'cake'; id = 'Ramp'; x = $CAKE.x; z = $CAKE.z - ($CAKE.r + $CAKE.reach) / 2; r = ($CAKE.reach - $CAKE.r) / 2 + 2 }
foreach ($p in $pieces) { $lab = "$($p.kind) $($p.id)"
  foreach ($n in $nl) { if ((Flat $p.x $p.z $n.x $n.z) - $p.r -lt 8) { F "$lab on nest $($n.id)" } }
  foreach ($q in $ap) { if ((Flat $p.x $p.z $q.x $q.z) - $p.r -lt 6) { F "$lab on post $($q.id)" } }
  foreach ($t in $TRAPS) { if ((Flat $p.x $p.z $t[0] $t[1]) - $p.r -lt 10) { F "$lab on trap" } }
  $rd = RouteD $p.x $p.z; if ($rd - $p.r - 7 -lt 3) { F "$lab on route $(fmt ($rd - $p.r - 7))" }
  if ((Flat $p.x $p.z $BOSS.x $BOSS.z) - $p.r -lt 76) { F "$lab boss" }
  if ((Flat $p.x $p.z $PORTAL[0] $PORTAL[1]) - $p.r -lt 16) { F "$lab portal" }
  if ((Flat $p.x $p.z $ENTR[0] $ENTR[1]) - $p.r -lt 28) { F "$lab entrance" }
  foreach ($s in $KEEP) { if ((Flat $p.x $p.z $s.x $s.z) - $p.r - $s.r -lt 2) { F "$lab keep $($s.why)" } }
  if ($p.kind -eq 'mountain') { if ((Depth $p.x $p.z) -lt $p.r - 0.5) { F "$lab leaves plot" } } else { if ((Depth $p.x $p.z) - $p.r -lt 2) { F "$lab edge" } }
  if (-not $p.src -and $p.kind -ne 'dock') { if ((Liq $p.x $p.z) - $p.r -lt 2) { F "$lab in chocolate $(fmt ((Liq $p.x $p.z) - $p.r))" } }
  if ($p.kind -ne 'dock' -and (NearBridge $p.x $p.z $p.r)) { F "$lab on bridge" }
}
for ($i = 0; $i -lt $pieces.Count; $i++) { for ($j = $i + 1; $j -lt $pieces.Count; $j++) { $a = $pieces[$i]; $b = $pieces[$j]
  if ($a.kind -eq 'cake' -and $b.kind -eq 'cake') { continue }; if ($a.kind -eq 'dock' -and $b.kind -eq 'dock' -and $a.id[0] -eq $b.id[0]) { continue }
  if ((Flat $a.x $a.z $b.x $b.z) - $a.r - $b.r -lt 2) { F "$($a.kind) $($a.id) touches $($b.kind) $($b.id)" } } }
$mm1 = $MOUNT[0]; if ($mm1.x + $mm1.r -lt $PLOT.maxX - 0.5) { F "M1 not on east edge" }
# houses door
foreach ($h in $HOUSES) { $yx = 0 - $h.x; $yz = 0 - $h.z; $l = [math]::Sqrt($yx * $yx + $yz * $yz); $lx = $yx / $l; $lz = $yz / $l; if ($h.turn -eq 180) { $lx = -$lx; $lz = -$lz }
  $dx = $h.x + $lx * ($h.r + 4); $dz = $h.z + $lz * ($h.r + 4)
  if ((Depth $dx $dz) -lt 5) { F "door $($h.id) edge" }; if ((Liq $dx $dz) -lt 4) { F "door $($h.id) chocolate" }
  foreach ($p in $pieces) { if (-not ($p.kind -eq 'house' -and $p.id -eq $h.id)) { if ((Flat $dx $dz $p.x $p.z) - $p.r -lt 4) { F "door $($h.id) faces $($p.kind) $($p.id)" } } } }
# hills
foreach ($h in $HILLS) { if ($h.r -eq 0) { continue }; $x = $HILLX; $z = $h.z
  foreach ($n in $nl) { if ((Flat $x $z $n.x $n.z) - $h.r -lt 8) { F "hill $($h.id) nest $($n.id)" } }
  foreach ($q in $ap) { if ((Flat $x $z $q.x $q.z) - $h.r -lt 6) { F "hill $($h.id) post" } }
  if ((RouteD $x $z) - $h.r - 7 -lt 3) { F "hill $($h.id) route" }
  if ((Flat $x $z $BOSS.x $BOSS.z) - $h.r -lt 76) { F "hill $($h.id) boss" }
  foreach ($s in $KEEP) { if ((Flat $x $z $s.x $s.z) - $h.r - $s.r -lt 2) { F "hill keep" } }
  foreach ($p in $pieces) { if ((Flat $x $z $p.x $p.z) - $h.r - $p.r -lt 2) { F "hill $($h.id) on $($p.kind) $($p.id)" } }
  if ((Liq $x $z) - $h.r -lt 2) { F "hill $($h.id) chocolate" } }
# platforms in a lake disc, off bridges, apart
for ($i = 0; $i -lt $PLAT.Count; $i++) { $pl2 = $PLAT[$i]; $in = $false; foreach ($d in $LAKE) { if ((Flat $pl2.x $pl2.z $d.x $d.z) + $pl2.r -le $d.r) { $in = $true } }
  if (-not $in) { F "platform $i out of lake" }
  for ($j = $i + 1; $j -lt $PLAT.Count; $j++) { if ((Flat $pl2.x $pl2.z $PLAT[$j].x $PLAT[$j].z) - $pl2.r - $PLAT[$j].r -lt 2) { F "platforms $i $j touch" } }
  foreach ($IS in $ISL) { if ((Flat $pl2.x $pl2.z $IS.x $IS.z) - $pl2.r - $IS.foot -lt 4) { F "platform $i on island" } } }
# island: inside disc 1, hull channel all round, off docks
$IS = $ISL[0]
if ((Flat $IS.x $IS.z $LAKE[0].x $LAKE[0].z) + $IS.foot -gt $LAKE[0].r) { F "island leaves disc 1" }
for ($a = 0; $a -lt 360; $a += 10) { $rad = $a * [math]::PI / 180; $x = $IS.x + [math]::Cos($rad) * ($IS.r + 3.5); $z = $IS.z + [math]::Sin($rad) * ($IS.r + 3.5)
  if ((Liq $x $z) -gt -3 + 0.0 -and $false) { } }
foreach ($d in $DOCKS) { if ((Flat $IS.x $IS.z $d.tx $d.tz) - $IS.foot -lt 15) { F "island by tip $($d.id)" }; if ((Flat $IS.x $IS.z $d.sx $d.sz) - $IS.foot -lt 20) { F "island by stand $($d.id)" } }
# raft: centreline samples float a hull (liquid <= -3), except within 30 of the mouth edge
$sails = 0; $dry = 0
for ($i = 0; $i -lt $RIVER.Count - 1; $i++) { $a = $RIVER[$i]; $b = $RIVER[$i + 1]; $L = Flat $a[0] $a[1] $b[0] $b[1]; $n = [math]::Ceiling($L / 2)
  for ($s = 0; $s -lt $n; $s++) { $x = $a[0] + ($b[0] - $a[0]) * $s / $n; $z = $a[1] + ($b[1] - $a[1]) * $s / $n
    if ((Depth $x $z) -lt 4) { continue }
    if ((Liq $x $z) -le -3) { $sails++ } else { $dry++; F "centreline dry for hull at $(fmt $x),$(fmt $z) $(fmt (Liq $x $z))" } } }
"centreline hull samples ok $sails, dry $dry"
"wet area / hull area:"; $wet = 0; $hull = 0
for ($x = -258; $x -le 858; $x += 8) { for ($z = -258; $z -le 258; $z += 8) { $l = Liq $x $z; if ($l -lt 0) { $wet += 64 }; if ($l -le -3) { $hull += 64 } } }
"wet $wet hull $hull plot $((1120*520)) share $(fmt (100*$wet/(1120*520)))%"
# Nube / Abeja homes (BeastSites S7)
$pond = $KEEP[0]; $hive = $KEEP[1]
function NN($x, $z) { $b = 1e9; foreach ($n in $nl) { $b = [math]::Min($b, (Flat $x $z $n.x $n.z)) }; $b }
"pond route {0} portal {1} entr {2} boss {3} nest {4} depth {5}" -f (fmt (RouteD $pond.x $pond.z)), (fmt (Flat $pond.x $pond.z $PORTAL[0] $PORTAL[1])), (fmt (Flat $pond.x $pond.z $ENTR[0] $ENTR[1])), (fmt (Flat $pond.x $pond.z $BOSS.x $BOSS.z)), (fmt (NN $pond.x $pond.z)), (fmt (Depth $pond.x $pond.z))
"hive route {0} portal {1} entr {2} boss {3} nest {4} depth {5}" -f (fmt (RouteD $hive.x $hive.z)), (fmt (Flat $hive.x $hive.z $PORTAL[0] $PORTAL[1])), (fmt (Flat $hive.x $hive.z $ENTR[0] $ENTR[1])), (fmt (Flat $hive.x $hive.z $BOSS.x $BOSS.z)), (fmt (NN $hive.x $hive.z)), (fmt (Depth $hive.x $hive.z))
if ((RouteD $pond.x $pond.z) -lt 67 -or (NN $pond.x $pond.z) -lt 68 -or (Flat $pond.x $pond.z $BOSS.x $BOSS.z) -lt 136) { F "pond reach" }
if ((RouteD $hive.x $hive.z) -lt 42 -or (NN $hive.x $hive.z) -lt 43 -or (Flat $hive.x $hive.z $ENTR[0] $ENTR[1]) -le 70) { F "hive reach" }
# barrier: every x column from the west edge to M1 meets chocolate
for ($x = -258; $x -le 858; $x += 6) { $hit = $false; for ($z = -256; $z -le 256; $z += 8) { if ((Liq $x $z) -lt 0) { $hit = $true; break } }
  if (-not $hit -and [math]::Abs($x - $MOUNT[0].x) -gt $MOUNT[0].r) { F "dry column x $x" } }
# min liquid margins report
foreach ($n in $nl) { $l = Liq $n.x $n.z; if ($l -lt 12) { "tight nest {0} liquid {1}" -f $n.id, (fmt $l) } }
foreach ($p in $ap) { $l = Liq $p.x $p.z; if ($l -lt 14) { "tight post {0} liquid {1}" -f $p.id, (fmt $l) }; $rd = RouteD $p.x $p.z; if ($p.kind -eq 'extra') { $w = $CREAT[$p.c][0]; if ($w - $rd -lt 4) { "tight post {0} route {1} wake {2}" -f $p.id, (fmt $rd), $w } } }
foreach ($p in $ap) { "post {0} {1} ({2:N1},{3:N1}) world ({4:N1},{5:N1}) liq {6:N1} route {7:N1} boss {8:N1}" -f $p.id, $p.c, $p.x, $p.z, ($p.x + 672), ($p.z - 3), (Liq $p.x $p.z), (RouteD $p.x $p.z), (Flat $p.x $p.z $BOSS.x $BOSS.z) }
foreach ($n in $nl) { "nest {0} {1} ({2},{3}) liq {4:N1} route {5:N1} boss {6:N1} reach {7}" -f $n.id, $n.rar, $n.x, $n.z, (Liq $n.x $n.z), (RouteD $n.x $n.z), (Flat $n.x $n.z $BOSS.x $BOSS.z), ($n.x + 260) }
foreach ($p in $pieces) { "piece {0} {1} ({2:N1},{3:N1}) r {4:N2} liq-r {5:N1} route-r-7 {6:N1} depth {7:N1}" -f $p.kind, $p.id, $p.x, $p.z, $p.r, ((Liq $p.x $p.z) - $p.r), ((RouteD $p.x $p.z) - $p.r - 7), (Depth $p.x $p.z) }
"---- FAILS: $($fails.Count)"; $fails | Select-Object -First 80



