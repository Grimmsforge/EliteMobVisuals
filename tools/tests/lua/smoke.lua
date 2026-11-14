-- Drives the loaded addon through a session and reports each check through
-- __check(ok, message), which the JS runner collects.
local ns = __ns

-- One Blizzard atlas this client "lacks", to check the fallback (styles are
-- resolved once and cached, so it goes before anything draws).
__atlases["nameplates-icon-elite-gold"] = nil

-- Login: saved variables, settings page, events.
__Fire("PLAYER_LOGIN")
__check(ns.db and ns.db.profile and ns.db.profile.enabled == true, "profile loaded with defaults")
__check(__settingsCategory ~= nil, "settings page registered")

-- Minimap button: a LibDBIcon look-alike that button bags can collect.
local mmb = LibDBIcon10_EliteMobVisuals
__check(mmb ~= nil, "minimap button is the global LibDBIcon10_EliteMobVisuals")
__check(mmb and mmb.__parent == Minimap, "minimap button is parented to Minimap")
__check(mmb and mmb:IsShown(), "minimap button shown at login")
__check(mmb and mmb.icon ~= nil and mmb.dataObject == ns.launcher, "keeps .icon and .dataObject for button bags")
__check(mmb and mmb.icon.__texture == ns.ICON, "minimap icon texture")
__check(__ldb.objects.EliteMobVisuals and __ldb.objects.EliteMobVisuals.type == "launcher", "launcher published to LibDataBroker")
__check(__ldb.objects.EliteMobVisuals ~= ns.launcher, "LDB gets a copy of the launcher")
mmb.__scripts.OnEnter(mmb)
mmb.__scripts.OnLeave(mmb)
mmb.__scripts.OnClick(mmb, "LeftButton")
__check(EliteMobVisualsOptionsFrame and EliteMobVisualsOptionsFrame:IsShown(), "left-click opens the options")
mmb.__scripts.OnClick(mmb, "LeftButton")
__check(not EliteMobVisualsOptionsFrame:IsShown(), "left-click again closes them")
mmb.__scripts.OnDragStart(mmb)
mmb.__scripts.OnUpdate(mmb)
mmb.__scripts.OnDragStop(mmb)
__check(math.abs((ns.db.profile.minimap.minimapPos or -1) - 0) < 1e-9, "drag saves the angle")
mmb.__scripts.OnClick(mmb, "RightButton")
__check(not mmb:IsShown() and ns.db.profile.minimap.hide == true, "right-click hides the button")
SlashCmdList.ELITEMOBVISUALS("minimap")
__check(mmb:IsShown() and ns.db.profile.minimap.hide == false, "/emv minimap shows it again")

-- The Settings page re-reads its values when shown.
local panel = ns.Options.settingsPanel
__check(panel ~= nil, "settings page built")
panel.__scripts.OnShow(panel)
SlashCmdList.ELITEMOBVISUALS("settings")
__check(__openedCategory == 1, "/emv settings opens the Settings page")

