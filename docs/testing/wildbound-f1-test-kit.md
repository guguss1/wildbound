# Wildbound F1 test kit

Everything a person needs to run the fun test, gate F1, and the smaller first baseline, M1.7. You do not need to be technical. Words in `this style` are for whoever reads the logs.

**Status: prepared 2026-11-07. Nothing here has been run.** Agents prepare and analyze. **Only people can pass F1, and an agent never marks it passed.**

**Today's answer: F1 is a no-go, see Part C. M1.7 can run as soon as Part B's short list is true.**

## Quick path

| You want to | Go to | Time |
| --- | --- | --- |
| Run the first baseline with 3 people | Part B | About 30 minutes per person |
| Check if F1 can run | Part C | 10 minutes |
| Run F1 with 10 people | Part A | About 35 minutes per person, about 6 hours in all |
| Set up people safely, especially anyone under 18 | Part D, **first** | Before you invite anyone |

## Choices worth your review

| # | Choice taken | Why | Tradeoff |
| --- | --- | --- | --- |
| 1 | **Testers aged 16 or older first** | Roblox's early-tester rule lets an adult invite friends 16+ (trusted friends differ, see Part D), and the game has no age rating yet | Younger players may be the real audience. Test them later, after a person checks the rules |
| 2 | **M1.7 runs on your own computer in Studio, testers beside you** | No publishing, no invites, no tester account, no personal data | No real phone, so touch stays untested |
| 3 | **One tester at a time, with a helper account in the same server** | That is how server logs can be read before the server closes | Your helper's avatar stands at camp. The tester is told to ignore it |
| 4 | **People's words beat the logs on fairness** | A log shows a warning was sent, never that it was seen (`docs/mechanics/wildbound-fair-strike.md:156`) | One tester can fail the fairness line. That is intended |
| 5 | **Pass lines are counted out of 10** and marked as proposals | D15 is still open. See the note under the table | Ten people show direction, not proof |

---

# Part A: Gate F1

## A1. What you are testing

Will new people, with no help, choose to keep going out, understand what is at stake, and feel tense but treated fairly?

## A2. Pass lines

**All lines are proposals until the user settles D15** (`docs/wildbound-roadmap.md:323-330`, `:455`). Do not change them after seeing results.

| Measure | How you get it | Proposed pass, out of 10 | Source of the number |
| --- | --- | --- | --- |
| Goes back by choice | Sheet, then log | **6 or more** start a third trip without being asked | Roadmap: at least 60% |
| Understands what is at stake | Exit question 3 | **7 or more** correct | Roadmap: at least 70% |
| Real tension | Exit question 4 | **5 or more** describe a specific moment | Roadmap: at least half |
| Fairness | Exit question 5, then log | **0** say they were beaten with no warning. **0** `strike.unacked` | Roadmap: zero |
| Trip length | Log, or stopwatch | Middle trip is **3 to 8 minutes** | Roadmap, from D5 |
| Weighs staying against leaving | Sheet | **5 or more** show at least one clear moment | **New proposal.** Roadmap gives no number |

| Rule | Proposal |
| --- | --- |
| Replace a tester | Only for a non-game reason: phone call, crash, lost internet. Write it down |
| Fewer than 10 valid | Report as "x of y". Do not scale up or claim a pass |
| Same build | Every tester plays one build. If it must change, stop and start counting again |
| If it fails | Go back to M2 to M5, using what testers said. Do not add content (`wildbound-roadmap.md:332`) |

## A3. Recruiting brief

Who: **10 people who have never played this game.** Not people who worked on it. At least 5 play on a real phone. A mix of people who like horror and people who do not. Part D applies.

Message you can send, to people you already know, outside Roblox:

> I am testing an early Roblox game and would like to watch someone play it for the first time. It takes about 35 minutes. It is a mild horror game: dark woods, and a creature that can chase you. There is no blood. You can stop at any time, for any reason. I will not teach you the game, because I want to see what is confusing. It tests the game, not you. Nothing is for sale. I will not record your name, your account or your voice in my notes. Could you do [date and time]? You would need [your phone with Roblox installed / to come to my computer].

