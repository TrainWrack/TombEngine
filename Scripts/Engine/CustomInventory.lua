--RING INVENTORY BY TRAINWRECK

local CustomInventory = {}

local PICKUP_DATA = require("Engine.CustomInventory.InventoryConstants")
local Statistics = require("Engine.Statistics")
local Settings = require("Engine.CustomInventory.Settings")
local Interpolate = require("Engine.InterpolateModule")
local Menu = require("Engine.CustomMenu")

local debug = false

--CONSTANTS
local NO_VALUE = -1
local ROTATION_SPEED = 4
local CAMERA_START = Vec3(0,-2500, 200)
local CAMERA_END = Vec3(0,-36,-1151)
local TARGET_START = Vec3(0,0, 1000)
local TARGET_END = Vec3(0,110,0)
local INVENTORY_ANIM_TIME = 0.5
local RING_RADIUS = -512
local ITEM_START = Vec3(0,200,512)
local ITEM_END = Vec3(0,0,400)
local AMMO_LOCATION = Vec3(0,300,512)
local RING_POSITION_OFFSET = 1000
local PROGRESS_COMPLETE = 1
local EXAMINE_DEFAULT_SCALE = 1
local EXAMINE_MIN_SCALE = 0.3
local EXAMINE_MAX_SCALE = 1.6
local EXAMINE_TEXT_POS = Vec2(50, 80)
local ALPHA_MAX = 255
local ALPHA_MIN = 0

--Pointers to tables
local TYPE = PICKUP_DATA.TYPE
local RING = PICKUP_DATA.RING
local RING_CENTER = PICKUP_DATA.RING_CENTER
local INVENTORY_MODE = PICKUP_DATA.INVENTORY_MODE
local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP

--variables
local useBinoculars = false

local itemStoreRotations = false
local itemRotation = Rotation(0, 0, 0)
local itemRotationOld = Rotation(0, 0, 0)
local examineRotation = Rotation(0, 0 ,0)
local examineScaler = EXAMINE_DEFAULT_SCALE
local examineScalerOld = EXAMINE_DEFAULT_SCALE
local examineShowString = false

local ammoAdded = true
local statisticsType = false

local combineItem1 = nil
local combineItem2 = nil
local combineResult = nil
local performCombine = false
local addedItems = 0

--Structure for inventory
local inventory = {ring = {}, slice = {}, selectedItem = {}, ringPosition = {}}
local inventoryOpenItem = nil
local inventoryStart = true
local gameflowOverrides = nil
local selectedRing = RING.MAIN
local previousRing = nil
local timeInMenu = 0
local inventoryDelay = 0 --count of actual frames before inventory is opened. Used for setting the grayscale tint.
local inventoryMode = INVENTORY_MODE.RING_OPENING
local previousMode = nil
local currentRingAngle = 0
local previousRingAngle = 0
local targetRingAngle = 0
local direction = 1
local inventoryHeader = {"actions_inventory", Vec2(50, 4), 1.5, COLOR_MAP.HEADER_FONT, true}
local inventorySubHeader = {"actions_inventory", Vec2(50, 40.3), 0.9, COLOR_MAP.HEADER_FONT, false}

local saveList = false
local saveSelected = false

LevelFuncs.Engine.CustomInventory = {}

--functions
local colorCombine = function(color, transparency)
    return Color(color.r, color.g, color.b, transparency)
end

local offsetY = function(position, offsetY)
    return Vec3(position.x, position.y + offsetY, position.z)
end

local percentPos = function(x, y)
    return TEN.Vec2(TEN.Util.PercentToScreen(x, y))
end

local function copyRotation(r)
    return Rotation(r.x, r.y, r.z)
end

local setInventoryHeader = function(string, visible)

    inventoryHeader[1] = string
    inventoryHeader[5] = visible

end

local setInventorySubHeader = function(string, visible)

    inventorySubHeader[1] = string
    inventorySubHeader[5] = visible

end

local function DrawBackground(alpha)
    if Settings.BACKGROUND.ENABLE then
        local bgAlpha = math.min(alpha, Settings.BACKGROUND.ALPHA)
        local bgColor = colorCombine(Settings.BACKGROUND.COLOR, bgAlpha)
        local bgSprite = TEN.DisplaySprite(Settings.BACKGROUND.OBJECTID, Settings.BACKGROUND.SPRITEID, Settings.BACKGROUND.POSITION, Settings.BACKGROUND.ROTATION, Settings.BACKGROUND.SCALE, bgColor)
        bgSprite:Draw(0, Settings.BACKGROUND.ALIGN_MODE, Settings.BACKGROUND.SCALE_MODE, Settings.BACKGROUND.BLEND_MODE)
    end
end

local calculateCompassAngle = function()

    local needleOrient = Rotation(0, -Lara:GetRotation().y, 0)

	local wibble =  math.sin((timeInMenu % 0x40) / 0x3F * (2 * math.pi))
    needleOrient.y = needleOrient.y + wibble

    return needleOrient
end

local calculateStopWatchRotation = function(type)

    local angles = {}

    local level_time = Flow.GetStatistics(type).timeTaken

    angles.hour_hand_angle = Rotation(0,0,-(level_time.h / 12) * 360)
    angles.minute_hand_angle = Rotation(0,0,-(level_time.m / 60) * 360)
    angles.second_hand_angle = Rotation(0,0,-(level_time.s / 60) * 360)

    return angles

end

local hasItemAction = function(packedFlags, flag)
    return (packedFlags & flag) ~= 0
end

local function hasChooseAmmo(menuActions)
    for _, flag in ipairs(PICKUP_DATA.CHOOSE_AMMO_FLAGS) do
        if hasItemAction(menuActions, flag) then
            return true
        end
    end
    return false
end

local isSingleFlagSet = function(flags)
    return flags ~= 0 and (flags & (flags - 1)) == 0
end

local SetRotationInventoryItems = function()

    local angles = calculateStopWatchRotation(statisticsType)

    --Stopwatch hands

    local stopwatch = TEN.View.DisplayItem.GetItemByName(tostring(TEN.Objects.ObjID.STOPWATCH_ITEM))
    stopwatch:SetJointRotation(4, angles.hour_hand_angle)
    stopwatch:SetJointRotation(5, angles.minute_hand_angle)
    stopwatch:SetJointRotation(6, angles.second_hand_angle)

    --Compass Needle
    local compass = TEN.View.DisplayItem.GetItemByName(tostring(TEN.Objects.ObjID.COMPASS_ITEM))
    compass:SetJointRotation(1, calculateCompassAngle())

end

local FindItemInInventory = function(targetID)
    for ringIndex, ring in pairs(inventory.ring) do
        for itemIndex, itemEntry in ipairs(ring) do
            if itemEntry.objectID == targetID then
                return ringIndex, itemIndex
            end
        end
    end
    return nil, nil -- not found
end

local GetInventoryItem = function(itemID)
	local ringIndex, itemIndex = FindItemInInventory(itemID)
	if not ringIndex or not itemIndex then
		return nil
	end
	return inventory.ring[ringIndex][itemIndex]
end

local BuildInventoryItem = function(data)

    gameflowOverrides = LevelFuncs.Engine.CustomInventory.ReadGameflow() or {}
    data.count = TEN.Inventory.GetItemCount(data.objectID)

    local override = gameflowOverrides[data.objectID] or {}

    if override.yOffset     ~= nil then data.yOffset     = override.yOffset end
    if override.scale       ~= nil then data.scale       = override.scale end
    if override.rotation    ~= nil then data.rotation    = override.rotation end
    if override.menuActions ~= nil then data.menuActions = override.menuActions end
    if override.name        ~= nil then data.name        = override.name end
    if override.meshBits    ~= nil then data.meshBits    = override.meshBits end
    if override.orientation ~= nil then data.orientation = override.orientation end
    if override.type        ~= nil then data.type        = override.type end
    if override.combine     ~= nil then data.combine     = override.combine end

    return data
end

local PerformWaterskinCombine = function(flag)
    -- flag = true  → pour from big → small
    -- flag = false → pour from small → big

    local smallRaw = Lara:GetWaterSkinStatus(false)
    local bigRaw = Lara:GetWaterSkinStatus(true)

    -- Convert to liters only if player has the skin
    local smallLiters = (smallRaw > 0) and (smallRaw - 1) or 0
    local bigLiters = (bigRaw > 0) and (bigRaw - 1) or 0

    local smallCapacity = 3 - smallLiters
    local bigCapacity = 5 - bigLiters

    if flag then
        -- Pour from big into small
        if bigRaw > 1 and smallCapacity > 0 then
            local transfer = math.min(bigLiters, smallCapacity)
            smallLiters = smallLiters + transfer
            bigLiters = bigLiters - transfer

            Lara:SetWaterSkinStatus(smallLiters + 1, false)
            Lara:SetWaterSkinStatus(bigLiters + 1, true)

            combineItem1 = (smallLiters + 1) + (TEN.Objects.ObjID.WATERSKIN1_EMPTY - 1)
            return true
        end
    else
        -- Pour from small into big
        if smallRaw > 1 and bigCapacity > 0 then
            local transfer = math.min(smallLiters, bigCapacity)
            bigLiters = bigLiters + transfer
            smallLiters = smallLiters - transfer

            Lara:SetWaterSkinStatus(smallLiters + 1, false)
            Lara:SetWaterSkinStatus(bigLiters + 1, true)

            combineItem1 = (bigLiters + 1) + (TEN.Objects.ObjID.WATERSKIN2_EMPTY - 1)
            return true
        end
    end

    return false
