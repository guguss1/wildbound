---
name: lumipol-rig-pipeline
description: "Lumipol rig plan in Blender, asset ownership blockers in the Wildbound Roblox place, and the animations the user wants"
metadata:
  node_type: memory
  type: project
  originSessionId: 5d7602fe-979d-4d19-81bd-a664a55b6720
  modified: 2026-11-11T23:32:56.491Z
---

Wildbound place (placeId 122652861404212) is owned by benitodevv (11937129310); the user works as collaborator agusmiau98 (11952612439). Meshes owned by another account (e.g. the blue MeshGen1 by benitoka33) cannot be read by EditableMesh nor exported (Studio writes an empty glTF). Only assets the user owns can be exported.

Rig workflow (2026-11-11): the user regenerates the Lumipol with their own account, exports glTF to `E:\juego roblox\assets\lumipol_rig\source\`, then an agent (user asked: Opus, medium effort) rigs it in Blender 5.0 (`C:\Program Files\Blender Foundation\Blender 5.0\blender.exe`) and exports FBX for Roblox. Animations wanted: sleeping idle with eyes closed, and walk/run.

**Why:** the first rig attempt failed on asset permissions.
**How to apply:** check the exported file size/content before launching the rig agent; an empty glTF means an ownership problem.
