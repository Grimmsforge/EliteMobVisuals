-- A small stand-in for the WoW client API: enough for Elite Mob Visuals to load,
-- run its events and build its options window in a plain Lua VM. Frames keep
-- the state the tests look at (shown, points, scripts, children); every other
-- method is a no-op.

local frames = {}
local eventFrames = {}

-- Fields the addon reads off third-party frames. On a mock frame they are nil
-- (as on a plain frame), not auto-generated methods.
local FIELDS = {
    UnitFrame = true, unitFrame = true, kui = true, namePlateUnitToken = true,
    HealthBarsContainer = true, healthBar = true, Health = true, HealthBar = true,
}

local noop = function() end
local Methods = {}

local function NewObject(kind, parent)
    local o = setmetatable({
        __kind = kind, __shown = true, __scripts = {}, __children = {}, __points = {},
        __parent = parent, __level = 1, __value = 0, __checked = false,
    }, { __index = function(t, k)
        if Methods[k] then return Methods[k] end
        if FIELDS[k] then return nil end
        if type(k) == "string" and k:match("^%u") then return noop end
        return nil
    end })
    if parent and parent.__children then table.insert(parent.__children, o) end
    return o
end

function Methods:Show() self.__shown = true end
function Methods:Hide()
    self.__shown = false
    local onHide = self.__scripts.OnHide
    if onHide then onHide(self) end
end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local f = self
    while f do
        if not f.__shown then return false end
        f = f.__parent
    end
    return true
end
function Methods:IsForbidden() return false end
function Methods:SetScript(name, fn) self.__scripts[name] = fn end
function Methods:GetScript(name) return self.__scripts[name] end
function Methods:HookScript(name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = function(...) if old then old(...) end fn(...) end
end
function Methods:RegisterEvent(event)
    eventFrames[event] = eventFrames[event] or {}
    table.insert(eventFrames[event], self)
end
function Methods:SetPoint(point, rel, relPoint, x, y)
    table.insert(self.__points, { point, rel, relPoint, x, y })
end
function Methods:ClearAllPoints() self.__points = {} end
function Methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Methods:SetParent(parent)
    local old = self.__parent
    if old and old.__children then
        for i, c in ipairs(old.__children) do
            if c == self then table.remove(old.__children, i) break end
        end
    end
    self.__parent = parent
    if parent and parent.__children then table.insert(parent.__children, self) end
end
function Methods:GetParent() return self.__parent end
function Methods:SetFrameStrata(s) self.__strata = s end
function Methods:GetFrameStrata() return self.__strata or "LOW" end
function Methods:SetFrameLevel(l) self.__level = l end
function Methods:GetFrameLevel() return self.__level end
function Methods:SetChecked(v) self.__checked = v and true or false end
function Methods:GetChecked() return self.__checked end
function Methods:SetValue(v) self.__value = v end
function Methods:GetValue() return self.__value end
function Methods:GetWidth() return 100 end
function Methods:GetHeight() return 100 end
function Methods:GetCenter() return 500, 400 end
function Methods:GetEffectiveScale() return 1 end
function Methods:SetTexCoord(...) self.__coords = { ... } end
function Methods:GetStringWidth() return 50 end
function Methods:IsPlaying() return self.__playing == true end
function Methods:Play() self.__playing = true end
function Methods:Stop() self.__playing = false end
function Methods:SetText(t) self.__text = t end
function Methods:GetText() return self.__text end
function Methods:SetTexture(t) self.__texture = t end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:CreateTexture() return NewObject("Texture", self) end
function Methods:CreateFontString() return NewObject("FontString", self) end
function Methods:CreateAnimationGroup() return NewObject("AnimationGroup", self) end
function Methods:CreateAnimation() return NewObject("Animation", self) end

function CreateFrame(kind, name, parent)
    local f = NewObject(kind, parent)
    table.insert(frames, f)
    if name then _G[name] = f end
    return f
end

UIParent = NewObject("Frame")
WorldFrame = NewObject("Frame")
Minimap = NewObject("Frame", UIParent)
__cursor = { 600, 400 }   -- straight east of the minimap's centre (500, 400)
function GetCursorPosition() return __cursor[1], __cursor[2] end
function IsLoggedIn() return true end

-- LibStub with LibDataBroker-1.1, as another addon would have loaded them.
__ldb = { objects = {} }
function __ldb:NewDataObject(name, obj) self.objects[name] = obj return obj end
function __ldb:GetDataObjectByName(name) return self.objects[name] end
LibStub = setmetatable({}, { __call = function(_, name) if name == "LibDataBroker-1.1" then return __ldb end end })
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(__chat, msg) end }
__chat = {}
GameTooltip = NewObject("GameTooltip", UIParent)
ColorPickerFrame = NewObject("Frame", UIParent)
SettingsPanel = NewObject("Frame", UIParent)
SettingsPanel.__shown = false
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
YES, NO = "Yes", "No"
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
function StaticPopup_Show(which) __lastPopup = which end
function HideUIPanel(f) f:Hide() end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetLocale() return "enUS" end
function InCombatLockdown() return false end
function GetRealmName() return "Test Realm" end
function GetFileIDFromPath() return 1 end
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- Timers wait until the test runs them, like the next frame.
__timers = {}
C_Timer = { After = function(_, fn) table.insert(__timers, fn) end }
function __RunTimers()
    local due = __timers
    __timers = {}
    for _, fn in ipairs(due) do fn() end
