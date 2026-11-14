-- Caramelo biome environment kit (odd/tasks/caramelo-bioma.md, T2). The meshes come from Blender
-- (caramelo/kit/build_candy_kit.py in the local repo), uploaded as one Model asset (ASSET_ID). An import arrives grey,
-- unanchored, colliding, with an arbitrary yaw and as a package, so Kit.assemble rebuilds each asset as a prefab from
-- SPEC: one colour per piece, anchored, upright on a pivot at its base centre, facing -Z, with simple collisions.
-- SPEC is the builder's candy_kit_spec.json, compacted: asset -> size {x, y, z in Blender axes, Z up} and pieces ->
-- { import object name, colour, collision plan, transparency, centre, size }. Blender to Roblox: X = -x, Y = z, Z = y.
-- No mesh ever collides: MeshPart.CollisionFidelity cannot be set from a script, so a colliding mesh would use the
-- precise decomposition. Plain invisible parts named Collision_* collide instead. Collision plans: "hull" gets an
-- upright cylinder around the piece, "box" its bounding block, "none" nothing, and "proxy" the hand-made parts in
-- PROXIES (arches you walk through, the hollow nest, the cake tiers, the bridge rails).
-- Rules: WildboundCandyKit_Test.
local HttpService = game:GetService("HttpService")

