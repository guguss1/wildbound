$ErrorActionPreference = 'Stop'
# ---------- v9 design data (plot-local, world = local + (672, -3)) ----------
$PLOT = @{ minX = -260; maxX = 860; minZ = -260; maxZ = 260 }
function Depth($x, $z) { [math]::Min([math]::Min($x - $PLOT.minX, $PLOT.maxX - $x), [math]::Min($z - $PLOT.minZ, $PLOT.maxZ - $z)) }
function Flat($ax, $az, $bx, $bz) { [math]::Sqrt(($ax - $bx) * ($ax - $bx) + ($az - $bz) * ($az - $bz)) }
function SegD($x, $z, $ax, $az, $bx, $bz) {
  $dx = $bx - $ax; $dz = $bz - $az; $l2 = $dx * $dx + $dz * $dz; $t = 0
  if ($l2 -gt 0) { $t = [math]::Max([double]0, [math]::Min([double]1, (($x - $ax) * $dx + ($z - $az) * $dz) / $l2)) }
  Flat $x $z ($ax + $dx * $t) ($az + $dz * $t)
}
# M1 and its kit offsets (scale s): pool 37.7s, waterfall 31.0s, outlet 49.7s ahead; r 54s; height 90.44s
$M1 = @{ x = 811.4; z = 200; s = 0.9 }
$R2 = @(700, 195)
$ux = $R2[0] - $M1.x; $uz = $R2[1] - $M1.z; $ul = [math]::Sqrt($ux * $ux + $uz * $uz); $ux /= $ul; $uz /= $ul
$out = @(($M1.x + $ux * 49.7 * $M1.s), ($M1.z + $uz * 49.7 * $M1.s))
$POOL = @{ x = $M1.x + $ux * 37.7 * $M1.s; z = $M1.z + $uz * 37.7 * $M1.s; r = 11 * $M1.s }
$WF = @{ x = $M1.x + $ux * 31.0 * $M1.s; z = $M1.z + $uz * 31.0 * $M1.s }
$RIVER = @(
  @($out[0], $out[1], 50),
  @(700, 195, 80), @(600, 190, 90), @(545, 165, 60), @(510, 120, 60),
  @(510, -125, 60), @(485, -170, 70), @(430, -190, 100), @(330, -195, 120), @(255, -172, 80),
  @(215, -125, 60), @(215, 130, 60), @(185, 190, 70), @(90, 205, 70), @(-80, 205, 60), @(-260, 205, 60)
)
$LAKE = @(@{ x = 370; z = -180; r = 70 }, @{ x = 290; z = -192; r = 45 })
$ISL = @(@{ id = 'I1'; x = $args[0]; z = 0; r = 6 })
$ISL = @(@{ id = 'I1'; x = 395; z = -185; r = 6; foot = 9.9 })
function RiverD($x, $z) {
  $best = [double]::MaxValue
  for ($i = 0; $i -lt $RIVER.Count - 1; $i++) { $a = $RIVER[$i]; $b = $RIVER[$i + 1]
    $d = (SegD $x $z $a[0] $a[1] $b[0] $b[1]) - [math]::Max($a[2], $b[2]) / 2; if ($d -lt $best) { $best = $d } }
  $best
}
function IslD($x, $z) { $b = [double]::MaxValue; foreach ($i in $ISL) { $b = [math]::Min($b, (Flat $x $z $i.x $i.z) - $i.r) }; $b }
function Liq($x, $z) {
  $b = RiverD $x $z
  $b = [math]::Min($b, (Flat $x $z $POOL.x $POOL.z) - $POOL.r)
  foreach ($d in $LAKE) { $b = [math]::Min($b, (Flat $x $z $d.x $d.z) - $d.r) }
  $b = [math]::Max($b, -(IslD $x $z))
  [math]::Max($b, -(Depth $x $z))  # v9: no chocolate outside the plot
}
$ROUTES = [ordered]@{
  main = @(@(-260, 0), @(-143, 0), @(0, 0), @(600, 0), @(687, 0))
  left = @(@(-143, 0), @(-130, -104), @(-65, -182), @(65, -182), @(117, -143), @(0, 0))
  right = @(@(-143, 0), @(-117, 91), @(-52, 156), @(52, 156), @(104, 130), @(0, 0))
  deep = @(@(0, 0), @(-31.2, 0))
  lake = @(@(117, -143), @(150, -70), @(600, -70), @(700, -150), @(790, -150))
  alto = @(@(104, 130), @(150, 100), @(600, 100), @(720, 115))
  gate = @(@(600, 100), @(600, 0), @(600, -70))
}
function RouteD($x, $z) { $b = [double]::MaxValue
  foreach ($k in $ROUTES.Keys) { $r = $ROUTES[$k]; for ($i = 0; $i -lt $r.Count - 1; $i++) { $b = [math]::Min($b, (SegD $x $z $r[$i][0] $r[$i][1] $r[$i + 1][0] $r[$i + 1][1])) } }; $b }
