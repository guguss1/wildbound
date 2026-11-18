# Design brief: the longer Caramelo with a river 5 times wider (v9)

## Owner's words (Spanish, verbatim)
- 2026-11-18: "y agranda mas el bioma caramelo a lo largo, el rio necesito qeu sea 5 veces su ancho asi es navegable por la balsa"
- 2026-11-18 (later): "que todos los biomas tengan el mismo tamaño, pero ahora hacelos mas largos aun. Lo del rio de chocolate que vaya de una punta a la otra (o sea como esta, pero que llegue al final de esos costados)"
- Standing rules: no questions to the owner (decide and record), one task at a time, no Robux, never touch SistemaSonriente, never upload assets without separate approval (use only existing kit models and primitive parts).

## Decisions already taken by the parent (do not re-open)
- PD1. All four big4 arms (Forest W, Caramelo E, Mountains N, Pueblo Gatito S) get one size: 600 wide x 1200 long, the long side running outward from the hub. Each arm grows by one more 600 square outward. This task does Caramelo only; the other three come later as their own tasks.
- PD2. Caramelo grows EAST only. Its west edge (the entrance at world x 412, the arch, Road_pradera_1, the hub) and its z range (-263..257) stay. The big4 arm square becomes x 412..1612, z -303..297. Keep today's relation between plot, cloud band and arm: plot x 412..1532 (1120 long, 520 wide), cloud band/Collider x 1532..1548, 64 studs of arm past it. (A designer may argue for a different exact east edge with numbers, but the arm is 412..1612.)
- PD3. The river runs along the biome's LENGTH (x), from one end to the other, keeping its look (a winding chocolate river with banks, a waterfall source at a mountain). It is 5 times as wide as today (today's widths 10..24, so 50..120; a designer may pick a profile in that range). The banana raft must be able to sail it from end to end.
- PD4. Bridges must let the raft pass (raised decks, or another way the raft passes); today bridge footprints are 2D walls for the raft.
- PD5. More than 2 docks along the river (today Raft.new needs >= 2 and accepts homeDock 1 or 2 only; a call teleports the raft).
- PD6. It is a migration of the live map (v9), on the pattern of tools/wildbound-caramelo-v8-migrate.luau: dry run, backup, archive, marks, idempotent.

## Read first (research already done, in this folder)
C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\und\
- r3.md: the plot geometry source of truth (Layout, V3Layout: every constant, nest list, routes, river points, bridges, docks, houses, mountains)
- r2.md: the raft and water gameplay (Raft.area, wading, current, cookie bridges, docks)
- r1.md: how the live map is built and migrated (v8 pattern, builders, budgets)
- r4.md: the surroundings in big4 and what moves when Caramelo grows east
- r5.md: every hard-coded literal and test that would change
- r6.md: the completeness critic (exact river today, what x5 breaks, raft size and turning, raised-bridge clearance, invisible-chocolate risk, V3-14 barrier rule, open risks)
Repo: E:\juego roblox\wb-first-playable (read-only for you). Key files: tools/WildboundCandyLayout.luau, tools/WildboundCandyV3Layout.luau, tools/WildboundCandyV3Builder.luau, tools/WildboundCandyBuilder.luau, tools/WildboundCandyEast.luau, tools/wildbound-caramelo-v8-migrate.luau, src/wildbound/WildboundPraderaSites.luau, WildboundCandyNests.luau, WildboundCandyRaft*.luau, WildboundCandyWade.luau, WildboundCandyCurrent.luau, WildboundCandyCookieBridge*.luau, WildboundCandyLife.luau, WildboundCandyAmbience.luau, docs/design/wildbound-caramelo-v8-plan.md, docs/design/wildbound-caramelo-v3-plan.md.
