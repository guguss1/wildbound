-- Invoke with require(freshTestClone)(require(freshPlanClone), { Streamer = require(dataClone), Root = ..., Gaze = ...,
-- Lurker = ..., Viper = ..., Pouncer = ... }, beastsClientSource, animClientSource).
-- Wave 2 rigs (odd/tasks/wildbound-beasts-wave2.md, BW2-10): the phase-to-clip plans, the baked data they name, and
-- the client contract (the beast client publishes the phase; the anim client leaves bone-less proxies alone). Pure.
return function(Plan, datas, beastsClient, animClient)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, label)
		assert(math.abs(actual - expected) < 1e-6, (label or "") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and string.find(text, needle, 1, true), label .. " (missing " .. needle .. ")")
	end
	local BEASTS = { "Streamer", "Root", "Gaze", "Lurker" }
	local LENGTHS = { A = 1, B = 0.5, Idle = 3, Walk = 0.8 }

	case("BW2-10 data: every clip a plan names is baked, with keys from 0 to its length", function()
		for _, beast in ipairs(BEASTS) do
			local data = datas[beast]
			assert(type(data) == "table" and data.actions, beast .. " data")
			equal(data.beast, beast, "data beast")
			for _, clip in ipairs(Plan.clips(beast)) do
				local action = data.actions[clip]
				assert(action, beast .. " lacks " .. clip)
				local keys = action.keys
				assert(#keys >= 2, beast .. " " .. clip .. " keys")
				near(keys[1].t, 0, clip .. " first key")
				near(keys[#keys].t, action.length, clip .. " last key")
			end
		end
	end)

	case("BW2-10 data: rest heads and parents for every bone; poses are unit quaternions", function()
		for _, beast in ipairs(BEASTS) do
			local data = datas[beast]
			local count = 0
			for name, p in pairs(data.restPos) do
				count += 1
				assert(data.parents[name] ~= nil, beast .. " parent of " .. name)
				assert(#p == 3, name)
			end
			assert(count >= 30, beast .. " bones " .. count)
			assert(data.restPos.Root and data.restPos.Head, beast .. " Root and Head bones")
			for clip, action in pairs(data.actions) do
				for _, key in ipairs(action.keys) do
					for bone, v in pairs(key.p) do
						local n = v[4] * v[4] + v[5] * v[5] + v[6] * v[6] + v[7] * v[7]
						assert(math.abs(n - 1) < 1e-3, beast .. " " .. clip .. " " .. bone .. " |q| " .. n)
					end
				end
			end
		end
	end)

	case("BW2-10 data: a baked pose stays near rest at the start of the idle (no unpacking drift)", function()
		for beast, idle in pairs({ Streamer = "Idle", Root = "TreeIdle", Gaze = "Idle", Lurker = "Idle" }) do
			local head = datas[beast].actions[idle].keys[1].p.Head
			assert(head, beast .. " head")
			local moved = Vector3.new(head[1], head[2], head[3]).Magnitude
			assert(moved < 2, beast .. " head offset " .. moved)
		end
	end)

	case("BW2-10 plan: each phase of the four state machines maps to its action", function()
		local function first(beast, previous, phase)
			local steps = Plan.steps(beast, previous, phase)
			local s = steps[1]
			return s.clip or s.moving
		end
		equal(first("Streamer", nil, "Warn"), "Warn")
		equal(first("Streamer", "Warn", "ScreamCharge"), "ScreamCharge")
		equal(first("Streamer", "ScreamCharge", "Pursue"), "ScreamPulse", "the pulse lands at the scream")
		equal(first("Streamer", "Recovery", "Pursue"), "Pursue")
		equal(first("Streamer", nil, "RushTelegraph"), "RushTelegraph")
		equal(first("Streamer", nil, "RushCommit"), "Rush")
		equal(first("Streamer", nil, "Recovery"), "Crash")
		equal(Plan.steps("Streamer", nil, "Stunned")[2].clip, "Stun")
		equal(first("Streamer", nil, "Disengage"), "Despawn")
		equal(first("Root", nil, "Rise"), "Emerge")
		equal(first("Root", nil, "TelegraphTrap"), "HandsToGround")
		equal(first("Root", nil, "Erupt"), "SummonRoots")
		equal(first("Root", nil, "TelegraphWalls"), "RaiseWalls")
		equal(first("Root", nil, "WhipWindup"), "WhipWindup")
		equal(first("Root", nil, "WhipActive"), "WhipSweep")
		equal(first("Root", nil, "Disengage"), "Collapse")
		equal(first("Gaze", nil, "Manifest"), "Appear")
		equal(first("Gaze", nil, "Watch"), "HeadTurn")
		equal(first("Gaze", nil, "ExposureBuild"), "EyesOpen", "observed")
		equal(first("Gaze", nil, "ChargeZone"), "ChargeZone")
		equal(first("Gaze", nil, "Disengage"), "Dissolve")
		equal(first("Lurker", nil, "Presence"), "HideCrouch")
		equal(first("Lurker", nil, "StalkObserved"), "FreezeObserved", "observed")
		equal(first("Lurker", nil, "CoverApproach"), "Sprint", "unobserved")
		equal(first("Lurker", nil, "LeapWindup"), "LeapWindup")
		equal(first("Lurker", nil, "LeapCommit"), "Leap")
		equal(first("Lurker", nil, "Land"), "LandSkid")
		equal(first("Lurker", "LeapCommit", "CoverApproach"), "LandSkid", "Land is replaced in the same step")
		equal(first("Root", "WhipWindup", "Recovery"), "WhipSweep", "WhipActive is replaced in the same step")
		equal(first("Lurker", nil, "OverrunStunned"), "Stun")
		equal(first("Lurker", nil, "Disengage"), "Retreat")
		equal(first("Root", nil, "Unknown"), "TreeIdle", "default")
		equal(Plan.steps("Gargoyle", nil, "Warn"), nil, "no plan for a beast without clips (BR1 gave Viper one)")
	end)

	case("BW2-10 plan: fit steps fill the phase, clamped; others play at rate 1", function()
		local run = Plan.start({ { clip = "A", fit = true }, { clip = "B", fit = true } }, 3, LENGTHS)
		near(run.fitRate, 0.5)
		run = Plan.start({ { clip = "A", fit = true } }, 0.25, LENGTHS)
		near(run.fitRate, 3, "clamped")
		run = Plan.start({ { clip = "A", fit = true } }, nil, LENGTHS)
		near(run.fitRate, 1, "no duration")
		local clip, time, oneShot = Plan.advance(Plan.start({ { clip = "A", fit = true } }, 2, LENGTHS), 1, 0, LENGTHS)
		equal(clip, "A"); near(time, 0.5); equal(oneShot, true)
	end)

	case("BW2-10 plan: one-shots chain into the next step and the last one holds its final pose", function()
		local run = Plan.start({ { clip = "A" }, { clip = "B" } }, nil, LENGTHS)
		local clip, time = Plan.advance(run, 1.2, 0, LENGTHS)
		equal(clip, "B"); near(time, 0.2)
		clip, time = Plan.advance(run, 5, 0, LENGTHS)
		equal(clip, "B"); near(time, 0.5, "held")
		run = Plan.start({ { clip = "A" }, { clip = "Idle", loop = true } }, nil, LENGTHS)
		local _, _, oneShot = Plan.advance(run, 4, 0, LENGTHS)
		equal(run.clip, "Idle"); equal(oneShot, false)
	end)

	case("BW2-10 plan: a walk step picks moving or still with hysteresis, rate from speed, reverse when backing", function()
		local steps = { { moving = "Walk", still = "Idle", ref = 10, reverse = true } }
		local run = Plan.start(steps, nil, LENGTHS)
		equal(Plan.advance(run, 0.1, 0, LENGTHS), "Idle")
		equal(Plan.advance(run, 0.1, 5, LENGTHS), "Idle", "a change must hold 0.25 s (10 Hz snapshots)")
		equal(Plan.advance(run, 0.2, 5, LENGTHS), "Walk")
		near(run.time, 0.1, "rate 0.5")
		equal(Plan.advance(run, 0.1, 1.5, LENGTHS), "Walk", "still moving between the thresholds")
		equal(Plan.advance(run, 0.1, 0.5, LENGTHS), "Walk", "a short stop keeps the clip")
		equal(Plan.advance(run, 0.2, 0.5, LENGTHS), "Idle")
		Plan.advance(run, 0.3, -10, LENGTHS)
		equal(run.clip, "Walk")
		near(run.time, -0.3, "backwards")
	end)

	case("BW2-10 plan: a new plan carries on with the clip already playing", function()
		local steps = Plan.steps("Root", "Erupt", "Recovery")
		local run = Plan.start(steps, 3.5, { SummonRoots = 1.2, Recover = 1, TreeIdle = 4 }, "SummonRoots", 0.5)
		equal(run.index, 1); near(run.time, 0.5)
		run = Plan.start(Plan.steps("Root", "WhipActive", "Recovery"), 3.5, { WhipSweep = 0.6, Recover = 1, TreeIdle = 4 },
			"TreeIdle", 2)
		equal(run.clip, "TreeIdle", "the idle keeps looping"); near(run.time, 2)
		run = Plan.start(Plan.steps("Streamer", nil, "Warn"), 1, { Warn = 1 }, "Idle", 2)
		equal(run.clip, "Warn"); near(run.time, 0)
	end)

	case("BW2-10 client: the beast client publishes each phase and skips posture() for rigged models", function()
		has(beastsClient, 'view.model:SetAttribute("BeastPhase", phase)', "phase attribute")
		has(beastsClient, "publishPhase(view, ev.phase, ev.at, ev.untilAt)", "every Phase event")
		has(beastsClient, 'publishPhase(view, "Disengage", ev.at, ev.untilAt)', "the leave")
		has(beastsClient, "if view.wave2 and not view.rigged then base = posture(view, base, at) end", "posture for proxies only")
		has(animClient, "if not rig then return end", "a proxy without bones is left alone")
		has(animClient, 'ReplicatedStorage:WaitForChild("WildboundLumipolRig"', "the shared rig math")
		has(animClient, 'model:GetAttribute("BeastPhase")', "reads the phase")
		assert(not string.find(animClient, "FireServer", 1, true), "the anim client sends nothing")
	end)

	-- SC8 (odd/tasks/wildbound-scuttler.md, docs/design/wildbound-scuttler-plan.md section 9): Scuttler's phases and the
	-- clips its rig will bake. The baked data arrives with the rig (SC9), so these cases read no data module.
	local SCUTTLER_PHASES = { "Spawn", "Stalk", "FeintTell", "ChargeTell", "PunishTell", "Charge", "Recovery", "Fallen",
		"Read", "Intercept", "Block", "Snap", "PulseCharge", "Pulse", "Disengage" }
	local SCUTTLER_CLIPS = { "Idle", "Skitter", "Read", "Intercept", "Block", "Feint", "ChargeWindup", "Charge", "Snap",
		"PulseCharge", "Pulse", "Recover", "Stumble", "Crash", "Fallen", "GetUp", "Retreat" }

	case("SC8 plan: every Scuttler phase has its own plan and the plans name exactly the section 9 clips", function()
		local plan = Plan.PLANS.Scuttler
		assert(type(plan) == "table" and type(plan.phases) == "table", "a Scuttler plan")
		for _, phase in ipairs(SCUTTLER_PHASES) do assert(plan.phases[phase], "a plan for " .. phase) end
		local expected = table.clone(SCUTTLER_CLIPS)
		table.sort(expected)
		equal(table.concat(Plan.clips("Scuttler"), ","), table.concat(expected, ","), "clips")
	end)

	case("SC8 plan: each Scuttler phase maps to its section 9 action; a fall's variant picks Crash or Stumble", function()
		local function first(previous, phase, variant)
			local s = Plan.steps("Scuttler", previous, phase, variant)[1]
			return s.clip or s.moving
		end
		equal(first(nil, "Spawn"), "Skitter")
		equal(first(nil, "Stalk"), "Skitter")
		equal(Plan.steps("Scuttler", nil, "Stalk")[1].still, "Idle", "idle when it stands")
		equal(first(nil, "Read"), "Read")
		equal(first(nil, "Intercept"), "Intercept")
		equal(first(nil, "Block"), "Block")
		equal(first(nil, "FeintTell"), "Feint")
		equal(first(nil, "ChargeTell"), "ChargeWindup")
		equal(first(nil, "PunishTell"), "ChargeWindup")
		assert(Plan.steps("Scuttler", nil, "ChargeTell")[1].fit, "the windup fills the tell")
		equal(first(nil, "Charge"), "Charge")
		equal(first(nil, "Snap"), "Snap")
		equal(first(nil, "PulseCharge"), "PulseCharge")
		assert(Plan.steps("Scuttler", nil, "PulseCharge")[1].fit, "rears up for the whole charge")
		equal(first(nil, "Pulse"), "Pulse")
		equal(first(nil, "Recovery"), "Recover")
		equal(first(nil, "Fallen"), "Stumble", "a stumble without a variant")
		equal(first(nil, "Fallen", "Stumble"), "Stumble")
		equal(first(nil, "Fallen", "Crash"), "Crash", "head into the wall")
		equal(Plan.steps("Scuttler", nil, "Fallen")[2].clip, "Fallen", "then dazed")
		equal(Plan.steps("Scuttler", nil, "Fallen", "Crash")[2].clip, "Fallen", "then dazed")
		equal(first("Fallen", "Stalk"), "GetUp", "it gets up after a fall")
		equal(first(nil, "Disengage"), "Retreat")
		equal(first(nil, "Unknown"), "Skitter", "default")
		equal(Plan.steps("Streamer", nil, "Warn", "Crash")[1].clip, "Warn", "a variant without its own entry is ignored")
	end)

	case("SC8 client: the fall's variant is published on the model and read by the anim client", function()
		has(beastsClient, 'view.model:SetAttribute("BeastPhaseVariant", variant)', "the variant attribute")
		has(beastsClient, "publishVariant(view, ev.fall)", "Fallen's fall (Crash or Stumble)")
		has(animClient, 'Plan.steps(entry.beast, previous, phase, model:GetAttribute("BeastPhaseVariant"))', "the anim client")
	end)

	-- BR1 (odd/tasks/wildbound-beast-revision.md): Viper's clips, baked from assets/models/beasts/viper.blend.
	case("BR1 Viper: every phase (rest/move, windup, dash, impact or miss, recovery) has a baked clip", function()
		local data = datas.Viper
		assert(type(data) == "table" and data.actions, "Viper data")
		equal(data.beast, "Viper", "data beast")
		for _, clip in ipairs(Plan.clips("Viper")) do
			local action = data.actions[clip]
			assert(action, "Viper lacks " .. clip)
			near(action.keys[1].t, 0, clip .. " first key")
			near(action.keys[#action.keys].t, action.length, clip .. " last key")
		end
		local function first(previous, phase, variant)
			local s = Plan.steps("Viper", previous, phase, variant)[1]
			return s.clip or s.moving
		end
		equal(first(nil, "Stalk"), "Slither", "moves")
		equal(Plan.steps("Viper", nil, "Stalk")[1].still, "Idle", "rests")
		equal(first(nil, "Windup"), "Windup"); assert(Plan.steps("Viper", nil, "Windup")[1].fit, "the windup fills the tell")
		equal(first(nil, "Dash"), "Dash"); assert(Plan.steps("Viper", nil, "Dash")[1].loop, "the dash loops while it travels")
		equal(first(nil, "Recover"), "Recover", "a hit or a miss")
		equal(first(nil, "Recover", "Crash"), "Crash", "a wall")
	end)

	case("BR1 client: Viper's events publish the phase the anim client reads", function()
		for _, needle in ipairs({ 'publishPhase(view, "Windup", ev.at, ev.dashAt)', 'publishPhase(view, "Dash", ev.at, ev.endAt)',
			'publishPhase(view, "Recover", ev.at, ev.untilAt)', 'publishVariant(view, "Crash")', 'function handlers.Stalk(ev, view)' }) do
			has(beastsClient, needle, "Viper phase")
		end
	end)

	-- BR2: the tarantula Pouncer's clips (pouncer_tarantula.blend), with the new web throw.
	case("BR2 Pouncer: preparation, leap, landing, web throw and recovery each have a baked clip", function()
		local data = datas.Pouncer
		assert(type(data) == "table" and data.actions, "Pouncer data")
		equal(data.beast, "Pouncer", "data beast")
		for _, clip in ipairs(Plan.clips("Pouncer")) do
			local action = data.actions[clip]
			assert(action, "Pouncer lacks " .. clip)
			near(action.keys[#action.keys].t, action.length, clip .. " last key")
		end
		equal(Plan.steps("Pouncer", nil, "Telegraph")[1].clip, "Windup")
		equal(Plan.steps("Pouncer", nil, "Leap")[1].clip, "Leap")
		equal(Plan.steps("Pouncer", nil, "Throw")[1].clip, "Land", "the landing first")
		equal(Plan.steps("Pouncer", nil, "Throw")[2].clip, "Throw", "then the throw")
		has(beastsClient, 'publishPhase(view, "Throw", ev.at, ev.throwAt)', "the throw phase is published")
	end)

	-- BR3: the Screamer's statue is a still pose; the scream and the grab have their clips.
	case("BR3 Screamer: the statue holds one still pose; the scream, chase and grab have clips", function()
		local statue = Plan.steps("Streamer", nil, "Statue")[1]
		equal(statue.clip, "Warn"); equal(statue.freeze, true)
		local run = Plan.start({ statue }, nil, { Warn = 1 })
		local clip, time, oneShot = Plan.advance(run, 5, 0, { Warn = 1 })
		equal(clip, "Warn"); near(time, 0, "never moves"); equal(oneShot, true)
		equal(Plan.steps("Streamer", nil, "Scream")[1].clip, "ScreamCharge")
		equal(Plan.steps("Streamer", "Scream", "Pursue")[1].clip, "ScreamPulse")
		equal(Plan.steps("Streamer", nil, "CatchTell")[1].clip, "RushTelegraph")
		has(beastsClient, "trueForm(view)", "the client reveals the true form at the scream")
	end)

	return result
end
