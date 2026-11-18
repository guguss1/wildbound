$ErrorActionPreference = 'Stop'
$S = 1.3; $HALF = 260.0
$fails = New-Object System.Collections.ArrayList
$notes = New-Object System.Collections.ArrayList
function Fail($m) { [void]$fails.Add($m) }
function Note($m) { [void]$notes.Add($m) }
function P($x, $z) { return @{ x = [double]$x; z = [double]$z } }
function Flat($ax, $az, $bx, $bz) { return [math]::Sqrt(($ax - $bx) * ($ax - $bx) + ($az - $bz) * ($az - $bz)) }
function SegD($x, $z, $ax, $az, $bx, $bz) {
	$dx = $bx - $ax; $dz = $bz - $az; $l2 = $dx * $dx + $dz * $dz; $t = 0.0
	if ($l2 -gt 0) { $t = (($x - $ax) * $dx + ($z - $az) * $dz) / $l2; if ($t -lt 0) { $t = 0 } elseif ($t -gt 1) { $t = 1 } }
	return Flat $x $z ($ax + $dx * $t) ($az + $dz * $t)
}
function Depth($x, $z) { return $HALF - [math]::Max([math]::Abs($x), [math]::Abs($z)) }

# ---- Layout ----
$TORTA = @{ x = 114 * $S; z = 0.0; radius = 42.0 }
$BOSS = @{ x = $TORTA.x; z = 0.0; plaza = 58.0; terr = 76.0; perc = 36.0; whip = 22.0; home = (P ($TORTA.x + (64 - 114)) 0) }
$PORTAL = P (-24 * $S) 0
$ENTR = P (-$HALF) 0
$FORK = P (-110 * $S) 0
function RouteOf($pts) { $l = @(); foreach ($p in $pts) { $l += , (P ($p[0] * $S) ($p[1] * $S)) }; return , $l }
$ROUTES = [ordered]@{
	main = @($ENTR, (P (-110 * $S) 0), (P 0 0), (P ($TORTA.x - $BOSS.plaza) 0))
	left = (RouteOf @(@(-110, 0), @(-100, -80), @(-50, -140), @(50, -140), @(90, -110), @(0, 0)))
	right = (RouteOf @(@(-110, 0), @(-90, 70), @(-40, 120), @(40, 120), @(80, 100), @(0, 0)))
	deep = (RouteOf @(@(0, 0), @(-24, 0)))
}
$BRIDGE = @{ x = 0.0; z = -140 * $S; length = 86.0 }
$SLAKE = @(
	@{ x = $BRIDGE.x + 0; z = $BRIDGE.z + 20; r = 24.0 },
	@{ x = $BRIDGE.x + 26; z = $BRIDGE.z + 6; r = 16.0 },
	@{ x = $BRIDGE.x - 26; z = $BRIDGE.z + 6; r = 16.0 })
$KEEP = @(@{ x = 165 * $S; z = 150 * $S; r = 26.0; why = 'pond' }, @{ x = -60 * $S; z = 185 * $S; r = 10.0; why = 'hive' })
$nestRows = @(
	@('C1', 'Comun', -160, -18), @('C2', 'Comun', -140, 24), @('C3', 'Comun', -90, -132), @('C4', 'Comun', -62, 130), @('C5', 'Comun', 60, 152),
	@('R1', 'Rara', -78, -30), @('R2', 'Rara', -78, 34), @('R3', 'Rara', -45, -93), @('R4', 'Rara', -20, 95), @('E1', 'Epica', -34, -20),
	@('E2', 'Epica', -34, 24), @('L1', 'Legendaria', 36, -22), @('C6', 'Comun', 10, -162), @('C7', 'Comun', 5, 142), @('C8', 'Comun', 60, -170),
	@('C9', 'Comun', -135, -62), @('C10', 'Comun', -60, -162), @('R5', 'Rara', 88, 112), @('R6', 'Rara', 96, -122), @('R7', 'Rara', -116, 58),
	@('E3', 'Epica', 0, 36), @('R8', 'Rara', -110, 95), @('R9', 'Rara', -60, 70), @('R10', 'Rara', -10, -45), @('R11', 'Rara', 36, 74),
	@('C11', 'Comun', -30, 150), @('C12', 'Comun', -130, -100), @('C13', 'Comun', 100, -150))
$NESTS = @(); $NB = @{}
foreach ($r in $nestRows) { $n = @{ id = $r[0]; rarity = $r[1]; x = $r[2] * $S; z = $r[3] * $S }; $NESTS += $n; $NB[$r[0]] = $n }
# posts: v7 offset from the paired nest
$postRows = @(@('candyNest', 'C1', -6, 6), @('candyNestR1', 'R1', 8, -8), @('candyNestC3', 'C3', -12, -8), @('candyNestC2', 'C2', -6, 13),
	@('candyNestR2', 'R2', 5, 12), @('candyNestR3', 'R3', 12, 10), @('candyNestR4', 'C5', 6, 14), @('candyNestC4', 'C4', -8, 12),
	@('candyPostC7', 'C7', 7, -9), @('candyPostR6', 'R6', 7, 5), @('candyPostC8', 'C8', -5, 12), @('candyPostC9', 'C9', 11, 4),
	@('candyPostR7', 'R7', -10, 8), @('candyPostR5', 'R5', 8, 10), @('candyPostC6', 'C6', -10, 8), @('candyPostC10', 'C10', 12, 8),
	@('candyPostE3', 'E3', -12, 0), @('candyPostR8', 'R8', 12, 0), @('candyPostR9', 'R9', 12, 0), @('candyPostR10', 'R10', 6, -11),
	@('candyPostC11', 'C11', 0, -12), @('candyPostC12', 'C12', 12, 0), @('candyPostC13', 'C13', -12, 1), @('candyPostR11', 'R11', -9, 8))
