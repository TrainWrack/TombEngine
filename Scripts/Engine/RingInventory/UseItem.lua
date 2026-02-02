-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

--External Modules
local CustomInventory = require("Engine.RingInventory.Inventory")
local Settings = require("Engine.RingInventory.Settings")

--Pointers to constant tables
local CONSTANTS = require("Engine.RingInventory.Constants")
local INVENTORY_MODE = CustomInventory.INVENTORY_MODE
local SOUND_MAP = Settings.SOUND_MAP

local Use = {}

local CROUCH_STATES = {
    LS_CROUCH_IDLE = 71,
    LS_CROUCH_TURN_LEFT = 105,
    LS_CROUCH_TURN_RIGHT = 106,
    LS_CROUCH_TURN_180 = 171
}

local CRAWL_STATES = {
    LS_CRAWL_IDLE = 80,
    LS_CRAWL_FORWARD = 81,
    LS_CRAWL_BACK = 86,
    LS_CRAWL_TURN_LEFT = 84,
    LS_CRAWL_TURN_RIGHT = 85,
    LS_CRAWL_TURN_180 = 172,
    LS_CRAWL_TO_HANG = 88
}

local function TestState(table)
    local currentState = Lara:GetState()
    for _, state in pairs(table) do
        if currentState == state then
            return true
        end
    end
    return false
end

local function CrawlTest(item)
    if item.crawl then
        return true
    end
    return not (TestState(CROUCH_STATES) or TestState(CRAWL_STATES))
end

local function WaterTest(item)
    if item.underwater then
        return true
    end
    return (Lara:GetWaterStatus() == TEN.Objects.WaterStatus.DRY or Lara:GetWaterStatus() == TEN.Objects.WaterStatus.WADE)
end

function Use.Item(item)

    local levelStatistics = Flow.GetStatistics()
    local gameStatistics = Flow.GetStatistics(true)
    
    TEN.Inventory.SetUsedItem(item)
    TEN.Util.OnUseItemCallBack()
    
    if (TEN.Inventory.GetUsedItem() == CONSTANTS.NO_VALUE) then
        CustomInventory.SetMode(INVENTORY_MODE.INVENTORY_EXIT)
        return
    end
    
    if PICKUP_DATA.WEAPON_SET[item] and WaterTest(PICKUP_DATA.WEAPON_SET[item]) and CrawlTest(PICKUP_DATA.WEAPON_SET[item]) then
        TEN.Inventory.ClearUsedItem()
        local currentWeapon = Lara:GetWeaponType()
        
        if item == TEN.Objects.ObjID.FLARE_INV_ITEM and currentWeapon == TEN.Objects.WeaponType.FLARE then
            CustomInventory.SetMode(INVENTORY_MODE.INVENTORY_EXIT)
            return
        end
        
        Lara:SetWeaponType(PICKUP_DATA.WEAPON_SET[item].slot, true)
        
        if item == TEN.Objects.ObjID.FLARE_INV_ITEM then
            TEN.Inventory.TakeItem(item, 1)
        end
    end
    
    if PICKUP_DATA.HEALTH_SET[item] then
        TEN.Inventory.ClearUsedItem()
        local hp = Lara:GetHP()
        local poison = Lara:GetPoison()
        
        if hp <= 0 or hp >= PICKUP_DATA.HEALTH_MAX then
            if poison == 0 then
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                CustomInventory.SetMode(INVENTORY_MODE.INVENTORY_EXIT)
                return
            end
        end
        
        local count = TEN.Inventory.GetItemCount(item)
        
        if count then
            if count ~= CONSTANTS.NO_VALUE then
                TEN.Inventory.TakeItem(item, 1)
            end
            
            Lara:SetPoison(0)
            local setHP = math.min(CONSTANTS.HEALTH_MAX, (hp + PICKUP_DATA.HEALTH_SET[item]))
            Lara:SetHP(setHP)
            TEN.Sound.PlaySound(SOUND_MAP.TR4_MENU_MEDI)
            
            levelStatistics.healthPacksUsed = levelStatistics.healthPacksUsed + 1
            gameStatistics.healthPacksUsed = gameStatistics.healthPacksUsed + 1
            Flow.SetStatistics(levelStatistics)
            Flow.SetStatistics(gameStatistics, true)
        end
    end
    
    if item == TEN.Objects.ObjID.BINOCULARS_ITEM then
        TEN.Inventory.ClearUsedItem()
        CustomInventory.UseBinoculars()
    end
    
    CustomInventory.SetMode(INVENTORY_MODE.INVENTORY_EXIT)
end

return Use