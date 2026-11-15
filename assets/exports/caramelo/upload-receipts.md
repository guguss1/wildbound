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
