--- Internal file used by the RingInventory module.
-- @module RingInventory.Settings
-- @local

local Settings = {}

--- Animation
-- @section Animation
-- These settings determine the animations of the Inventory.
-- @usage
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.Animations.skipRingClose = true
-- RingInventory.SetSettings(settings)

--- Duration of the inventory ring open/close transition.
-- @tfield[opt=0.5] float inventoryAnimTime Time in seconds for the ring to animate.

--- Duration of the per-item spin or presentation animation.
-- @tfield[opt=0.2] float itemAnimTime Time in seconds for an individual item to animate into its focused pose.

--- Skip the ring collapse animation when closing the inventory.
-- @tfield[opt=false] bool skipRingClose If true, the inventory closes instantly without playing the ring-retract animation.

--- Speed at which inventory text fades in and out.
-- @tfield[opt=25.5] float textAlphaSpeed Alpha change applied per frame (255 / 10 ≈ 25.5). Higher values cause faster fades.

Settings.Animation = 
{
    inventoryAnimTime = .5,
    itemAnimTime = .2,
    skipRingClose = false,
    textAlphaSpeed = 255 / 5
}

--- Background
-- @section Background
-- These settings control the inventory background sprite display.
-- @usage
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.Background.enable = false
-- RingInventory.SetSettings(settings)

--- Whether the background sprite is rendered.
-- @tfield[opt=true] bool enable If true, the background sprite will be displayed behind the inventory.

--- The object ID used to source the background sprite.
-- @tfield[opt=TEN.Objects.ObjID.DIARY_ENTRY_SPRITES] Objects.ObjID objectID Object ID for the background's sprite.

--- The sprite index within the object to use as the background.
-- @tfield[opt=0] int spriteID Sprite ID from the specified object for the background's sprite.

