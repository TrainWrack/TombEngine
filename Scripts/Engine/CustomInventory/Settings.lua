
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
    NORMAL_FONT = Color(255, 255, 255, 255),
    HEADER_FONT = Color(216, 117, 49, 255),
    BLACK = Color(0, 0 ,0 , 255),
    BACKGROUND = Color(128, 128, 128, 255),
    INVENTORY_AMBIENT = Color(255, 255, 128),
    ITEM_COLOR = Color(128, 128, 128, 0),
    ITEM_COLOR_VISIBLE = Color(128, 128, 128, 255)
}

Settings.BACKGROUND = 
{
    ENABLE = false,
    OBJECTID = TEN.Objects.ObjID.DIARY_SPRITES,
    SPRITEID = 1,
    COLOR = TEN.Color(255, 255, 255),
    POSITION = TEN.Vec2(TEN.Util.PercentToScreen(50,50)),
    ROTATION = 0,
    SCALE = TEN.Vec2(100,100),
    ALIGN_MODE = TEN.View.AlignMode.CENTER,
    SCALE_MODE = TEN.View.ScaleMode.STRETCH,
    BLEND_MODE = TEN.Effects.BlendID.ALPHA_BLEND,
    ALPHA = 255
}


return Settings