end

local CombineItems = function(item1, item2)


    local data1 = GetInventoryItem(item1).type
    local data2 = GetInventoryItem(item2).type

    if data1 == TYPE.WATERSKIN and data2 == TYPE.WATERSKIN then
        if (item1 >= TEN.Objects.ObjID.WATERSKIN1_EMPTY and
            item1 <= TEN.Objects.ObjID.WATERSKIN1_3 and
            item2 >= TEN.Objects.ObjID.WATERSKIN2_EMPTY and
            item2 <= TEN.Objects.ObjID.WATERSKIN2_5) then
    
            if (PerformWaterskinCombine(false)) then
                return true
            end
        elseif(item2 >= TEN.Objects.ObjID.WATERSKIN1_EMPTY and
            item2 <= TEN.Objects.ObjID.WATERSKIN1_3 and
            item1 >= TEN.Objects.ObjID.WATERSKIN2_EMPTY and
            item1 <= TEN.Objects.ObjID.WATERSKIN2_5) then
                if (PerformWaterskinCombine(true)) then
                    return true
                end
        end

	end

    for _, combo in ipairs(PICKUP_DATA.combineTable) do
		
        local a, b, result = combo[1], combo[2], combo[3]

		if (item1 == a and item2 == b) or (item1 == b and item2 == a) then

            -- Check if both items are actually present
            local count1 = TEN.Inventory.GetItemCount(item1)
            local count2 = TEN.Inventory.GetItemCount(item2)

            if count1 == 0 or count2 == 0 then
                return false
            end

            -- If the combined result is a weapon that supports lasersight, enable it
            if PICKUP_DATA.WEAPON_LASERSIGHT_DATA[result]
                and PICKUP_DATA.WEAPON_SET[result]
                and PICKUP_DATA.WEAPON_SET[result].slot then
                Lara:SetLaserSight(PICKUP_DATA.WEAPON_SET[result].slot, true)
            end

            -- Remove the original items
            TEN.Inventory.TakeItem(item1, 1)
            TEN.Inventory.TakeItem(item2, 1)

            -- Add the new combined item
            TEN.Inventory.GiveItem(result, 1)



            combineResult = result
			return true
		end
	end

	-- No valid combination found
	return false
end

local SeparateItems = function(item3)
	
    for _, combo in ipairs(PICKUP_DATA.combineTable) do
		
        local a, b, result = combo[1], combo[2], combo[3]

		if item3 == result then

            -- Check if item is actually present
            local count = TEN.Inventory.GetItemCount(item3)

            if count == 0 then
                return false
            end

            -- If the separate result is a weapon that supports lasersight, disable it
            if PICKUP_DATA.WEAPON_LASERSIGHT_DATA[result]
                and PICKUP_DATA.WEAPON_SET[result]
                and PICKUP_DATA.WEAPON_SET[result].slot then
                Lara:SetLaserSight(PICKUP_DATA.WEAPON_SET[result].slot, false)
            end

            -- Remove the original items
            TEN.Inventory.TakeItem(item3, 1)

            -- Add the new separated items
            TEN.Inventory.GiveItem(a, 1)
            TEN.Inventory.GiveItem(b, 1)

            combineItem1 = a

			return true
		end
	end

	-- No valid combination found
	return false
end

local CreateRingMenu = function(ringName)
    
    local ringItems = {}
    local ring = inventory.ring[ringName]

    if ring then
        for _, itemData in ipairs(ring) do

            local text = "< " .. GetString(itemData.name) .. " >"

            table.insert(ringItems, text)
        end
    end

    local ringTable = {
        {
            itemName = "Blank",
            options = ringItems,
            currentOption = 1
        }
    }

    local text = "combine_with"

    if ringName == RING.AMMO then text = "choose_ammo" end

    local combineMenu = Menu.Create("ringMenu", text, ringTable, nil, nil, Menu.Type.OPTIONS_ONLY)

    combineMenu:SetOptionsPosition(Vec2(50, 35))
    combineMenu:SetVisibility(true)
    combineMenu:SetLineSpacing(5.3)
    combineMenu:SetOptionsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    combineMenu:EnableInputs(false)
    combineMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)

end

local ShowRingMenu = function()

    local ringMenu = Menu.Get("ringMenu")
    ringMenu:Draw()

end

local CreateSaveMenu = function(save)

    local textPosition = {
        Vec2(10, 12),
        Vec2(20, 12),
        Vec2(75, 12),
        Vec2(50, 12),
    }

    local saveTitleText = {
        nil,
        "save_game", 
        nil,
        nil
    }

    local loadTitleText = {
        nil,
        "load_game", 
        nil,
        nil
    }

    local saveFunctions = {
        nil,
        "Engine.CustomInventory.DoSave", 
        nil,
        nil
    }

    local loadFunctions = {
        nil,
        "Engine.CustomInventory.DoLoad", 
        nil,
        nil
    }

    local soundMap = {
    [1] = { select = nil, choose = nil },
    [2] = { select = SOUND_MAP.MENU_SELECT, choose = SOUND_MAP.MENU_CHOOSE },
    [3] = { select = nil, choose = nil },
    [4] = { select = nil, choose = nil}
    }

    local itemFlag = {Strings.DisplayStringOption.SHADOW}
    local selectedFlag = {Strings.DisplayStringOption.BLINK, Strings.DisplayStringOption.SHADOW}


    local itemFlags = {itemFlag, itemFlag, itemFlag, {Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}}

    local selectedFlags = {selectedFlag, selectedFlag,  selectedFlag, {Strings.DisplayStringOption.BLINK, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}}

    local headers = Flow.GetSaveHeaders()

    local items = {
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {}
    }

    for i = 1, #headers do
        local h = headers[i]
        local itemText1
        local itemText2
        local itemText3
        local itemText4

        if h and h.Present then
            itemText1 = string.format("%02d", h.Count)
            itemText2 = string.format("%s", h.LevelName)
            itemText3 = string.format("%02d:%02d:%02d", h.Hours, h.Minutes, h.Seconds)
            itemText4 = ""
        else
            itemText1 = ""
            itemText2 = ""
            itemText3 = ""
            itemText4 = "empty"
        end

        table.insert(items[1], { itemName = itemText1 })
        table.insert(items[2], { itemName = itemText2 })
        table.insert(items[3], { itemName = itemText3 })
        table.insert(items[4], { itemName = itemText4 })
    end

    if save then
        for index in ipairs(items) do
            Menu.Create("SaveMenu"..index, saveTitleText[index], items[index], saveFunctions[index], nil, Menu.Type.ITEMS_ONLY)
        end 
    else
        for index in ipairs(items) do
            Menu.Create("SaveMenu"..index, loadTitleText[index], items[index], loadFunctions[index], nil, Menu.Type.ITEMS_ONLY)
        end 
    end

    for index = 1, 4 do

        local saveMenu = Menu.Get("SaveMenu"..index)
        
        local translate = false
        if index == 4 then  translate = true end
        
        saveMenu:SetItemsPosition(textPosition[index])
        saveMenu:SetTitlePosition(Vec2(50, 4))
        saveMenu:SetVisibility(true)
        saveMenu:SetLineSpacing(5.3)
        saveMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9, itemFlags[index])
        saveMenu:SetSelectedItemFlags(selectedFlags[index])
        saveMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, 1.5, nil, true)
        saveMenu:SetItemsTranslate(translate)
        saveMenu:SetSoundEffects(soundMap[index].select, soundMap[index].choose)
    end 

end

LevelFuncs.Engine.CustomInventory.DoSave = function()

    local slot = Menu.Get("SaveMenu2"):getCurrentItemIndex() -1
    Flow.SaveGame(slot)
    saveSelected = true
    for index = 1, 4 do
        Interpolate.Clear("SaveMenu"..index)
    end 
    inventoryMode = INVENTORY_MODE.SAVE_CLOSE

end

LevelFuncs.Engine.CustomInventory.DoLoad = function()

    local slot = Menu.Get("SaveMenu2"):getCurrentItemIndex() - 1

    if Flow.DoesSaveGameExist(slot) then
        Flow.LoadGame(slot)
        saveSelected = true
        for index = 1, 4 do
            Interpolate.Clear("SaveMenu"..index)
        end 
        inventoryMode = INVENTORY_MODE.SAVE_CLOSE
    else
        TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
    end

end

local RunSaveMenu = function()

    for index = 1, 4 do
        local saveMenu = Menu.Get("SaveMenu"..index)
        saveMenu:Draw()
    end 

end

