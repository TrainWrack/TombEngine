#include "framework.h"
#include "GameLogicScript.h"
#include "items.h"
#include "box.h"
#include "lara.h"
#include "savegame.h"
#include "lot.h"
#include "sound.h"
#include "setup.h"
#include "level.h"
#include "tomb4fx.h"
#include "effect2.h"
#include "pickup.h"
#include "newinv2.h"
#include <iostream>
#include "InventorySlots.h"
#include "ObjectIDs.h"

#ifndef _DEBUG
#include <iostream>
#endif

extern GameFlow* g_GameFlow;
GameScript* g_GameScript;
extern bool const WarningsAsErrors = true;

GameScript::GameScript(sol::state* lua) : LuaHandler{ lua }
{
	m_lua->set_function("SetAmbientTrack", &GameScript::SetAmbientTrack);
	m_lua->set_function("PlayAudioTrack", &GameScript::PlayAudioTrack);

	m_lua->set_function("GiveInvItem", &GameScript::InventoryAdd);
	m_lua->set_function("TakeInvItem", &GameScript::InventoryRemove);

	m_lua->set_function("GetInvItemCount", &GameScript::InventoryGetCount);
	m_lua->set_function("SetInvItemCount", &GameScript::InventorySetCount);

	m_lua->set_function("GetItemByName", &GameScript::GetItemByName, this);
	m_lua->set_function("GetItemByID", &GameScript::GetItemById, this);
	auto makeReadOnlyTable = [this](std::string const & tableName, auto const& container)
	{
		auto mt = tableName + "Meta";
		// Put all the data in the metatable	
		m_lua->set(mt, sol::as_table(container));

		// Make the metatable's __index refer to itself so that requests
		// to the main table will go through to the metatable (and thus the
		// container's members)
		m_lua->safe_script(mt + ".__index = " + mt);

		// Don't allow the table to have new elements put into it
		m_lua->safe_script(mt + ".__newindex = function() error('" + tableName + " is read-only') end");

		// Protect the metatable
		m_lua->safe_script(mt + ".__metatable = 'metatable is protected'");

		auto tab = m_lua->create_named_table(tableName);
		m_lua->safe_script("setmetatable(" + tableName + ", " + mt + ")");

		// point the initial metatable variable away from its contents. this is just for cleanliness
		m_lua->safe_script(mt + "= nil");
	};

	makeReadOnlyTable("InvItem", kInventorySlots);
	makeReadOnlyTable("ObjID", kObjIDs);

	GameScriptItemInfo::Register(m_lua);
	GameScriptItemInfo::SetNameCallbacks(
		[this](std::string const& str, short num) {	return AddLuaName(str, num); },
		[this](std::string const& str) { return RemoveLuaName(str); }
	);

	GameScriptMeshInfo::Register(m_lua);
	GameScriptMeshInfo::SetNameCallbacks(
		[this](std::string const& str, MESH_INFO & info) {	return AddLuaNameMesh(str, info); },
		[this](std::string const& str) { return RemoveLuaNameMesh(str); }
	);

	GameScriptPosition::Register(m_lua);
	GameScriptRotation::Register(m_lua);
	GameScriptColor::Register(m_lua);

	m_lua->new_enum<GAME_OBJECT_ID>("Object", {
		{"LARA", ID_LARA}
		});

	m_lua->new_usertype<LuaVariables>("Variable",
		sol::meta_function::index, &LuaVariables::GetVariable,
		sol::meta_function::new_index, &LuaVariables::SetVariable,
		"new", sol::no_constructor
		);
}

void GameScript::AddTrigger(LuaFunction* function)
{
	m_triggers.push_back(function);
	(*m_lua).script(function->Code);
}

void GameScript::AddLuaId(int luaId, short itemNumber)
{
	m_itemsMapId.insert(std::pair<int, short>(luaId, itemNumber));
}

bool GameScript::RemoveLuaName(std::string const & luaName)
{
	return m_itemsMapName.erase(luaName);
}

bool GameScript::AddLuaName(std::string const & luaName, short itemNumber)
{
	return m_itemsMapName.insert(std::pair<std::string, short>(luaName, itemNumber)).second;
}

bool GameScript::RemoveLuaNameMesh(std::string const & luaName)
{
	return m_meshesMapName.erase(luaName);
}