$POSTS = @()
foreach ($r in $postRows) { $n = $NB[$r[1]]; $POSTS += @{ id = $r[0]; x = $n.x + $r[2]; z = $n.z + $r[3] } }
$POSTS += @{ id = 'bossHome'; x = $BOSS.home.x; z = 0.0 }; $POSTS += @{ id = 'bossTerritory'; x = $BOSS.x; z = 0.0 }
$TRAPS = @(@{ key = 'riverside'; x = -97 * $S; z = -55 * $S }, @{ key = 'path'; x = -72 * $S; z = 8 * $S },
	@{ key = 'rareNest'; x = $NB['R1'].x - 8; z = $NB['R1'].z + 9 }, @{ key = 'rareNestScaled'; x = -86 * $S; z = -21 * $S })

function RouteDist($x, $z, $name) {
	$best = [double]::MaxValue
	foreach ($k in $ROUTES.Keys) { if ($null -eq $name -or $name -eq $k) { $pts = $ROUTES[$k]
		for ($i = 0; $i -lt $pts.Count - 1; $i++) { $d = SegD $x $z $pts[$i].x $pts[$i].z $pts[$i + 1].x $pts[$i + 1].z; if ($d -lt $best) { $best = $d } } } }
	return $best
}
function RouteLen($name) { $pts = $ROUTES[$name]; $t = 0; for ($i = 0; $i -lt $pts.Count - 1; $i++) { $t += Flat $pts[$i].x $pts[$i].z $pts[$i + 1].x $pts[$i + 1].z }; return $t }
function Samples($name) {
	$out = @(); $pts = $ROUTES[$name]
	for ($i = 0; $i -lt $pts.Count - 1; $i++) { $a = $pts[$i]; $b = $pts[$i + 1]
		$steps = [math]::Max(1, [math]::Ceiling((Flat $a.x $a.z $b.x $b.z) / 2))
		for ($s = 0; $s -le $steps; $s++) { $out += , @{ name = $name; x = $a.x + ($b.x - $a.x) * $s / $steps; z = $a.z + ($b.z - $a.z) * $s / $steps } } }
	return $out
}

# ---- V3 ----
$M1DX = -4 * $S - -4; $M1DZ = $HALF - 24 - 176
$D1DX = 8 * $S - 8; $D1DZ = -98 * $S + 98
$D2DX = -14 * $S + 14; $D2DZ = -114 * $S + 114
$MOUNT = @(
	@{ id = 'M1'; x = -4 * $S; z = $HALF - 24; r = 24.3; river = $true },
	@{ id = 'M2'; x = 180 * $S; z = -90 * $S; r = 14.2 }, @{ id = 'M3'; x = 76 * $S; z = 187 * $S; r = 13.1 },
	@{ id = 'M4'; x = 165 * $S; z = -120 * $S; r = 13.1 }, @{ id = 'M5'; x = -186 * $S; z = -186 * $S; r = 13.1 },
	@{ id = 'M6'; x = -187 * $S; z = 187 * $S; r = 13.1 })
$RIVER = @(
	@((-8.36 + $M1DX), (154.08 + $M1DZ), 12), @((-12 + $M1DX), (138 + $M1DZ), 19), @((-10 * $S), (131 * $S), 19.5),
	@((-9 * $S), (120 * $S + 4), 24), @((-3 * $S), (104 * $S), 24), @((5 * $S), (82 * $S), 24), @((11 * $S), (62 * $S), 24),
	@((13 * $S), (54 * $S), 24), @((12 * $S), (50 * $S), 16), @((12 * $S), (44 * $S), 10), @((11.25 * $S), (30.07 * $S), 10),
	@((19.06 * $S), (23.82 * $S), 10), @((27.49 * $S), (13.21 * $S), 10), @((30.5 * $S), 0, 10), @((27.57 * $S), (-13.06 * $S), 10),
	@((19.31 * $S), (-23.6 * $S), 10), @((11.57 * $S), (-29.93 * $S), 10), @((12 * $S), (-42 * $S), 14), @((17 * $S), (-58 * $S), 20),
	@((14 * $S), (-90 * $S), 24), @((24 * $S), (-125 * $S), 24), @((27 * $S), (-140 * $S), 24), @((29 * $S), (-170 * $S), 24),
	@((30 * $S), (-$HALF), 24))
