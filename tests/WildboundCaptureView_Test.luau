-- Invoke with require(freshTestClone)(require(freshViewClone), require(freshLayoutClone),
-- require(freshSessionClone), freshViewClone.Source). Pure view-model for the touch capture screen: what each
-- state says, which shape marks it, how the world ring is drawn from the server clock, where the panel and the
-- Stop button sit. Nothing here touches an interface object. CAP numbers refer to docs/mechanics/wildbound-capture.md.
-- Delivery A: the words come from WildboundText (passed fifth), and the seal step has its own state (H1, H3).
return function(View, Layout, CaptureSession, source, Text)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected)
			.. ", got " .. tostring(actual))
	end
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local NAN, INF = 0 / 0, math.huge
	local K = View.CONSTANTS
	local S = CaptureSession.CONSTANTS
	local V, N = Text.CAPTURE_VIEW, Text.CAPTURE_NOTICES

	local function active(extra)
		local snap = { token = "cap:1", phase = "Active", calm = 1.5, inside = true, moving = false,
			outsideFor = 0, deadline = 12 }
		for key, value in pairs(extra or {}) do snap[key] = value end
		return snap
	end
	local function ended(phase, reason, extra)
		local snap = { token = "cap:1", phase = phase, reason = reason, notice = N[reason] or "",
			calm = 2, inside = true, moving = false, outsideFor = 0, deadline = 12 }
		for key, value in pairs(extra or {}) do snap[key] = value end
		return snap
	end
	local function info(extra)
		local value = { age = 0.2, sinceEnd = 0, ringDistance = 0, reduced = false, compact = false }
		for key, item in pairs(extra or {}) do value[key] = item end
		return value
	end
	local function luminance(color)
		local function channel(value)
			local c = value / 255
			return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
	end
	local function contrast(a, b)
		local la, lb = luminance(a), luminance(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end
	local function overlap(a, b) return Layout.overlapArea(a, b) end

	-- An open seal: the marker starts at server time 100 and crosses the bar in 1.6 s; the band is 0.4 to 0.6.
	local SEAL = { startedAt = 100, sweep = 1.6, lo = 0.4, hi = 0.6 }

	-- Status --------------------------------------------------------------------------------------

	case("nothing to show without a snapshot, or with a junk one", function()
		for _, bad in ipairs({ "x", 5, true, {}, { phase = "Weird", token = "cap:1" }, { phase = "Active" } }) do
			local view = View.status(bad, info())
			equal(view.visible, false, tostring(bad))
			equal(view.state, "Idle")
			equal(view.ringStyle, "hidden")
		end
		equal(View.status(nil, info()).visible, false)
		equal(View.status(active(), nil).visible, true)
	end)

	case("inside the ring and still: stay still, bar shows the meter", function()
		local view = View.status(active({ calm = 2.25 }), info())
		equal(view.visible, true)
		equal(view.state, "Calm")
		equal(view.headline, V.calm)
		near(view.fraction, 0.5, 1e-9)
		equal(view.ringStyle, "solid")
		equal(view.arrow, false)
	end)

	case("H2: the meter fills against the session's own requirement when it has one", function()
		near(View.status(active({ calm = 2, required = 4 }), info()).fraction, 0.5, 1e-9)
		near(View.status(active({ calm = 2.25 }), info()).fraction, 0.5, 1e-9)
		for _, junk in ipairs({ NAN, 0, -1, "4" }) do
			near(View.status(active({ calm = 2.25, required = junk }), info()).fraction, 0.5, 1e-9, tostring(junk))
		end
	end)

	case("the meter fraction is clamped and a bad meter reads empty", function()
		near(View.status(active({ calm = 0 }), info()).fraction, 0)
		near(View.status(active({ calm = 99 }), info()).fraction, 1)
		near(View.status(active({ calm = -3 }), info()).fraction, 0)
		near(View.status(active({ calm = NAN }), info()).fraction, 0)
		near(View.status(active({ calm = INF }), info()).fraction, 1)
		near(View.status(active({ calm = "2" }), info()).fraction, 0)
	end)

	case("moving too fast inside the ring says slow down and keeps the ring solid", function()
		local view = View.status(active({ moving = true }), info())
		equal(view.state, "Slow")
		equal(view.headline, V.slow)
		equal(view.ringStyle, "solid")
		equal(view.arrow, false)
	end)

	case("outside the ring: words, a countdown, a dashed ring and an arrow back", function()
		local view = View.status(active({ inside = false, outsideFor = 0.7 }), info())
		equal(view.state, "Outside")
		assert(view.headline:find(V.outside, 1, true), view.headline)
		assert(view.headline:find("1.8s"), "countdown missing: " .. view.headline)
		equal(view.ringStyle, "dashed")
		equal(view.arrow, true)
		local compact = View.status(active({ inside = false, outsideFor = 0.7 }), info({ compact = true }))
		assert(compact.headline:find("1.8s"), compact.headline)
		assert(#compact.headline <= 16, "compact line too long: " .. compact.headline)
	end)

	case("the countdown never goes below zero or shows junk", function()
		assert(View.status(active({ inside = false, outsideFor = 9 }), info()).headline:find("0.0s"))
		assert(View.status(active({ inside = false, outsideFor = NAN }), info()).headline:find("2.5s"))
		assert(View.status(active({ inside = false, outsideFor = -4 }), info()).headline:find("2.5s"))
	end)

	case("the step cue starts one stud inside the drawn edge, with a direction arrow", function()
		local edge = S.RING_RADIUS_VISIBLE - K.STEP_MARGIN
		local early = View.status(active(), info({ ringDistance = edge - 0.01 }))
		equal(early.state, "Calm")
		equal(early.arrow, false)
		local view = View.status(active(), info({ ringDistance = edge }))
		equal(view.state, "Step")
		equal(view.headline, V.step)
		equal(view.arrow, true)
		equal(view.ringStyle, "solid")
		equal(View.status(active(), info({ ringDistance = 99 })).state, "Step")
		equal(View.status(active(), info({ ringDistance = NAN })).state, "Calm")
		equal(View.status(active(), info({ ringDistance = nil })).state, "Calm")
	end)

	case("slowing down outranks the step cue, and being outside outranks both", function()
		equal(View.status(active({ moving = true }), info({ ringDistance = 4.4 })).state, "Slow")
		equal(View.status(active({ inside = false, moving = true }), info({ ringDistance = 4.4 })).state, "Outside")
	end)

	case("no sub-frame timing: the step cue gives at least half a second of warning", function()
		assert(K.STEP_MARGIN / S.RING_SPEED >= 0.5, "the cue would give " .. K.STEP_MARGIN / S.RING_SPEED .. " s")
		near(S.RING_RADIUS_SERVER - S.RING_RADIUS_VISIBLE, 0.5, 1e-9)
		assert(S.OUTSIDE_LIMIT >= 2, "the way back must stay wide")
	end)

	case("a server that went quiet reads as waiting, and claims nothing else", function()
		local view = View.status(active({ calm = 4, inside = false }), info({ age = K.STALE_AFTER + 0.01 }))
		equal(view.state, "Waiting")
		equal(view.headline, V.waiting)
		equal(view.arrow, false)
		equal(View.status(active(), info({ age = K.STALE_AFTER })).state, "Calm")
		equal(View.status(active(), info({ age = NAN })).state, "Waiting")
		equal(View.status(active(), {}).state, "Waiting")
		equal(View.status(active(), info({ age = -1 })).state, "Waiting")
	end)

	case("a finished capture shows Caught with a full meter and no ring", function()
		local view = View.status(ended("Completed", "Completed", { calm = 4.5 }), info({ age = 99 }))
		equal(view.visible, true)
		equal(view.state, "Caught")
		equal(view.headline, V.caught)
		near(view.fraction, 1)
		equal(view.ringStyle, "hidden")
		assert(view.detail:find("campamento", 1, true), view.detail)
		equal(View.status(ended("Completed", "Completed"), info({ compact = true })).headline, V.caught)
	end)

	case("the Caught line does not repeat its headline, and no line is too long for two lines", function()
		local caught = View.status(ended("Completed", "Completed"), info())
		assert(caught.detail:sub(1, #V.caught) ~= V.caught, "repeats the headline: " .. caught.detail)
		assert(caught.detail:find("campamento", 1, true), caught.detail)
		for _, snap in ipairs({ active(), active({ moving = true }), active({ inside = false }), ended("Failed", "LeftRing"),
			ended("Failed", "Struck"), ended("Failed", "TimedOut"), ended("Failed", "TooFar"), ended("Completed", "Completed") }) do
			local view = View.status(snap, info({ age = 0.2 }))
			assert(#view.detail <= 64, "detail too long (" .. #view.detail .. "): " .. view.detail)
		end
	end)

	case("every way a capture can end has a headline, a short form and the server's own words", function()
		local reasons = { "LeftRing", "TimedOut", "TooFar", "Struck", "Defeated", "Cancelled", "Lost", "LostTrack", "Watchdog",
			"SealMissed" }
		local seen = {}
		for _, reason in ipairs(reasons) do
			local phase = reason == "Cancelled" and "Cancelled" or "Failed"
			local full = View.status(ended(phase, reason), info())
			local short = View.status(ended(phase, reason), info({ compact = true }))
			assert(full.visible and short.visible, reason .. " must show")
			assert(full.headline ~= "" and short.headline ~= "", reason .. " has no text")
			assert(#short.headline <= 16, reason .. " short form too long: " .. short.headline)
			equal(full.detail, N[reason], reason)
			equal(full.headline, Text.CAPTURE_HEADLINES[reason][1], reason)
			assert(not seen[full.headline], "two reasons share the headline " .. full.headline)
			seen[full.headline] = true
			equal(full.ringStyle, "hidden")
			equal(View.reasonText(reason, false), full.headline)
			equal(View.reasonText(reason, true), short.headline)
		end
		equal(View.status(ended("Failed", "Struck"), info()).state, "Failed")
		equal(View.status(ended("Cancelled", "Cancelled"), info()).state, "Stopped")
	end)

	case("a leaving player's ending, and a blank one, show nothing", function()
		equal(View.status(ended("Cancelled", "Disconnected"), info()).visible, false)
		equal(View.reasonText("Disconnected", false), nil)
		equal(View.reasonText("Nope", false), nil)
		equal(View.reasonText(nil, false), nil)
	end)

	case("an unknown ending reason still says something plain", function()
		local view = View.status(ended("Failed", "Mystery", { notice = "" }), info())
		equal(view.visible, true)
		equal(view.headline, V.ended)
		equal(View.status(ended("Failed", nil, { notice = "Odd one." }), info()).detail, "Odd one.")
	end)

	case("the result stays for three seconds, then goes", function()
		local snap = ended("Failed", "LeftRing")
		equal(View.status(snap, info({ sinceEnd = 0 })).visible, true)
		equal(View.status(snap, info({ sinceEnd = K.RESULT_SECONDS - 0.01 })).visible, true)
		equal(View.status(snap, info({ sinceEnd = K.RESULT_SECONDS })).visible, false)
		equal(View.status(snap, info({ sinceEnd = NAN })).visible, false)
		equal(View.status(snap, info({ sinceEnd = -1 })).visible, false)
		equal(View.status(snap, {}).visible, false)
		equal(K.RESULT_SECONDS, 3)
	end)

	case("every state has its own words and its own shape, so hue is never the only cue", function()
		local states = {
			View.status(active(), info()), View.status(active({ moving = true }), info()),
			View.status(active(), info({ ringDistance = 4.4 })), View.status(active({ inside = false }), info()),
			View.status(active(), info({ age = 5 })), View.status(ended("Completed", "Completed"), info()),
			View.status(ended("Failed", "LeftRing"), info()), View.status(ended("Cancelled", "Cancelled"), info()),
			View.status(active({ stage = "Seal", seal = SEAL }), info({ serverNow = 101 })),
		}
		local glyphs, words, tones = {}, {}, {}
		for _, view in ipairs(states) do
			assert(type(view.glyph) == "string" and view.glyph ~= "", view.state .. " has no glyph")
			assert(not glyphs[view.glyph], "glyph shared: " .. view.glyph)
			assert(not words[view.headline], "words shared: " .. view.headline)
			glyphs[view.glyph], words[view.headline] = true, true
			tones[view.tone] = true
			assert(View.TONES[view.tone], "unknown tone " .. tostring(view.tone))
		end
		equal(#states, 9)
	end)

	case("every tone keeps readable text and a visible meter", function()
		local count = 0
		for name, tone in pairs(View.TONES) do
			count += 1
			assert(contrast(tone.text, tone.bg) >= 4.5, name .. " text contrast " .. contrast(tone.text, tone.bg))
			assert(contrast(tone.fill, tone.track) >= 3, name .. " meter contrast " .. contrast(tone.fill, tone.track))
			assert(contrast(tone.fill, tone.bg) >= 3, name .. " meter against panel " .. contrast(tone.fill, tone.bg))
		end
		assert(count >= 6, "too few tones")
		assert(table.isfrozen(View.TONES), "tones must be frozen")
	end)

	case("reduced effects stop the ring pulsing and change no words", function()
		local calm = View.status(active(), info({ reduced = false }))
		local reduced = View.status(active(), info({ reduced = true }))
		equal(calm.pulse, true)
		equal(reduced.pulse, false)
		equal(calm.headline, reduced.headline)
		equal(View.status(active({ inside = false }), info()).pulse, false)
		equal(View.status(ended("Completed", "Completed"), info()).pulse, false)
	end)

	case("the stop button needs a live token", function()
		equal(View.stopToken(active()), "cap:1")
		equal(View.stopToken(active({ token = "" })), nil)
		equal(View.stopToken(active({ token = string.rep("x", 129) })), nil)
		equal(View.stopToken(active({ token = 5 })), nil)
		equal(View.stopToken(ended("Failed", "LeftRing")), nil)
		equal(View.stopToken(ended("Completed", "Completed")), nil)
		equal(View.stopToken(nil), nil)
		equal(View.stopToken("cap:1"), nil)
	end)

	-- The seal step (H1) ---------------------------------------------------------------------------

	case("H1: an open seal shows its own words, a marker drawn from the server clock and the band, and no ring", function()
		local view = View.status(active({ stage = "Seal", seal = SEAL }), info({ serverNow = 100.8 }))
		equal(view.visible, true)
		equal(view.state, "Seal")
		equal(view.headline, V.seal)
		equal(view.detail, V.sealDetail)
		near(view.fraction, 0.5, 1e-9)
		equal(view.ringStyle, "hidden")
		equal(view.arrow, false)
		near(view.band.lo, 0.4); near(view.band.hi, 0.6)
		equal(View.status(active({ stage = "Seal", seal = SEAL }), info({ serverNow = 100.8, compact = true })).headline, V.sealShort)
	end)

	case("H1: the marker is clamped to the bar and waits at 0 before the sweep starts", function()
		near(View.sealMarker(SEAL, 99), 0); near(View.sealMarker(SEAL, 100), 0)
		near(View.sealMarker(SEAL, 100.4), 0.25, 1e-9); near(View.sealMarker(SEAL, 200), 1)
		equal(View.sealMarker(SEAL, NAN), nil); equal(View.sealMarker(nil, 100), nil)
		equal(View.sealMarker({ startedAt = 0, sweep = 0, lo = 0.4, hi = 0.6 }, 1), nil, "a zero sweep")
	end)

	case("H1: a seal outranks the ring cues, but a quiet server still reads as waiting", function()
		equal(View.status(active({ stage = "Seal", seal = SEAL, inside = false, moving = true }), info({ serverNow = 100.5 })).state, "Seal")
		equal(View.status(active({ stage = "Seal", seal = SEAL }), info({ serverNow = 100.5, age = 9 })).state, "Waiting")
		equal(View.status(active({ stage = "Seal" }), info({ serverNow = 100.5 })).state, "Calm", "a seal stage without a band")
		equal(View.status(active({ stage = "Seal", seal = SEAL }), info({ serverNow = NAN })).fraction, 0)
	end)

	case("H1: the seal button needs a live token in an open seal", function()
		equal(View.sealToken(active({ stage = "Seal", seal = SEAL })), "cap:1")
		equal(View.sealToken(active()), nil)
		equal(View.sealToken(active({ stage = "Seal" })), nil)
		equal(View.sealToken(ended("Failed", "SealMissed", { stage = "Seal", seal = SEAL })), nil)
		equal(View.sealToken(nil), nil)
		equal(View.stopToken(active({ stage = "Seal", seal = SEAL })), "cap:1", "Stop still works during the seal")
	end)

	case("H1: a seal push is held with its band; a junk band is dropped", function()
		local held = View.merge(nil, active({ stage = "Seal", seal = SEAL }))
		equal(held.seal.lo, 0.4)
		assert(held.seal ~= SEAL, "copied")
		local bad = View.merge(nil, active({ stage = "Seal", seal = { startedAt = NAN, sweep = 1.6, lo = 0.4, hi = 0.6 } }))
		equal(bad.seal, nil)
		local flipped = View.merge(nil, active({ stage = "Seal", seal = { startedAt = 1, sweep = 1.6, lo = 0.7, hi = 0.6 } }))
		equal(flipped.seal, nil)
	end)

	case("H1: a missed seal has its own headline and the server's words", function()
		local view = View.status(ended("Failed", "SealMissed"), info())
		equal(view.state, "Failed")
		equal(view.headline, Text.CAPTURE_HEADLINES.SealMissed[1])
		equal(view.detail, N.SealMissed)
	end)

	case("H3: the view's words all come from WildboundText", function()
		equal(View.reasonText("LeftRing", false), Text.CAPTURE_HEADLINES.LeftRing[1])
		equal(View.reasonText("LeftRing", true), Text.CAPTURE_HEADLINES.LeftRing[2])
		assert(source:find("WildboundText", 1, true), "reads the text module")
		for _, english in ipairs({ "Stay still", "Slow down", "Step this way", "Caught!", "Back in", "Capture ended" }) do
			assert(not source:find(english, 1, true), "English left in the view: " .. english)
		end
	end)


	-- Holding the snapshot ------------------------------------------------------------------------

	case("the ring arrives once and is kept for the whole session", function()
		local ring = { pivotX = 1, pivotZ = 2, y = 3, orbit = 6, a0 = 0, w = 0.25, startedAt = 100, radius = 4.5 }
		local held = View.merge(nil, active({ ring = ring }))
		equal(held.ring.pivotX, 1)
		local next = View.merge(held, active({ calm = 2 }))
		equal(next.calm, 2)
		equal(next.ring.orbit, 6)
		local finished = View.merge(next, ended("Completed", "Completed"))
		equal(finished.phase, "Completed")
		equal(finished.ring.orbit, 6)
		local fresh = View.merge(finished, active({ token = "cap:2", ring = { pivotX = 9, pivotZ = 9, y = 0, orbit = 7, a0 = 0, w = 1, startedAt = 5, radius = 4.5 } }))
		equal(fresh.ring.pivotX, 9)
		local bare = View.merge(finished, active({ token = "cap:3" }))
		equal(bare.ring, nil)
		assert(held.ring ~= ring, "the ring must be copied")
	end)

	case("junk pushes are ignored and never replace what is held", function()
		local held = View.merge(nil, active())
		for _, bad in ipairs({ "x", 5, true, {}, { phase = "Weird", token = "cap:1" }, { phase = "Active", token = 5 } }) do
			equal(View.merge(held, bad), held, tostring(bad))
		end
		equal(View.merge(nil, "x"), nil)
		local badRing = View.merge(nil, active({ ring = { pivotX = NAN, pivotZ = 0, y = 0, orbit = 6, a0 = 0, w = 1, startedAt = 0, radius = 4.5 } }))
		equal(badRing.ring, nil)
	end)

	-- Direction -----------------------------------------------------------------------------------

	case("the arrow points relative to where the camera looks", function()
		local function angle(cx, cz, lx, lz) return (View.arrow(0, 0, cx, cz, lx, lz)) end
		near(angle(0, -5, 0, -1), 0, 1e-6, "ahead")
		near(angle(5, 0, 0, -1), 90, 1e-6, "right")
		near(angle(0, 5, 0, -1), 180, 1e-6, "behind")
		near(angle(-5, 0, 0, -1), 270, 1e-6, "left")
		near(angle(5, 0, 1, 0), 0, 1e-6, "looking east")
		near(angle(0, 5, 1, 0), 90, 1e-6, "looking east, ring south")
		near(angle(3, -3, 0, -1), 45, 1e-6, "ahead right")
		local W = Text.ARROWS
		local _, word = View.arrow(0, 0, 0, -5, 0, -1)
		equal(word, W[1])
		equal(select(2, View.arrow(0, 0, 5, -1, 0, -1)), W[3])
		equal(select(2, View.arrow(0, 0, 4, -4, 0, -1)), W[2])
		equal(select(2, View.arrow(0, 0, 0, 5, 0, -1)), W[5])
		equal(select(2, View.arrow(0, 0, -5, 4, 0, -1)), W[6])
		equal(select(2, View.arrow(0, 0, -5, 0, 0, -1)), W[7])
		equal(select(2, View.arrow(0, 0, -4, -4, 0, -1)), W[8])
		equal(select(2, View.arrow(0, 0, 4, 4, 0, -1)), W[4])
		equal(View.moveLine(W[3]), V.move:format(W[3]))
	end)

	case("the arrow has no answer for a degenerate input", function()
		equal(View.arrow(0, 0, 0, 0, 0, -1), nil)
		equal(View.arrow(0, 0, 3, 3, 0, 0), nil)
		equal(View.arrow(NAN, 0, 3, 3, 0, -1), nil)
		equal(View.arrow(0, 0, INF, 3, 0, -1), nil)
		equal(View.arrow(0, 0, 3, 3, 0, NAN), nil)
		equal(View.arrow(nil, 0, 3, 3, 0, -1), nil)
		equal(View.arrow(0, 0, 3, 3, "x", -1), nil)
	end)

	-- The ring in the world -----------------------------------------------------------------------

	case("the ring is drawn as an even number of segments on the radius", function()
		local segments = View.ringSegments(10, -20, 4.5, 32, "solid")
		equal(#segments, 32)
		for _, segment in ipairs(segments) do
			near(math.sqrt((segment.x - 10) ^ 2 + (segment.z + 20) ^ 2), 4.5, 1e-9)
			equal(segment.visible, true)
		end
		equal(#View.ringSegments(0, 0, 4.5, 31, "solid"), 32)
		equal(#View.ringSegments(0, 0, 4.5, 3, "solid"), K.MIN_SEGMENTS)
		equal(#View.ringSegments(0, 0, 4.5, 4000, "solid"), K.MAX_SEGMENTS)
		equal(#View.ringSegments(0, 0, 4.5, nil, "solid"), K.RING_SEGMENTS)
	end)

	case("segments touch end to end, so the ring has no gaps", function()
		local segments = View.ringSegments(0, 0, 4.5, 32, "solid")
		local chord = 2 * 4.5 * math.sin(math.pi / 32)
		for _, segment in ipairs(segments) do
			assert(segment.length >= chord - 1e-9, "gap: " .. segment.length)
			assert(segment.length <= chord * 1.15, "overlap too large: " .. segment.length)
		end
	end)

	case("each segment's turn matches its tangent, so a part's long axis follows the ring", function()
		for _, segment in ipairs(View.ringSegments(3, 4, 4.5, 24, "solid")) do
			-- Roblox CFrame.Angles(0, ry, 0) sends the X axis to (cos ry, 0, -sin ry).
			local ax, az = math.cos(segment.rotY), -math.sin(segment.rotY)
			local rx, rz = segment.x - 3, segment.z - 4
			near(ax * rx + az * rz, 0, 1e-9, "axis must be perpendicular to the radius")
		end
	end)

	case("a dashed ring hides every other segment and a hidden one hides all", function()
		local dashed = View.ringSegments(0, 0, 4.5, 32, "dashed")
		local shown = 0
		for index, segment in ipairs(dashed) do
			equal(segment.visible, index % 2 == 1, "segment " .. index)
			if segment.visible then shown += 1 end
		end
		equal(shown, 16)
		for _, segment in ipairs(View.ringSegments(0, 0, 4.5, 32, "hidden")) do equal(segment.visible, false) end
		for _, segment in ipairs(View.ringSegments(0, 0, 4.5, 32, "nonsense")) do equal(segment.visible, false) end
	end)

	case("a bad centre or radius draws nothing", function()
		equal(#View.ringSegments(NAN, 0, 4.5, 32, "solid"), 0)
		equal(#View.ringSegments(0, INF, 4.5, 32, "solid"), 0)
		equal(#View.ringSegments(0, 0, 0, 32, "solid"), 0)
		equal(#View.ringSegments(0, 0, -2, 32, "solid"), 0)
		equal(#View.ringSegments(0, 0, NAN, 32, "solid"), 0)
		equal(#View.ringSegments("x", 0, 4.5, 32, "solid"), 0)
	end)

	case("the drawn ring follows the server clock and matches the server's ring centre", function()
		local ring = { pivotX = 4, pivotZ = -3, y = 3, orbit = 6, a0 = 0.5, w = 0.25, startedAt = 100, radius = 4.5 }
		local cx, cz = View.ringCenterAt(ring, 102, CaptureSession)
		local sx, sz = CaptureSession.ringCenter(ring, 2)
		equal(cx, sx)
		equal(cz, sz)
		local bx, bz = View.ringCenterAt(ring, 99, CaptureSession)
		local zx, zz = CaptureSession.ringCenter(ring, 0)
		equal(bx, zx)
		equal(bz, zz)
		equal(View.ringCenterAt(nil, 100, CaptureSession), nil)
		equal(View.ringCenterAt(ring, NAN, CaptureSession), nil)
		equal(View.ringCenterAt(ring, 100, nil), nil)
	end)

	case("the ring width pulses only when allowed and stays within its bounds", function()
		local widths = {}
		for step = 0, 40 do
			local steady = View.ringWidth(false, step * 0.1)
			equal(steady, K.RING_WIDTH)
			local width = View.ringWidth(true, step * 0.1)
			assert(width >= K.RING_WIDTH - 1e-9 and width <= K.RING_WIDTH + K.RING_PULSE + 1e-9, "width " .. width)
			widths[width] = true
		end
		assert(next(widths) ~= nil and (function() local n = 0 for _ in pairs(widths) do n += 1 end return n end)() > 5, "no pulse")
		equal(View.ringWidth(true, NAN), K.RING_WIDTH)
	end)

	-- Layout --------------------------------------------------------------------------------------

	local DEVICES = {
		{ name = "iPhone 17 Pro landscape", w = 750, h = 381, touch = true },
		{ name = "iPhone 17 Pro portrait", w = 401, h = 778, touch = true },
		{ name = "Galaxy A06 landscape", w = 705, h = 338, touch = true },
		{ name = "Galaxy A06 portrait", w = 359, h = 718, touch = true },
		{ name = "iPhone 17 Pro landscape interface", w = 750, h = 323, touch = true },
		{ name = "Galaxy A06 landscape interface", w = 705, h = 280, touch = true },
		{ name = "iPhone 17 Pro portrait interface", w = 401, h = 720, touch = true },
		{ name = "Galaxy A06 portrait interface", w = 359, h = 660, touch = true },
		{ name = "Studio desktop", w = 1094, h = 558, touch = false },
		{ name = "desktop 1366", w = 1366, h = 768, touch = false },
		{ name = "desktop 1920", w = 1920, h = 1080, touch = false },
		{ name = "tablet landscape", w = 1024, h = 768, touch = true },
		{ name = "small desktop window", w = 800, h = 600, touch = false },
	}
	local function placed(device)
		local layout = Layout.compute(device.w, device.h, { touch = device.touch })
		return layout, View.layout(layout)
	end

	case("every tested device gets a panel and a large Stop button", function()
		for _, device in ipairs(DEVICES) do
			local layout, spot = placed(device)
			assert(spot and spot.panel and spot.stop, device.name .. " has no placement")
			assert(spot.panel.w >= 190 and spot.panel.h >= 40, device.name .. " panel " .. spot.panel.w .. "x" .. spot.panel.h)
			assert(spot.stop.w >= K.STOP_MIN and spot.stop.h >= K.STOP_MIN, device.name .. " stop " .. spot.stop.w .. "x" .. spot.stop.h)
			assert(K.STOP_MIN >= Layout.MIN_TARGET, "Stop must meet the 44 pixel target")
			for _, rect in ipairs({ spot.panel, spot.stop }) do
				assert(rect.x >= 4 and rect.y >= 4 and rect.x + rect.w <= layout.width - 4
					and rect.y + rect.h <= layout.height - 4, device.name .. " runs off screen")
			end
		end
	end)

	case("the capture screen never covers the avatar, the thumbstick, the jump button or the controls", function()
		for _, device in ipairs(DEVICES) do
			local layout, spot = placed(device)
			local zones = layout.zones
			for label, rect in pairs({ panel = spot.panel, stop = spot.stop }) do
				equal(overlap(rect, zones.keepout), 0, device.name .. " " .. label .. " covers the avatar")
				if layout.mode == "compact" then
					equal(overlap(rect, zones.thumbstick), 0, device.name .. " " .. label .. " on the thumbstick")
					equal(overlap(rect, zones.jump), 0, device.name .. " " .. label .. " on the jump button")
				end
				for _, name in ipairs(Layout.ELEMENTS) do
					if spot.takesOver ~= name then
						equal(overlap(rect, layout.rects[name]), 0, device.name .. " " .. label .. " overlaps " .. name)
					end
				end
			end
			equal(overlap(spot.panel, spot.stop), 0, device.name .. " panel and Stop overlap")
		end
	end)

	case("the headline always fits one line of the panel", function()
		for _, device in ipairs(DEVICES) do
			local layout, spot = placed(device)
			local compact = layout.mode == "compact"
			assert(spot.chars >= 14, device.name .. " has room for only " .. spot.chars .. " characters")
			local lines = {
				View.status(active(), info({ compact = compact })).headline,
				View.status(active({ moving = true }), info({ compact = compact })).headline,
				View.status(active({ inside = false, outsideFor = 0 }), info({ compact = compact })).headline,
				View.status(active(), info({ compact = compact, ringDistance = 4 })).headline,
				View.status(active(), info({ compact = compact, age = 9 })).headline,
			}
			for _, reason in ipairs({ "LeftRing", "TimedOut", "TooFar", "Struck", "Defeated", "Cancelled", "Lost", "LostTrack", "Watchdog",
				"SealMissed" }) do
				table.insert(lines, View.status(ended("Failed", reason), info({ compact = compact })).headline)
			end
			table.insert(lines, View.status(active({ stage = "Seal", seal = SEAL }), info({ compact = compact, serverNow = 101 })).headline)
			for _, line in ipairs(lines) do
				assert(#line <= spot.chars, device.name .. ": \"" .. line .. "\" is " .. #line .. " characters, room for " .. spot.chars)
			end
		end
	end)

	case("a tall phone screen gets a wide panel, not a narrow one", function()
		local _, tall = placed({ w = 401, h = 720, touch = true })
		assert(tall.panel.w >= 300, "iPhone portrait panel is only " .. tall.panel.w .. " wide")
		local _, small = placed({ w = 359, h = 660, touch = true })
		assert(small.panel.w >= 300, "Galaxy portrait panel is only " .. small.panel.w .. " wide")
		for _, device in ipairs(DEVICES) do
			local _, spot = placed(device)
			assert(spot.panel.w >= 190, device.name)
		end
	end)

	case("on phones the Stop button sits next to the panel it belongs to", function()
		for _, device in ipairs(DEVICES) do
			if device.touch then
				local _, spot = placed(device)
				local px, py = spot.panel.x + spot.panel.w / 2, spot.panel.y + spot.panel.h / 2
				local sx, sy = spot.stop.x + spot.stop.w / 2, spot.stop.y + spot.stop.h / 2
				assert(math.sqrt((px - sx) ^ 2 + (py - sy) ^ 2) <= 260, device.name .. " Stop is far from its panel")
			end
		end
	end)

	case("layout is deterministic and returns fresh tables", function()
		local layout = Layout.compute(750, 323, { touch = true })
		local a, b = View.layout(layout), View.layout(layout)
		equal(a.panel.x, b.panel.x)
		equal(a.stop.y, b.stop.y)
		assert(a.panel ~= b.panel, "must be fresh")
		a.panel.x = -999
		equal(View.layout(layout).panel.x, b.panel.x)
	end)

	case("a layout that cannot be used gives no placement", function()
		equal(View.layout(nil), nil)
		equal(View.layout({}), nil)
		equal(View.layout({ width = NAN, height = 400, rects = {}, zones = {} }), nil)
		equal(View.layout({ width = 400, height = 400, rects = {}, zones = {} }), nil)
		equal(View.layout("x"), nil)
	end)

	case("the view's copies of the rule's numbers agree with the rule", function()
		equal(K.CALM_REQUIRED, S.CALM_REQUIRED)
		equal(K.OUTSIDE_LIMIT, S.OUTSIDE_LIMIT)
		equal(K.RING_VISIBLE, S.RING_RADIUS_VISIBLE)
		assert(table.isfrozen(K), "constants must be frozen")
	end)

	case("the module reads no service, clock or interface", function()
		assert(type(source) == "string" and #source > 500, "source missing")
		for _, banned in ipairs({ "GetService", "os.clock", "os.time", "tick%(%)", "Instance.new", "workspace", "game%." }) do
			assert(not source:find(banned), "source uses " .. banned)
		end
	end)

	return result
end
