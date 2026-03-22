local options = {
	Name = "Priest (Discipline)", -- shown as collapsing header

	Widgets = {
		{ type = "text", text = "=== General ===" },
	},
}

local dotMode = false
local function DoCombat()
	if imgui.is_key_pressed(551) then
		dotMode = not dotMode
	end

	if Me:IsCastingOrChanneling() then
		return
	end

	if Spell:IsGCDActive() then
		return
	end

	if not Me:HasAura("Power Word: Shield") and not Me:HasAura("Weakened Soul") then
		Spell.PowerWordShield:CastEx(Me)
		return
	end

	if dotMode then
		local nearbyTargets = Me:getUnitsAroundUnit(40)
		for _, target in pairs(nearbyTargets) do
			if not target:HasAura("Shadow Word: Pain") then
				Spell.ShadowWordPain:CastEx(target, false, true)
				return
			end
		end
	end

	local target = Combat.BestTarget
	if not target then
		return
	end

	if Spell.Smite:CastEx(target) then
		return
	end
end

local behaviors = {
	[BehaviorType.Combat] = DoCombat,
}

return { Options = options, Behaviors = behaviors }