if ($args -contains 'scaledTop') { $RIVER[3] = @((-9 * $S), (124 * $S), 24) }
if ($args -contains 'scaledRiver3') { $RIVER[2] = @((-10 + $M1DX), (131 + $M1DZ), 19.5) }
$POOL = @{ x = -7.24 + $M1DX; z = 159.36 + $M1DZ; r = 4.95 }
$W = @{ x = -6.62 + $M1DX; z = 162.3 + $M1DZ }
$LAKE = @(@{ x = 8 * $S; z = -98 * $S; r = 34.5 }, @{ x = -14 * $S; z = -114 * $S; r = 18.0 })
$ISL = @(@{ x = 15 + $D1DX; z = -73 + $D1DZ; r = 6.5 })
if ($args -contains 'islandScaled') { $ISL = @(@{ x = 15 * $S; z = -73 * $S; r = 6.5 }) }
$BB = @{ width = 15.0; deck = 4.1; ramp = 9.0; gapWidth = 8.0; sideRamp = 9.0 }
$brows = @(
	@{ id = 'Top'; route = 'right'; from = @((-40 * $S), (120 * $S)); to = @((40 * $S), (120 * $S)); at = 31 * $S; length = 28.0; gaps = @(0) },
	@{ id = 'RightLast'; route = 'right'; from = @((80 * $S), (100 * $S)); to = @(0.0, 0.0); at = 97.56 * $S; length = 11.0; gaps = @() },
	@{ id = 'Main'; route = 'main'; from = @(0.0, 0.0); to = @((114 * $S - 58), 0.0); at = 30.5 * $S; length = 11.0; gaps = @() },
	@{ id = 'LeftLast'; route = 'left'; from = @((90 * $S), (-110 * $S)); to = @(0.0, 0.0); at = 111.63 * $S; length = 11.0; gaps = @() },
	@{ id = 'Bottom'; route = 'left'; from = @((-50 * $S), (-140 * $S)); to = @((50 * $S), (-140 * $S)); at = 76 * $S; length = 28.0; gaps = @(0) })
$BRIDGES = @()
foreach ($b in $brows) { $dx = $b.to[0] - $b.from[0]; $dz = $b.to[1] - $b.from[1]; $l = [math]::Sqrt($dx * $dx + $dz * $dz)
	$b.ux = $dx / $l; $b.uz = $dz / $l; $b.x = $b.from[0] + $b.ux * $b.at; $b.z = $b.from[1] + $b.uz * $b.at
	foreach ($k in $BB.Keys) { $b[$k] = $BB[$k] }; $BRIDGES += $b }
$HOUSES = @(
	@{ id = 'H1'; asset = 'Sweet'; x = -148 * $S; z = 166 * $S; r = 28.0; turn = 0 }, @{ id = 'H2'; asset = 'Tower'; x = -100 * $S; z = 175 * $S; r = 15.0; turn = 180 },
	@{ id = 'H3'; asset = 'Choco'; x = -158 * $S; z = -150 * $S; r = 22.4; turn = 0 }, @{ id = 'H4'; asset = 'Sweet'; x = 178 * $S; z = 100 * $S; r = 20.0; turn = 0 },
	@{ id = 'H5'; asset = 'Tower'; x = -168 * $S; z = -82 * $S; r = 21.0; turn = 180 }, @{ id = 'H6'; asset = 'Choco'; x = 150 * $S; z = -170 * $S; r = 16.0; turn = 0 },
	@{ id = 'H7'; asset = 'Sweet'; x = 110 * $S; z = 178 * $S; r = 20.0; turn = 0 })
$DOCKS = @(@{ id = 'A'; sx = -38 + $D2DX; sz = -116 + $D2DZ; tx = -22 + $D2DX; tz = -114 + $D2DZ },
	@{ id = 'B'; sx = 48 + $D1DX; sz = -104 + $D1DZ; tx = 32 + $D1DX; tz = -102 + $D1DZ })
$DOCK = @{ deckWidth = 6.0; tipGap = 5.0; rampBack = 10.0 }
$LIC = @{ x = -124 * $S; z = 0.0; scale = 0.8; feet = @(@{ off = 20.6; r = 5.7 }, @{ off = 34.8; r = 4.5 }) }
$CAKE = @{ x = -150 * $S; z = 112 * $S; r = 18.0; reach = 38.5; fx = -150 * $S; fz = 0.0 }
$PLAT = @(@{ x = -6 + $D2DX; z = -120 + $D2DZ; r = 6.7 }, @{ x = 0 + $D1DX; z = -88 + $D1DZ; r = 11.7 }, @{ x = 20 + $D1DX; z = -86 + $D1DZ; r = 3.9 }, @{ x = -20 + $D1DX; z = -90 + $D1DZ; r = 3.9 })
$HILLS = @(@{ id = 'Hill_1'; z = -190; r = 17.75 }, @{ id = 'Hill_2'; z = -125; r = 16.0 }, @{ id = 'Hill_3'; z = -60; r = 17.75 }, @{ id = 'Hill_4'; z = 60; r = 17.75 }, @{ id = 'Hill_5'; z = 125; r = 9.94 }, @{ id = 'Hill_6'; z = 190; r = 17.75 })
foreach ($h in $HILLS) { $h.x = $HALF - 2; $h.z = $h.z * $S }

