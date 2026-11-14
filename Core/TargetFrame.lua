-- =============================================================================
-- Elite Mob Visuals: the badge on the target unit frame
-- The same badge, on the target frame at the top of the screen. The
-- Visibility tab decides when: targetFrame.enabled shows it always;
-- targetFrame.fallback (the default) only while the badge isn't showing on
-- the target's nameplate (nameplate badge off, nameplates off, out of range),
-- so it never doubles up.
--
-- It attaches to whichever target frame is in use: EllesmereUI's, ElvUI's,
-- Shadowed Unit Frames' or Blizzard's (EllesmereUI parks Blizzard's on a
-- hidden parent, so that one never wins there). With none found, or with the
-- free position chosen, it sits at a spot the player drags while the options
-- window is open.
--
-- Unit frames are secure (SecureUnitButtonTemplate), so the badge is never
-- parented to one: it lives on its own frame under UIParent and is only
-- anchored to the unit frame, drawn just above it.
-- =============================================================================
local _, ns = ...
local L = ns.L
local Readable, Classify, Visuals = ns.Readable, ns.Classify, ns.Visuals

local TF = {}
ns.TargetFrame = TF

-- Target frames by global name; the first in use wins.
TF.CANDIDATES = {
    "EllesmereUIUnitFrames_Target",   -- EllesmereUI Unit Frames
    "ElvUF_Target",                   -- ElvUI
    "SUFUnittarget",                  -- Shadowed Unit Frames
    "TargetFrame",                    -- Blizzard
}

local function Call(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return nil end
    local ok, v = pcall(obj[method], obj, ...)
    return ok and Readable(v) or nil
end

local IsUsable = ns.Plates.IsUsable

-- In use: its parent is shown and not faded out. Secure unit frames show
-- themselves a moment after the target changes (their unit watch), so a frame
-- can be in use while still hidden; a shown one wins, else the first in use.
local function InUse(f)
    if type(f) ~= "table" then return false end
    local parent = Call(f, "GetParent")
    if not IsUsable(parent) then return false end
    local alpha = Call(parent, "GetEffectiveAlpha")
    return not (type(alpha) == "number" and alpha < 0.01)
end

function TF.FindFrame()
    local waiting, waitingName
    for _, name in ipairs(TF.CANDIDATES) do
        local f = rawget(_G, name)
        if InUse(f) then
            if IsUsable(f) then return f, name end
            if not waiting then waiting, waitingName = f, name end
        end
    end
    return waiting, waitingName
end

-- ---------------------------------------------------------------------------
-- Free position: a frame on UIParent, dragged while the options are open.
-- ---------------------------------------------------------------------------

local handle
local function Handle()
    if handle then return handle end
    handle = CreateFrame("Frame", "EliteMobVisualsTargetAnchor", UIParent)
    handle:SetSize(96, 36)
    handle:SetFrameStrata("MEDIUM")
    handle:SetClampedToScreen(true)
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    handle:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = nil
        local point, _, relPoint, x, y = self:GetPoint()
        local free = ns.db.profile.targetFrame.free
        free.point, free.relPoint, free.x, free.y = point, relPoint, x, y
    end)
    handle.bg = handle:CreateTexture(nil, "BACKGROUND")
    handle.bg:SetAllPoints()
    handle.bg:SetColorTexture(0.95, 0.74, 0.25, 0.22)
    handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    handle.label:SetPoint("CENTER")
    handle.label:SetText(L["Target badge"] .. "\n" .. L["drag to move"])
    handle:EnableMouse(false)
    handle.bg:Hide()
    handle.label:Hide()
    return handle
end

local function PlaceHandle()
    local h = Handle()
    if h.dragging then return h end
    local free = ns.db.profile.targetFrame.free
    h:ClearAllPoints()
    h:SetPoint(free.point or "CENTER", UIParent, free.relPoint or free.point or "CENTER", free.x or 0, free.y or 0)
    return h
end

-- Show the drag box while the options window is open and the free position
-- is (or may be) in use.
function TF.RefreshHandle()
    if not ns.db then return end
    local t = ns.db.profile.targetFrame
    local p = ns.db.profile
    local unlocked = ns.Options.IsShown() and (ns.BadgeOnTargetFrame(p) or ns.MarkerOnTargetFrame(p))
        and (t.attach == "screen" or not TF.FindFrame())
    local h = PlaceHandle()
    h:EnableMouse(unlocked and true or false)
    h.bg:SetShown(unlocked and true or false)
    h.label:SetShown(unlocked and true or false)
end

-- ---------------------------------------------------------------------------
-- The badge (beside the frame) and the marker (above it)
-- ---------------------------------------------------------------------------

local holder = CreateFrame("Frame", nil, UIParent)
holder:SetSize(1, 1)
holder:SetPoint("CENTER")
local set = Visuals.Create(holder)

-- What showed last, for /emv debug.
TF.state = { shown = false, badge = false, marker = false, anchor = "-" }

function TF.Update()
    if not ns.db then return end
    local p = ns.db.profile
    local t = p.targetFrame
    TF.RefreshHandle()

    local tm = p.targetMarker
    local class = p.enabled and (ns.BadgeOnTargetFrame(p) or ns.MarkerOnTargetFrame(p)) and Classify.Get("target")
    local cdb = class and p.classes[class]
    local marked = cdb and cdb.show and Classify.Passes("target", p)
    -- Each shows always when ticked, else as the fallback: only while its
    -- nameplate counterpart isn't showing on the target.
    local showBadge = marked and (t.enabled or (t.fallback and not ns.TargetPlateBadgeShown())) and true or false
    local showMarker = marked and (tm.enabled or (tm.fallback and not ns.TargetPlateMarkerShown())) and true or false
    if not (showBadge or showMarker) then
        set:HideAll()
        TF.state.shown, TF.state.badge, TF.state.marker, TF.state.anchor = false, false, false, "-"
        return
    end

    local anchor, name
    if t.attach ~= "screen" then anchor, name = TF.FindFrame() end
    if not anchor then
        anchor, name = PlaceHandle(), "free position"
    end

    -- Follow the unit frame's scale, so the badge keeps its size beside it.
    local scale = 1
    if anchor ~= handle then
        local own, ui = Call(anchor, "GetEffectiveScale"), Call(UIParent, "GetEffectiveScale")
        if type(own) == "number" and type(ui) == "number" and ui > 0 and own > 0 then
            scale = own / ui
        end
    end
    holder:SetScale(scale)

    local place = set.place
    local strata, level = Call(anchor, "GetFrameStrata"), Call(anchor, "GetFrameLevel")
    place.host, place.badge, place.over = holder, anchor, anchor
    place.strata = type(strata) == "string" and strata or "MEDIUM"
    place.level = math.min((type(level) == "number" and level or 1) + 20, 9000)
    set:Update(class, place, showBadge, showMarker, p, t, tm)
    TF.state.shown, TF.state.badge, TF.state.marker, TF.state.anchor = true, showBadge, showMarker, name
end

-- The target's death (hide on dead mobs) arrives as a health update.
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function() TF.Update() end)
if events.RegisterUnitEvent then
    events:RegisterUnitEvent("UNIT_HEALTH", "target")
end
