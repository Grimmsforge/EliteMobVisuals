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

        -- Per classification: shown or not, its colour (tints the bundled
        -- styles, the glow and the label) and optional style overrides ("" =
        -- use the badge's or marker's own style).
        classes = {
            elite     = { show = true, color = { r = 1.00, g = 0.82, b = 0.25 }, badgeStyle = "", overheadStyle = "" },
            rareelite = { show = true, color = { r = 0.62, g = 0.86, b = 1.00 }, badgeStyle = "", overheadStyle = "" },
            rare      = { show = true, color = { r = 0.82, g = 0.84, b = 0.90 }, badgeStyle = "", overheadStyle = "" },
            worldboss = { show = true, color = { r = 1.00, g = 0.36, b = 0.26 }, badgeStyle = "", overheadStyle = "" },
        },

        -- The badge beside the nameplate.
        badge = {
            enabled = true,
            -- Where the badge shows:
            --   "auto"      the nameplate, or the target frame when the target
            --               has no nameplate badge (nameplates off, out of range)
            --   "nameplate" the nameplate above the mob's head only
            --   "frame"     the target unit frame only (Core/TargetFrame.lua)
            --   "both"      the nameplate and the target frame
            where = "auto",
            -- On nameplates: "target" (your target's only) or "all" (every
            -- marked plate).
            scope = "target",
            style = "wing",
            size = 26,
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
        },

        -- How the badge looks on the target unit frame (Core/TargetFrame.lua).
        -- Whether it shows there is badge.where.
        targetFrame = {
            -- "frame": the target frame in use (EllesmereUI, ElvUI, Shadowed
            -- Unit Frames or Blizzard's), else the free position.
            -- "screen": always the free position (drag it while the options
            -- window is open).
            attach = "frame",
            -- "" = the nameplate badge's style.
            style = "",
            size = 32,
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
            free = { point = "CENTER", x = 0, y = 180 },
        },

        -- The marker above the mob's nameplate (its head).
        overhead = {
            enabled = true,
            -- "all", "target" (your target only) or "nontarget" (all but your target).
            scope = "all",
            style = "chevron",
            size = 22,
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
        },
    },
    global = {
        -- Options window position, saved when dragged.
        window = {},
    },
}

-- Where the badge may show (badge.where). "auto" allows both: the target
-- frame then shows it only while the target's nameplate doesn't.
ns.WHERE_ORDER = { "auto", "nameplate", "frame", "both" }

function ns.BadgeOnNameplates(profile)
    local b = profile.badge
    return b.enabled and b.where ~= "frame"
end

function ns.BadgeOnTargetFrame(profile)
    local b = profile.badge
    return b.enabled and b.where ~= "nameplate"
end

-- Saved settings from before badge.where: the target frame had its own on/off
-- switch and a "fallback"/"always" mode. Fold them into badge.where, once.
function ns.MigrateProfile(profile)
    local tf = profile.targetFrame
    if type(tf) ~= "table" then return end
    if tf.enabled ~= nil or tf.mode ~= nil then
        if profile.badge.where == "auto" then
            if tf.enabled == false then
                profile.badge.where = "nameplate"
            elseif tf.mode == "always" then
                profile.badge.where = "both"
            end
        end
        tf.enabled, tf.mode = nil, nil
    end
end
