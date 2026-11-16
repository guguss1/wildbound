-- Wave 2 beast animations (odd/tasks/wildbound-beasts-wave2.md): which baked clip (assets/bestias_rig/<beast>, the
-- actions in WildboundBeastAnim<Beast>) a rigged Streamer, Root, Gaze or Lurker plays in each phase of its server state
-- machine (and Scuttler's, SC8). Pure and shared: WildboundBeastAnim (client) asks it for a plan when the phase
-- changes and advances it every frame; it never reads an Instance.
--
-- A plan is a list of steps played in order:
--   { clip = "Warn", loop = true }              loops until the phase changes
--   { clip = "ScreamCharge", fit = true }       one shot; all fit steps together are stretched to the phase's length
--   { clip = "Crash" }                          one shot at rate 1; the last one-shot step holds its final pose
--   { clip = "Warn", freeze = true }            holds the clip's first frame, still (BR3: the Screamer's statue)
--   { moving = "Pursue", still = "Idle", ref = 12, reverse = true }
--                                               loops; the moving clip while the body moves (rate = speed / ref),
--                                               the still clip otherwise; reverse plays it backwards when backing off
-- A phase that the server sends and replaces in the same step (Lurker's Land, Root's WhipActive without walls) is never
-- seen by the client's frame loop, so the phase after it carries its clip ("LeapCommit>CoverApproach", ...).
-- When a new plan contains the clip that is playing now, it carries on from that step at the same time (Root's roots
-- that keep rising into the recovery, an idle that is already looping), so a phase change never restarts a clip.
local Plan = {}

local MOVE_ABOVE = 2 -- studs/s: faster than this the body counts as moving
local MOVE_BELOW = 1 -- ...and it stays moving until it drops under this
local MIN_RATE, MAX_RATE = 0.5, 3
local SWITCH_HOLD = 0.25 -- seconds a moving/still change must last before the clip changes

local function walk(moving, still, ref, reverse)
	return { moving = moving, still = still, ref = ref, reverse = reverse }
end
local function loop(clip) return { clip = clip, loop = true } end
local function fit(clip) return { clip = clip, fit = true } end
local function once(clip) return { clip = clip } end
-- BR3: a pose held still on the clip's first frame (the Screamer's statue).
local function freeze(clip) return { clip = clip, freeze = true } end

