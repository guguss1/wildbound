-- T1 (docs/design/wildbound-fun-build-plan.md; owner request 2026-11-20 "quiero que comences eso de que se pueda jugar
-- mas tiempo"): the thief rank. Every egg a player brings home moves a bar toward the next named rank: Aprendiz, then
-- Ladronzuelo at 3 eggs, Ladrón at 8, Bandido at 15, Maestro at 25 and Leyenda at 40 (the ladder of proposal C,
-- docs/design/wildbound-progression-proposals.md, which the recommended B took for its names). The count only grows,
-- so the rank never goes down.
-- Where the count lives: WildboundState's bankItem adds 1 to the training map's `eggsHome` for each egg banked (the
-- chest, the base, the hub stations, the shelter capsule), like gold: WildboundRecord already saves and checks every
-- count of that map, so there is no record schema step. WildboundGoldService.sync mirrors it on the player attribute
-- WildboundThiefSteals, and WildboundRank.client shows the sign, the bar and a card when a new rank is reached.
-- What a rank gives (a tool, faster beasts for higher ranks) comes in later tasks (T3, T6, T12); this step only shows
-- progress. Pure: no service, no clock, no randomness.
local Rank = {}

Rank.ATTRIBUTE = "WildboundThiefSteals" -- the player attribute the server keeps for the HUD
Rank.KEY = "eggsHome" -- the training map's count (saved)
Rank.MAX = 999999 -- a count above this is shown as this

-- Ordered by `at` (eggs brought home needed). Icons are built-in emoji (no upload); check each in Play on a phone.
Rank.LADDER = table.freeze({
	table.freeze({ name = "Aprendiz", at = 0, icon = "🥚" }),
	table.freeze({ name = "Ladronzuelo", at = 3, icon = "🐾" }),
	table.freeze({ name = "Ladrón", at = 8, icon = "🎒" }),
	table.freeze({ name = "Bandido", at = 15, icon = "🔑" }),
	table.freeze({ name = "Maestro", at = 25, icon = "👑" }),
	table.freeze({ name = "Leyenda", at = 40, icon = "🏆" }),
})

-- Player words (neutral Spanish). They live here, not in WildboundText, so the HUD needs no shared text change.
Rank.TEXT = table.freeze({
	bar = "%d/%d huevos", -- eggs toward the next rank
	top = "¡Rango máximo!",
	upTitle = "¡%s!", -- the new rank's name
	upBody = "Nuevo rango de ladrón",
	upNext = "Próximo: %s con %d huevos",
	upTop = "¡Llegaste al rango más alto!",
})

-- count(value) -> a whole count between 0 and MAX; anything else (nil, NaN, a negative, a string) is 0.
function Rank.count(value)
	if type(value) ~= "number" or value ~= value or value < 0 then return 0 end
	if value == math.huge then return Rank.MAX end
	return math.min(math.floor(value), Rank.MAX)
end

-- fromTraining(training) -> the saved count in a profile's or snapshot's training map (0 when there is none).
function Rank.fromTraining(training)
	return Rank.count(type(training) == "table" and training[Rank.KEY] or nil)
end

-- index(steals) -> the ladder position (1 = Aprendiz) a count reaches.
function Rank.index(steals)
	local have, found = Rank.count(steals), 1
	for position, entry in ipairs(Rank.LADDER) do
		if have >= entry.at then found = position end
	end
	return found
end

-- at(steals) -> the ladder entry ({ name, at, icon }) a count reaches.
function Rank.at(steals)
	return Rank.LADDER[Rank.index(steals)]
end

-- progress(steals) -> { index, name, icon, have, need, nextName, nextAt, top, text }. have and need count eggs since
-- the current rank toward the next one; at the top rank have = need = 1 (a full bar) and nextName is nil.
function Rank.progress(steals)
	local count = Rank.count(steals)
	local position = Rank.index(count)
	local current, following = Rank.LADDER[position], Rank.LADDER[position + 1]
	if not following then
		return { index = position, name = current.name, icon = current.icon, have = 1, need = 1, nextName = nil,
			nextAt = nil, top = true, text = Rank.TEXT.top }
	end
	local have, need = count - current.at, following.at - current.at
	return { index = position, name = current.name, icon = current.icon, have = have, need = need,
		nextName = following.name, nextAt = following.at, top = false, text = Rank.TEXT.bar:format(have, need) }
end

-- reached(before, after) -> the ladder entry of the new rank when `after` reaches a higher rank than `before`, else nil.
-- A jump over two ranks at once names the higher one. before = nil (the first read) never counts as a rank up.
function Rank.reached(before, after)
	if before == nil then return nil end
	local from, to = Rank.index(before), Rank.index(after)
	if to > from then return Rank.LADDER[to] end
	return nil
end

-- upLines(entry) -> title, body, hint: the words of the rank-up card for a ladder entry.
function Rank.upLines(entry)
	local title = Rank.TEXT.upTitle:format(entry.name)
	local position = 1
	for index, item in ipairs(Rank.LADDER) do
		if item == entry then position = index end
	end
	local following = Rank.LADDER[position + 1]
	local hint = following and Rank.TEXT.upNext:format(following.name, following.at) or Rank.TEXT.upTop
	return title, Rank.TEXT.upBody, hint
end

return Rank
