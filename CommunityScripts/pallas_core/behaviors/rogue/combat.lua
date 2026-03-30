local options = {
	Name = "Rogue (Combat)",

	Widgets = {
		-- Finishers
		{ type = "text", text = "=== Finishers ===" },
		{ type = "slider", uid = "RogueEvisCP", text = "Eviscerate at CP", default = 3, min = 1, max = 5 },
		{ type = "slider", uid = "RogueSnDCP", text = "Slice and Dice at CP", default = 2, min = 1, max = 5 },

		-- Interrupts
		{ type = "text", text = "=== Interrupts ===" },
		{ type = "checkbox", uid = "RogueUseKick", text = "Use Kick", default = true },

		-- AoE
		{ type = "text", text = "=== AoE ===" },
		{ type = "slider", uid = "RogueBladeFlurryMobs", text = "Blade Flurry at mobs", default = 3, min = 2, max = 5 },
	},
}

local function DoCombat()
	if Me:IsCastingOrChanneling() then
		return
	end

	if not Me:HasAura("Deadly Poison") and Spell.DeadlyPoison:CastEx(Me) then
		return
	end

	local target = Combat.BestTarget
	if not target then
		return
	end

	if not Me:InMeleeRange(target) then
		return
	end

	-- Interrupt with Kick (highest priority in melee)
	if PallasSettings.RogueUseKick and Spell.Kick:Interrupt() then
		return
	end

	if not Me:IsAutoAttacking() and Me:StartAttack(target) then
		return
	end

	if Spell:IsGCDActive() then
		return
	end

	if Me:HasAura("Stealth") then
		Spell.Ambush:CastEx(target)
		return
	end

	local nearby = Combat:GetEnemiesWithinDistance(8)
	local bf_threshold = PallasSettings.RogueBladeFlurryMobs or 3
	if nearby >= bf_threshold and not Me:HasAura("Blade Flurry") and Spell.BladeFlurry:CastEx(Me) then
		return
	end

	local snd_cp = PallasSettings.RogueSnDCP or 2
	if Me.ComboPoints >= snd_cp and not Me:HasAura("Slice and Dice") and Spell.SliceAndDice:CastEx(Me) then
		return
	end

	local evis_cp = PallasSettings.RogueEvisCP or 3
	if Me.ComboPoints >= evis_cp and Spell.Eviscerate:CastEx(target) then
		return
	end

	if target:IsBoss() and not target:HasAura("Revealing Strike") and Spell.RevealingStrike:CastEx(target) then
		return
	end

	if Spell.SinisterStrike:CastEx(target) then
		return
	end
end

local behaviors = {
	[BehaviorType.Combat] = DoCombat,
}

return { Options = options, Behaviors = behaviors }
