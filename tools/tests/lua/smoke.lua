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

-- End piece: grips both ends of the bar, mirrored, overlapping by its inset at
-- any size and width; Width stretches it.
for _, endPiece in ipairs({ "clasp", "winged" }) do
    local saved = { p.badge.style, p.badge.point, p.badge.pair, p.badge.size, p.badge.width, p.badge.x }
    p.badge.style, p.badge.point, p.badge.pair, p.badge.size, p.badge.width, p.badge.x = endPiece, "LEFT", true, 40, 1.5, 2
    ns.NotifySettingsChanged()
    local spec = ns.Media.Resolve(endPiece, "elite")
    __check(spec.inset and spec.facing == "left", endPiece .. ": is an end piece")
    local w = 40 * spec.aspect * 1.5
    local n, list = __ShownElements(elite)
    __check(n == 2, endPiece .. ": both ends")
    local byPoint = {}
    for _, e in ipairs(list) do byPoint[e.__points[1][1]] = e end
    local l, r = byPoint.RIGHT, byPoint.LEFT   -- the left piece hangs off its RIGHT point
    __check(l and r, endPiece .. ": anchored at each end")
    if l and r then
        __check(math.abs(l.__w - w) < 1e-6 and l.__h == 40, endPiece .. ": Width stretches, Size sets the height")
        __check(math.abs(l.__points[1][4] - (2 + w * spec.inset)) < 1e-6, endPiece .. ": left overlaps the bar by its inset")
        __check(math.abs(r.__points[1][4] + (2 + w * spec.inset)) < 1e-6, endPiece .. ": right mirrors the overlap")
        local lc, rc = l.tex.__coords, r.tex.__coords
        __check(lc[1] < lc[2] and rc[1] > rc[2], endPiece .. ": drawn as-is on the left, mirrored on the right")
    end
    p.badge.point, p.badge.pair = "RIGHT", false
    ns.NotifySettingsChanged()
    local _, one = __ShownElements(elite)
    local c = one[1] and one[1].tex.__coords
    __check(c and c[1] > c[2], endPiece .. ": a single piece on the right end faces outward")
    p.badge.style, p.badge.point, p.badge.pair, p.badge.size, p.badge.width, p.badge.x = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
    ns.NotifySettingsChanged()
end

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
p.overhead.classStyles.elite = "star"
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
p.targetFrame.fallback = false
p.targetMarker.fallback = false
chatBefore = #__chat
SlashCmdList.ELITEMOBVISUALS("test")
local warned = false
for i = chatBefore + 1, #__chat do
    if __chat[i]:find("Every visual is turned off") then warned = true end
end
__check(warned, "test mode explains when every visual is off")
SlashCmdList.ELITEMOBVISUALS("test")
p.badge.enabled = true
p.targetFrame.fallback = true
p.targetMarker.fallback = true
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

-- The preview shows the badge where the game would: on the mock nameplate,
-- the mock target frame, or both, following the Visibility tab.
local plateSet, frameSet = ns.Options.PreviewSets()
local function On(set, key) return set[key] ~= nil and set[key]:IsShown() end
-- Visibility settings as (nameplate badge, target frame badge, fallback).
local function Preview(badge, frame, fallback, target, plates)
    p.badge.enabled, p.targetFrame.enabled, p.targetFrame.fallback = badge, frame, fallback
    ns.NotifySettingsChanged()
    ns.Options.SetPreview(target, plates)
    return On(plateSet, "badge"), On(frameSet, "badge")