$BB = @{ width = 15; deck = 12; ramp = 26 }
$BROWS = @(
  @{ id = 'Medio'; route = 'main'; from = @(0, 0); to = @(600, 0); at = 215; length = 68 },
  @{ id = 'Hondo'; route = 'main'; from = @(0, 0); to = @(600, 0); at = 510; length = 68 },
  @{ id = 'LagoMedio'; route = 'lake'; from = @(150, -70); to = @(600, -70); at = 65; length = 68 },
  @{ id = 'LagoHondo'; route = 'lake'; from = @(150, -70); to = @(600, -70); at = 360; length = 68 },
  @{ id = 'AltoMedio'; route = 'alto'; from = @(150, 100); to = @(600, 100); at = 65; length = 68 },
  @{ id = 'AltoHondo'; route = 'alto'; from = @(150, 100); to = @(600, 100); at = 360; length = 68 }
)
$BR = @()
foreach ($r in $BROWS) { $dx = $r.to[0] - $r.from[0]; $dz = $r.to[1] - $r.from[1]; $l = [math]::Sqrt($dx * $dx + $dz * $dz)
  $b = $r.Clone(); $b.ux = $dx / $l; $b.uz = $dz / $l; $b.x = $r.from[0] + $b.ux * $r.at; $b.z = $r.from[1] + $b.uz * $r.at; $b.leg = $l; $BR += $b }
function Frame($B, $x, $z) { $dx = $x - $B.x; $dz = $z - $B.z; @(($dx * $B.ux + $dz * $B.uz), (-$dx * $B.uz + $dz * $B.ux)) }
function OnBridge($x, $z, $deckOnly) { foreach ($B in $BR) { $f = Frame $B $x $z
  $reach = if ($deckOnly) { 0 } else { $BB.ramp }
  if ([math]::Abs($f[1]) -le $BB.width / 2 -and [math]::Abs($f[0]) -le $B.length / 2 + $reach) { return $B.id } }; $null }
function NearBridge($x, $z, $reach) { foreach ($B in $BR) { $f = Frame $B $x $z
  if ([math]::Abs($f[1]) -le $BB.width / 2 + $reach -and [math]::Abs($f[0]) -le $B.length / 2 + $BB.ramp + $reach) { return $true } }; $false }

