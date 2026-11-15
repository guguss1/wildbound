-- Invoke with require(freshTestClone)(require(freshClipPublishClone), require(freshTortidragonClipsClone),
-- require(freshDonGlaseonClipsClone), ServerStorage.WildboundAssets.Tortidragon, ServerStorage.WildboundAssets.DonGlaseon,
-- { tortidragonService = WildboundCandyTortidragonService.Source, donGlaseonService = WildboundCandyDonGlaseonService.Source }).
-- CE0 (odd/tasks/wildbound-caramelo.md): the kit the owner uses to publish Tortidragon's and Don Glaseon's clips to the
-- group. Builds only into an unparented scratch folder; changes nothing.
return function(Publish, TortiClips, DonClips, tortiPrefab, donPrefab, sources)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function joined(list) return table.concat(list, ",") end

	case("pending lists the clips without a valid id, in ORDER", function()
		local fake = { ORDER = { "A", "B", "C", "D" }, IDS = { A = 123456789012, B = 0, D = 1.5 } }
		equal(joined(Publish.pending(fake)), "B,C,D", "fake")
		equal(joined(Publish.pending({ ORDER = { "A" } })), "A", "no IDS table")
		equal(#Publish.pending(TortiClips), #TortiClips.ORDER - (function()
			local n = 0
			for _, name in ipairs(TortiClips.ORDER) do if TortiClips.IDS[name] then n += 1 end end
			return n
		end)(), "Tortidragon")
	end)

	case("parseId reads what the owner copies and refuses the rest", function()
		equal(Publish.parseId(123456789012), 123456789012, "number")
		equal(Publish.parseId("  123456789012 "), 123456789012, "digits")
		equal(Publish.parseId("rbxassetid://987654321"), 987654321, "content id")
		equal(Publish.parseId("https://create.roblox.com/store/asset/111222333444/Tortidragon_Idle"), 111222333444, "store link")
		equal(Publish.parseId("https://www.roblox.com/library/555666777/Name"), 555666777, "library link")
		equal(Publish.parseId("https://create.roblox.com/dashboard/creations/store/888999000111/configure"), 888999000111, "dashboard link")
		for _, bad in ipairs({ 0, -5, 1.5, "", "abc", "12a", "https://example.com/asset/123/", true }) do
			equal(Publish.parseId(bad), nil, "bad " .. tostring(bad))
		end
	end)

	case("idsSource writes the paste line in ORDER and refuses typos", function()
		local line = Publish.idsSource(TortiClips, { HatchReact = "rbxassetid://222", Idle = 111 })
		equal(line, "Clips.IDS = { Idle = 111, HatchReact = 222 }", "line")
		assert(not pcall(Publish.idsSource, TortiClips, { Idel = 1 }), "an unknown clip must error")
		assert(not pcall(Publish.idsSource, TortiClips, { Idle = "nope" }), "a bad id must error")
	end)

	local scratch = Instance.new("Folder")
	local sets = { { name = "Tortidragon", Clips = TortiClips, prefab = tortiPrefab }, { name = "DonGlaseon", Clips = DonClips, prefab = donPrefab } }

	case("build parks one KeyframeSequence per clip, named as its key, with its keys, loop and priority", function()
		assert(tortiPrefab and donPrefab, "prefabs missing")
		local folder = Publish.build(scratch, sets)
		equal(folder.Name, "WildboundPublishClips", "folder")
		equal(folder.Parent, scratch, "parent")
		for _, set in ipairs(sets) do
			local creature = folder:FindFirstChild(set.name)
			assert(creature, "missing " .. set.name)
			equal(#creature:GetChildren(), 11, set.name .. " count")
			equal(#set.Clips.ORDER, 11, set.name .. " order")
			for _, name in ipairs(set.Clips.ORDER) do
				local sequence = creature:FindFirstChild(name)
				assert(sequence and sequence:IsA("KeyframeSequence"), set.name .. "." .. name .. " is not a KeyframeSequence")
				local clip = set.Clips.CLIPS[name]
				equal(#sequence:GetChildren(), #clip.keys, set.name .. "." .. name .. " keyframes")
				equal(sequence.Loop, clip.loop, set.name .. "." .. name .. " loop")
				equal(sequence.Priority, clip.priority, set.name .. "." .. name .. " priority")
			end
		end
	end)

	case("the README says why and how, in Spanish, and a rebuild never duplicates", function()
		local folder = Publish.build(scratch, sets)
		local readme = folder:FindFirstChild("README")
		assert(readme and readme:IsA("StringValue"), "README missing")
		for _, words in ipairs({ "Save to Roblox", "GRUPO", "Clips.IDS", "Tortidragon", "DonGlaseon", "Para que sirve", "11" }) do
			assert(string.find(readme.Value, words, 1, true), "README lacks " .. words)
		end
		local note = Instance.new("StringValue")
		note.Name = "OwnerNote"
		note.Parent = folder
		Publish.build(scratch, sets)
		equal(#scratch:GetChildren(), 1, "one publish folder")
		equal(#folder:GetChildren(), 4, "README + two creatures + the owner's note")
		equal(#folder.Tortidragon:GetChildren(), 11, "Tortidragon after rebuild")
		equal(#folder.DonGlaseon:GetChildren(), 11, "DonGlaseon after rebuild")
	end)

	case("a pasted id is all the services need: they set Clip_<name> from Clips.IDS", function()
		for key, text in pairs({ tortidragonService = sources.tortidragonService, donGlaseonService = sources.donGlaseonService }) do
			assert(type(text) == "string", key .. " source missing")
			assert(string.find(text, "for _, name in ipairs(Clips.ORDER) do", 1, true), key .. " does not walk Clips.ORDER")
			assert(string.find(text, 'if Clips.IDS[name] then model:SetAttribute("Clip_" .. name, Clips.animationId(name)) end', 1, true),
				key .. " does not set Clip_<name> from Clips.IDS")
		end
		local saved = TortiClips.IDS.Idle
		TortiClips.IDS.Idle = 123456789012
		local ok, message = pcall(function()
			equal(TortiClips.animationId("Idle"), "rbxassetid://123456789012", "content id")
			for _, name in ipairs(Publish.pending(TortiClips)) do assert(name ~= "Idle", "Idle still pending") end
		end)
		TortiClips.IDS.Idle = saved
		assert(ok, message)
	end)

	scratch:Destroy()
	return result
end
