-- Caramelo biome (odd/tasks/caramelo-bioma.md, T3): plays Gomibu's clips on this client. WildboundBeastsClient draws
-- every beast as a client-only clone in workspace.WildboundBeastsLocal and publishes the server's phase on it (attribute
-- BeastPhase). Gomibu's clone carries an Animator and the published clip ids (attributes Clip_<name>, set by
-- WildboundCandyGomibuService); this script plays the clip of the current phase. WildboundBeastAnim leaves it alone
-- (it only poses the beasts of WildboundBeastAnimPlan).
local folder = workspace:WaitForChild("WildboundBeastsLocal", 120)
if not folder then return end

local CLIP = { Spawn = "Idle", Calm = "Idle", Notice = "Alert", Chase = "Bounce_Move", Telegraph = "Attack_Telegraph",
	Jump = "Attack_Release", Recover = "Attack_Recover" }
local LOOPED = { Idle = true, Bounce_Move = true }

local function setup(model)
	if not model:IsA("Model") or model.Name ~= "Gomibu" then return end
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not animator then return end
	-- the face rides the Head bone on a RigidConstraint: it must stay unanchored to follow it
	for _, name in ipairs({ "Eyes", "EyeShine", "Nose" }) do
		local part = model:FindFirstChild(name)
		if part then part.Anchored = false end
	end
	local tracks, current = {}, nil
	local function play()
		local name = CLIP[model:GetAttribute("BeastPhase")] or "Idle"
		if name == current then return end
		if current and tracks[current] then tracks[current]:Stop(0.1) end
		current = name
		if not tracks[name] then
			local id = model:GetAttribute("Clip_" .. name)
			if type(id) ~= "string" then return end
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			tracks[name] = animator:LoadAnimation(animation)
			tracks[name].Looped = LOOPED[name] == true
		end
		tracks[name]:Play(0.1)
		model:SetAttribute("GomibuClip", name)
	end
	model:GetAttributeChangedSignal("BeastPhase"):Connect(play)
	play()
end

folder.ChildAdded:Connect(setup)
for _, child in ipairs(folder:GetChildren()) do setup(child) end