--- Tint color applied to the background sprite.
-- @tfield[opt=TEN.Color(255&#44; 255&#44; 255)] Color color Color of background's sprite.

--- Screen position of the background sprite's anchor point, in percent.
-- @tfield[opt=TEN.Vec2(50&#44; 50)] Vec2 position X,Y position of the background sprite in screen percent (0-100).

--- Rotation of the background sprite in degrees.
-- @tfield[opt=0] float rotation Rotation of the background's sprite (0-360), in degrees.

--- Scale of the background sprite as a percentage of screen size.
-- @tfield[opt=TEN.Vec2(100&#44; 100)] Vec2 scale X,Y Scaling factor for the background's sprite.

--- Alignment mode used when positioning the background sprite.
-- @tfield[opt=TEN.View.AlignMode.CENTER] View.AlignMode alignMode Alignment for the background's sprite.

--- Scaling mode used when sizing the background sprite.
-- @tfield[opt=TEN.View.ScaleMode.STRETCH] View.ScaleMode scaleMode Scaling for the background's sprite.

--- Blend mode used when rendering the background sprite.
-- @tfield[opt=TEN.Effects.BlendID.ALPHA_BLEND] Effects.BlendID blendMode Blending modes for the background's sprite.

--- Overall opacity of the background sprite.
-- @tfield[opt=255] int alpha Opacity value from 0 (fully transparent) to 255 (fully opaque).

Settings.Background = 
{
    enable = true,
    objectID = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
    spriteID = 0,
    color = TEN.Color(255, 255, 255),
    position = TEN.Vec2(50,50),
    rotation = 0,
    scale = TEN.Vec2(100,100),
    alignMode = TEN.View.AlignMode.CENTER,
    scaleMode = TEN.View.ScaleMode.STRETCH,
    blendMode = TEN.Effects.BlendID.ALPHA_BLEND,
    alpha = 255
}

--- ColorMap
-- @section ColorMap
-- These settings define the colors used throughout the inventory UI.
-- Colors are of type @{Color}.
-- @usage
-- -- Example of changing the selected item highlight color
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.ColorMap.itemSelected = TEN.Color(200, 180, 60, 255)
-- RingInventory.SetSettings(settings)

--- Color used for standard body text in the inventory.
-- @tfield[opt=Flow.GetSettings().UI.plainTextColor] Color plainText Applied to descriptive text.

--- Color used for section headers and titles.
-- @tfield[opt=Flow.GetSettings().UI.headerTextColor] Color headerText Applied to inventory category headings and titles.

--- Color used for selectable option text.
-- @tfield[opt=Flow.GetSettings().UI.optionTextColor] Color optionText Applied to text entries.

--- Background tint color for the inventory.
-- @tfield[opt=Color(64&#44; 64&#44; 64&#44; 128)] Color background Semi-transparent overlay color drawn behind inventory content. The alpha channel determines the strenght of the effect.

--- Ambient light color cast on inventory item models.
-- @tfield[opt=Color(255&#44; 255&#44; 128)] Color inventoryAmbient Light applied to Inventory items.

--- Color used to render hidden inventory items.
-- @tfield[opt=Color(0&#44; 0&#44; 0&#44; 0)] Color itemHidden Fully transparent; items with this color are invisible in the ring.

--- Color used to render unselected inventory items.
-- @tfield[opt=Color(32&#44; 32&#44; 32&#44; 255)] Color itemDeselected Tint applied to items that are not currently highlighted.

--- Color used to render the currently selected inventory item.
-- @tfield[opt=Color(128&#44; 128&#44; 128&#44; 255)] Color itemSelected Tint applied to the item the player has focused on.

--- Color used to render the neutral sprites.
-- @tfield[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color neutral Tint applied to the sprites.

Settings.ColorMap =
{
    plainText = Flow.GetSettings().UI.plainTextColor,
    headerText = Flow.GetSettings().UI.headerTextColor,
    optionText = Flow.GetSettings().UI.optionTextColor,
    background = Color(64, 64, 64, 128),
    inventoryAmbient = Color(255, 255, 128),
    itemHidden = Color(0, 0, 0, 0),
    itemDeselected = Color(32, 32, 32, 255),
    itemSelected = Color(128, 128, 128, 255),
    neutral =  Color(255, 255, 255, 255)
}

--- SoundMap
-- @section SoundMap
-- These settings map inventory UI events to sound effect IDs.
-- Sound IDs correspond to entries in the game's sound catalogue.
-- @usage
-- -- Example of overriding the inventory open sound
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.SoundMap.inventoryOpen = 42
-- RingInventory.SetSettings(settings)

--- Sound played when Lara has no item available.
-- @tfield[opt=2] int playerNo Sound effect ID triggered when the player attempts to use an unavailable item.

--- Sound played when rotating the inventory ring.
-- @tfield[opt=108] int menuRotate Sound effect ID triggered while scrolling through inventory items.

--- Sound played when hovering over or highlighting a menu option.
-- @tfield[opt=109] int menuSelect Sound effect ID triggered on item selection highlight.

--- Sound played when confirming a menu choice.
-- @tfield[opt=111] int menuChoose Sound effect ID triggered when the player confirms a selected action.

--- Sound played when combining two inventory items.
-- @tfield[opt=114] int menuCombine Sound effect ID triggered when two compatible items are combined.

--- Sound played when the inventory is opened.
-- @tfield[opt=109] int inventoryOpen Sound effect ID triggered when the inventory ring is opened.

--- Sound played when the inventory is closed.
-- @tfield[opt=109] int inventoryClose Sound effect ID triggered when the inventory ring is closed.

Settings.SoundMap =
{
    playerNo = 2,
    menuRotate = 108,
    menuSelect = 109,
    menuChoose = 111,
    menuCombine = 114,
    inventoryOpen = 109,
    inventoryClose = 109,
}

--- Statistics
-- @section Statistics
-- These settings control time progression in Inventory and Game statistics display.
-- @usage
-- -- Example of disabling the game statistics screen
-- -- In the level's lua file
-- local settings = RingInventory.GetSettings()
-- settings.Statistics.gameStats = false
-- RingInventory.SetSettings(settings)

--- Progress time while in Inventory. Stopwatch hands are also moving.
-- @tfield[opt=true] bool progressTime If true, time is progressed in the inventory.

--- Display the full game statistics in Statistics mode.
-- @tfield[opt=true] bool gameStats If true, full game statistics are show in Statistics mode in Inventory.

Settings.Statistics = 
{
    progressTime = true,
    gameStats = true
}

return Settings