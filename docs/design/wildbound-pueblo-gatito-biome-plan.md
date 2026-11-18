# Pueblo Gatito as its own biome (plan, 2026-11-18)

Owner's words (2026-11-18): "es mejor mantener esto en el bioma reino de caramelo o hacer uno aparte? ... dale, hacelo
bioma aparte". Then: "y agrandá más el bioma caramelo a lo largo, el río necesito que sea 5 veces su ancho así es
navegable por la balsa".

The owner approved this order:
1. Separate the park as its own biome.
2. Move it to its own side of the hub.
3. Fix how the park looks.
4. The micro-phases.

The longer Caramelo with the wider river is queued after step 1.

The task log is `odd/tasks/wildbound-pueblo-gatito.md`. The park itself was built by
`docs/design/wildbound-kitten-park-plan.md` (K-D1..K-D21).

## What a biome is in this code (read-only survey, 2026-11-18)

A biome is the sum of these parts:
- a tagged square in `WildboundBiomes` (copied into `WildboundBiomeLight`);
- a light preset (HUD label, mood, clock, Atmosphere zone);
- the Day/Night rule set (BiomeLight `RULES`; in code, "phase" always means this rule set, never a sub-area);
- creatures whose config row names that tag (`homeBiome`), plus `NO_GLOBAL_BIOMES`;
- nests mapped to species and a reward tier;
- a music bed and a return portal.

Pueblo Gatito already has nearly all of them:
- the tag `CandyEast`;
- the preset `Gatuno` with Day rules, Atmosphere zone `park` and a white-cloud sky;
- the four kittens, whose home biome is `CandyEast`;
- the `gatitoMusic` bed;
- the `parque` portal.

Still tied to Caramelo:
- its nests are Caramelo island entries;
- its portal has no name;
- its kittens have no words;
- the Caramelo music, lights and life leak 32 studs into it;
- the cloud is pink from both sides;
- the Gomibu card says "del bioma Caramelo";
- the Balance record lacks its preset;
- the docs log it as "phase 2 of Caramelo".

## Decisions (PG-D1..PG-D9, step 1 only)

- **PG-D1: its own biome; the internal tag stays.** Pueblo Gatito is a biome of its own in every name, text, sound and
  doc. The internal tag stays `CandyEast` and the module names stay (WildboundCandyKittens, Candy_Este_v1). Players never
  see them. A rename would touch the Studio big4 copies and about 15 pinned tests, with no visible gain and a real risk:
  one mismatch and the director refuses every kitten.
- **PG-D2: its own nest identity.** Park nests become their own island entries:
  - id `GatitoK1`..`GatitoK8` (new `Nests.PARK_ID_PREFIX = "Gatito"`; letters only, because the guard binding parses
    `@(%w+)$`);
  - key `gatito_k<n>`;
  - `biome = "PuebloGatito"`.

  The plot keeps `Candy*` / `caramelo_*` / `"Caramelo"`. Nothing persists the key; only runtime model names and telemetry
  change (`Island_GatitoK1`). The `WildboundBiomes` row key and `East.KEY` become `"pueblo-gatito"`. The live root
  attribute `Key` follows.
- **PG-D3: the return portal gets a name.** `Text.PORTAL.names.parque = "Portal de Pueblo Gatito"`; it was the fallback
  "Portal".
- **PG-D4: the kittens speak.** `Text.BEAST` rows for the four kittens (warn, hit, Notice, Chase, Telegraph), in the
  candy critters' style. This reverses the K-D20 choice of no Text rows. Lines:
  - Gatito Lanudo: warn "¡Gatito Lanudo va a rebotar! Sal del círculo", hit "¡Enredado en lana!".
  - Gatito Guerrero: warn "¡Carga de escudo! Sal de la franja por un lado", hit "¡Escudazo!".
  - Gatita Bouquet: warn "¡Lluvia de pétalos! Sal del círculo", hit "¡Achís! Pétalos".
  - Gatito Actually: warn "¡De hecho! Aléjate de Gatito Actually", hit "¡De hecho, te alcanzó!".
  - Each row also has Notice "<name> te vio", Chase "¡<name> te sigue!" and Telegraph = warn.

  The existing length caps apply.
- **PG-D5: the border is the cloud.** Caramelo ends and Pueblo Gatito begins at the cloud band.
  - The kitten flag (`GatitoAmbience`) now turns on within `Kittens.ENTER_MARGIN = 16` of the park, which is inside the
    band. It turns off past `Kittens.LEAVE_MARGIN = 24` (was 0 and 8).
  - While the kitten flag is on, the Caramelo ambience (lights, sparkles, fireflies, the `CandyAmbience` flag that plays
    the Caramelo music) and the Caramelo life (birds, butterflies, fish) are off.
  - On the way back west the kitten flag turns off inside the plot, where the Caramelo ambience is already on: no gap and
    no overlap.
- **PG-D6: the cloud has two faces.** The cloud-wall puffs are pink and white seen from Caramelo, and white and sky blue
  (`Atmosphere` park air, about 199, 226, 245) seen from Pueblo Gatito. The side is the camera's x against the Veil's x,
  read at the client's 2 Hz step. The Veil part itself is unchanged.
- **PG-D7: the Gomibu card is place-neutral.** It becomes "Osito de goma. Rebota y empuja." because park nests also give
  Gomibu.
- **PG-D8: the Balance record knows Gatuno.** `Balance.LIVE.dayCycle` rules and light get `Gatuno = "Day"`.
  `liveFrom` already derives it from BiomeLight, so suite B23 was failing; B20 gets a "Deliberately changed" note.
- **PG-D9: its own docs.**
  - The park's log moves to `odd/tasks/wildbound-pueblo-gatito.md`; caramelo-v2 keeps a pointer.
  - The overview gets Pueblo Gatito rows (§3.1, §3.4, §13) and the v8 Caramelo square.
  - The kitten-park plan gets a header note.

## Not in step 1 (recorded, in order)

- **Step 2: move the park to its own side of the hub.**
  - The planned side is the south arm, x -3..597, z 337..937, which today holds only the big4 volcanic decor.
  - The park gets one frame in a shared module (an origin and a yaw in multiples of 90). Its nests, posts, portal,
    arrival, music rectangle and squares become park-local, and a migration moves the built park.
  - The cloud wall then is Caramelo's own east edge, or goes.
  - This also frees the east for a longer Caramelo, and shortens the walk home from the park (830-985 studs today).
- **Step 2b: a longer Caramelo and a river 5 times wider** (a v9 migration on the v8 pattern). The survey found:
  - the long axis is x (east);
  - the plot is a single-HALF square;
  - widths at 5x are 60-120;
  - nine nests, dock B, every bridge and point 23 fall into a 5x river on today's course, so it needs a new course;
  - the raft is boxed in the lake because bridges are walls (`Raft.area`), so a navigable river also needs raised
    bridges or a new crossing rule, and more docks.
- **Step 3: the park's look.** Shrink the space or scale items 1.5-2x, a denser village square, a hedge or cloud border,
  low hills.
- **Owner decision (later): kitten eggs.** Park nests still give Caramelo species (K-D8). Kitten species, pets and icons
  need new egg art, pets and toolbar icons, and an icon is an upload (separate approval).

## Deploy notes

- Studio runs the big4 copies of `WildboundBiomes` and `WildboundBiomeLight`. They exist only in Studio and in branch
  `agus/big4-map`, so their changes are patched as hunks.
- WildboundText is a mixed Studio copy: hunks only.
- The live root attribute `Candy_Este_v1.Key` is set directly. Nothing is rebuilt.