function RiverD($x, $z) { $best = [double]::MaxValue
	for ($i = 0; $i -lt $RIVER.Count - 1; $i++) { $a = $RIVER[$i]; $b = $RIVER[$i + 1]
		$d = (SegD $x $z $a[0] $a[1] $b[0] $b[1]) - [math]::Max($a[2], $b[2]) / 2; if ($d -lt $best) { $best = $d } }
	return $best }
function IslD($x, $z) { $best = [double]::MaxValue; foreach ($i in $ISL) { $d = (Flat $x $z $i.x $i.z) - $i.r; if ($d -lt $best) { $best = $d } }; return $best }
function LiqD($x, $z) { $best = RiverD $x $z
	$d = (Flat $x $z $POOL.x $POOL.z) - $POOL.r; if ($d -lt $best) { $best = $d }
	foreach ($c in $LAKE) { $d = (Flat $x $z $c.x $c.z) - $c.r; if ($d -lt $best) { $best = $d } }
	return [math]::Max($best, -(IslD $x $z)) }
function Frame($Br, $x, $z) { $dx = $x - $Br.x; $dz = $z - $Br.z; return @(($dx * $Br.ux + $dz * $Br.uz), (-$dx * $Br.uz + $dz * $Br.ux)) }
function OnBridge($x, $z, $deckOnly) { foreach ($Br in $BRIDGES) { $f = Frame $Br $x $z; $ext = 0; if (-not $deckOnly) { $ext = $Br.ramp }
		if ([math]::Abs($f[1]) -le $Br.width / 2 -and [math]::Abs($f[0]) -le $Br.length / 2 + $ext) { return $Br } }; return $null }
function NearBridge($x, $z, $reach) { foreach ($Br in $BRIDGES) { $f = Frame $Br $x $z; $side = 0; if ($Br.gaps.Count -gt 0) { $side = $Br.sideRamp }
		if ([math]::Abs($f[1]) -le $Br.width / 2 + $side + $reach -and [math]::Abs($f[0]) -le $Br.length / 2 + $Br.ramp + $reach) { return $true } }; return $false }
function DockPts($d) { $dx = $d.tx - $d.sx; $dz = $d.tz - $d.sz; $l = [math]::Sqrt($dx * $dx + $dz * $dz); $ux = $dx / $l; $uz = $dz / $l; $de = $l - $DOCK.tipGap
	return @{ foot = (P ($d.sx - $ux * $DOCK.rampBack) ($d.sz - $uz * $DOCK.rampBack)); mid = (P ($d.sx + $ux * $de / 2) ($d.sz + $uz * $de / 2)) } }
function FaceYaw($x, $z, $tx, $tz) { return [math]::Atan2(-($tx - $x), -($tz - $z)) }
function Pieces { $l = @()
	foreach ($m in $MOUNT) { $l += , @{ kind = 'mountain'; id = $m.id; x = $m.x; z = $m.z; r = $m.r } }
	foreach ($h in $HOUSES) { $l += , @{ kind = 'house'; id = $h.id; x = $h.x; z = $h.z; r = $h.r } }
	foreach ($d in $DOCKS) { $p = DockPts $d
		$l += , @{ kind = 'dock'; id = $d.id; x = $d.sx; z = $d.sz; r = 3.0 }
		$l += , @{ kind = 'dock'; id = $d.id + 'Ramp'; x = $p.foot.x; z = $p.foot.z; r = $DOCK.deckWidth / 2 + 0.5 }
		$l += , @{ kind = 'dock'; id = $d.id + 'Deck'; x = $p.mid.x; z = $p.mid.z; r = $DOCK.deckWidth / 2 } }
	$i = 0; foreach ($f in $LIC.feet) { $i++; $k = 0; foreach ($side in @(-1, 1)) { $k++; $l += , @{ kind = 'licorice'; id = "Foot$i$k"; x = $LIC.x; z = $LIC.z + $side * $f.off * $LIC.scale; r = $f.r * $LIC.scale } } }
	$l += , @{ kind = 'cake'; id = 'Base'; x = $CAKE.x; z = $CAKE.z; r = $CAKE.r }
	$yaw = FaceYaw $CAKE.x $CAKE.z $CAKE.fx $CAKE.fz; $mid = ($CAKE.r + $CAKE.reach) / 2
	$l += , @{ kind = 'cake'; id = 'Ramp'; x = $CAKE.x - [math]::Sin($yaw) * $mid; z = $CAKE.z - [math]::Cos($yaw) * $mid; r = ($CAKE.reach - $CAKE.r) / 2 + 2 }
	return , $l }
$PIECES = Pieces
$hp = 7.0

# ===== Layout_Test =====
foreach ($n in @('left', 'right')) { foreach ($p in (Samples $n)) {
		if ((Flat $p.x $p.z $BOSS.x $BOSS.z) -lt 83) { Fail "L: $n in boss" }; if ((Depth $p.x $p.z) -lt 20) { Fail "L: $n leaves" } } }
