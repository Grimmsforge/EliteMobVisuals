-- =============================================================================
-- Elite Mob Visuals: namespace and shared helpers
-- =============================================================================
local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.TITLE = "Elite Mob Visuals"
ns.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\media\\"
-- Two logos: the full one with wings (options window, Settings page), and a
-- compact, padded icon without them (minimap button, addon list, compartment),
-- since minimap button bags crop and ring the edge of whatever icon they get.
ns.LOGO = ns.MEDIA .. "logo\\emv-logo-128"
ns.ICON = ns.MEDIA .. "logo\\emv-icon-64"

local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"

-- The classifications this addon marks, in display order. UnitClassification
-- also returns "normal", "trivial" and "minus", which are never marked.
ns.CLASSES = { "elite", "rareelite", "rare", "worldboss" }
ns.IS_MARKED = { elite = true, rareelite = true, rare = true, worldboss = true }

-- WoW Forever runs the 12.x engine, where some unit reads can return secret
-- values that error when compared. Readable() turns a secret into nil, so every
-- check below simply fails closed instead of erroring.
local issecretvalue = issecretvalue
function ns.Readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local CHAT_PREFIX = "|cffe8b23aElite Mob Visuals|r: "
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. tostring(msg))
end

-- Shallow-enough copy for defaults and colour tables.
function ns.CopyTable(src)
    local t = {}
    for k, v in pairs(src) do
        t[k] = (type(v) == "table") and ns.CopyTable(v) or v
    end
    return t
end

-- Tiny callback list: settings changes notify the controller and the preview.
local listeners = {}
function ns.OnSettingsChanged(fn) listeners[#listeners + 1] = fn end
function ns.NotifySettingsChanged()
    ns.settingsVersion = (ns.settingsVersion or 0) + 1
    for i = 1, #listeners do listeners[i]() end
end
ns.settingsVersion = 0