local CreateStatisticsMenu = function()

    local statItems = {}
    local items = {"statistics_level", "statistics_game"}

    if items then
        for _, itemData in ipairs(items) do

            local text = "< " .. GetString(itemData) .. " >"

            table.insert(statItems, text)
        end
    end

    local ringTable = {
        {
            itemName = "Blank",
            options = statItems,
            currentOption = 1
        }
    }

    local statisticsMenu = Menu.Create("SatisticsMenu", "statistics", ringTable, nil, nil, Menu.Type.OPTIONS_ONLY)

    statisticsMenu:SetOptionsPosition(Vec2(50, 24.7))
    statisticsMenu:SetVisibility(true)
    statisticsMenu:SetLineSpacing(5.3)
    statisticsMenu:SetOptionsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    statisticsMenu:SetOnOptionChangeFunction("Blank", "Engine.CustomInventory.ChangeStatistics")
    statisticsMenu:SetWrapAroundOptions(true)
    statisticsMenu:EnableInputs(true)
    statisticsMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)
    statisticsMenu:SetTitlePosition(Vec2(50,4))
end

LevelFuncs.Engine.CustomInventory.ChangeStatistics = function()

    statisticsType = not statisticsType

end

local RunStatisticsMenu = function()

    local statisticsMenu = Menu.Get("SatisticsMenu")
    statisticsMenu:Draw()

end

local CreateWeaponModeMenu = function(item)

    local weaponModes = {}
    local itemData = GetInventoryItem(item)

    for _, entry in ipairs(PICKUP_DATA.WEAPON_MODE_LOOKUP) do
        if entry.weapon == item then
            table.insert(weaponModes, {
                itemName = entry.string,
                actionBit = entry.bit,
                options = nil,
                currentOption = 1
            })
        end
    end

    local modeIndex = Lara:GetWeaponMode()

    local itemMenu = Menu.Create("WeaponModeMenu", itemData.name, weaponModes, "Engine.CustomInventory.ChangeWeaponMode", nil, Menu.Type.ITEMS_ONLY)

    itemMenu:SetItemsPosition(Vec2(50, 35))
    itemMenu:SetVisibility(true)
    itemMenu:SetLineSpacing(5.3)
    itemMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    itemMenu:SetItemsTranslate(true)
    itemMenu:setCurrentItem(modeIndex)
    itemMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, nil, nil, true)

end

LevelFuncs.Engine.CustomInventory.ChangeWeaponMode = function()

    local index = Menu.Get("WeaponModeMenu"):getCurrentItemIndex()

    Lara:SetWeaponMode(index)
    inventoryMode = INVENTORY_MODE.WEAPON_MODE_CLOSE

end

local RunWeaponModeMenu = function()

    local weaponModeMenu = Menu.Get("WeaponModeMenu")
    weaponModeMenu:Draw()

end

local ParseMenuAction = function(menuActions)

    if hasItemAction(menuActions, ItemAction.USE) or hasItemAction(menuActions, ItemAction.EQUIP) then
        inventoryMode = INVENTORY_MODE.ITEM_USE
    elseif hasItemAction(menuActions, ItemAction.EXAMINE) then
        inventoryMode = INVENTORY_MODE.EXAMINE_OPEN
    elseif hasItemAction(menuActions, ItemAction.COMBINE) then
        inventoryMode = INVENTORY_MODE.COMBINE_SETUP
    elseif hasItemAction(menuActions, ItemAction.STATISTICS) then
        inventoryMode = INVENTORY_MODE.STATISTICS_OPEN
    elseif hasItemAction(menuActions, ItemAction.SAVE) then
        saveList = true
        inventoryMode = INVENTORY_MODE.SAVE_SETUP
    elseif hasItemAction(menuActions, ItemAction.LOAD) then
        saveList = false
        inventoryMode = INVENTORY_MODE.SAVE_SETUP
    elseif hasItemAction(menuActions, ItemAction.SEPARATE) then
        inventoryMode = INVENTORY_MODE.SEPARATE
    elseif hasItemAction(menuActions, ItemAction.CHOOSE_AMMO_HK) then
        inventoryMode = INVENTORY_MODE.WEAPON_MODE_SETUP
    elseif hasChooseAmmo(menuActions) then
        inventoryMode = INVENTORY_MODE.AMMO_SELECT_SETUP
    end

end

LevelFuncs.Engine.CustomInventory.DoItemAction = function()

    local menu = LevelVars.Engine.Menus["menuActions"]
    if not menu then return end

    local selectedItem = menu.items[menu.currentItem]
    if selectedItem and selectedItem.actionBit then
        ParseMenuAction(selectedItem.actionBit)
    end

end

local CreateItemMenu = function(item)

    local menuActions = {}
    local itemData = GetInventoryItem(item)
    local itemMenuActions = itemData.menuActions

    for _, entry in ipairs(PICKUP_DATA.ItemActionFlags) do
        if hasItemAction(itemMenuActions, entry.bit) then
            table.insert(menuActions, {
                itemName = entry.string,
                actionBit = entry.bit,
                options = nil,
                currentOption = 1
            })
        end
    end

    local itemMenu = Menu.Create("menuActions", nil, menuActions, "Engine.CustomInventory.DoItemAction", nil, Menu.Type.ITEMS_ONLY)

    itemMenu:SetItemsPosition(Vec2(50, 35))
    itemMenu:SetVisibility(true)
    itemMenu:SetLineSpacing(5.3)
    itemMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9)
    itemMenu:SetItemsTranslate(true)
    itemMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, 1.5, nil, true)
    itemMenu:SetTitlePosition(Vec2(50,4))
end

local ShowItemMenu = function()

    local itemMenu = Menu.Get("menuActions")
    itemMenu:Draw()

end

local guiIsPulsed = function(actionID)

    local DELAY		 = 120
	local INITIAL_DELAY = 30

	--Action already held prior to entering menu; lock input.
	if (GetActionTimeActive(actionID) >= timeInMenu) then
	    return false
    end
	--Pulse only directional inputs.
	local oppositeAction = nil

    if actionID == TEN.Input.ActionID.FORWARD then
        oppositeAction = TEN.Input.ActionID.BACK
    elseif actionID == TEN.Input.ActionID.BACK then
        oppositeAction = TEN.Input.ActionID.FORWARD
    elseif actionID == TEN.Input.ActionID.LEFT then
        oppositeAction = TEN.Input.ActionID.RIGHT
    elseif actionID == TEN.Input.ActionID.RIGHT then
        oppositeAction = TEN.Input.ActionID.LEFT
    end

	--Opposite action held; lock input.
    local isActionLocked = false
	if oppositeAction ~= nil then
		isActionLocked = IsKeyHeld(oppositeAction)
	end

	if isActionLocked then
		return false
	end

	return TEN.Input.IsKeyPulsed(actionID, DELAY, INITIAL_DELAY)
end

local GetSelectedItem = function(ring)

    return inventory.ring[ring][inventory.selectedItem[ring]]

end

local ClearInventory = function(ringName, clearDrawItems)
    
    if ringName then

        local ring = inventory.ring[ringName]

        if clearDrawItems and ring then
            for _, itemData in ipairs(ring) do
                local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(itemData.objectID))
                displayItem:Remove()
            end
        end

        -- Clear only the specific ring
        inventory.ring[ringName] = {}
        inventory.slice[ringName] = nil
        inventory.selectedItem[ringName] = nil
        inventory.ringPosition[ringName] = nil

    else

        if clearDrawItems then
            TEN.View.DisplayItem.ClearAllItems()
        end

        -- Clear entire inventory
        inventory = {ring = {}, slice = {}, selectedItem = {}, ringPosition = {}}

    end

end

local changeOptionsforMenu = function()

    if selectedRing == RING.AMMO or selectedRing == RING.COMBINE then
        
        local ringMenu = Menu.Get("ringMenu")
        ringMenu:setOptionIndexForItem(1, inventory.selectedItem[selectedRing])
        
    end

end

local doLeftKey = function()
    local inventoryTable = inventory.ring[selectedRing]
    inventory.selectedItem[selectedRing] = (inventory.selectedItem[selectedRing] % #inventoryTable) + 1
    targetRingAngle = currentRingAngle - inventory.slice[selectedRing]
    previousMode = inventoryMode
    inventoryMode = INVENTORY_MODE.RING_ROTATE
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)

    changeOptionsforMenu()
end

local doRightKey = function()
    local inventoryTable = inventory.ring[selectedRing]
    inventory.selectedItem[selectedRing] = ((inventory.selectedItem[selectedRing] - 2) % #inventoryTable) + 1
    targetRingAngle = currentRingAngle + inventory.slice[selectedRing]
    previousMode = inventoryMode
    inventoryMode = INVENTORY_MODE.RING_ROTATE
    TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE) 

    changeOptionsforMenu()
end

