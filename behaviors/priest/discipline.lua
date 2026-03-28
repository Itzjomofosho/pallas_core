local options = {
    Name = "Priest (Discipline)", -- shown as collapsing header

    Widgets = {
        { type = "header",   text = "General" },
        { type = "slider",   uid = "DiscDPSAboveHP",             text = "DPS Above Health %",              default = 90,  min = 0,   max = 100 },

        { type = "header",   text = "Single Target Healing" },
        { type = "slider",   uid = "DiscPenanceHP",              text = "Penance %",                       default = 60,  min = 0,   max = 100 },
        { type = "slider",   uid = "DiscFlashHealHP",            text = "Flash Heal %",                    default = 50,  min = 0,   max = 100 },
        { type = "slider",   uid = "DiscHealHP",                 text = "Heal %",                          default = 85,  min = 0,   max = 100 },

        { type = "header",   text = "Shielding" },
        { type = "checkbox", uid = "DiscPWSOnTargeted",          text = "PW:S allies being targeted",      default = true },
        { type = "slider",   uid = "DiscPWSHP",                  text = "PW:S Below Health %",             default = 90,  min = 0,   max = 100 },

        { type = "header",   text = "AoE Healing" },
        { type = "slider",   uid = "DiscPoHCount",               text = "Prayer of Healing - Members",     default = 3,   min = 1,   max = 5 },
        { type = "slider",   uid = "DiscPoHHP",                  text = "Prayer of Healing - Health %",    default = 75,  min = 0,   max = 100 },
        { type = "slider",   uid = "DiscPoMHP",                  text = "Prayer of Mending - Health %",    default = 85,  min = 0,   max = 100 },

        { type = "header",   text = "Cooldowns" },
        { type = "slider",   uid = "DiscPainSuppressionHP",      text = "Pain Suppression %",              default = 25,  min = 0,   max = 100 },
        { type = "slider",   uid = "DiscDesperatePrayerHP",      text = "Desperate Prayer %",              default = 35,  min = 0,   max = 100 },
        { type = "checkbox", uid = "DiscUseSpiritShell",         text = "Use Spirit Shell",                default = true },
        { type = "checkbox", uid = "DiscUsePowerInfusion",       text = "Use Power Infusion",              default = true },
        { type = "checkbox", uid = "DiscUseShadowfiend",         text = "Use Shadowfiend/Mindbender",      default = true },

        { type = "header",   text = "Utility" },
        { type = "checkbox", uid = "DiscPurify",                 text = "Purify",                          default = true },
        { type = "combobox", uid = "DiscInnerBuff",              text = "Inner Buff",                      default = 0,   options = { "Inner Fire", "Inner Will" } },
    },
}

