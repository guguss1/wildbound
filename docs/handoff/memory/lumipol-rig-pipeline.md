---
name: lumipol-rig-pipeline
description: "Lumipol rig plan in Blender, asset ownership blockers in the Wildbound Roblox place, and the animations the user wants"
metadata:
  node_type: memory
  type: project
  modified: 2026-11-11T23:32:56.491Z
---

The Wildbound place (placeId 122652861404212) is owned by a teammate's account / group; the user works as a collaborator. Meshes owned by another account cannot be read by EditableMesh nor exported (Studio writes an empty glTF). Only assets the user owns can be exported.

Rig workflow (2026-11-11): the user regenerates the Lumipol with their own account, exports glTF to `E:\juego roblox\assets\lumipol_rig\source\`, then an agent (Opus, medium effort) rigs it in Blender 5.0 (`C:\Program Files\Blender Foundation\Blender 5.0\blender.exe`) and exports FBX for Roblox. Animations wanted: sleeping idle with eyes closed, and walk/run.

**Why:** the first rig attempt failed on asset permissions.
**How to apply:** check the exported file size/content before launching the rig agent; an empty glTF means an ownership problem.