end

C_AddOns = { GetAddOnMetadata = function(_, field) if field == "Version" then return "0.0.0-test" end end }

-- Atlases the client has. The test removes one to check the fallback.
__atlases = {
    ["nameplates-icon-elite-gold"] = true, ["nameplates-icon-elite-silver"] = true,
    ["nameplates-icon-rareelite"] = true, ["VignetteKillElite"] = true, ["VignetteKill"] = true,
    ["UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"] = true,
    ["UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged"] = true,
}
C_Texture = {
    GetAtlasInfo = function(name)
        if not __atlases[name] then return nil end
        return { file = 12345, width = 64, height = 32, leftTexCoord = 0.1, rightTexCoord = 0.5, topTexCoord = 0, bottomTexCoord = 0.25 }
    end,
}

Settings = {
    RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name, GetID = function() return 1 end } end,
    RegisterAddOnCategory = function(cat) __settingsCategory = cat end,
    OpenToCategory = function(id) __openedCategory = id end,
}

-- Units: the test fills __units[token] = { class=, attackable=, dead=, player=, secret= }.
__units = {}
__target = nil
__inCombat = false
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(v) return v == SECRET end

-- "target" reads the targeted unit (__target holds its token; a token with no
-- plate is a target whose nameplate isn't shown).
local function U(unit)
    if unit == "target" then unit = __target end
    return unit and __units[unit]
end
function UnitName(unit) if unit == "player" then return "Tester" end return "Mob" end
function UnitExists(unit)
    if unit == "target" then return __target ~= nil end
    return U(unit) ~= nil
end
function UnitClassification(unit)
    local u = U(unit)
    if not u then return nil end
    if u.secret then return SECRET end
    return u.class
end
function UnitIsPlayer(unit) local u = U(unit) return u and u.player or false end
function UnitCanAttack(_, unit) local u = U(unit) return u and u.attackable or false end
function UnitIsDead(unit) local u = U(unit) return u and u.dead or false end
function UnitAffectingCombat(unit) if unit == "player" then return __inCombat end return false end
function UnitIsUnit(a, b)
    if b == "target" then return __target ~= nil and a == __target end
    return a == b
end

-- Nameplates: one mock plate frame per unit token.
__plates = {}
C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        if unit == "target" then unit = __target end
        if not unit then return nil end
        return __plates[unit]
    end,
    GetNamePlates = function()
        local list = {}
        for _, p in pairs(__plates) do list[#list + 1] = p end
        return list
    end,
}
function __AddPlate(unit, data)
    __units[unit] = data
    local plate = NewObject("Frame", WorldFrame)
    __plates[unit] = plate
    return plate
end
function __RemovePlate(unit)
    __plates[unit] = nil
end

-- Fire an event at every frame that registered it.
function __Fire(event, ...)
    for _, f in ipairs(eventFrames[event] or {}) do
        local fn = f.__scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

-- Shown element frames on a plate (the addon's visuals are the children with a .tex).
function __ShownElements(plate)
    local n, list = 0, {}
    for _, child in ipairs(plate.__children) do
        if rawget(child, "tex") and child.__shown then
            n = n + 1
            list[#list + 1] = child
        end
    end
    return n, list
end