For anyone under 18, send it to the parent or guardian. Do not contact them through Roblox chat.

**Do not** offer Robux or game items as thanks. Do not recruit strangers from inside Roblox.

## A4. Devices

| Slot | Device | Why | Check before |
| --- | --- | --- | --- |
| At least 2 testers | Low-end Android phone. A Samsung Galaxy A06 or similar | D12 asks for this. The baseline used it only in an emulator (`docs/testing/wildbound-baseline-m1.md:105`) | Roblox updated, battery over 50%, notifications silenced |
| At least 3 testers | Whatever phone the tester owns | Real thumbs and real habits | Same |
| Up to 5 testers | Computer, keyboard and mouse | Comparison | Roblox installed |
| Host, always | Computer with Developer Console and a helper account with edit permission | Only the owner or editors can see server logs (Part A8) | Signed in before the tester arrives |
| Host, always | Stopwatch, printed sheets, this kit | Works if logs fail | |

Write down: phone model, Wi-Fi or mobile data, sound on or off **as the tester had it**. Do not change their settings. An emulator never counts as a phone.

## A5. Your day

About 35 minutes per tester. Break it up into as many blocks as you like, with the same build.

| Minutes | Step |
| --- | --- |
| 0 to 3 | Welcome, consent check, read the script |
| 3 to 23 | **20 free minutes.** You watch and fill in the sheet |
| 23 to 30 | Exit questions |
| 30 to 33 | Copy the log, label it with the tester code |
| 33 to 35 | Thank them. Reset |

## A6. Host script

**Read this word for word.** Say it in the tester's language if needed, keeping the meaning, and write down the language. The game's text is English only (D13 is open), so note if they struggle to read it.

**Before starting:**

> Thanks for coming. I am testing the game, not you, and you cannot do it wrong. Please play as you would at home. I am not going to explain anything or answer questions about the game, because I need to see what is confusing. If you get stuck, that is useful for me. Please say out loud whatever you are thinking, if you are comfortable doing that. There will be about 20 minutes of play, then a few questions. You can stop whenever you want, for any reason, and that is completely fine. That other character at camp is my recorder, please ignore it. Ready?

**At 20 minutes:**

> That is the time. Thank you. You can put it down.

If they want to finish a thing, let them, up to 2 minutes. Write it down. Time past 20 minutes does not count as a third trip.

**During play, you may only say:**

| They do or say | You say |
| --- | --- |
| "What do I do?" | "What would you try?" |
| "Is this right?" | "I can't say during the game. Tell me what you think." |
| "Did I die?" or "What happened?" | "What do you think happened?" |
| Silence for a long time | Nothing. Wait. After 2 minutes, once: "What are you thinking now?" |
| Wants to stop | "Of course. Thank you." Go to exit questions |
| Game crashes or freezes | Rejoin for them. Write the time. Say nothing about the game |
| Upset or frightened | Stop the test. Ask if they are all right. Their comfort comes first |

**Never:** point, touch their device, name anything in the game, say "go back", "be careful" or "look out", laugh at or sigh over a choice, or show any reaction when something bad happens. **Do not ask them to go out again.** That is the main thing being measured.

## A7. Exit questions

Ask in this order, one at a time, exactly as written. Write their words. Do not correct them, even if they are wrong.

