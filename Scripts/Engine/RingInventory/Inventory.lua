-----
-- This module enables classic ring inventory in TEN levels. 
-- Example usage:
--
--	local RingInventory = require("Engine.RingInventory.Inventory")
--
-- Global ring inventory settings.
-- Settings is composed of several sub-tables, and each section of the Settings documentation corresponds to one of these sub-tables.
-- These configuration groups are located in *Settings.lua* script file inside RingInventory folder.
--
-- It is possible to change settings on a per-level basis via @{RingInventory.GetSettings} and @{RingInventory.SetSettings} functions, but keep in mind that
-- _Settings.lua is reread every time the level is reloaded_. Therefore, you need to implement custom settings management in your level script
-- if you want to override global settings.
-- @luautil RingInventory

--External Modules
local Constants = require("Engine.RingInventory.Constants")
local InventoryData = require("Engine.RingInventory.InventoryData")
local InventoryStates
local ItemSpin = require("Engine.RingInventory.ItemSpin")
local RingLight = require("Engine.RingInventory.RingLight")
local Settings = require("Engine.RingInventory.Settings")
local Strings = require("Engine.RingInventory.Strings")

--Pointers to tables
local COLOR_MAP = Settings.COLOR_MAP

--Local Variables
local inventoryDelay = 0

local inventorySetup = true
local inventoryOpen = false
local inventoryRunning = false

LevelFuncs.Engine.RingInventory = {}

-- ============================================================================
-- MAIN FUNCTIONS
-- ============================================================================
local function UpdateInventory()
    if not inventoryRunning then
        return
    end

    if not InventoryStates then
        InventoryStates = require("Engine.RingInventory.InventoryStates")
    end

    RingLight.Update()
    ItemSpin.Update()
    InventoryStates.Update()

end

local function RunInventory()

    if not InventoryStates then
        InventoryStates = require("Engine.RingInventory.InventoryStates")
    end

    if inventorySetup then
        LevelVars.Engine.RingInventory = {}
        inventoryOpen = false
        InventoryStates.SetInventoryClosed(false)
        inventoryRunning = false
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_SELECTED)
        local settings = TEN.Flow.GetSettings()
        settings.Gameplay.enableInventory = false
        TEN.Flow.SetSettings(settings)
        
        inventorySetup = false
    end
    
    local playerHp = Lara:GetHP() > 0
    local isNotUsingBinoculars = TEN.View.GetCameraType() ~= CameraType.BINOCULARS
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.INVENTORY) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        inventoryOpen = true
        InventoryData.SetOpenAtItem(TEN.Inventory.GetFocusedItem())
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.SAVE) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       playerHp and 
       isNotUsingBinoculars then
        inventoryOpen = true
        local Save = require("Engine.RingInventory.Save")
        Save.SetQuickSaveStatus(true)
        Save.SetSaveMenu()
        inventoryDelay = 0
    end
    
    if (TEN.Input.IsKeyHit(TEN.Input.ActionID.LOAD) or TEN.Inventory.GetFocusedItem() ~= Constants.NO_VALUE) and 
       not inventoryOpen and 
       isNotUsingBinoculars then
        inventoryOpen = true
        local Save = require("Engine.RingInventory.Save")
        Save.SetQuickSaveStatus(true)
        Save.SetLoadMenu()
        inventoryDelay = 0
    end
    
    if inventoryOpen == true then
        inventoryDelay = inventoryDelay + 1
        TEN.View.SetPostProcessMode(View.PostProcessMode.MONOCHROME)
        TEN.View.SetPostProcessStrength(COLOR_MAP.BACKGROUND.a / Constants.ALPHA_MAX)
        TEN.View.SetPostProcessTint(COLOR_MAP.BACKGROUND)
        if inventoryDelay >= 2 then
            TEN.View.DisplayItem.SetCameraPosition(Constants.CAMERA_START)
            TEN.View.DisplayItem.SetTargetPosition(Constants.TARGET_START)
            TEN.View.DisplayItem.SetFOV(80)
            TEN.View.DisplayItem.SetAmbientLight(COLOR_MAP.INVENTORY_AMBIENT)
            inventoryRunning = true
            inventoryOpen = false
            Flow.SetFreezeMode(Flow.FreezeMode.FULL)
        end
    end
    
    if InventoryStates.GetInventoryClosed() then
        TEN.View.SetPostProcessMode(View.PostProcessMode.NONE)
        TEN.View.SetPostProcessStrength(1)
        TEN.View.SetPostProcessTint(COLOR_MAP.ITEM_SELECTED)
        InventoryStates.SetInventoryClosed(false)
        inventoryRunning = false
    end
