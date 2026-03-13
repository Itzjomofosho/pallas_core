-- Abstract targeting pipeline (mirrors Pallas common/targeting.lua).
--
-- Subclasses override WantToRun, CollectTargets, ExclusionFilter,
-- InclusionFilter, and WeighFilter to implement specific targeting logic.
-- Update() drives the full pipeline: Reset → Collect → Exclude → Include → Weigh.

Targeting = {}
Targeting.__index = Targeting

function Targeting:New(o)
  o = o or {}
  o.Targets     = {}
  o.HealTargets = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Targeting:WantToRun()
  return true
end

function Targeting:Update()
  self:Reset()
  if not self:WantToRun() then return end
  self:CollectTargets()
  self:ExclusionFilter()
  self:InclusionFilter()
  self:WeighFilter()
end

function Targeting:Reset()
  self.Targets     = {}
  self.HealTargets = {}
end

function Targeting:CollectTargets()   end
function Targeting:ExclusionFilter()  end
function Targeting:InclusionFilter()  end
function Targeting:WeighFilter()      end

return Targeting
