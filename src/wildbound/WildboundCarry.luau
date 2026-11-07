-- Delivery B (B2): pure rules for the carried creature. The server reads the existing threat signal (Silueta's
-- mode and distance, the fog and the safe zone, as WildboundWorldRules.isThreat uses them), turns it into a mood
-- and publishes it on the capsule; every client draws the same small movements from that mood. Nothing here
-- reads the clock, a service or an instance, so the server and the clients agree. Numbers are hypotheses.
local Carry = {}

Carry.CONFIG = table.freeze({
	-- Silueta hunting within this many studs, in the fog, scares the creature; within UNEASY_RADIUS it fidgets.
	FEAR_RADIUS = 40,
	UNEASY_RADIUS = 80,
	-- Small movements, in studs and radians. A calm creature only bobs; fear adds a fast, small shake.
	BOB_AMPLITUDE = 0.08,
	BOB_SPEED = 2.2,
	SHAKE_AMPLITUDE = 0.12,
	SHAKE_SPEED = 31,
	SHAKE_ROLL = 0.12,
	-- The sound hook (delivery D plays it) fires only when fear rises, and never more often than this.
	SOUND_COOLDOWN = 8,
})
local K = Carry.CONFIG

Carry.MOODS = table.freeze({ "calm", "uneasy", "afraid" })
local RANK = table.freeze({ calm = 0, uneasy = 1, afraid = 2 })

local LOOKS = table.freeze({
	calm = table.freeze({ glow = table.freeze({ r = 151, g = 236, b = 175 }), brightness = 0.8 }),
	uneasy = table.freeze({ glow = table.freeze({ r = 255, g = 196, b = 110 }), brightness = 1.1 }),
	afraid = table.freeze({ glow = table.freeze({ r = 255, g = 96, b = 120 }), brightness = 1.6 }),
})

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- reading = { mode, distance, inFog, safe, alive }, all read by the server. Camp, the open field, death and a
-- missing guardian are calm. A retreating Silueta still unsettles it up close, but only a hunt scares it.
function Carry.mood(reading)
	if type(reading) ~= "table" or reading.alive ~= true or reading.safe == true or reading.inFog ~= true then
		return "calm"
	end
	local distance = reading.distance
	if not finite(distance) or distance < 0 or type(reading.mode) ~= "string" then return "calm" end
	local hunting = reading.mode ~= "Retreat"
	if hunting and distance <= K.FEAR_RADIUS then return "afraid" end
	if (hunting and distance <= K.UNEASY_RADIUS) or distance <= K.FEAR_RADIUS then return "uneasy" end
	return "calm"
end

-- Glow colour and light brightness for a mood. Unknown moods look calm.
function Carry.look(mood)
	return LOOKS[mood] or LOOKS.calm
end

-- The capsule's small movements at time t (seconds): y is the bob, x the side shake, roll the tilt.
function Carry.pose(mood, t)
	if not finite(t) then return { x = 0, y = 0, roll = 0 } end
	local rank = RANK[mood] or 0
	local y = math.sin(t * K.BOB_SPEED * (1 + rank * 0.5)) * K.BOB_AMPLITUDE
	if rank == 0 then return { x = 0, y = y, roll = 0 } end
	local share = rank / 2
	local x = math.sin(t * K.SHAKE_SPEED) * K.SHAKE_AMPLITUDE * share
	local roll = math.sin(t * K.SHAKE_SPEED * 0.7 + 1) * K.SHAKE_ROLL * share
	return { x = x, y = y, roll = roll }
end

function Carry.newSoundMemory()
	return { mood = "calm", lastAt = -math.huge }
end

-- The sound hook: "fear" or "unease" when the mood rises, at most once per SOUND_COOLDOWN, nothing otherwise.
-- Staying scared is silent, so carrying never makes the constant noise that would guarantee a chase.
function Carry.soundCue(memory, mood, now)
	if type(memory) ~= "table" or not finite(now) or not RANK[mood] then return nil end
	local rose = RANK[mood] > (RANK[memory.mood] or 0)
	memory.mood = mood
	if not rose or now - memory.lastAt < K.SOUND_COOLDOWN then return nil end
	memory.lastAt = now
	return mood == "afraid" and "fear" or "unease"
end

-- The HUD line for the carried creature: its name, its state and its ward, the longest wording that fits
-- `budget` bytes. nil when nothing is carried. Text is ReplicatedStorage.WildboundText.
function Carry.hudLine(carried, mood, Text, budget)
	if type(carried) ~= "table" or type(Text) ~= "table" or type(Text.CARRY) ~= "table" then return nil end
	local words = Text.CARRY
	local name = type(carried.species) == "string" and carried.species or "?"
	local state = words.moods[mood] or words.moods.calm
	local ward = carried.protected == true and words.warded or words.unwarded
	budget = finite(budget) and math.floor(budget) or 40
	local candidates = {
		("%s: %s · %s · %s"):format(words.label, name, state, ward),
		("%s: %s · %s"):format(words.label, name, state),
		("%s · %s"):format(name, state),
		name,
	}
	local tone = mood == "afraid" and "risk" or "calm"
	for _, text in ipairs(candidates) do
		if #text <= budget then return { text = text, tone = tone } end
	end
	-- Cut on a character boundary so the line stays valid UTF-8.
	local cut = name
	while #cut > math.max(1, budget) do cut = cut:sub(1, utf8.offset(cut, -1) - 1) end
	return { text = cut, tone = tone }
end

return Carry
