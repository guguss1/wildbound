-- Pure horror mix (delivery D9): target volumes by threat level, time of day and Reduced effects, fades, the
-- footstep interval, one-shot scheduling with an injected roll, cue positions and the jumpscare gate. Numbers are the
-- starting points of docs/mechanics/wildbound-delivery-d.md section 4; nothing here is measured or heard.
local Mix = {}

Mix.LIMITS = table.freeze({ sounds = 14, snaps = 2, steps = 3 })
Mix.STINGER_COOLDOWN = 15
Mix.EVENT_MAX_AGE = 2
Mix.DUCK = table.freeze({ scale = 0.6, seconds = 1.5 })
Mix.MUFFLE = table.freeze({ highGain = -18, midGain = -6, seconds = 0.4 })
Mix.REDUCED_MASTER = 0.6

local LEVEL = { Safe = true, Distant = true, Near = true, Chase = true }
local TIME = { Day = "Day", Dusk = "Dusk", Dawn = "Dusk", Night = "Night" }
local BEDS = { wind = true, birds = true, insectsDusk = true, insectsNight = true, safeMusic = true, nightBed = true }
local CHASE = { chaseMusic = true, pulse = true }
local ONE_SHOTS = {
	snap = { slot = "snap", volume = 0.25 }, dirt = { slot = "dirt", volume = 0.20 },
	whisper = { slot = "whisper", volume = 0.20 }, signature = { slot = "signature", volume = 0.30, reduced = 0.15 },
	hit = { slot = "hit", volume = 0.35, reduced = 0.30 },
	crack = { slot = "crack", volume = 0.25 }, groan = { slot = "groan", volume = 0.30, reduced = 0.15 },
	stinger = { slot = "stinger", volume = 0.35, fadeIn = 0.1, reducedSlot = "softStinger", reduced = 0.25, reducedFadeIn = 0.3 },
}
local SCHEDULE = {
	snap = { Distant = { 8, 20 }, Near = { 6, 14 } }, dirt = { Near = { 6, 14 } },
	whisper = { Distant = { 20, 40 }, reducedOff = true }, signature = { Chase = { 12, 20 } },
	crack = { Near = { 8, 16 } }, groan = { Chase = { 10, 18 } },
}
-- Dread pass: the giant is heard before it is seen. Its steps roll off from 12 to 150 studs (the fog hides it from
-- about 48 at night to 140 by day); every other spatial cue keeps 8 to 60.
local ROLLOFF = { steps = { 12, 150 }, giantSteps = { 12, 150 }, approach = { 20, 180 } }
Mix.STRIDE = 9 -- studs per step for a 17-stud giant (was 5)

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Mix.master(reduced)
	return reduced == true and Mix.REDUCED_MASTER or 1
end

-- targets(level, time, reduced) -> { slot = volume } for every looping layer.
function Mix.targets(level, time, reduced)
	level = LEVEL[level] and level or "Safe"
	time = TIME[time] or "Day"
	local night, dusk, day = time == "Night", time == "Dusk", time == "Day"
	local bed = level == "Near" and 0.7 or (level == "Chase" and 0.4 or 1)
	local calm = level == "Safe" or level == "Distant"
	local t = {
		wind = (night and 0.14 or 0.20) * bed,
		birds = (day and calm) and 0.10 or 0,
		insectsDusk = dusk and 0.12 * bed or 0,
		insectsNight = night and 0.12 * bed or 0,
		safeMusic = level == "Safe" and (day and 0.15 or (dusk and 0.12 or 0.08)) or (level == "Distant" and 0.08 or 0),
		nightBed = (level == "Safe" and night) and 0.08 or 0,
		unsettling = (level == "Distant" or level == "Near") and 0.20 or 0,
		breathing = (level == "Near" or level == "Chase") and 0.30 or 0,
		steps = level == "Distant" and 0.25 or (level == "Near" and 0.40 or (level == "Chase" and 0.45 or 0)),
		giantSteps = level == "Distant" and 0.18 or (level == "Near" and 0.30 or (level == "Chase" and 0.35 or 0)),
		approach = level == "Distant" and 0.12 or (level == "Near" and 0.10 or 0),
		creak = level == "Near" and 0.12 or (level == "Chase" and 0.08 or 0),
		chaseMusic = level == "Chase" and 0.35 or 0,
		pulse = level == "Chase" and 0.12 or 0,
	}
	if reduced == true then
		t.chaseMusic = math.min(t.chaseMusic, 0.20)
		t.breathing = math.min(t.breathing, 0.15)
	end
	return t