end


local InventoryModule = {}

local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

---Get settings tables for RingInventory.
-- @function RingInventory.GetSettings
-- @treturn Settings Current settings table
InventoryModule.GetSettings = function()
    return deepCopy(Settings)
end

---Set settings tables for RingInventory.
-- @function RingInventory.SetSettings
-- @tparam Settings newSettings Required settings table
InventoryModule.SetSettings = function(newSettings)
    for section, values in pairs(newSettings) do
        if Settings[section] ~= nil then
            for setting, value in pairs(values) do
                if Settings[section][setting] ~= nil then
                    Settings[section][setting] = value
                end
            end
        end
    end
end

--- BACKGROUND
-- @section BACKGROUND
-- These settings control the inventory background sprite display.
-- @usage
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.BACKGROUND.ENABLE = false
-- RingInventory.SetSettings(settings)

--- Whether the background sprite is rendered.
-- @tfield[opt=true] bool ENABLE If true, the background sprite will be displayed behind the inventory.

--- The object ID used to source the background sprite.
-- @tfield[opt=TEN.Objects.ObjID.DIARY_ENTRY_SPRITES] Objects.ObjID OBJECTID Object ID for the background's sprite.

--- The sprite index within the object to use as the background.
-- @tfield[opt=0] int SPRITEID Sprite ID from the specified object for the background's sprite.

--- Tint color applied to the background sprite.
-- @tfield[opt=TEN.Color(255, 255, 255)] Color COLOR Color of background's sprite.

--- Screen position of the background sprite's anchor point, in percent.
-- @tfield[opt=TEN.Vec2(50, 50)] Vec2 POSITION X,Y position of the background sprite in screen percent (0-100).

--- Rotation of the background sprite in degrees.
-- @tfield[opt=0] float ROTATION Rotation of the background's sprite (0-360), in degrees.

--- Scale of the background sprite as a percentage of screen size.
-- @tfield[opt=TEN.Vec2(100, 100)] Vec2 SCALE X,Y Scaling factor for the background's sprite.

--- Alignment mode used when positioning the background sprite.
-- @tfield[opt=TEN.View.AlignMode.CENTER] View.AlignMode ALIGN_MODE Alignment for the background's sprite.

--- Scaling mode used when sizing the background sprite.
-- @tfield[opt=TEN.View.ScaleMode.STRETCH] View.ScaleMode SCALE_MODE Scaling for the background's sprite.

--- Blend mode used when rendering the background sprite.
-- @tfield[opt=TEN.Effects.BlendID.ALPHA_BLEND] Effects.BlendID BLEND_MODE Blending modes for the background's sprite.

--- Overall opacity of the background sprite.
-- @tfield[opt=255] int ALPHA Opacity value from 0 (fully transparent) to 255 (fully opaque).

--- SOUND_MAP
-- @section SOUND_MAP
-- These settings map inventory UI events to sound effect IDs.
-- Sound IDs correspond to entries in the game's sound catalogue.
-- @usage
-- -- Example of overriding the inventory open sound
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.SoundEffects.INVENTORY_OPEN = 42
-- RingInventory.SetSettings(settings)

--- Sound played when Lara has no item available.
-- @tfield[opt=2] int PLAYER_NO Sound effect ID triggered when the player attempts to use an unavailable item.

--- Sound played when rotating the inventory ring.
-- @tfield[opt=108] int MENU_ROTATE Sound effect ID triggered while scrolling through inventory items.

--- Sound played when hovering over or highlighting a menu option.
-- @tfield[opt=109] int MENU_SELECT Sound effect ID triggered on item selection highlight.

--- Sound played when confirming a menu choice.
-- @tfield[opt=111] int MENU_CHOOSE Sound effect ID triggered when the player confirms a selected action.

--- Sound played when combining two inventory items.
-- @tfield[opt=114] int MENU_COMBINE Sound effect ID triggered when two compatible items are combined.

--- Sound played when using a medipack.
-- @tfield[opt=116] int TR4_MENU_MEDI Sound effect ID triggered when a medipack is consumed from the inventory.