local Input = function(mode)

    if mode == INVENTORY_MODE.INVENTORY then

        if guiIsPulsed(TEN.Input.ActionID.LEFT) then
            doLeftKey()
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            doRightKey()
        elseif guiIsPulsed(TEN.Input.ActionID.FORWARD) and selectedRing < RING.COMBINE then --disable up and down keys for combine and ammo rings
            previousRing = selectedRing
            selectedRing = math.max(RING.PUZZLE, selectedRing - 1) 
            if selectedRing ~= previousRing then
                inventoryMode = INVENTORY_MODE.RING_CHANGE
                direction = 1
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif guiIsPulsed(TEN.Input.ActionID.BACK) and selectedRing < RING.COMBINE then --disable up and down keys for combine and ammo rings
            previousRing = selectedRing
            selectedRing = math.min(RING.OPTIONS, selectedRing + 1)
            if selectedRing ~= previousRing then
                direction = -1
                inventoryMode = INVENTORY_MODE.RING_CHANGE
                TEN.Sound.PlaySound(SOUND_MAP.MENU_ROTATE)
            end
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) or guiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            itemStoreRotations = true
            local menuActions = GetSelectedItem(selectedRing).menuActions
            --if the item has single action, proceed with direct action for items like medipack and flares.
            if isSingleFlagSet(menuActions) then  
                ParseMenuAction(menuActions)
            else
                inventoryMode = INVENTORY_MODE.ITEM_SELECT  
            end
        elseif (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) and LevelVars.Engine.CustomInventory.InventoryOpenFreeze then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.RING_CLOSING
        end
    elseif mode == INVENTORY_MODE.COMBINE then

        if guiIsPulsed(TEN.Input.ActionID.LEFT) then
            doLeftKey()
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            doRightKey()
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) or guiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            performCombine = true
        elseif (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end
    elseif mode == INVENTORY_MODE.STATISTICS then

        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.STATISTICS_CLOSE
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE then

        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.WEAPON_MODE_CLOSE
        end
    elseif mode == INVENTORY_MODE.SAVE_MENU then

        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.SAVE_CLOSE
        end
    elseif mode == INVENTORY_MODE.ITEM_SELECTED then
        if (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.ITEM_DESELECT
        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT then

        if guiIsPulsed(TEN.Input.ActionID.LEFT) then
            doLeftKey()
        elseif guiIsPulsed(TEN.Input.ActionID.RIGHT) then
            doRightKey()
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) or guiIsPulsed(TEN.Input.ActionID.SELECT) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            performCombine = true
        elseif (guiIsPulsed(TEN.Input.ActionID.INVENTORY) or guiIsPulsed(TEN.Input.ActionID.DESELECT)) then
            TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_CLOSE)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
        end
    elseif mode == INVENTORY_MODE.EXAMINE then
         -- Static variables
        local ROTATION_MULTIPLIER = 2
        local ZOOM_MULTIPLIER = 0.3
        -- Handle rotation input
        if TEN.Input.IsKeyHeld(TEN.Input.ActionID.FORWARD) then
            examineRotation.x = examineRotation.x + ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.BACK) then
            examineRotation.x = examineRotation.x - ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.LEFT) then
            examineRotation.y = examineRotation.y + ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.RIGHT) then
            examineRotation.y = examineRotation.y - ROTATION_MULTIPLIER
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.SPRINT) then
            examineScaler = examineScaler + (ZOOM_MULTIPLIER)
        elseif TEN.Input.IsKeyHeld(TEN.Input.ActionID.CROUCH) then
            examineScaler = examineScaler - (ZOOM_MULTIPLIER)
        elseif guiIsPulsed(TEN.Input.ActionID.ACTION) then
            examineShowString = not examineShowString
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
        elseif guiIsPulsed(TEN.Input.ActionID.INVENTORY) then
            TEN.Sound.PlaySound(SOUND_MAP.MENU_CHOOSE)
            inventoryMode = INVENTORY_MODE.EXAMINE_RESET
        end
    else
        return
    end
end

local contains = function(tbl, value)
    for _, v in ipairs(tbl) do
    if v == value then
        return true
    end
    end
    return false
end

--Only uses combine and ammo as an option. Everything else dumps the whole inventory.
LevelFuncs.Engine.CustomInventory.ConstructObjectList = function(ringType, selectedWeapon)

    addedItems = 0
    local items  = PICKUP_DATA.constants

    if ringType == RING.AMMO or ringType == RING.COMBINE then
        ClearInventory(ringType, true)
    else
        ClearInventory()
    end

    for _, itemRow in ipairs(items) do

        local itemData = PICKUP_DATA.ConvertRowData(itemRow)
        local data = BuildInventoryItem(itemData)
        
        --copy rotation rather than a reference
        data.rotation = copyRotation(data.rotation)

        --Check if weapon is present and skip adding ammo to main inventory ring
        if data.type == TYPE.AMMO and ringType ~= RING.AMMO then
    
            local weaponPresent = TEN.Inventory.GetItemCount(PICKUP_DATA.AMMO_SET[data.objectID].weapon)
            if weaponPresent ~= 0 then
                goto continue
            end

        end

        --Check if laseright is connected and adjust the meshbits and name
        if data.type == TYPE.WEAPON then
            if Lara:GetLaserSight(PICKUP_DATA.WEAPON_SET[data.objectID].slot) then
                data.meshBits = PICKUP_DATA.WEAPON_LASERSIGHT_DATA[data.objectID].MESHBITS
                data.name = PICKUP_DATA.WEAPON_LASERSIGHT_DATA[data.objectID].NAME
                data.menuActions = PICKUP_DATA.WEAPON_LASERSIGHT_DATA[data.objectID].FLAGS
            end
        end

        --ammoRing is a bool to make sure to add ammo to the ring if creating an ammo ring even if the count is zero
        local ammoRing = false
        --shouldInsert is a bool to make sure the item gets added to the ring being created
        local shouldInsert = false

        --Check if a combine ring is being created and only proceed if the item is a combine type otherwise skip to continue
        if ringType == RING.COMBINE then
            if data.combine == true then
                data.ringName = RING.COMBINE

                --skip adding the selected item
                if combineItem1 == data.objectID then
                    goto continue
                end

                --Check if lasersight is connected and if it is skip adding to the combine table
                if data.type == TYPE.WEAPON and Lara:GetLaserSight(PICKUP_DATA.WEAPON_SET[data.objectID].slot) then
                    goto continue
                end

                --should only insert the item if count is not zero
                shouldInsert = (data.count ~= 0)

            else
                --skip adding this item to table if the item is not a combine type
                goto continue
            end
        elseif ringType == RING.AMMO then
            --if Ammo is present for the weapon add it for the ammo ring being created for the weapon
   
            if data.type == TYPE.AMMO and PICKUP_DATA.WEAPON_AMMO_LOOKUP[selectedWeapon] and contains(PICKUP_DATA.WEAPON_AMMO_LOOKUP[selectedWeapon], data.objectID) then
                data.ringName = RING.AMMO
                ammoRing = true
                shouldInsert = true
            else
                --skip adding this item to table if the item is not an ammo type 
                goto continue
            end
        else
            -- Dump all inventory, skip only if count is 0
            shouldInsert = (data.count ~= 0)
        end

        inventory.ring[data.ringName] = inventory.ring[data.ringName] or {}
        
        if debug then
            print("Item: "..Util.GetObjectIDString(data.objectID))
            print("shouldInsert: ".. tostring(shouldInsert))
            print("ammoRing: " .. tostring(ammoRing))
            print("Actions:"..tostring(menuActions))
        end

        if shouldInsert or ammoRing then
            table.insert(inventory.ring[data.ringName], data)
            local inventoryItem = TEN.View.DisplayItem(tostring(data.objectID), data.objectID, RING_CENTER[data.ringName], data.rotation, data.scale, data.meshBits)
            inventoryItem:SetColor(COLOR_MAP.ITEM_COLOR)
            addedItems = addedItems + 1
        end

        ::continue::
    end

    --Calculate the slice angle and save it
    if ringType then
        local ringItems = inventory.ring[ringType] or {}
        local count = #ringItems
        inventory.selectedItem[ringType] = 1
        inventory.slice[ringType] = (count > 0) and (360 / count) or 0
        inventory.ringPosition[ringType] = RING_CENTER[ringType]
    else
        for index, ringItems in pairs(inventory.ring) do
            local count = #ringItems
            inventory.selectedItem[index] = 1
            inventory.slice[index] = (count > 0) and (360 / count) or 0
            inventory.ringPosition[index] = RING_CENTER[index]
        end
    end

end

LevelFuncs.Engine.CustomInventory.ReadGameflow = function()

    local overrides = {}
    for _, itemID in ipairs(TEN.Flow.GetCurrentLevel().objects) do

        if itemID.objectID then
            local id = TEN.Inventory.ConvertInventoryItemToObject(itemID.objectID)
            overrides[id] = { 
                    item = id,
                    yOffset = itemID.yOffset,
                    scale = itemID.scale,
                    rotation = itemID.rotation,
                    menuActions = itemID.action,
                    name = itemID.nameKey,
                    meshBits = itemID.meshBits,
                    orientation = itemID.axis
            }
        end
    end

    return overrides

end

local SetRingVisibility = function(ringName, visible)
    
    local ring = inventory.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring

    for i = 1, itemCount do
        local currentItem = ring[i].objectID
        local inventoryItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        inventoryItem:SetVisible(visible)
    end
end