local Kit = {}
Kit.ASSET_ID = 139302047387424
Kit.LIBRARY_NAME = "CandyKit"
Kit.SPEC = HttpService:JSONDecode([==[{"TreeCotton_S":{"size":[7.5306,7.5476,10.0],"pieces":{"Trunk":["TreeCotton_S__Trunk","#B36A38","hull",0.0,[0.0149,0.0235,2.4587],[1.9382,1.7578,4.9174]],"CrownA":["TreeCotton_S__CrownA","#FF96BE","none",0.0,[-0.5275,0.4584,6.7849],[6.2028,6.1388,6.4301]],"CrownB":["TreeCotton_S__CrownB","#FFC3DC","none",0.0,[0.6902,-0.9771,6.0797],[6.423,6.0853,4.7822]]}},"TreeCotton_M":{"size":[7.9369,8.642,16.0],"pieces":{"Trunk":["TreeCotton_M__Trunk","#B36A38","hull",0.0,[0.0002,0.0524,3.726],[2.475,2.226,7.452]],"CrownA":["TreeCotton_M__CrownA","#FF96BE","none",0.0,[-0.011,0.7273,11.8875],[6.326,7.0124,8.225]],"CrownB":["TreeCotton_M__CrownB","#FFC3DC","none",0.0,[1.3447,-0.8797,10.3097],[6.8363,7.0576,8.0059]]}},"TreeCotton_L":{"size":[10.4201,10.6465,24.0],"pieces":{"Trunk":["TreeCotton_L__Trunk","#B36A38","hull",0.0,[-0.031,-0.0201,4.4642],[2.7431,2.4591,8.9284]],"CrownA":["TreeCotton_L__CrownA","#FF96BE","none",0.0,[-0.8409,0.904,17.0023],[8.9619,8.436,13.9954]],"CrownB":["TreeCotton_L__CrownB","#FFC3DC","none",0.0,[1.0106,-0.9353,13.2858],[8.1754,9.1785,11.907]]}},"TreeLollipop_Straight":{"size":[8.4,1.6,19.56],"pieces":{"StickA":["TreeLollipop_Straight__StickA","#FFF7EE","hull",0.0,[0.0272,0.0,5.0],[1.0455,1.0724,10.0]],"StickB":["TreeLollipop_Straight__StickB","#F45A99","hull",0.0,[0.0272,0.0,7.0],[1.0455,1.0724,10.0]],"DiscA":["TreeLollipop_Straight__DiscA","#F45A99","none",0.0,[0.0,0.0,15.36],[8.4,1.1,8.4]],"DiscB":["TreeLollipop_Straight__DiscB","#FFF7EE","none",0.0,[0.0,0.0,15.36],[8.4,1.1,8.4]],"Hub":["TreeLollipop_Straight__Hub","#D83485","none",0.0,[0.0,0.0,15.36],[1.9,1.6,1.9]]}},"TreeLollipop_Tilted":{"size":[7.4727,1.6,16.4858],"pieces":{"StickA":["TreeLollipop_Tilted__StickA","#FFF7EE","hull",0.0,[0.8929,0.0,4.1243],[2.7553,1.0724,8.2486]],"StickB":["TreeLollipop_Tilted__StickB","#F45A99","hull",0.0,[1.2395,0.0,5.6946],[2.7553,1.0724,8.3686]],"DiscA":["TreeLollipop_Tilted__DiscA","#F45A99","none",0.0,[2.7112,0.0,12.7494],[7.4727,1.1,7.4727]],"DiscB":["TreeLollipop_Tilted__DiscB","#FFF7EE","none",0.0,[2.7112,0.0,12.7494],[7.4339,1.1,7.4339]],"Hub":["TreeLollipop_Tilted__Hub","#D83485","none",0.0,[2.7112,0.0,12.7494],[1.8585,1.6,1.8585]]}},"TreeCookie":{"size":[9.5212,9.2693,13.6544],"pieces":{"Trunk":["TreeCookie__Trunk","#D99A45","hull",0.0,[0.0479,0.0124,3.25],[3.0099,2.6736,6.5]],"Crown":["TreeCookie__Crown","#F8BF66","none",0.0,[-0.0974,-0.1446,9.7779],[9.087,9.042,7.7528]],"Chips":["TreeCookie__Chips","#5C3A2C","none",0.0,[-0.1514,0.1134,10.7466],[9.5212,8.9805,2.4683]]}},"TreeCream":{"size":[8.4,8.4,13.3517],"pieces":{"Trunk":["TreeCream__Trunk","#D99A45","hull",0.0,[0.0176,0.007,2.8],[2.7155,2.4475,5.6]],"Cream":["TreeCream__Cream","#FFF1C9","none",0.0,[0.0,0.0,8.591],[8.4,8.4,6.782]],"Cherry":["TreeCream__Cherry","#E0263C","none",0.0,[-0.0038,-0.0091,12.4263],[1.8688,1.9166,1.8506]]}},"RockSugar":{"size":[8.8494,6.8625,10.0],"pieces":{"Crystals":["RockSugar__Crystals","#FAD66E","hull",0.0,[-1.1366,-0.194,5.0],[6.3636,5.6469,10.0]],"CrystalsLight":["RockSugar__CrystalsLight","#FDE896","hull",0.0,[1.8847,-0.87,3.3],[5.2924,6.726,6.6]]}},"RockChocolate":{"size":[8.2322,6.4421,5.8019],"pieces":{"Rock":["RockChocolate__Rock","#5C3A2C","hull",0.0,[-0.0474,0.1122,2.901],[8.2322,6.4421,5.8019]]}},"DonutArch":{"size":[18.7061,4.606,14.966],"pieces":{"Dough":["DonutArch__Dough","#F8BF66","proxy",0.0,[0.0,0.0,7.35],[18.7061,3.7047,14.7]],"Icing":["DonutArch__Icing","#F45A99","none",0.0,[0.0,0.0,10.851],[18.6733,4.2234,8.2299]],"Sprinkles":["DonutArch__Sprinkles","#FFF7EE","none",0.0,[-0.0634,0.0,10.6737],[13.5356,4.606,5.5179]]}},"ReturnPortal":{"size":[13.6,10.0,12.8],"pieces":{"ArchA":["ReturnPortal__ArchA","#FFF7EE","proxy",0.0,[0.0,0.0,6.4],[13.6,1.6,12.8]],"ArchB":["ReturnPortal__ArchB","#F45A99","proxy",0.0,[0.0,0.0,7.4],[13.6,1.6,10.8]],"ReturnRing":["ReturnPortal__ReturnRing","#58D6DC","none",0.0,[0.0,0.0,0.05],[10.0,10.0,0.1]]}},"CreamMushroom":{"size":[7.2041,7.6003,6.2446],"pieces":{"Stem":["CreamMushroom__Stem","#FFF1C9","hull",0.0,[0.0569,0.0,1.65],[2.1861,2.2423,3.3]],"Cap":["CreamMushroom__Cap","#FF96BE","none",0.0,[0.0761,-0.012,4.15],[7.2041,7.6003,2.3]],"Cream":["CreamMushroom__Cream","#FFF7EE","none",0.0,[0.0,0.0,5.3973],[4.6,4.5301,1.6946]]}},"GumdropBush_A":{"size":[3.1009,5.2366,2.5318],"pieces":{"DropsA":["GumdropBush_A__DropsA","#58D6DC","none",0.25,[-0.3007,-0.6298,1.2659],[2.9281,3.8591,2.5318]],"DropsB":["GumdropBush_A__DropsB","#FF96BE","none",0.25,[-0.9017,1.5506,1.0804],[2.0717,2.2534,2.1607]]}},"GumdropBush_B":{"size":[4.7167,5.252,2.4582],"pieces":{"DropsA":["GumdropBush_B__DropsA","#58D6DC","none",0.25,[-0.4176,-0.1464,1.2291],[4.5643,4.9515,2.4582]],"DropsB":["GumdropBush_B__DropsB","#FF96BE","none",0.25,[-0.4354,0.3677,1.2185],[4.7167,4.5243,2.4369]]}},"Nest":{"size":[7.4,7.4,2.4848],"pieces":{"Bowl":["Nest__Bowl","#F8BF66","proxy",0.0,[0.0,0.0,1.1],[5.4,5.1357,2.2]],"Wafers":["Nest__Wafers","#B36A38","none",0.0,[0.0,-0.0,1.2424],[5.8229,5.8229,2.4848]],"Support":["Nest__Support","#FFF7EE","none",0.0,[0.0,0.0,1.075],[2.1,2.1,0.35]],"RarityRing":["Nest__RarityRing","#58D6DC","none",0.0,[0.0,0.0,0.04],[7.4,7.4,0.08]]}},"ConfettiPile":{"size":[4.3356,3.9244,0.6458],"pieces":{"ConfettiA":["ConfettiPile__ConfettiA","#58D6DC","none",0.0,[-0.1272,0.8406,0.2327],[2.1481,2.6037,0.4654]],"ConfettiB":["ConfettiPile__ConfettiB","#FBE15E","none",0.0,[1.126,0.0962,0.225],[2.5599,2.1478,0.45]],"ConfettiC":["ConfettiPile__ConfettiC","#D83485","none",0.0,[-1.2517,-0.4689,0.3229],[1.3558,2.6262,0.6458]]}},"Ground_Pink":{"size":[20.0,20.0,0.4],"pieces":{"Ground":["Ground_Pink__Ground","#FFB1D1","box",0.0,[0.0,0.0,0.2],[20.0,20.0,0.4]]}},"Path_Icing":{"size":[14.0,20.1095,0.36],"pieces":{"Icing":["Path_Icing__Icing","#F45A99","box",0.0,[0.0,0.0,0.15],[14.0,20.0,0.3]],"Veins":["Path_Icing__Veins","#FFF7EE","none",0.0,[0.0765,0.0025,0.18],[10.8015,20.1095,0.36]]}},"Cookie_Tile":{"size":[14.0,12.0,0.86],"pieces":{"Slab":["Cookie_Tile__Slab","#F8BF66","box",0.0,[0.0,0.0,0.4],[14.0,12.0,0.8]],"Chips":["Cookie_Tile__Chips","#5C3A2C","none",0.0,[-0.6223,0.2597,0.78],[9.422,7.548,0.16]]}},"CookieBridge":{"size":[14.0,12.0,3.55],"pieces":{"Slab":["CookieBridge__Slab","#F8BF66","box",0.0,[0.0,0.0,0.5],[14.0,12.0,1.0]],"Chips":["CookieBridge__Chips","#5C3A2C","none",0.0,[-0.6223,0.2597,0.98],[9.422,7.548,0.16]],"Rails":["CookieBridge__Rails","#D99A45","proxy",0.0,[0.0,0.0,2.275],[14.0,12.0,2.55]]}},"Syrup_Puddle":{"size":[11.9287,11.9899,0.24],"pieces":{"Syrup":["Syrup_Puddle__Syrup","#DE963C","none",0.15,[-0.5273,-0.0729,0.09],[11.9287,11.9899,0.18]],"Shine":["Syrup_Puddle__Shine","#F2BE6E","none",0.15,[-1.2037,0.5227,0.205],[5.5875,5.1855,0.07]]}},"CakeTower":{"size":[74.6,74.6,66.013],"pieces":{"TiersA":["CakeTower__TiersA","#F6968C","proxy",0.0,[0.0,0.0,23.0],[72.0,72.0,46.0]],"TiersB":["CakeTower__TiersB","#FF7F6E","proxy",0.0,[0.0,0.0,37.0],[55.7202,55.7202,38.0]],"Icing":["CakeTower__Icing","#FFF7EE","none",0.0,[0.0,0.0,33.685],[74.6,74.6,46.0301]],"Fruit":["CakeTower__Fruit","#E0263C","none",0.0,[4.7854,-0.0523,41.7152],[60.8447,61.7286,48.5955]],"Confetti":["CakeTower__Confetti","#FBE15E","none",0.0,[-0.1029,-0.0762,27.1924],[73.9143,70.9039,48.4036]]}}}]==])

