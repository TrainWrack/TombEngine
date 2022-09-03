#include "framework.h"
#include <filesystem>

#include "FlowHandler.h"
#include "ReservedScriptNames.h"
#include "Sound/sound.h"
#include "Game/savegame.h"
#include "Flow/InventoryItem/InventoryItem.h"
#include "InventorySlots.h"
#include "Game/gui.h"
#include "Logic/LevelFunc.h"
#include "Vec3/Vec3.h"
#include "Objects/ScriptInterfaceObjectsHandler.h"
#include "Strings/ScriptInterfaceStringsHandler.h"
#include "Specific/trutils.h"

/***
Functions for use in Flow.lua, settings.lua and strings.lua
@tentable Flow 
@pragma nostrip
*/

using std::string;
using std::vector;
using std::unordered_map;

ScriptInterfaceGame* g_GameScript;
ScriptInterfaceObjectsHandler* g_GameScriptEntities;
ScriptInterfaceStringsHandler* g_GameStringsHandler;
ScriptInterfaceFlowHandler* g_GameFlow;

FlowHandler::FlowHandler(sol::state* lua, sol::table & parent) : m_handler{ lua }
{

/*** gameflow.lua.
These functions are called in gameflow.lua, a file loosely equivalent to winroomedit's SCRIPT.DAT.
They handle a game's 'metadata'; i.e., things such as level titles, loading screen paths, and default
ambient tracks.
@section Flowlua
*/
	sol::table table_flow{ m_handler.GetState()->lua_state(), sol::create };
	parent.set(ScriptReserved_Flow, table_flow);

/***
Add a level to the Flow.
@function AddLevel
@tparam Level level a level object
*/
	table_flow.set_function(ScriptReserved_AddLevel, &FlowHandler::AddLevel, this);

/*** Image to show when loading the game.
Must be a .jpg or .png image.
@function SetIntroImagePath
@tparam string path the path to the image, relative to the TombEngine exe
*/
	table_flow.set_function(ScriptReserved_SetIntroImagePath, &FlowHandler::SetIntroImagePath, this);

/*** Image to show in the background of the title screen.
Must be a .jpg or .png image.
__(not yet implemented)__
@function SetTitleScreenImagePath
@tparam string path the path to the image, relative to the TombEngine exe
*/
	table_flow.set_function(ScriptReserved_SetTitleScreenImagePath, &FlowHandler::SetTitleScreenImagePath, this);

/*** settings.lua.
These functions are called in settings.lua, a file which holds your local settings.
settings.lua shouldn't be bundled with any finished levels/games.
@section settingslua
*/
/***
@function SetSettings
@tparam Settings settings a settings object 
*/
	table_flow.set_function(ScriptReserved_SetSettings, &FlowHandler::SetSettings, this);

/***
@function SetAnimations
@tparam Animations animations an animations object 
*/
	table_flow.set_function(ScriptReserved_SetAnimations, &FlowHandler::SetAnimations, this);

/*** strings.lua. 
These functions used in strings.lua, which is generated by TombIDE.
You will not need to call them manually.
@section stringslua
*/
/*** Set string variable keys and their translations.
@function SetStrings
@tparam tab table array-style table with strings
*/
	table_flow.set_function(ScriptReserved_SetStrings, &FlowHandler::SetStrings, this);

/*** Get translated string
@function GetString
@tparam key string key for translated string 
*/
	table_flow.set_function(ScriptReserved_GetString, &FlowHandler::GetString, this);

/*** Set language names for translations.
Specify which translations in the strings table correspond to which languages.
@function SetLanguageNames
@tparam tab table array-style table with language names
*/
	table_flow.set_function(ScriptReserved_SetLanguageNames, &FlowHandler::SetLanguageNames, this);

	ScriptColor::Register(parent);
	Rotation::Register(parent);
	Vec3::Register(parent);
	Level::Register(table_flow);
	SkyLayer::Register(table_flow);
	Mirror::Register(table_flow);
	InventoryItem::Register(table_flow);
	Animations::Register(table_flow);
	Settings::Register(table_flow);
	Fog::Register(table_flow);
	
	m_handler.MakeReadOnlyTable(table_flow, ScriptReserved_WeatherType, kWeatherTypes);
	m_handler.MakeReadOnlyTable(table_flow, ScriptReserved_LaraType, kLaraTypes);
	m_handler.MakeReadOnlyTable(table_flow, ScriptReserved_InvItem, kInventorySlots);
	m_handler.MakeReadOnlyTable(table_flow, ScriptReserved_RotationAxis, kRotAxes);
	m_handler.MakeReadOnlyTable(table_flow, ScriptReserved_ItemAction, kItemActions);
	m_handler.MakeReadOnlyTable(table_flow, ScriptReserved_ErrorMode, kErrorModes);
}

FlowHandler::~FlowHandler()
{
	for (auto& lev : Levels)
		delete lev;
}

void FlowHandler::SetLanguageNames(sol::as_table_t<std::vector<std::string>> && src)
{
	m_languageNames = std::move(src);
}

void FlowHandler::SetStrings(sol::nested<std::unordered_map<std::string, std::vector<std::string>>> && src)
{
	m_translationsMap = std::move(src);
}

