# Wildbound F2 plan

Gate F2, unit M9.5 and the private beta M10.1. Wave W16.

**Status: proposal, written 2026-11-07. Nothing here is built, published or measured.** No numeric retention target is set here, by design: the roadmap sets targets only after a first beta baseline (`docs/wildbound-roadmap.md:401`). **No monetization.** Publishing, and every audience change, needs explicit user approval. Agents never mark F2 passed.

## Quick path

1. Add funnel and custom events through one server-only module (section 2). Test with a fake in Studio.
2. Finish the beta preconditions (section 5). Today, almost none are true.
3. User approves publishing and audience, then run the beta (section 6).
4. Read the reports in order (section 3).
5. Set targets from the baseline with the method in section 4, **before** the second cohort opens.
6. A person decides F2 with the sheet in section 7.

## Choices worth your review

| # | Choice taken | Tradeoff |
| --- | --- | --- |
| 1 | **First capture and first defeat are custom events, not funnel steps.** Differs from the roadmap's list of four funnel events | A linear funnel counts skipped steps as complete, so a player who never dies would show as defeated. See contradiction 1 |
| 2 | **Trip length uses named buckets** as a custom field, plus average value | The custom-event aggregations I read have no median. The buckets reuse the D5 hypothesis |
| 3 | **Beta runs at least 14 days after the first cohort,** with a day-7 reading for the first week's joiners. D30 is reported later, and not required | Slower than a weekend. A shorter beta cannot produce D7 for a cohort of useful size |
| 4 | **No reminders in the beta.** Any contact is logged and its days flagged | Fewer returns, but the roadmap requires "returning without prompting" |
| 5 | **Each target is written down before the second cohort opens** | Prevents moving goalposts. Slower decisions |
| 6 | **Targets that the cohort cannot detect are marked not measurable, not guessed** | With 20 to 50 players, many will be. See section 4 |

## Contradictions found

| # | Conflict | Evidence | Resolved here as |
| --- | --- | --- | --- |
| 1 | M9.5 lists first capture, first extract, first defeat, third expedition as one funnel, but these are not linear: a player may take an egg first, or never die | `wildbound-roadmap.md:384`; funnel page: skipped steps count as complete | Section 2 |
| 2 | Waves ask for a "retention targets proposal"; roadmap says none are invented before a baseline | `odd/tasks/wildbound-waves.md:75`; `wildbound-roadmap.md:401` | Roadmap wins. Method only |
| 3 | M9.5 says "validated" and is tested in Studio, but events send only from published games | Roadmap `:384`; funnel page | Studio proves the module with a fake. Roblox receipt is proven only in the approved published dry run |
| 4 | M10 lists the beta before compliance and publishing approval, but a beta **is** a publish, and audience changes are release actions needing the age question | `wildbound-roadmap.md:393-395`; publishing page | Do the questionnaire and approval part of M10.2 and M10.3 **before** step 3 in section 6 |
| 5 | Beta of 20 to 50 cannot use benchmarks: they need 100+ DAU. Early testers cap at 10 | Analytics pages; publishing page | No outside comparison. Early-tester route alone cannot reach 20 |
| 6 | F2 needs "session length", but the Retention page has none | Roadmap `:401`; retention and engagement pages | Average session time comes from Engagement |
| 7 | F1 expects logs, but analytics is scheduled after F1 | `wildbound-roadmap.md:329`, `:384` | F1 has its own log (`docs/testing/wildbound-f1-test-kit.md`). They can share one event source |

## 1. What Roblox documents

Read 2026-11-07 through a fetch tool that returns a summary, not raw text. Pages are undated. **Recheck at M9.5.**