local TranslateRing = function(ringName, center, radius, rotationOffset)

    local ring = inventory.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring
    
    for i = 1, itemCount do
        local currentItem = ring[i].objectID 

        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        local angleDeg = (360 / itemCount) * (i - 1) +  rotationOffset
       
        local position = center:Translate(Rotation(0,angleDeg,0),radius)

        local itemRotations  = currentDisplayItem:GetRotation()

        currentDisplayItem:SetPosition(offsetY(position, ring[i].yOffset))
        currentDisplayItem:SetRotation(Rotation(itemRotations.x, angleDeg, itemRotations.z))
    end

end

local FadeRing = function(ringName, fadeValue, omitSelectedItem)
    
    local ring = inventory.ring[ringName]

    if not ring then
        return
    end

    local itemCount = #ring
    local selectedItem = omitSelectedItem and GetSelectedItem(selectedRing).objectID

    for i = 1, itemCount do
        local currentItem = ring[i].objectID 
        local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(tostring(currentItem))
        if omitSelectedItem and selectedItem == currentItem then
            goto continue
        end

        local itemColor = currentDisplayItem:GetColor()
        currentDisplayItem:SetColor(colorCombine(itemColor, fadeValue))

        ::continue::
    end
end

local FadeRings = function(visible, omitSelectedRing)
    
    local fadeValue = visible and 255 or 0

    for index in pairs(inventory.ring) do
        
        if not (omitSelectedRing and index == selectedRing) then
            FadeRing(index, fadeValue, false)
            SetRingVisibility(index, visible)
        end
    end

end

local RotateItem = function(itemName)

    local currentDisplayItem = TEN.View.DisplayItem.GetItemByName(itemName)
    local itemRotations  = currentDisplayItem:GetRotation()
    currentDisplayItem:SetRotation(Rotation(itemRotations.x, (itemRotations.y + ROTATION_SPEED) % 360, itemRotations.z))
end

local OpenInventoryAtItem = function(itemID)

    if itemID == NO_VALUE then
		return
	end

    local ringIndex, itemIndex = FindItemInInventory(itemID)

    if not (ringIndex and itemIndex) then
		return
	end

    selectedRing = ringIndex
    inventory.selectedItem[ringIndex] = itemIndex
    local slice = inventory.slice[ringIndex]
	local angle = -slice * (itemIndex - 1) --this has to be a negative angle cause reasons.
    currentRingAngle = angle
    targetRingAngle = angle

    -- Position the selected ring at RING.MAIN
	local ringPosition = RING_CENTER[RING.MAIN]

	for index in pairs(inventory.ring) do
		local offset = (index - selectedRing) * RING_POSITION_OFFSET
		inventory.ringPosition[index] = Vec3(ringPosition.x, ringPosition.y + offset, ringPosition.z)
        TranslateRing(index, inventory.ringPosition[index], RING_RADIUS, angle)
	end

    --Hack for save menu loading
    if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM or itemID == TEN.Objects.ObjID.PC_LOAD_INV_ITEM then
        if itemID == TEN.Objects.ObjID.PC_SAVE_INV_ITEM then
            saveList = true  
        end
        saveSelected = true
    end

end

local OpenAmmoRingAtSelectedAmmo = function(itemID)

    if itemID == NO_VALUE then
		return
	end

    local ringIndex, itemIndex = FindItemInInventory(itemID)

    if not (ringIndex and itemIndex) then
		return
	end

    inventory.selectedItem[ringIndex] = itemIndex
    local slice = inventory.slice[ringIndex]
	local angle = -slice * (itemIndex - 1) --this has to be a negative angle cause reasons.
    currentRingAngle = angle
    targetRingAngle = angle
    
    --Set index of the item
    changeOptionsforMenu()
end

local SetupSecondaryRing = function(ringName, item)
    --used for combine and ammo rings

    previousRing = selectedRing
    combineItem1 = item or GetSelectedItem(selectedRing).objectID
    targetRingAngle = 0
    currentRingAngle = 0
    LevelFuncs.Engine.CustomInventory.ConstructObjectList(ringName, combineItem1)
    selectedRing = ringName
    CreateRingMenu(ringName)
    inventory.ringPosition[ringName] = RING_CENTER[ringName]

    --to set the ring angle at the selected ammo
    if ringName == RING.AMMO then
        
        local weaponSlot = PICKUP_DATA.WEAPON_SET[combineItem1].slot
        local ammoType   = Lara:GetAmmoType(weaponSlot)

        --SUPER FAST O(1) LOOKUP
        local objectID = PICKUP_DATA.AMMO_TYPE_TO_OBJECT[ammoType]
        
        OpenAmmoRingAtSelectedAmmo(objectID)
        
    end

end

local ShowChosenAmmo = function(item, textOnly)

    local inventoryItem = GetInventoryItem(item)
    if not inventoryItem or inventoryItem.type ~= TYPE.WEAPON then
        return
    end

    local slot = PICKUP_DATA.WEAPON_SET[item].slot
    local ammoType = Lara:GetAmmoType(slot)
    if not ammoType then
        return
    end

    local objectID = PICKUP_DATA.AMMO_TYPE_TO_OBJECT[ammoType]
    if not objectID then
        return
    end

    local row  = PICKUP_DATA.GetRow(objectID)
    local base = PICKUP_DATA.ConvertRowData(row)

    if ammoAdded and not textOnly then
        local data = BuildInventoryItem(base)
        data.rotation = copyRotation(data.rotation)

        local ammoItem = TEN.View.DisplayItem(
            "ChosenAmmo",
            data.objectID,
            AMMO_LOCATION,
            data.rotation,
            data.scale,
            data.meshBits
        )

        ammoItem:SetColor(COLOR_MAP.ITEM_COLOR_VISIBLE)
        ammoAdded = false
    end

    local data = BuildInventoryItem(base)
    LevelFuncs.Engine.CustomInventory.DrawItemLabel(data, false)

    if not textOnly then RotateItem("ChosenAmmo") end

end

local DeleteChosenAmmo = function()

    TEN.View.DisplayItem.RemoveItem("ChosenAmmo")
    ammoAdded = true

end

LevelFuncs.Engine.CustomInventory.ExitInventory = function()

    LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
    ClearInventory(nil, true)
    TEN.Inventory.SetEnterInventory(NO_VALUE)
    Interpolate.ClearAll()
    Menu.DeleteAll()
    View.SetFOV(80)
    Flow.SetFreezeMode(Flow.FreezeMode.NONE)
    LevelVars.Engine.CustomInventory.InventoryClosed = true
    inventoryMode = INVENTORY_MODE.RING_OPENING
    selectedRing = RING.MAIN
    TEN.View.DisplayItem.SetCameraPosition(CAMERA_START)
    TEN.View.DisplayItem.SetTargetPosition(TARGET_START)
    timeInMenu = 0
    saveList = false
    combineItem1 = nil

end

LevelFuncs.Engine.CustomInventory.UpdateInventory = function()

    timeInMenu = timeInMenu + 1

    DrawBackground(255)

    if LevelVars.Engine.CustomInventory.InventoryOpen then
        TEN.View.SetFOV(80)
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        currentRingAngle = 0
        targetRingAngle = 0
        TEN.Sound.PlaySound(SOUND_MAP.INVENTORY_OPEN)
        LevelFuncs.Engine.CustomInventory.ConstructObjectList()
        LevelVars.Engine.CustomInventory.InventoryOpen = false
        OpenInventoryAtItem(inventoryOpenItem)
    else
        LevelFuncs.Engine.CustomInventory.DrawInventoryHeader(inventoryHeader)
        LevelFuncs.Engine.CustomInventory.DrawInventorySubHeader(inventorySubHeader)
        Input(inventoryMode)
        --LevelFuncs.Engine.CustomInventory.ControlTexts(inventoryMode)
        LevelFuncs.Engine.CustomInventory.DrawInventory(inventoryMode)

        --Set rotation of InventoryItems like compass and stopwatch
        SetRotationInventoryItems()

    end
end

function CustomInventory.Run()
    
    if inventoryStart then
        inventoryStart = false
        LevelVars.Engine.CustomInventory = {}
        LevelVars.Engine.CustomInventory.InventoryOpen = false
        LevelVars.Engine.CustomInventory.InventoryOpenFreeze = false
        LevelVars.Engine.CustomInventory.InventoryClosed = false
        TEN.View.DisplayItem.SetCameraPosition(CAMERA_START)
        TEN.View.DisplayItem.SetTargetPosition(TARGET_START)
        TEN.View.DisplayItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)

        TEN.Inventory.SetInventoryOverride(true)
    end

    if useBinoculars then
        TEN.View.UseBinoculars()
        useBinoculars = false
    end

    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS

    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.Inventory.GetEnterInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and playerHp and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Inventory.GetEnterInventory()
        inventoryDelay = 0
    end

    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.SAVE) or TEN.Inventory.GetEnterInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and playerHp and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Objects.ObjID.PC_SAVE_INV_ITEM
        inventoryDelay = 0
        
    end

    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.Inventory.GetEnterInventory() ~= NO_VALUE) and not LevelVars.Engine.CustomInventory.InventoryOpen and isNotUsingBinoculars  then
        LevelVars.Engine.CustomInventory.InventoryOpen = true
        inventoryOpenItem = TEN.Objects.ObjID.PC_LOAD_INV_ITEM
        inventoryDelay = 0
    end

    if LevelVars.Engine.CustomInventory.InventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(COLOR_MAP.BACKGROUND.a / 255) --use alpha to define the strenght of the effect
        TEN.View.SetPostProcessTint(COLOR_MAP.BACKGROUND)

        if inventoryDelay >= 2 then
            TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.CustomInventory.UpdateInventory)
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end

    
    if LevelVars.Engine.CustomInventory.InventoryClosed then
        TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.CustomInventory.UpdateInventory)
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_COLOR_VISIBLE)
        LevelVars.Engine.CustomInventory.InventoryClosed = false
    end
