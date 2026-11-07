-- Server-only switches. Clients cannot read or write this module, and no attribute is ever read back
-- to decide damage. "off" is shadow mode: every fair-strike gate runs and counts, nothing is harmed.
-- "private" is real only for a place listed below, and the list ships empty. Adding a place needs the
-- user's confirmed target and approval (docs/mechanics/wildbound-fair-strike.md, damageMode).
return table.freeze({
	damageMode = "off", -- "off" | "private"
	privateTestPlaceIds = table.freeze({}),
})
