-- =============================================================================
-- Elite Mob Visuals: nameplate adapters
-- Where on a nameplate the visuals go, for whichever addon draws the plates.
-- Most draw inside Blizzard's nameplate frame, so that frame (or the health
-- bar inside it) is enough. EllesmereUI Nameplates needs its own adapter.
--
-- Plates.Resolve(nameplate, unit, out) fills `out` and returns it:
--   host    the frame the visuals are parented to; they take its scale and fade
--   bar     its health bar, or nil when none is found
--   top     the frame the overhead marker sits above (the name, when it is
--           above the bar)
--   strata, level  an explicit draw order, or nil to draw just above the
--           anchor at the host's own strata
--   addon   the adapter's name ("EllesmereUI"), or nil
-- =============================================================================
local _, ns = ...
local Readable = ns.Readable

local Plates = {}
ns.Plates = Plates

local function IsUsable(f)
    if type(f) ~= "table" or type(f.IsVisible) ~= "function" then return false end
    local ok, forbidden = pcall(f.IsForbidden, f)
    if ok and forbidden then return false end
    local ok2, visible = pcall(f.IsVisible, f)
    return ok2 and Readable(visible) == true
end
-- Shown, not forbidden, and readable as such (used for target frames too).
Plates.IsUsable = IsUsable

-- ---------------------------------------------------------------------------
-- EllesmereUI Nameplates
--
-- Why it is different (EllesmereUINameplates 9.8.x):
--  * It sizes Blizzard's nameplate frame to its health bar
--    (C_NamePlate.SetNamePlateSize), so that frame's top is the bar's top,
--    which is where it draws the mob's name. A marker "above the plate" lands
--    on the name.
--  * It hides Blizzard's UnitFrame (alpha 0, children parked on a hidden
--    frame) and draws its own plate, a child of the nameplate centred on it
--    and shifted by its own Y offset setting.
--  * That plate flattens its render layers (SetFlattensRenderLayers) and lifts
--    its text (level 900), auras (800) and indicators to MEDIUM strata. Anything
--    left at the nameplate's strata draws under all of them.
--  * It scales its own plate (Target Scale, cast scale, minor enemies) and
--    fades it (non-target and out-of-combat opacity).
--
-- So the visuals parent to EllesmereUI's plate (they scale and fade with it),
-- anchor to its health bar and name, and draw at MEDIUM strata between its
-- auras and its text. Its plates are found through the namespace it exposes,
-- _G.EllesmereNameplates_NS.plates[unit].
-- ---------------------------------------------------------------------------

local EUI_STRATA, EUI_LEVEL = "MEDIUM", 850

local function EllesmerePlate(nameplate, unit)
    local ens = rawget(_G, "EllesmereNameplates_NS")
    local plates = type(ens) == "table" and rawget(ens, "plates")
    local plate = type(plates) == "table" and unit and plates[unit]
    if type(plate) == "table" and plate.nameplate == nameplate and IsUsable(plate.health) then
        return plate
    end
end

-- The name sits above the bar by default, but EllesmereUI can move it into a
-- text slot on the bar; then the marker goes above the bar instead.
local function NameAboveBar(name, bar)
    if type(name) ~= "table" or not IsUsable(name) then return false end
    local ok1, bottom = pcall(name.GetBottom, name)
    local ok2, top = pcall(bar.GetTop, bar)
    bottom, top = ok1 and Readable(bottom), ok2 and Readable(top)
    if type(bottom) == "number" and type(top) == "number" then
        return bottom >= top - 1
    end
    return true   -- positions unreadable: assume EllesmereUI's default layout
end

-- Whether EllesmereUI Nameplates is running (for the options window's note).
function Plates.EllesmereLoaded()
    return type(rawget(_G, "EllesmereNameplates_NS")) == "table"
end

-- ---------------------------------------------------------------------------
-- Everything else: Blizzard's plates and addons that draw inside its frame.
-- Known health bars: Blizzard, Plater, ElvUI, KuiNameplates.
-- ---------------------------------------------------------------------------

local function FindHealthBar(nameplate)
    local uf, pf, kui = nameplate.UnitFrame, nameplate.unitFrame, nameplate.kui
    local candidates = {
        uf and uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar,
        uf and uf.healthBar,
        pf and pf.healthBar,
        pf and pf.Health,
        kui and kui.HealthBar,
    }
    for i = 1, 5 do
        if IsUsable(candidates[i]) then return candidates[i] end
    end
end

function Plates.Resolve(nameplate, unit, out)
    local ok, eui = pcall(EllesmerePlate, nameplate, unit)
    if ok and eui then
        local bar = eui.health
        out.host, out.bar = eui, bar
        out.top = NameAboveBar(eui.name, bar) and eui.name or bar
        out.strata, out.level, out.addon = EUI_STRATA, EUI_LEVEL, "EllesmereUI"
        -- Its own Rare/Elite indicator: the same Blizzard icons, in its own
        -- slot. EllesmereUI only ever shows and hides this frame, so the
        -- visuals can fade it out on mobs they mark (hideNameplateIcons).
        out.ownIcon = type(eui.classFrame) == "table" and eui.classFrame or nil
        return out
    end

    local okBar, bar = pcall(FindHealthBar, nameplate)
    out.host, out.bar, out.top = nameplate, okBar and bar or nil, nameplate
    out.strata, out.level, out.addon, out.ownIcon = nil, nil, nil, nil
    return out
end
