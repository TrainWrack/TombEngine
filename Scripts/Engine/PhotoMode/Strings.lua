--- Translatable strings for the PhotoMode module.
-- @module Engine.PhotoMode.Strings
-- @local

local strings =
{
    -- Header tabs
    pm_header_camera  = {"Camera"},
    pm_header_lens    = {"Lens"},
    pm_header_pose    = {"Pose"},
    pm_header_light   = {"Light"},
    pm_header_filters = {"Filters"},
    pm_header_outfit  = {"Outfit"},
    pm_header_frames  = {"Frames"},
    pm_header_ui      = {"UI"},

    -- Camera menu items
    pm_mode           = {"Mode"},
    pm_move_speed     = {"Move Speed"},
    pm_look_speed     = {"Look Speed"},
    pm_collision      = {"Collision"},
    pm_reset_camera   = {"Reset Camera"},

    -- Lens menu items
    pm_fov            = {"FOV"},
    pm_roll           = {"Roll"},
    pm_reset_lens     = {"Reset Lens"},

    -- Pose menu items
    pm_anim_index     = {"Anim Index"},
    pm_frame          = {"Frame"},
    pm_reset_pose     = {"Reset Pose"},

    -- Light menu items
    pm_enabled        = {"Enabled"},
    pm_source         = {"Source"},
    pm_radius         = {"Radius"},
    pm_shadows        = {"Shadows"},
    pm_color          = {"Color"},
    pm_place_camera   = {"Place at Camera"},
    pm_place_lara     = {"Place at Lara"},
    pm_reset_light    = {"Reset Light"},

    -- Filter menu items
    pm_preset         = {"Preset"},
    pm_strength       = {"Strength"},
    pm_tint           = {"Tint"},
    pm_reset_filters  = {"Reset Filters"},

    -- Outfit menu items
    pm_outfit         = {"Outfit"},
    pm_weapons        = {"Weapons"},
    pm_reset          = {"Reset"},

    -- Frames menu items
    pm_frame_overlay  = {"Frame"},

    -- UI menu items
    pm_hide_ui        = {"Hide UI"},
    pm_exit           = {"Exit Photo Mode"},

    -- Common
    pm_press          = {"[Action]"},

    -- Display strings
    pm_help           = {"StepL/R=Tab  Up/Down=Select  Left/Right=Adjust  Look=Hide UI  Inventory=Exit"},
}

TEN.Flow.SetStrings(strings)
