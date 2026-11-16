-- Caramelo biome (odd/tasks/wildbound-candy-critters.md, CC5): gives the beast client the real rigs of the five small
-- candy creatures (Mochimiau, Canelin, Flanin, Mielita, GatoRepartidor). WildboundBeastsClient shows
-- ReplicatedStorage.WildboundBeasts.Models.<beast> when it exists, so each rig import in
-- ServerStorage.WildboundNewCandyImports is prepared once and parked there: a clone without its PackageLink, PrimaryPart
-- = RootPart (the part that carries the bones), the pivot on the ground under the root facing -Z (the import's RootPart
-- already looks the creature's way), the root anchored and every part out of collisions and queries. The client clones
-- it, anchors it and drives its bones from BeastPhase (the client animator, not this script). Clip_<name> attributes
-- follow the guarded pattern of WildboundCandyTortidragonService: only clips with a published id, and IDS is empty
-- until the owner publishes them to the group. Duquesa Burbuja is not here: it stays seated scenery in
-- Workspace.WildboundNewCandyPreview, with no brain.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NAMES = { "Mochimiau", "Canelin", "Flanin", "Mielita", "GatoRepartidor" }
-- The clip names of each creature (assets/blender/caramelo/<slug>/<slug>-clips.json) and their published ids.
local CLIPS = {
	Mochimiau = { ORDER = { "Idle", "Walk", "Trot", "Bounce", "Roll", "Charge", "Rest" }, IDS = {} },
	Canelin = { ORDER = { "Idle", "Walk", "Bounce", "Spin", "Charge", "Rest", "Alert" }, IDS = {} },
	Flanin = { ORDER = { "Idle", "Walk", "Jump", "Land", "Slide", "Charge", "Wave", "Rest" }, IDS = {} },
	Mielita = { ORDER = { "Fly", "Patrol", "Dash", "Pollen", "Orbit", "Rest", "Dizzy" }, IDS = {} },
	GatoRepartidor = { ORDER = { "Idle", "Walk", "Run", "Deliver", "Throw", "Call", "Rest", "Surprised" }, IDS = {} },
}
local function animationId(Clips, name)
	local id = Clips.IDS[name]
	assert(type(id) == "number" and id > 0, "no published id for clip " .. tostring(name))
	return "rbxassetid://" .. string.format("%d", id)
end

local function prepare(import, name)
	local model = import:Clone()
	model.Name = name
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("PackageLink") then d:Destroy() end
	end
	local root = model:FindFirstChild("RootPart")
	if not (root and root:IsA("BasePart")) then
		warn("WildboundCandyCritterService: " .. name .. " has no RootPart, no model.")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	local box, size = model:GetBoundingBox()
	local ground = Vector3.new(root.Position.X, box.Position.Y - size.Y / 2, root.Position.Z)
	local frame = CFrame.new(ground) * root.CFrame.Rotation
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
		end
	end
	root.Transparency = 1
	local controller = model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController", model)
	if not controller:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = controller end
	root.PivotOffset = root.CFrame:ToObjectSpace(frame)
	model:PivotTo(CFrame.new())
	model:SetAttribute("Species", name)
	model:SetAttribute("Height", size.Y)
	-- only published clips: until a clip has an id the client leaves the model to its live animator
	local Clips = CLIPS[name]
	for _, clip in ipairs(Clips.ORDER) do
		if Clips.IDS[clip] then model:SetAttribute("Clip_" .. clip, animationId(Clips, clip)) end
	end
	return model
end

local imports = ServerStorage:WaitForChild("WildboundNewCandyImports", 30)
local root = ReplicatedStorage:WaitForChild("WildboundBeasts", 60)
local models = root and root:WaitForChild("Models", 60)
if not imports or not models then
	warn("WildboundCandyCritterService: WildboundNewCandyImports or WildboundBeasts.Models missing, the candy critters have no model.")
	return
end
for _, name in ipairs(NAMES) do
	local import = imports:FindFirstChild(name)
	if not import then
		warn("WildboundCandyCritterService: no import for " .. name .. ", it has no model.")
	elseif not models:FindFirstChild(name) then
		local model = prepare(import, name)
		if model then model.Parent = models end
	end
end
