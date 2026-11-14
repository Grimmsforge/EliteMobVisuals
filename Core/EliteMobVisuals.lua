-- =============================================================================
-- Elite Mob Visuals: events, nameplate tracking and slash commands
-- Event driven, no OnUpdate: a plate is drawn when it appears, when the target
-- changes, when its unit's data changes, and when a setting changes. Each draw
-- is skipped when nothing about it changed (Visuals Set:Update).
-- =============================================================================
local ADDON_NAME, ns = ...
local L = ns.L
local Classify, Visuals, Readable = ns.Classify, ns.Visuals, ns.Readable

local GetNamePlateForUnit = C_NamePlate and C_NamePlate.GetNamePlateForUnit
local GetNamePlates = C_NamePlate and C_NamePlate.GetNamePlates
local UnitIsUnit = UnitIsUnit

local active = {}                                   -- unit token -> plate frame
local sets = setmetatable({}, { __mode = "k" })     -- plate frame -> visual set
local targetPlate

local function GetSet(plate)
    local s = sets[plate]
    if not s then
        s = Visuals.Create(plate)
        sets[plate] = s
    end
    return s
end

local function IsTarget(unit, plate)
    return (targetPlate ~= nil and plate == targetPlate)
        or Readable(UnitIsUnit(unit, "target")) == true
end

-- Whether the badge and the marker show on a plate. Test mode shows them on
-- every plate, whatever "Show on" says: its point is positioning on real
-- plates, and a target-only badge would mark just one of them.
local function Visibility(p, isTarget)
    local b, o = p.badge, p.overhead
    local testing = Classify.testClass ~= nil
    local showBadge = ns.BadgeOnNameplates(p) and (testing or b.scope == "all" or isTarget)
    local showOver = o.enabled and (testing or o.scope == "all"
        or (o.scope == "target" and isTarget)
        or (o.scope == "nontarget" and not isTarget))
    return showBadge, showOver
end

local function UpdateUnit(unit)
    local plate = active[unit]
    if not plate then return end
    local s = GetSet(plate)
    local p = ns.db.profile

    local class = p.enabled and Classify.Get(unit)
    local cdb = class and p.classes[class]
    if not (cdb and cdb.show and Classify.Passes(unit, p)) then
        s:HideAll()
        return
    end

    local showBadge, showOver = Visibility(p, IsTarget(unit, plate))
    if not (showBadge or showOver) then
        s:HideAll()
        return
    end
    s:Update(class, Visuals.Place(plate, unit, p, s.place), showBadge, showOver, p)
end

local function UpdateAll()
    for unit in pairs(active) do UpdateUnit(unit) end
end
ns.UpdateAll = UpdateAll

-- Whether the badge is showing on the target's nameplate right now. The
-- target frame badge, in its default mode, shows only when it isn't.
function ns.TargetPlateBadgeShown()
    local s = targetPlate and sets[targetPlate]
    local e = s and s.badge
    return e ~= nil and e:IsShown() and true or false
end

local function RefreshTarget()
    targetPlate = GetNamePlateForUnit and GetNamePlateForUnit("target") or nil
end

