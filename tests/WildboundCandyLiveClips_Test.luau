-- Invoke with require(freshTestClone)(require(freshKitClone), require(freshSpecClone), require(freshTortidragonClipsClone),
-- require(freshDonGlaseonClipsClone), ServerStorage.WildboundAssets.Tortidragon, ServerStorage.WildboundAssets.DonGlaseon,
-- { anim = WildboundCandyCritterAnim.Source, tortService = WildboundCandyTortidragonService.Source,
-- donService = WildboundCandyDonGlaseonService.Source, tortAnim = WildboundCandyTortidragonAnim.Source,
-- donAnim = WildboundCandyDonGlaseonAnim.Source }).
-- A3 (odd/tasks/wildbound-caramelo-playfix.md): Tortidragon and Don Glaseon animate live with no published Animation
-- asset, the same way the six critters do. Their clip data (ServerStorage, keys { time, pose }) is copied to
-- ReplicatedStorage by their services, converted to the clip kit format by Kit.fromLegacy, and played by the shared
-- client WildboundCandyCritterAnim, which writes Bone.Transform from it. The phase maps are the old clients' CLIP
-- tables. A Clip_<name> attribute (a published id) still wins: the Animator plays it instead. Don Glaseon's sleeping copy
-- (workspace.DonGlaseonDormant) and the resting copies (WildboundBeastsLocal) play the idle loop. Changes nothing.
return function(Kit, Spec, TortClips, DonClips, tortPrefab, donPrefab, sources)
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
	local function near(actual, expected, tolerance, label)
		assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
			(label and label .. ": " or "") .. "expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(text, needle, label)
		assert(type(text) == "string" and string.find(text, needle, 1, true), (label or "source") .. " lacks " .. needle)
	end
	local function lacks(text, needle, label)
		assert(type(text) == "string" and not string.find(text, needle, 1, true), (label or "source") .. " still has " .. needle)
	end

	-- The phase maps of the old WildboundCandyTortidragonAnim / WildboundCandyDonGlaseonAnim clients (plus Stagger).
	local TORTI = { Spawn = "Idle", Calm = "Idle", Notice = "Alert", Chase = "Run_Quadruped", GiveUp = "Walk_Quadruped",
		Disengage = "Walk_Quadruped", Telegraph = "Attack_Telegraph", Release = "Attack_Release", Recover = "Attack_Recover" }
	local DON = { Spawn = "Idle_Breath", Dormant = "Idle_Breath", Patrol = "Patrol_Walk", Suspicious = "Notice",
		Roar = "Roar_Visual", Chase = "Chase_Run", Search = "Search", Telegraph = "Attack_Telegraph_Licorice",
		Attack = "Attack_Release_Licorice", Recover = "Attack_Recover_Licorice", LoseTarget = "LoseTarget",
		Return = "Patrol_Walk", Disengage = "Patrol_Walk", Stagger = "HitReact_ImmuneBat" }
	local BIG = {
		{ name = "Tortidragon", clips = TortClips, prefab = tortPrefab, idle = "Idle", map = TORTI },
		{ name = "DonGlaseon", clips = DonClips, prefab = donPrefab, idle = "Idle_Breath", map = DON },
	}

	case("A3-1: Kit.fromLegacy turns { time, pose } keys into the kit format without touching the source", function()
		assert(type(Kit.fromLegacy) == "function", "Kit.fromLegacy is missing")
		local legacy = { ORDER = { "Bob", "Snap" }, IDS = {}, CLIPS = {
			Bob = { length = 2, loop = true, priority = Enum.AnimationPriority.Idle, keys = {
				{ 0, {} }, { 1, { Pelvis = { 0, 0.5, 0, 0, 0, 0 } } }, { 2, {} } } },
			Snap = { length = 1, loop = false, priority = Enum.AnimationPriority.Action, markers = { { 0, "HitFrame" } }, keys = {
				{ 0, { Head = { 0, 0, 0, 10 } } }, { 0.5, { Head = { 0, 0, 0, 30 } } } } },
		} }
		local clips = Kit.fromLegacy(legacy)
		equal(clips.ORDER[2], "Snap", "order")
		local bob, snap = clips.CLIPS.Bob, clips.CLIPS.Snap
		equal(bob.length, 2, "length")
		equal(bob.loop, true, "loop")
		equal(bob.priority, "Idle", "priority name")
		equal(snap.priority, "Action", "priority name")
		equal(#bob.keys, 3, "keys")
		equal(bob.keys[2].t, 1, "key time")
		equal(bob.keys[2].pose, legacy.CLIPS.Bob.keys[2][2], "pose table shared, not copied")
		near(Kit.sample(bob, 1).Pelvis[2], 0.5, 1e-9, "sample at the key")
		near(Kit.sample(bob, 0.5).Pelvis[2], 0.25, 1e-9, "cubic in-out halfway (the legacy Pose easing)")
		near(Kit.sample(snap, 3).Head[4], 30, 1e-9, "a one-shot holds its last key")
		equal(type(legacy.CLIPS.Bob.keys[1][1]), "number", "the source keeps its { time, pose } keys")
		equal(legacy.CLIPS.Bob.priority, Enum.AnimationPriority.Idle, "the source keeps its Enum priority")
		-- Don Glaseon walk: a legacy clip may ask for Linear keys (many keys, no stop at each one)
		local linear = Kit.fromLegacy({ ORDER = { "Step" }, CLIPS = { Step = { length = 1, loop = true, easing = "Linear",
			priority = Enum.AnimationPriority.Movement, keys = { { 0, {} }, { 1, { Thigh_L = { 0, 0, 0, 20 } } } } } } })
		equal(linear.CLIPS.Step.easing, "Linear", "easing carried")
		near(Kit.sample(linear.CLIPS.Step, 0.25).Thigh_L[4], 5, 1e-9, "linear a quarter of the way")
	end)

	case("A3-2: the real clip data converts; every clip samples to the legacy pose at each key", function()
		for _, big in ipairs(BIG) do
			local clips = Kit.fromLegacy(big.clips)
			equal(#clips.ORDER, #big.clips.ORDER, big.name .. " order")
			for _, name in ipairs(big.clips.ORDER) do
				local legacy, clip = big.clips.CLIPS[name], clips.CLIPS[name]
				assert(clip, big.name .. ": " .. name .. " missing after conversion")
				equal(clip.loop, legacy.loop, big.name .. " " .. name .. " loop")
				equal(#clip.keys, #legacy.keys, big.name .. " " .. name .. " keys")
				local key = legacy.keys[math.min(2, #legacy.keys)]
				local at = Kit.sample(clip, key[1])
				for bone, v in pairs(key[2]) do
					for i = 1, 6 do
						near(at[bone] and at[bone][i] or 0, v[i] or 0, 1e-6, big.name .. " " .. name .. " " .. bone .. "[" .. i .. "]")
					end
				end
			end
		end
	end)

	case("A3-3: every bone the data poses is a bone under the prefab's PrimaryPart (the live path reaches it)", function()
		for _, big in ipairs(BIG) do
			assert(big.prefab and big.prefab.PrimaryPart, big.name .. " prefab with a PrimaryPart")
			local bones = {}
			for _, d in ipairs(big.prefab.PrimaryPart:GetDescendants()) do
				if d:IsA("Bone") then bones[d.Name] = true end
			end
			for name, clip in pairs(big.clips.CLIPS) do
				for _, key in ipairs(clip.keys) do
					for bone in pairs(key[2]) do assert(bones[bone], big.name .. " " .. name .. ": no bone " .. bone) end
				end
			end
		end
	end)

	case("A3-4: the spec plays both from converted data, with the old clients' phase maps", function()
		for _, big in ipairs(BIG) do
			local spec = Spec.SPEC[big.name]
			assert(spec, "no spec for " .. big.name)
			equal(spec.legacy, true, big.name .. " is legacy data")
			equal(spec.idle, big.idle, big.name .. " idle")
			local clips = Kit.fromLegacy(big.clips).CLIPS
			equal(clips[spec.idle].loop, true, big.name .. " idle loops")
			for _, extra in ipairs(spec.extras) do assert(clips[extra], big.name .. ": extra " .. extra) end
			for phase, clip in pairs(spec.phase) do assert(clips[clip], big.name .. ": phase " .. phase .. " -> missing " .. clip) end
			for phase, clip in pairs(big.map) do equal(Spec.clipFor(big.name, phase, clips), clip, big.name .. " " .. phase) end
			equal(Spec.clipFor(big.name, "NoSuchPhase", clips), big.idle, big.name .. " unknown phase")
		end
		local probe = Instance.new("Model")
		local ok, problem = pcall(function()
			probe.Name = "DonGlaseonDormant"
			equal(Spec.critterName(probe), "DonGlaseon", "the sleeping copy is Don Glaseon")
			equal(Spec.SCENERY.DonGlaseonDormant, "DonGlaseon", "scenery table")
			probe.Name = "Tortidragon"
			equal(Spec.critterName(probe), "Tortidragon", "Tortidragon by name (live view or resting copy)")
			probe.Name = "Gomibu"
			equal(Spec.critterName(probe), nil, "Gomibu keeps its own published-clip player")
			probe.Name = "Flanfuria"
			equal(Spec.critterName(probe), nil, "Flanfuria keeps its own published-clip player")
		end)
		probe:Destroy()
		assert(ok, problem)
	end)

	case("A3-5: the services copy the clip data to ReplicatedStorage and still set Clip_ only for published ids", function()
		for key, pair in pairs({ tortService = "Tortidragon", donService = "DonGlaseon" }) do
			local text = sources[key]
			has(text, '"WildboundCandyCritterClips' .. pair .. '"', key .. " (replicated copy name)")
			has(text, "Clips.IDS[name]", key .. " (Clip_ only for published ids)")
			has(text, ".Parent = ReplicatedStorage", key .. " (the copy goes to ReplicatedStorage)")
		end
	end)

	case("A3-6: the shared client converts legacy data, animates the sleeping copy and waits for streamed bones", function()
		local anim = sources.anim
		has(anim, "Kit.fromLegacy(", "client (conversion)")
		has(anim, "Spec.SCENERY[", "client (the sleeping copy in Workspace)")
		lacks(anim, "for _ = 1, 20 do", "client (a streamed model must not be given up after 10 s)")
		has(anim, "Spec.publishedId(", "client (a published id still wins)")
	end)

	case("A3-7: the old clients keep only their effects: no second animator on the same bones", function()
		local tort, don = sources.tortAnim, sources.donAnim
		has(tort, "local function volley(", "Tortidragon client (the candies)")
		has(don, "local function ribbon(", "Don Glaseon client (the licorice)")
		for label, text in pairs({ tortAnim = tort, donAnim = don }) do
			lacks(text, ":LoadAnimation(", label)
			lacks(text, ".Transform =", label)
		end
		lacks(don, "local function breathe(", "donAnim (the breath is the Idle_Breath clip now)")
	end)

	return result
end