| # | Question | Scoring |
| --- | --- | --- |
| 1 | "In your own words, what is this game?" | Note only |
| 2 | "What did you want to do next when we stopped?" | Note only. Says if a next goal exists |
| 3 | **"What do you lose if you die?"** | **Correct** must include both: things you were carrying and had not brought back to camp can be lost, and creatures already kept at camp are safe. Bonus note if they mention half the materials or the seal. Update this line if the build's rule changes |
| 4 | **"Tell me about a tense moment."** | **Counts** only if they name what happened and where or when. "It was scary" does not count. "None" is fine |
| 5 | **"Was there any time you got hurt, caught or lost things and did not understand why, or did not get a warning?"** Then: "Tell me about it." | **Counts against fairness** if they describe being beaten or hit with no warning they noticed. Keep the time, then check the log |
| 6 | "What made you decide to go out again, or not to?" | Note only |
| 7 | "How did it feel to catch a creature?" | Listen for "I just stood there" (`wildbound-capture.md:389`) |
| 8 | "Did anything get in the way, like buttons, text or your fingers?" | Note only |
| 9 | "Was anything too dark, too scary or hard to see or read?" | Note only |
| 10 | "Would you want to play again tomorrow, if you could? Why?" | Note only |

## A8. Server logs

For the person who reads logs. **F1 needs a small log feature that does not exist yet:** there are no log lines in `src/wildbound` (searched 2026-11-07). Roblox's analytics cannot replace it, since it sends only from a published game, updates daily and is not per-session (`docs/testing/wildbound-f2-plan.md`). Fair-strike and capture designs already define most of the numbers.

**How to read them.** Server output is visible only to the owner or editors, in the Developer Console, Log tab, Server (Roblox docs, read through a summary, 2026-11-07). The docs do not say how long logs last, so assume they vanish when the server closes.

1. Before the tester joins, the helper account joins and stays in a corner of camp.
2. The tester joins the same server. **Prove this in the dry run**, as joining the same server is unverified. Max players 2 should help. A private server is the fallback, also unverified.
3. At the end, while the tester is still in, copy or photograph the log lines.

Helper in the server: slot scaling counts players (`wildbound-capture.md:286`) and the helper sits in the camp safe zone. The F1 build should leave the helper out of the count.

**Line format.** Printed by the server only, after its own checks.

```text
F1|<build>|<server short>|P1|<seconds since start>|<event>|key=value ...
```

`P1` is by join order. **No UserId, name or chat, ever.** The tester code is written only on your sheet.

| F1 measure | Events | Calculation | If logs fail |
| --- | --- | --- | --- |
| Goes back by choice | `trip_open n=` | `n=3` before minute 20. A trip opens on leaving the camp circle (`wildbound-economy-p0.md:135`). Combine with the sheet: no prompt given | Count on the sheet |
| Understands stakes | None | Exit question. Optional: `defeat` shows they did lose something | Same |
| Real tension | `warning`, `capture_end`, `strike` | Check that the moment they named happened | Exit question only |
| Fairness | `warning attack= sentAt=`, `strike attack= outcome=`, and `strike.unacked`, `strike.executed`, `cancel.*`, `attack.issued` | Each strike needs a warning. `strike.unacked` must be 0. Counter identity holds (`wildbound-fair-strike.md:122`) | Exit question. Mark "log missing" in the result |
| Trip length | `trip_close n= seconds= outcome=` | Median of all closed trips, plus extracted and defeated apart (`wildbound-economy-p0.md:68`) | Stopwatch from camp exit to extract or defeat |
| Weighing | `decision type=marked|bagFull|pouchFull|nightStart, next=left|stayed, value=` | Supports what you saw, never replaces it | Sheet |
| Capture exposure | `capture_end outcome= seconds= inTerritory= guardianMode= guardianDistance=` | Compare to `wildbound-capture.md:329` | Note |

Also print once a minute: all counters, so a crash loses little. `session_end` adds the build ID, `damageMode` and player count.

A later agent can total this from the copied text. No results go in git with names or account details.

## A9. Observation sheet

Print one per tester. Mark the clock time as you go.

