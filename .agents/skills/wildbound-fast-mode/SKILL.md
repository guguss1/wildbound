---
name: wildbound-fast-mode
description: "Trigger: explicit rápido, rapido, or fast mode requests. Route bounded work to GPT-6.1 Sol Very High without weakening checks."
license: Apache-2.0
metadata:
  author: project-maintainers
  version: "1.0"
---

## Activation Contract

Activate for an explicit user request for `rápido`, `rapido`, fast mode, or this skill. Do not activate for incidental gameplay speed/performance wording.

## Hard Rules

- Request `gpt-6.1-sol` with `xhigh` reasoning (Very High). Never silently substitute another model or effort.
- Treat the keyword as routing intent, not a speed/cost guarantee. Do not change priority tiers, credentials, approvals, or security.
- Do not claim a skill/config edit changed the running parent. Disclose an unmet runtime-selection limitation once.
- Preserve authorization, strict TDD, functional checks, native RDD/consent, and Studio target confirmation.
- Keep at most three concurrent subagents. Assign one writer per overlapping script set or live scene; require parent review/integration. Do not nest delegation without parent approval.

## Decision Gates

| Evidence | Action |
| --- | --- |
| Verified live runtime selector | Request Sol/xhigh and verify the result. |
| No live selector; non-trivial bounded work | Spawn explicitly with `model="gpt-6.1-sol"`, `reasoning_effort="xhigh"`, `fork_turns="none"`. |
| Trivial direct work | Avoid unnecessary workers; do not misrepresent the parent's runtime. |

## Execution Steps

1. Read the routing guide and matching project skills; establish authorized scope.
2. Pass independent workers their exact task, skill paths, effective TDD source/runner, ownership, and checks. Keep product decisions with the parent.
3. Validate results before integration; report failed, unavailable, or pending checks. Do not activate the deferred economical architecture.

## Output Contract

Report the observed routing, verified outcome, and any pending runtime discovery/selection. Never invent a hot-switch or a speed gain.

## References

- [Routing and safety guide](../../../docs/agent-routing.md)