-- Plates appear: an elite, a rare, a normal mob, a friendly elite, a player,
-- and a mob whose classification is a secret value.
local elite    = __AddPlate("nameplate1", { class = "elite", attackable = true })
local rare     = __AddPlate("nameplate2", { class = "rare", attackable = true })
local normal   = __AddPlate("nameplate3", { class = "normal", attackable = true })
local friendly = __AddPlate("nameplate4", { class = "elite", attackable = false })
local player   = __AddPlate("nameplate5", { class = "normal", attackable = true, player = true })
local secret   = __AddPlate("nameplate6", { class = "elite", attackable = true, secret = true })
for i = 1, 6 do __Fire("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end

-- Defaults: badge on the target only, overhead marker on every marked plate.
__check(__ShownElements(elite) == 1, "elite, not targeted: overhead marker only")
__check(__ShownElements(rare) == 1, "rare, not targeted: overhead marker only")
__check(__ShownElements(normal) == 0, "normal mob: nothing")
__check(__ShownElements(friendly) == 0, "friendly elite: nothing (hostile only)")
__check(__ShownElements(player) == 0, "player: nothing")
__check(__ShownElements(secret) == 0, "secret classification: nothing, and no error")

-- Target the elite: badge and its mirrored pair appear.
__target = "nameplate1"
__Fire("PLAYER_TARGET_CHANGED")
__check(__ShownElements(elite) == 3, "targeted elite: badge, pair and overhead")
local _, shown = __ShownElements(elite)
local mirroredOne = false
for _, e in ipairs(shown) do
    if e.__points[1] and (e.__points[1][1] == "LEFT" or e.__points[1][1] == "RIGHT") then mirroredOne = true end
end
__check(mirroredOne, "badges anchored beside the plate")

-- Retarget: the badge moves.
__target = "nameplate2"
__Fire("PLAYER_TARGET_CHANGED")
__check(__ShownElements(elite) == 1, "old target: badge gone")
__check(__ShownElements(rare) == 3, "new target: badge shown")

-- Settings: no pair, overhead off, badge on every plate.
local p = ns.db.profile
p.badge.pair = false
p.overhead.enabled = false
p.badge.scope = "all"
ns.NotifySettingsChanged()
__check(__ShownElements(elite) == 1 and __ShownElements(rare) == 1, "badge on all plates, single, no overhead")

-- Per-class off.
p.classes.rare.show = false
ns.NotifySettingsChanged()
__check(__ShownElements(rare) == 0, "rare turned off")
p.classes.rare.show = true

-- Every style draws for every class, including missing Blizzard art (fallback).
for _, style in ipairs(ns.Media.ORDER) do
    p.badge.style = style
    for _, class in ipairs(ns.CLASSES) do
        local spec = ns.Media.Resolve(style, class)
        __check(spec and spec.file and spec.coords and spec.aspect, "style " .. style .. " resolves for " .. class)
    end
    ns.NotifySettingsChanged()
end
__check(ns.Media.Resolve("blizzIcon", "elite").file == ns.MEDIA .. "textures\\badge-crest", "missing atlas falls back to a bundled style")

-- Every placement and animation.
for _, point in ipairs(ns.PLACEMENT_ORDER) do
    p.badge.point = point
    p.badge.pair = true
    for _, anim in ipairs(ns.ANIM_ORDER) do
        p.badge.anim = anim
        ns.NotifySettingsChanged()
    end
end
__check(__ShownElements(elite) >= 1, "badge still shown after cycling placements and animations")

-- Overhead with a text-only style and label.
p.overhead.enabled = true
p.overhead.style = "none"
p.classes.elite.overheadStyle = "star"
p.overhead.label = true
ns.NotifySettingsChanged()
__check(__ShownElements(elite) >= 2, "overhead with per-class style and label")

-- Health bar anchor with no known bar falls back to the plate.
p.anchor = "health"
ns.NotifySettingsChanged()
__check(__ShownElements(elite) >= 1, "health anchor falls back to the plate")

-- Test mode marks the normal mob and the friendly elite.
SlashCmdList.ELITEMOBVISUALS("test rare")
__check(ns.Classify.testClass == "rare", "test mode on as rare")
__check(__ShownElements(normal) >= 1, "test mode marks a normal mob")
__check(__ShownElements(friendly) >= 1, "test mode ignores the hostility filter")
__check(__ShownElements(player) == 0, "test mode skips players")
SlashCmdList.ELITEMOBVISUALS("test")
__check(ns.Classify.testClass == nil, "test mode off")
__check(__ShownElements(normal) == 0, "normal mob unmarked again")

-- Test mode with the settings from the in-game report: badge on the target
-- only, overhead marker off. Test mode must still badge every plate.
p.badge.scope = "target"
p.overhead.enabled = false
__target = nil
__Fire("PLAYER_TARGET_CHANGED")
SlashCmdList.ELITEMOBVISUALS("test")
__check(__ShownElements(normal) >= 1 and __ShownElements(rare) >= 1, "test mode badges every plate even when the badge shows on the target only")
local chatBefore = #__chat
SlashCmdList.ELITEMOBVISUALS("debug")
__check(#__chat > chatBefore + 3, "/emv debug prints the state and each plate")
local sawPlateLine = false
for i = chatBefore + 1, #__chat do
    if __chat[i]:find("nameplate2") and __chat[i]:find("marked=elite") then sawPlateLine = true end
end
__check(sawPlateLine, "/emv debug lists each plate with what it was marked as")
SlashCmdList.ELITEMOBVISUALS("test")
__check(__ShownElements(normal) == 0, "test mode off: the normal mob is unmarked again")
-- Turning test mode on with nothing to show says so.
p.badge.enabled = false
chatBefore = #__chat
SlashCmdList.ELITEMOBVISUALS("test")
local warned = false
for i = chatBefore + 1, #__chat do
    if __chat[i]:find("both turned off") then warned = true end
end
__check(warned, "test mode explains when the badge and marker are both off")
SlashCmdList.ELITEMOBVISUALS("test")
p.badge.enabled = true
p.badge.scope = "all"
p.overhead.enabled = true
ns.NotifySettingsChanged()

-- Combat only.
p.combatOnly = true
ns.NotifySettingsChanged()
__check(__ShownElements(elite) == 0, "combat only: hidden out of combat")
__inCombat = true
__Fire("PLAYER_REGEN_DISABLED")
__check(__ShownElements(elite) >= 1, "combat only: shown in combat")
__inCombat = false
p.combatOnly = false

-- Off and on.
SlashCmdList.ELITEMOBVISUALS("off")
__check(__ShownElements(elite) == 0, "/emv off hides everything")
SlashCmdList.ELITEMOBVISUALS("on")
__check(__ShownElements(elite) >= 1, "/emv on shows again")

-- Options window: build, every tab, preview classes, close.
SlashCmdList.ELITEMOBVISUALS("")
__check(EliteMobVisualsOptionsFrame and EliteMobVisualsOptionsFrame:IsShown(), "options window opens")
ns.Options.RefreshControls()
for _, class in ipairs(ns.CLASSES) do
    p.classes[class].show = false
    ns.NotifySettingsChanged()
    p.classes[class].show = true
    ns.NotifySettingsChanged()
end
SlashCmdList.ELITEMOBVISUALS("")
__check(not EliteMobVisualsOptionsFrame:IsShown(), "options window toggles closed")

-- Unit data arriving late: a plate first reads normal, then elite.
local late = __AddPlate("nameplate7", { class = "normal", attackable = true })
__Fire("NAME_PLATE_UNIT_ADDED", "nameplate7")
__check(__ShownElements(late) == 0, "late unit: nothing while normal")
__units.nameplate7.class = "elite"
__Fire("UNIT_NAME_UPDATE", "nameplate7")
__check(__ShownElements(late) >= 1, "late unit: marked once its data arrives")

-- EllesmereUI Nameplates: it draws its own plate (a child of the nameplate)
-- and registers it in EllesmereNameplates_NS.plates[unit], here only after our
-- NAME_PLATE_UNIT_ADDED handler has run, as can happen in game.
__check(ns.db.profile.anchor == "health", "health anchor in use for the EllesmereUI checks")
EllesmereNameplates_NS = { plates = {} }
local np8 = __AddPlate("nameplate8", { class = "elite", attackable = true })
local eui = CreateFrame("Frame", nil, UIParent)
eui:SetParent(np8)
eui.nameplate = np8
eui.health = CreateFrame("StatusBar", nil, eui)
eui.name = eui:CreateFontString()
__Fire("NAME_PLATE_UNIT_ADDED", "nameplate8")
__check(__ShownElements(np8) >= 1 and __ShownElements(eui) == 0, "EllesmereUI not attached yet: visuals on the nameplate")
EllesmereNameplates_NS.plates.nameplate8 = eui
__RunTimers()
local nEui, euiShown = __ShownElements(eui)
__check(nEui >= 2 and __ShownElements(np8) == 0, "EllesmereUI: next-frame check moves the visuals onto its plate")
local lifted, onName, onBar = true, false, false
for _, e in ipairs(euiShown) do
    if e.__strata ~= "MEDIUM" or e.__level ~= 850 then lifted = false end
    local pt = e.__points[1]
    if rawget(e, "label") and pt and pt[2] == eui.name then onName = true end
    if not rawget(e, "label") and pt and pt[2] == eui.health then onBar = true end
end
__check(lifted, "EllesmereUI: drawn at MEDIUM strata, level 850 (above its auras, under its text)")
__check(onName, "EllesmereUI: overhead marker sits above its name")
__check(onBar, "EllesmereUI: badge sits beside its health bar")
p.anchor = "plate"
ns.NotifySettingsChanged()
local _, plateShown = __ShownElements(eui)
__check(plateShown[1] and plateShown[1].__points[1][2] == np8, "EllesmereUI with the plate anchor: anchored to the nameplate frame")
p.anchor = "health"
ns.NotifySettingsChanged()
__Fire("NAME_PLATE_UNIT_REMOVED", "nameplate8")
local leftOnEui = 0
for _, c in ipairs(eui.__children) do if rawget(c, "tex") then leftOnEui = leftOnEui + 1 end end
__check(leftOnEui == 0, "EllesmereUI: removed plate hands its visuals back to the nameplate (none left on the pooled plate)")
__check(__ShownElements(np8) == 0, "EllesmereUI: removed plate's visuals hidden")
EllesmereNameplates_NS = nil

-- Target frame badge: for nameplates off or out of range.
local tfp, tfs = p.targetFrame, ns.TargetFrame.state
__check(p.badge.where == "auto" and tfp.attach == "frame" and tfp.enabled == nil, "badge where defaults to auto; target frame defaults")
local blizzTarget = CreateFrame("Button", "TargetFrame", UIParent)
__units.mob9 = { class = "elite", attackable = true }      -- no nameplate
__target = "mob9"
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.shown and tfs.anchor == "TargetFrame", "nameplates off: badge on Blizzard's target frame")
local tfBadge = nil
for _, c in ipairs(UIParent.__children) do
    for _, e in ipairs(c.__children or {}) do
        if rawget(e, "tex") and e.__shown and e.__points[1] and e.__points[1][2] == blizzTarget then tfBadge = e end
    end
end
__check(tfBadge ~= nil, "the badge is anchored to the target frame (not parented to the secure frame)")
__check(tfBadge and tfBadge.__parent ~= blizzTarget, "never parented to the unit frame")

-- EllesmereUI's target frame: Blizzard's is parked on a hidden parent, and
-- EllesmereUI's shows a moment later (its unit watch).
local parked = CreateFrame("Frame", nil, UIParent)
parked:Hide()
blizzTarget:SetParent(parked)
local euiTarget = CreateFrame("Button", "EllesmereUIUnitFrames_Target", CreateFrame("Frame", nil, UIParent))
euiTarget:Hide()
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.anchor == "EllesmereUIUnitFrames_Target", "EllesmereUI target frame used, even before it shows")
euiTarget:Show()
__RunTimers()
__check(tfs.shown and tfs.anchor == "EllesmereUIUnitFrames_Target", "EllesmereUI target frame used once shown")

