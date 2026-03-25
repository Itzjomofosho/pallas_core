local options = {
	Name = "Warrior (Protection)",

	Widgets = {
		{ type = "text",   text = "=== Offensive ===" },
		{ type = "slider", uid = "ProtWarHeroicStrikeRage", text = "Heroic Strike min rage %", default = 60, min = 10, max = 100 },
	},
}

local function DoCombat()
	if Me:IsCastingOrChanneling() then return end

	local target = Combat.BestTarget
	if not target then return end

	if not Me:InMeleeRange(target) then return end

	if not Me:IsAutoAttacking() and Me:StartAttack(target) then return end

	-- Shield Block — off-GCD, use when a mob is in melee range
	if not Me:HasAura("Shield Block") and Combat:GetEnemiesWithinDistance(4) >= 1 then
		Spell.ShieldBlock:CastEx(Me)
	end

	if Spell:IsGCDActive() then return end

	-- Taunt — grab mobs not targeting me
	for _, enemy in ipairs(Combat.Targets) do
		if enemy.InCombat then
			local enemyTarget = enemy:GetTarget()
			if enemyTarget and enemyTarget.Guid ~= Me.Guid and enemyTarget.IsPlayer then
				if Spell.Taunt:CastEx(enemy) then return end
			end
		end
	end

	-- 1. Shield Slam — top priority
	if Spell.ShieldSlam:CastEx(target) then return end

	-- 2. Victory Rush — free heal proc, use when available
	if Spell.VictoryRush:CastEx(target) then return end

	-- 3. Execute — low-health finisher
	if Spell.Execute:CastEx(target) then return end

	-- 4. Heroic Strike — rage dump
	local hs_rage = PallasSettings.ProtWarHeroicStrikeRage or 60
	if Me.PowerPct >= hs_rage and Spell.HeroicStrike:CastEx(target) then return end
end

local behaviors = {
	[BehaviorType.Combat] = DoCombat,
}

return { Options = options, Behaviors = behaviors }
