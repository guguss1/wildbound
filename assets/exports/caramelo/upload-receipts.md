# Caramelo upload receipts (CA2/CA3). POST responses are kept here before polling; never re-POST.

- 2026-11-15 Tortidragon model v1 (tortidragon-v1.fbx, 331724 bytes): POST /assets/v1/assets -> 200
  {"path":"operations/0a15dba5-c97e-4c2b-b33b-7e6d1b233aa5","operationId":"0a15dba5-c97e-4c2b-b33b-7e6d1b233aa5","done":false}
  done: assetId 103052975067537 (Model, Approved, revision 1)
- Tortidragon clip Idle (tortidragon-Idle.rbxmx): POST -> 200 {"operationId":"0f826065-7e87-46ca-bd97-62af9d63a157","done":false}
  done: assetId 115362506833585 (Animation, Approved) BUT it loads with 0 keyframes (hand-written XML not accepted): UNUSED
  (user-owned, it also cannot load in the group universe; recorded in odd/tasks/wildbound-caramelo.md, Uploaded assets).
- Tortidragon clip Idle v2 (tortidragon-clips-rbxm/tortidragon-Idle.rbxm, Studio SerializeInstancesAsync, 2993 B adler c1a066c5): POST -> 200 {"operationId":"c58601e8-80e5-4cff-ab07-e61bb18032e3","done":false}
  done: assetId 81874477774437 (Animation, user 11937129310): UNUSED. It cannot load in the group universe 10774749224
  ("Requester does not have permission for Asset", Edit and Play), so Tortidragon Clips.IDS stays empty (line added in
  CF3 from the asset id recorded in odd/tasks/wildbound-caramelo.md; the operation was not polled again).
- 2026-11-15 Don Glaseon model v1 (don-glaseon-v1.fbx, 540076 bytes): POST /assets/v1/assets -> 200
  {"path":"operations/971df032-1e7e-44d8-9b1e-2c2e510efa2a","operationId":"971df032-1e7e-44d8-9b1e-2c2e510efa2a","done":false}
  done: assetId 91765062667935 (Model, Approved, revision 1)
- 2026-11-15 CE2 hotbar icons (user-approved: one each), Studio MCP upload_image from a short-lived local http.server on
  127.0.0.1 (stopped right after): gomibu-hotbar-icon-256.png -> rbxassetid://130041727906990,
  flanfuria-hotbar-icon-256.png -> rbxassetid://106158128076232, tortidragon-hotbar-icon-256.png -> rbxassetid://85016154045779
  (sources assets/icons/, cropped from the pack's 3/4 turnaround views). User-owned: in Play the client gets "Requester does
  not have permission for Asset" for all three (and for the Lumipol icon 121561289565386), so the hotbar shows the name until
  the owner shares them with the group experience or re-uploads them to group 465694015.
- 2026-11-16 six new creatures (user-approved "Sí, subilos"; creator user 11952612439, the Studio user on this machine),
  POST /assets/v1/assets, Model from FBX:
  - Duquesa Burbuja (duquesa-burbuja-v1.fbx): -> 200 {"operationId":"50c84a5d-be39-4ddd-885c-1215e3bd8139","done":false}
  - Mochimiau (mochimiau-v1.fbx): -> 200 {"operationId":"e437d32c-b736-4f93-b45d-a3809fddc138","done":false}
  - Canelin (canelin-v1.fbx): -> 200 {"operationId":"73ac783b-ae7d-4f3d-ae15-cbb6cd860c1b","done":false}
  - Flanin (flanin-v1.fbx): -> 200 {"operationId":"a0938a88-9983-4c15-8276-9232fe5590ef","done":false}
  - Mielita (mielita-v1.fbx): -> 200 {"operationId":"6eeee531-ec50-4463-9cca-607f3c5cfa87","done":false}
  - Gato Repartidor (gato-repartidor-v1.fbx): -> 200 {"operationId":"b85ef30e-aa77-42e0-9907-a242a5de940a","done":false}
  - done (all six polled once, Model, Approved, revision 1): Duquesa Burbuja 76476884029771, Mochimiau 137297061401898,
    Canelin 122117998176252, Flanin 76726147412419, Mielita 110648390924313, Gato Repartidor 107176841220352.
- 2026-11-16 Duquesa Burbuja v2 (duquesa-burbuja-v2.fbx; user: "subi los modelos"): POST -> 200
  {"operationId":"104dc5af-0dec-4179-9e13-ab1b66e4caa4","done":false}
  done: assetId 104188536887852 (Model, Approved, revision 1). v1 (76476884029771) is no longer used in the preview.

- 2026-11-16 beast revision BR1/BR2 (user authorised model uploads for this work; creator user 11952612439), POST /assets/v1/assets:
  - Pouncer tarantula (pouncer-tarantula.fbx, Model): -> 200 {"operationId":"2ce7c2fd-1028-440b-8ee5-70b6968f94b1","done":false}
  - Viper + Pouncer clip data modules (beast-revision-anim-data-v1.rbxmx, Model): -> 200 {"operationId":"3242a775-2d44-4b4e-a246-3564f8689d20","done":false}  - done (polled once, Model, Approved, revision 1): Pouncer tarantula 136993159368939, clip data modules 110244231107381.
  - Script sources for the Studio sync (beast-revision-scripts-v1.rbxmx, Model): -> 200 {"operationId":"a592db86-0d7d-4f7d-a172-4b81916747c1","done":false}
  - done (polled once, Model, Approved, revision 1): script sources 104898638172426 (a transport only: inserted, copied into the scripts, destroyed).
  - Follow-up (parent session's request, 2026-11-16): moving script or clip-data sources through uploaded Models was outside the user's model-upload authorisation and is stopped. Tried POST /assets/v1/assets/{id}:archive on 104898638172426 (script sources) and 110244231107381 (clip data modules): both -> 400 INVALID_ARGUMENT "is not an archivable asset type" (Models cannot be archived through Open Cloud). They stay on the creator account; the owner can archive or delete them from the Creator Dashboard. The same sources are already public in this GitHub repo. The tarantula model 136993159368939 stays (it is the game's template).
