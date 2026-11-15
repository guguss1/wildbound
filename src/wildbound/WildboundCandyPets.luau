-- CE2 (odd/tasks/wildbound-caramelo.md): the hatched Caramelo creatures as passive farm pets. A Gomibu, Flanfuria or
-- Tortidragon placed in the base farm is a scaled-down copy of its real rig prefab (ServerStorage.WildboundAssets.<name>,
-- the one the wild beast wears), never a beast: no brain, no attack, no collision, no own light (pack
-- 05_SISTEMAS/03 and 06_PROMPTS_CLAUDE/07: "sin seguimiento automatico ni luz propia", "no actor hostil").
-- WildboundCreatureToolbar walks it around the own pad (PF6) and sets FarmWalking while it walks; `animate` plays the
-- species' published FarmIdle / walk clip on the server's Animator (replicated to every client). A clip with no
-- published id leaves the rig in its rest pose. The server injects `build` as the Toolbar's farmModel.
local Pets = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

-- prefab: the child of ServerStorage.WildboundAssets; clips: its Clips module in ServerStorage; idle / walk: clip keys;
-- height: studs tall in the farm (a Lumipol stands about 1.5, a player 5.5).
Pets.SPECIES = freeze({
	Gomibu = { prefab = "Gomibu", clips = "WildboundCandyGomibuClips", idle = "FarmIdle", walk = "Bounce_Move", height = 3 },
	Flanfuria = { prefab = "Flanfuria", clips = "WildboundCandyFlanfuriaClips", idle = "FarmIdle", walk = "Hop_Move",
		height = 3.2 },
	Tortidragon = { prefab = "Tortidragon", clips = "WildboundCandyTortidragonClips", idle = "FarmIdle",
		walk = "Walk_Quadruped", height = 3.6 },
})
Pets.WALKING = "FarmWalking" -- model attribute set by the Toolbar's wander
Pets.PASSIVE = "WildboundPassive" -- model attribute: a farm pet, never a beast

function Pets.isPet(species)
	return type(species) == "string" and Pets.SPECIES[species] ~= nil
end

-- The published ids of the pet's two clips, from its Clips module (`IDS`, `animationId`); a missing id is nil.
function Pets.clipIds(species, clips)
	local spec = Pets.SPECIES[species]
	if not spec or type(clips) ~= "table" or type(clips.IDS) ~= "table" then return { idle = nil, walk = nil } end
	local function id(name)
		if clips.IDS[name] == nil then return nil end
		return clips.animationId(name)
	end
	return { idle = id(spec.idle), walk = id(spec.walk) }
end

-- Height of the visible rig over its pivot (the prefab's pivot is on the ground between the feet). Hidden parts (the
-- root, the collision box, Flanfuria's Keeper) do not count.
function Pets.visibleHeight(model)
	local pivotY, top = model:GetPivot().Position.Y, 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			top = math.max(top, part.Position.Y + part.Size.Y / 2 - pivotY)
		end
	end
	return top
end

-- A detached farm model of `species` standing with its feet on `spot`, facing `look`, or nil when the species is not a
-- pet or its prefab is missing. assets: ServerStorage.WildboundAssets; ids: Pets.clipIds (optional).
function Pets.build(species, assets, spot, look, ids)
	local spec = Pets.SPECIES[species]
	local template = spec and typeof(assets) == "Instance" and assets:FindFirstChild(spec.prefab)
	if not template or not template:IsA("Model") then return nil end
	local model = template:Clone()
	model.Name = "WildboundFarmCreature"
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Light") or item:IsA("PackageLink") then item:Destroy() end
	end
	local height = Pets.visibleHeight(model)
	if height > 0 then model:ScaleTo(model:GetScale() * spec.height / height) end
	local direction = typeof(look) == "Vector3" and Vector3.new(look.X, 0, look.Z) or Vector3.zero
	if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
	model:PivotTo(CFrame.lookAt(spot, spot + direction.Unit))
	local root = model.PrimaryPart
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = part == root
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		end
	end
	model:SetAttribute(Pets.PASSIVE, true)
	model:SetAttribute("WildboundSpecies", species)
	model:SetAttribute(Pets.WALKING, false)
	ids = ids or {}
	if ids.idle then model:SetAttribute("Clip_Idle", ids.idle) end
	if ids.walk then model:SetAttribute("Clip_Walk", ids.walk) end
	local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController", model)
	if not controller:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = controller end
	local body = model:FindFirstChild("Collision") or root
	return model, body
end

-- Plays the idle clip, and the walk clip while FarmWalking is true. load(animator, id) -> track (default
-- Animator:LoadAnimation). Returns the tracks, or nil when the model has no published clip (rest pose).
function Pets.animate(model, load)
	local ids = { idle = model:GetAttribute("Clip_Idle"), walk = model:GetAttribute("Clip_Walk") }
	if type(ids.idle) ~= "string" and type(ids.walk) ~= "string" then return nil end
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	load = load or function(target, id)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return target:LoadAnimation(animation)
	end
	local tracks = {}
	for key, id in pairs(ids) do
		if type(id) == "string" then
			tracks[key] = load(animator, id)
			tracks[key].Looped = true
		end
	end
	local current = nil
	local function pick()
		local want = model:GetAttribute(Pets.WALKING) == true and tracks.walk and "walk" or tracks.idle and "idle" or nil
		if want == current then return end
		if current then tracks[current]:Stop(0.2) end
		current = want
		if want then tracks[want]:Play(0.2) end
	end
	model:GetAttributeChangedSignal(Pets.WALKING):Connect(pick)
	pick()
	return tracks
end

return Pets
