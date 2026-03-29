-- ═══════════════════════════════════════════════════════════════════
-- Survival Hunter behavior (MoP 5.5.3)
--
-- Single-Target Priority:
--   1. Maintain Aspect of the Iron Hawk / Hawk (Pack OOC)
--   2. Kill Shot (scan all targets ≤20%, fallback to main)
--   3. Explosive Shot on CD
--   4. Explosive Trap (at target pos, lua path — only if not moving)
--   5. Glaive Toss on CD (talent)
--   6. Black Arrow on CD
--   7. A Murder of Crows (talent — prioritize ≤20%)
--   8. Dire Beast on CD (talent)
--   9. Maintain Serpent Sting
--  10. Stampede on CD
--  11. Rapid Fire on CD
--  12. Rabid (pet) on CD
--  13. Arcane Shot at 55+ focus (or Thrill of the Hunt proc)
--  14. Cobra Shot (filler)
--
-- AoE (>2 enemies within 10yd of target):
--   Explosive Trap > Explosive Shot (Lock and Load) > Multi-Shot >
--   Fervor > Dire Beast > Kill Shot > Black Arrow > Glaive Toss >
--   Cobra Shot
-- ═══════════════════════════════════════════════════════════════════

-- ── Menu options ────────────────────────────────────────────────

local options = {
  Name = "Hunter (Survival)",
  Widgets = {
    { type = "text",     text = "=== Cooldowns ===" },
    { type = "checkbox", uid = "SVUseRapidFire",
      text = "Use Rapid Fire",        default = true },
    { type = "checkbox", uid = "SVUseStampede",
      text = "Use Stampede",           default = true },
    { type = "checkbox", uid = "SVUseFervor",
      text = "Use Fervor",             default = true },

    { type = "text",     text = "=== Focus Management ===" },
    { type = "slider",   uid = "SVArcaneShotMinFocus",
      text = "Arcane Shot min focus",  default = 55, min = 30, max = 100 },
    { type = "slider",   uid = "SVFervorThreshold",
      text = "Fervor below focus %",   default = 50, min = 10, max = 80 },

    { type = "text",     text = "=== Interrupts ===" },
    { type = "checkbox", uid = "SVUseCounterShot",
      text = "Use Counter Shot",       default = true },

    { type = "text",     text = "=== Utility ===" },
    { type = "checkbox", uid = "SVAutoAspects",
      text = "Auto Aspect (Iron Hawk in combat, Pack OOC)", default = true },
    { type = "checkbox", uid = "SVUseMastersCall",
      text = "Use Master's Call (root/snare removal)", default = true },
    { type = "checkbox", uid = "SVUseMisdirection",
      text = "Use Misdirection (aggro to tank)",       default = true },
    { type = "checkbox", uid = "SVSpreadSerpentSting",
      text = "Spread Serpent Sting (multi-dot)", default = true },

    { type = "text",     text = "=== AoE ===" },
    { type = "checkbox", uid = "SVAoeEnabled",
      text = "Use AoE rotation",               default = true },
    { type = "slider",   uid = "SVAoeCount",
      text = "AoE mob threshold",              default = 2, min = 1, max = 10 },
    { type = "slider",   uid = "SVAoeRange",
      text = "AoE detection range (yards)",    default = 10, min = 5, max = 40 },
  },
}

-- ── Helpers ────────────────────────────────────────────────────

--- Returns true if any combat target is targeting the player.
local function MobsTargetingMe()
  for _, enemy in ipairs(Combat.Targets or {}) do
    local enemyTarget = enemy:GetTarget()
    if enemyTarget and enemyTarget.Guid == Me.Guid then
      return true
    end
  end
  return false
end

--- Finds the group's tank unit, or nil if none.
local function GetTank()
  for _, v in ipairs(Heal.PriorityList or {}) do
    if v.Unit and not v.Unit.IsDead and v.Unit:IsTank() and v.Unit.Guid ~= Me.Guid then
      return v.Unit
    end
  end
  return nil
end

--- Returns true if the player has an active ROOT or SNARE loss-of-control effect.
local function IsRootedOrSnared()
  local count = game.loss_of_control_count(Me.obj_ptr)
  if count == 0 then return false end
  for i = 1, count do
    local loc = game.loss_of_control_info(Me.obj_ptr, i)
    if loc and (loc.locType == "ROOT" or loc.locType == "SNARE") then
      return true
    end
  end
  return false
end

local function SpreadSerpentSting(target)
  if not Spell.SerpentSting.IsKnown then return false end
  for _, u in ipairs(Combat.Targets or {}) do
    if not u:HasAura("Serpent Sting") then
      local ok, visible = pcall(game.is_visible, Me.obj_ptr, u.obj_ptr, 0x03)
      if ok and visible then
        if Spell.SerpentSting:CastEx(u) then return true end
      end
    end
  end
  return false
end

-- ── Aspect management (runs every tick, regardless of target/combat) ──

local function SurvivalExtra()
  if not PallasSettings.SVAutoAspects then return end

  local anyone_in_combat = false
  for _, v in ipairs(Heal.PriorityList or {}) do
    if v.Unit and not v.Unit.IsDead and v.Unit.InCombat then
      anyone_in_combat = true
      break
    end
  end

  if anyone_in_combat then
    if not Me:HasAura("Aspect of the Iron Hawk") and not Me:HasAura("Aspect of the Hawk") then
      if not Spell.AspectOfTheIronHawk:CastEx(Me) then
        Spell.AspectOfTheHawk:CastEx(Me)
      end
    end
  else
    if not Me:HasAura("Aspect of the Pack") then
      Spell.AspectOfThePack:CastEx(Me)
    end
  end
end