bool GameScript::AddLuaNameMesh(std::string const& luaName, MESH_INFO& infoRef)
{
	return m_meshesMapName.insert(std::pair<std::string, MESH_INFO&>(luaName, infoRef)).second;
}

void GameScript::FreeLevelScripts()
{
	/*
	// Delete all triggers
	for (int i = 0; i < m_triggers.size(); i++)
	{
		LuaFunction* trigger = m_triggers[i];
		char* name = (char*)trigger->Name.c_str();
		(*m_lua)[name] = NULL;
		delete m_triggers[i];
	}
	m_triggers.clear();

	// Clear the items mapping
	m_itemsMap.clear();

	(*m_lua)["Lara"] = NULL;
	//delete m_Lara;
	*/
}

bool GameScript::ExecuteTrigger(short index)
{
	return true;
	/*
	// Is this a valid trigger?
	if (index >= m_triggers.size())
		return true;

	LuaFunction* trigger = m_triggers[index];

	// We want to execute a trigger just one time 
	// TODO: implement in the future continoous trigger?
	if (trigger->Executed)
		return true;

	// Get the trigger function name
	char* name = (char*)trigger->Name.c_str();

	// Execute trigger
	bool result = (*m_lua)[name]();

	// Trigger was executed, don't execute it anymore
	trigger->Executed = result;

	m_locals.for_each([&](sol::object const& key, sol::object const& value) {
		if (value.is<bool>())
			std::cout << key.as<std::string>() << " " << value.as<bool>() << std::endl;
		else if (value.is<std::string>())
			std::cout << key.as<std::string>() << " " << value.as<std::string>() << std::endl;
		else
			std::cout << key.as<std::string>() << " " << value.as<int>() << std::endl;		
	});

	return result;
	*/
}

void GameScript::JumpToLevel(int levelNum)
{
	if (levelNum >= g_GameFlow->GetNumLevels())
		return;
	LevelComplete = levelNum;
}

int GameScript::GetSecretsCount()
{
	return Savegame.Level.Secrets;
}

void GameScript::SetSecretsCount(int secretsNum)
{
	if (secretsNum > 255)
		return;
	Savegame.Level.Secrets = secretsNum;
}

void GameScript::AddOneSecret()
{
	if (Savegame.Level.Secrets >= 255)
		return;
	Savegame.Level.Secrets++;
	S_CDPlay(TRACK_FOUND_SECRET, 0);
}

/*
void GameScript::MakeItemInvisible(short id)
{
	if (m_itemsMap.find(id) == m_itemsMap.end())
		return;

	short itemNum = m_itemsMap[id];

	ITEM_INFO* item = &g_Level.Items[itemNum];

	if (item->active)
	{
		if (Objects[item->objectNumber].intelligent)
		{
			if (item->status == ITEM_ACTIVE)
			{
				item->touchBits = 0;
				item->status = ITEM_INVISIBLE;
				DisableBaddieAI(itemNum);
			}
		}
		else
		{
			item->touchBits = 0;
			item->status = ITEM_INVISIBLE;
		}
	}
}
*/
template <typename T>
void GameScript::GetVariables(std::map<std::string, T>& locals, std::map<std::string, T>& globals)
{
	for (const auto& it : m_locals.variables)
	{
		if (it.second.is<T>())
			locals.insert(std::pair<std::string, T>(it.first, it.second.as<T>()));
	}
	for (const auto& it : m_globals.variables)
	{
		if (it.second.is<T>())
			globals.insert(std::pair<std::string, T>(it.first, it.second.as<T>()));
	}
}

template void GameScript::GetVariables<bool>(std::map<std::string, bool>& locals, std::map<std::string, bool>& globals);
template void GameScript::GetVariables<float>(std::map<std::string, float>& locals, std::map<std::string, float>& globals);
template void GameScript::GetVariables<std::string>(std::map<std::string, std::string>& locals, std::map<std::string, std::string>& globals);

template <typename T>
void GameScript::SetVariables(std::map<std::string, T>& locals, std::map<std::string, T>& globals)
{
	m_locals.variables.clear();
	for (const auto& it : locals)
	{
		m_locals.variables.insert(std::pair<std::string, sol::object>(it.first, sol::object(m_lua->lua_state(), sol::in_place, it.second)));
	}
	for (const auto& it : globals)
	{
		m_globals.variables.insert(std::pair<std::string, sol::object>(it.first, sol::object(m_lua->lua_state(), sol::in_place, it.second)));
	}
}

