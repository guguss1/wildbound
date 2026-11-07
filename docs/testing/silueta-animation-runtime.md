# Silueta v3 runtime verification

## Verified in Studio Play

Four approved User `11937129310` assets loaded through a real server Animator: Idle `90427760879990` (3 s), Locomotion `109004575414309` (2 s), Telegraph `106571946482274` (1.4 s), Attack `139759980248576` (1 s). Actual bone transforms and rendered skin changed with the original anchored rig; the sampled root displacement and rotation were zero. No root-only anchoring change was needed.

The operator deployed the reviewed Visual and World sources in the confirmed place `122652861404212`. The disabled previous World and template attribute snapshot were kept in `ServerStorage.WildboundAnimationRuntimeBackup_20261107`. Fresh Play contracts: **64/64** (23 visual, 5 map, 17 inventory state, 19 world rules). The authoritative Body remained the primary part.

Solo Play observed Alert → Hunt → Telegraph → Attack → Retreat, cancellation, reveal across nine meshes and restoration, and static/primitive fallbacks. Explicit adapter destruction was idempotent on the test rig. Streaming stayed enabled and guardian damage stayed off.

## Genuine two-client evidence

Native Server & Clients established distinct Player1 (`-1`) and Player2 (`-2`) identities on one local server. Both clients observed a shared warning deadline `1794011209.545098`, shared reveal expiry `1794011211.511399`, mesh transparency `0.25` then `0.86`, actual Telegraph → Attack → Retreat tracks and changing chest poses. Both remained at health 100; all nine mesh fetches succeeded on each client. The operator inspected a rendered Player2 capture.

These are overlapping observations of replication and shared state, not a general synchronization pass. A cold Telegraph sample showed server time position `0.9167` vs client `0.5042`; one warm Attack sample matched at `0.23749994`. Inventory race, touch, muted warnings and latency cases were not completed.

## Failures and limits

- **FAIL — direct owner Script deletion:** destroying the live World Script left its runtime/art/remotes after the sampled 0.1 seconds. Ordinary Stop returned to Edit before the multiplayer session; that does not prove selective teardown. A callback in its own destroyed Script is not a robust lifecycle guarantee. Actual signal behavior was not verified; no global setting changed.
- The prior operator stopped when Computer Use was interrupted. A separate closeout must verify Edit and any editable backup; this report does not claim that the final session was stopped at that time.
- No game publication, permission changes, datastore access, or damaging strike claim.
