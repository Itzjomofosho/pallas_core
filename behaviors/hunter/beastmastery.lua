-- ═══════════════════════════════════════════════════════════════════
-- Jmr-BM — Beast Mastery Hunter behavior (MoP 5.5.3)
--
-- Pre-GCD (off-GCD abilities, checked every tick):
--   - Counter Shot interrupt
--   - Master's Call (root/snare removal)
--   - Misdirection (aggro to tank > pet)
--   - Rapid Fire (skip during Lust, gated on TTD > 20s)
--   - On-use trinkets (sync with Bestial Wrath)
--   - Rabid (pet CD)
--   - Tranquilizing Shot (auto-purge)
--
-- Burst Window (Bestial Wrath active):
--   1. Beast Cleave (Multi-Shot if buff missing, AoE/Cleave)
--   2. Kill Command
--   3. Kill Shot (execute scan all targets ≤20%)
--   4. Glaive Toss / A Murder of Crows
--   5. Arcane Shot (focus dump, low threshold during BW)
--   6. Cobra Shot only if focus-starved
--
-- Single-Target Priority:
--   1. Kill Command (delay if BW about to come off CD)
--   2. Kill Shot (execute scan all targets ≤20%)
--   3. Glaive Toss (skip if KC imminent)
--   4. A Murder of Crows (TTD-gated, execute scan)
--   5. Fervor if ≤50 focus (check pet focus too)
--   6. Cobra Shot if Serpent Sting <6s remaining
--   7. Arcane Shot (smart focus conservation for BW/AMoC/KC)
--   8. Cobra Shot (filler, skip if KC imminent, focus cap)
--
-- Cleave (2 targets):
--   1. Beast Cleave maintenance (Multi-Shot)
--   2. Kill Command
--   3. Kill Shot (execute scan)
--   4. Glaive Toss
--   5. A Murder of Crows
--   6. Arcane Shot (surplus focus)
--   7. Cobra Shot (filler)
--
-- AoE (3+ targets):
--   1. Multi-Shot if Beast Cleave not active on pet
--   2. Kill Command if <5 targets
--   3. Kill Shot (execute scan)
--   4. Glaive Toss
--   5. Fervor if ≤50 focus
--   6. Multi-Shot (Beast Cleave refresh / focus dump)
--   7. Cobra Shot (filler, focus cap)
-- ═══════════════════════════════════════════════════════════════════

-- ── Menu options ────────────────────────────────────────────────