end
local onPlate, onFrame = Preview(true, false, true, true, true)
__check(onPlate and not onFrame, "preview default, nameplates on: badge on the nameplate only")
onPlate, onFrame = Preview(true, false, true, true, false)
__check(not onPlate and onFrame, "preview default, nameplates off: badge moves to the target frame")
onPlate, onFrame = Preview(false, false, true, true, true)
__check(not onPlate and onFrame, "preview nameplate badge off + fallback: badge on the target frame")
onPlate, onFrame = Preview(false, true, false, true, true)
__check(not onPlate and onFrame, "preview target frame only: badge on the target frame")
onPlate, onFrame = Preview(true, true, false, true, true)
__check(onPlate and onFrame, "preview both: badge on the nameplate and the target frame")
onPlate, onFrame = Preview(true, false, false, true, false)
__check(not onPlate and not onFrame, "preview nameplate only, nameplates off: nothing")
onPlate, onFrame = Preview(true, true, false, false, true)
__check(not onFrame, "preview not your target: no target frame badge")
Preview(true, false, true, true, true)

-- Each visual's page previews that visual alone, even while it's off.
local function Focus(page)
    ns.Options.SelectPage(page)
    return On(plateSet, "badge"), On(plateSet, "overhead"), On(frameSet, "badge"), On(frameSet, "overhead")
end
local pb, pm, fb, fm = Focus("npBadge")
__check(pb and not pm and not fb and not fm, "Nameplate > Badge page previews the nameplate badge only")
pb, pm, fb, fm = Focus("npMarker")
__check(not pb and pm and not fb and not fm, "Nameplate > Marker page previews the nameplate marker only")
pb, pm, fb, fm = Focus("tfBadge")
__check(not pb and not pm and fb and not fm, "Target frame > Badge page previews the target frame badge only")
p.targetMarker.fallback = false                         -- off on the Visibility page
ns.NotifySettingsChanged()
pb, pm, fb, fm = Focus("tfMarker")
__check(not pb and not pm and not fb and fm, "Target frame > Marker page previews its marker, even while it's off")
p.targetMarker.fallback = true
ns.NotifySettingsChanged()
pb, pm, fb, fm = Focus("visible")
__check(pb and fm == false and not fb, "Visibility page previews everything by the rules again")

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
eui.classFrame = CreateFrame("Frame", nil, eui)   -- its own Rare/Elite indicator
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
__check(eui.classFrame.__alpha == 0, "EllesmereUI: its own Rare/Elite icon is hidden on a marked mob")
p.hideNameplateIcons = false
ns.NotifySettingsChanged()
__check(eui.classFrame.__alpha == 1, "EllesmereUI: its own icon is back with the option off")
p.hideNameplateIcons = true
ns.NotifySettingsChanged()
__check(eui.classFrame.__alpha == 0, "EllesmereUI: hidden again with the option on")
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
__check(eui.classFrame.__alpha == 1, "EllesmereUI: removed plate gets its own icon back (its plates are pooled)")
EllesmereNameplates_NS = nil

-- Blizzard styles size and place like any other: drawn by atlas name at the
-- badge's size (the mock atlas is 2:1), not at the atlas's own size.
local function Badge(plate)
    for _, c in ipairs(plate.__children) do
        if rawget(c, "tex") and not rawget(c, "label") and c.__shown then return c end
    end
end
p.badge.style = "blizzIcon"
p.badge.size = 40
p.badge.point = "LEFT"
p.badge.x, p.badge.y = 7, -3
ns.NotifySettingsChanged()
local bz = Badge(rare)
__check(bz and bz.tex.__atlas == "nameplates-icon-rareelite", "Blizzard Nameplate Icon draws the rare atlas by name")
__check(bz and bz.__w == 80 and bz.__h == 40, "Blizzard style takes the badge size")
__check(bz and bz.__points[1][4] == 7 and bz.__points[1][5] == -3, "Blizzard style takes the badge offsets")
p.badge.size = 20
ns.NotifySettingsChanged()
bz = Badge(rare)
__check(bz and bz.__w == 40 and bz.__h == 20, "Blizzard style resizes")
p.badge.flip = true
ns.NotifySettingsChanged()
bz = Badge(rare)
__check(bz and bz.tex.__coords and bz.tex.__coords[1] == 0.5 and bz.tex.__coords[2] == 0.1, "Blizzard style mirrors with the atlas's own crop")
p.badge.flip = false

