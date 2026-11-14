-- =============================================================================
-- Elite Mob Visuals: styles
-- A style is what a badge or marker draws. Bundled styles are greyscale art in
-- media/textures/, tinted with the classification colour. Blizzard styles use
-- the game's own elite and rare art (a different texture per classification)
-- and are never tinted. A Blizzard texture the client lacks falls back to a
-- bundled style, so a style can never draw a blank or green square.
--
-- ns.Media.Resolve(styleKey, classification) returns a spec:
--   { file, coords = { l, r, t, b }, aspect = width / height,
--     facing = "right" | nil, tintable = bool }
-- =============================================================================
local _, ns = ...
local L = ns.L

local Media = {}
ns.Media = Media

local TEX = ns.MEDIA .. "textures\\"
Media.GLOW = TEX .. "glow"

local FALLBACK_STYLE = "crest"

-- facing = "right": the art points right, so on the left of a plate it is
-- mirrored to point outward. Unset: symmetric art.
local STYLES = {
    wing    = { name = L["Gilded Wing"],    file = TEX .. "badge-wing",    facing = "right" },
    crest   = { name = L["Heraldic Crest"], file = TEX .. "badge-crest" },
    star    = { name = L["Faceted Star"],   file = TEX .. "badge-star" },
    skull   = { name = L["Skull"],          file = TEX .. "badge-skull" },
    diamond = { name = L["Cut Gem"],        file = TEX .. "badge-diamond" },
    crown   = { name = L["Crown"],          file = TEX .. "badge-crown" },
    chevron = { name = L["Chevron"],        file = TEX .. "badge-chevron" },
    arrow   = { name = L["Arrow"],          file = TEX .. "badge-arrow" },

    -- The nameplate classification icons (gold elite, silver rare elite, star).
    blizzIcon = {
        name = L["Blizzard Nameplate Icon"], native = true,
        byClass = {
            elite     = { atlas = { "nameplates-icon-elite-gold" } },
            worldboss = { atlas = { "nameplates-icon-elite-gold" } },
            rareelite = { atlas = { "nameplates-icon-elite-silver" } },
            rare      = { atlas = { "nameplates-icon-rareelite" } },
        },
    },
    -- The target frame's portrait dragons. Each lists fallbacks: not every
    -- client carries every variant (Forever uses the winged silver for rares).
    blizzDragon = {
        name = L["Blizzard Dragon"], native = true, facing = "right",
        byClass = {
            elite     = { atlas = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold" } },
            worldboss = { atlas = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",
                                    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold" } },
            rareelite = { atlas = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged",
                                    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver" } },
            rare      = { atlas = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver",
                                    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged" } },
        },
    },
    -- The vanilla target frame's dragon and portrait ring, cropped out of the
    -- classic textures (see docs/reference/blizzard/).
    classicDragon = {
        name = L["Classic Dragon"], native = true, facing = "right",
        byClass = {
            elite     = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite",      coords = { 144 / 256, 1, 0, 104 / 128 }, aspect = 112 / 104 },
            worldboss = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite",      coords = { 144 / 256, 1, 0, 104 / 128 }, aspect = 112 / 104 },
            rareelite = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite", coords = { 144 / 256, 1, 0, 104 / 128 }, aspect = 112 / 104 },
            rare      = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare",       coords = { 144 / 256, 1, 0, 104 / 128 }, aspect = 112 / 104 },
        },
    },
    -- The minimap's rare and rare elite vignettes.
    vignette = {
        name = L["Blizzard Vignette"], native = true,
        byClass = {
            elite     = { atlas = { "VignetteKillElite" } },
            worldboss = { atlas = { "VignetteKillElite" } },
            rareelite = { atlas = { "VignetteKillElite" } },
            rare      = { atlas = { "VignetteKill" } },
        },
    },
    -- Raid target icons: skull for elites and bosses, star for rares.
    raidIcon = {
        name = L["Raid Target Icon"], native = true,
        byClass = {
            elite     = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
            worldboss = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
            rareelite = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
            rare      = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
        },
    },
}

Media.ORDER = {
    "wing", "crest", "star", "skull", "diamond", "crown", "chevron", "arrow",
    "blizzIcon", "blizzDragon", "classicDragon", "vignette", "raidIcon",
}

function Media.GetName(key)
    local s = STYLES[key]
    return s and s.name or key
end

function Media.Exists(key) return STYLES[key] ~= nil end

-- Each candidate atlas name in turn; the first the client has wins.
local function ResolveAtlas(names)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    for _, name in ipairs(names) do
        local info = C_Texture.GetAtlasInfo(name)
        if info and info.file then
            local w, h = info.width or 1, info.height or 1
            return {
                file = info.file,
                coords = { info.leftTexCoord or 0, info.rightTexCoord or 1, info.topTexCoord or 0, info.bottomTexCoord or 1 },
                aspect = (h > 0) and (w / h) or 1,
            }
        end
    end
end

-- A plain file path, if the client has it. Without GetFileIDFromPath the file
-- is assumed present (every file named here has shipped since vanilla).
local function ResolveFile(def)
    if GetFileIDFromPath and not GetFileIDFromPath(def.file) then return nil end
    return { file = def.file, coords = def.coords or { 0, 1, 0, 1 }, aspect = def.aspect or 1 }
end

local cache = {}

function Media.Resolve(key, class)
    local cacheKey = key .. ":" .. (class or "")
    local spec = cache[cacheKey]
    if spec then return spec end

    local style = STYLES[key] or STYLES[FALLBACK_STYLE]
    if style.byClass then
        local def = style.byClass[class] or style.byClass.elite
        local found = def.atlas and ResolveAtlas(def.atlas) or (def.file and ResolveFile(def))
        if found then
            found.facing = style.facing
            found.tintable = false
            spec = found
        else
            spec = Media.Resolve(FALLBACK_STYLE, class)
        end
    else
        spec = { file = style.file, coords = { 0, 1, 0, 1 }, aspect = 1, facing = style.facing, tintable = true }
    end
    cache[cacheKey] = spec
    return spec
end
