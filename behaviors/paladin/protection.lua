local options = {
	Name = "Paladin (Protection)",

	Widgets = {
		{ type = "text", text = "=== Offensive ===" },
		{ type = "slider", uid = "ProtAvengersShieldYards", text = "Avenger's Shield range (yd)", default = 5, min = 1, max = 15 },
		{ type = "slider", uid = "ProtHotRYards", text = "Hammer of the Righteous range (yd)", default = 8, min = 1, max = 15 },
		{ type = "slider", uid = "ProtHotRTargets", text = "Hammer of the Righteous min targets", default = 3, min = 2, max = 10 },
	},
}

local function DoCombat()
	if Me:IsCastingOrChanneling() then return end

	local target = Combat.BestTarget
	if not target then return end

	-- Lay on Hands — emergency self-heal
	if Me.HealthPct <= 25 and Spell.LayOnHands:CastEx(Me) then return end

	if Spell:IsGCDActive() then return end

	-- Word of Glory — self-heal when low
	if Me.HealthPct <= 40 and Spell.WordOfGlory:CastEx(Me) then return end

	-- Reckoning — taunt mobs targeting party members (uses Heal.Friends.All)
	local friends = Heal.Friends and Heal.Friends.All
	if friends and #friends > 0 then
		-- Build guid set of friendlies excluding self
		local friend_guids = {}
		for _, f in ipairs(friends) do
			if f.Guid and f.Guid ~= Me.Guid then
				friend_guids[f.Guid] = true
			end
		end

		for _, enemy in ipairs(Combat.Targets) do
			if enemy.InCombat then
				local enemyTarget = enemy:GetTarget()
				if enemyTarget and enemyTarget.Guid and friend_guids[enemyTarget.Guid] then
					if Spell.Reckoning:CastEx(enemy) then return end
				end
			end
		end
	end

	-- Avenger's Shield — on bosses or when 2+ enemies within 7yd of target
	local as_range = PallasSettings.ProtAvengersShieldYards or 5
	if (target:IsBoss() or Combat:GetTargetsAround(target, as_range) >= 2) and Spell.AvengersShield:CastEx(target) then return end

	-- Judgment — high holy power generator, keep on cooldown
	if Spell.Judgment:CastEx(target) then return end

	-- Hammer of the Righteous — AoE when 3+ targets nearby
	local hotr_range = PallasSettings.ProtHotRYards or 8
	local hotr_targets = PallasSettings.ProtHotRTargets or 3
	if Combat:GetTargetsAround(target, hotr_range) >= hotr_targets and Me:InMeleeRange(target) and Spell.HammerOfTheRighteous:CastEx(target) then return end

	-- Crusader Strike — melee filler / holy power generator
	if Me:InMeleeRange(target) and Spell.CrusaderStrike:CastEx(target) then return end
end

-- ── Debug window ──────────────────────────────────────────────

local function draw_debug_content()
	-- Party info via Heal.Friends.All
	local friends = Heal.Friends and Heal.Friends.All or {}
	imgui.text(string.format("Heal.Friends.All: %d members", #friends))

	-- Build guid set for taunt check
	local friend_guids = {}
	for _, f in ipairs(friends) do
		if f.Guid and f.Guid ~= Me.Guid then
			friend_guids[f.Guid] = true
		end
	end

	imgui.text(string.format("Me GUID: %s", tostring(Me and Me.Guid or "nil")))
	imgui.separator()

	-- Combat targets
	local targets = Combat.Targets or {}
	imgui.text(string.format("Combat.Targets: %d", #targets))

	for i, enemy in ipairs(targets) do
		local ename = enemy.Name or "?"
		local in_combat = enemy.InCombat and "yes" or "no"
		local etgt = enemy:GetTarget()
		local tgt_name = "nil"
		local tgt_guid = "nil"
		local taunts_party = false

		if etgt then
			tgt_name = etgt.Name or "?"
			tgt_guid = tostring(etgt.Guid or "?")

			if etgt.Guid and friend_guids[etgt.Guid] then
				taunts_party = true
			end
		end

		local color = taunts_party and 0xFF4444FF or 0xFFFFFFFF
		imgui.text_colored(color, string.format(
			"  [%d] %s | combat=%s | tgt=%s (%s)%s",
			i, ename, in_combat, tgt_name, tgt_guid,
			taunts_party and " << TAUNT" or ""))
	end

	imgui.separator()

	-- Reckoning spell state
	local reck = Spell.Reckoning
	if reck then
		imgui.text(string.format("Reckoning CD: %s | Known: %s | Usable: %s",
			tostring(reck.CooldownRemaining or reck.Cooldown or "?"),
			tostring(reck.IsKnown or "?"),
			tostring(reck.IsUsable or "?")))
	else
		imgui.text("Spell.Reckoning: nil")
	end
end

local function DoDraw()
	local visible = imgui.begin_window("Prot Paladin Debug", 0)
	if visible then
		pcall(draw_debug_content)
	end
	imgui.end_window()
end

Pallas._behavior_draw = DoDraw

-- No-op heal behavior so Heal.Friends.All gets populated each tick
local function DoHeal() end

local behaviors = {
	[BehaviorType.Combat] = DoCombat,
	[BehaviorType.Heal] = DoHeal,
}

return { Options = options, Behaviors = behaviors }