-- Background: a rectangle of its own size behind the art, with a border.
local bgs = p.badge.bg
bgs.enabled, bgs.width, bgs.height = true, 50, 30
ns.NotifySettingsChanged()
bz = Badge(rare)
__check(bz and bz.bg and bz.bg.__shown and bz.bg.__w == 50 and bz.bg.__h == 30, "background drawn at its own width and height")
__check(bz and bz.bgEdges[1].__shown and bz.bgEdges[4].__shown, "background border on")
-- Animations move the art only; the background stays put.
for _, kind in ipairs({ "pulse", "breathe", "bob" }) do
    p.badge.anim = kind
    ns.NotifySettingsChanged()
    bz = Badge(rare)
    local group = bz and bz.anims and bz.anims[kind]
    __check(group and group.__parent == bz.art and group.__playing, kind .. " animates the art frame")
end
__check(bz.bg.__parent == bz and bz.bgEdges[1].__parent == bz, "background and border live on the element, outside the animated art")
__check(bz.tex.__parent == bz.art and bz.glow.__parent == bz.art, "icon and glow live on the animated art")
p.badge.anim = "none"
ns.NotifySettingsChanged()
__check(bz and bz.bgEdges[1].__color[1] == bgs.borderColor.r, "border uses the border colour")
bgs.borderTint = true
ns.NotifySettingsChanged()
bz = Badge(rare)
local rc = p.classes.rare.color
__check(bz and bz.bgEdges[2].__color[1] == rc.r and bz.bgEdges[2].__color[3] == rc.b, "border tinted with the classification colour (rare)")
bgs.borderTint = false
bgs.border = false
ns.NotifySettingsChanged()
bz = Badge(rare)
__check(bz and not bz.bgEdges[1].__shown, "background border off")
bgs.color.r, bgs.alpha = 0.5, 0.25
ns.NotifySettingsChanged()
bz = Badge(rare)
__check(bz and bz.bg.__color[1] == 0.5 and bz.bg.__color[4] == 0.25, "background colour and opacity")
bgs.enabled = false
ns.NotifySettingsChanged()
bz = Badge(rare)
__check(bz and not bz.bg.__shown, "background off")
p.badge.style, p.badge.size, p.badge.x, p.badge.y = "wing", 26, 0, 0
bgs.border, bgs.color.r, bgs.alpha = true, 0.05, 0.7
ns.NotifySettingsChanged()

-- Target frame badge: for nameplates off or out of range.
local tfp, tfs = p.targetFrame, ns.TargetFrame.state
__check(p.badge.enabled and tfp.enabled == false and tfp.fallback == true and tfp.attach == "frame" and p.badge.where == nil, "visibility defaults: nameplate badge on, target frame as fallback")
local blizzTarget = CreateFrame("Button", "TargetFrame", UIParent)
__units.mob9 = { class = "elite", attackable = true }      -- no nameplate
__target = "mob9"
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.badge and tfs.anchor == "TargetFrame", "nameplates off: badge on Blizzard's target frame")
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
__check(tfs.badge and tfs.anchor == "EllesmereUIUnitFrames_Target", "EllesmereUI target frame used once shown")

-- EllesmereUI set to Blizzard's target frame: no frame of its own.
_G.EllesmereUIUnitFrames_Target = nil
blizzTarget:SetParent(UIParent)
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.anchor == "TargetFrame", "EllesmereUI on Blizzard's frame: Blizzard's target frame used")

-- Target with a nameplate that shows the badge: no doubling up by default.
__target = "nameplate2"
__Fire("PLAYER_TARGET_CHANGED")
__check(ns.TargetPlateBadgeShown() and not tfs.badge, "auto: target frame steps aside while the target's nameplate shows the badge")