local options = {
  Name = "Hunter (Beast Mastery)",
  Widgets = {
    { type = "text",     text = "=== Cooldowns ===" },
    { type = "checkbox", uid = "BMUseStampede",
      text = "Use Stampede",       default = true },
    { type = "checkbox", uid = "BMSyncStampede",
      text = "Sync Stampede with BW / RF / Heroism", default = true },
    { type = "checkbox", uid = "BMUseRapidFire",
      text = "Use Rapid Fire",     default = true },
    { type = "checkbox", uid = "BMAvoidRFHeroism",
      text = "Avoid Rapid Fire during Heroism", default = true },
    { type = "checkbox", uid = "BMUseBestialWrath",
      text = "Use Bestial Wrath",  default = true },
    { type = "checkbox", uid = "BMUseFervor",
      text = "Use Fervor",         default = true },
    { type = "checkbox", uid = "BMUseDireBeast",
      text = "Use Dire Beast",     default = true },
    { type = "checkbox", uid = "BMUseAMoC",
      text = "A Murder of Crows",  default = true },
    { type = "checkbox", uid = "BMUseTrinkets",
      text = "Use on-use trinkets with Bestial Wrath", default = true },

    { type = "text",     text = "=== Focus Management ===" },
    { type = "slider",   uid = "BMArcaneShotMinFocus",
      text = "Arcane Shot min focus",  default = 65, min = 30, max = 100 },
    { type = "slider",   uid = "BMFervorThreshold",
      text = "Fervor below focus",     default = 50, min = 10, max = 80 },
    { type = "slider",   uid = "BMBWMinFocus",
      text = "Bestial Wrath min focus", default = 80, min = 30, max = 100 },
    { type = "slider",   uid = "BMCobraShotFocusCap",
      text = "Cobra Shot focus cap (skip above)", default = 80, min = 50, max = 100 },

    { type = "text",     text = "=== Interrupts ===" },
    { type = "checkbox", uid = "BMUseCounterShot",
      text = "Use Counter Shot",       default = true },

    { type = "text",     text = "=== Pet ===" },
    { type = "checkbox", uid = "BMMendPet",
      text = "Auto Mend Pet",          default = true },
    { type = "slider",   uid = "BMMendPetHP",
      text = "Mend Pet HP %",          default = 60, min = 20, max = 90 },
    { type = "checkbox", uid = "BMAutoMisdirect",
      text = "Auto Misdirection (tank > pet)", default = true },

    { type = "text",     text = "=== Utility ===" },
    { type = "checkbox", uid = "BMUseMastersCall",
      text = "Use Master's Call (root/snare removal)", default = true },
    { type = "checkbox", uid = "BMUseTranqShot",
      text = "Use Tranquilizing Shot (auto-purge)", default = true },
    { type = "checkbox", uid = "BMUseExhilaration",
      text = "Use Exhilaration (self-heal)",        default = true },
    { type = "slider",   uid = "BMExhilPlayerHP",
      text = "Exhilaration player HP %",            default = 50, min = 10, max = 80 },
    { type = "slider",   uid = "BMExhilPetHP",
      text = "Exhilaration pet HP %",               default = 20, min = 5,  max = 50 },

    { type = "text",     text = "=== AoE ===" },
    { type = "checkbox", uid = "BMAoeEnabled",
      text = "Use AoE rotation (Multi-Shot / Beast Cleave)", default = true },
    { type = "slider",   uid = "BMAoeCount",
      text = "AoE target threshold",  default = 3, min = 2, max = 8 },
    { type = "slider",   uid = "BMAoeRange",
      text = "AoE detection range (yards)", default = 10, min = 5, max = 40 },
    { type = "checkbox", uid = "BMCleaveEnabled",
      text = "Use Cleave rotation (2 targets)", default = true },
  },
}

local function S(uid)
  return PallasSettings[uid] ~= false
end

-- ── Constants ──────────────────────────────────────────────────

local FOCUS_FIRE_FRENZY_STACKS = 5
local SERPENT_STING_REFRESH    = 6
local EXECUTE_PCT              = 20
local AOE_KC_CAP               = 5

-- ── Helpers ────────────────────────────────────────────────────

local function AuraRemaining(unit, name_or_id)
  local a = unit:GetAura(name_or_id)
  if not a then return 0 end
  return a.remaining or 0
end

local function InBurstWindow()
  return Me:HasAura("Bestial Wrath")
end

local function HasBeastCleave()
  local pet = Pet.GetPrimary()
  if not pet then return false end
  return pet:HasAura("Beast Cleave")
end

local function HasHasteBuff()
  return Me:HasAura("Bloodlust") or Me:HasAura("Heroism")
      or Me:HasAura("Time Warp") or Me:HasAura("Ancient Hysteria")
end

local function HasRapidFire()
  return Me:HasAura("Rapid Fire")
end

--- Cooldown remaining helper. Returns seconds remaining, 0 if ready.
local function cd_remaining(spell)
  if not spell or not spell.IsKnown then return 999 end
  local cd = spell:GetCooldown()
  if not cd or not cd.on_cooldown then return 0 end
  return cd.remaining or 0
end

--- TTD for the primary target (updated each tick).
local function UpdateTargetTTD(target)
  if not TTD or not target then return end
  TTD.Update(target)
  TTD.Cleanup()
end

