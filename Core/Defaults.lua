-- =============================================================================
-- Elite Mob Visuals: default settings
-- Every option the addon has. A default changed here reaches everyone who never
-- changed that option (DB.lua strips defaults on logout).
-- =============================================================================
local _, ns = ...

ns.DEFAULTS = {
    profile = {
        enabled = true,
        -- Only mark mobs the player can attack (hostile and neutral).
        hostileOnly = true,
        -- Only mark mobs while the player is in combat.
        combatOnly = false,
        hideDead = true,
        -- The minimap button (Core/MinimapButton.lua). hide: the button is
        -- off. minimapPos (saved once dragged): its angle around the minimap.
        minimap = { hide = false },

        -- What the visuals attach to (Core/Plates.lua finds the frames):
        -- "health": the badge beside the health bar and the marker above the
        -- name, for Blizzard, EllesmereUI, Plater, ElvUI and Kui plates, else
        -- the nameplate frame. "plate": always Blizzard's nameplate frame
        -- (the click box), which nameplate addons size in their own ways.
        anchor = "health",

        -- Hide the nameplate addon's own elite/rare icon on mobs this addon
        -- marks, so they don't show two (EllesmereUI's Rare/Elite indicator;
        -- restored the moment a mob stops being marked).
        hideNameplateIcons = true,

        -- Per classification: shown or not, and its colour (tints the bundled
        -- styles, the glow, the label and a tinted border). Styles per
        -- classification belong to each visual (its classStyles).
        classes = {
            elite     = { show = true, color = { r = 1.00, g = 0.82, b = 0.25 } },
            rareelite = { show = true, color = { r = 0.62, g = 0.86, b = 1.00 } },
            rare      = { show = true, color = { r = 0.82, g = 0.84, b = 0.90 } },
            worldboss = { show = true, color = { r = 1.00, g = 0.36, b = 0.26 } },
        },

        -- The badge beside the nameplate.
        -- What shows is set in one place, the Visibility page: the four
        -- visuals' enabled (and the target frame ones' fallback), plus the
        -- nameplate ones' scope.
        --
        -- Each visual has a style and classStyles: a style per classification,
        -- "" for "the visual's own style". The target frame visuals' style ""
        -- means their nameplate counterpart's (per classification too).
        badge = {
            -- The badge on nameplates.
            enabled = true,
            -- Which nameplates: "target" (your target's only) or "all" (every
            -- marked plate).
            scope = "target",
            style = "wing",
            classStyles = { elite = "", rareelite = "", rare = "", worldboss = "" },
            size = 26,
            -- Width as a share of the art's own: stretch or squash to fit a plate.
            width = 1,
            -- Where on the plate, see ns.PLACEMENTS in Visuals.lua.
            point = "LEFT",
            x = 0,
            y = 0,
            -- A mirrored copy on the opposite side.
            pair = true,
            -- Mirror the art. Styles that point one way already face outward.
            flip = false,
            alpha = 1,
            tint = true,
            glow = false,
            glowAlpha = 0.6,
            -- "none", "pulse", "breathe", "bob" or "spin".
            anim = "none",
            -- A plain rectangle behind the icon (each visual's page).
            bg = {
                enabled = false,
                width = 36,
                height = 36,
                x = 0,
                y = 0,
                color = { r = 0.05, g = 0.04, b = 0.06 },
                alpha = 0.7,
                border = true,
                -- true: the border takes the classification colour instead.
                borderTint = false,
                borderColor = { r = 0.95, g = 0.74, b = 0.25 },
                borderSize = 1,
            },
        },

        -- The badge on the target unit frame (Core/TargetFrame.lua).
        targetFrame = {
            -- Always on the target frame.
            enabled = false,
            -- On the target frame while the nameplate badge isn't showing on
            -- the target: it is turned off, nameplates are off, or the target
            -- is out of nameplate range.
            fallback = true,
            -- "frame": the target frame in use (EllesmereUI, ElvUI, Shadowed
            -- Unit Frames or Blizzard's), else the free position.
            -- "screen": always the free position (drag it while the options
            -- window is open).
            attach = "frame",
            -- "" = the nameplate badge's style.
            style = "",
            classStyles = { elite = "", rareelite = "", rare = "", worldboss = "" },
            size = 32,
            -- Width as a share of the art's own: stretch or squash to fit a plate.
            width = 1,
            point = "RIGHT",
            x = 0,
            y = 0,
            pair = false,
            flip = false,
            alpha = 1,
            tint = true,
            glow = false,
            glowAlpha = 0.6,
            anim = "none",
            -- A plain rectangle behind the icon (each visual's page).
            bg = {
                enabled = false,
                width = 42,
                height = 42,
                x = 0,
                y = 0,
                color = { r = 0.05, g = 0.04, b = 0.06 },
                alpha = 0.7,
                border = true,
                -- true: the border takes the classification colour instead.
                borderTint = false,
                borderColor = { r = 0.95, g = 0.74, b = 0.25 },
                borderSize = 1,
            },
            free = { point = "CENTER", x = 0, y = 180 },
        },

        -- The marker above the mob's nameplate (its head).
        overhead = {
            enabled = true,
            -- "all", "target" (your target only) or "nontarget" (all but your target).
            scope = "all",
            style = "chevron",
            classStyles = { elite = "", rareelite = "", rare = "", worldboss = "" },
            size = 22,
            -- Width as a share of the art's own: stretch or squash to fit a plate.
            width = 1,
            x = 0,
            y = 4,
            alpha = 1,
            tint = true,
            glow = false,
            glowAlpha = 0.6,
            anim = "bob",
            -- A text label: "Elite", "Rare", "Rare Elite" or "Boss".
            label = false,
            labelSize = 11,
            labelPos = "above",
            -- A plain rectangle behind the icon (each visual's page).
            bg = {
                enabled = false,
                width = 30,
                height = 30,
                x = 0,
                y = 0,
                color = { r = 0.05, g = 0.04, b = 0.06 },
                alpha = 0.7,
                border = true,
                -- true: the border takes the classification colour instead.
                borderTint = false,
                borderColor = { r = 0.95, g = 0.74, b = 0.25 },
                borderSize = 1,
            },
        },

        -- The marker above the target unit frame (Core/TargetFrame.lua): the
        -- nameplate marker's counterpart, set up on its own.
        targetMarker = {
            -- Always above the target frame.
            enabled = false,
            -- Above the target frame while the nameplate marker isn't showing
            -- on the target (turned off, nameplates off, out of range).
            fallback = true,
            -- "" = the nameplate marker's style ("none" = text only).
            style = "",
            classStyles = { elite = "", rareelite = "", rare = "", worldboss = "" },
            size = 22,
            -- Width as a share of the art's own: stretch or squash to fit a plate.
            width = 1,
            x = 0,
            y = 4,
            alpha = 1,
            tint = true,
            glow = false,
            glowAlpha = 0.6,
            anim = "bob",
            label = false,
            labelSize = 11,
            labelPos = "above",
            bg = {
                enabled = false,
                width = 30,
                height = 30,
                x = 0,
                y = 0,
                color = { r = 0.05, g = 0.04, b = 0.06 },
                alpha = 0.7,
                border = true,
                borderTint = false,
                borderColor = { r = 0.95, g = 0.74, b = 0.25 },
                borderSize = 1,
            },
        },
    },
    global = {
        -- Options window position, saved when dragged.
        window = {},
    },
}

function ns.BadgeOnNameplates(profile)
    return profile.badge.enabled
end

-- Whether the target frame can show the badge (or marker) at all: always, or
-- as the fallback for when its nameplate counterpart isn't showing.
function ns.BadgeOnTargetFrame(profile)
    local tf = profile.targetFrame
    return tf.enabled or tf.fallback
end

function ns.MarkerOnTargetFrame(profile)
    local tm = profile.targetMarker
    return tm.enabled or tm.fallback
end

-- Saved settings from earlier versions, folded into the Visibility settings
-- once (neither key is a default any more, so a saved one is a real choice):
--   badge.where     "nameplate" | "frame" | "both" ("auto" is today's default)
--   targetFrame.mode "always" (from before badge.where)
--   classes[c].badgeStyle / overheadStyle: per-classification styles that
--     applied to both badges / both markers; now the nameplate visuals'
--     classStyles, which the target frame visuals inherit
function ns.MigrateProfile(profile)
    local b, tf = profile.badge, profile.targetFrame
    if type(b) ~= "table" or type(tf) ~= "table" then return end
    for class, c in pairs(profile.classes or {}) do
        if type(c) == "table" then
            local bs, os = rawget(c, "badgeStyle"), rawget(c, "overheadStyle")
            if type(bs) == "string" and bs ~= "" and b.classStyles[class] == "" then b.classStyles[class] = bs end
            if type(os) == "string" and os ~= "" and profile.overhead.classStyles[class] == "" then
                profile.overhead.classStyles[class] = os
            end
            c.badgeStyle, c.overheadStyle = nil, nil
        end
    end
    local where = rawget(b, "where")
    if where == "nameplate" then
        tf.enabled, tf.fallback = false, false
    elseif where == "frame" then
        b.enabled, tf.enabled = false, true
    elseif where == "both" then
        tf.enabled = true
    end
    if rawget(tf, "mode") == "always" then
        tf.enabled = true
    end
    b.where, tf.mode = nil, nil
end
