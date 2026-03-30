local options = {
    Name = "Monk (Mistweaver)", -- shown as collapsing header

    Widgets = {
        { type = "header",   text = "General" },
        { type = "slider",   uid = "MistweaverDPSAboveHP",       text = "DPS Above Health %",              default = 80,  min = 0,   max = 100 },

        { type = "header",   text = "Single Target Healing" },
        { type = "slider",   uid = "MistweaverSoothingMist",     text = "Soothing Mist %",                 default = 80,  min = 0,   max = 100 },
        { type = "slider",   uid = "MistweaverEnvelopingMist",   text = "Enveloping Mist %",               default = 60,  min = 0,   max = 100 },
        { type = "slider",   uid = "MistweaverSurgingMist",      text = "Surging Mist %",                  default = 45,  min = 0,   max = 100 },

        { type = "slider",   uid = "MistweaverRenewingMist",    text = "Renewing Mist %",                 default = 95,  min = 0,   max = 100 },

        { type = "header",   text = "AoE Healing" },
        { type = "slider",   uid = "MistweaverUpliftCount",      text = "Uplift - Members Below",          default = 3,   min = 1,   max = 5 },
        { type = "slider",   uid = "MistweaverUpliftHP",         text = "Uplift - Health %",               default = 75,  min = 0,   max = 100 },

        { type = "header",   text = "Cooldowns" },
        { type = "slider",   uid = "MistweaverLifeCocoonHP",     text = "Life Cocoon %",                   default = 25,  min = 0,   max = 100 },
        { type = "slider",   uid = "MistweaverRevivalHP",        text = "Revival - Health %",              default = 40,  min = 0,   max = 100 },
        { type = "slider",   uid = "MistweaverRevivalCount",     text = "Revival - Members Below",         default = 3,   min = 1,   max = 5 },

        { type = "header",   text = "Utility" },
        { type = "checkbox", uid = "MistweaverDetox",            text = "Detox",                           default = true },
    },
}

local function DoRotation()
    local lowest = Heal:GetLowestMember()

    local channeling_soothing = (Me.ChannelingSpellId == Spell.SoothingMist.Id)
    if Me:IsCastingOrChanneling() and not channeling_soothing then
        return
    end

    if Spell.SpearHandStrike:Interrupt() then
        return
    end

    if Spell:IsGCDActive() then
        return
    end

    -- Muscle Memory: spend proc on Blackout Kick
    if Me:HasAura("Muscle Memory") then
        local mm_target = Combat.BestTarget
        if mm_target and Spell.BlackoutKick:CastEx(mm_target) then
            return
        end
    end

    -- Life Cocoon: emergency cooldown
    if lowest then
        local cocoon_pct = PallasSettings.MistweaverLifeCocoonHP or 25
        if lowest.HealthPct < cocoon_pct and Spell.LifeCocoon:CastEx(lowest) then
            return
        end
    end

    -- Revival: raid-wide emergency
    local revival_hp    = PallasSettings.MistweaverRevivalHP or 40
    local revival_count = PallasSettings.MistweaverRevivalCount or 3
    local members_below_revival, _ = Heal:GetMembersBelow(revival_hp)
    if #members_below_revival >= revival_count and Spell.Revival:CastEx(Me) then
        return
    end

    -- Single Target Healing
    if lowest then
        local surging_pct = PallasSettings.MistweaverSurgingMist or 45
        local enveloping_pct = PallasSettings.MistweaverEnvelopingMist or 60

        -- Soothing Mist must be on the target before Surging/Enveloping Mist
        if (lowest.HealthPct < surging_pct or lowest.HealthPct < enveloping_pct)
            and not lowest:HasAura("Soothing Mist")
            and Spell.SoothingMist:CastEx(lowest, { skipFacing = true }) then
            return
        end

        if lowest.HealthPct < surging_pct and Spell.SurgingMist:CastEx(lowest, { skipFacing = true }) then
            return
        end

        if lowest.HealthPct < enveloping_pct and Spell.EnvelopingMist:CastEx(lowest, { skipFacing = true }) then
            return
        end

        local renewing_pct = PallasSettings.MistweaverRenewingMist or 95
        if lowest.HealthPct < renewing_pct and not lowest:HasAura("Renewing Mist") and Spell.RenewingMist:CastEx(lowest) then
            return
        end
    end

    -- AoE Healing
    local uplift_count = PallasSettings.MistweaverUpliftCount or 3
    local uplift_hp    = PallasSettings.MistweaverUpliftHP or 75
    local members_below_uplift, _ = Heal:GetMembersBelow(uplift_hp)
    if #members_below_uplift >= uplift_count and Spell.Uplift:CastEx(Me) then
        return
    end

    -- Chi Burst: narrow cone, 40 yd range — only cast if we hit >= 1 friend AND >= 1 enemy
    local CHI_BURST_CONE = 0.35 -- ~20 degrees half-angle (narrow line)
    if Spell.ChiBurst and Spell.ChiBurst.IsKnown then
        local friends_hit = 0
        local enemies_hit = 0
        local all_friends = Heal.Friends and Heal.Friends.All or {}
        for _, f in ipairs(all_friends) do
            if f.HealthPct < 95 and Me:GetDistance(f) <= 40 and Me:IsFacing(f, CHI_BURST_CONE) then
                friends_hit = friends_hit + 1
            end
        end
        if friends_hit >= 1 then
            for _, e in ipairs(Combat.Targets or {}) do
                if Me:GetDistance(e) <= 40 and Me:IsFacing(e, CHI_BURST_CONE) then
                    enemies_hit = enemies_hit + 1
                    break
                end
            end
        end
        if friends_hit >= 1 and enemies_hit >= 1 and Spell.ChiBurst:CastEx(Me) then
            return
        end
    end

    -- Single Target Healing (continued)
    if lowest then
        local soothing_pct = PallasSettings.MistweaverSoothingMist or 80
        if lowest.HealthPct < soothing_pct and Spell.SoothingMist:CastEx(lowest, { skipFacing = true }) then
            return
        end
    end

    -- Detox
    if PallasSettings.MistweaverDetox ~= false then
        if Spell.Detox:Dispel(true, { DispelType.Magic, DispelType.Poison, DispelType.Disease }) then
            return
        end
    end

    -- Resurrect current target if dead
    local myTarget = Me.Target
    if myTarget and myTarget.IsDead and myTarget.isPlayer and Spell.Resuscitate:CastEx(myTarget) then
        return
    end

    -- Damage (only when healing is comfortable)
    local dps_above_hp = PallasSettings.MistweaverDPSAboveHP or 80
    if lowest and (lowest.HealthPct < dps_above_hp or Me.PowerPct < 50) then
        return
    end

    local target = Combat.BestTarget
    if not target then
        return
    end

    if not Me:IsAutoAttacking() and Me:StartAttack(target) then
        return
    end

    if Spell.ChiWave:CastEx(target) then
        return
    end

    if not Me:HasAura("Tiger Power") and Spell.TigerPalm:CastEx(target) then
        return
    end

    if Spell.BlackoutKick:CastEx(target) then
        return
    end

    if Spell.Jab:CastEx(target) then
        return
    end

    if Spell.TigerPalm:CastEx(target) then
        return
    end
end

local behaviors = {
    [BehaviorType.Heal] = DoRotation,
    [BehaviorType.Combat] = DoRotation,
}

return { Options = options, Behaviors = behaviors }