```text
Tester code: T__   Date: ____   Host: ____   Build: ________
Device: ____________  Phone real? Y/N  Wi-Fi/Data: ____  Sound: on/off  Language: ____
Consent checked (Part D)? Y/N

TIMES
First movement  ____   First left camp ____   First catch ____   First item back ____
Trip 1 left ____ back ____ how: extract/beaten/other
Trip 2 left ____ back ____ how: extract/beaten/other
Trip 3 left ____ back ____ how: extract/beaten/other   Asked to go? (must be NO)
More trips: ____        Stopped at ____  Reason: time / chose to / problem

MOMENTS  (mark time and what they did or said)
Stuck over 30 s:
Read something aloud or squinted at text:
Mis-tap or thumb in the way:
Scared or surprised (jump, gasp, words):
Silueta near them: did they notice? did they react?
Warning shown: did they act in time?
Hit or beaten: did they seem to know why?
"I just stood there" or bored during a hold:
Blamed lag, the controls or the game:

WEIGHING STAY OR LEAVE  (needs behavior, not your guess)
Clear signs: says it aloud / stops and looks toward camp then chooses /
             opens the bag then chooses / turns back after starting home
Time ____  Situation: bag full / marked / heavy / Night began / other
What they chose: stayed / left           Time ____ ...

EXIT ANSWERS   (their words)
1 ...   2 ...   3 ...  correct? Y/N   4 ...  specific? Y/N
5 ...  no-warning report? Y/N   Time: ____   6 ...  7 ...  8 ...  9 ...  10 ...

Log copied? Y/N  File label: ____
Anything that made this session unusual:
```

**Results page, one row each:**

| Code | Phone? | Third trip by choice | Stakes correct | Tense moment | No-warning report | Middle trip length | Weighed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T01 | | | | | | | |
| T02 | | | | | | | |
| T03 | | | | | | | |
| T04 | | | | | | | |
| T05 | | | | | | | |
| T06 | | | | | | | |
| T07 | | | | | | | |
| T08 | | | | | | | |
| T09 | | | | | | | |
| T10 | | | | | | | |
| **Total** | Need 5 | Need 6 | Need 7 | Need 5 | Need 0 | All trips: 3 to 8 min | Need 5 |

If you can, have a second person score questions 3, 4 and 5 from the written answers alone, and settle differences before you count.

---

# Part B: First baseline, M1.7

**A smaller first look: three people, 15 minutes, no coaching. Write down what confuses them** (`wildbound-roadmap.md:252`). It can run before F1, and it is the only item left to close M1 (`docs/testing/wildbound-baseline-m1.md:135`).

**This cannot say whether the game is fun.** The build has no danger or skill yet. Say that in your notes.

## B1. Before you start

| Must be true | Who checks |
| --- | --- |
| Studio and place confirmed, with no one else working in it right now. Others are active overnight, so agree a time | Host, with the user |
| Latest code is in Studio, hashes match (`python -I -B tools/deploy_manifest.py`). Latest measured run was before the phone HUD change | An agent can do this |
| `DamageEnabled` false, streaming on, night rewards off | An agent can read this |
| Part D done for all three | Host |

**Setup: the computer running Studio. Press Play, once for each person.** Nothing is published, and nobody signs in or shares an account. Stop Play afterward and do not save the place. If the user approves private phone access, one tester may use a real phone instead. Studio's phone simulator may be tried by one tester with a mouse: note that it is not a phone.

## B2. The 15 minutes

Read the script from A6, but say "15 minutes", and drop the line about the recorder. Allowed replies and rules are the same.

| Minute | Watch for |
| --- | --- |
| 0 to 1 | Do they move? Do they know where to go? Time to first action |
| 1 to 5 | Finding the creature, the egg, what the prompts mean, and getting back to camp. Does "Extract" make sense? |
| 5 to 10 | Inventory, hatch, equip. Do they find Flashlight and Pulse? Do they notice Silueta, and do they know if it is after them? |
| 10 to 12 | Do they go out again on their own? What do they try? |
| 12 to 15 | Night starts about minute 12 on a fresh server (`wildbound-baseline-m1.md:53`). Can they see? Do they care? |

## B3. Things the build already suggests

Do not point these out. Tick if the tester runs into them. From `wildbound-baseline-m1.md:125-131`.

