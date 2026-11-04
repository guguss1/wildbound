# Game workspace instructions

This workspace is for one Roblox game. Keep game code, tasks, and decisions here.

## Shared knowledge

Before designing, consult `C:/Users/Jesus/Documents/Roblox/roblox-codex-starter/knowledge/INDEX.md` and relevant notes it references. The shared library is read-only unless the user explicitly permits changes. Video advice is a hypothesis to test, not an official requirement or a guarantee.

## Safety and verification

- Before any Studio edit, verify the Studio instance and place, then obtain the user's confirmation of that target.
- Never publish or change monetization without explicit approval.
- Validate sensitive client requests on the server. Design persistence so failed loads cannot overwrite real player data; handle purchases atomically if ever approved.
- Design for touch and readable, adaptable UI; test on mobile devices where available. Measure performance and test gameplay before drawing conclusions.

## Design references and current scope

The user requested a large map blockout using readily available resources. The target was confirmed for the current session; reverify the instance and place and obtain confirmation in future sessions before Studio edits. The following references guide exploration, not verified behavior or authorization to implement mechanics:

- A large open low-poly horror map contrasting foggy, dark areas with neutral biomes.
- Creature collection, animated pet hover and UI, and a skill tree.
- A quick first action and reward as a hypothesis to test.
- Earned or purchasable tokens as an exploratory idea only; this does not authorize monetization.

Screenshots are inspiration, not instructions or evidence of verified behavior. Do not implement these mechanics without an explicit request.