local function GetTargetTTD(target)
  if not TTD or not target then return 999 end
  return TTD.Get(target)
end

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

--- Kill Shot scanning: finds any execute-eligible target (≤20% HP).
local function TryKillShot()
  for _, ks_target in ipairs(Combat.Targets or {}) do
    if not ks_target.IsDead and ks_target.HealthPct <= EXECUTE_PCT then
      if Spell.KillShot:CastEx(ks_target) then return true end
    end
  end
  return false
end

-- ── Mend Pet ───────────────────────────────────────────────────

local function TryMendPet()
  if not S("BMMendPet") then return false end
  if not Spell.MendPet or not Spell.MendPet.IsKnown then return false end

  local pet = Pet.GetPrimary()
  if not pet then return false end
  if pet.HealthPct >= (PallasSettings.BMMendPetHP or 60) then return false end
  if pet:HasAura("Mend Pet") then return false end

  if Spell.MendPet:CastEx(pet) then return true end
  return false
end

-- ── Exhilaration ──────────────────────────────────────────────

local function TryExhilaration()
  if not S("BMUseExhilaration") then return false end
  if not Spell.Exhilaration or not Spell.Exhilaration.IsKnown then return false end

  local pet = Pet.GetPrimary()
  local player_low = Me.HealthPct < (PallasSettings.BMExhilPlayerHP or 50)
  local pet_low = pet and not pet.IsDead and pet.HealthPct < (PallasSettings.BMExhilPetHP or 20)
  if player_low or pet_low then
    if Spell.Exhilaration:CastEx(Me) then return true end
  end
  return false
end

-- ── Misdirection ───────────────────────────────────────────────

local function TryMisdirection()
  if not S("BMAutoMisdirect") then return false end
  if not Spell.Misdirection or not Spell.Misdirection.IsKnown then return false end
  if not Spell.Misdirection:IsReady() then return false end
  if Me:HasAura("Misdirection") then return false end
  if not MobsTargetingMe() then return false end

  -- Prefer tank in group, fall back to pet
  local tank = GetTank()
  if tank then
    if Spell.Misdirection:CastEx(tank) then return true end
  end
  local pet = Pet.GetPrimary()
  if pet then
    if Spell.Misdirection:CastEx(pet) then return true end
  end
  return false
end

-- ── Burst rotation (inside Bestial Wrath) ─────────────────────

local function BurstRotation(target, use_aoe, use_cleave)
  -- Maintain Beast Cleave in AoE/Cleave
  if (use_aoe or use_cleave) and not HasBeastCleave() then
    if Spell.Multishot:CastEx(target) then return true end
  end

  -- Kill Command is king during BW — always top priority
  if Spell.KillCommand:CastEx(target) then return true end

  -- Kill Shot (execute scan all targets)
  if TryKillShot() then return true end

  if Spell.GlaiveToss:CastEx(target) then return true end

  -- A Murder of Crows during burst (execute scan for CD reset)
  if S("BMUseAMoC") and Spell.AMurderOfCrows and Spell.AMurderOfCrows.IsKnown then
    -- Execute priority: scan all targets for ≤20% HP (CD resets on kill)
    for _, u in ipairs(Combat.Targets or {}) do
      if not u.IsDead and u.HealthPct <= EXECUTE_PCT then
        if Spell.AMurderOfCrows:CastEx(u) then return true end
      end
    end
    if not target:HasAura("A Murder of Crows") then
      if Spell.AMurderOfCrows:CastEx(target) then return true end
    end
  end

  -- Focus dump: Arcane Shot at LOW threshold during BW (any focus >= 20)
  if use_aoe or use_cleave then
    if Spell.Multishot:CastEx(target) then return true end
  else
    if Me.Power >= 20 then
      if Spell.ArcaneShot:CastEx(target) then return true end
    end
  end

  -- Cobra Shot only if we absolutely need focus
  if Me.Power < 30 then
    if Spell.CobraShot:CastEx(target) then return true end
  end

  return false