| Fact | Source |
| --- | --- |
| Funnel and custom events send **only from the server, only in published games**, never from a client or Studio | [Funnels](https://create.roblox.com/docs/production/analytics/funnel-events), [Custom events](https://create.roblox.com/docs/production/analytics/custom-events) |
| `LogOnboardingFunnelStepEvent(player, stepNumber, stepName)`, once per user | Funnels |
| `LogFunnelStepEvent(player, funnelName, funnelSessionId, stepNumber, stepName)`, recurring. Only the 10 latest session IDs per user per funnel count | Funnels |
| Only the first instance of a step counts. **Skipped steps count as complete.** Filters apply to the first step. Displayed by entry cohort. A step expires after 180 days of no events | Funnels |
| `LogCustomEvent(player, eventName, value)`. Aggregations: count, unique users, average, sum, min, max, average per user. Up to 24 hours delay | Custom events |
| 120 + 20 x CCU analytics requests per minute. 3 custom fields per event. 8,000 combined values, then "Other". 10 funnels, 100 steps, 100 custom event names | [Event types](https://create.roblox.com/docs/production/analytics/event-types) |
| Retention is D1, D7, D30 by first-play date, plus cumulative 7D playtime per user. D7 appears after 7 days, D30 after 30. Daily and weekly cohorts | [Retention](https://create.roblox.com/docs/production/analytics/retention) |
| Average session time, and New User First Session Retention | [Engagement](https://create.roblox.com/docs/production/analytics/engagement) |
| **All KPIs need more than 10 DAU and 10 play hours for 7 consecutive days** | [Dashboard](https://create.roblox.com/docs/production/analytics/analytics-dashboard) |
| Similar-game benchmarks need 100+ DAU. Platform breakdowns can double-count | Dashboard |
| Published games start limited to creator, editors and permitted group members. Changing audience and releasing are release actions | [Publishing](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places) |
| Playtest tab: playable by users with Edit or Playtest access and invited early testers, up to 10. Public tab with Friends on: friends and Playtest users. Public games can opt out of Recommended For You | Publishing |
| A "No" on the age-restricted question gives "Content May Vary", for age-checked users 16+. A "Yes" needs the questionnaire. All-ages release needs ID or age verification, 2FA, and Plus or Premium or a refundable fee in Robux, and an evaluation | Publishing |

**Could not read or not stated:**

| Gap | How it gets settled |
| --- | --- |
| Whether Playtest or Friends audiences produce Analytics at all, and whether preview sessions count | Dry run, step 4 in section 6 |
| How to grant Playtest access, and limits | Dashboard, by the user |
| Formal signatures and how custom fields are passed. The summary showed call forms only | M9.5, read the reference |
| Whether small groups are hidden. The dashboard page does not say | Beta |
| Whether Explore offers a median or percentile | Beta |
| [Get started](https://create.roblox.com/docs/production/analytics/get-started) gave no read order or minimums, so the order in section 3 is my proposal | |
| Creator Analytics Terms of Use | Not read. A person checks before M10.1 |

## 2. Events, M9.5

**One server module, `WildboundAnalytics`,** takes a sink, so Studio tests use a fake and the live sink is one thin file. It is called from server state changes only, and **never from a remote**. Events follow a confirmed save where one applies (`docs/mechanics/wildbound-persistence.md`, section 6). No names, IDs, chat or free text in any field.

### Funnel A: first steps, one-time

Each step must come after the one before, in every play path. Durable counters from `stats` make "second" and "third" work across sessions. Players in unsaved mode do not log steps past 2: they log `persistence_unsaved` only, because their counters restart.

| Step | Name | Logged when | Server evidence |
| --- | --- | --- | --- |
| 1 | `Joined` | `Players.PlayerAdded`, as the funnel page advises for a start on join | Engine event |
| 2 | `LeftCamp` | First expedition opens | Crossed camp circle (`wildbound-economy-p0.md:135`) |
| 3 | `FirstGain` | First bag item or pouch unit | Pickup, capture or gather granted |
| 4 | `FirstExtract` | First confirmed extraction | Confirmed commit |
| 5 | `SecondTrip` | `stats.tripsOpened` reaches 2 | Same |
| 6 | `ThirdTrip` | `stats.tripsOpened` reaches 3 | Same. **The F1 measure, also at scale** |

### Funnel B: each trip, recurring

`funnelName = "Expedition"`, session ID is the trip ID. Defeated trips stop early, which is the point.

| Step | Name | When |
| --- | --- | --- |
| 1 | `Opened` | Crossed out of camp |
| 2 | `Gained` | First gain on this trip |
| 3 | `Banked` | Extraction confirmed |

### Custom events

| Event | Value | Fields, at most 3 | Answers |
| --- | --- | --- | --- |
| `first_capture` | None | `riskTier` | M9.5 named event |
| `first_defeat` | None | `cause`: strike or other | M9.5 named event |
| `expedition_ended` | Seconds | `outcome`: extracted, defeated, away. `lengthBand`: under3, 3to8, over8. `phase` at end | Trip length and D5 |
| `capture_ended` | Seconds | `outcome`, `zone` | Exposure and skill. `wildbound-capture.md:389-395` |
| `strike` | None | `outcome`: marked, defeated | Danger |
| `strike_unacked` | None | None | **Fairness. Expected 0 on a healthy network** |
| `gate_cancel` | None | `gate` | Fair-strike falsifier (`wildbound-fair-strike.md:333`) |
| `marked_choice` | Item count at risk | `next`: left, stayed. `load`: light, heavy | Stay or leave |
| `spent` | None | `what`: seal, totem, capsule, pack, skill | Sinks. Not Economy events, to keep this free of revenue reports |
| `load_status` | None | `status`: New, Loaded, LockedElsewhere, Unavailable, Quarantined, TooNew | Data health |
| `save_failed` | None | `kind`, `final` | Data health |
| `persistence_unsaved` | None | `reason` | Players who chose unsaved play |
| `night_entered_fog` | None | None | Night worth the danger? |

**Budget, calculated.** A trip of about 3 minutes emits about 10 events, so about 3 per minute per player, against a limit of 120 + 20 x CCU per minute. Field values come from fixed lists only, to stay under the 8,000-value limit. **Never put a UserId, item UID or trip ID in a custom field.**

### Tests

| ID | Case | Run in |
| --- | --- | --- |
| AN-1 | Same state change twice logs once for one-time steps | Studio, fake sink |
| AN-2 | Every funnel A path keeps strict order: egg first, defeat first, capture first, materials only | Studio, fake |
| AN-3 | A client remote cannot cause any event. Source check plus forged-input run | Studio |
| AN-4 | Banked or extract event only after commit, with fake store failing | Studio, fake |
| AN-5 | Sink throws: game continues, counter rises | Studio, fake |
| AN-6 | Fields only from allowed lists, no number or ID patterns | Studio, fake |
| AN-7 | Sink is no-op in Studio; only one file names `AnalyticsService` | Source check |
| AN-8 | Receipt in Roblox within 24 hours | **Published dry run only, after approval** |

## 3. What to read, and in what order

Proposal for order. Weekly during the beta, and write the raw counts in a sheet: dashboards can change.

| Order | Report, in Creator Analytics | Read | Beta limit |
| --- | --- | --- | --- |
| 1 | Data health: custom `load_status`, `save_failed`, plus reports from players | Any data loss stops the beta | Daily |
| 2 | Custom `strike_unacked`, `gate_cancel`, and fairness reports | Fairness | Daily |
| 3 | **Funnel A** | Largest drop between steps, by entry device | Entry cohort. Filters on the first step only |
| 4 | **Funnel B** | Share of trips reaching Banked | Last 10 per user |
| 5 | Custom Explore, `expedition_ended` | Bands by outcome, average seconds | Up to 24 hours late. Median not assumed |
| 6 | **Engagement**: average session time, New User First Session Retention | Session length. Where in the first session people leave | Needs eligibility |
| 7 | **Retention**: D1, D7, then D30, and 7D playtime per user | Cohort table, with cohort size written next to each rate | D7 after 7 days |
| 8 | Acquisition | Check recruited players explain the traffic | Not a performance read |
| 9 | Insights | Note only | Not a decision input |
| Skip | Benchmarks, monetization | Benchmarks need 100+ DAU. Monetization is out of scope | |

## 4. Setting thresholds from the first baseline

**A method, with no target numbers in it. The numbers come from your first cohort.**

### Step 1: is the baseline usable?

| Check | Pass |
| --- | --- |
| Build frozen for the whole cohort | Yes, or start again |
| All KPIs available: more than 10 DAU and 10 play hours for 7 straight days | Yes. Otherwise fall back to the record counters (`stats` in the persistence record), and say so |
| D7 mature for the cohort reported | Yes |
| No reminders, or contact days flagged | Yes |
| No open data or fairness issue during the window | Yes, or fix and restart |

### Step 2: report rates with their uncertainty

Never a bare percent. For a retention or funnel rate with `k` of `n`, report `k/n` and a 95% Wilson interval:

```text
center = (p + z^2/(2n)) / (1 + z^2/n)     p = k/n, z = 1.96
half   = z * sqrt(p(1-p)/n + z^2/(4n^2)) / (1 + z^2/n)
```

### Step 3: know what your cohort can show

Smallest difference two cohorts of `n` can reliably show, at 95% confidence and 80% power:

```text
detectable = 2.8 * sqrt(2 p (1-p) / n)
```

Calculated at the worst case, `p = 0.5`, for the roadmap's cohort sizes. **These are limits of the test, not targets:**

| Cohort | Detectable difference |
| --- | --- |
| 20 | About 44 points |
| 50 | About 28 points |

So the beta can catch a large problem but cannot prove a small improvement. Plan on that.

### Step 4: write targets, before cohort 2 opens

| Metric | Target is | How it is decided |
| --- | --- | --- |
| Retention D1, D7 | **A floor:** cohort 2 must not fall clearly below baseline, meaning its interval is not wholly under baseline's rate | Automatic from data |
| Any metric a fix targets | Baseline rate + detectable difference, or the user's chosen goal if higher | If this goes above what makes sense, mark **not measurable at this size** and use step 5 instead |
| Session time, 7D playtime | Same floor. Report the average with the cohort size | Averages hide outliers, so read with Funnel B |
| Funnel A largest drop | Must get smaller, by the same detectable rule | One top fix per cohort |
| D30 | Report only | Too slow and small to gate on |

Record in a table: metric, baseline `k/n`, interval, target, why, date written, by whom. **After cohort 2 opens, targets change only with a written reason.**

### Step 5: what numbers cannot do

| Signal | How to read it |
| --- | --- |
| Unprompted return | Count of players who returned with no logged contact. Named in the roadmap's gate |
| Short open question at the next natural contact, if any | Reasons only |
| Recruited players | Invited friends may return out of kindness, so a good beta rate does not predict public rates. Say so in every report |
| Comparison with others | None below 100 DAU. Do not borrow numbers from videos or forums |

## 5. Beta preconditions

Status from `odd/tasks/wildbound-waves.md`, and source searched 2026-11-07.

| # | Must be true | Status |
| --- | --- | --- |
| 1 | F1 passed, by a person | **No.** Part C of `docs/testing/wildbound-f1-test-kit.md` is no-go today |
| 2 | M6 saving passed in the isolated experience, with D8 approved | **No.** Design only |
| 3 | M7 co-op and full touch | **No** |
| 4 | M8 art, sound and UI, and M9 phones, hardening and M9.5 events | **No** |
| 5 | M10.2: age question and questionnaire, chat and policy check, IP check | **No.** See contradiction 4 |
| 6 | User decides intended ages, since a "No" on the age question means 16+ and all-ages has extra conditions and a refundable Robux fee | **Not asked yet** |
| 7 | Rollback and data recovery plan (M10.3), right-to-be-forgotten set up | **No** |
| 8 | Monetization absent: no `MarketplaceService` | Yes today (`wildbound-roadmap.md:91`) |

## 6. Private beta steps, M10.1

**Every row marked "User" stops until the user says yes, in their own words, for that action.**

| Step | Action | Who | Done when |
| --- | --- | --- | --- |
| 1 | Pass section 5 | Agents and user | All yes |
| 2 | Choose route: **A** Playtest tab, plus up to 10 early testers. **B** Friends on. **C** Public, excluded from recommendations | **User** | Written. Recommendation: A for dry run, then B or C. 20 to 50 people cannot fit in early testers alone |
| 3 | **Publish the frozen build,** set audience | **User** | Approval recorded. Build hash recorded |
| 4 | Dry run, 2 or 3 people, 2 days. Events arrive? Analytics appears for this audience? Dashboard read works? | Agents analyze | AN-8 passes. If analytics does not appear on this audience, change route or use `stats` fallback |
| 5 | Invite cohort 1. Same care as F1 Part D. Brief says what data exists and how to stop | User | 20 to 50 joined. **Keep DAU above 10 for 7 straight days,** or KPIs stay locked |
| 6 | Wait. No reminders, log any contact | User | Contact log kept |
| 7 | Daily: data and fairness. Stop on any confirmed loss or duplication, using the recovery plan | Agents analyze, user acts | Stopped or clean |
| 8 | Day 14: read section 3, write baseline, section 4 steps 1 to 3 | Agents analyze | Baseline table |
| 9 | Pick the top issues. Fix one at a time, with tests | Agents, user chooses | Issues listed. Each update to a released game is a release action, so each publish is **User** |
| 10 | Write targets, step 4, then invite cohort 2 | **User** | Dated targets exist first |
| 11 | Repeat reading, and fill in section 7 | Agents analyze | Sheet complete |
| 12 | Decide F2 | **User** | Signed |

Feedback channel: reporting tools stay on in-game. Any survey collects no personal data and is approved like the rest. In-game links out of Roblox are restricted (Community Standards), so plan feedback outside the game with people you invited.

**Do not** enable damage beyond what the user has already approved for this audience (`odd/tasks/wildbound-waves.md:20`).

## 7. F2 decision sheet

Filled in by a person. The roadmap's requirement has no thresholds until step 4 supplies them.

| Requirement, `wildbound-roadmap.md:401` | Evidence | Met? |
| --- | --- | --- |
| Retention measured, from Creator Analytics | D1, D7 for cohort 1 and 2, `k/n` and interval | |
| Session length measured | Engagement average, with cohort size | |
| Targets written before cohort 2 | Dated table | |
| Targets met, or marked not measurable with a reason | Table | |
| Players returned without prompting | Count, contact log | |
| No open fairness issue | `strike_unacked`, reports | |
| No open data issue | `save_failed`, `load_status`, reports | |
| M10 exit items complete | `wildbound-roadmap.md:397` | |

**Decided by:** ____________ **Date:** ______ **Pass or not:** ______

**If it does not pass:** fix and run another cohort. Do not treat already-drafted expansion content as earned: it stays labelled unvalidated (`odd/tasks/wildbound-waves.md:14`).

## Next step

Nothing here can start until F1. The first useful action is to build `WildboundAnalytics` alongside the F1 log, so one event source serves both.