if ((RouteLen 'left') -le (RouteLen 'right')) { Fail 'L: left shorter' }
Note ("route lengths left {0:N1} right {1:N1} main {2:N1}" -f (RouteLen 'left'), (RouteLen 'right'), (RouteLen 'main'))
$ring = @{ Comun = @(0, (75 * $S)); Rara = @((75 * $S), (160 * $S)); Epica = @((160 * $S), (200 * $S)); Legendaria = @((160 * $S), (200 * $S)) }
foreach ($n in $NESTS) { $d = Depth $n.x $n.z; $b = $ring[$n.rarity]; if ($d -lt $b[0] -or $d -gt $b[1]) { Fail "L: ring $($n.id) $d" } }
$near = 0; $minEnt = 999
foreach ($n in $NESTS) { $d = Flat $n.x $n.z $ENTR.x $ENTR.z; if ($d -lt $minEnt) { $minEnt = $d }
	if ($d -lt 30 * $S) { Fail "L: crowds entrance $($n.id)" }; if ($d -le 70 * $S) { if ($n.rarity -ne 'Comun') { Fail "L: near not comun $($n.id)" }; $near++ } }
Note "first nests within 91: $near (closest $minEnt)"
if ($near -lt 2) { Fail 'L: fewer than two first nests' }
$maxRoute = 0
for ($i = 0; $i -lt $NESTS.Count; $i++) { $n = $NESTS[$i]
	$tr = RouteDist $n.x $n.z $null; $tt = Flat $n.x $n.z $TORTA.x $TORTA.z
	if ($tr -lt 11) { Fail "L: $($n.id) blocks path" }
	if ($tt -gt $BOSS.plaza -and $tr -gt $maxRoute) { $maxRoute = $tr; $maxId = $n.id }
	if ($tr -gt 40) { Note ("nest {0} {1:N1} from a route (>40)" -f $n.id, $tr) }
	if ($tt -lt 48) { Fail "L: in torta" }
	for ($j = $i + 1; $j -lt $NESTS.Count; $j++) { if ((Flat $n.x $n.z $NESTS[$j].x $NESTS[$j].z) -lt 20) { Fail "L: touch $($n.id)" } }
	foreach ($c in $SLAKE) { if ((Flat $n.x $n.z $c.x $c.z) -lt $c.r + 6) { Fail "L: $($n.id) in syrup" } }
	foreach ($c in $KEEP) { if ((Flat $n.x $n.z $c.x $c.z) -lt $c.r + 20) { Fail "L: $($n.id) on keep" } }
	if ((Flat $n.x $n.z $BOSS.x $BOSS.z) -lt 96) { Note "nest $($n.id) within boss+20" }
	if ((Flat $n.x $n.z $ENTR.x $ENTR.z) -lt 80) { Note "nest $($n.id) within 80 of entrance" }
	if ((Flat $n.x $n.z $PORTAL.x $PORTAL.z) -lt 16) { Fail "L: $($n.id) on portal" }
	if ($n.x -ge $TORTA.x) { Fail "L: behind torta" } }
Note ("max nest route distance {0:N2} ({1})" -f $maxRoute, $maxId)
Note ("territory east depth {0:N2}; plaza east depth {1:N2}" -f (Depth ($BOSS.x + 76) 0), (Depth ($TORTA.x + 58) 0))
Note ("home to avenue end {0:N2}" -f (Flat $BOSS.home.x 0 $ROUTES.main[3].x 0))
foreach ($c in $SLAKE) { if ((Depth $c.x $c.z) - $c.r -lt 20) { Fail 'L: syrup leaves' }; if ((Flat $c.x $c.z $BOSS.x $BOSS.z) - $c.r -lt 76) { Fail 'L: syrup in territory' } }
foreach ($n in $ROUTES.Keys) { foreach ($p in (Samples $n)) { foreach ($c in $SLAKE) { if ((Flat $p.x $p.z $c.x $c.z) -le $c.r) {
				if (-not ([math]::Abs($p.x - $BRIDGE.x) -le 43 -and [math]::Abs($p.z - $BRIDGE.z) -le 7)) { Fail ("L: {0} wades syrup at {1:N1},{2:N1}" -f $n, $p.x, $p.z) } } } } }

# ===== V3Layout_Test =====
$first = $RIVER[0]; $last = $RIVER[$RIVER.Count - 1]
if ((Flat $first[0] $first[1] $POOL.x $POOL.z) -gt $POOL.r + 1) { Fail 'V2: river start' }
if ([math]::Abs((Depth $last[0] $last[1])) -ge 0.01) { Fail 'V2: river end' }
$m1 = $MOUNT[0]; if ($m1.z + $m1.r -lt $HALF - 0.5) { Fail 'V2: M1 edge' }
for ($i = 0; $i -lt $RIVER.Count; $i++) { $p = $RIVER[$i]; if ($i -gt 0 -and $p[2] -lt 10) { Fail 'V2: narrow' }
	if ($i -lt $RIVER.Count - 1 -and (Depth $p[0] $p[1]) - $p[2] / 2 -lt 2) { Fail "V2: point $i leaves" } }
# barrier
for ($z = -$HALF; $z -le $HALF; $z += 2) { if ([math]::Abs($z - $m1.z) -gt $m1.r) { $west = [double]::MaxValue
		for ($x = -$HALF; $x -le 80; $x++) { if ((LiqD $x $z) -lt 0) { $west = $x; break } }
		if ($west -ge $BOSS.x - 76 + 1) { Fail "V14: dry/east at z $z ($west)" } } }
