-- =============================================================================
-- Elite Mob Visuals: saved variables
-- db.profile and db.global over the EliteMobVisualsDB saved variable, with
-- defaults (the same small store Epithet uses, no libraries):
--   EliteMobVisualsDB.profileKeys["Name - Realm"] = "Default"
--   EliteMobVisualsDB.profiles.Default            -> db.profile
--   EliteMobVisualsDB.global                      -> db.global
--
-- Defaults are copied in at load and stripped again at PLAYER_LOGOUT, so only
-- values that differ from a default are saved, and a default changed in a
-- later version reaches everyone who never changed it.
-- =============================================================================
local _, ns = ...

local DB = {}
ns.DB = DB

local pairs, next, type, rawget, rawset, wipe = pairs, next, type, rawget, rawset, wipe

local DEFAULT_PROFILE = "Default"

-- Fill in every default the saved table lacks. Tables are always fresh, never
-- the defaults' own; a saved non-table where a table is expected is replaced.
local function CopyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(rawget(saved, k)) ~= "table" then rawset(saved, k, {}) end
            CopyDefaults(saved[k], v)
        elseif rawget(saved, k) == nil or type(rawget(saved, k)) ~= type(v) then
            rawset(saved, k, v)
        end
    end
end

-- Remove every value equal to its default, and tables left empty by that.
local function StripDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        local value = saved[k]
        if type(v) == "table" and type(value) == "table" then
            StripDefaults(value, v)
            if next(value) == nil then saved[k] = nil end
        elseif value == v then
            saved[k] = nil
        end
    end
end

local function Section(parent, key)
    local t = parent[key]
    if type(t) ~= "table" then
        t = {}
        parent[key] = t
    end
    return t
end

-- svName: the saved variable's global name. defaults: { profile = {...}, global = {...} }.
function DB.New(svName, defaults)
    local sv = _G[svName]
    if type(sv) ~= "table" then
        sv = {}
        _G[svName] = sv
    end

    local charKey = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
    local profileKeys = Section(sv, "profileKeys")
    local profileName = profileKeys[charKey] or DEFAULT_PROFILE
    profileKeys[charKey] = profileName

    local profile = Section(Section(sv, "profiles"), profileName)
    local global = Section(sv, "global")
    CopyDefaults(profile, defaults.profile or {})
    CopyDefaults(global, defaults.global or {})

    local db = { profile = profile, global = global }

    -- Back to defaults in place, so every reference to db.profile stays valid.
    function db:ResetProfile()
        wipe(profile)
        CopyDefaults(profile, defaults.profile or {})
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function()
        local profiles = rawget(sv, "profiles")
        if type(profiles) == "table" then
            local saved = profiles[profileName]
            if type(saved) == "table" and defaults.profile then
                StripDefaults(saved, defaults.profile)
                if next(saved) == nil then profiles[profileName] = nil end
            end
            if next(profiles) == nil then sv.profiles = nil end
        end
        local savedGlobal = rawget(sv, "global")
        if type(savedGlobal) == "table" then
            if defaults.global then StripDefaults(savedGlobal, defaults.global) end
            if next(savedGlobal) == nil then sv.global = nil end
        end
    end)

    return db
end