end

-- ── AoE rotation (3+ targets) ───────────────────────────────────

local function AoeRotation(target, aoe_count)
  -- Explosive Trap (ground-targeted via lua path for Trap Launcher)
  if Spell.ExplosiveTrap:CastAtPosLuaPath(target) then return true end

  -- Maintain Beast Cleave
  if not HasBeastCleave() then
    if Spell.Multishot:CastEx(target) then return true end
  end

  if aoe_count < AOE_KC_CAP then
    if Spell.KillCommand:CastEx(target) then return true end
  end

  -- Kill Shot (execute scan all targets)
  if TryKillShot() then return true end

  if Spell.GlaiveToss:CastEx(target) then return true end

  -- Fervor — check both player and pet focus
  if S("BMUseFervor") then
    local pet = Pet.GetPrimary()
    local pet_low = pet and (pet.Power or 100) <= 50
    if Me.Power <= (PallasSettings.BMFervorThreshold or 50) or pet_low then
      if Spell.Fervor:CastEx(Me) then return true end
    end
  end

  -- Multi-Shot (Beast Cleave refresh / focus dump)
  -- Skip if BW is about to come off CD (conserve for burst)
  local bw_cd = cd_remaining(Spell.BestialWrath)
  local conserve_for_bw = S("BMUseBestialWrath") and bw_cd > 0 and bw_cd < 3 and Me.Power < 60
  if not conserve_for_bw then
    if Spell.Multishot:CastEx(target) then return true end
  end

  -- Cobra Shot (filler, focus cap)
  if Me.Power < (PallasSettings.BMCobraShotFocusCap or 80) then
    Spell.CobraShot:CastEx(target)
  end
  return false
end

-- ── Cleave rotation (2 targets) ─────────────────────────────────

local function CleaveRotation(target)
  local bw_cd = cd_remaining(Spell.BestialWrath)
  local kc_cd = cd_remaining(Spell.KillCommand)

  -- Maintain Beast Cleave
  if not HasBeastCleave() then
    if Spell.Multishot:CastEx(target) then return true end
  end

  -- Kill Command
  local delay_kc_for_bw = S("BMUseBestialWrath")
      and bw_cd > 0 and bw_cd < 2 and not InBurstWindow()
  if not delay_kc_for_bw then
    if Spell.KillCommand:CastEx(target) then return true end
  end

  -- Kill Shot (execute scan all targets)
  if TryKillShot() then return true end

  -- Glaive Toss
  if kc_cd > 0.7 then
    if Spell.GlaiveToss:CastEx(target) then return true end
  end

  -- A Murder of Crows (execute scan for CD reset, then beefy targets)
  if S("BMUseAMoC") and Spell.AMurderOfCrows and Spell.AMurderOfCrows.IsKnown then
    for _, u in ipairs(Combat.Targets or {}) do
      if not u.IsDead and u.HealthPct <= EXECUTE_PCT then
        if Spell.AMurderOfCrows:CastEx(u) then return true end
      end
    end
    local ttd = GetTargetTTD(target)
    if ttd > 15 and not target:HasAura("A Murder of Crows") then
      if Spell.AMurderOfCrows:CastEx(target) then return true end
    end
  end

  -- Fervor — check both player and pet focus
  if S("BMUseFervor") and not InBurstWindow() then
    local pet = Pet.GetPrimary()
    local pet_low = pet and (pet.Power or 100) <= 50
    if Me.Power <= (PallasSettings.BMFervorThreshold or 50) or pet_low then
      if Spell.Fervor:CastEx(Me) then return true end
    end
  end

  -- Multi-Shot with surplus focus (Beast Cleave refresh)
  if Me:HasAura("Thrill of the Hunt") or Me.Power >= 55 then
    local conserve_for_bw = S("BMUseBestialWrath") and bw_cd > 0 and bw_cd < 3
    if not conserve_for_bw then
      if Spell.Multishot:CastEx(target) then return true end
    end
  end

  -- Arcane Shot (smart focus conservation)
  local conserve_for_bw = S("BMUseBestialWrath") and bw_cd > 0 and bw_cd < 3
  if not conserve_for_bw then
    local as_thresh = PallasSettings.BMArcaneShotMinFocus or 65
    if Me:HasAura("Thrill of the Hunt") then
      -- Skip TotH Arcane if KC is about to be ready and focus is tight
      if kc_cd < 0.5 and Me.Power < 50 then
        as_thresh = 999 -- block
      else
        as_thresh = 40
      end
    end
    -- Hold for AMoC execute reset
    if S("BMUseAMoC") and Spell.AMurderOfCrows and Spell.AMurderOfCrows.IsKnown
       and cd_remaining(Spell.AMurderOfCrows) < 2
       and target.HealthPct <= EXECUTE_PCT and Me.Power < 60 then
      as_thresh = 999 -- block
    end
    if Me.Power >= as_thresh then
      if Spell.ArcaneShot:CastEx(target) then return true end
    end
  end

  -- Cobra Shot (filler, focus cap)
  if kc_cd < 1.0 and Me.Power >= 40 then
    return false
  end
  if Me.Power < (PallasSettings.BMCobraShotFocusCap or 80) then
    Spell.CobraShot:CastEx(target)
  end
  return false