end

-- Clear progress for a batch
local ClearBatchMotionProgress = function(prefix, motionTable)
    for _, motion in ipairs(motionTable) do
        local id = prefix .. motion.key
        Interpolate.Clear(id)
    end
end

-- Perform a batch of motions and apply their effects
local PerformBatchMotion = function(prefix, motionTable, time, clearProgress, ringName, item, reverse)
    local interpolated = {}
    local allComplete = true
    local omitSelectedItem = item and true or false

    for _, motion in ipairs(motionTable) do
        local id = prefix .. motion.key
        local interp = {output = motion.start, progress = PROGRESS_COMPLETE}

        if motion.start ~= motion.finish then
            local startVal = reverse and motion.finish or motion.start
            local endVal = reverse and motion.start or motion.finish
            interp = Interpolate.Calculate(id, motion.type, startVal, endVal, time, true)
        end

        interpolated[motion.key] = interp
        
        if interp.progress < PROGRESS_COMPLETE then
            allComplete = false
        end
    end

    if interpolated.ringCenter or interpolated.ringRadius or interpolated.ringAngle then
        local center = interpolated.ringCenter and interpolated.ringCenter.output or inventory.ringPosition[ringName]
        local radius = interpolated.ringRadius and interpolated.ringRadius.output or RING_RADIUS
        local angle = interpolated.ringAngle and interpolated.ringAngle.output or 0
        TranslateRing(ringName, center, radius, angle)
    end

    if interpolated.ringFade then
        FadeRing(ringName, interpolated.ringFade.output, omitSelectedItem)
    end

    if interpolated.camera then TEN.View.DisplayItem.SetCameraPosition(interpolated.camera.output) end
    if interpolated.target then TEN.View.DisplayItem.SetTargetPosition(interpolated.target.output) end

    if item then
        local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(item.objectID))
        if interpolated.itemColor then displayItem:SetColor(interpolated.itemColor.output) end
        if interpolated.itemPosition then displayItem:SetPosition(offsetY(interpolated.itemPosition.output, item.yOffset)) end
        if interpolated.itemScale then displayItem:SetScale(interpolated.itemScale.output) end
        if interpolated.itemRotation then displayItem:SetRotation(interpolated.itemRotation.output) end
    end

    if allComplete then
        if clearProgress then
            ClearBatchMotionProgress(prefix, motionTable)
        end
        return true
    end
end

local AnimateInventory = function(mode)

    local selectedItem = GetSelectedItem(selectedRing)

    local ringAnimation = {
        { key = "ringRadius", type = Interpolate.Type.LINEAR, start = 0, finish = RING_RADIUS },
        { key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = currentRingAngle },
        { key = "ringCenter", type = Interpolate.Type.VEC3, start = inventory.ringPosition[selectedRing], finish = inventory.ringPosition[selectedRing] },
        { key = "ringFade", type = Interpolate.Type.LINEAR, start = 0, finish = 255 },
        { key = "camera", type = Interpolate.Type.VEC3, start = CAMERA_START, finish = CAMERA_END },
        { key = "target", type = Interpolate.Type.VEC3, start = TARGET_START, finish = TARGET_END },
        }

    local useAnimation = {
        { key = "itemPosition", type = Interpolate.Type.VEC3, start = ITEM_START, finish = ITEM_END },
        { key = "itemScale", type = Interpolate.Type.LINEAR, start = examineScalerOld, finish = examineScaler },
        { key = "itemRotation", type = Interpolate.Type.ROTATION, start = itemRotationOld, finish = itemRotation },
        }

    local examineReset = {
        useAnimation[2],
        { key = "itemRotation", type = Interpolate.Type.ROTATION, start = itemRotation, finish = examineRotation },
        }

    local examineAnimation = {
        useAnimation[1],
        useAnimation[2],
        useAnimation[3],
        { key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MAX, finish = ALPHA_MIN},
        }

    local combineRingAnimation = {
        ringAnimation[1],
        ringAnimation[2],
        ringAnimation[3],
        ringAnimation[4]
        }

    local combineClose = {
        { key = "ringFade", type = Interpolate.Type.LINEAR, start = ALPHA_MAX, finish = ALPHA_MIN}
        }

    if mode == INVENTORY_MODE.RING_OPENING then

        if PerformBatchMotion("RingOpening", ringAnimation, INVENTORY_ANIM_TIME, true, selectedRing) then

            --set alpha for all rings. This is required to make items in other items visible.
            FadeRings(true, true)
            LevelVars.Engine.CustomInventory.InventoryOpenFreeze = true
            return true
        end

    elseif mode == INVENTORY_MODE.RING_CLOSING then

        --Hide other rings to ensure the closing animation looks clean.
        FadeRings(false, true)

        if PerformBatchMotion("RingClosing", ringAnimation, INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end

    elseif mode == INVENTORY_MODE.RING_CHANGE then
        
        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            local oldPosition = inventory.ringPosition[index]
            local newPosition = Vec3(oldPosition.x, oldPosition.y + direction * RING_POSITION_OFFSET, oldPosition.z) 
            local motionSet = {
            { key = "ringAngle", type = Interpolate.Type.LINEAR, start = -360, finish = 0},
            { key = "ringCenter", type = Interpolate.Type.VEC3, start = oldPosition, finish = newPosition},
            }

            if PerformBatchMotion("RingChange"..index, motionSet, INVENTORY_ANIM_TIME, true, index) then
                inventory.ringPosition[index] = newPosition
            else
                allMotionComplete = false
            end

        end
        
        if allMotionComplete then
            return true
        end
    
    elseif mode == INVENTORY_MODE.RING_ROTATE then

        local motionSet = {
            { key = "ringAngle", type = Interpolate.Type.LINEAR, start = currentRingAngle, finish = targetRingAngle},
            }

            if PerformBatchMotion("RingRotate", motionSet, INVENTORY_ANIM_TIME/4, true, selectedRing) then
                currentRingAngle = targetRingAngle
                return true
            end
        
    elseif mode == INVENTORY_MODE.EXAMINE_OPEN or mode == INVENTORY_MODE.STATISTICS_OPEN or mode == INVENTORY_MODE.SAVE_SETUP or mode == INVENTORY_MODE.COMBINE_SETUP or mode == INVENTORY_MODE.ITEM_SELECT or mode == INVENTORY_MODE.COMBINE_SUCCESS then

        if PerformBatchMotion("ExamineOpen", examineAnimation, INVENTORY_ANIM_TIME, true, selectedRing, selectedItem) then
            return true
        end

    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE or mode == INVENTORY_MODE.STATISTICS_CLOSE or mode == INVENTORY_MODE.SAVE_CLOSE or mode == INVENTORY_MODE.ITEM_DESELECT then

        if PerformBatchMotion("ExamineClose", examineAnimation, INVENTORY_ANIM_TIME, true, selectedRing, selectedItem, true) then
            return true
        end

    elseif mode == INVENTORY_MODE.EXAMINE_RESET then

        if PerformBatchMotion("ExamineReset", examineReset, INVENTORY_ANIM_TIME/4, true, selectedRing, selectedItem, true) then
            return true
        end

    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING or mode == INVENTORY_MODE.AMMO_SELECT_OPEN then

        if PerformBatchMotion("CombineRingOpening", combineRingAnimation, INVENTORY_ANIM_TIME, true, selectedRing) then
            return true
        end

    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then

        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, INVENTORY_ANIM_TIME, true, index) then
                allMotionComplete = false 
            end

        end
        
        if allMotionComplete then
            return true
        end

    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then

        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false 
            end

        end
        
        if allMotionComplete then
            return true
        end

    elseif mode == INVENTORY_MODE.ITEM_USE then

        if combineItem1 or PerformBatchMotion("ItemSelect", useAnimation, INVENTORY_ANIM_TIME, false, selectedRing, selectedItem) then
            if PerformBatchMotion("ItemDeselect", useAnimation, INVENTORY_ANIM_TIME, false, selectedRing, selectedItem, true) then
                FadeRings(false, true)
                if PerformBatchMotion("RingClosing", ringAnimation, INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
                    if not combineItem1 then ClearBatchMotionProgress("ItemSelect", useAnimation) end
                    ClearBatchMotionProgress("ItemDeselect", useAnimation)
                    return true
                end
            end
        end

    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then

        if PerformBatchMotion("AmmoRingClosing", combineRingAnimation, INVENTORY_ANIM_TIME, true, selectedRing, nil, true) then
            return true
        end
    elseif mode == INVENTORY_MODE.SEPARATE then

    local allMotionComplete = true

    for index in pairs(inventory.ring) do

        if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, INVENTORY_ANIM_TIME, true, index) then
            allMotionComplete = false 
        end

    end
    
    if allMotionComplete then
        return true
    end

    elseif mode == INVENTORY_MODE.SEPARATE_COMPLETE then

        local allMotionComplete = true

        for index in pairs(inventory.ring) do

            if not PerformBatchMotion("combineCloseSuccess"..index, combineClose, INVENTORY_ANIM_TIME, true, index, nil, true) then
                allMotionComplete = false 
            end

        end
        
        if allMotionComplete then
            return true
        end
    end

