--External Modules
local InventoryStates = require("Engine.RingInventory.InventoryStates")
local Settings = require("Engine.CustomInventory.Settings")
local Utilities = require("Engine.CustomInventory.Utilities")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP
local INVENTORY_MODE = InventoryStates.MODE

--CONSTANTS
local BG_LAYER = 0

local Sprites = {}

local function DrawArrows(list, alpha)
    for _, entry in ipairs(list) do
        local entrySprite = DisplaySprite(
            TEN.Objects.ObjID.MISC_SPRITES,
            3,
            entry[2],
            entry[1],
            Vec2(3, 3),
            Utilities.ColorCombine(COLOR_MAP.NORMAL_FONT, alpha)
        )
        entrySprite:Draw(-8, View.AlignMode.CENTER, View.ScaleMode.FIT, TEN.Effects.BlendID.ALPHA_BLEND)
    end
end

function Sprites.Arrows(selectedRing, alpha)
    local visibleModes = {
        [INVENTORY_MODE.INVENTORY] = true,
        [INVENTORY_MODE.INVENTORY_OPENING] = true,
        [INVENTORY_MODE.INVENTORY_EXIT] = true,
        [INVENTORY_MODE.RING_OPENING] = true,
        [INVENTORY_MODE.RING_CLOSING] = true,
        [INVENTORY_MODE.RING_ROTATE] = true
    }
    
    if not visibleModes[InventoryStates.GetMode()] then
        return
    end
    
    local arrowsUp = {
        {0, Vec2(5, 5)},
        {0, Vec2(95, 5)},
    }
    
    local arrowsDown = {
        {180, Vec2(5, 95)},
        {180, Vec2(95, 95)},
    }
    
    if selectedRing ~= PICKUP_DATA.RING.PUZZLE and 
       selectedRing ~= PICKUP_DATA.RING.COMBINE and 
       selectedRing ~= PICKUP_DATA.RING.AMMO then
        DrawArrows(arrowsUp, alpha)
    end
    
    if selectedRing ~= PICKUP_DATA.RING.OPTIONS and 
       selectedRing ~= PICKUP_DATA.RING.COMBINE and 
       selectedRing ~= PICKUP_DATA.RING.AMMO then
        DrawArrows(arrowsDown, alpha)
    end
end

function Sprites.Background(alpha)
    
    if Settings.BACKGROUND.ENABLE then
        local bgAlpha = math.min(alpha, Settings.BACKGROUND.ALPHA)
        local bgColor = Utilities.ColorCombine(Settings.BACKGROUND.COLOR, bgAlpha)
        local bgSprite = TEN.DisplaySprite(
            Settings.BACKGROUND.OBJECTID,
            Settings.BACKGROUND.SPRITEID,
            Settings.BACKGROUND.POSITION,
            Settings.BACKGROUND.ROTATION,
            Settings.BACKGROUND.SCALE,
            bgColor
        )
        bgSprite:Draw(BG_LAYER, Settings.BACKGROUND.ALIGN_MODE, Settings.BACKGROUND.SCALE_MODE, Settings.BACKGROUND.BLEND_MODE)
    end

end

return Sprites