-- Plates already on screen (after a /reload), so nothing waits for a re-add.
local function SeedPlates()
    if not GetNamePlates then return end
    for _, plate in ipairs(GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then active[unit] = plate end
    end
end

-- ---------------------------------------------------------------------------
-- Public actions (slash commands and the options window)
-- ---------------------------------------------------------------------------

local function CountPlates()
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n
end

-- quiet: no chat (the options window re-applies test mode when the previewed
-- classification changes).
function ns.SetTestMode(on, class, quiet)
    local wasOn = Classify.testClass ~= nil
    if on then
        Classify.testClass = ns.IS_MARKED[class or ""] and class or Classify.testClass or "elite"
    else
        Classify.testClass = nil
    end
    ns.NotifySettingsChanged()
    ns.Options.RefreshControls()
    if quiet then return end

    if not on then
        if wasOn then ns.Print(L["Test mode off."]) end
        return
    end
    ns.Print(string.format(L["Test mode on: every nameplate is marked as %s. Type /emv test again to stop."],
        ns.CLASS_LABELS[Classify.testClass]))
    -- Say why nothing would show, rather than leave a silent test mode.
    local p = ns.db.profile
    if not p.enabled then
        ns.Print(L["The addon is turned off, so nothing shows. Type /emv on."])
    elseif not p.badge.enabled and not p.overhead.enabled and not ns.BadgeOnTargetFrame(p) then
        ns.Print(L["The nameplate badge, overhead marker and target frame badge are all turned off (Visibility tab), so there is nothing to show."])
    elseif not p.classes[Classify.testClass].show then
        ns.Print(string.format(L["%s is turned off in the Classifications tab, so nothing shows."],
            ns.CLASS_LABELS[Classify.testClass]))
    end
    if CountPlates() == 0 then
        ns.Print(L["No nameplates are on screen. Turn on enemy nameplates (V) or friendly ones (Shift+V); test mode marks friendly NPCs too."])
    end
end

function ns.SetEnabled(on)
    ns.db.profile.enabled = on
    ns.NotifySettingsChanged()
    ns.Options.RefreshControls()
end

function ns.SetMinimapShown(show)
    local db = ns.db.profile.minimap
    db.hide = not show
    if show then ns.MinimapButton:Show() else ns.MinimapButton:Hide() end
    ns.Options.RefreshControls()
end

function ns.ResetProfile()
    ns.db:ResetProfile()
    -- The reset rebuilds profile.minimap; point the button at the new table.
    local mb, minimap = ns.MinimapButton, ns.db.profile.minimap
    mb.db = minimap
    if mb.button then mb.button.db = minimap end
    if minimap.hide then mb:Hide() else mb:Show() end
    ns.NotifySettingsChanged()
    ns.Options.RefreshControls()
    ns.Print(L["Settings reset to their defaults."])
end

-- ---------------------------------------------------------------------------
-- Launcher: the minimap button, and the same launcher offered to broker
-- displays (Titan Panel, ChocolateBar, Bazooka, ...) when one is installed.
-- ---------------------------------------------------------------------------

local launcher = {
    type = "launcher",
    label = ns.TITLE,
    text = ns.TITLE,
    icon = ns.ICON,
    OnClick = function(_, button)
        if button == "RightButton" then
            ns.SetMinimapShown(false)
            ns.Print(L["Minimap button hidden. Type /emv minimap to show it again."])
        else
            ns.Options.Toggle()
        end
    end,
    OnTooltipShow = function(tooltip)
        local p = ns.db.profile
        tooltip:AddLine(ns.TITLE, 1, 0.82, 0.25)
        if not p.enabled then
            tooltip:AddLine(L["Turned off"], 1, 0.4, 0.4)
        elseif Classify.testClass then
            tooltip:AddLine(string.format(L["Test mode: marking every nameplate as %s"],
                ns.CLASS_LABELS[Classify.testClass]), 0.4, 0.8, 1)
        end
        tooltip:AddLine(L["Left-click: open the options"], 0.7, 0.7, 0.7)
        tooltip:AddLine(L["Right-click: hide this button"], 0.7, 0.7, 0.7)
    end,
}
ns.launcher = launcher

-- Broker displays find launchers through LibDataBroker-1.1. This addon does
-- not ship it, but when another addon has loaded it (any broker display has)
-- the launcher is registered there too. LDB takes over the table it is given,
-- so it gets a copy.
local function PublishLauncher()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB or LDB:GetDataObjectByName(ADDON_NAME) then return end
    local copy = {}
    for k, v in pairs(launcher) do copy[k] = v end
    LDB:NewDataObject(ADDON_NAME, copy)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

-- Unit events that can change whether, or how, a plate is marked. The name
-- update catches a mob whose classification arrives after its plate.
local UNIT_EVENTS = { "UNIT_CLASSIFICATION_CHANGED", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_FLAGS" }

function handlers.PLAYER_LOGIN()
    ns.db = ns.DB.New("EliteMobVisualsDB", ns.DEFAULTS)
    ns.MigrateProfile(ns.db.profile)
    ns.OnSettingsChanged(UpdateAll)
    -- After the plates: the target frame badge checks the target plate's badge.
    ns.OnSettingsChanged(ns.TargetFrame.Update)
    ns.Options.RegisterSettingsPage()
    ns.MinimapButton:Init(launcher, ns.db.profile.minimap, true)
    PublishLauncher()

    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _, event in ipairs(UNIT_EVENTS) do frame:RegisterEvent(event) end

    SeedPlates()
    RefreshTarget()
    UpdateAll()
end

function handlers.NAME_PLATE_UNIT_ADDED(unit)
    local plate = GetNamePlateForUnit(unit)
    if not plate then return end
    active[unit] = plate
    if not targetPlate then RefreshTarget() end
    UpdateUnit(unit)
    -- Nameplate addons that draw their own plate (EllesmereUI) attach it in
    -- their own handler for this event, which may run after this one, and
    -- finish its layout a frame later. Look again next frame; nothing redraws
    -- unless the host or anchors changed.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if active[unit] == plate then
                UpdateUnit(unit)
                if plate == targetPlate then ns.TargetFrame.Update() end
            end
        end)
    end
    -- The target's plate may just have come into range.
    if plate == targetPlate then ns.TargetFrame.Update() end
end

function handlers.NAME_PLATE_UNIT_REMOVED(unit)
    local plate = active[unit]
    active[unit] = nil
    if plate then
        if sets[plate] then sets[plate]:HideAll() end
        if plate == targetPlate then
            targetPlate = nil
            -- Out of nameplate range: the target frame badge takes over.
            ns.TargetFrame.Update()
        end
    end
end

function handlers.PLAYER_TARGET_CHANGED()
    RefreshTarget()
    UpdateAll()
    ns.TargetFrame.Update()
    -- Target unit frames show themselves a moment after the target changes
    -- (their unit watch, or their own handler for this event): look again.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, ns.TargetFrame.Update)
        C_Timer.After(0.3, ns.TargetFrame.Update)
    end