end

local SaveItemData = function(selectedItem)
   
    if itemStoreRotations then
        local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(selectedItem.objectID))
        itemRotationOld =  displayItem:GetRotation()
        itemRotation = selectedItem.rotation
        examineRotation = copyRotation(selectedItem.rotation)
        examineScalerOld = selectedItem.scale
        examineScaler = selectedItem.scale
        itemStoreRotations = false
    end
end

LevelFuncs.Engine.CustomInventory.DrawInventory = function(mode)
    
    local selectedItem = GetSelectedItem(selectedRing)

    if mode == INVENTORY_MODE.INVENTORY then
        
        RotateItem(tostring(selectedItem.objectID))
        ShowChosenAmmo(selectedItem.objectID, true)
        LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem, true)

    elseif mode == INVENTORY_MODE.RING_OPENING then
        
        if AnimateInventory(mode) then

            if saveSelected then
                itemStoreRotations = true
                inventoryMode = INVENTORY_MODE.SAVE_SETUP
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
            
        end

    elseif mode == INVENTORY_MODE.RING_CLOSING then

        if AnimateInventory(mode) then

            LevelFuncs.Engine.CustomInventory.ExitInventory()

        end

    elseif mode == INVENTORY_MODE.RING_ROTATE then

        if AnimateInventory(mode) then
            currentRingAngle = targetRingAngle
            
            if previousMode then
                inventoryMode = previousMode
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end

        end

    elseif mode == INVENTORY_MODE.RING_CHANGE then

        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
            
            --reset to first item in ring
            for index, _ in ipairs(inventory.selectedItem) do
                inventory.selectedItem[index] = 1
            end

            currentRingAngle = 0
            targetRingAngle = 0

        end

    elseif mode == INVENTORY_MODE.EXAMINE_OPEN then
        
        SaveItemData(selectedItem)
        DeleteChosenAmmo()
        setInventoryHeader("examine", true)
        if combineItem1 or AnimateInventory(mode) then

            inventoryMode = INVENTORY_MODE.EXAMINE

        end

    elseif mode == INVENTORY_MODE.EXAMINE then

        LevelFuncs.Engine.CustomInventory.ExamineItem(selectedItem.objectID)

    elseif mode == INVENTORY_MODE.EXAMINE_RESET then
        
        if AnimateInventory(mode) then
            examineScaler = examineScalerOld
            inventoryMode = INVENTORY_MODE.EXAMINE_CLOSE
        end

    elseif mode == INVENTORY_MODE.EXAMINE_CLOSE then
        setInventoryHeader("actions_inventory", true)
        if combineItem1 or AnimateInventory(mode) then
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end

    elseif mode == INVENTORY_MODE.ITEM_SELECT then
        
        SaveItemData(selectedItem)

        if AnimateInventory(mode) then
            previousRingAngle = currentRingAngle
            combineItem1 = selectedItem.objectID
            setInventoryHeader(selectedItem.name, true)
            CreateItemMenu(selectedItem.objectID)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED

        end

    elseif mode == INVENTORY_MODE.ITEM_SELECTED then

        ShowItemMenu()
        ShowChosenAmmo(combineItem1)

    elseif mode == INVENTORY_MODE.ITEM_DESELECT then
        
        DeleteChosenAmmo()
        setInventoryHeader("actions_inventory", true)
        if AnimateInventory(mode) then
            combineItem1 = nil
            currentRingAngle = previousRingAngle
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.STATISTICS_OPEN then
        
        DeleteChosenAmmo()
        SaveItemData(selectedItem)
        CreateStatisticsMenu()
        setInventoryHeader("actions_inventory", false)
        if combineItem1 or  AnimateInventory(mode)then
            inventoryMode = INVENTORY_MODE.STATISTICS
        end

    elseif mode == INVENTORY_MODE.STATISTICS then
        
        RunStatisticsMenu()
        Statistics.ShowLevelStats(statisticsType)

    elseif mode == INVENTORY_MODE.STATISTICS_CLOSE then

        if combineItem1 or AnimateInventory(mode) then
            setInventoryHeader("actions_inventory", true)
            inventoryMode = combineItem1 and INVENTORY_MODE.ITEM_SELECTED or INVENTORY_MODE.INVENTORY
        end

    elseif mode == INVENTORY_MODE.SAVE_SETUP then

        DeleteChosenAmmo()
        SaveItemData(selectedItem)

        if combineItem1 or  AnimateInventory(mode) then
            CreateSaveMenu(saveList)
            setInventoryHeader("actions_inventory", false)
            inventoryMode = INVENTORY_MODE.SAVE_MENU
        end

    elseif mode == INVENTORY_MODE.SAVE_MENU then
        
        RunSaveMenu()

    elseif mode == INVENTORY_MODE.SAVE_CLOSE then

        if combineItem1 then
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        elseif AnimateInventory(mode) then
            setInventoryHeader("actions_inventory", true)
            if saveSelected then
                saveSelected = false
                inventoryMode = INVENTORY_MODE.RING_CLOSING
            else
                inventoryMode = INVENTORY_MODE.INVENTORY
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SETUP then
        
        DeleteChosenAmmo()
        SaveItemData(selectedItem)

        if  combineItem1 or AnimateInventory(mode) then
            SetupSecondaryRing(RING.COMBINE)
            setInventoryHeader(selectedItem.name, true)
            setInventorySubHeader("combine_with", true)
            inventoryMode = INVENTORY_MODE.COMBINE_RING_OPENING
        end

    elseif mode == INVENTORY_MODE.COMBINE_RING_OPENING then
        
        if AnimateInventory(mode) then
            
            inventoryMode = INVENTORY_MODE.COMBINE

        end

    elseif mode == INVENTORY_MODE.COMBINE then
        RotateItem(tostring(selectedItem.objectID))
        LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem, true)

        --ShowRingMenu()

        if performCombine then

            combineItem2 = GetSelectedItem(RING.COMBINE).objectID

            if CombineItems(combineItem1, combineItem2) then
                TEN.Sound.PlaySound(SOUND_MAP.MENU_COMBINE)
                inventoryMode = INVENTORY_MODE.COMBINE_SUCCESS
            else
                TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
                performCombine = false
            end
        end
    elseif mode == INVENTORY_MODE.COMBINE_SUCCESS then

        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.COMBINE_CLOSE
        end

    elseif mode == INVENTORY_MODE.COMBINE_CLOSE then
        
        if AnimateInventory(mode) then
            setInventorySubHeader("combine_with", false)
            setInventoryHeader("actions_inventory", true)
            inventoryOpenItem = combineResult and combineResult or combineItem1
            combineItem1 = nil
            combineItem2 = nil
            combineResult = nil
            performCombine = false
            inventoryMode = INVENTORY_MODE.COMBINE_COMPLETE
            LevelVars.Engine.CustomInventory.InventoryOpen = true
        end
    elseif mode == INVENTORY_MODE.COMBINE_COMPLETE then
        
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.ITEM_USE then
        
        SaveItemData(selectedItem)
        DeleteChosenAmmo()

        if AnimateInventory(mode) then
            
            LevelFuncs.Engine.CustomInventory.UseItem(selectedItem.objectID)

        end
    elseif mode == INVENTORY_MODE.AMMO_SELECT_SETUP then
        
        SaveItemData(selectedItem)
        DeleteChosenAmmo()

        SetupSecondaryRing(RING.AMMO, combineItem1)
        inventoryMode = INVENTORY_MODE.AMMO_SELECT_OPEN

    elseif mode == INVENTORY_MODE.AMMO_SELECT_OPEN then

        if AnimateInventory(mode) then
            setInventorySubHeader("choose_ammo", true)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT
        end

    elseif mode == INVENTORY_MODE.AMMO_SELECT then
        
        RotateItem(tostring(selectedItem.objectID))
        --ShowRingMenu()
        LevelFuncs.Engine.CustomInventory.DrawItemLabel(selectedItem, false)
        if performCombine then
            local ammo = PICKUP_DATA.AMMO_SET[selectedItem.objectID]
            Lara:SetAmmoType(ammo.slot)
            inventoryMode = INVENTORY_MODE.AMMO_SELECT_CLOSE
        end

    elseif mode == INVENTORY_MODE.AMMO_SELECT_CLOSE then
        
        if AnimateInventory(mode) then
            performCombine = false
            selectedRing = previousRing
            setInventorySubHeader("choose_ammo", false)
            inventoryMode = INVENTORY_MODE.ITEM_SELECTED
        end
    elseif mode == INVENTORY_MODE.SEPARATE then
        
        DeleteChosenAmmo()

        if AnimateInventory(mode) then
            SeparateItems(selectedItem.objectID)
            inventoryOpenItem = combineItem1
            combineItem1 = nil
            LevelVars.Engine.CustomInventory.InventoryOpen = true
            inventoryMode = INVENTORY_MODE.SEPARATE_COMPLETE
        end
    elseif mode == INVENTORY_MODE.SEPARATE_COMPLETE then
        
        if AnimateInventory(mode) then
            inventoryMode = INVENTORY_MODE.INVENTORY
        end
    elseif mode == INVENTORY_MODE.WEAPON_MODE_SETUP then

        CreateWeaponModeMenu(combineItem1)
        setInventorySubHeader("choose_ammo", true)
        inventoryMode = INVENTORY_MODE.WEAPON_MODE

    elseif mode == INVENTORY_MODE.WEAPON_MODE then
        RunWeaponModeMenu()

    elseif mode == INVENTORY_MODE.WEAPON_MODE_CLOSE then
        setInventorySubHeader("choose_ammo", false)
        inventoryMode = INVENTORY_MODE.ITEM_SELECTED

    end