| Known issue | Seen? | Comment |
| --- | --- | --- |
| The equipped pet looks like a flat white disc and blocks the view | | |
| Old messages stay on screen for minutes | | |
| Near camp, E triggers the wrong prompt | | |
| Silueta's movement looks choppy (a smoothing change landed after the measurement) | | |
| Status text or buttons feel crowded | | |
| Chip about who Silueta is hunting: noticed? understood? | | |

## B4. Three questions after

Ask in this order. Write their words.

1. "In your own words, what is this game?"
2. "What confused you most?"
3. "What did you want to do next?"

Then, only if time allows: "Tell me about a moment when you felt tense, if there was one."

## B5. Notes page, for M1 exit

Save this as `docs/testing/wildbound-m17-results.md`. No names.

```text
M1.7 baseline, date ____, build ____, host ____, setup: Studio on one computer

| Code | Device | First action (s) | First item (min) | First back at camp (min) | Went out again by choice? | Saw Silueta? | Knew if hunted? | Saw Night? |

Confusion, in the order it happened, with tester code and minute:
What each said for questions 1 to 3:
Things not tested: real phones, real network, damage, skill capture, stakes.
Top three problems, ranked by how many people hit them:
```

**Done when** three sheets exist and the notes page is filed.

---

# Part C: Go or no-go for F1

**Every line must be YES on the day. If not, do not invite anyone.** Status below is what agents found on 2026-11-07; recheck it.

## What the game must have

| # | Must be true | Status 2026-11-07 | Evidence |
| --- | --- | --- | --- |
| 1 | Skill capture works, M3 exit test passed | **NO.** Still a 0.25 s press | `src/wildbound/WildboundServer.server.luau:91`, `:173`; no capture module |
| 2 | Silueta can truly beat a player, fairly, M4 exit test passed | **NO.** No `damageMode`, damage off under streaming | `WildboundWorld.server.luau:33`; `wildbound-fair-strike.md:5` |
| 3 | Materials, Ember, upgrades, working protections, M5 | **NO.** None in the source | Searched `src/wildbound` for `carried`, `ember`, `expedition`, none found |
| 4 | Players can tell who is hunted, M2 exit test with five pairs | **PARTIAL.** Chip built and wired; no person has tried it | Commits `e2a8f02`, `9de38a9`, `3b85c87`; `docs/mechanics/wildbound-awareness.md:5` |
| 5 | Phone screen works: no overlap, warning stays on with the inventory open | **PARTIAL.** Baseline failed; a fix landed, more edits in progress, not re-measured. Real touch never tested | `wildbound-baseline-m1.md:109`, `:112`; `3b85c87` |
| 6 | Night shows up inside 20 minutes: 12-minute cycle, random start (D5) | **NO.** Still 20 minutes | `wildbound-baseline-m1.md:50-55` |
| 7 | Minimum sound and warnings, M4.9 | **NO** | No Sound in `src/wildbound` per `wildbound-roadmap.md:84` |
| 8 | F1 log lines from A8 | **NO.** Roadmap schedules analytics after F1 (M9.5), so this is a **new small unit, needed before F1** | No `print` in `src/wildbound`, searched 2026-11-07 |
| 9 | First-time help is enough to start (M8.5 basics) | **NOT REQUIRED but risky.** W9 is pending. Without it, "understands stakes" also measures missing tutorial | `odd/tasks/wildbound-waves.md:66` |
| 10 | M1.7 baseline done, top problems fixed | **NO** | Part B |

Saving is **not** needed: F1 comes before M6, and one session is enough to reach a third trip. Session-only wording must stay accurate.

## What people must decide

