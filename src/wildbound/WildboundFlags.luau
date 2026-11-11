-- Server-only switches. Clients cannot read or write this module, and no attribute is ever read back
-- to decide damage. "off" is shadow mode: every fair-strike gate runs and counts, nothing is harmed.
-- "private" is real only for a place listed below. Delivery C (decision D-C4, H5): the user approved damage for
-- the unpublished test place 122652861404212 only, through the fair-strike gates. Publishing with this flag
-- needs its own, separate approval (docs/mechanics/wildbound-fair-strike.md, damageMode).
return table.freeze({
	damageMode = "private", -- "off" | "private"
	privateTestPlaceIds = table.freeze({ 122652861404212 }),
	-- D-C4: the dwell gate's radius. A game script cannot read Workspace.StreamingMinRadius, so it is configured here
	-- and must equal the place's value (the fair-strike contract compares them in Studio). Streaming stays on.
	streamingMinRadius = 64,
	-- W16 analytics seam: "off" builds a no-op. "record" keeps events in server memory for tests and Play checks.
	-- There is no live sink; no mode calls any Roblox analytics service (docs/testing/wildbound-analytics.md).
	analyticsMode = "off", -- "off" | "record"
	-- Nest Heist Phase 3 (NS1, user approval 2026-11-10): saved progress. "datastore" uses the real data store (in
	-- Studio without API access it falls back to memory and says so); "memory" keeps saves for one server only;
	-- "off" is the old session-only game. WildboundSave and WildboundStoreRoblox read it.
	persistenceMode = "datastore", -- "datastore" | "memory" | "off"
})