-- The Visibility tab's switches, with the target's nameplate on screen.
local function PlateBadges(plate)
    local n = 0
    for _, c in ipairs(plate.__children) do
        if rawget(c, "tex") and not rawget(c, "label") and c.__shown then n = n + 1 end
    end
    return n
end
local function Vis(badge, frame, fallback)
    p.badge.enabled, tfp.enabled, tfp.fallback = badge, frame, fallback
    ns.NotifySettingsChanged()
end
Vis(true, true, false)
__check(tfs.badge and PlateBadges(rare) >= 1, "nameplate badge + target frame badge: both")
Vis(false, true, false)
__check(tfs.badge and PlateBadges(rare) == 0, "target frame badge only: no badge on any nameplate")
SlashCmdList.ELITEMOBVISUALS("test")
__check(PlateBadges(normal) == 0 and tfs.badge, "target frame badge only: test mode badges no nameplate either")
SlashCmdList.ELITEMOBVISUALS("test")
Vis(false, false, true)
__check(tfs.badge and PlateBadges(rare) == 0, "nameplate badge off + fallback: on the target frame")
Vis(true, false, false)
__check(not tfs.badge and PlateBadges(rare) >= 1, "nameplate badge only: never on the target frame")
__target = "mob9"                                           -- a target with no nameplate
__Fire("PLAYER_TARGET_CHANGED")
__check(not tfs.badge, "nameplate badge only: not on the target frame even with nameplates off")
__target = "nameplate2"
__Fire("PLAYER_TARGET_CHANGED")
Vis(false, false, false)
__check(not tfs.badge and PlateBadges(rare) == 0, "all off: nowhere")
Vis(true, false, true)
__check(not tfs.badge and PlateBadges(rare) >= 1, "defaults again: on the nameplate, not the target frame")

-- The target frame marker, set up on its own: steps in for the nameplate
-- marker, or shows alongside it when ticked.
local tmk = p.targetMarker
__check(not tmk.enabled and tmk.fallback, "target frame marker defaults: fallback only")
p.overhead.enabled, p.overhead.scope = true, "all"
ns.NotifySettingsChanged()
__check(ns.TargetPlateMarkerShown() and not tfs.marker, "nameplate marker showing: target frame marker steps aside")
p.overhead.enabled = false
ns.NotifySettingsChanged()
__check(tfs.marker, "nameplate marker off: target frame marker steps in")
p.overhead.enabled, tmk.enabled = true, true
ns.NotifySettingsChanged()
__check(tfs.marker and ns.TargetPlateMarkerShown(), "target frame marker ticked: shown alongside the nameplate marker")
tmk.enabled, tmk.fallback = false, false
ns.NotifySettingsChanged()
__check(not tfs.marker, "target frame marker off: never")
tmk.fallback = true
ns.NotifySettingsChanged()

-- Style per classification, per visual. The target frame visuals fall back
-- to their nameplate counterpart (per classification first).
local StyleFor = ns.Visuals.StyleFor
p.badge.classStyles.rare = "star"
ns.NotifySettingsChanged()
local rb = Badge(rare)
__check(rb and tostring(rb.tex.__texture):find("badge%-star"), "nameplate badge: rare uses its own style")
__check(StyleFor(p.badge, nil, "elite", false) == "wing", "nameplate badge: elite keeps the badge style")
__check(StyleFor(p.targetFrame, p.badge, "rare", false) == "star", "target frame badge inherits the nameplate badge's rare style")
p.targetFrame.classStyles.rare = "skull"
__check(StyleFor(p.targetFrame, p.badge, "rare", false) == "skull", "target frame badge: its own rare style wins")
p.targetFrame.style = "crown"
p.targetFrame.classStyles.rare = ""
__check(StyleFor(p.targetFrame, p.badge, "rare", false) == "crown", "target frame badge: its own style wins over the nameplate's per-class one")
p.overhead.classStyles.elite = "none"
__check(StyleFor(p.targetMarker, p.overhead, "elite", true) == "none", "target frame marker inherits text only from the nameplate marker")
__check(StyleFor(p.badge, nil, "rare", false) == "star" and StyleFor({ style = "none", classStyles = {} }, nil, "rare", false) == nil,
    "badges can't be text only")