--- Sound played when the inventory is opened.
-- @tfield[opt=109] int INVENTORY_OPEN Sound effect ID triggered when the inventory ring is opened.

--- Sound played when the inventory is closed.
-- @tfield[opt=109] int INVENTORY_CLOSE Sound effect ID triggered when the inventory ring is closed.

--- Sound played for empty or null inventory actions.
-- @tfield[opt=110] int EMPTY Sound effect ID triggered for interactions with no associated item.

--- COLOR_MAP
-- @section COLOR_MAP
-- These settings define the colors used throughout the inventory UI.
-- Colors are of type @{Color}.
-- @usage
-- -- Example of changing the selected item highlight color
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.Colors.ITEM_SELECTED = TEN.Color(200, 180, 60, 255)
-- RingInventory.SetSettings(settings)

--- Color used for standard body text in the inventory.
-- @tfield[opt=Flow.GetSettings().UI.plainTextColor] Color NORMAL_FONT Applied to descriptive text.

--- Color used for section headers and titles.
-- @tfield[opt=Flow.GetSettings().UI.headerTextColor] Color HEADER_FONT Applied to inventory category headings and titles.

--- Color used for selectable option text.
-- @tfield[opt=Flow.GetSettings().UI.optionTextColor] Color OPTION_FONT Applied to text entries.

--- Background tint color for the inventory panel.
-- @tfield[opt=Color(64, 64, 64, 128)] Color BACKGROUND Semi-transparent overlay color drawn behind inventory content.

--- Ambient light color cast on inventory item models.
-- @tfield[opt=Color(255, 255, 128)] Color INVENTORY_AMBIENT Light applied to Inventory items.

--- Color used to render hidden inventory items.
-- @tfield[opt=Color(0, 0, 0, 0)] Color ITEM_HIDDEN Fully transparent; items with this color are invisible in the ring.

--- Color used to render unselected inventory items.
-- @tfield[opt=Color(32, 32, 32, 255)] Color ITEM_DESELECTED Tint applied to items that are not currently highlighted.

--- Color used to render the currently selected inventory item.
-- @tfield[opt=Color(128, 128, 128, 255)] Color ITEM_SELECTED Tint applied to the item the player has focused on.

--- ANIMATION
-- @section ANIMATION
-- These settings determine the animations of the Inventory.
-- @usage
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.Animations.crouchRoll = false
-- RingInventory.SetSettings(settings)

--- Duration of the inventory ring open/close transition.
-- @tfield[opt=0.5] float INVENTORY_ANIM_TIME Time in seconds for the ring to animate.

--- Duration of the per-item spin or presentation animation.
-- @tfield[opt=0.2] float ITEM_ANIM_TIME Time in seconds for an individual item to animate into its focused pose.

--- Skip the ring collapse animation when closing the inventory.
-- @tfield[opt=false] bool SKIP_RING_CLOSE If true, the inventory closes instantly without playing the ring-retract animation.

--- Speed at which inventory text fades in and out.
-- @tfield[opt=25.5] float TEXT_ALPHA_SPEED Alpha change applied per frame (255 / 10 ≈ 25.5). Higher values cause faster fades.

--- STATISTICS
-- @section STATISTICS
-- These settings control time progression in Inventory and Game statistics display.
-- @usage
-- -- Example of disabling the game statistics screen
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.Statistics.GAME_STATS = false
-- RingInventory.SetSettings(settings)

--- Progress time while in Inventory. Stopwatch hands are also moving.
-- @tfield[opt=true] bool PROGRESS_TIME If true, time is progressed in the inventory.

--- Display the full game statistics in Statistics mode.
-- @tfield[opt=true] bool GAME_STATS If true, full game statistics are show in Statistics mode in Inventory.


-- ============================================================================
-- PUBLIC API (LevelFuncs.Engine.RingInventory)
-- ============================================================================
LevelFuncs.Engine.RingInventory = LevelFuncs.Engine.RingInventory or {}
LevelFuncs.Engine.RingInventory.UpdateInventory = UpdateInventory
LevelFuncs.Engine.RingInventory.RunInventory = RunInventory

-- ============================================================================
-- CALLBACKS
-- ============================================================================
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_FREEZE, LevelFuncs.Engine.RingInventory.UpdateInventory)
TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRE_LOOP, LevelFuncs.Engine.RingInventory.RunInventory)

return InventoryModule