end

LevelFuncs.Engine.CustomInventory.UseItem = function(item)

    local levelStatistics = Flow.GetStatistics()
    local gameStatistics = Flow.GetStatistics(true)

    local CROUCH_STATES ={
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

    local TestState = function(table)
        local currentState = Lara:GetState()
        for _, state in pairs(table) do
            if currentState == state then
                return true
            end
        end
        return false
    end

    local CrawlTest = function(item)

        if item.crawl then
            return true
        end

        return not (TestState(CROUCH_STATES) or TestState(CRAWL_STATES))

    end

    local WaterTest = function(item)
        
        if item.underwater then
            return true
        end

        return (Lara:GetWaterStatus() == TEN.Objects.WaterStatus.DRY or Lara:GetWaterStatus() == TEN.Objects.WaterStatus.WADE)

    end

	TEN.Inventory.SetUsedItem(item)

	--Use item event handling.
	TEN.Util.OnUseItemCallBack()
    
    --Quickly discard further processing if chosen item was reset in script.
    if (TEN.Inventory.GetUsedItem() == NO_VALUE) then
        LevelFuncs.Engine.CustomInventory.ExitInventory()
        return
    end

    if PICKUP_DATA.WEAPON_SET[item] and WaterTest(PICKUP_DATA.WEAPON_SET[item]) and CrawlTest(PICKUP_DATA.WEAPON_SET[item]) then
        
        TEN.Inventory.ClearUsedItem()

        local currentWeapon = Lara:GetWeaponType()

        --Return if flare is already equipped
        if item == TEN.Objects.ObjID.FLARE_INV_ITEM and currentWeapon == TEN.Objects.WeaponType.FLARE then
            LevelFuncs.Engine.CustomInventory.ExitInventory()
            return
        end
        
        Lara:SetWeaponType(PICKUP_DATA.WEAPON_SET[item].slot, true)

        if currentWeapon == PICKUP_DATA.WEAPON_SET[item].slot and Lara:GetHandStatus() ~= TEN.Objects.HandStatus.WEAPON_READY then
            Lara:SetHandStatus(TEN.Objects.HandStatus.WEAPON_DRAW)
        end

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
                LevelFuncs.Engine.CustomInventory.ExitInventory()
                return
            end
        end

        local count = TEN.Inventory.GetItemCount(item)
        
        if count then
            if count ~= NO_VALUE then
                TEN.Inventory.TakeItem(item, 1)
            end

            Lara:SetPoison(0)
            
            local setHP = math.min(1000, (hp + PICKUP_DATA.HEALTH_SET[item]))
            Lara:SetHP(setHP)

            TEN.Sound.PlaySound(SOUND_MAP.TR4_MENU_MEDI)
            
            --update statistics for health item used
            levelStatistics.healthPacksUsed = levelStatistics.healthPacksUsed + 1
            gameStatistics.healthPacksUsed = gameStatistics.healthPacksUsed + 1
            Flow.SetStatistics(levelStatistics)
            Flow.SetStatistics(gameStatistics, true)
        end

    end

    if item == TEN.Objects.ObjID.BINOCULARS_ITEM then
        
        TEN.Inventory.ClearUsedItem()
        useBinoculars = true

    end

    LevelFuncs.Engine.CustomInventory.ExitInventory()

end

LevelFuncs.Engine.CustomInventory.ExamineItem = function(item)
    
    examineScaler = math.max(EXAMINE_MIN_SCALE, math.min(EXAMINE_MAX_SCALE, examineScaler))

    -- Get the localized string key
    local objectName = Util.GetObjectIDString(item)
    local stringKey = objectName:lower() .. "_text"
    local localizedString = IsStringPresent(stringKey) and GetString(stringKey) or nil

    local displayItem = TEN.View.DisplayItem.GetItemByName(tostring(item))

    displayItem:SetRotation(examineRotation)
    displayItem:SetScale(examineScaler)
    
    if localizedString and examineShowString then
        local entryText = TEN.Strings.DisplayString(localizedString, percentPos(EXAMINE_TEXT_POS.x, EXAMINE_TEXT_POS.y), 1, COLOR_MAP.NORMAL_FONT, true, {Strings.DisplayStringOption.VERTICAL_CENTER, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER})
        ShowString(entryText, 1 / 30)
    end

end

LevelFuncs.Engine.CustomInventory.DrawItemLabel = function(item, primary)

    local entryPosInPixel = primary and percentPos(50, 80) or percentPos(50, 90) 
    local scale = primary and 1.5 or 1 --Item label
    local label = TEN.Flow.GetString(item.name)
    local count = item.count
    local result

    if count == -1 then
        result = TEN.Flow.GetString("unlimited"):gsub(" ", ""):gsub("%%s", "").. " "
    elseif count > 1 or item.type == PICKUP_DATA.TYPE.AMMO or item.type == PICKUP_DATA.TYPE.MEDIPACK then
        result = tostring(count) .. " x "
    else
        result = ""
    end

    local string = result ..label
    local entryText = TEN.Strings.DisplayString(string, entryPosInPixel, scale, COLOR_MAP.NORMAL_FONT, false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
    TEN.Strings.ShowString(entryText, 1 / 30)
    
end

LevelFuncs.Engine.CustomInventory.DrawInventoryHeader = function(text)

    if text[5] then
        local entryText = TEN.Strings.DisplayString(Flow.GetString(text[1]), percentPos(text[2].x, text[2].y), text[3], colorCombine(text[4], 255), false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
        TEN.Strings.ShowString(entryText, 1 / 30)
    end
end

LevelFuncs.Engine.CustomInventory.DrawInventorySubHeader = function(text)

    if text[5] then
        local entryText = TEN.Strings.DisplayString(Flow.GetString(text[1]), percentPos(text[2].x, text[2].y), text[3], colorCombine(text[4], 255), false, {Strings.DisplayStringOption.CENTER, Strings.DisplayStringOption.SHADOW})
        TEN.Strings.ShowString(entryText, 1 / 30)
    end
end

LevelFuncs.Engine.CustomInventory.ControlTexts = function(inventoryMode)

    -- local fadeInterpolate = nil
    -- if inventoryMode == INVENTORY_MODE.RING_OPENING then
    --     fadeInterpolate = Interpolate.Calculate("FontFade", Interpolate.Type.LINEAR, 0, 255, INVENTORY_ANIM_TIME, true)
    --     if fadeInterpolate.progress >= PROGRESS_COMPLETE then
    --         Interpolate.Clear("FontFade")
    --     end
    -- elseif inventoryMode == INVENTORY_MODE.RING_CLOSING then
    --     fadeInterpolate = Interpolate.Calculate("FontFade", Interpolate.Type.LINEAR, 255, 0, INVENTORY_ANIM_TIME, true)
    --     if fadeInterpolate.progress >= PROGRESS_COMPLETE then
    --         Interpolate.Clear("FontFade")
    --     end
    -- else
    --     fadeInterpolate = {output = 255, progress = 1}
    -- end
  
    local selectedItem = GetSelectedItem(selectedRing)
    local actions = selectedItem.menuActions

    local stringTable = {}

    for i = 1, #PICKUP_DATA.ItemActionFlags do
        local entry = PICKUP_DATA.ItemActionFlags[i]
        if hasItemAction(actions, entry.bit) then
            stringTable[#stringTable+1] = TEN.Flow.GetString(entry.string)
        end
    end

    local finalString

    if #stringTable == 1 then
        finalString = stringTable[1]
    else
        finalString = TEN.Flow.GetString("actions_select")
    end

    local scale = 0.5
    local color = colorCombine(COLOR_MAP.NORMAL_FONT, 255)

    local entryPosInPixel = percentPos(5, 95)

    local entryText = TEN.Strings.DisplayString(finalString, entryPosInPixel, scale, color, false, {Strings.DisplayStringOption.SHADOW})
    TEN.Strings.ShowString(entryText, 1 / 30)



end

return CustomInventory