p.badge.classStyles.rare, p.targetFrame.style, p.overhead.classStyles.elite = "", "", ""
ns.NotifySettingsChanged()

-- Out of nameplate range: the plate goes, the target frame badge takes over.
__Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
__check(tfs.badge, "target's nameplate removed: target frame badge shows")
__Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
__check(not tfs.badge, "target's nameplate back: target frame badge steps aside")

-- Free position, and its drag box while the options window is open.
__target = "mob9"
tfp.attach = "screen"
__Fire("PLAYER_TARGET_CHANGED")
__check(tfs.badge and tfs.anchor == "free position", "free position")
SlashCmdList.ELITEMOBVISUALS("")
__check(EliteMobVisualsTargetAnchor.bg:IsShown(), "drag box shows while the options are open")
SlashCmdList.ELITEMOBVISUALS("")
__check(not EliteMobVisualsTargetAnchor.bg:IsShown(), "drag box hides when the options close")
tfp.attach = "frame"

-- No target frame at all (EllesmereUI's set to hidden): the free position.
blizzTarget:SetParent(parked)
ns.NotifySettingsChanged()
__check(tfs.badge and tfs.anchor == "free position", "no target frame in use: falls back to the free position")
blizzTarget:SetParent(UIParent)

-- Friendly or unmarked targets, and no target.
__units.mob10 = { class = "normal", attackable = true }
__target = "mob10"
__Fire("PLAYER_TARGET_CHANGED")
__check(not tfs.badge, "normal target: nothing on the target frame")
SlashCmdList.ELITEMOBVISUALS("test")
__check(tfs.badge, "test mode marks the target on the target frame too")
SlashCmdList.ELITEMOBVISUALS("test")
__target = nil
__Fire("PLAYER_TARGET_CHANGED")
__check(not tfs.badge, "no target: nothing on the target frame")

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

-- Settings saved by earlier versions fold into the Visibility switches.
local function Migrated(saved)
    EliteMobVisualsDB = { profiles = { Default = saved } }
    local d = ns.DB.New("EliteMobVisualsDB", ns.DEFAULTS)
    ns.MigrateProfile(d.profile)
    return d.profile
end
local m1 = Migrated({ badge = { where = "nameplate" } })
__check(m1.badge.enabled and not m1.targetFrame.enabled and not m1.targetFrame.fallback and m1.badge.where == nil, "where=nameplate -> nameplate badge only")
local m2 = Migrated({ badge = { where = "frame" } })
__check(not m2.badge.enabled and m2.targetFrame.enabled, "where=frame -> target frame badge only")
local m3 = Migrated({ badge = { where = "both" } })
__check(m3.badge.enabled and m3.targetFrame.enabled, "where=both -> both")
local m4 = Migrated({ targetFrame = { mode = "always", size = 40 } })
__check(m4.targetFrame.enabled and m4.targetFrame.size == 40 and m4.targetFrame.mode == nil, "old mode=always -> target frame badge on, other settings kept")
local m6 = Migrated({ classes = { rare = { badgeStyle = "star", overheadStyle = "none" } } })
__check(m6.badge.classStyles.rare == "star" and m6.overhead.classStyles.rare == "none"
    and m6.classes.rare.badgeStyle == nil and m6.classes.rare.overheadStyle == nil,
    "old per-classification styles move to the nameplate visuals' own")
local m5 = Migrated({})
__check(m5.badge.enabled and not m5.targetFrame.enabled and m5.targetFrame.fallback, "nothing saved -> the defaults")

-- Slash help does not error.
SlashCmdList.ELITEMOBVISUALS("help")
__check(#__chat > 0, "chat output")