if ((Flat $W.x $W.z $m1.x $m1.z) -ge $m1.r) { Fail 'V3: sheet' }; if ((Flat $W.x $W.z $POOL.x $POOL.z) -ge $POOL.r) { Fail 'V3: pool' }
# V3-4
foreach ($n in $ROUTES.Keys) { foreach ($p in (Samples $n)) { $d = LiqD $p.x $p.z
		if ($d -le 0 -and $null -eq (OnBridge $p.x $p.z $true)) { Fail ("V4: {0} wades at {1:N1},{2:N1}" -f $n, $p.x, $p.z) }
		if ($d -lt $hp -and $null -eq (OnBridge $p.x $p.z $false)) { Fail ("V4: {0} edge wades at {1:N1},{2:N1} d {3:N2}" -f $n, $p.x, $p.z, $d) } } }
foreach ($Br in $BRIDGES) { $pts = $ROUTES[$Br.route]; $onLeg = $false
	for ($i = 0; $i -lt $pts.Count - 1; $i++) { $a = $pts[$i]; $b = $pts[$i + 1]
		if ($a.x -eq $Br.from[0] -and $a.z -eq $Br.from[1] -and $b.x -eq $Br.to[0] -and $b.z -eq $Br.to[1]) { $ll = Flat $a.x $a.z $b.x $b.z
			$onLeg = ($Br.at - $Br.length / 2 - $Br.ramp -ge -1e-6) -and ($Br.at + $Br.length / 2 + $Br.ramp -le $ll + 1e-6) } }
	if (-not $onLeg) { Fail "V4: $($Br.id) not on leg" }
	if ((LiqD $Br.x $Br.z) -ge 0) { Fail "V4: $($Br.id) not over chocolate" }
	Note ("bridge {0} at ({1:N2},{2:N2}) liquid {3:N2}" -f $Br.id, $Br.x, $Br.z, (LiqD $Br.x $Br.z)) }
function Corners($Br) { $a = $Br.length / 2 + $Br.ramp; $c = $Br.width / 2; if ($Br.gaps.Count -gt 0) { $c += $Br.sideRamp }; $o = @()
	foreach ($s in @(@(-1, -1), @(1, -1), @(1, 1), @(-1, 1))) { $o += , (P ($Br.x + $s[0] * $a * $Br.ux - $s[1] * $c * $Br.uz) ($Br.z + $s[0] * $a * $Br.uz + $s[1] * $c * $Br.ux)) }; return , $o }
function Overlap($p, $q) { foreach ($poly in @($p, $q)) { for ($i = 0; $i -lt 4; $i++) { $a = $poly[$i]; $b = $poly[($i + 1) % 4]; $nx = -($b.z - $a.z); $nz = $b.x - $a.x
			$pv = $p | ForEach-Object { $nx * $_.x + $nz * $_.z }; $qv = $q | ForEach-Object { $nx * $_.x + $nz * $_.z }
			if (($pv | Measure-Object -Maximum).Maximum -lt ($qv | Measure-Object -Minimum).Minimum -or ($qv | Measure-Object -Maximum).Maximum -lt ($pv | Measure-Object -Minimum).Minimum) { return $false } } }; return $true }
for ($i = 0; $i -lt $BRIDGES.Count; $i++) { for ($j = $i + 1; $j -lt $BRIDGES.Count; $j++) { if (Overlap (Corners $BRIDGES[$i]) (Corners $BRIDGES[$j])) { Fail "V4: overlap $($BRIDGES[$i].id) $($BRIDGES[$j].id)" } } }
# V3-5
$minN = 999; $minP = 999
foreach ($n in $NESTS) { $d = LiqD $n.x $n.z; if ($d -lt $minN) { $minN = $d; $minNid = $n.id }; if ($d -lt 6) { Fail "V5: nest $($n.id) $d" } }
foreach ($p in $POSTS) { $d = LiqD $p.x $p.z; if ($d -lt $minP) { $minP = $d; $minPid = $p.id }; if ($d -lt 8) { Fail "V5: post $($p.id) $d" } }
Note ("closest nest to chocolate {0} {1:N2}; post {2} {3:N2}" -f $minNid, $minN, $minPid, $minP)
foreach ($t in $TRAPS) { if ((LiqD $t.x $t.z) -lt 10) { Fail "V5: trap $($t.key)" } }
if ((LiqD $BOSS.x 0) -lt 76) { Fail 'V5: boss' }
if ((LiqD $PORTAL.x 0) -lt 16) { Fail 'V5: portal' }; if ((LiqD $ENTR.x 0) -lt 28) { Fail 'V5: entrance' }
foreach ($k in $KEEP) { if ((LiqD $k.x $k.z) -lt $k.r) { Fail "V5: keep $($k.why)" } }
# V3-6
foreach ($p in $PIECES) { $label = "$($p.kind) $($p.id)"
	foreach ($n in $NESTS) { if ((Flat $p.x $p.z $n.x $n.z) - $p.r -lt 8) { Fail "V6: $label on nest $($n.id)" } }
	foreach ($q in $POSTS) { if ((Flat $p.x $p.z $q.x $q.z) - $p.r -lt 6) { Fail "V6: $label on post $($q.id)" } }
	foreach ($t in $TRAPS) { if ((Flat $p.x $p.z $t.x $t.z) - $p.r -lt 10) { Fail "V6: $label on trap $($t.key)" } }
	if ((RouteDist $p.x $p.z $null) - $p.r - $hp -lt 3) { Fail ("V6: {0} on a route {1:N2}" -f $label, ((RouteDist $p.x $p.z $null) - $p.r - $hp)) }
	if ((Flat $p.x $p.z $BOSS.x 0) - $p.r -lt 76) { Fail "V6: $label in boss" }
	if ((Flat $p.x $p.z $PORTAL.x 0) - $p.r -lt 16) { Fail "V6: $label portal" }
	if ((Flat $p.x $p.z $ENTR.x 0) - $p.r -lt 28) { Fail "V6: $label entrance" }
	foreach ($k in $KEEP) { if ((Flat $p.x $p.z $k.x $k.z) - $p.r - $k.r -lt 2) { Fail "V6: $label on $($k.why)" } }
	if ($p.kind -eq 'mountain') { if ((Depth $p.x $p.z) -lt $p.r - 0.5) { Fail "V6: $label leaves" } } elseif ((Depth $p.x $p.z) - $p.r -lt 2) { Fail "V6: $label by edge" }
	$source = $p.kind -eq 'mountain' -and $p.id -eq 'M1'
	if (-not $source -and $p.kind -ne 'dock') { if ((LiqD $p.x $p.z) - $p.r -lt 2) { Fail ("V6: {0} in chocolate {1:N2}" -f $label, ((LiqD $p.x $p.z) - $p.r)) } }
	if ($p.kind -ne 'dock' -and (NearBridge $p.x $p.z $p.r)) { Fail "V6: $label on bridge" } }
