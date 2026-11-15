-- Invoke with require(freshTestClone)(require(freshDonGlaseonClipsClone), ServerStorage.WildboundAssets:FindFirstChild("DonGlaseon")).
-- Caramelo biome (odd/tasks/wildbound-caramelo.md, CA3): Don Glaseon's eleven clips against the sheet (pack
-- 03_PERSONAJES/04_DON_GLASEON_BOSS.md, "Animaciones"): names, lengths, loops, markers, in place (no root motion),
-- only the prefab's bones, and real KeyframeSequences. Builds sequences in memory, parents nothing.
return function(Clips, prefab)
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
	local SHEET = { Idle_Breath = { 3.0, true }, Patrol_Walk = { 1.1, true }, Chase_Run = { 0.75, true }, Notice = { 0.8, false },
		Search = { 1.6, true }, Attack_Telegraph_Licorice = { 1.1, false }, Attack_Release_Licorice = { 0.35, false },
		Attack_Recover_Licorice = { 1.0, false }, HitReact_ImmuneBat = { 0.35, false }, LoseTarget = { 1.0, false }, Roar_Visual = { 1.5, false } }
	local bones = {}
	if prefab then for _, d in ipairs(prefab:GetDescendants()) do if d:IsA("Bone") then bones[d.Name] = true end end end
	local function pose(clip, t)
		for _, key in ipairs(clip.keys) do if math.abs(key[1] - t) < 1e-9 then return key[2] end end
		error("no key at " .. t, 0)
	end

	case("the sheet's eleven clips, in order, with their lengths and loops", function()
		equal(#Clips.ORDER, 11, "clips")
		for _, name in ipairs(Clips.ORDER) do
			local clip, sheet = Clips.CLIPS[name], SHEET[name]
			assert(clip and sheet, "not in the sheet: " .. name)
			assert(math.abs(clip.length - sheet[1]) < 1e-9, name .. " length " .. clip.length)
			equal(clip.loop, sheet[2], name .. " loop")
		end
	end)

	case("keys from 0 to the length, in order; loops end where they start", function()
		for _, name in ipairs(Clips.ORDER) do
			local clip = Clips.CLIPS[name]
			equal(clip.keys[1][1], 0, name .. " first key")
			assert(math.abs(clip.keys[#clip.keys][1] - clip.length) < 1e-9, name .. " last key")
			for i = 2, #clip.keys do assert(clip.keys[i][1] > clip.keys[i - 1][1], name .. " keys out of order") end
			if clip.loop then
				local a, b = clip.keys[1][2], clip.keys[#clip.keys][2]
				for bone, v in pairs(a) do for i = 1, 6 do assert(math.abs((v[i] or 0) - ((b[bone] or {})[i] or 0)) < 1e-9, name .. " loop seam at " .. bone) end end
			end
		end
	end)

	case("in place, on the prefab's bones only: Root never moves", function()
		assert(prefab, "no DonGlaseon prefab")
		for _, name in ipairs(Clips.ORDER) do
			for _, key in ipairs(Clips.CLIPS[name].keys) do
				for bone in pairs(key[2]) do
					assert(bones[bone], name .. " poses an unknown bone " .. bone)
					assert(bone ~= "Root", name .. " moves the Root")
				end
			end
		end
	end)

	case("the attack's markers: commit at the lock (0.6 s), the hit frame at the end of the lash, the end of the recovery", function()
		local t, r, c = Clips.CLIPS.Attack_Telegraph_Licorice, Clips.CLIPS.Attack_Release_Licorice, Clips.CLIPS.Attack_Recover_Licorice
		equal(t.markers[1][2], "TelegraphStart"); equal(t.markers[2][2], "AttackCommit"); equal(t.markers[2][1], 0.6, "commit")
		equal(r.markers[1][2], "HitFrame"); equal(r.markers[1][1], 0.35, "hit frame")
		equal(c.markers[2][2], "AttackEnd"); equal(c.markers[2][1], 1.0, "end")
	end)

	case("the tell reads: the right arm high, the jaw wide; the lash throws the arm and the licorice forward", function()
		local raised = pose(Clips.CLIPS.Attack_Telegraph_Licorice, 1.1)
		assert(raised.UpperArm_R[4] >= 120, "the arm is not raised in the tell")
		assert(raised.Jaw[4] <= -20, "the jaw is not open in the tell")
		local lash = pose(Clips.CLIPS.Attack_Release_Licorice, 0.35)
		assert(lash.UpperArm_R[4] >= 60 and lash.UpperArm_R[4] < raised.UpperArm_R[4], "the arm is not thrown forward")
		assert(lash.Licorice_01[4] > 0, "the licorice does not straighten")
		local walk = Clips.CLIPS.Patrol_Walk.keys
		assert(walk[1][2].Thigh_L[4] * walk[3][2].Thigh_L[4] < 0, "the legs do not alternate")
	end)

	case("Clips.build makes one KeyframeSequence per clip with a pose for every bone", function()
		assert(prefab, "no DonGlaseon prefab")
		for _, name in ipairs(Clips.ORDER) do
			local sequence = Clips.build(prefab, name)
			equal(sequence.ClassName, "KeyframeSequence"); equal(sequence.Loop, Clips.CLIPS[name].loop, name .. " loop")
			local frames = sequence:GetKeyframes()
			equal(#frames, #Clips.CLIPS[name].keys, name .. " keyframes")
			local count = 0
			for _, d in ipairs(frames[1]:GetDescendants()) do if d:IsA("Pose") and d.Name ~= "RootPart" then count += 1 end end
			equal(count, 29, name .. " poses")
			sequence:Destroy()
		end
	end)

	case("every clip is published (an Animation id the game can play)", function()
		for _, name in ipairs(Clips.ORDER) do
			assert(type(Clips.IDS[name]) == "number", "not published: " .. name)
			equal(Clips.animationId(name), "rbxassetid://" .. string.format("%d", Clips.IDS[name]))
		end
	end)

	return result
end
