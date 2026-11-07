# Four permanent Silueta animation assets

**PASS — exactly four Animation assets created and metadata verified.** Each corrected sequence was individually saved through Studio Explorer → Save / Export → Save to File, then uploaded once. Actual Animator playback, runtime integration, replication and mobile checks remain pending; upload success does not prove them.

## Verified IDs

| Clip | Animation ID | Keys / native duration | Operation ID |
| --- | --- | --- | --- |
| Idle | `90427760879990` | 91 / 3 s | `ca273cef-8415-46a3-ad5f-e01636679b60` |
| Locomotion | `109004575414309` | 61 / 2 s | `5c67a4a0-589f-4760-b034-a9cfe12a2748` |
| Telegraph | `106571946482274` | 43 / 1.39999998 s | `69892ddd-eb58-4c9f-ad5a-3c3a12e139d9` |
| Attack | `139759980248576` | 31 / 1 s | `61acf4cc-554b-430a-a8cf-637fe7eec4f9` |

All four operation polls returned `done=true`. Separate metadata GETs returned HTTP 200 and confirmed type `Animation`, creator User `11937129310`, revision `1`, moderation `Approved`, and state `Active`. Their asset-level `isPublished=true` is not game/place publication.

Full tool responses are preserved in [the upload manifest](../assets/silueta-animation-upload-manifest.json). The full POST response was written and read back **before** polling its operation. There were four POST calls, one per clip, in table order; no retries, updates or duplicate assets. Reuse these IDs rather than uploading again.

## Native export checks

Files are under `assets/exports/`, named `silueta-horror-rig-v3-native-<clip>-v1.rbxmx`. No external XML split, rewrite or normalization was performed. Read-only XML inspection verified one top-level KeyframeSequence per file, the expected name/key count/duration, and exactly 20 poses per key. The pre-existing four-sequence backup remains unchanged.

| Clip | Bytes | SHA-256 |
| --- | ---: | --- |
| idle | 2,107,587 | `75415765FC55B1164A5A717C6E70591FA26CDF9DC0A1408D6070C74B29C67F1B` |
| locomotion | 1,437,233 | `D0E311DDA0F385E451E0674D8DE471A6467A02528FC16F740DF02D3280DC5289` |
| telegraph | 1,002,607 | `32F043B55BB292D56C3F3ADE4AC6F0CEA2EDDDE337D9C378E175CC1FB2B67F8C` |
| attack | 725,297 | `E2F38FBD8E6FC590E87D58178141D7E81DC898C01F3FFCE6C955ED8EBADEC383` |

The original staging-backup hash is still `76D26F1CDFE9181FC9247164B572130065DFEF96E43B36E75CCC9DBB6906DAD2`. Native pose acceptance and the common neutral-basis correction are documented separately in [native animation verification](silueta-native-idle.md).

## Scope and handoff

Reverified Studio instance `81631061-9001-4c69-be21-f79a34aaa1d8`, place `122652861404212`, universe `10774749224`, Edit mode, current user and User creator `11937129310` before export/upload. Asset read/write scope probe returned HTTP 200. Final readback remained Edit, streaming enabled, with all four staged sequences intact. The last selected object was the staged Attack sequence; no modal or temporary probe remained.

This unit changed only selection, created the four local native exports, created the four authorized cloud animation assets, and wrote its manifest/report. No template or runtime source edits, Play session, package unlink/update setting, game publication, monetization, permission/security change, real player data access, commit or native review occurred. Native RDD remains disabled; prior delivery-chain decision remains pending.

**Next:** the next exclusive Studio owner must load these existing IDs through the actual Animator, observe four bounded nonzero lengths and correct bone motion/timing, then perform separately authorized runtime/client checks. Prior 23+41 test results are historical and were not rerun for this upload-only unit.

## Primary API guidance

[Roblox asset usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets) lists Animation RBXM/RBXMX with MIME `model/x-rbxm`, one asset per create, up to 20 MB, and warns that externally edited Roblox model files might not work. [Assets API reference](https://create.roblox.com/docs/cloud/reference/features/assets) documents create, operation polling and metadata retrieval. Real MCP Open Cloud, permission and documentation skills were loaded before calls; authentication was handled by Studio, without API keys.