for ($i = 0; $i -lt $PIECES.Count; $i++) { for ($j = $i + 1; $j -lt $PIECES.Count; $j++) { $a = $PIECES[$i]; $b = $PIECES[$j]
		$sameDock = $a.kind -eq 'dock' -and $b.kind -eq 'dock' -and $a.id.Substring(0, 1) -eq $b.id.Substring(0, 1)
		if (-not (($a.kind -eq 'cake' -and $b.kind -eq 'cake') -or $sameDock) -and (Flat $a.x $a.z $b.x $b.z) - $a.r - $b.r -lt 2) { Fail "V6: $($a.id) touches $($b.id)" } } }
# V3-7 doors
foreach ($h in $HOUSES) { $yaw = (FaceYaw $h.x $h.z 0 0) + $h.turn * [math]::PI / 180; $lx = -[math]::Sin($yaw); $lz = -[math]::Cos($yaw)
	$dx = $h.x + $lx * ($h.r + 4); $dz = $h.z + $lz * ($h.r + 4)
	if ((Depth $dx $dz) -lt 5) { Fail "V7: $($h.id) door edge" }; if ((LiqD $dx $dz) -lt 4) { Fail "V7: $($h.id) door chocolate" }
	foreach ($p in $PIECES) { if (-not ($p.kind -eq 'house' -and $p.id -eq $h.id)) { if ((Flat $dx $dz $p.x $p.z) - $p.r -lt 4) { Fail "V7: $($h.id) door faces $($p.id)" } } } }
# V3-8 docks
foreach ($d in $DOCKS) { if ((LiqD $d.sx $d.sz) -le 0) { Fail "V8: stand $($d.id) wet" }
	$t = LiqD $d.tx $d.tz; Note ("dock {0} tip liquid {1:N2}, stand ({2:N2},{3:N2}) tip ({4:N2},{5:N2})" -f $d.id, $t, $d.sx, $d.sz, $d.tx, $d.tz)
	if ($t -gt -6) { Fail "V8: tip $($d.id) $t" }; if (NearBridge $d.tx $d.tz 6) { Fail "V8: tip $($d.id) by bridge" }
	$pp = DockPts $d; if ((LiqD $pp.foot.x $pp.foot.z) -le 0) { Fail "V13: $($d.id) ramp foot wet" } }
$wet = $false; $a = $DOCKS[0]; $b = $DOCKS[1]
for ($s = 1; $s -le 99; $s++) { if ((LiqD ($a.sx + ($b.sx - $a.sx) * $s / 100) ($a.sz + ($b.sz - $a.sz) * $s / 100)) -lt 0) { $wet = $true } }
if (-not $wet) { Fail 'V8: same bank' }
if ((Flat $a.tx $a.tz $b.tx $b.tz) -lt 50) { Fail 'V17: docks close' }
# V3-9
foreach ($f in $LIC.feet) { if (($f.off - $f.r) * $LIC.scale - $hp -lt 4) { Fail 'V9: feet' } }
if ((RouteDist $LIC.x $LIC.z 'main') -ge 0.01) { Fail 'V9: arch off main' }
for ($i = 0; $i -lt $PLAT.Count; $i++) { $pl = $PLAT[$i]; $in = $false
	foreach ($c in $LAKE) { if ((Flat $pl.x $pl.z $c.x $c.z) + $pl.r -le $c.r) { $in = $true } }
	if (-not $in) { Fail "V9: platform $i leaves" }; if (NearBridge $pl.x $pl.z $pl.r) { Fail "V9: platform $i bridge" }
	for ($j = $i + 1; $j -lt $PLAT.Count; $j++) { if ((Flat $pl.x $pl.z $PLAT[$j].x $PLAT[$j].z) - $pl.r - $PLAT[$j].r -lt 2) { Fail 'V9: platforms touch' } } }
