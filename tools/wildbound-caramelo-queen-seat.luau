-- La Duquesa back on the Gran Torta's summit (V4-D10, owner request 2026-11-17 "the queen seated on top of the cake as
-- before"; the GT cake move left her scenery model over the old summit). Studio Edit mode only: run it once from the
-- command bar or execute_luau, first with DRY_RUN = true to read the plan, then with DRY_RUN = false. Not deployed: a
-- one-shot tool. The running game corrects the server copy by itself (WildboundCandyDuquesaService); this moves the edit
-- copy so the saved place agrees.
-- Needs, in ServerStorage, the V4 WildboundCandyDuquesa (seatPivot, offSeat), WildboundCandyFrutillon and
-- WildboundCandyLayout. Moves only Workspace.WildboundNewCandyPreview.DuquesaBurbuja (PivotTo; one undo step,
-- ChangeHistoryService recording "CaramelQueenSeat"); anything named SistemaSonriente is never touched. Returns (and
-- prints) a summary: the pivot before, the seat, and whether it moved ("already" when she sits there).
local DRY_RUN = true -- true: only report; false: move her

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Edit mode only: stop Play first")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function module(name)
	local found = ServerStorage:FindFirstChild(name)
	assert(found and found:IsA("ModuleScript"), "no ServerStorage." .. name)
	return require(found)
end
local Duq, Frut, Layout = module("WildboundCandyDuquesa"), module("WildboundCandyFrutillon"), module("WildboundCandyLayout")
assert(type(Duq.seatPivot) == "function" and type(Duq.offSeat) == "function", "deploy the V4 WildboundCandyDuquesa first")

local preview = workspace:FindFirstChild("WildboundNewCandyPreview")
local queen = preview and preview:FindFirstChild("DuquesaBurbuja")
assert(queen and queen:IsA("Model"), "no Workspace.WildboundNewCandyPreview.DuquesaBurbuja")
assert(queen:FindFirstAncestor("SistemaSonriente") == nil, "refused: inside SistemaSonriente")

local summit = Frut.summit(Layout)
local junction = { x = Layout.CENTRE.x + Layout.JUNCTION.x, z = Layout.CENTRE.z + Layout.JUNCTION.z }
local s = Duq.seatPivot(summit, junction)
local before = queen:GetPivot().Position
local summary = {
	before = { before.X, before.Y, before.Z },
	seat = { s.x, s.y, s.z, math.deg(s.yaw) },
	off = Duq.offSeat({ x = before.X, y = before.Y, z = before.Z }, summit),
	dryRun = DRY_RUN,
}
if not summary.off then
	summary.result = "already"
elseif DRY_RUN then
	summary.result = "would move"
else
	local recording = ChangeHistoryService:TryBeginRecording("CaramelQueenSeat")
	queen:PivotTo(CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.yaw, 0))
	if recording then ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
	local after = queen:GetPivot().Position
	summary.after = { after.X, after.Y, after.Z }
	summary.result = "moved"
end
print("CaramelQueenSeat " .. game:GetService("HttpService"):JSONEncode(summary))
return summary