void FlowHandler::SetSettings(Settings const & src)
{
	m_settings = src;
}

void FlowHandler::SetAnimations(Animations const& src)
{
	Anims = src;
}

void FlowHandler::AddLevel(Level const& level)
{
	Levels.push_back(new Level{ level });
}

void FlowHandler::SetIntroImagePath(std::string const& path)
{
	IntroImagePath = path;
}

void FlowHandler::SetTitleScreenImagePath(std::string const& path)
{
	TitleScreenImagePath = path;
}

void FlowHandler::LoadFlowScript()
{
	m_handler.ExecuteScript("Scripts/Gameflow.lua");
	m_handler.ExecuteScript("Scripts/Strings.lua");
	m_handler.ExecuteScript("Scripts/Settings.lua");

	SetScriptErrorMode(GetSettings()->ErrorMode);
}

char const * FlowHandler::GetString(const char* id) const
{
	if (!ScriptAssert(m_translationsMap.find(id) != m_translationsMap.end(), std::string{ "Couldn't find string " } + id))
		return "String not found";
	else
		return m_translationsMap.at(string(id)).at(0).c_str();
}

Settings* FlowHandler::GetSettings()
{
	return &m_settings;
}

Level* FlowHandler::GetLevel(int id)
{
	return Levels[id];
}

int	FlowHandler::GetNumLevels() const
{
	return Levels.size();
}

int FlowHandler::GetLevelNumber(std::string const& fileName)
{
	if (fileName.empty())
		return -1;

	auto lcFilename = TEN::Utils::ToLower(fileName);

	for (int i = 0; i < Levels.size(); i++)
	{
		auto level = TEN::Utils::ToLower(this->GetLevel(i)->FileName);
		if (level == lcFilename && std::filesystem::exists(fileName))
			return i;
	}

	return -1;
}

bool FlowHandler::IsFlyCheatEnabled() const
{
	return FlyCheat;
}

bool FlowHandler::DoFlow()
{
	// We start with the title level, if no other index is specified
	if (CurrentLevel == -1)
		CurrentLevel = 0;

	SelectedLevelForNewGame = 0;
	SelectedSaveGame = 0;
	SaveGameHeader header;

	// We loop indefinitely, looking for return values of DoTitle or DoLevel
	bool loadFromSavegame = false;

	while (DoTheGame)
	{
		// First we need to fill some legacy variables in PCTomb5.exe
		Level* level = Levels[CurrentLevel];

		GameStatus status;

		if (CurrentLevel == 0)
		{
			try
			{
				status = DoTitle(0, level->AmbientTrack);
			}
			catch (TENScriptException const& e)
			{
				std::string msg = std::string{ "A Lua error occurred while running the title level; " } + __func__ + ": " + e.what();
				TENLog(msg, LogLevel::Error, LogConfig::All);
				ShutdownTENLog();
				throw;
			}
		}
		else
		{
			// Prepare inventory objects table
			for (size_t i = 0; i < level->InventoryObjects.size(); i++)
			{
				InventoryItem* obj = &level->InventoryObjects[i];
				if (obj->slot >= 0 && obj->slot < INVENTORY_TABLE_SIZE)
				{
					InventoryObject* invObj = &inventry_objects_list[obj->slot];

					invObj->objname = obj->name.c_str();
					invObj->scale1 = obj->scale;
					invObj->yoff = obj->yOffset;
					invObj->xrot = FROM_DEGREES(obj->rot.x);
					invObj->yrot = FROM_DEGREES(obj->rot.y);
					invObj->zrot = FROM_DEGREES(obj->rot.z);
					invObj->meshbits = obj->meshBits;
					invObj->opts = obj->action;
					invObj->rot_flags = obj->rotationFlags;
				}
			}

			try
			{
				status = DoLevel(CurrentLevel, level->AmbientTrack, loadFromSavegame);
			}
			catch (TENScriptException const& e) 
			{
				std::string msg = std::string{ "A Lua error occurred while running a level; " } + __func__ + ": " + e.what();
				TENLog(msg, LogLevel::Error, LogConfig::All);
				status = GameStatus::ExitToTitle;
			}
			loadFromSavegame = false;
		}

		switch (status)
		{
		case GameStatus::ExitGame:
			return true;
		case GameStatus::ExitToTitle:
			CurrentLevel = 0;
			break;
		case GameStatus::NewGame:
			CurrentLevel = (SelectedLevelForNewGame != 0 ? SelectedLevelForNewGame : 1);
			SelectedLevelForNewGame = 0;
			InitialiseGame = true;
			break;
		case GameStatus::LoadGame:
			// Load the header of the savegame for getting the level to load
			SaveGame::LoadHeader(SelectedSaveGame, &header);

			// Load level
			CurrentLevel = header.Level;
			GameTimer = header.Timer;
			loadFromSavegame = true;

			break;
		case GameStatus::LevelComplete:
			if (LevelComplete >= Levels.size())
				CurrentLevel = 0; // TODO: final credits
			else
				CurrentLevel = LevelComplete;
			LevelComplete = 0;
			break;
		}
	}

	g_GameScript->ResetScripts(true);
	return true;
}

bool FlowHandler::CanPlayAnyLevel() const
{
	return PlayAnyLevel;
}