# V3-11
function ClearOf($x, $z, $r) { if ((LiqD $x $z) -lt $r + 2) { return 'chocolate' }; foreach ($i in $ISL) { if ((Flat $x $z $i.x $i.z) -le $i.r + $r + 2) { return 'island' } }
	foreach ($p in $PIECES) { if ((Flat $x $z $p.x $p.z) -lt $p.r + $r + 2) { return "on $($p.id)" } }; if (NearBridge $x $z ($r + 2)) { return 'bridge' }; return 'ok' }
Note ("clearOf(-150,60,3) = {0}" -f (ClearOf -150 60 3))
# V3-12 side ramps vs posts
foreach ($Br in $BRIDGES) { foreach ($gx in $Br.gaps) { foreach ($s in @(-1, 1)) {
			$lo = [math]::Min($s * $Br.width / 2, $s * ($Br.width / 2 + $Br.sideRamp)); $hi = [math]::Max($s * $Br.width / 2, $s * ($Br.width / 2 + $Br.sideRamp))
			foreach ($p in $POSTS) { $f = Frame $Br $p.x $p.z; $da = [math]::Max([math]::Abs($f[0] - $gx) - $Br.gapWidth / 2, 0); $dc = [math]::Max([math]::Max($lo - $f[1], 0), $f[1] - $hi)
				if ([math]::Sqrt($da * $da + $dc * $dc) -lt 6) { Fail "V12: $($Br.id) ramp on post $($p.id)" } } } } }
# V3-15 hills
foreach ($h in $HILLS) {
	foreach ($n in $NESTS) { if ((Flat $h.x $h.z $n.x $n.z) - $h.r -lt 8) { Fail "V15: $($h.id) nest" } }
	foreach ($q in $POSTS) { if ((Flat $h.x $h.z $q.x $q.z) - $h.r -lt 6) { Fail "V15: $($h.id) post $($q.id)" } }
	if ((RouteDist $h.x $h.z $null) - $h.r - $hp -lt 3) { Fail "V15: $($h.id) route" }
	if ((Flat $h.x $h.z $BOSS.x 0) - $h.r -lt 76) { Fail "V15: $($h.id) boss" }
	foreach ($k in $KEEP) { if ((Flat $h.x $h.z $k.x $k.z) - $h.r - $k.r -lt 2) { Fail "V15: $($h.id) $($k.why)" } }
	foreach ($p in $PIECES) { if ((Flat $h.x $h.z $p.x $p.z) - $h.r - $p.r -lt 2) { Fail "V15: $($h.id) on $($p.id)" } }
	if ((LiqD $h.x $h.z) - $h.r -lt 2) { Fail "V15: $($h.id) chocolate" } }
# V3-17
$wideLen = 0; for ($i = 0; $i -lt $RIVER.Count; $i++) { $p = $RIVER[$i]
	if ((Flat $p[0] $p[1] 0 0) -le 31 * $S -and $p[2] -ne 10) { Fail "V17: arc point $i width" }
	if ($i -lt $RIVER.Count - 1) { $q = $RIVER[$i + 1]; if ([math]::Min($p[2], $q[2]) -ge 24) { $wideLen += Flat $p[0] $p[1] $q[0] $q[1] } } }
Note ("wide length {0:N1}; river length computed elsewhere" -f $wideLen)
foreach ($id in @('Top', 'Bottom')) { $Br = $BRIDGES | Where-Object { $_.id -eq $id }
	$lo = -[math]::Floor($Br.length / 2) - 9; $hi = [math]::Floor($Br.length / 2) + 9; $minS = 99; $maxS = -99
	for ($s = $lo; $s -le $hi; $s++) { if ((LiqD ($Br.x + $Br.ux * $s) ($Br.z + $Br.uz * $s)) -le 1) { if ($s -lt $minS) { $minS = $s }; if ($s -gt $maxS) { $maxS = $s }
			if ([math]::Abs($s) -gt $Br.length / 2) { Fail "V17: $id chocolate past deck at $s" } } }
	Note "$id chocolate along deck s $minS..$maxS" }
if ($args -contains 'open') {
	$open = 0; $x0 = [math]::Floor(-60 * $S); $x1 = [math]::Floor(79 * $S); $z0 = [math]::Floor(-150 * $S); $z1 = [math]::Floor(-21 * $S)
	for ($x = $x0; $x -le $x1; $x++) { for ($z = $z0; $z -le $z1; $z++) { if ((LiqD ($x + 0.5) ($z + 0.5)) -le -3 -and -not (NearBridge ($x + 0.5) ($z + 0.5) 3)) { $open++ } } }
	Note "open water $open in x $x0..$x1 z $z0..$z1" }
"FAILS: $($fails.Count)"; $fails; "NOTES:"; $notes
