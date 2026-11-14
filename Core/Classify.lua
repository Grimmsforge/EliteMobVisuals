-- =============================================================================
-- Elite Mob Visuals: which units get marked
-- Every unit read goes through ns.Readable, so a secret value (12.x engine)
-- never errors: it reads as nil and the check fails closed.
-- =============================================================================
local _, ns = ...
local Readable = ns.Readable

local UnitExists, UnitClassification, UnitIsPlayer = UnitExists, UnitClassification, UnitIsPlayer
local UnitCanAttack, UnitIsDead, UnitAffectingCombat = UnitCanAttack, UnitIsDead, UnitAffectingCombat

local Classify = {}
ns.Classify = Classify

-- Test mode marks every non-player nameplate as this classification, so the
-- visuals can be positioned without finding an elite. Session only.
Classify.testClass = nil

-- The unit's marked classification ("elite", "rareelite", "rare",
-- "worldboss"), or nil. A unit seen for the first time can read "normal" until
-- its data arrives; the controller re-checks on UNIT_NAME_UPDATE.
function Classify.Get(unit)
    if not unit or Readable(UnitExists(unit)) ~= true then return nil end
    if Classify.testClass then
        if Readable(UnitIsPlayer(unit)) == true then return nil end
        return Classify.testClass
    end
    local c = Readable(UnitClassification(unit))
    if c and ns.IS_MARKED[c] then return c end
    return nil
end

-- The profile's unit filters: hostility, death and combat.
function Classify.Passes(unit, profile)
    if profile.combatOnly and Readable(UnitAffectingCombat("player")) ~= true then
        return false
    end
    if profile.hostileOnly and not Classify.testClass then
        if Readable(UnitCanAttack("player", unit)) ~= true then return false end
    end
    if profile.hideDead and Readable(UnitIsDead(unit)) == true then
        return false
    end
    return true
end
