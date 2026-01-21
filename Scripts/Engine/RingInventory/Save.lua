--External Modules
local Menu = require("Engine.RingInventory.Menu")
local Settings = require("Engine.RingInventory.Settings")

--Pointers to tables
local SOUND_MAP = Settings.SOUND_MAP
local COLOR_MAP = Settings.COLOR_MAP

local Save = {}

Save.saveList = false
Save.saveSelected = false
Save.saveSlotSelected = 1

function Save.DoSave()
    local slot = Menu.Get("SaveMenu2"):getCurrentItemIndex()
    Save.saveSlotSelected = slot
    Flow.SaveGame(slot - 1)
    Save.saveSelected = true
    for index = 1, 4 do
        Menu.Delete("SaveMenu"..index)
    end
    return true
end

function Save.DoLoad()

    local slot = Menu.Get("SaveMenu2"):getCurrentItemIndex()

    if Flow.DoesSaveGameExist(slot - 1) then
        Save.saveSlotSelected = slot
        Flow.LoadGame(slot - 1)
        Save.saveSelected = true
        for index = 1, 4 do
            Menu.Delete("SaveMenu"..index)
        end
        return true
    else
        TEN.Sound.PlaySound(SOUND_MAP.PLAYER_NO)
        return false
    end
end

function Save.CreateSaveMenu(save)
    local textPosition = {
        Vec2(10, 12),
        Vec2(20, 12),
        Vec2(75, 12),
        Vec2(50, 12),
    }
    
    local saveTitleText = {nil, "save_game", nil, nil}
    local loadTitleText = {nil, "load_game", nil, nil}
    local saveFunctions = {nil, "Engine.RingInventory.DoSave", nil, nil}
    local loadFunctions = {nil, "Engine.RingInventory.DoLoad", nil, nil}
    
    local soundMap = {
        [1] = {select = nil, choose = nil},
        [2] = {select = SOUND_MAP.MENU_SELECT, choose = SOUND_MAP.MENU_CHOOSE},
        [3] = {select = nil, choose = nil},
        [4] = {select = nil, choose = nil}
    }
    
    local itemFlag = {Strings.DisplayStringOption.SHADOW}
    local selectedFlag = {Strings.DisplayStringOption.BLINK, Strings.DisplayStringOption.SHADOW}
    
    local itemFlags = {
        itemFlag,
        itemFlag,
        itemFlag,
        {Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}
    }
    
    local selectedFlags = {
        selectedFlag,
        selectedFlag,
        selectedFlag,
        {Strings.DisplayStringOption.BLINK, Strings.DisplayStringOption.SHADOW, Strings.DisplayStringOption.CENTER}
    }
    
    local headers = Flow.GetSaveHeaders()
    local items = {[1] = {}, [2] = {}, [3] = {}, [4] = {}}
    
    for i = 1, #headers do
        local h = headers[i]
        local itemText1, itemText2, itemText3, itemText4
        
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
        
        table.insert(items[1], {itemName = itemText1})
        table.insert(items[2], {itemName = itemText2})
        table.insert(items[3], {itemName = itemText3})
        table.insert(items[4], {itemName = itemText4})
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
        local translate = (index == 4)
        
        saveMenu:SetItemsPosition(textPosition[index])
        saveMenu:SetTitlePosition(Vec2(50, 4))
        saveMenu:SetVisibility(true)
        saveMenu:SetLineSpacing(5.3)
        saveMenu:SetItemsFont(COLOR_MAP.NORMAL_FONT, 0.9, itemFlags[index])
        saveMenu:SetSelectedItemFlags(selectedFlags[index])
        saveMenu:SetTitle(nil, COLOR_MAP.HEADER_FONT, 1.5, nil, true)
        saveMenu:SetItemsTranslate(translate)
        saveMenu:SetSoundEffects(soundMap[index].select, soundMap[index].choose)
        saveMenu:setCurrentItem(Save.saveSlotSelected)
    end
end

function Save.RunSaveMenu()
    for index = 1, 4 do
        local saveMenu = Menu.Get("SaveMenu"..index)
        saveMenu:Draw()
    end
end

-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================
LevelFuncs.Engine.RingInventory = LevelFuncs.Engine.RingInventory or {}
LevelFuncs.Engine.RingInventory.DoSave = Save.DoSave
LevelFuncs.Engine.RingInventory.DoLoad = Save.DoLoad

return Save