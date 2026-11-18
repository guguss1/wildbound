-- Pueblo Gatito (docs/design/wildbound-kitten-park-plan.md K-D12; owner request 2026-11-17: "es como el mundo de gatito:
-- un parque verde lindo con las criaturas gatitas, ..."): gives the beast client the four kitten guardians' looks. At
-- server start it builds each kitten from primitive parts (WildboundCandyKittens.build: nothing uploaded) and parks it
-- in ReplicatedStorage.WildboundBeasts.Models.<name>, replacing any older one, with the attributes Species and Height.
-- WildboundBeastsClient shows Models.<beast> for a live encounter, WildboundCandyRestingClient clones it onto the
-- kittens' posts, and WildboundCandyKittenAnimClient poses both. ServerScriptService Script; no per-frame work.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kittens = require(ReplicatedStorage:WaitForChild("WildboundCandyKittens"))

local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
local models = root and root:WaitForChild("Models", 60)
if not models then
	warn("WildboundCandyKittenService: WildboundBeasts.Models missing, the kittens have no model.")
	return
end

for _, name in ipairs(Kittens.NAMES) do
	local ok, model = pcall(Kittens.build, name)
	if ok and model then
		model:SetAttribute("Species", name)
		model:SetAttribute("Height", Kittens.HEIGHT[name])
		local old = models:FindFirstChild(name)
		if old then old:Destroy() end
		model.Parent = models
	else
		warn("WildboundCandyKittenService: " .. name .. " was not built: " .. tostring(model))
	end
end