local function DoRotation()
    local lowest = Heal:GetLowestMember()

    if Me:IsCastingOrChanneling() then
        return
    end

    if Spell:IsGCDActive() then
        return
    end

    -- Desperate Prayer: self emergency
    local dp_pct = PallasSettings.DiscDesperatePrayerHP or 35
    if Me.HealthPct < dp_pct and Spell.DesperatePrayer:CastEx(Me) then
        return
    end

    -- Pain Suppression: emergency single target
    if lowest then
        local ps_pct = PallasSettings.DiscPainSuppressionHP or 25
        if lowest.HealthPct < ps_pct and Spell.PainSuppression:CastEx(lowest) then
            return
        end
    end

    -- From Darkness Comes Light: free instant Flash Heal proc
    if lowest and Me:HasAura("From Darkness, Comes Light") and Spell.FlashHeal:CastEx(lowest, { skipFacing = true }) then
        return
    end

    -- Spirit Shell window: Archangel + Spirit Shell then spam Prayer of Healing
    if PallasSettings.DiscUseSpiritShell ~= false and Me:HasAura("Spirit Shell") then
        -- Consume Evangelism stacks for healing boost during Spirit Shell
        if Me:HasAura("Evangelism") and Spell.Archangel:CastEx(Me) then
            return
        end
        local poh_hp = PallasSettings.DiscPoHHP or 75
        local poh_count = PallasSettings.DiscPoHCount or 3
        local members_below_poh, _ = Heal:GetMembersBelow(poh_hp)
        if #members_below_poh >= poh_count then
            if Spell.PrayerOfHealing:CastEx(members_below_poh[1], { skipFacing = true }) then
                return
            end
        end
    end

    -- Power Word: Shield on allies being targeted by mobs
    if PallasSettings.DiscPWSOnTargeted ~= false then
        local pws_hp = PallasSettings.DiscPWSHP or 90
        local friend_set = {}
        for _, ally in ipairs(Heal.Friends.All) do
            friend_set[ally.Guid] = ally
        end
        for _, enemy in ipairs(Combat.Targets or {}) do
            local tgt = enemy:GetTarget()
            if tgt then
                local ally = friend_set[tgt.Guid]
                if ally and ally.HealthPct < pws_hp
                    and not ally:HasAura("Power Word: Shield")
                    and not ally:HasAura("Weakened Soul") then
                    if Spell.PowerWordShield:CastEx(ally) then
                        return
                    end
                end
            end
        end
    end

    -- Single Target Healing
    if lowest then
        local penance_pct = PallasSettings.DiscPenanceHP or 60
        if lowest.HealthPct < penance_pct and Spell.Penance:CastEx(lowest) then
            return
        end

        local flash_pct = PallasSettings.DiscFlashHealHP or 50
        if lowest.HealthPct < flash_pct and Spell.FlashHeal:CastEx(lowest, { skipFacing = true }) then
            return
        end
    end

    -- AoE Healing
    local poh_hp = PallasSettings.DiscPoHHP or 75
    local poh_count = PallasSettings.DiscPoHCount or 3
    local members_below_poh, _ = Heal:GetMembersBelow(poh_hp)
    if #members_below_poh >= poh_count then
        if Spell.PrayerOfHealing:CastEx(members_below_poh[1], { skipFacing = true }) then
            return
        end
    end

    -- Prayer of Mending
    if lowest then
        local pom_hp = PallasSettings.DiscPoMHP or 85
        if lowest.HealthPct < pom_hp and not lowest:HasAura("Prayer of Mending") and Spell.PrayerOfMending:CastEx(lowest) then
            return
        end
    end

    -- Single Target Healing (continued)
    if lowest then
        local heal_pct = PallasSettings.DiscHealHP or 85
        if lowest.HealthPct < heal_pct and Spell.Heal:CastEx(lowest, { skipFacing = true }) then
            return
        end
    end

    -- Purify
    if PallasSettings.DiscPurify ~= false then
        if Spell.Purify:Dispel(true, { DispelType.Magic, DispelType.Disease }) then
            return
        end
    end

    -- Resurrect current target if dead
    local myTarget = Me.Target
    if myTarget and myTarget.IsDead and myTarget.isPlayer and Spell.Resurrection:CastEx(myTarget) then
        return
    end

    -- Damage / Atonement (only when healing is comfortable)
    local dps_above_hp = PallasSettings.DiscDPSAboveHP or 90
    if lowest and (lowest.HealthPct < dps_above_hp or Me.PowerPct < 40) then
        return
    end

    -- Inner buff maintenance
    local inner_choice = PallasSettings.DiscInnerBuff or 0
    if inner_choice == 0 then
        if not Me:HasAura("Inner Fire") and Spell.InnerFire:CastEx(Me) then
            return
        end
    else
        if not Me:HasAura("Inner Will") and Spell.InnerWill:CastEx(Me) then
            return
        end
    end

    -- Shadowfiend / Mindbender for mana
    if PallasSettings.DiscUseShadowfiend ~= false and Me.PowerPct < 80 then
        local target = Combat.BestTarget
        if target then
            if Spell.Mindbender and Spell.Mindbender.IsKnown and Spell.Mindbender:CastEx(target) then
                return
            end
            if Spell.Shadowfiend:CastEx(target) then
                return
            end
        end
    end

    -- Spirit Shell: activate when Evangelism is at 5 stacks and healing is stable
    if PallasSettings.DiscUseSpiritShell ~= false then
        local _, evang_stacks = Me:HasAura("Evangelism")
        if evang_stacks and evang_stacks >= 5 and not Me:HasAura("Spirit Shell") then
            -- Inner Focus for free crit Prayer of Healing during shell
            if Spell.InnerFocus:CastEx(Me) then
                return
            end
            if PallasSettings.DiscUsePowerInfusion ~= false and Spell.PowerInfusion:CastEx(Me) then
                return
            end
            if Spell.SpiritShell:CastEx(Me) then
                return
            end
        end
    end

    -- Archangel: consume Evangelism stacks for healing boost (outside Spirit Shell)
    if not Me:HasAura("Spirit Shell") then
        local _, evang_stacks = Me:HasAura("Evangelism")
        if evang_stacks and evang_stacks >= 5 and Spell.Archangel:CastEx(Me) then
            return
        end
    end

    local target = Combat.BestTarget
    if not target then
        return
    end

    -- Atonement rotation: Penance > Holy Fire/Solace > Smite
    if Spell.Penance:CastEx(target) then
        return
    end

    -- Power Word: Solace (talent) or Holy Fire
    if Spell.PowerWordSolace and Spell.PowerWordSolace.IsKnown then
        if Spell.PowerWordSolace:CastEx(target) then
            return
        end
    else
        if Spell.HolyFire:CastEx(target) then
            return
        end
    end

    -- Shadow Word: Pain maintenance
    if not target:HasAura("Shadow Word: Pain") and Spell.ShadowWordPain:CastEx(target) then
        return
    end

    if Spell.Smite:CastEx(target, { skipMoving = true }) then
        return
    end
end

local behaviors = {
    [BehaviorType.Heal] = DoRotation,
    [BehaviorType.Combat] = DoRotation,
}

return { Options = options, Behaviors = behaviors }