-- Phase names are the ones the behaviour modules send (Attack.phase), plus "Spawn" before the first one and
-- "Disengage" when the beast leaves. "A>B" entries apply when phase B follows phase A.
Plan.PLANS = table.freeze({
	Streamer = {
		default = { walk("Pursue", "Idle", 12) },
		phases = {
			-- BR3 (odd/tasks/wildbound-beast-revision.md): the Screamer stands frozen as a statue (the first frame of Warn, a
			-- hunched pose), screams (ScreamCharge into the pulse) and chases fast; its grab reuses the rush tell and crash.
			Statue = { freeze("Warn") },
			Scream = { fit("ScreamCharge") },
			["Scream>Pursue"] = { once("ScreamPulse"), walk("Pursue", "Idle", 20) },
			CatchTell = { fit("RushTelegraph") },
			["CatchTell>Recovery"] = { once("Rush"), fit("Crash") },
			Spawn = { freeze("Warn") },
			Dormant = { walk("Pursue", "Idle", 12) },
			Warn = { loop("Warn") },
			ScreamCharge = { fit("ScreamCharge") },
			-- The pulse has no phase of its own: the scream lands when ScreamCharge turns into Pursue.
			["ScreamCharge>Pursue"] = { once("ScreamPulse"), walk("Pursue", "Idle", 12) },
			Pursue = { walk("Pursue", "Idle", 12) },
			RushTelegraph = { fit("RushTelegraph") },
			RushCommit = { loop("Rush") },
			Recovery = { fit("Crash") },
			Stunned = { fit("Crash"), fit("Stun") },
			Disengage = { fit("Despawn") },
		},
	},
	Root = {
		default = { loop("TreeIdle") },
		phases = {
			Spawn = { fit("Emerge"), loop("TreeIdle") },
			Rise = { fit("Emerge"), loop("TreeIdle") },
			-- BR4: following underground: it sinks and rises nearer the target.
			Burrow = { fit("Collapse"), fit("Emerge") },
			SelectAttack = { loop("TreeIdle") },
			TelegraphTrap = { fit("HandsToGround") },
			Erupt = { once("SummonRoots") },
			Recovery = { once("Recover"), loop("TreeIdle") },
			["Erupt>Recovery"] = { once("SummonRoots"), once("Recover"), loop("TreeIdle") },
			TelegraphWalls = { fit("RaiseWalls") },
			WallHold = { loop("TreeIdle") },
			WhipWindup = { fit("WhipWindup") },
			WhipActive = { once("WhipSweep"), once("Recover"), loop("TreeIdle") },
			["WhipActive>Recovery"] = { once("WhipSweep"), once("Recover"), loop("TreeIdle") },
			["WhipWindup>Recovery"] = { once("WhipSweep"), once("Recover"), loop("TreeIdle") },
			Disengage = { fit("Collapse") },
		},
	},
	Gaze = {
		default = { loop("Idle") },
		phases = {
			Spawn = { once("Appear"), loop("Idle") },
			Manifest = { once("Appear"), loop("Idle") },
			-- Unobserved it looks around; observed (ExposureBuild) its eyes open and its hands frame them.
			Watch = { loop("HeadTurn") },
			ExposureBuild = { once("EyesOpen"), once("HandsFrame") },
			ChargeZone = { fit("ChargeZone") },
			-- BR5: the 3 s look completed: its eyes flare once (the defeat), then it just stands there.
			Kill = { once("Pulse"), loop("Idle") },
			Dissipate = { once("Pulse"), loop("Idle") },
			Disengage = { fit("Dissolve") },
		},
	},
	Lurker = {
		default = { loop("Idle") },
		phases = {
			Spawn = { loop("HideCrouch") },
			Presence = { loop("HideCrouch") },
			-- Seen: it freezes mid-step, then creeps (backwards when it backs off).
			StalkObserved = { once("FreezeObserved"), walk("Stalk", "Idle", 6, true) },
			-- Unseen: short sprints between cover, crouched in the pauses.
			CoverApproach = { walk("Sprint", "HideCrouch", 15) },
			LeapWindup = { fit("LeapWindup") },
			LeapCommit = { fit("Leap") },
			Land = { once("LandSkid"), loop("Idle") },
			["LeapCommit>CoverApproach"] = { once("LandSkid"), walk("Sprint", "HideCrouch", 15) },
			["LeapCommit>StalkObserved"] = { once("LandSkid"), walk("Stalk", "Idle", 6, true) },
			OverrunStunned = { fit("Stun") },
			Disengage = { fit("Retreat") },
		},
	},
	-- BR1 (odd/tasks/wildbound-beast-revision.md): Viper's clips, the actions of assets/models/beasts/viper.blend baked by
	-- tools/beast_rig/blend_to_anim_luau.py. Its phases are its own events (Stalk, Windup, Dash, Recover), which the beast
	-- client publishes like the wave 2 phases; "Recover:Crash" is a dash that ended on a wall.
	Viper = {
		default = { walk("Slither", "Idle", 14) },
		phases = {
			Spawn = { walk("Slither", "Idle", 14) },
			Stalk = { walk("Slither", "Idle", 14) },
			Windup = { fit("Windup") },
			Dash = { loop("Dash") },
			Recover = { fit("Recover"), walk("Slither", "Idle", 14) },
			["Recover:Crash"] = { once("Crash"), fit("Recover"), walk("Slither", "Idle", 14) },
			Disengage = { walk("Slither", "Idle", 14) },
		},
	},
	-- BR2: the tarantula Pouncer (assets/models/beasts/pouncer_tarantula.blend): preparation (Windup fills the telegraph),
	-- leap, landing, then the web throw, then the recovery.
	Pouncer = {
		default = { walk("Stalk", "Idle", 16) },
		phases = {
			Spawn = { walk("Stalk", "Idle", 16) },
			Hunt = { walk("Stalk", "Idle", 16) },
			Telegraph = { fit("Windup") },
			Leap = { fit("Leap") },
			Throw = { once("Land"), once("Throw") },
			Recover = { once("Throw"), fit("Recover"), walk("Stalk", "Idle", 16) },
			Disengage = { walk("Stalk", "Idle", 16) },
		},
	},
	-- Scuttler (docs/design/wildbound-scuttler-plan.md section 9, SC8): the clips its rig bakes in SC9. Fallen carries the
	-- fall (Crash or Stumble) as the phase's variant; "Fallen:Crash" applies when the overrun ended on a wall.
	Scuttler = {
		default = { walk("Skitter", "Idle", 14) },
		phases = {
			Spawn = { walk("Skitter", "Idle", 14) },
			Stalk = { walk("Skitter", "Idle", 14) },
			-- The feint looks like a real windup until it is cancelled (crouch and a short lunge).
			FeintTell = { fit("Feint") },
			ChargeTell = { fit("ChargeWindup") },
			PunishTell = { fit("ChargeWindup") },
			Charge = { loop("Charge") },
			Recovery = { once("Recover"), walk("Skitter", "Idle", 14) },
			Fallen = { once("Stumble"), loop("Fallen") },
			["Fallen:Crash"] = { once("Crash"), loop("Fallen") },
			["Fallen>Stalk"] = { once("GetUp"), walk("Skitter", "Idle", 14) },
			Read = { loop("Read") },
			Intercept = { walk("Intercept", "Idle", 21) },
			Block = { loop("Block") },
			Snap = { fit("Snap") },
			PulseCharge = { fit("PulseCharge") },
			Pulse = { once("Pulse"), walk("Skitter", "Idle", 14) },
			Disengage = { fit("Retreat") },
		},
	},
})

