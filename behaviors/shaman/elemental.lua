local options = {
	Name = "Shaman (Elemental)", -- shown as collapsing header

	Widgets = {
		{ type = "text", text = "=== General ===" },
	},
}

local function DoCombat()
	if Me:IsCastingOrChanneling() then
		return
	end

	if not Me:HasAura("Lightning Shield") and Spell.LightningShield:CastEx(Me) then
		return
	end

	if Me.HealthPct < 50 and Spell.HealingSurge:CastEx(Me) then
		return
	end

	local target = Combat.BestTarget
	if not target then
		return
	end

	if Spell:IsGCDActive() then
		return
	end

	if target.InCombat and Spell.EarthShock:CastEx(target) then
		return
	end

	if Spell.LightningBolt:CastEx(target) then
		return
	end
end

local behaviors = {
	[BehaviorType.Combat] = DoCombat,
}

return { Options = options, Behaviors = behaviors }