-- ── Main rotation ──────────────────────────────────────────────

local function SurvivalCombat()

  local target = Combat.BestTarget
  if not target then return end

  -- Fervor (talent — instant 50 focus when starved)
  if PallasSettings.SVUseFervor and Me.PowerPct < (PallasSettings.SVFervorThreshold or 50) then
    if Spell.Fervor:CastEx(Me) then return end
  end

  -- Auto-range
  if not Me:IsAutoRanging() then
    Me:StartRanging(target)
  end

  if Me:IsCastingOrChanneling() then return end

  -- Counter Shot — interrupt enemy casts (off-GCD check)
  if PallasSettings.SVUseCounterShot then
    if Spell.CounterShot:Interrupt() then return end
  end

  -- Master's Call — break roots/snares on the player
  if PallasSettings.SVUseMastersCall and IsRootedOrSnared() then
    if Spell.MastersCall:CastEx(Me) then return end
  end

  -- Misdirection — redirect threat to tank if mobs are targeting me
  if PallasSettings.SVUseMisdirection and not Me:HasAura("Misdirection") and MobsTargetingMe() then
    local tank = GetTank()
    if tank then
      if Spell.Misdirection:CastEx(tank) then return end
    end
  end

  if Spell:IsGCDActive() then return end

  -- Determine AoE
  local use_aoe = false
  if PallasSettings.SVAoeEnabled then
    local aoe_range = PallasSettings.SVAoeRange or 10
    local aoe_count = PallasSettings.SVAoeCount or 2
    local nearby_target = Combat:GetTargetsAround(target, aoe_range)
    use_aoe = nearby_target > aoe_count
  end

  -- ── Priority list (MoP 5.5.3 Survival) ────────────────────

  if use_aoe then
    -- ── AoE priority ───────────────────────────────────────

    -- Explosive Trap (ground-targeted via lua path for Trap Launcher)
    if Spell.ExplosiveTrap:CastAtPosLuaPath(target) then return end

    -- Explosive Shot (Lock and Load procs)
    if Me.Power >= 65 and Spell.ExplosiveShot:CastEx(target) then return end

    -- Multi-Shot as main AoE spender
    if Spell.Multishot:CastEx(target) then return end

    -- Glaive Toss
    if Spell.GlaiveToss:CastEx(target) then return end

    -- Dire Beast
    if Spell.DireBeast:CastEx(target) then return end

    -- Kill Shot (execute — prioritize ≤20% HP, fallback to main target)
    for _, ks_target in ipairs(Combat.Targets) do
      if not ks_target.IsDead and ks_target.HealthPct <= 20 then
        if Spell.KillShot:CastEx(ks_target) then return end
      end
    end
    if Spell.KillShot:CastEx(target) then return end

    -- Black Arrow (still worth keeping up in AoE for L&L)
    if Spell.BlackArrow:CastEx(target) then return end

    -- Cobra Shot (filler)
    Spell.CobraShot:CastEx(target)
    return
  end

  -- ── Single-target priority ─────────────────────────────

  -- 2. Kill Shot (execute — prioritize ≤20% HP, fallback to main target)
  for _, ks_target in ipairs(Combat.Targets) do
    if not ks_target.IsDead and ks_target.HealthPct <= 20 then
      if Spell.KillShot:CastEx(ks_target) then return end
    end
  end
  if Spell.KillShot:CastEx(target) then return end

  -- 3. Explosive Shot (also consumes Lock and Load)
  if Spell.ExplosiveShot:CastEx(target) then return end

  -- 4. Explosive Trap (only if target is stationary)
  if not target:IsMoving() then
    if Spell.ExplosiveTrap:CastAtPosLuaPath(target) then return end
  end

  -- 5. Glaive Toss (talent)
  if Spell.GlaiveToss:CastEx(target) then return end

  -- 6. Black Arrow on CD
  if Spell.BlackArrow:CastEx(target) then return end

  -- 7. A Murder of Crows (talent — scan all targets for ≤20% HP, else main target)
  for _, amoc_target in ipairs(Combat.Targets) do
    if not amoc_target.IsDead and amoc_target.HealthPct <= 20 then
      if Spell.AMurderOfCrows:CastEx(amoc_target) then return end
    end
  end
  if Spell.AMurderOfCrows:CastEx(target) then return end

  -- 8. Dire Beast (talent)
  if Spell.DireBeast:CastEx(target) then return end

  -- 9. Maintain Serpent Sting
  if PallasSettings.SVSpreadSerpentSting then
    if SpreadSerpentSting(target) then return end
  elseif not target:HasAura("Serpent Sting") then
    if Spell.SerpentSting:CastEx(target) then return end
  end

  -- 10. Stampede on CD
  if PallasSettings.SVUseStampede then
    if Spell.Stampede:CastEx(Me) then return end
  end

  -- 11. Rapid Fire on CD
  if PallasSettings.SVUseRapidFire then
    if Spell.RapidFire:CastEx(Me) then return end
  end

  -- 12. Rabid (pet) on CD
  if Spell.Rabid:CastEx(Me) then return end

  -- 13. Arcane Shot at focus threshold (or Thrill of the Hunt proc)
  if Me:HasAura("Thrill of the Hunt") or Me.Power >= (PallasSettings.SVArcaneShotMinFocus or 55) then
    if Spell.ArcaneShot:CastEx(target) then return end
  end

  -- 13. Cobra Shot (filler / focus generator)
  Spell.CobraShot:CastEx(target)
end

-- ── Export ───────────────────────────────────────────────────

local behaviors = {
  [BehaviorType.Combat] = SurvivalCombat,
  [BehaviorType.Extra]  = SurvivalExtra,
}

return { Options = options, Behaviors = behaviors }
