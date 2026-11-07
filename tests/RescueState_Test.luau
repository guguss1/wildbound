-- Contract tests for the session-only rescue state.
return function(t)
	local RescueState = require(game.ServerScriptService.RescueState)
	local expect = t.expect

	-- New players start with independent, empty collections.
	t.test("fresh player states are independent", function()
		local first = RescueState.new()
		local second = RescueState.new()
		first:capture("frog", true, 0)
		expect.equal(#second:snapshot().entries, 0)
		expect.equal(second:snapshot().walkSpeed, 16)
	end)

	-- A living player can capture at the exact range boundary.
	t.test("captures at ten studs", function()
		local state = RescueState.new()
		local accepted = state:capture("frog", true, 10)
		expect.truthy(accepted)
		expect.equal(state:snapshot().entries[1].status, "Pending")
		expect.equal(state:snapshot().pendingCount, 1)
	end)

	-- Captures beyond the range do not mutate the collection.
	t.test("rejects out of range capture", function()
		local state = RescueState.new()
		local accepted = state:capture("frog", true, 10.01)
		expect.falsy(accepted)
		expect.equal(#state:snapshot().entries, 0)
	end)

	-- Dead players cannot capture even in range.
	t.test("rejects capture while dead", function()
		local state = RescueState.new()
		local accepted = state:capture("frog", false, 0)
		expect.falsy(accepted)
		expect.equal(#state:snapshot().entries, 0)
	end)

	-- Missing, non-numeric, negative, NaN and infinite distances are invalid.
	t.test("rejects invalid capture distances", function()
		for _, distance in ipairs({-1, 0/0, math.huge, -math.huge, "near"}) do
			local state = RescueState.new()
			expect.falsy(state:capture("frog", true, distance))
			expect.equal(#state:snapshot().entries, 0)
		end
		local state = RescueState.new()
		expect.falsy(state:capture("frog", true, nil))
	end)

	-- IDs identify a creature and cannot be empty or missing.
	t.test("rejects invalid creature ids", function()
		local state = RescueState.new()
		expect.falsy(state:capture("", true, 0))
		expect.falsy(state:capture(nil, true, 0))
		expect.falsy(state:capture(123, true, 0))
		expect.equal(#state:snapshot().entries, 0)
	end)

	-- One player cannot capture an ID twice while it is pending.
	t.test("rejects duplicate pending captures", function()
		local state = RescueState.new()
		state:capture("frog", true, 0)
		expect.falsy(state:capture("frog", true, 0))
		expect.equal(state:snapshot().pendingCount, 1)
	end)

	-- Three pending creatures fill the backpack.
	t.test("rejects a fourth pending creature", function()
		local state = RescueState.new()
		state:capture("a", true, 0)
		state:capture("b", true, 0)
		state:capture("c", true, 0)
		expect.falsy(state:capture("d", true, 0))
		expect.equal(state:snapshot().pendingCount, 3)
	end)

	-- An alive player can deposit at the exact refuge boundary.
	t.test("deposits pending creatures at twelve studs", function()
		local state = RescueState.new()
		state:capture("frog", true, 0)
		local count = state:deposit(true, 12)
		local snapshot = state:snapshot()
		expect.equal(count, 1)
		expect.equal(snapshot.entries[1].status, "Rescued")
		expect.equal(snapshot.totalRescued, 1)
		expect.equal(snapshot.walkSpeed, 18)
	end)

	-- A deposit requires a living player and valid in-range distance.
	t.test("rejects unsafe deposit contexts", function()
		for _, distance in ipairs({12.01, -1, 0/0, math.huge, -math.huge, "near"}) do
			local state = RescueState.new()
			state:capture("frog", true, 0)
			expect.equal(state:deposit(true, distance), 0)
			expect.equal(state:snapshot().pendingCount, 1)
		end
		local state = RescueState.new()
		state:capture("frog", true, 0)
		expect.equal(state:deposit(false, 0), 0)
		expect.equal(state:deposit(true, nil), 0)
		expect.equal(state:snapshot().pendingCount, 1)
	end)

	-- Depositing frees bag capacity without deleting rescued entries.
	t.test("frees pending capacity and retains collection", function()
		local state = RescueState.new()
		state:capture("a", true, 0)
		state:capture("b", true, 0)
		state:capture("c", true, 0)
		state:deposit(true, 0)
		expect.truthy(state:capture("d", true, 0))
		local snapshot = state:snapshot()
		expect.equal(#snapshot.entries, 4)
		expect.equal(snapshot.pendingCount, 1)
		expect.equal(snapshot.totalRescued, 3)
	end)

	-- Rescued IDs cannot be captured or rewarded again.
	t.test("rejects duplicate rescued creatures", function()
		local state = RescueState.new()
		state:capture("frog", true, 0)
		state:deposit(true, 0)
		expect.falsy(state:capture("frog", true, 0))
		expect.equal(state:snapshot().totalRescued, 1)
	end)

	-- Empty and repeated deposits award nothing.
	t.test("empty and repeated deposits do not reward", function()
		local state = RescueState.new()
		expect.equal(state:deposit(true, 0), 0)
		state:capture("frog", true, 0)
		state:deposit(true, 0)
		expect.equal(state:deposit(true, 0), 0)
		expect.equal(state:snapshot().totalRescued, 1)
	end)

	-- Two rescues give speed 20 and additional rescues do not exceed it.
	t.test("caps movement speed after two rescues", function()
		local state = RescueState.new()
		state:capture("a", true, 0)
		state:capture("b", true, 0)
		state:capture("c", true, 0)
		expect.equal(state:deposit(true, 0), 3)
		expect.equal(state:snapshot().walkSpeed, 20)
	end)

	-- Snapshot mutations must not alter authoritative state.
	t.test("returns detached snapshots", function()
		local state = RescueState.new()
		state:capture("frog", true, 0)
		local snapshot = state:snapshot()
		snapshot.entries[1].status = "Rescued"
		table.clear(snapshot.entries)
		expect.equal(state:snapshot().entries[1].status, "Pending")
		expect.equal(state:snapshot().pendingCount, 1)
	end)
end
