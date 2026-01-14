Settings = {}

Settings.SOUND_MAP =
{
    PLAYER_NO = 2,
    MENU_ROTATE = 108,
    MENU_SELECT = 109,
    MENU_CHOOSE = 111,
    MENU_COMBINE = 114,
    TR4_MENU_MEDI = 116,
    INVENTORY_OPEN = 109,
    INVENTORY_CLOSE = 109,
    EMPTY = 110
}

Settings.COLOR_MAP =
{
    NORMAL_FONT = Flow.GetSettings().UI.plainTextColor,
    HEADER_FONT = Flow.GetSettings().UI.headerTextColor,
    YELLOW_FONT = Flow.GetSettings().UI.optionTextColor,
    BLACK = Flow.GetSettings().UI.shadowTextColor,
    BACKGROUND = Color(64, 64, 64, 128),
    INVENTORY_AMBIENT = Color(255, 255, 128),
    ITEM_COLOR = Color(64, 64, 64, 0),
    ITEM_COLOR_DESELECTED = Color(32, 32, 32, 255),
    ITEM_COLOR_VISIBLE = Color(128, 128, 128, 255)
}

Settings.BACKGROUND = 
{
    ENABLE = true,
    OBJECTID = TEN.Objects.ObjID.DIARY_ENTRY_SPRITES,
    SPRITEID = 0,
    COLOR = TEN.Color(255, 255, 255),
    POSITION = TEN.Vec2(50,50),
    ROTATION = 0,
    SCALE = TEN.Vec2(100,100),
    ALIGN_MODE = TEN.View.AlignMode.CENTER,
    SCALE_MODE = TEN.View.ScaleMode.STRETCH,
    BLEND_MODE = TEN.Effects.BlendID.ALPHA_BLEND,
    ALPHA = 255
}

Settings.ANIMATION = 
{
    INVENTORY_ANIM_TIME = .5,
    ITEM_ANIM_TIME = .125,
    ROTATION_SPEED = 4,
}


return Settings