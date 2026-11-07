-- Funnel reducer (W16, F2 analysis). Given a list of recorded analytics events it computes step counts and
-- conversion, per-trip counts, a session summary and the Wilson interval from docs/testing/wildbound-f2-plan.md
-- section 4. Pure and read-only: it never writes, never names a service and keeps no state between calls.
-- tools/analytics_funnel.py does the same on an exported log (JSON lines); both are tested on one fixture.
--
-- A session reaches step k only if its events, sorted by seq, hold a matching event for step 1, then a LATER
-- one for step 2, and so on. One event moves a session at most one step. This is stricter than Roblox's funnel
-- page, which counts skipped steps as complete, so a player who never dies is never shown as defeated.
local Funnel = {}

Funnel.SCHEMA = 1
Funnel.Z = 1.96

local function freezeSteps(steps)
	for _, step in ipairs(steps) do
		if step.where then
			for field, values in pairs(step.where) do step.where[field] = table.freeze(values) end
			table.freeze(step.where)
		end
		table.freeze(step)
	end
	return table.freeze(steps)
end

-- Funnel A of docs/testing/wildbound-f2-plan.md, redefined on the events this build can really log.
Funnel.FIRST_STEPS = freezeSteps({
	{ step = "Joined", name = "session_join" },
	{ step = "LeftCamp", name = "trip_open" },
	{ step = "FirstGain", name = "first_gain" },
	{ step = "FirstExtract", name = "first_extract" },
	{ step = "SecondTrip", name = "trip_open", where = { n = { "2", "3", "4plus" } } },
	{ step = "ThirdTrip", name = "trip_open", where = { n = { "3", "4plus" } } },
})

local function usable(e)
	if type(e) ~= "table" or e.v ~= Funnel.SCHEMA or type(e.name) ~= "string" or type(e.f) ~= "table" then return false end
	if type(e.sid) ~= "string" or #e.sid == 0 or #e.sid > 64 then return false end
	local seq = e.seq
	return type(seq) == "number" and seq == seq and seq >= 1 and seq % 1 == 0 and seq < math.huge
end

-- Valid, de-duplicated events grouped by session id. A line seen twice (a log pasted twice) counts once.
local function collect(events)
	local sessions, order, seen = {}, {}, {}
	local invalid, duplicates = 0, 0
	for _, e in ipairs(events) do
		if not usable(e) then
			invalid += 1
		else
			local id = e.sid .. "#" .. e.seq
			if seen[id] then
				duplicates += 1
			else
				seen[id] = true
				local list = sessions[e.sid]
				if not list then
					list = {}
					sessions[e.sid] = list
					table.insert(order, e.sid)
				end
				table.insert(list, e)
			end
		end
	end
	for _, list in pairs(sessions) do table.sort(list, function(a, b) return a.seq < b.seq end) end
	return sessions, order, invalid, duplicates
end

local function matches(step, e)
	if e.name ~= step.name then return false end
	if step.where then
		for field, values in pairs(step.where) do
			if not table.find(values, e.f[field]) then return false end
		end
	end
	return true
end

function Funnel.reduce(events, steps)
	steps = steps or Funnel.FIRST_STEPS
	local sessions, order, invalid, duplicates = collect(events)
	local reached = table.create(#steps, 0)
	for _, sid in ipairs(order) do
		local position = 1
		for _, e in ipairs(sessions[sid]) do
			if position > #steps then break end
			if matches(steps[position], e) then
				reached[position] += 1
				position += 1
			end
		end
	end
	local out = {}
	for index, step in ipairs(steps) do
		local count = reached[index]
		local first, previous = reached[1], index > 1 and reached[index - 1] or nil
		out[index] = { index = index, step = step.step, name = step.name, reached = count,
			ofStart = first > 0 and count / first or nil,
			ofPrev = previous and previous > 0 and count / previous or nil,
			lost = previous and previous - count or 0 }
	end
	return { sessions = #order, invalid = invalid, duplicates = duplicates, steps = out }
end

local function bump(map, key)
	map[key] = (map[key] or 0) + 1
end

-- Trips across all sessions: how many opened and ended, how they ended, how many gained, how long they ran.
function Funnel.trips(events)
	local sessions, order = collect(events)
	local out = { opened = 0, ended = 0, gained = 0, outcomes = {}, bands = {} }
	for _, sid in ipairs(order) do
		for _, e in ipairs(sessions[sid]) do
			if e.name == "trip_open" then
				out.opened += 1
			elseif e.name == "trip_end" then
				out.ended += 1
				bump(out.outcomes, tostring(e.f.outcome))
				bump(out.bands, tostring(e.f.band))
				if e.f.gained == "yes" then out.gained += 1 end
			end
		end
	end
	out.extractedOfEnded = out.ended > 0 and (out.outcomes.extracted or 0) / out.ended or nil
	out.gainedOfEnded = out.ended > 0 and out.gained / out.ended or nil
	return out
end

function Funnel.summary(events)
	local sessions, order, invalid, duplicates = collect(events)
	local ends = { count = 0, bands = {}, trips = {}, ended = {} }
	local deaths, captures = {}, { ended = 0, reasons = {} }
	for _, sid in ipairs(order) do
		for _, e in ipairs(sessions[sid]) do
			if e.name == "session_end" then
				ends.count += 1
				bump(ends.bands, tostring(e.f.band))
				bump(ends.trips, tostring(e.f.trips))
				bump(ends.ended, tostring(e.f.ended))
			elseif e.name == "death" then
				bump(deaths, tostring(e.f.cause))
			elseif e.name == "capture_end" then
				captures.ended += 1
				bump(captures.reasons, tostring(e.f.reason))
			end
		end
	end
	return { sessions = #order, invalid = invalid, duplicates = duplicates, firstSteps = Funnel.reduce(events),
		trips = Funnel.trips(events), sessionEnds = ends, deaths = deaths, captures = captures }
end

-- 95% Wilson score interval for k of n. Returns nil unless 0 <= k <= n are whole numbers and n > 0.
function Funnel.wilson(k, n)
	if type(k) ~= "number" or type(n) ~= "number" or k ~= k or n ~= n or k % 1 ~= 0 or n % 1 ~= 0
		or n <= 0 or k < 0 or k > n or n == math.huge then return nil end
	local z = Funnel.Z
	local p = k / n
	local denominator = 1 + z * z / n
	local center = (p + z * z / (2 * n)) / denominator
	local half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator
	return { k = k, n = n, center = center, low = math.max(0, center - half), high = math.min(1, center + half) }
end

return Funnel
