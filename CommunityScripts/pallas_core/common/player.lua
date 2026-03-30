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
---@return boolean - true if the player is auto-attacking, false otherwise
function Player:IsAutoAttacking()
  return game.is_current_spell(6603)
end

-- Check if the player is currently auto-ranging
---@return boolean - true if the player is auto-ranging, false otherwise
function Player:IsAutoRanging()
  return Spell.AutoShot:IsAutoRepeat()
end

-- Stop any ongoing casting
---@return void
function Player:StopCasting()
  game.stop_casting()
end

-- Cancel a player aura/buff by spell ID or name.
---@param name_or_id number|string - Spell ID or aura name to cancel
---@return boolean - true if the cancel was queued
function Player:CancelAura(name_or_id)
  local spell_id
  if type(name_or_id) == "number" then
    spell_id = name_or_id
  else
    local aura = self:GetAura(name_or_id)
    if not aura then return false end
    spell_id = aura.spell_id
  end
  if not spell_id or spell_id == 0 then return false end
  local ok, result = pcall(game.cancel_aura, spell_id)
  return ok and result or false
end

-- Set the current target to a unit
---@param target Unit - The unit to target
---@return boolean - true if the target was set successfully
function Player:SetTarget(target)
  if not target or not target.obj_ptr then
    return false
  end
  local ok, result = pcall(game.set_target, target.obj_ptr)
  return ok and result or false
end

-- Clear the current target
---@return void
function Player:ClearTarget()
  pcall(game.clear_target)
end

-- Start auto-attacking a target
---@param target Unit - The target to attack
---@return boolean - true if the attack was started, false otherwise
function Player:StartAttack(target)
  return Spell.AutoAttack:CastEx(target)
end

-- Start Ranging a target
---@param target Unit - The target to range
---@return boolean - true if the range was started, false otherwise
function Player:StartRanging(target)
  return Spell.AutoShot:CastEx(target)
end

return Player
