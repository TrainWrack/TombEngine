-----
--- Diaries:
--The module provides functions to create and manage Diaries. It maintains diary definitions and configurations in GameVars.Diaries and GameVars.LastUsedDiary so please do not use them for anything else.
-- Each diary is accessed by the object that was used to create it. 
--
-- Example usage:
--
--	local CustomDiary = require("Engine.CustomDiary")
--
--	--This function creates a diary from the DiarySetup.lua template file in script folder
--	CustomDiary.ImportDiary("DiarySetup")
--
--	--This method gets the diary that was created with the DIARY_ITEM object and stores it in variable diary.
--	local diary = CustomDiary.Get(TEN.Objects.ObjID.DIARY_ITEM)
--	--This method opens the diary on the 3rd page
--	diary:showDiary(3)
--
-- @luautil Diary

local Type = require("Engine.Type")

local CustomDiary = {}
CustomDiary.__index = CustomDiary

LevelFuncs.Engine.Diaries = {}
GameVars.Diaries = GameVars.Diaries or {}
GameVars.LastUsedDiary = GameVars.LastUsedDiary or nil

---
-- Imports diary from an external file.
-- @tparam string fileName Name of file in the script folder without extension to import the diary from.
function CustomDiary.ImportDiary(fileName)

    if not Type.IsString(fileName) then
        Util.PrintLog("'fileName' is in an incorrect format. Expected a string type in function 'CustomDiary.ImportDiary' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    local importDiary = nil
    local diaryObject = nil
    local unlockCount = 1
    local diaryData = require(fileName)

    --Create the diary
    for _, entry in ipairs(diaryData) do
        if entry.type == "diary" then
            if not Type.IsNumber(entry.spriteIdBg) then
                Util.PrintLog("'spriteIdBg' is not a number. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.colorBg) then
                Util.PrintLog("'colorBg' is not in a Color format. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.pos) then
                Util.PrintLog("'pos' is not a Vec2. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.rot) then
                Util.PrintLog("'rot' is not a number. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.scale) then
                Util.PrintLog("'scale' is not a Vec2. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.alpha) or entry.alpha < 0 or entry.alpha > 256 then
                Util.PrintLog("'alpha' is not a number or not within range (0-255). Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.pageSound) or entry.pageSound <=0 then
                Util.PrintLog("'pageSound' is not a valid number. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.exitSound) or entry.exitSound <=0 then
                Util.PrintLog("'exitSound' is not a valid number. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.pagesToUnlock) or entry.pagesToUnlock <=0 then
                Util.PrintLog("'pagesToUnlock' is not a valid page number. Error in template data for diary entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            CustomDiary.Create(
                entry.object,
                entry.objectIdBg,
                entry.spriteIdBg,
                entry.colorBg,
                entry.pos,
                entry.rot,
                entry.scale,
                entry.alignMode,
                entry.scaleMode,
                entry.blendMode,
                entry.alpha,
                entry.pageSound,
                entry.exitSound
            )

            unlockCount = entry.pagesToUnlock
            diaryObject = entry.object
        end
    end

    --Start the diary
    CustomDiary.Status(true)
    importDiary = CustomDiary.Get(diaryObject)

    for _, entry in ipairs(diaryData) do
        if entry.type == "background" then

            if not Type.IsNumber(entry.spriteIdBg) then
                Util.PrintLog("'spriteIdBg' is not a number. Error in template data for background entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.colorBg) then
                Util.PrintLog("'colorBg' is not in a Color format. Error in template data for background entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.pos) then
                Util.PrintLog("'pos' is not a Vec2. Error in template data for background entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.rot) then
                Util.PrintLog("'rot' is not a number. Error in template data for background entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.scale) then
                Util.PrintLog("'scale' is not a Vec2. Error in template data for background entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.alpha) or entry.alpha < 0 or entry.alpha > 256 then
                Util.PrintLog("'alpha' is not a number or not within range (0-255). Error in template data for background entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:addBackground(
                entry.objectIdBg,
                entry.spriteIdBg,
                entry.colorBg,
                entry.pos,
                entry.rot,
                entry.scale,
                entry.alignMode,
                entry.scaleMode,
                entry.blendMode,
                entry.alpha
            )
        elseif entry.type == "pageNumbers" then

            if not Type.IsNumber(entry.pageNoType) or entry.pageNoType < 0 or entry.pageNoType > 2 then
                Util.PrintLog("'pageNoType' is not a a valid option (1 or 2). Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.prefix) then
                Util.PrintLog("'prefix' is not a a string. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.separator) then
                Util.PrintLog("'separator' is not a a string. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.separator) then
                Util.PrintLog("'separator' is not a a string. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsVec2(entry.textPos) then
                Util.PrintLog("'textPos' is not a a Vec2. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsTable(entry.textOptions) then
                Util.PrintLog("'textOptions' is not a table. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.textScale) then
                Util.PrintLog("'textScale' is not a number. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.textColor) then
                Util.PrintLog("'textColor' is not in a Color format. Error in template data for page numbers entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:customizePageNumbers(
                entry.pageNoType,
                entry.prefix,
                entry.separator,
                entry.textPos,
                entry.textOptions,
                entry.textScale,
                entry.textColor
            )
        elseif entry.type == "controls" then
            if not Type.IsString(entry.string1) then
                Util.PrintLog("'string1' is not a string. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.string2) then
                Util.PrintLog("'string2' is not a string. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.string3) then
                Util.PrintLog("'string3' is not a string. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.string4) then
                Util.PrintLog("'string4' is not a string. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsString(entry.separator) then
                Util.PrintLog("'separator' is not a string. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsVec2(entry.textPos) then
                Util.PrintLog("'textPos' is not a Vec2. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsTable(entry.textOptions) then
                Util.PrintLog("'textOptions' is not a table. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.textScale) then
                Util.PrintLog("'textScale' is not a number. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.textColor) then
                Util.PrintLog("'textColor' is not in a Color format. Error in template data for controls entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:customizeControls(
                entry.textPos,
                entry.textOptions,
                entry.textScale,
                entry.textColor)
            importDiary:customizeControlsText(
                entry.string1,
                entry.string2,
                entry.string3,
                entry.string4,
                entry.separator)
        elseif entry.type == "notification" then
            if not Type.IsNumber(entry.notificationTime) or entry.notificationTime <=0 then
                Util.PrintLog("'notificationTime' is not a valid number. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.spriteId) then
                Util.PrintLog("'spriteId' is not a number. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.color) then
                Util.PrintLog("'color' is not in a Color format. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.pos) then
                Util.PrintLog("'pos' is not a Vec2. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.rot) then
                Util.PrintLog("'rot' is not a number. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.scale) then
                Util.PrintLog("'scale' is not a Vec2. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end
            if not Type.IsNumber(entry.notificationSound) or entry.notificationSound <=0 then
                Util.PrintLog("'notificationSound' is not a valid number. Error in template data for notification entry. Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:customizeNotification(
                entry.notificationTime,
                entry.objectId,
                entry.spriteId,
                entry.color,
                entry.pos,
                entry.rot,
                entry.scale,
                entry.alignMode,
                entry.scaleMode,
                entry.blendMode,
                entry.notificationSound
            )
        elseif entry.type == "image" then

            if not Type.IsNumber(entry.pageIndex) or entry.pageIndex <=0 then
                Util.PrintLog("'pageIndex' is not a valid page number. Error in template data for image entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.spriteId) then
                Util.PrintLog("'spriteId' is not a number. Error in template data for image entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.color) then
                Util.PrintLog("'color' is not in a Color format. Error in template data for image entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.pos) then
                Util.PrintLog("'pos' is not a Vec2. Error in template data for image entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.rot) then
                Util.PrintLog("'rot' is not a number. Error in template data for image entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.scale) then
                Util.PrintLog("'scale' is not a Vec2. Error in template data for image entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:addImageEntry(
                entry.pageIndex,
                entry.objectId,
                entry.spriteId,
                entry.color,
                entry.pos,
                entry.rot,
                entry.scale,
                entry.alignMode,
                entry.scaleMode,
                entry.blendMode
            )
        elseif entry.type == "text" then

            if not Type.IsNumber(entry.pageIndex) or entry.pageIndex <=0 then
                Util.PrintLog("'pageIndex' is not a valid page number. Error in template data for text entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsString(entry.text) then
                Util.PrintLog("'text' is not a string. Error in template data for text entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsVec2(entry.textPos) then
                Util.PrintLog("'textPos' is not a a Vec2. Error in template data for text entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsTable(entry.textOptions) then
                Util.PrintLog("'textOptions' is not a table. Error in template data for text entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsNumber(entry.textScale) then
                Util.PrintLog("'textScale' is not a number. Error in template data for text entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsColor(entry.textColor) then
                Util.PrintLog("'textColor' is not in a Color format. Error in template data for text entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:addTextEntry(
                entry.pageIndex,
                entry.text,
                entry.textPos,
                entry.textOptions,
                entry.textScale,
                entry.textColor
            )
        elseif entry.type == "narration" then

            if not Type.IsNumber(entry.pageIndex) or entry.pageIndex <=0 then
                Util.PrintLog("'pageIndex' is not a valid page number. Error in template data for narration entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            if not Type.IsString(entry.trackName) then
                Util.PrintLog("'trackName' is not a string. Error in template data for narration entry for page: "..tostring(entry.pageIndex)..". Import Stopped for file: "..tostring(fileName), Util.LogLevel.WARNING)
                return
            end

            importDiary:addNarration(
                entry.pageIndex,
                entry.trackName
            )
        elseif entry.type == "diary" then
        print()
        else
            print("Unknown entry type: " .. tostring(entry.type))
        end
    end
    
    --Unlock the pages as per the template
    importDiary:unlockPages(unlockCount, false)
    print("External diary from file: "..tostring(fileName).." imported")
end

---
-- Creates a diary with extensive configuration options.
-- Parameters:
-- @tparam Objects.ObjID object The pickup object that will be used to create the diary. The diary can be created using PICKUP_ITEMX (596-611) or DIARY_ITEM (986). Access the diary by selecting the item in the inventory. 
-- @tparam Objects.ObjID objectIdBg Object ID for the diary's sprite.
-- @tparam int spriteIdBg SpriteID from the specified object for the diary's sprite.
-- @tparam Color colorBg Color of diary's sprite.
-- @tparam Vec2 pos X,Y position of the bar's background in screen percent (0-100).
-- @tparam float rot rotation of the diary's sprite (0-360).
-- @tparam Vec2 scale X,Y Scaling factor for the bar's background sprite.
-- @tparam View.AlignMode alignMode Alignment for the diary's sprite.
-- @tparam View.ScaleMode scaleMode Scaling for the diary's sprite.
-- @tparam Effects.BlendID blendMode Blending modes for the diary's sprite.
-- @tparam number alpha alpha value for the diary's sprite (0-255).
-- @tparam Sound pageSound Sound to play with page turn.
-- @tparam Sound exitSound Sound to play when existing the diary.
-- @treturn CustomDiary
CustomDiary.Create = function(object, objectIdBg, spriteIdBg, colorBg, pos, rot, scale, alignMode, scaleMode, blendMode, alpha, pageSound, exitSound)

    if (object < 596 or object > 611) and object ~= 986 then
        print("Error: Invalid object slot for diary creation. Please use a pickup object slot in the range 596 to 611 and 986.")
        return
    end

	local dataName = object .. "_diarydata"
    local self = {Name = dataName}
    GameVars.LastUsedDiary = object

	if GameVars.Diaries[dataName] then
		return setmetatable(self, CustomDiary)
	end

	GameVars.Diaries[dataName]				        = {}

    if Type.IsNumber(spriteIdBg) then
        GameVars.Diaries[dataName].SpriteIdBg	        = spriteIdBg
    else
        Util.PrintLog("'spriteIdBg' is in an incorrect format. Expected a number type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsColor(colorBg) then
        GameVars.Diaries[dataName].ColorBg		        = colorBg
    else
        Util.PrintLog("'colorBg' is in an incorrect format. Expected a Color type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsVec2(pos) then
        GameVars.Diaries[dataName].Pos			        = pos
    else
        Util.PrintLog("'posBg' is in an incorrect format. Expected a Vec2 type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(rot) then
        GameVars.Diaries[dataName].Rot			        = rot
    else
        Util.PrintLog("'rot' is in an incorrect format. Expected a number type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsVec2(scale) then
        GameVars.Diaries[dataName].Scale 		        = scale
    else
        Util.PrintLog("'scale' is in an incorrect format. Expected a Vec2 type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(alpha) and alpha>-1 and alpha < 266 then
        GameVars.Diaries[dataName].Alpha     	        = alpha
    else
        Util.PrintLog("'alpha is in an incorrect format. Expected a number (0-255) type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(pageSound) and pageSound > 0 then
        GameVars.Diaries[dataName].PageSound	        = pageSound
    else
        Util.PrintLog("'pageSound' is in an incorrect format. Expected a number type in function 'CustomDiary.Create' for the diary system.", Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(exitSound) and exitSound > 0 then
        GameVars.Diaries[dataName].ExitSound            = exitSound
    else
        Util.PrintLog("'exitSound' is in an incorrect format. Expected a number type in function 'CustomDiary.Create' for the diary system:.", Util.LogLevel.WARNING)
        return
    end

    GameVars.Diaries[dataName].Name			        = dataName
	GameVars.Diaries[dataName].CurrentPageIndex     = 1
    GameVars.Diaries[dataName].UnlockedPages        = 1
	GameVars.Diaries[dataName].Pages  		        = {NarrationTrack=nil,TextEntries={},ImageEntries={}}
	GameVars.Diaries[dataName].Object		        = object
	GameVars.Diaries[dataName].ObjectIdBg	        = objectIdBg
	GameVars.Diaries[dataName].AlignMode            = alignMode
	GameVars.Diaries[dataName].ScaleMode            = scaleMode
	GameVars.Diaries[dataName].BlendMode	        = blendMode
    GameVars.Diaries[dataName].CurrentAlpha		    = 0
	GameVars.Diaries[dataName].TargetAlpha		    = 255
    GameVars.Diaries[dataName].EntryCurrentAlpha	= 0
	GameVars.Diaries[dataName].EntryTargetAlpha     = 255
    GameVars.Diaries[dataName].Visible              = false
    GameVars.Diaries[dataName].Notification         = {}
    GameVars.Diaries[dataName].PageNumbers          = {}
    GameVars.Diaries[dataName].Controls             = {}
    GameVars.Diaries[dataName].Background           = {}
    GameVars.Diaries[dataName].AlphaBlendSpeed      = 100
    GameVars.Diaries[dataName].EntryFadingIn        = true

	print("CustomDiary Constructed for CustomDiary: " .. dataName)
    return setmetatable(self, CustomDiary)
end

---
-- The function retrieves a diary by its unique object. This function is useful when you need to access or manipulate a diary that has already been created .
-- @tparam Objects.ObjID object The pickup object that was used to create the diary (596-611,986).
-- @treturn CustomDiary The diary created using the object.
CustomDiary.Get = function(object)
	local dataName = object .. "_diarydata"
    if GameVars.Diaries[dataName] then
        local self = {Name = dataName}
        return setmetatable(self, CustomDiary)
    end
end

---
-- The function removes a custom diary and its associated data from the system. It ensures that the diary is no longer tracked or accessible in the LevelVars.Engine.Diaries. 
-- Please call this once a diary has served its purpose. It helps reduce the savegame size.
-- @tparam Objects.ObjID object The pickup object that was used to create the diary (596-611,986).
CustomDiary.Delete = function (object)
    local dataName = object .. "_diarydata"
	if GameVars.Diaries[dataName] then
		GameVars.Diaries[dataName] = nil
	end
end

--- 
-- The function adds the callback to enable diaries in levels. This needs to be added to every level preferably in the LevelFuncs.OnStart.
-- 	@bool value True enables the diaries to be activated. False would disable the diaries.
CustomDiary.Status = function(value)

    if Type.IsBoolean(value) then
        if GameVars.Diaries then
            if value == true then
                TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.POSTUSEITEM, LevelFuncs.Engine.Diaries.ActivateDiary)
                print("Diary system started.")
            elseif value == false then
                TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.POSTUSEITEM, LevelFuncs.Engine.Diaries.ActivateDiary)
                print("Diary system stopped.")
            end
        end
    else
        Util.PrintLog("'value' is in an incorrect format. Expected a bool type in function 'CustomDiary.Status' for the diary system", Util.LogLevel.WARNING)
    end


end

---
-- The function checks whether the specified diary is currently visible.
-- @treturn bool true if the diary is visible and false if it is not.
function CustomDiary:IsVisible()

	if GameVars.Diaries[self.Name] then
		return GameVars.Diaries[self.Name].Visible
	end
end

--- 
-- The function displays the specified diary. Can be used to call the diary directly using volume or classic triggers.
-- @tparam int pageIndex The page number at which diary should be opened.
function CustomDiary:showDiary(pageIndex)

	if GameVars.Diaries[self.Name] then

		local object = GameVars.Diaries[self.Name].Object

        if not Type.IsNumber(pageIndex) or pageIndex > #GameVars.Diaries[self.Name].Pages or pageIndex <=0 then
            print("'pageIndex' is in an incorrect format or not a valid page number. Expected a number type in function 'showDiary' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        GameVars.Diaries[self.Name].CurrentPageIndex    = pageIndex
        GameVars.Diaries[self.Name].NextPageIndex       = pageIndex

        LevelFuncs.Engine.Diaries.ActivateDiary(object)

	end
end

--- 
-- The function returns the number of unlocked pages in the diary.
-- @treturn int total number of unlocked pages in the diary.
function CustomDiary:getUnlockedPageCount()

	if GameVars.Diaries[self.Name] then
		return GameVars.Diaries[self.Name].UnlockedPages
	end
end

---
-- The function unlocks the specified diary up to the given page number. 
-- This value can be overridden to lock or unlock pages as needed.
-- A lower number can be set to restrict access to previously unlocked pages.
-- @tparam int pageIndex The page number up to which the diary should be unlocked.
-- @tparam bool notification If true, and notification has been defined, a notification icon and sound will be played.
function CustomDiary:unlockPages(pageIndex, notification)
    if GameVars.Diaries[self.Name] then

        if not Type.IsNumber(pageIndex) or pageIndex > #GameVars.Diaries[self.Name].Pages or pageIndex <= 0 then
            Util.PrintLog("'pageIndex' is in an incorrect format or not a valid page number. Expected a number type in function 'unlockPages' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        local diary = GameVars.Diaries[self.Name]
		diary.UnlockedPages = pageIndex
        diary.CurrentPageIndex = pageIndex
        diary.NextPageIndex = pageIndex
        print("UnlockPages: currentPageIndex = " .. tostring(diary.CurrentPageIndex))

        if notification and diary.Notification and next(diary.Notification) then
            PlaySound(diary.Notification.NotificationSound)
            diary.Notification.ElapsedTime = 0
            diary.TargetAlpha = 255
            diary.CurrentAlpha = 1
            TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Diaries.ShowNotification)
        end
    end
end

---
-- The function clears the page for the diary.
-- @tparam int pageIndex The page number to be cleared.
function CustomDiary:clearPage(pageIndex)

    if not Type.IsNumber(pageIndex) or pageIndex > #GameVars.Diaries[self.Name].Pages or pageIndex <=0 then
        Util.PrintLog("'pageIndex' is in an incorrect format or not a valid page number. Expected a number type in function 'clearPage' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if GameVars.Diaries[self.Name] then
        GameVars.Diaries[self.Name].Pages[pageIndex]= {NarrationTrack=nil,TextEntries={},ImageEntries={}}
        print("Page Cleared: ".. tostring(pageIndex).." for the diary system: "..tostring(self.Name))
    end
end

---
-- Adds a text entry to the specified page for the diary.
-- @tparam int pageIndex page number to add the text entry to.
-- @tparam string text Text entry to be added to the page.
-- @tparam Vec2 textPos X,Y position of the text.
-- @tparam Strings.DisplayStringOption textOptions alignment and effects for the text. Default: None. Please note text is automatically aligned to the LEFT
-- @tparam number textScale Scale factor for the text.
-- @tparam Color textColor Color of the text.
function CustomDiary:addTextEntry(pageIndex, text, textPos, textOptions, textScale, textColor)
    local textEntry = {}

    if Type.IsString(text) then
        textEntry.text = text
    else
        Util.PrintLog("'text' is in an incorrect format. Expected a string type in function 'addTextEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsVec2(textPos) then
        textEntry.textPos = textPos
    else
        Util.PrintLog("'textPos' is in an incorrect format. Expected a Vec2 type in function 'addTextEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsTable(textOptions) then
        textEntry.textOptions = textOptions
    else
        Util.PrintLog("'textOptions' is in an incorrect format. Expected a table type in function 'addTextEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(textScale) then
        textEntry.textScale = textScale
    else
        Util.PrintLog("'textScale' is in an incorrect format. Expected a number type in function 'addTextEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsColor(textColor) then
        textEntry.textColor = textColor
    else
        Util.PrintLog("'textColor' is in an incorrect format. Expected a Color type in function 'addTextEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(pageIndex) and pageIndex > 0 then
        if not GameVars.Diaries[self.Name].Pages[pageIndex] then
            GameVars.Diaries[self.Name].Pages[pageIndex] = {NarrationTrack=nil, TextEntries = {}, ImageEntries = {}}
        end
        table.insert(GameVars.Diaries[self.Name].Pages[pageIndex].TextEntries, textEntry)
        print("Text entry added to page: ".. tostring(pageIndex).." for the diary system: "..tostring(self.Name))
    else
        Util.PrintLog("'pageIndex' is in an incorrect format. Expected a number type in function 'addTextEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
    end
end

---
-- Adds an image entry to the specified page for the diary.
-- @tparam int pageIndex page number to add the image entry to.
-- @tparam Objects.ObjID objectId Object ID for the image entry sprite.
-- @tparam number spriteId SpriteID from the specified object for the image entry.
-- @tparam Color color Color of image entry.
-- @tparam Vec2 pos X,Y position of the image entry in screen percent (0-100).
-- @tparam number rot rotation of the image entry (0-360).
-- @tparam Vec2 scale X,Y Scaling factor for the image entry.
-- @tparam View.AlignMode alignMode Alignment for the image entry.
-- @tparam View.ScaleMode scaleMode Scaling for the image entry.
-- @tparam Effects.BlendID blendMode Blending modes for the image entry.
function CustomDiary:addImageEntry(pageIndex, objectId, spriteId, color, pos, rot, scale, alignMode, scaleMode, blendMode)

    local imageEntry = {}

    if Type.IsNumber(spriteId) then
        imageEntry.spriteId     = spriteId
    else
        Util.PrintLog("'spriteId' is in an incorrect format. Expected a number type in function 'addImageEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsColor(color) then
        imageEntry.color        = color
    else
        Util.PrintLog("'color' is in an incorrect format. Expected a Color type in function 'addImageEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsVec2(pos) then
        imageEntry.pos          = pos
    else
        Util.PrintLog("'pos' is in an incorrect format. Expected a Vec2 type in function 'addImageEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsNumber(rot) then
        imageEntry.rot          = rot
    else
        Util.PrintLog("'rot' is in an incorrect format. Expected a number type in function 'addImageEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if Type.IsVec2(scale) then
        imageEntry.scale        = scale
    else
        Util.PrintLog("'scale' is in an incorrect format. Expected a Vec2 type in function 'addImageEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    imageEntry.objectId     = objectId
    imageEntry.alignMode    = alignMode
    imageEntry.scaleMode    = scaleMode
    imageEntry.blendMode    = blendMode

    if Type.IsNumber(pageIndex) and pageIndex > 0 then
        if not GameVars.Diaries[self.Name].Pages[pageIndex] then
            GameVars.Diaries[self.Name].Pages[pageIndex] = {NarrationTrack=nil, TextEntries = {}, ImageEntries = {}}
        end
        table.insert(GameVars.Diaries[self.Name].Pages[pageIndex].ImageEntries, imageEntry)
        print("Image entry added to page: ".. tostring(pageIndex).." for the diary system: "..tostring(self.Name))
    else
        Util.PrintLog("'pageIndex' is in an incorrect format. Expected a number type in function 'addImageEntry' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
    end
end

---
-- Add a narration track in the voice channel to the page. Track is played with the draw button.
-- @tparam int pageIndex page number to add the narration track to.
-- @tparam string trackName of track (without file extension) to play.
function CustomDiary:addNarration(pageIndex, trackName)

    if Type.IsNumber(pageIndex) and pageIndex > 0 then
        if not GameVars.Diaries[self.Name].Pages[pageIndex] then
            GameVars.Diaries[self.Name].Pages[pageIndex] = {NarrationTrack=nil, TextEntries = {}, ImageEntries = {}}
        end

        if Type.IsString(trackName) then
            GameVars.Diaries[self.Name].Pages[pageIndex].NarrationTrack = trackName
            print("Narration added to page: ".. tostring(pageIndex).." for the diary system: "..tostring(self.Name))
        else
            Util.PrintLog("'trackName' is in an incorrect format. Expected a string type in function 'addNarration' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

    else
        Util.PrintLog("'pageIndex' is in an incorrect format. Expected a number type in function 'addNarration' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
    end

end

---
-- Remove the narration track from the page of the specified diary.
-- @tparam int pageIndex page number to remove the narration track from.
function CustomDiary:removeNarration(pageIndex)

    if not Type.IsNumber(pageIndex) or pageIndex > #GameVars.Diaries[self.Name].Pages or pageIndex <=0 then
        Util.PrintLog("'pageIndex' is in an incorrect format or not a valid page number. Expected a number type in function 'removeNarration' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end

    if GameVars.Diaries[self.Name].Pages[pageIndex] then
        GameVars.Diaries[self.Name].Pages[pageIndex].NarrationTrack = {}
    end
        print("Narration removed from the page: ".. tostring(pageIndex).." for the diary system: "..tostring(self.Name))
 end

---
-- Add a background image for the diary.
-- @tparam Objects.ObjID objectId Object ID for the diary's background.
-- @tparam number spriteId SpriteID from the specified object for the diary's background.
-- @tparam Color color Color of diary's background.
-- @tparam Vec2 pos X,Y position of the diary's background in screen percent (0-100).
-- @tparam float rot rotation of the diary's background sprite (0-360).
-- @tparam Vec2 scale X,Y Scaling factor for the diary's background.
-- @tparam View.AlignMode alignMode Alignment for the diary's background.
-- @tparam View.ScaleMode scaleMode Scaling for the diary's background.
-- @tparam Effects.BlendID blendMode Blending modes for the diary's background.
-- @tparam number alpha alpha value for the diary's background (0-255).
function CustomDiary:addBackground(objectId, spriteId, color, pos, rot, scale, alignMode, scaleMode, blendMode, alpha)
    if GameVars.Diaries[self.Name] then

        if Type.IsNumber(spriteId) then
            GameVars.Diaries[self.Name].Background.SpriteIdBg	    = spriteId
        else
            Util.PrintLog("'spriteId' is in an incorrect format. Expected a number type in function 'addBackground' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsColor(color) then
            GameVars.Diaries[self.Name].Background.ColorBg		    = color
        else
            Util.PrintLog("'color' is in an incorrect format. Expected a Color type in function 'addBackground' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsVec2(pos) then
            GameVars.Diaries[self.Name].Background.Pos			    = pos
        else
            Util.PrintLog("'pos' is in an incorrect format. Expected a Vec2 type in function 'addBackground' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsNumber(rot) then
            GameVars.Diaries[self.Name].Background.Rot			    = rot
        else
            Util.PrintLog("'rot' is in an incorrect format. Expected a number type in function 'addBackground' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsVec2(scale) then
            GameVars.Diaries[self.Name].Background.Scale            = scale
        else
            Util.PrintLog("'scale' is in an incorrect format. Expected a Vec2 type in function 'addBackground' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsNumber(alpha) and alpha>-1 and alpha < 266 then
            GameVars.Diaries[self.Name].Background.Alpha		        = alpha
        else
            Util.PrintLog("'alpha is in an incorrect format. Expected a number (0-255) type in function 'addBackground' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end
        GameVars.Diaries[self.Name].Background.ObjectIdBg	    = objectId
	    GameVars.Diaries[self.Name].Background.AlignMode        = alignMode
	    GameVars.Diaries[self.Name].Background.ScaleMode        = scaleMode
	    GameVars.Diaries[self.Name].Background.BlendMode 	    = blendMode

        print("Background added for the diary system: "..tostring(self.Name))
    end
end

---
-- Clears settings for the background for the specified diary.
function CustomDiary:clearBackground()
    if GameVars.Diaries[self.Name] then
        GameVars.Diaries[self.Name].Background = {}

        print("Background cleared for the diary system: "..tostring(self.Name))
    end
end

---
-- Customizes the notification icon and sound for the diary.
-- @tparam number notificationTime Time in seconds the notification icon will show on screen.
-- @tparam Objects.ObjID objectId Object ID for the notification icon.
-- @tparam number spriteId SpriteID from the specified object for the notification icon.
-- @tparam Color color Color of notification icon.
-- @tparam Vec2 pos X,Y position of the notification icon in screen percent (0-100).
-- @tparam number rot rotation of the notification icon (0-360).
-- @tparam Vec2 scale X,Y Scaling factor for the notification icon.
-- @tparam View.AlignMode alignMode Alignment for the notification icon.
-- @tparam View.ScaleMode scaleMode Scaling for the notification icon.
-- @tparam Effects.BlendID blendMode Blending modes for the notification icon.
-- @tparam Sound notificationSound Sound to play with notification icon.
function CustomDiary:customizeNotification(notificationTime, objectId, spriteId, color, pos, rot, scale, alignMode, scaleMode, blendMode, notificationSound)
    if GameVars.Diaries[self.Name] then

        if Type.IsNumber(spriteId) then
            GameVars.Diaries[self.Name].Notification.SpriteID	        = spriteId
        else
            Util.PrintLog("'spriteId' is in an incorrect format. Expected a number type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsColor(color) then
            GameVars.Diaries[self.Name].Notification.Color		        = color
        else
            Util.PrintLog("'color' is in an incorrect format. Expected a Color type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsVec2(pos) then
            GameVars.Diaries[self.Name].Notification.Pos			    = pos
        else
            Util.PrintLog("'pos' is in an incorrect format. Expected a Vec2 type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsNumber(rot) then
            GameVars.Diaries[self.Name].Notification.Rot			    = rot
        else
            Util.PrintLog("'rot' is in an incorrect format. Expected a number type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsVec2(scale) then
            GameVars.Diaries[self.Name].Notification.Scale		        = scale
        else
            Util.PrintLog("'scale' is in an incorrect format. Expected a Vec2 type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsNumber(notificationSound) and notificationSound > 0 then
            GameVars.Diaries[self.Name].Notification.NotificationSound	= notificationSound
        else
            Util.PrintLog("'notificationSound' is in an incorrect format. Expected a number type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsNumber(notificationTime) and notificationTime > 0 then
            GameVars.Diaries[self.Name].Notification.NotificationTime    = notificationTime
        else
            Util.PrintLog("'notificationTime' is in an incorrect format. Expected a number type in function 'customizeNotification' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        GameVars.Diaries[self.Name].Notification.ObjectID           = objectId
        GameVars.Diaries[self.Name].Notification.AlignMode		    = alignMode
        GameVars.Diaries[self.Name].Notification.ScaleMode		    = scaleMode
        GameVars.Diaries[self.Name].Notification.BlendMode		    = blendMode
        GameVars.Diaries[self.Name].Notification.ElapsedTime         = 0

        print("Notification updated for the diary system: "..tostring(self.Name))
    end
end

---
-- Clears settings for the notification system for the specified diary.
function CustomDiary:clearNotification()
    if GameVars.Diaries[self.Name] then
        GameVars.Diaries[self.Name].Notification = {}

        print("Notifications cleared for the diary system: "..tostring(self.Name))
    end
end

---
-- Customizes the page numbers for the diary.
-- @tparam int pageNoType Specifies the format for page numbers (1 or 2). 1: Displays only the current page number. 2: Formats the page number as: [Prefix][CurrentPage][Separator][UnlockedPages].
-- @tparam string prefix Prefix to be added for type 2 of page numbers.
-- @tparam string separator Separator to be added for type 2 of page numbers.
-- @tparam Vec2 textPos X,Y position of the page numbers.
-- @tparam Strings.DisplayStringOption textOptions alignment and effects for the text. Default: None. Please note text is automatically aligned to the LEFT
-- @tparam number textScale Scale factor for the page numbers.
-- @tparam Color textColor Color of the page numbers.
function CustomDiary:customizePageNumbers(pageNoType, prefix, separator, textPos, textOptions, textScale, textColor)

    if Type.IsNumber(pageNoType) then
        if GameVars.Diaries[self.Name] and pageNoType >0 and pageNoType <=2 then

            GameVars.Diaries[self.Name].PageNumbers.pageNoType       = pageNoType

            if Type.IsString(prefix) then
                GameVars.Diaries[self.Name].PageNumbers.prefix           = prefix
            else
                Util.PrintLog("'prefix' is in an incorrect format. Expected a string type in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
                return
            end

            if Type.IsString(separator) then
                GameVars.Diaries[self.Name].PageNumbers.separator        = separator
            else
                Util.PrintLog("'separator' is in an incorrect format. Expected a string type in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
                return
            end

            if Type.IsVec2(textPos) then
                GameVars.Diaries[self.Name].PageNumbers.textPos          = textPos
            else
                Util.PrintLog("'textPos' is in an incorrect format. Expected a Vec2 type in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
                return
            end

            if Type.IsTable(textOptions) then
                GameVars.Diaries[self.Name].PageNumbers.textOptions      = textOptions
            else
                Util.PrintLog("'textOptions' is in an incorrect format. Expected a table type in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
                return
            end

            if Type.IsNumber(textScale) then
                GameVars.Diaries[self.Name].PageNumbers.textScale		= textScale
            else
                Util.PrintLog("'textScale' is in an incorrect format. Expected a number type in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
                return
            end

            if Type.IsColor(textColor) then
                GameVars.Diaries[self.Name].PageNumbers.textColor		= textColor
            else
                Util.PrintLog("'textColor' is in an incorrect format. Expected a Color type in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
                return
            end
        end
    else
        Util.PrintLog("'pageNoType' is in an incorrect format. Expected a number type (1 or 2) in function 'customizePageNumbers' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
        return
    end
    print("Page Numbers updated for the diary system: "..tostring(self.Name))
end


---
-- Clears settings for the page numbers for the specified diary.
function CustomDiary:clearPageNumbers()
    if GameVars.Diaries[self.Name] then
        GameVars.Diaries[self.Name].PageNumbers = nil
		print("Page Numbers cleared for the diary system: "..tostring(self.Name))
    end
end

---
-- Customizes the controls text for the diary.
-- @tparam Vec2 textPos X,Y position of the controls text.
-- @tparam Strings.DisplayStringOption textOptions alignment and effects for the text. Default: None. Please note text is automatically aligned to the LEFT.
-- @tparam number textScale Scale factor for the controls.
-- @tparam Color textColor Color of the page controls.
function CustomDiary:customizeControls(textPos, textOptions, textScale, textColor)
    if GameVars.Diaries[self.Name] then
        if Type.IsVec2(textPos) then
            GameVars.Diaries[self.Name].Controls.textPos         = textPos
        else
            Util.PrintLog("'textPos' is in an incorrect format. Expected a Vec2 type in function 'customizeControls' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsTable(textOptions) then
            GameVars.Diaries[self.Name].Controls.textOptions    = textOptions
        else
            Util.PrintLog("'textOptions' is in an incorrect format. Expected a table type in function 'customizeControls' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsNumber(textScale) then
            GameVars.Diaries[self.Name].Controls.textScale        = textScale
        else
            Util.PrintLog("'textScale' is in an incorrect format. Expected a number type in function 'customizeControls' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsColor(textColor) then
            GameVars.Diaries[self.Name].Controls.textColor		= textColor
        else
            Util.PrintLog("'textColor' is in an incorrect format. Expected a Color type in function 'customizeControls' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end
        GameVars.Diaries[self.Name].Controls.text1           = "Space: Play Voice Note"
        GameVars.Diaries[self.Name].Controls.text2           = "Left Key: Previous Page"
        GameVars.Diaries[self.Name].Controls.text3           = "Right Key: Next Page"
        GameVars.Diaries[self.Name].Controls.text4           = "Esc: Back"
        GameVars.Diaries[self.Name].Controls.separator       = "|"
        print("Controls updated for the diary system: "..tostring(self.Name))
    end
end

---
-- Customizes the display text for controls for specified diary.
-- @tparam string string1 Text for Space key controls text.
-- @tparam string string2 Text for Left key controls text.
-- @tparam string string3 Text for Right key controls text.
-- @tparam string string4 Text for Esc key controls text.
-- @tparam string separator Text for separator between controls text.
function CustomDiary:customizeControlsText(string1, string2, string3, string4, separator)
    if GameVars.Diaries[self.Name] then

        if Type.IsString(string1) then
            GameVars.Diaries[self.Name].Controls.text1           = string1
        else
            Util.PrintLog("'string1' is in an incorrect format. Expected a string type in function 'customizeControlsText' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsString(string2) then
            GameVars.Diaries[self.Name].Controls.text2           = string2
        else
            Util.PrintLog("'string2' is in an incorrect format. Expected a string type in function 'customizeControlsText' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsString(string3) then
            GameVars.Diaries[self.Name].Controls.text3           = string3
        else
            Util.PrintLog("'string3' is in an incorrect format. Expected a string type in function 'customizeControlsText' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsString(string4) then
            GameVars.Diaries[self.Name].Controls.text4           = string4
        else
            Util.PrintLog("'string4' is in an incorrect format. Expected a string type in function 'customizeControlsText' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end

        if Type.IsString(separator) then
            GameVars.Diaries[self.Name].Controls.separator       = separator
            print("Controls text updated")
        else
            Util.PrintLog("'separator' is in an incorrect format. Expected a string type in function 'customizeControlsText' for the diary system: "..tostring(self.Name), Util.LogLevel.WARNING)
            return
        end
    end
end


---
-- Clears settings for the specified diary's controls text.
function CustomDiary:clearControls()
    if GameVars.Diaries[self.Name] then
        GameVars.Diaries[self.Name].Controls ={}

        print("Controls cleared for the diary system: "..tostring(self.Name))
    end
end

-- !Ignore
LevelFuncs.Engine.Diaries.ShowDiary = function()

    local objectNumber = GameVars.LastUsedDiary
	local dataName = objectNumber .. "_diarydata"

    if GameVars.Diaries[dataName] then

        local diary             = GameVars.Diaries[dataName]
        local currentIndex      = diary.CurrentPageIndex
        local maxPages          = diary.UnlockedPages
        local narrationTrack    = diary.Pages[currentIndex].NarrationTrack
        local alphaDelta        = diary.AlphaBlendSpeed

        if diary.CurrentAlpha ~= diary.TargetAlpha then

            if diary.CurrentAlpha < diary.TargetAlpha then
                diary.CurrentAlpha = math.floor(math.min(diary.CurrentAlpha + alphaDelta, diary.TargetAlpha))
            else
                diary.CurrentAlpha = math.floor(math.max(diary.CurrentAlpha - alphaDelta, diary.TargetAlpha))
            end
        end

        -- Switch pages when entries have fully faded out
        if diary.EntryFadingOut then
            -- Fade out current entries
            if diary.EntryCurrentAlpha > 0 then
                diary.EntryCurrentAlpha = math.max(0, diary.EntryCurrentAlpha - alphaDelta)
            else
                -- Fade-out completed, switch page and start fade-in
                diary.EntryFadingOut = false
                diary.EntryFadingIn = true
                diary.EntryCurrentAlpha = 0
                currentIndex = diary.NextPageIndex and diary.NextPageIndex or 1-- Update to the new page
            end
        elseif diary.EntryFadingIn then
            -- Fade in new entries
            if diary.EntryCurrentAlpha < diary.EntryTargetAlpha then
                diary.EntryCurrentAlpha = math.min(diary.EntryTargetAlpha, diary.EntryCurrentAlpha + alphaDelta)
            else
                -- Fade-in completed
                diary.EntryFadingIn = false
            end
        end

        if KeyIsHit(ActionID.DRAW) then
            if narrationTrack then
            PlayAudioTrack(narrationTrack, Sound.SoundTrackType.VOICE)
            end
        elseif KeyIsHit(ActionID.LEFT) and not (diary.EntryFadingOut or diary.EntryFadingIn) then
            -- Initiate fade-out to switch to the previous page
                if currentIndex > 1 then
                    diary.EntryFadingOut = true
                    diary.NextPageIndex = math.max(1, currentIndex - 1)
                    StopAudioTrack(Sound.SoundTrackType.VOICE)
                    PlaySound(diary.PageSound)
                end
        elseif KeyIsHit(ActionID.RIGHT) and not (diary.EntryFadingOut or diary.EntryFadingIn) then
                -- Initiate fade-out to switch to the next page
                if currentIndex < maxPages then
                    diary.EntryFadingOut = true
                    diary.NextPageIndex = math.min(maxPages, currentIndex + 1)
                    StopAudioTrack(Sound.SoundTrackType.VOICE)
                    PlaySound(diary.PageSound)
                end
        elseif KeyIsHit(ActionID.INVENTORY) then
            PlaySound(diary.ExitSound)
            diary.TargetAlpha = 0
            diary.EntryFadingOut = true
        end

       --Sets the currentindex so that the diary opens at the same page
        diary.CurrentPageIndex = currentIndex
        local textEntries = GameVars.Diaries[dataName].Pages[currentIndex].TextEntries
        local imageEntries = GameVars.Diaries[dataName].Pages[currentIndex].ImageEntries

        if diary.CurrentAlpha > 0 then
            diary.Visible = true
        elseif diary.CurrentAlpha == 0 and diary.EntryCurrentAlpha == 0 then
            diary.Visible = false
            StopAudioTrack(Sound.SoundTrackType.VOICE)
            PlaySound(diary.ExitSound)
            Flow.SetFreezeMode(Flow.FreezeMode.NONE)
            TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.Diaries.ShowDiary)
            return
        end

        if textEntries or imageEntries then
            -- Draw Diary sprite
            local dAlpha = math.min(diary.CurrentAlpha, diary.Alpha)
            local dColor = TEN.Color(diary.ColorBg.r, diary.ColorBg.g, diary.ColorBg.b, dAlpha)
            local dSprite = TEN.DisplaySprite(diary.ObjectIdBg, diary.SpriteIdBg, diary.Pos, diary.Rot, diary.Scale, dColor)
            dSprite:Draw(1, diary.AlignMode, diary.ScaleMode, diary.BlendMode)

            -- Draw Background Image
            if diary.Background and next(diary.Background) then
                local bgAlpha = math.min(diary.CurrentAlpha, diary.Background.Alpha)
                local bgColor = TEN.Color(diary.Background.ColorBg.r, diary.Background.ColorBg.g, diary.Background.ColorBg.b, bgAlpha)
                local bgSprite = TEN.DisplaySprite(diary.Background.ObjectIdBg, diary.Background.SpriteIdBg, diary.Background.Pos, diary.Background.Rot, diary.Background.Scale, bgColor)
                bgSprite:Draw(0, diary.Background.AlignMode, diary.Background.ScaleMode, diary.Background.BlendMode)
            end

            if diary.Controls.textPos then

                local controlTexts = {}

                if narrationTrack then
                    table.insert(controlTexts, diary.Controls.text1)
                end
                if currentIndex > 1 then
                    table.insert(controlTexts, diary.Controls.text2)
                end
                if currentIndex < maxPages then
                    table.insert(controlTexts, diary.Controls.text3)
                end

                -- Add the always-present back control
                table.insert(controlTexts, diary.Controls.text4)
                local alignedText = table.concat(controlTexts, diary.Controls.separator)
                local controlPosInPixel = TEN.Vec2(TEN.Util.PercentToScreen(diary.Controls.textPos.x, diary.Controls.textPos.y))
                local IsString = TEN.Flow.IsStringPresent(alignedText)
                local textColor = TEN.Color(diary.Controls.textColor.r, diary.Controls.textColor.g, diary.Controls.textColor.b, diary.CurrentAlpha)

                local controlsText = TEN.Strings.DisplayString(alignedText, controlPosInPixel, diary.Controls.textScale, textColor, IsString, diary.Controls.textOptions)
                ShowString(controlsText, 1 / 30)

            end



            --Draw Page Numbers
            if diary.PageNumbers and next(diary.PageNumbers) then

                local pageNo = diary.PageNumbers
                local pageNumbers = tostring(currentIndex)
                if pageNo.pageNoType == 2 then
                    pageNumbers = pageNo.prefix .. currentIndex  .. pageNo.separator .. diary.UnlockedPages
                end

                local pageNoPosInPixel = TEN.Vec2(TEN.Util.PercentToScreen(pageNo.textPos.x, pageNo.textPos.y))
                local IsString = TEN.Flow.IsStringPresent(pageNumbers)
                local textColor = TEN.Color(pageNo.textColor.r, pageNo.textColor.g, pageNo.textColor.b, diary.CurrentAlpha)

                local pageNumberText = TEN.Strings.DisplayString(pageNumbers, pageNoPosInPixel, pageNo.textScale, textColor, IsString, pageNo.textOptions)
                ShowString(pageNumberText, 1 / 30)

            end

            -- Draw entries based on type
            if textEntries then
                for _, entry in ipairs(textEntries) do

                    local entryPosInPixel = TEN.Vec2(TEN.Util.PercentToScreen(entry.textPos.x, entry.textPos.y))
                    local IsString = TEN.Flow.IsStringPresent(entry.text)
                    local textColor = TEN.Color(entry.textColor.r, entry.textColor.g, entry.textColor.b, diary.EntryCurrentAlpha)

                    local entryText = TEN.Strings.DisplayString(entry.text, entryPosInPixel, entry.textScale, textColor, IsString, entry.textOptions)
                    ShowString(entryText, 1 / 30)

                end
            end

            if imageEntries then
                for _, entry in ipairs(imageEntries) do

                    local entryColor = TEN.Color(entry.color.r,entry.color.g,entry.color.b,diary.EntryCurrentAlpha)
                    local entrySprite = TEN.DisplaySprite(entry.objectId, entry.spriteId, entry.pos, entry.rot, entry.scale, entryColor)

                    entrySprite:Draw(2, entry.alignMode, entry.scaleMode, entry.blendMode)

                end
            end
        end
    end
end

-- !Ignore
LevelFuncs.Engine.Diaries.ActivateDiary = function(objectNumber)

    local dataName = objectNumber .. "_diarydata"

	if GameVars.Diaries[dataName] then
        GameVars.LastUsedDiary = objectNumber
        TEN.Inventory.ClearUsedItem()
        GameVars.Diaries[dataName].TargetAlpha = 255
        GameVars.Diaries[dataName].EntryTargetAlpha = 255
		TEN.Logic.AddCallback(TEN.Logic.CallbackPoint.PREFREEZE, LevelFuncs.Engine.Diaries.ShowDiary)
        Flow.SetFreezeMode(Flow.FreezeMode.FULL)
	end

end

-- !Ignore
LevelFuncs.Engine.Diaries.ShowNotification = function(dt)

    local dataName = GameVars.LastUsedDiary .. "_diarydata"

    if GameVars.Diaries[dataName] then
        local diary = GameVars.Diaries[dataName]

        if diary.CurrentAlpha ~= diary.TargetAlpha then

            if diary.CurrentAlpha < diary.TargetAlpha then
                diary.CurrentAlpha = math.floor(math.min(diary.CurrentAlpha + diary.AlphaBlendSpeed, diary.TargetAlpha))
            else
                diary.CurrentAlpha = math.floor(math.max(diary.CurrentAlpha - diary.AlphaBlendSpeed, diary.TargetAlpha))
            end

        end

        GameVars.Diaries[dataName].Notification.ElapsedTime  = GameVars.Diaries[dataName].Notification.ElapsedTime + dt

        if GameVars.Diaries[dataName].Notification.ElapsedTime <= GameVars.Diaries[dataName].Notification.NotificationTime then
            diary.TargetAlpha = 255
        else
            diary.TargetAlpha = 0
        end

        if diary.CurrentAlpha > 0 then
            LevelFuncs.Engine.Diaries.PrepareNotification()
        elseif diary.CurrentAlpha == 0 then
            diary.Notification.ElapsedTime = 0
            TEN.Logic.RemoveCallback(TEN.Logic.CallbackPoint.PRELOOP, LevelFuncs.Engine.Diaries.ShowNotification)
            print("Notification Callback removed")
            return
        end
	end

end

-- !Ignore
LevelFuncs.Engine.Diaries.PrepareNotification = function()

	local dataName = GameVars.LastUsedDiary .. "_diarydata"

    if GameVars.Diaries[dataName] then

        local diary = GameVars.Diaries[dataName]
        local notif = diary.Notification
        local spriteColor = Color(notif.Color.r, notif.Color.g, notif.Color.b, diary.CurrentAlpha)

        local sprite = TEN.DisplaySprite(notif.ObjectID, notif.SpriteID, notif.Pos, notif.Rot, notif.Scale, spriteColor)
        sprite:Draw(0, notif.AlignMode,  notif.ScaleMode,  notif.BlendMode)

    end

end

return CustomDiary