template void GameScript::SetVariables<bool>(std::map<std::string, bool>& locals, std::map<std::string, bool>& globals);
template void GameScript::SetVariables<float>(std::map<std::string, float>& locals, std::map<std::string, float>& globals);
template void GameScript::SetVariables<std::string>(std::map<std::string, std::string>& locals, std::map<std::string, std::string>& globals);

std::unique_ptr<GameScriptItemInfo> GameScript::GetItemById(int id)
{
	if (m_itemsMapId.find(id) == m_itemsMapId.end())
	{
		if (WarningsAsErrors)
			throw "item id not found";
		return std::unique_ptr<GameScriptItemInfo>(nullptr);
	}

	return std::make_unique<GameScriptItemInfo>(m_itemsMapId[id], false);
}

std::unique_ptr<GameScriptItemInfo> GameScript::GetItemByName(std::string const & name)
{
	if (m_itemsMapName.find(name) == m_itemsMapName.end())
	{
		if (WarningsAsErrors)
		{
			std::string error{ "Item name not found: " };
			error += name;
			throw std::runtime_error{error};
		}
		return std::unique_ptr<GameScriptItemInfo>(nullptr);
	}

	return std::make_unique<GameScriptItemInfo>(m_itemsMapName[name], false);
}

void GameScript::PlayAudioTrack(std::string const & trackName, bool looped)
{
	S_CDPlay(trackName, looped);
}

void GameScript::PlaySoundEffect(int id, GameScriptPosition p, int flags)
{
	PHD_3DPOS pos;

	pos.xPos = p.x;
	pos.yPos = p.y;
	pos.zPos = p.z;
	pos.xRot = 0;
	pos.yRot = 0;
	pos.zRot = 0;

	SoundEffect(id, &pos, flags);
}

void GameScript::PlaySoundEffect(int id, int flags)
{
	SoundEffect(id, NULL, flags);
}

void GameScript::SetAmbientTrack(std::string const & trackName)
{
	CurrentAtmosphere = trackName;
	S_CDPlay(CurrentAtmosphere, 1);
}

void GameScript::AddLightningArc(GameScriptPosition src, GameScriptPosition dest, GameScriptColor color, int lifetime, int amplitude, int beamWidth, int segments, int flags)
{
	PHD_VECTOR p1;
	p1.x = src.x;
	p1.y = src.y;
	p1.z = src.z;

	PHD_VECTOR p2;
	p2.x = dest.x;
	p2.y = dest.y;
	p2.z = dest.z;

	TriggerLightning(&p1, &p2, amplitude, color.GetR(), color.GetG(), color.GetB(), lifetime, flags, beamWidth, segments);
}

void GameScript::AddShockwave(GameScriptPosition pos, int innerRadius, int outerRadius, GameScriptColor color, int lifetime, int speed, int angle, int flags)
{
	PHD_3DPOS p;
	p.xPos = pos.x;
	p.yPos = pos.y;
	p.zPos = pos.z;
	
	TriggerShockwave(&p, innerRadius, outerRadius, speed, color.GetR(), color.GetG(), color.GetB(), lifetime, FROM_DEGREES(angle), flags);
}

void GameScript::AddDynamicLight(GameScriptPosition pos, GameScriptColor color, int radius, int lifetime)
{
	TriggerDynamicLight(pos.x, pos.y, pos.z, radius, color.GetR(), color.GetG(), color.GetB());
}

void GameScript::AddBlood(GameScriptPosition pos, int num)
{
	TriggerBlood(pos.x, pos.y, pos.z, -1, num);
}

void GameScript::AddFireFlame(GameScriptPosition pos, int size)
{
	AddFire(pos.x, pos.y, pos.z, size, FindRoomNumber(pos), true);
}

void GameScript::Earthquake(int strength)
{
	Camera.bounce = -strength;
}

// Inventory
void GameScript::InventoryAdd(GAME_OBJECT_ID slot, sol::optional<int> count)
{
	PickedUpObject(slot, count.value_or(0));
}