end

-- A heavy, slow walk and a faster run (no giant-run asset exists: run = shorter interval and higher pitch).
function Mix.stepPitch(level)
	return level == "Chase" and 1.2 or 0.85
end

-- PlaybackSpeed of the looping giant thumps from the guardian's measured speed: slow when it walks, fast when it runs.
function Mix.gait(speed)
	if not finite(speed) then return 1 end
	return math.clamp(speed / 6, 0.7, 1.3)
end

-- RollOffMinDistance and RollOffMaxDistance for a spatial slot.
function Mix.rollOff(slot)
	local range = ROLLOFF[slot]
	if range then return range[1], range[2] end
	return 8, 60
end

-- oneShot(kind, reduced) -> { slot, volume, fadeIn } (every one-shot fades in over at least 80 ms).
function Mix.oneShot(kind, reduced)
	local spec = ONE_SHOTS[kind]
	if not spec then return { slot = kind, volume = 0, fadeIn = 0.08 } end
	if reduced == true then
		return { slot = spec.reducedSlot or spec.slot, volume = spec.reduced or spec.volume, fadeIn = spec.reducedFadeIn or spec.fadeIn or 0.08 }
	end
	return { slot = spec.slot, volume = spec.volume, fadeIn = spec.fadeIn or 0.08 }
end

-- Seconds to the next random one-shot of this kind at this level, or nil when it does not play.
function Mix.nextDelay(kind, level, reduced, roll)
	local schedule = SCHEDULE[kind]
	if not schedule or (reduced == true and schedule.reducedOff) or not finite(roll) then return nil end
	local range = schedule[level]
	if not range then return nil end
	roll = math.clamp(roll, 0, 1)
	return range[1] + (range[2] - range[1]) * roll
end

-- Fade length: rises take 1.5 s (2 s with Reduced); chase layers leave over 3 s, threat layers 2 s, beds 4 s.
function Mix.fadeSeconds(slot, rising, reduced)
	if rising then return reduced == true and 2 or 1.5 end
	if CHASE[slot] then return 3 end
	if BEDS[slot] then return 4 end
	return 2
end

function Mix.stepInterval(speed)
	if not finite(speed) or speed <= 0.5 then return nil end
	return Mix.STRIDE / speed
end

-- Where a snap or whisper sounds: 15 to 70 studs from the player toward the guardian, up to 35 degrees off; a
-- random bearing when the guardian is not streamed in.
function Mix.cuePosition(px, pz, gx, gz, distanceRoll, angleRoll)
	if not (finite(px) and finite(pz) and finite(distanceRoll) and finite(angleRoll)) then return nil end
	local distance = 15 + 55 * math.clamp(distanceRoll, 0, 1)
	local bearing
	if finite(gx) and finite(gz) and (gx ~= px or gz ~= pz) then
		bearing = math.atan2(gz - pz, gx - px) + math.rad(35) * (math.clamp(angleRoll, 0, 1) * 2 - 1)
	else
		bearing = math.clamp(angleRoll, 0, 1) * 2 * math.pi
	end
	return { x = px + math.cos(bearing) * distance, z = pz + math.sin(bearing) * distance }
end

function Mix.fresh(eventAt, now)
	return finite(eventAt) and finite(now) and now - eventAt <= Mix.EVENT_MAX_AGE and now - eventAt >= -1
end

function Mix.newJumpscare()
	return { lastAt = -math.huge, life = nil }
end

-- The defeat stinger: once per life, never within 15 s of another, never when the asset did not load.
function Mix.jumpscareAllowed(state, now, life, loaded)
	if type(state) ~= "table" or loaded ~= true or not finite(now) or life == nil then return false end
	if state.life == life then return false end
	return now - state.lastAt >= Mix.STINGER_COOLDOWN
end

function Mix.markJumpscare(state, now, life)
	state.lastAt, state.life = now, life
end

return Mix