-- The steps for `phase` after `previous`, or nil for a beast without a plan. `variant` (optional) picks a
-- "Phase:Variant" entry when the plan has one (Scuttler's Fallen: Crash); otherwise it is ignored.
function Plan.steps(beast, previous, phase, variant)
	local plan = Plan.PLANS[beast]
	if not plan then return nil end
	if type(variant) == "string" and type(phase) == "string" then
		local own = plan.phases[phase .. ":" .. variant]
		if own then return own end
	end
	if type(previous) == "string" and type(phase) == "string" then
		local after = plan.phases[previous .. ">" .. phase]
		if after then return after end
	end
	return plan.phases[phase] or plan.default
end

-- Every clip a beast's plans name (for the data check).
function Plan.clips(beast)
	local seen, list = {}, {}
	local plan = Plan.PLANS[beast]
	if not plan then return list end
	local function add(name)
		if name and not seen[name] then seen[name] = true; table.insert(list, name) end
	end
	local function scan(steps)
		for _, step in ipairs(steps) do add(step.clip); add(step.moving); add(step.still) end
	end
	scan(plan.default)
	for _, steps in pairs(plan.phases) do scan(steps) end
	table.sort(list)
	return list
end

local function clipOf(step, moving)
	if step.clip then return step.clip end
	return moving and step.moving or step.still
end

-- A running plan. lengths[clip] = seconds; duration = the phase's length (untilAt - at) or nil; current/currentTime =
-- the clip playing now, to carry on from.
function Plan.start(steps, duration, lengths, current, currentTime, moving)
	local fitTotal = 0
	for _, step in ipairs(steps) do
		if step.fit then fitTotal += lengths[step.clip] or 0 end
	end
	local fitRate = 1
	if fitTotal > 0 and type(duration) == "number" and duration > 0.05 then
		fitRate = math.clamp(fitTotal / duration, MIN_RATE, MAX_RATE)
	end
	local run = { steps = steps, index = 1, time = 0, fitRate = fitRate, moving = moving == true }
	if current then
		for i, step in ipairs(steps) do
			if step.clip == current or step.moving == current or step.still == current then
				run.index, run.time = i, currentTime or 0
				break
			end
		end
	end
	run.clip = clipOf(steps[run.index], run.moving)
	return run
end

-- Advances the plan by dt with the body's forward speed (studs/s, negative when backing off). Returns the clip to show
-- and its time (a one-shot clip's time never passes its length; a loop's time grows and is wrapped by the sampler),
-- and true when the clip is a one-shot (the caller holds it on its last pose instead of wrapping).
function Plan.advance(run, dt, speed, lengths)
	local step = run.steps[run.index]
	if not step then return nil, 0, false end
	local magnitude = math.abs(speed or 0)
	-- The body's speed comes from 10 Hz snapshots, so a new moving/still state must hold SWITCH_HOLD seconds first.
	local want = run.moving
	if magnitude > MOVE_ABOVE then want = true elseif magnitude < MOVE_BELOW then want = false end
	if want ~= run.moving then
		run.pending = (run.pending or 0) + dt
		if run.pending >= SWITCH_HOLD then run.moving, run.pending = want, 0 end
	else
		run.pending = 0
	end
	if step.moving then
		local clip = clipOf(step, run.moving)
		if clip ~= run.clip then run.clip, run.time = clip, 0 end
		local rate = 1
		if run.moving and step.ref then
			rate = math.clamp(magnitude / step.ref, MIN_RATE, MAX_RATE)
			if step.reverse and (speed or 0) < 0 then rate = -rate end
		end
		run.time += dt * rate
		return run.clip, run.time, false
	end
	if step.freeze then
		run.clip, run.time = step.clip, 0
		return run.clip, 0, true
	end
	if step.loop then
		run.clip = step.clip
		run.time += dt
		return run.clip, run.time, false
	end
	local length = lengths[step.clip] or 0
	run.clip = step.clip
	run.time += dt * (step.fit and run.fitRate or 1)
	if run.time >= length then
		local nextStep = run.steps[run.index + 1]
		if nextStep then
			local over = run.time - length
			run.index += 1
			run.time = 0
			run.clip = clipOf(nextStep, run.moving)
			return Plan.advance(run, over, speed, lengths)
		end
		run.time = length
	end
	return run.clip, run.time, true
end

return Plan