-- Proxy collision per asset, in Roblox axes from the base centre: cylinders stand upright (size = diameter, height).
local function cylinder(name, diameter, height, x, y, z)
	return { name = name, shape = Enum.PartType.Cylinder, size = Vector3.new(height, diameter, diameter), at = Vector3.new(x, y + height / 2, z) }
end
local function block(name, sx, sy, sz, x, y, z)
	return { name = name, shape = Enum.PartType.Block, size = Vector3.new(sx, sy, sz), at = Vector3.new(x, y + sy / 2, z) }
end
Kit.PROXIES = {
	CakeTower = { cylinder("Tier1", 72, 18, 0, 0, 0), cylinder("Tier2", 56, 15, 0, 18, 0), cylinder("Tier3", 40, 13, 0, 33, 0),
		cylinder("Tier4", 24, 10, 0, 46, 0) },
	DonutArch = { block("PostLeft", 3.6, 9, 3.6, -7.5, 0, 0), block("PostRight", 3.6, 9, 3.6, 7.5, 0, 0) },
	ReturnPortal = { cylinder("PostLeft", 1.6, 6, -6, 0, 0), cylinder("PostRight", 1.6, 6, 6, 0, 0) },
	Nest = { cylinder("Bowl", 5.3, 2.2, 0, 0, 0) },
	CookieBridge = { block("RailLeft", 0.5, 2.6, 12, -6.75, 1, 0), block("RailRight", 0.5, 2.6, 12, 6.75, 1, 0) },
}