| # | Approval needed | Status | Note |
| --- | --- | --- | --- |
| 11 | **User approves making this build reachable on real phones** | **NO** | Phones must join a server on Roblox, so the build must be published with access kept narrow. Publishing needs explicit approval (`AGENTS.md`). Published games start limited to creator and editors, and testers then need access (Roblox docs). **The roadmap does not list this before F1** |
| 12 | User approves damage in this private test, and names the place | **NO** | `odd/tasks/wildbound-waves.md:20`; list ships empty (`wildbound-fair-strike.md:75`) |
| 13 | D12: testers and two low-end phones found | **NO** | `odd/tasks/wildbound-waves.md:40` |
| 14 | D15: pass lines confirmed | **NO** | Same |
| 15 | Part D checked by a person | **NO** | Part D |

## On the day

- [ ] Same build for everyone. Build ID written here: ________
- [ ] All contract suites green on fresh clones, hashes match
- [ ] `damageMode` is `private` only in the named place, list contains only it
- [ ] Dry run with one person who is **not** counted: they joined the helper's server, logs copied, full session timed
- [ ] Phone dry run on the low-end phone: readable, not overheating, no crash
- [ ] Sheets printed, stopwatch ready, script in hand
- [ ] Monetization: none. Nothing is for sale

**Signed by a person, go or no-go:** ______________ **Date:** ________

---

# Part D: Consent and data care

**Testers may be children. This is careful practice, not legal advice. A person must check it before recruiting: local law, Roblox's Terms, and the Creator Analytics Terms, which I could not read.**

## What Roblox's pages say

Read 2026-11-07 through a summary tool. Pages may change.

| Fact | Source |
| --- | --- |
| Early testers: up to 10 similar-aged friends. An adult can invite friends 16+. A 13 to 15 invites 9 to 17. Trusted friends can be any age; under 9 needs parent approval | [Publishing](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places) |
| Under 16 cannot preview a game rated above what a parent allows; under 18 cannot preview Restricted. The reporting tools stay on. Community Standards apply | Same |
| Requesting or sharing personal information on Roblox may be prohibited depending on age. Examples: email, address, phone | [Community Standards](https://about.roblox.com/community-standards) |
| Sending users off Roblox to outside services from inside it is restricted | Same |
| How to grant Playtest access, and whether those people must be friends | **Not on the page I read** |

Unverified: whether the user is over 18; the age rating of this game, as no questionnaire has been done (M10.2); which privacy law applies to the user.

## Rules for this test

Proposals, all of them.

| Topic | Rule |
| --- | --- |
| **Who** | 16 or older first. Under 16 only after a person checks this page, the game has a rating that allows them, and a guardian has agreed |
| **Under 18** | Written yes from a parent or guardian, kept outside this repository. They get the brief first, and know it is a mild horror game. An adult they trust is present or nearby. Host is never alone with a child behind closed doors |
| **Recruiting** | People you already know, through channels outside Roblox. No messages to strangers in-game. Never ask for details in Roblox chat |
| **Their yes** | Ask the tester themselves too. They can stop at any time, without giving a reason, and their notes can be removed if they ask |
| **Collect only** | Tester code, age band if needed for the rules above (16+, or 13 to 15, and so on), device model, sound on or off, what they did and said |
| **Do not collect** | Real name, exact age, birthdate, school, address, email, phone number, account name, UserId, photos, face or voice |
| **Recording** | None by default. If a screen capture is really needed: guardian's yes, no camera, no sound, crop out the account name |
| **Accounts** | Testers use their own usual account, or the guardian decides. Do not ask for a password. Do not create accounts for them |
| **Contact list** | A separate list, by the host, outside the repository. Delete it when testing ends |
| **Logs** | Only `P1`, `P2`, never a UserId. Code-to-person links are never written down |
| **Git** | Only coded summaries reach the repository. Paper sheets stay with the host; destroy them after the results are written up |
| **Comfort** | Warn about dark woods and a chasing creature. Stop on any sign of distress |
| **Thanks** | A thank-you only. No Robux or in-game gifts |

## Next step

Read Part C. Today the shortest route is: run M1.7 (Part B), then finish W5 to W7, add the F1 log, and bring items 11 to 15 to the user.
