-- Player wrapper — extends Unit with player-specific functionality.
-- Inherits all Unit methods and adds player-only functions.
-- Unit is loaded as a global by the plugin.

local Player = {}
Player.__index = Player
setmetatable(Player, { __index = Unit })

function Player:New(entity)
  local unit = Unit:New(entity)
  if not unit then
    return nil
  end

  -- Set the metatable to Player so player-specific methods are available
  setmetatable(unit, Player)

  return unit
end

-- Check if the player is currently auto-attacking
-- Spell ID 6603 is "Auto Attack"
function Player:IsAutoAttacking()
  return game.is_current_spell(6603)
end

-- Check if the player is currently auto-ranging
-- Spell ID 75 is "Auto Shot"
function Player:IsAutoRanging()
  return game.is_current_spell(75)
end

-- Stop any ongoing casting
function Player:StopCasting()
  game.stop_casting()
end

-- Start auto-attacking a target
/*
@param target Unit - The target to attack
@return boolean - true if the attack was started, false otherwise
*/
function Player:StartAttack(target)
  return Spell.AutoAttack:CastEx(target)
end

-- Start Ranging a target
/*
@param target Unit - The target to range
@return boolean - true if the range was started, false otherwise
*/
function Player:StartRanging(target)
  return Spell.AutoShot:CastEx(target)
end

return Player