end

-- ── Single-target rotation ────────────────────────────────────

local function SingleTargetRotation(target)
  local bw_cd = cd_remaining(Spell.BestialWrath)
  local kc_cd = cd_remaining(Spell.KillCommand)

  -- 1. Kill Command — but delay if BW is about to be ready (< 2s)
  --    so we can sync BW → KC for maximum burst
  local delay_kc_for_bw = S("BMUseBestialWrath")
      and bw_cd > 0 and bw_cd < 2 and not InBurstWindow()
  if not delay_kc_for_bw then
    if Spell.KillCommand:CastEx(target) then return true end
  end

  -- 2. Kill Shot (execute scan all targets ≤20% HP)
  if TryKillShot() then return true end

  -- 3. Glaive Toss — skip if KC imminent (< 0.7s) to avoid wasting the GCD
  if kc_cd > 0.7 then
    if Spell.GlaiveToss:CastEx(target) then return true end
  end

  -- 4. A Murder of Crows — execute scan for CD reset, then beefy targets (TTD > 15s)
  if S("BMUseAMoC") and Spell.AMurderOfCrows and Spell.AMurderOfCrows.IsKnown then
    -- Execute priority: scan all targets for ≤20% HP (CD resets on kill)
    for _, u in ipairs(Combat.Targets or {}) do
      if not u.IsDead and u.HealthPct <= EXECUTE_PCT then
        if Spell.AMurderOfCrows:CastEx(u) then return true end
      end
    end
    local ttd = GetTargetTTD(target)
    if ttd > 15 and not target:HasAura("A Murder of Crows") then
      if Spell.AMurderOfCrows:CastEx(target) then return true end
    end
  end

  -- 5. Fervor if ≤ threshold focus — check both player and pet
  --    (but not during BW — focus flows freely there)
  if S("BMUseFervor") and not InBurstWindow() then
    local pet = Pet.GetPrimary()
    local pet_low = pet and (pet.Power or 100) <= 50
    if Me.Power <= (PallasSettings.BMFervorThreshold or 50) or pet_low then
      if Spell.Fervor:CastEx(Me) then return true end
    end
  end

  -- 6. Cobra Shot to refresh Serpent Sting if about to fall off
  local ss_rem = AuraRemaining(target, "Serpent Sting")
  if ss_rem > 0 and ss_rem < SERPENT_STING_REFRESH then
    if Spell.CobraShot:CastEx(target) then return true end
  end

  -- 7. Arcane Shot focus dump
  --    Lower threshold during Thrill of the Hunt (proc gives free shots)
  --    Don't dump focus when BW is about to come off CD (< 3s)
  --    Hold focus for AMoC execute reset
  local conserve_for_bw = S("BMUseBestialWrath") and bw_cd > 0 and bw_cd < 3
  if not conserve_for_bw then
    local as_thresh = PallasSettings.BMArcaneShotMinFocus or 65
    if Me:HasAura("Thrill of the Hunt") then
      -- Skip TotH Arcane if KC is about to be ready and focus is tight
      if kc_cd < 0.5 and Me.Power < 50 then
        as_thresh = 999 -- block
      else
        as_thresh = 40
      end
    end
    -- Hold for AMoC execute reset
    if S("BMUseAMoC") and Spell.AMurderOfCrows and Spell.AMurderOfCrows.IsKnown
       and cd_remaining(Spell.AMurderOfCrows) < 2
       and target.HealthPct <= EXECUTE_PCT and Me.Power < 60 then
      as_thresh = 999 -- block
    end
    if Me.Power >= as_thresh then
      if Spell.ArcaneShot:CastEx(target) then return true end
    end
  end

  -- 8. Cobra Shot (filler / focus regen)
  --    Skip if KC is about to come off CD and we have enough focus to KC
  --    Focus cap: don't waste regen above threshold
  if kc_cd < 1.0 and Me.Power >= 40 then
    return false
  end
  if Me.Power < (PallasSettings.BMCobraShotFocusCap or 80) then
    Spell.CobraShot:CastEx(target)
  end
  return false