-- EllesmereUI set to Blizzard's target frame: no frame of its own.
_G.EllesmereUIUnitFrames_Target = nil
blizzTarget:SetParent(UIParent)
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.anchor == "TargetFrame", "EllesmereUI on Blizzard's frame: Blizzard's target frame used")

-- Target with a nameplate that shows the badge: no doubling up by default.
__target = "nameplate2"
__Fire("PLAYER_TARGET_CHANGED")
__check(ns.TargetPlateBadgeShown() and not tfs.shown, "auto: target frame steps aside while the target's nameplate shows the badge")

-- "Show the badge on": each of the four choices, with the target's nameplate on screen.
local function PlateBadges(plate)
    local n = 0
    for _, c in ipairs(plate.__children) do
        if rawget(c, "tex") and not rawget(c, "label") and c.__shown then n = n + 1 end
    end
    return n
end
p.badge.where = "both"
ns.NotifySettingsChanged()
__check(tfs.shown and PlateBadges(rare) >= 1, "both: on the nameplate and the target frame")
p.badge.where = "frame"
ns.NotifySettingsChanged()
__check(tfs.shown and PlateBadges(rare) == 0, "target frame only: no badge on any nameplate")
SlashCmdList.ELITEMOBVISUALS("test")
__check(PlateBadges(normal) == 0 and tfs.shown, "target frame only: test mode badges no nameplate either")
SlashCmdList.ELITEMOBVISUALS("test")
p.badge.where = "nameplate"
ns.NotifySettingsChanged()
__check(not tfs.shown and PlateBadges(rare) >= 1, "nameplate only: never on the target frame")
__target = "mob9"                                           -- a target with no nameplate
__Fire("PLAYER_TARGET_CHANGED")
__check(not tfs.shown, "nameplate only: not on the target frame even with nameplates off")
__target = "nameplate2"
__Fire("PLAYER_TARGET_CHANGED")
p.badge.where = "auto"
p.badge.enabled = false
ns.NotifySettingsChanged()
__check(not tfs.shown and PlateBadges(rare) == 0, "badge off: nowhere")
p.badge.enabled = true
ns.NotifySettingsChanged()
__check(not tfs.shown and PlateBadges(rare) >= 1, "badge back on (auto): on the nameplate, not the target frame")