$TORTA = @{ x = 745; z = 0; r = 42 }; $BOSS = @{ x = 745; z = 0; plaza = 58; terr = 76; perc = 36; whip = 22; hx = 695; hz = 0 }
$PORTAL = @(-31.2, 0); $ENTR = @(-260, 0); $FORK = @(-143, 0); $JUNC = @(0, 0); $GATE = @(600, 0)
$KEEP = @(@{ x = 360; z = 192; r = 26; why = 'pond' }, @{ x = -230; z = -150; r = 10; why = 'hive' })
$TRAPS = @(@(-126.1, -71.5), @(-93.6, 8), @(-109.4, -30))
$NESTS = [ordered]@{
  C1 = @('Comun', -208, -23.4); C2 = @('Comun', -182, 31.2); C3 = @('Comun', -117, -171.6); C6 = @('Comun', 13, -210.6)
  C8 = @('Comun', 78, -221); C9 = @('Comun', -175.5, -80.6); C10 = @('Comun', -78, -210.6); C12 = @('Comun', -169, -130); C13 = @('Comun', 130, -195)
  R1 = @('Rara', -101.4, -39); R2 = @('Rara', -101.4, 44.2); R3 = @('Rara', -58.5, -120.9); R4 = @('Rara', -26, 123.5); R5 = @('Rara', 114.4, 145.6)
  R6 = @('Rara', 124.8, -158.6); R7 = @('Rara', -150.8, 75.4); R8 = @('Rara', -143, 123.5); R9 = @('Rara', -78, 91); R10 = @('Rara', -13, -58.5); R11 = @('Rara', 46.8, 96.2)
  C4 = @('Comun', 300, -35); C11 = @('Comun', 440, -35); C5 = @('Comun', 300, 50); C7 = @('Comun', 440, 45); C14 = @('Comun', 370, 50)
  R12 = @('Rara', 370, -35); R13 = @('Rara', 285, 145); R14 = @('Rara', 445, 150)
  R15 = @('Rara', 560, 50); R16 = @('Rara', 650, 135); R17 = @('Rara', 575, -35)
  E1 = @('Epica', 650, -150); E2 = @('Epica', 735, -200); E3 = @('Epica', 690, -95); E4 = @('Epica', 560, -115); E5 = @('Epica', 760, 120); E6 = @('Epica', 800, -200)
  L1 = @('Legendaria', 795, -115)
}
$CREAT = @{ Gomibu = @(40, 30, 30); Flanfuria = @(40, 16, 16); Tortidragon = @(40, 35, 35); Mochimiau = @(45, 34, 46); Canelin = @(45, 36, 49)
  Flanin = @(42, 32, 48); Mielita = @(48, 38, 50); GatoRepartidor = @(40, 30, 40) } # wake, leash, reach