end

-- ── Main rotation ──────────────────────────────────────────────

local was_in_combat = false

local function BeastMasteryCombat()
  local target = Combat.BestTarget
  if not target then return end

  -- TTD tracking
  UpdateTargetTTD(target)

  -- Combat drop: reset TTD
  if Me.InCombat then
    if not was_in_combat then was_in_combat = true end
  else
    if was_in_combat then
      was_in_combat = false
      if TTD then TTD.Reset() end
    end
  end

  -- Mend Pet (can cast while doing other things)
  if TryMendPet() then return end

  -- Exhilaration — self-heal when player or pet HP critical
  if TryExhilaration() then return end

  -- Auto-range
  if not Me:IsAutoRanging() then
    Me:StartRanging(target)
  end

  if Me:IsCastingOrChanneling() then return end

  -- ── Off-GCD abilities (checked before GCD gate) ────────────

  -- Counter Shot — interrupt enemy casts
  if S("BMUseCounterShot") then
    if Spell.CounterShot:Interrupt() then return end
  end

  -- Master's Call — break roots/snares on the player
  if S("BMUseMastersCall") and IsRootedOrSnared() then
    if Spell.MastersCall:CastEx(Me) then return end
  end

  -- Misdirection (threat management — tank > pet)
  if TryMisdirection() then return end

  -- Rapid Fire — off-GCD, skip during Lust
  local ttd = GetTargetTTD(target)
  if S("BMUseRapidFire") and ttd > 20 then
    local can_rf = true
    if S("BMAvoidRFHeroism") and HasHasteBuff() then can_rf = false end
    if HasRapidFire() then can_rf = false end
    if can_rf then
      if Spell.RapidFire:CastEx(Me) then return end
    end
  end

  -- Tranquilizing Shot — auto-purge stealable buffs
  if S("BMUseTranqShot") and Spell.TranquilizingShot and Spell.TranquilizingShot.IsKnown then
    if target:HasStealableBuff() then
      if Spell.TranquilizingShot:CastEx(target) then return end
    end
  end

  -- Rabid (pet) — off-GCD
  if Spell.Rabid:CastEx(Me) then end

  if Spell:IsGCDActive() then return end

  -- ── Determine AoE / Cleave / ST ────────────────────────────
  local aoe_count = 0
  local use_aoe = false
  local use_cleave = false
  if S("BMAoeEnabled") or S("BMCleaveEnabled") then
    local aoe_range = PallasSettings.BMAoeRange or 10
    aoe_count = Combat:GetTargetsAround(target, aoe_range) or 0
  end
  local aoe_threshold = PallasSettings.BMAoeCount or 3
  use_aoe = S("BMAoeEnabled") and aoe_count >= aoe_threshold
  use_cleave = not use_aoe and S("BMCleaveEnabled") and aoe_count >= 2

  -- ── Pre-rotation maintenance ─────────────────────────────────

  -- Hunter's Mark
  if not target:HasAura("Hunter's Mark") then
    if Spell.HuntersMark:CastEx(target) then return end
  end

  -- Serpent Sting (apply only if missing)
  if not target:HasAura("Serpent Sting") then
    if Spell.SerpentSting:CastEx(target) then return end
  end

  -- ── Major cooldowns (TTD-gated) ────────────────────────────

  -- Stampede (10min CD) — sync with BW/RF/Heroism if enabled
  if S("BMUseStampede") and ttd > 30 then
    if S("BMSyncStampede") then
      if InBurstWindow() or HasRapidFire() or HasHasteBuff() or target.HealthPct < 5 then
        if Spell.Stampede:CastEx(Me) then return end
      end
    else
      if Spell.Stampede:CastEx(Me) then return end
    end
  end

  -- ── Bestial Wrath opener: Fervor first if low on focus ───────
  if S("BMUseBestialWrath") and not InBurstWindow() then
    if Spell.BestialWrath:IsReady() then
      local bw_min_focus = PallasSettings.BMBWMinFocus or 80
      -- Lower focus requirement during RF or Focus Fire (haste = faster regen)
      if HasRapidFire() or Me:HasAura("Focus Fire") then
        bw_min_focus = bw_min_focus - 15
      end

      if Me.Power < bw_min_focus then
        -- Pre-cast Fervor to fill focus before BW
        if S("BMUseFervor") and Spell.Fervor:IsReady() then
          if Spell.Fervor:CastEx(Me) then return end
        end
      end

      -- Only pop BW when we have enough focus AND KC is close to ready
      if Me.Power >= bw_min_focus and cd_remaining(Spell.KillCommand) < 3 then
        if Spell.BestialWrath:CastEx(Me) then
          -- Pop on-use trinkets with Bestial Wrath
          if S("BMUseTrinkets") then
            if Item.Trinket1 and Item.Trinket1:IsReady() then Item.Trinket1:Use() end
            if Item.Trinket2 and Item.Trinket2:IsReady() then Item.Trinket2:Use() end
          end
          return
        end
      end
    end
  end

  -- Dire Beast
  if S("BMUseDireBeast") then
    if Spell.DireBeast:CastEx(target) then return end
  end

  -- Focus Fire at 5 Frenzy stacks
  -- SKIP during: Bestial Wrath, Rapid Fire, or Lust (Frenzy stacks
  -- give multiplicative pet haste during these windows)
  local frenzy = Me:GetAura("Frenzy")
  if frenzy and (frenzy.stacks or 0) >= FOCUS_FIRE_FRENZY_STACKS then
    if not InBurstWindow() and not HasRapidFire() and not HasHasteBuff() then
      if Spell.FocusFire:CastEx(Me) then return end
    end
  end

  -- ── Core rotation ────────────────────────────────────────────

  if InBurstWindow() then
    if BurstRotation(target, use_aoe, use_cleave) then return end
  elseif use_aoe then
    if AoeRotation(target, aoe_count) then return end
  elseif use_cleave then
    if CleaveRotation(target) then return end
  else
    if SingleTargetRotation(target) then return end
  end
end

-- ── Export ───────────────────────────────────────────────────

local behaviors = {
  [BehaviorType.Combat] = BeastMasteryCombat,
}

return { Options = options, Behaviors = behaviors }
