-- MoP class ID → name mapping and per-class spec definitions.
--
-- The game exposes spec_id (1-based, 1-4) and spec_name on the active player's
-- unit subtable via game.local_player().  The SPEC_MAP here matches the game's
-- ordering and is used as a reference for the manual override dropdown and for
-- mapping spec_id → behavior file path.

local CLASS_MAP = {
  [1]  = "Warrior",
  [2]  = "Paladin",
  [3]  = "Hunter",
  [4]  = "Rogue",
  [5]  = "Priest",
  [6]  = "Death Knight",
  [7]  = "Shaman",
  [8]  = "Mage",
  [9]  = "Warlock",
  [10] = "Monk",
  [11] = "Druid",
}

local SPEC_MAP = {
  warrior      = { "Arms", "Fury", "Protection" },
  paladin      = { "Holy", "Protection", "Retribution" },
  hunter       = { "Beast Mastery", "Marksmanship", "Survival" },
  rogue        = { "Assassination", "Combat", "Subtlety" },
  priest       = { "Discipline", "Holy", "Shadow" },
  deathknight  = { "Blood", "Frost", "Unholy" },
  shaman       = { "Elemental", "Enhancement", "Restoration" },
  mage         = { "Arcane", "Fire", "Frost" },
  warlock      = { "Affliction", "Demonology", "Destruction" },
  monk         = { "Brewmaster", "Mistweaver", "Windwalker" },
  druid        = { "Balance", "Feral", "Guardian", "Restoration" },
}

local function class_key(class_id)
  local name = CLASS_MAP[class_id]
  if not name then return nil end
  return name:gsub("%s+", ""):lower()
end

return {
  CLASS_MAP = CLASS_MAP,
  SPEC_MAP  = SPEC_MAP,
  class_key = class_key,
}