# posts: key -> nest, dx, dz, creature, kind(home/extra)
$POSTS = [ordered]@{
  candyNest = @('C1', -6, 6, 'Gomibu', 'home'); candyNestR1 = @('R1', 8, -8, 'Flanfuria', 'home'); candyNestC3 = @('C3', -12, -8, 'Tortidragon', 'home')
  candyNestC2 = @('C2', -6, 13, 'GatoRepartidor', 'home'); candyNestR2 = @('R2', 5, 12, 'Mochimiau', 'home'); candyNestR3 = @('R3', 12, 10, 'Canelin', 'home')
  candyNestR4 = @('C5', 6, 14, 'Flanin', 'home'); candyNestC4 = @('C4', -8, 12, 'Mielita', 'home')
  candyPostC7 = @('C7', 7, -9, 'Gomibu', 'extra'); candyPostR6 = @('R6', 7, 5, 'Flanfuria', 'extra'); candyPostC8 = @('C8', -5, 12, 'Tortidragon', 'extra')
  candyPostC9 = @('C9', 11, 4, 'Mochimiau', 'extra'); candyPostR7 = @('R7', -10, 8, 'Canelin', 'extra'); candyPostR5 = @('R5', 8, 10, 'GatoRepartidor', 'extra')
  candyPostC6 = @('C6', -10, 8, 'Mielita', 'extra'); candyPostC10 = @('C10', 12, 8, 'Flanin', 'extra')
  candyPostE3 = @('E3', -12, 0, 'Gomibu', 'extra'); candyPostR8 = @('R8', 12, 0, 'Flanfuria', 'extra'); candyPostR9 = @('R9', 12, 0, 'Tortidragon', 'extra')
  candyPostR10 = @('R10', 9, 8, 'Mochimiau', 'extra'); candyPostC11 = @('C11', 0, -12, 'Canelin', 'extra'); candyPostC12 = @('C12', 12, 0, 'Flanin', 'extra')
  candyPostC13 = @('C13', -12, 1, 'Mielita', 'extra'); candyPostR11 = @('R11', -9, 8, 'GatoRepartidor', 'extra')
  candyPostE1 = @('E1', -8, 10, 'Gomibu', 'extra'); candyPostE4 = @('E4', 10, 6, 'Flanfuria', 'extra'); candyPostE5 = @('E5', -8, 8, 'Tortidragon', 'extra')
  candyPostR12 = @('R12', 0, -12, 'Mochimiau', 'extra'); candyPostR15 = @('R15', 12, 0, 'Canelin', 'extra'); candyPostR16 = @('R16', -12, -6, 'Flanin', 'extra')
  candyPostR17 = @('R17', 12, -6, 'Mielita', 'extra'); candyPostR14 = @('R14', 0, -12, 'GatoRepartidor', 'extra')
}
$HOUSES = @(
  @{ id = 'H1'; a = 'Sweet'; x = 285; z = 210; r = 28; turn = 0 }, @{ id = 'H2'; a = 'Tower'; x = 445; z = 215; r = 15; turn = 180 },
  @{ id = 'H3'; a = 'Choco'; x = -205.4; z = -195; r = 22.4; turn = 0 }, @{ id = 'H4'; a = 'Sweet'; x = 560; z = -205; r = 20; turn = 0 },
  @{ id = 'H5'; a = 'Tower'; x = -218.4; z = -106.6; r = 21; turn = 180 }, @{ id = 'H6'; a = 'Choco'; x = 828; z = -55; r = 16; turn = 0 },
  @{ id = 'H7'; a = 'Sweet'; x = -20; z = 70; r = 20; turn = 0 }
)
$MOUNT = @(
  @{ id = 'M1'; x = $M1.x; z = $M1.z; r = 54 * $M1.s; src = $true },
  @{ id = 'M2'; x = 838; z = -238; r = 14.2 }, @{ id = 'M3'; x = 370; z = 246; r = 13.1 }, @{ id = 'M4'; x = 135; z = -245; r = 13.1 },
  @{ id = 'M5'; x = -241.8; z = -241.8; r = 13.1 }, @{ id = 'M6'; x = -246; z = -48; r = 13.1 }
)
$DOCKS = @(
  @{ id = 'A'; sx = -150; sz = 162; tx = -150; tz = 186 }, @{ id = 'B'; sx = 168; sz = 40; tx = 195; tz = 40 },
  @{ id = 'C'; sx = 370; sz = -98; tx = 370; tz = -124 }, @{ id = 'D'; sx = 690; sz = 140; tx = 690; tz = 166 }
)
$LIC = @{ x = -161.2; z = 0; s = 0.8; feet = @(@(20.6, 5.7), @(34.8, 4.5)) }
$CAKE = @{ x = -195; z = 145.6; r = 18; reach = 38.5; fx = -195; fz = 0 }
$PLAT = @(@{ a = 'CookieM'; x = 300; z = -205; r = 6.7 }, @{ a = 'CookieL'; x = 345; z = -165; r = 11.7 }, @{ a = 'CookieS'; x = 400; z = -150; r = 3.9 }, @{ a = 'CookieS'; x = 330; z = -215; r = 3.9 })
$HILLS = @(@{ id = 'Hill_1'; z = -200; r = 17.75 }, @{ id = 'Hill_2'; z = -130; r = 16 }, @{ id = 'Hill_3'; z = -10; r = 17.75 }, @{ id = 'Hill_4'; z = 50; r = 17.75 }, @{ id = 'Hill_5'; z = 110; r = 9.94 }, @{ id = 'Hill_6'; z = 150; r = 9.94 })
$HILLX = $PLOT.maxX - 2



