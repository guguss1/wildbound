# Horror map blockout

`tools/build-map.luau` creates a deterministic, static map in the currently open Studio place. It does not install scripts or import assets. `tools/validate-map.luau` checks structural bounds and samples route, spawn, and baseplate clearance. Visual inspection and a Play smoke test are still necessary; sampled checks do not prove continuous clearance or device performance.

## Studio procedure

1. Verify the Studio instance and place and obtain the user’s confirmation for the target session before editing. Save a local `.rbxl` backup of the place first; the recorded lighting baseline is not a full backup. Run the full generator source once in the confirmed place's Edit command context, not in Play. Do not run it again while `Workspace.HorrorMapBlockout` exists.
2. Run the full validator source in the same Edit context. Inspect the routes and each biome visually, then test in Play. Test mobile performance on a real device when available.
3. If generation fails partway through, the owned folder may be incomplete. Restore from the backup or use the rollback below before trying again.

## Rollback

Run this in the verified place's Edit command context. It restores only the Lighting properties changed by the generator, from the baseline recorded on the owned folder, then removes that folder. Existing Workspace objects and Lighting effects are not deleted; the existing Atmosphere density, offset, and haze are restored. Any intentional changes to those same Lighting properties made **after** generation will be overwritten; back them up first.

```lua
local HttpService = game:GetService("HttpService")
local lighting = game:GetService("Lighting")
local root = assert(workspace:FindFirstChild("HorrorMapBlockout"), "Map not found")
local b = HttpService:JSONDecode(assert(root:GetAttribute("LightingBaseline"), "Baseline missing"))
local atmospheres = {}
for _, child in ipairs(lighting:GetChildren()) do
    if child:IsA("Atmosphere") then table.insert(atmospheres, child) end
end
assert(#atmospheres == 1 and atmospheres[1].Name == b.AtmosphereName, "Original Atmosphere is ambiguous or missing")
local atmosphere = atmospheres[1]
atmosphere.Density, atmosphere.Offset, atmosphere.Haze = b.AtmosphereDensity, b.AtmosphereOffset, b.AtmosphereHaze
local function color(v) return Color3.new(v[1], v[2], v[3]) end
lighting.Ambient = color(b.Ambient)
lighting.OutdoorAmbient = color(b.OutdoorAmbient)
lighting.FogColor = color(b.FogColor)
lighting.FogStart, lighting.FogEnd = b.FogStart, b.FogEnd
lighting.Brightness, lighting.ClockTime = b.Brightness, b.ClockTime
lighting.ExposureCompensation = b.ExposureCompensation
root:Destroy()
```
