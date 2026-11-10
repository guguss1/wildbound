-- Store ports for saved progress (Nest Heist Phase 3, NS1). Server only. This is the only module that names the
-- data store service. Port (docs/mechanics/wildbound-persistence.md section 8): update(key, transform) -> true, value,
-- info | false, errorKind; read(key) -> true, value, info | false, errorKind; budget() -> requests left or nil.
-- transform(current, info) returns the new value and its metadata, or nil to cancel. info holds updatedAt (seconds)
-- and metadata (the session lock lives there as LockId).
--
-- Store.open picks the port: "datastore" (the default) uses the real data store; in Studio, when the place has no
-- API access, it falls back to an in-memory store and says so (it never changes a game setting). "memory" always
-- uses memory; "off" saves nothing.
local HttpService = game:GetService("HttpService")

local Store = {}
Store.NAME = "WildboundPlayers_v1"
Store.PROBE_KEY = "WildboundProbe_access"

local function encode(value) return HttpService:JSONEncode(value) end
local function decode(bytes) return HttpService:JSONDecode(bytes) end
local function copyMeta(metadata)
	local out = {}
	for k, v in pairs(metadata or {}) do out[k] = v end
	return out
end

-- An error text -> the kind Persistence retries on. Access errors are not worth retrying, but are still failures.
function Store.errorKind(message)
	local text = string.lower(tostring(message))
	if string.find(text, "api services", 1, true) or string.find(text, "publish", 1, true)
		or string.find(text, "403", 1, true) then
		return "NoAccess"
	end
	if string.find(text, "throttl", 1, true) or string.find(text, "queue", 1, true) then return "Throttled" end
	if string.find(text, "timeout", 1, true) or string.find(text, "timed out", 1, true) then return "Timeout" end
	return "Error"
end

local function userIdOf(key)
	local digits = string.match(tostring(key), "^Player_(%d+)$")
	return digits and tonumber(digits) or nil
end

-- The real port over one GlobalDataStore. `service` is DataStoreService (or a test double with the same calls).
function Store.roblox(service, name, requestType)
	local store = service:GetDataStore(name or Store.NAME)
	local port = { label = "datastore" }
	local function infoOf(keyInfo)
		if keyInfo == nil then return nil end
		-- DataStoreKeyInfo.UpdatedTime is milliseconds since the epoch (Roblox engine reference).
		return { updatedAt = keyInfo.UpdatedTime / 1000, metadata = copyMeta(keyInfo:GetMetadata()) }
	end
	function port:update(key, transform)
		local ok, value, keyInfo = pcall(function()
			return store:UpdateAsync(key, function(current, keyInfo)
				local nextValue, metadata = transform(current, infoOf(keyInfo) or { metadata = {} })
				if nextValue == nil then return nil end
				local userId = userIdOf(key)
				return nextValue, userId and { userId } or nil, copyMeta(metadata)
			end)
		end)
		if not ok then return false, Store.errorKind(value) end
		return true, value, infoOf(keyInfo)
	end
	function port:read(key)
		-- Read past the 4 s cache, so a check after a write sees that write.
		local hasOptions, options = pcall(function()
			local value = Instance.new("DataStoreGetOptions")
			value.UseCache = false
			return value
		end)
		local ok, value, keyInfo = pcall(function() return store:GetAsync(key, hasOptions and options or nil) end)
		if not ok then return false, Store.errorKind(value) end
		return true, value, infoOf(keyInfo)
	end
	function port:budget()
		local ok, left = pcall(function() return service:GetRequestBudgetForRequestType(requestType) end)
		return ok and left or nil
	end
	-- A harmless read of a key no player uses, to learn whether this place may call the service at all.
	function port:probe()
		local ok, failure = self:read(Store.PROBE_KEY)
		return ok, failure
	end
	return port
end

-- In-memory port with the same contract: values kept as JSON text, detached copies out, the store's own clock for
-- updatedAt. failNext(n, kind) makes the next n calls fail (Studio probes simulate a failed load with it).
function Store.memory(clock)
	clock = clock or os.time
	local port = { label = "memory", entries = {}, failing = 0, failKind = "Error", writes = 0 }
	function port:failNext(count, kind)
		self.failing = math.max(0, math.floor(tonumber(count) or 0))
		self.failKind = kind or "Error"
	end
	local function failed(self)
		if self.failing > 0 then
			self.failing -= 1
			return true
		end
		return false
	end
	function port:update(key, transform)
		if failed(self) then return false, self.failKind end
		local entry = self.entries[key]
		local current = entry and decode(entry.bytes) or nil
		local info = entry and { updatedAt = entry.updatedAt, metadata = copyMeta(entry.metadata) } or { metadata = {} }
		local value, metadata = transform(current, info)
		if value == nil then return true, current, info end
		local ok, bytes = pcall(encode, value)
		if not ok then return false, "Error" end
		self.entries[key] = { bytes = bytes, metadata = copyMeta(metadata), updatedAt = clock() }
		self.writes += 1
		return true, decode(bytes), { updatedAt = clock(), metadata = copyMeta(metadata) }
	end
	function port:read(key)
		if failed(self) then return false, self.failKind end
		local entry = self.entries[key]
		if not entry then return true, nil, nil end
		return true, decode(entry.bytes), { updatedAt = entry.updatedAt, metadata = copyMeta(entry.metadata) }
	end
	function port:budget() return nil end
	function port:probe() return true end
	-- Studio probes only: put a value and metadata straight in, as another server would have left it.
	function port:seed(key, value, metadata, updatedAt)
		self.entries[key] = { bytes = encode(value), metadata = copyMeta(metadata), updatedAt = updatedAt or clock() }
	end
	function port:raw(key)
		local entry = self.entries[key]
		return entry and entry.bytes or nil
	end
	return port
end

-- Picks the port for this server. env: { mode, service, isStudio, requestType, clock }. Returns port (or nil for
-- "off"), label, reason. Outside Studio the real port is used even if the probe fails: loads then fail and players
-- play unsaved, which never overwrites anything.
function Store.open(env)
	local mode = env.mode
	if mode == "off" then return nil, "off", "saving is off (WildboundFlags.persistenceMode)" end
	if mode == "memory" then return Store.memory(env.clock), "memory", "memory store chosen by the flag" end
	local ok, port = pcall(function()
		local service = env.service or game:GetService("DataStoreService")
		return Store.roblox(service, env.name, env.requestType or Enum.DataStoreRequestType.UpdateAsync)
	end)
	if not ok then
		if env.isStudio then
			return Store.memory(env.clock), "memory", "the data store could not be opened in Studio: " .. tostring(port)
		end
		return nil, "off", "the data store could not be opened: " .. tostring(port)
	end
	if env.isStudio then
		local probed, failure = port:probe()
		if not probed then
			return Store.memory(env.clock), "memory",
				"Studio has no data store access (" .. tostring(failure) .. "); progress lives in memory for this Play only"
		end
	end
	return port, "datastore", nil
end

return Store