-- Out of nameplate range: the plate goes, the target frame badge takes over.
__Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
__check(tfs.shown, "target's nameplate removed: target frame badge shows")
__Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
__check(not tfs.shown, "target's nameplate back: target frame badge steps aside")

-- Free position, and its drag box while the options window is open.
__target = "mob9"
tfp.attach = "screen"
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.shown and tfs.anchor == "free position", "free position")
SlashCmdList.ELITEMOBVISUALS("")
__check(EliteMobVisualsTargetAnchor.bg:IsShown(), "drag box shows while the options are open")
SlashCmdList.ELITEMOBVISUALS("")
__check(not EliteMobVisualsTargetAnchor.bg:IsShown(), "drag box hides when the options close")
tfp.attach = "frame"

-- No target frame at all (EllesmereUI's set to hidden): the free position.
blizzTarget:SetParent(parked)
ns.NotifySettingsChanged()
__check(tfs.shown and tfs.anchor == "free position", "no target frame in use: falls back to the free position")
blizzTarget:SetParent(UIParent)

-- Friendly or unmarked targets, and no target.
__units.mob10 = { class = "normal", attackable = true }
__target = "mob10"
__Fire("PLAYER_TARGET_CHANGED")
__check(not tfs.shown, "normal target: nothing on the target frame")
SlashCmdList.ELITEMOBVISUALS("test")
__check(tfs.shown, "test mode marks the target on the target frame too")
SlashCmdList.ELITEMOBVISUALS("test")
__target = nil
__Fire("PLAYER_TARGET_CHANGED")
__check(not tfs.shown, "no target: nothing on the target frame")

-- Plate removed: its visuals hide.
__Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
__RemovePlate("nameplate1")
__check(__ShownElements(elite) == 0, "removed plate hides its visuals")

-- Reset, then logout strips every default.
ns.db.profile.minimap.hide = true
ns.ResetProfile()
__check(ns.db.profile.badge.style == "wing" and ns.db.profile.badge.pair == true, "reset restores defaults")
__check(ns.MinimapButton.db == ns.db.profile.minimap and mmb.db == ns.db.profile.minimap, "reset re-points the minimap button at the new table")
__check(mmb:IsShown(), "reset shows the minimap button again")
__Fire("PLAYER_LOGOUT")
__check(EliteMobVisualsDB.profiles == nil, "logout saves nothing when everything is default")

-- A changed value survives logout.
EliteMobVisualsDB = { profiles = { Default = { badge = { size = 40 } } } }
local db = ns.DB.New("EliteMobVisualsDB", ns.DEFAULTS)
__check(db.profile.badge.size == 40 and db.profile.badge.style == "wing", "saved value kept, defaults filled in")

-- Settings saved before "Show the badge on" fold into it.
local function Migrated(saved)
    EliteMobVisualsDB = { profiles = { Default = { targetFrame = saved } } }
    local d = ns.DB.New("EliteMobVisualsDB", ns.DEFAULTS)
    ns.MigrateProfile(d.profile)
    return d.profile
end
local m1 = Migrated({ enabled = false })
__check(m1.badge.where == "nameplate" and m1.targetFrame.enabled == nil, "old target frame off -> nameplate only")
local m2 = Migrated({ mode = "always" })
__check(m2.badge.where == "both" and m2.targetFrame.mode == nil, "old target frame always -> both")
local m3 = Migrated({ mode = "fallback", size = 40 })
__check(m3.badge.where == "auto" and m3.targetFrame.size == 40 and m3.targetFrame.mode == nil, "old fallback -> auto, other target frame settings kept")

-- Slash help does not error.
SlashCmdList.ELITEMOBVISUALS("help")
__check(#__chat > 0, "chat output")
