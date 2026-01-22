-- ============================================================================
-- INVENTORY ITEM METHODS
-- ============================================================================

local InventoryItem = {}
InventoryItem.__index = InventoryItem

function InventoryItem:GetObjectID()
    return self.objectID
end

function InventoryItem:GetName()
    return self.name
end

function InventoryItem:GetType()
    return self.type
end

function InventoryItem:GetYOffset()
    return self.yOffset
end

function InventoryItem:GetScale()
    return self.scale
end

function InventoryItem:GetRotation()
    return self.rotation
end

function InventoryItem:GetOrientation()
    return self.orientation
end

function InventoryItem:GetMeshBits()
    return self.meshBits
end

function InventoryItem:GetCount()
    return self.count
end

function InventoryItem:GetMenuActions()
    return self.menuActions
end

function InventoryItem:CanCombine()
    return self.combine ~= nil
end

function InventoryItem:IsType(typeName)
    return self.type == typeName
end

function InventoryItem.New(data)
    return setmetatable(data, InventoryItem)
end

return InventoryItem