void GameScript::InventoryRemove(GAME_OBJECT_ID slot, sol::optional<int> count)
{
	RemoveObjectFromInventory(static_cast<GAME_OBJECT_ID>(inventry_objects_list[slot].object_number), count.value_or(0));
}

int GameScript::InventoryGetCount(GAME_OBJECT_ID slot)
{
	return GetInventoryCount(slot);
}

void GameScript::InventorySetCount(GAME_OBJECT_ID slot, int count)
{
	// add the amount we'd need to add to get to count
	int currAmt = GetInventoryCount(slot);
	InventoryAdd(slot, count - currAmt);
}

void GameScript::InventoryCombine(int slot1, int slot2)
{
	
}

void GameScript::InventorySeparate(int slot)
{

}

// Misc
void GameScript::PrintString(std::string key, GameScriptPosition pos, GameScriptColor color, int lifetime, int flags)
{

}

int GameScript::FindRoomNumber(GameScriptPosition pos)
{
	return 0;
}

void GameScript::AssignItemsAndLara()
{
	m_lua->set("Level", m_locals);
	m_lua->set("Game", m_globals);
	m_lua->set("Lara", GameScriptItemInfo(Lara.itemNumber, false)); // do we need GetLara if we have this?
}

void GameScript::ResetVariables()
{
	(*m_lua)["Lara"] = NULL;
}

int GameScript::CalculateDistance(GameScriptPosition pos1, GameScriptPosition pos2)
{
	return sqrt(SQUARE(pos1.x - pos2.x) + SQUARE(pos1.y - pos2.y) + SQUARE(pos1.z - pos2.z));
}

int GameScript::CalculateHorizontalDistance(GameScriptPosition pos1, GameScriptPosition pos2)
{
	return sqrt(SQUARE(pos1.x - pos2.x) + SQUARE(pos1.z - pos2.z));
}

sol::object LuaVariables::GetVariable(std::string key)
{
	if (variables.find(key) == variables.end())
		return sol::lua_nil;
	return variables[key];
}

void LuaVariables::SetVariable(std::string key, sol::object value)
{
	switch (value.get_type())
	{
	case sol::type::lua_nil:
		variables.erase(key);
		break;
	case sol::type::boolean:
	case sol::type::number:
	case sol::type::string:
		variables[key] = value;
		break;
	default:
		if (WarningsAsErrors)
			throw std::runtime_error("unsupported variable type");
		break;
	}
}

void GameScript::ExecuteFunction(std::string const & name)
{
	sol::protected_function func = (*m_lua)[name.c_str()];
	auto r = func();
	if (WarningsAsErrors && !r.valid())
	{
		sol::error err = r;
		std::cerr << "An error occurred: " << err.what() << "\n";
		throw std::runtime_error(err.what());
	}
}

static void doCallback(sol::protected_function const & func) {
	auto r = func();
	if (WarningsAsErrors && !r.valid())
	{
		sol::error err = r;
		std::cerr << "An error occurred: " << err.what() << "\n";
		throw std::runtime_error(err.what());
	}
}

void GameScript::OnStart()
{
	if (m_onStart.valid())
		doCallback(m_onStart);
}

void GameScript::OnLoad()
{
	if (m_onLoad.valid())
		doCallback(m_onLoad);
}

void GameScript::OnControlPhase()
{
	if (m_onControlPhase.valid())
		doCallback(m_onControlPhase);
}

void GameScript::OnSave()
{
	if (m_onSave.valid())
		doCallback(m_onSave);
}

void GameScript::OnEnd()
{
	if (m_onEnd.valid())
		doCallback(m_onEnd);
}

void GameScript::InitCallbacks()
{
	auto assignCB = [this](sol::protected_function& func, char const* luaFunc) {
		func = (*m_lua)[luaFunc];
		if (WarningsAsErrors && !func.valid())
		{
			std::string err{ "Level's script file requires callback \"" };
			err += std::string{ luaFunc };
			err += "\"";
			throw std::runtime_error(err);
		}
	};
	assignCB(m_onStart, "OnStart");
	assignCB(m_onLoad, "OnLoad");
	assignCB(m_onControlPhase, "OnControlPhase");
	assignCB(m_onSave, "OnSave");
	assignCB(m_onEnd, "OnEnd");
}
