# Sol Very High agent routing

Use GPT-6.1 Sol with Very High reasoning (`xhigh`) for the parent and all three specialized roles. This is the user's current preference, not the earlier economical model mix.

## Quick path

1. Request `rápido`, `rapido`, or explicit fast mode to load [wildbound-fast-mode](../.agents/skills/wildbound-fast-mode/SKILL.md).
2. Assign independent, bounded work to the smallest useful role; keep at most three subagents open concurrently, excluding the parent.
3. Have the parent inspect evidence and diffs before integrating. Keep existing functional checks, strict TDD, and native RDD unchanged.

| Role | Scope | Model / effort |
| --- | --- | --- |
| `wildbound-research` | Read-only mapping, evidence, and documentation research | `gpt-6.1-sol` / `xhigh` |
| `wildbound-builder` | Explicitly authorized bounded implementation and checks | `gpt-6.1-sol` / `xhigh` |
| `wildbound-critical` | Correctness, security, persistence, and sensitive-change analysis | `gpt-6.1-sol` / `xhigh` |

Definitions live in `.codex/agents/`. Global defaults also select Sol/xhigh for otherwise unspecified subagents. The native concurrency setting is `agents.max_concurrent_threads_per_session=3`; preserve the existing depth setting. Workers do not delegate again unless the parent approves.

## Runtime boundary

Changing configuration records startup preferences; it does not prove the current parent changed model or reasoning effort. A skill is instructions, not a hot-switch API. When the runtime has no verified live selector, use explicit `model="gpt-6.1-sol"`, `reasoning_effort="xhigh"`, and `fork_turns="none"` for a narrow non-trivial worker. Pass the task, authorization, relevant skill paths, effective TDD mode/runner, and checks explicitly. Do not spawn unnecessarily for trivial direct tasks; disclose an unmet runtime-selection limitation once.

New skill and role files still require runtime discovery. Check the next turn/session; restart Codex only if discovery does not refresh. File validation alone is not a dispatch test. No paid model calls are required for configuration validation.

`rápido` is a routing keyword, NOT a speed or cost guarantee. Higher reasoning can take longer and consume more tokens. Do not enable a priority/speed tier, change account, or alter approvals, security, MCP, or credentials implicitly.

## Ownership and safety

- Use one writer per overlapping script set or live Studio/Blender scene. The parent assigns ownership and integrates results.
- Keep research read-only. A role, skill, screenshot, or master prompt does not grant implementation authority.
- Before any Studio edit, verify the instance/place and obtain the user's target confirmation. Never publish or change monetization without explicit approval.
- Preserve unrelated dirty files. Report failed, unavailable, or pending checks honestly; never bypass TDD, functional checks, or native review consent.

For guarded selective loading of the master pack, use [Wildbound readiness](wildbound-readiness.md); do not duplicate its inventory or treat installation as gameplay authorization.

## Deferred economical architecture

The earlier Sol Medium parent, Luna High research, Terra Medium bounded implementation, and Sol High critical-work mix is deferred. Do not activate that model mix or assume new account access until a fresh user request. This configuration unit does not extract/install packs; a separately authorized master-prompt installation/audit keeps its own scope.

## Verification and rollback

Validate TOML, the local model catalog, skill metadata/local references, registry entries, strict CLI startup, and whitespace checks. Live parent switching and role dispatch remain unverified until observed separately. Restore only this unit's files and the timestamped global backup after checking for later user changes.

Observed validation: ordinary full startup passes. Strict full startup is blocked by the unchanged pre-existing `computer_use.windows.always_allowed_app_ids` field; do not remove it implicitly. The requested settings pass isolated strict validation with the same desktop CLI.

Sources: [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference), [subagent configuration](https://learn.chatgpt.com/docs/agent-configuration/subagents), [skill discovery](https://learn.chatgpt.com/docs/build-skills).