end

local function OnUnitEvent(unit)
    if not unit then return end
    if unit == "target" then
        ns.TargetFrame.Update()
    elseif active[unit] then
        UpdateUnit(unit)
        if active[unit] == targetPlate then ns.TargetFrame.Update() end
    end
end
for _, event in ipairs(UNIT_EVENTS) do handlers[event] = OnUnitEvent end

local function OnCombatChange()
    if ns.db.profile.combatOnly then
        UpdateAll()
        ns.TargetFrame.Update()
    end
end
handlers.PLAYER_REGEN_DISABLED = OnCombatChange
handlers.PLAYER_REGEN_ENABLED = OnCombatChange

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)
frame:RegisterEvent("PLAYER_LOGIN")

-- ---------------------------------------------------------------------------
-- /emv debug: what the addon sees, plate by plate, for bug reports.
-- Every read is guarded: this must never error, whatever the client returns.
-- ---------------------------------------------------------------------------

local function Safe(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return "-" end
    local ok, a, b = pcall(obj[method], obj, ...)
    if not ok then return "err" end
    a, b = Readable(a), Readable(b)
    if a == nil then return "secret/nil" end
    if type(a) == "number" then a = string.format("%.0f", a) end
    if type(b) == "number" then return a .. "x" .. string.format("%.0f", b) end
    return tostring(a)
end

-- A global API call (no self), shown the same way.
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return "-" end
    local ok, a = pcall(fn, ...)
    if not ok then return "err" end
    a = Readable(a)
    return a == nil and "secret/nil" or tostring(a)
end

local function Line(text) DEFAULT_CHAT_FRAME:AddMessage("|cffe8b23aEMV|r " .. text) end

function ns.Debug()
    local p = ns.db.profile
    local b, o = p.badge, p.overhead
    Line(string.format("v%s enabled=%s test=%s anchor=%s hostileOnly=%s combatOnly=%s",
        ns.VERSION, tostring(p.enabled), tostring(Classify.testClass), tostring(p.anchor),
        tostring(p.hostileOnly), tostring(p.combatOnly)))
    Line(string.format("nameplate badge on=%s showOn=%s style=%s size=%s  marker on=%s showOn=%s style=%s",
        tostring(b.enabled), b.scope, b.style, tostring(b.size), tostring(o.enabled), o.scope, o.style))
    local clientPlates = GetNamePlates and #(GetNamePlates() or {}) or -1
    Line(string.format("plates tracked=%d client=%d targetPlate=%s EllesmereUI=%s",
        CountPlates(), clientPlates, targetPlate and "yes" or "no", tostring(ns.Plates.EllesmereLoaded())))
    local t = p.targetFrame
    local _, frameName = ns.TargetFrame.FindFrame()
    Line(string.format("target frame on=%s fallback=%s attach=%s found=%s shown=%s at=%s target=%s marked=%s",
        tostring(t.enabled), tostring(t.fallback), t.attach, tostring(frameName), tostring(ns.TargetFrame.state.shown),
        tostring(ns.TargetFrame.state.anchor), SafeCall(UnitName, "target"), tostring(Classify.Get("target"))))

    local listed = 0
    for unit, plate in pairs(active) do
        if listed >= 6 then Line("(more plates not listed)") break end
        listed = listed + 1
        local class = p.enabled and Classify.Get(unit)
        local passes = class and Classify.Passes(unit, p)
        local isTarget = IsTarget(unit, plate)
        local showBadge, showOver = Visibility(p, isTarget)
        local s = sets[plate]
        local place = s and s.place
        Line(string.format("%s %s: raw=%s marked=%s passes=%s target=%s badge=%s marker=%s via=%s plate=%s",
            unit, SafeCall(UnitName, unit), SafeCall(UnitClassification, unit), tostring(class), tostring(passes),
            tostring(isTarget), tostring(showBadge), tostring(showOver),
            place and place.host and (place.addon or "blizzard") or "-",
            Safe(plate, "IsVisible")))
        for _, key in ipairs({ "badge", "badge2", "overhead" }) do
            local e = s and s[key]
            if e then
                Line(string.format("   %s shown=%s visible=%s alpha=%s size=%s strata=%s level=%s onHost=%s",
                    key, Safe(e, "IsShown"), Safe(e, "IsVisible"), Safe(e, "GetEffectiveAlpha"),
                    Safe(e, "GetSize"), Safe(e, "GetFrameStrata"), Safe(e, "GetFrameLevel"),
                    tostring(place and e:GetParent() == place.host)))
            end
        end
    end
    if listed == 0 then
        Line("no nameplates tracked: turn on enemy (V) or friendly (Shift+V) nameplates")
    end
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

local function Help()
    ns.Print(L["Commands:"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv  - " .. L["open the options"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv settings  - " .. L["open the page in the game's Settings"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv test [elite|rareelite|rare|worldboss]  - " .. L["toggle test mode"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv on | off  - " .. L["turn the addon on or off"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv minimap  - " .. L["show or hide the minimap button"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv debug  - " .. L["print what the addon sees on each nameplate"])
    DEFAULT_CHAT_FRAME:AddMessage("  /emv reset  - " .. L["back to the defaults"])
end

SLASH_ELITEMOBVISUALS1 = "/emv"
SLASH_ELITEMOBVISUALS2 = "/elitemobvisuals"
SlashCmdList.ELITEMOBVISUALS = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options.Toggle()
    elseif cmd == "test" then
        local on = (arg ~= "" and ns.IS_MARKED[arg]) and true or not Classify.testClass
        ns.SetTestMode(on, arg)
    elseif cmd == "debug" then
        ns.Debug()
    elseif cmd == "on" or cmd == "off" then
        ns.SetEnabled(cmd == "on")
        ns.Print(cmd == "on" and L["Enabled."] or L["Disabled."])
    elseif cmd == "toggle" then
        ns.SetEnabled(not ns.db.profile.enabled)
        ns.Print(ns.db.profile.enabled and L["Enabled."] or L["Disabled."])
    elseif cmd == "settings" then
        ns.Options.OpenSettingsPage()
    elseif cmd == "minimap" then
        local show = ns.db.profile.minimap.hide == true
        ns.SetMinimapShown(show)
        ns.Print(show and L["Minimap button shown."] or L["Minimap button hidden. Type /emv minimap to show it again."])
    elseif cmd == "reset" then
        ns.ResetProfile()
    else
        Help()
    end
end

-- ---------------------------------------------------------------------------
-- Addon compartment (the minimap's addon list), named in the TOC.
-- ---------------------------------------------------------------------------

function EliteMobVisuals_OnAddonCompartmentClick()
    ns.Options.Toggle()
end

function EliteMobVisuals_OnAddonCompartmentEnter(_, button)
    GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.TITLE, 1, 0.82, 0.25)
    GameTooltip:AddLine(L["Click to open the options."], 1, 1, 1)
    GameTooltip:Show()
end

function EliteMobVisuals_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

_G[ADDON_NAME] = ns   -- for /dump and other addons
