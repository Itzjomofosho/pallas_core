-- Combat targeting system (mirrors Pallas system/combat.lua).
--
-- Collects enemy units each tick, filters, and ranks them by priority.
-- Behaviors read Combat.BestTarget and Combat.EnemiesInMeleeRange.

Combat                     = Combat or Targeting:New()

Combat.BestTarget          = nil
Combat.EnemiesInMeleeRange = 0
Combat.Enemies             = 0

function Combat:Update()
  Targeting.Update(self)
  
  -- Auto-target functionality: if we don't have a target and auto-target is enabled, target the best target
  if PallasSettings.PallasAutoTarget and Me and not Me.Target then
    if self.BestTarget and self.BestTarget:validTarget() then
      Me:SetTarget(self.BestTarget)
    end
  end
end

function Combat:Reset()
  self.BestTarget          = nil
  self.EnemiesInMeleeRange = 0
  self.Enemies             = 0
  self.Targets             = {}
end

function Combat:WantToRun()
  if not Behavior:HasBehavior(BehaviorType.Combat) then return false end
  if not Me then return false end
  if Me.IsMounted then return false end
  return PallasSettings.PallasAttackOOC or Me.InCombat
end

function Combat:CollectTargets()
  if not Me.InCombat and PallasSettings.PallasAttackOOC then
    local tgt = Me.Target
    if tgt and tgt:validTarget() then
      self.Targets[#self.Targets + 1] = tgt
    end

    return
  end

  -- Pre-filter on raw entity data to avoid wrapping hundreds of irrelevant entities.
  local entities = Pallas._entity_cache or {}
  local mx, my, mz
  if Me.Position then
    mx, my, mz = Me.Position.x, Me.Position.y, Me.Position.z
  end

  for _, e in ipairs(entities) do
    local cls = e.class
    if cls ~= "Unit" and cls ~= "Player" then goto skip end

    local eu = e.unit
    if not eu then goto skip end
    if eu.is_dead then goto skip end
    if eu.health and eu.health <= 0 then goto skip end
    if not eu.in_combat then
      -- Only allow out-of-combat units if they are the current target and AttackOOC is enabled
      local is_current_target = Me.Target and Me.Target.Guid == eu.guid
      if not (PallasSettings.PallasAttackOOC and is_current_target) then
        goto skip
      end
    end
    if not game.unit_can_attack(e.obj_ptr) then goto skip end

    -- Cheap squared-distance check (40yd = 1600 sq)
    if mx and e.position then
      local dx = mx - e.position.x
      local dy = my - e.position.y
      local dz = mz - e.position.z
      if dx * dx + dy * dy + dz * dz > 1600 then goto skip end
    end

    self.Targets[#self.Targets + 1] = Unit:New(e)

    ::skip::
  end
end

-- Traceline flags: terrain (0x01) + buildings/WMO (0x02).
-- Excludes models/doodads so creature geometry doesn't block the check.
local LOS_FLAGS = 0x03

function Combat:ExclusionFilter()
  local my_tgt_guid = Me.Target and Me.Target.Guid or ""
  local keep = {}
  for _, u in ipairs(self.Targets) do
    if not u or not u:validTarget() then goto skip_ex end

    -- Check if unit is attackable, dead, or out of range
    if not u:IsAttackable() then goto skip_ex end
    if u:DeadOrGhost() or u.Health <= 1 then goto skip_ex end
    if Me:GetDistance(u) >= 40 then goto skip_ex end
    if u:IsImmune() then goto skip_ex end

    -- Exempt current target when AttackOOC is enabled
    if u.Guid == my_tgt_guid and PallasSettings.PallasAttackOOC then
      keep[#keep + 1] = u
      goto skip_ex
    end

    -- Check if unit is in combat with player or party
    if not u.InCombat and not u:isUnitInCombatWithParty(u) then
      goto skip_ex
    end

    keep[#keep + 1] = u
    ::skip_ex::
  end
  self.Targets = keep
end

function Combat:InclusionFilter()
  if not PallasSettings.PallasAttackTarget then return end

  -- Don't add targets when out of combat with AttackOOC enabled
  if not Me.InCombat and PallasSettings.PallasAttackOOC then return end

  local tgt = Me.Target
  if not tgt then return end

  for _, u in ipairs(self.Targets) do
    if u.Guid == tgt.Guid then return end
  end

  if not tgt:validTarget() then return end
  if tgt:IsImmune() then return end
  self.Targets[#self.Targets + 1] = tgt
end

function Combat:WeighFilter()
  local priority_list = {}
  local tgt_guid = Me.Target and Me.Target.Guid or ""
  for _, u in ipairs(self.Targets) do
    local priority = 0
    self.Enemies = self.Enemies + 1

    if Me:InMeleeRange(u) then
      self.EnemiesInMeleeRange = self.EnemiesInMeleeRange + 1
    end

    if tgt_guid == u.Guid then
      priority = priority + 50
    end

    priority_list[#priority_list + 1] = { Unit = u, Priority = priority }
  end

  table.sort(priority_list, function(a, b) return a.Priority > b.Priority end)
  if #priority_list == 0 then return end

  self.BestTarget = priority_list[1].Unit
end

function Combat:GetEnemiesWithinDistance(dist)
  local count = 0
  for _, u in ipairs(self.Targets) do
    if Me:GetDistance(u) <= dist then count = count + 1 end
  end
  return count
end

function Combat:GetTargetsAround(unit, distance)
  local count = 0
  for _, u in ipairs(self.Targets) do
    if unit:GetDistance(u) <= distance then count = count + 1 end
  end
  return count
end

return Combat