local function convert(c) return Vector3.new(-c[1], c[3], c[2]) end

-- Builds the prefab library from an imported kit model and parents it under the given parent. Returns the Folder.
function Kit.assemble(import, parent)
	assert(typeof(import) == "Instance" and typeof(parent) == "Instance", "import and parent must be Instances")
	assert(not parent:FindFirstChild(Kit.LIBRARY_NAME), Kit.LIBRARY_NAME .. " already exists")
	local library = Instance.new("Folder")
	library.Name = Kit.LIBRARY_NAME
	for assetName, asset in pairs(Kit.SPEC) do
		local model = Instance.new("Model")
		model.Name = assetName
		local frame
		for pieceName, piece in pairs(asset.pieces) do
			local source = import:FindFirstChild(piece[1])
			assert(source and source:IsA("MeshPart"), "the import has no mesh " .. piece[1])
			local part = source:Clone()
			part.Name = pieceName
			part.Color = Color3.fromHex(piece[2])
			part.Material = Enum.Material.SmoothPlastic
			part.Transparency = piece[4]
			part.Anchored = true
			part.CanTouch = false
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = piece[3] ~= "none"
			-- every piece shares the import's rotation, so any of them gives the asset's base frame
			frame = frame or part.CFrame * CFrame.new(-convert(piece[5]))
			part.Parent = model
		end
		local proxies = table.clone(Kit.PROXIES[assetName] or {})
		for pieceName, piece in pairs(asset.pieces) do
			local centre, size = convert(piece[5]), piece[6]
			if piece[3] == "hull" then
				local diameter = math.max(size[1], size[2])
				table.insert(proxies, { name = pieceName, shape = Enum.PartType.Cylinder, size = Vector3.new(size[3], diameter, diameter), at = centre })
			elseif piece[3] == "box" then
				table.insert(proxies, { name = pieceName, shape = Enum.PartType.Block, size = Vector3.new(size[1], size[3], size[2]), at = centre })
			end
		end
		for _, proxy in ipairs(proxies) do
			local part = Instance.new("Part")
			part.Name = "Collision_" .. proxy.name
			part.Shape = proxy.shape
			part.Size = proxy.size
			part.Transparency = 1
			part.Anchored = true
			part.CanTouch = false
			part.CastShadow = false
			part.CFrame = frame * CFrame.new(proxy.at) * (proxy.shape == Enum.PartType.Cylinder and CFrame.Angles(0, 0, math.rad(90)) or CFrame.new())
			part.Parent = model
		end
		model.WorldPivot = frame
		model:PivotTo(CFrame.new())
		model:SetAttribute("KitAsset", assetName)
		model:SetAttribute("AssetId", Kit.ASSET_ID)
		model.Parent = library
	end
	library.Parent = parent
	return library
end

-- A detached clone of a prefab, scaled about its base and pivoted to the given CFrame.
function Kit.place(library, name, cframe, scale)
	local prefab = library:FindFirstChild(name)
	assert(prefab and prefab:IsA("Model"), "no prefab named " .. tostring(name))
	local clone = prefab:Clone()
	if scale and scale ~= 1 then clone:ScaleTo(scale) end
	clone:PivotTo(cframe)
	return clone
end

return Kit
