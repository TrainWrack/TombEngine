#include "frameworkandsol.h"
#include "ObjectsHandler.h"

#include <collision/collide_item.h>
#include <collision/collide_room.h>
#include <control/control.h>

#include "ScriptInterfaceGame.h"

#if TEN_OPTIONAL_LUA
#include "ReservedScriptNames.h"
#include "Lara/lara.h"
#include "ObjectIDs.h"
#include "Camera/Camera.h"
#include "Sink/Sink.h"
#include "SoundSource/SoundSource.h"

/***
Scripts that will be run on game startup.
@tentable Objects 
@pragma nostrip
*/
#endif

ObjectsHandler::ObjectsHandler(sol::state* lua, sol::table & parent) :
	m_handler{ lua },
	m_table_objects(sol::table{m_handler.GetState()->lua_state(), sol::create})
{
#if TEN_OPTIONAL_LUA
	parent.set(ScriptReserved_Objects, m_table_objects);

	/***
	Get a moveable by its name.
	@function GetMoveableByName
	@tparam string name the unique name of the Moveable as set in, or generated by, Tomb Editor
	@treturn Moveable a non-owning Moveable referencing the item.
	*/
	m_table_objects.set_function(ScriptReserved_GetMoveableByName, &ObjectsHandler::GetByName<Moveable, ScriptReserved_Moveable>, this);

	/***
	Get a Static by its name.
	@function GetStaticByName
	@tparam string name the unique name of the mesh as set in, or generated by, Tomb Editor
	@treturn Static a non-owning Static referencing the mesh.
	*/
	m_table_objects.set_function(ScriptReserved_GetStaticByName, &ObjectsHandler::GetByName<Static, ScriptReserved_Static>, this);

	/***
	Get a Camera by its name.
	@function GetCameraByName
	@tparam string name the unique name of the camera as set in, or generated by, Tomb Editor
	@treturn Camera a non-owning Camera referencing the camera.
	*/
	m_table_objects.set_function(ScriptReserved_GetCameraByName, &ObjectsHandler::GetByName<Camera, ScriptReserved_Camera>, this);

	/***
	Get a Sink by its name.
	@function GetSinkByName
	@tparam string name the unique name of the sink as set in, or generated by, Tomb Editor
	@treturn Sink a non-owning Sink referencing the sink.
	*/
	m_table_objects.set_function(ScriptReserved_GetSinkByName, &ObjectsHandler::GetByName<Sink, ScriptReserved_Sink>, this);

	/***
	Get a SoundSource by its name.
	@function GetSoundSourceByName
	@tparam string name the unique name of the sound source as set in, or generated by, Tomb Editor
	@treturn SoundSource a non-owning SoundSource referencing the sound source.
	*/
	m_table_objects.set_function(ScriptReserved_GetSoundSourceByName, &ObjectsHandler::GetByName<SoundSource, ScriptReserved_SoundSource>, this);

	/***
	Get an AIObject by its name.
	@function GetAIObjectByName
	@tparam string name the unique name of the AIObject as set in, or generated by, Tomb Editor
	@treturn AIObject a non-owning SoundSource referencing the AI moveable.
	*/
	m_table_objects.set_function(ScriptReserved_GetAIObjectByName, &ObjectsHandler::GetByName<AIObject, ScriptReserved_AIObject>, this);


	Moveable::Register(m_table_objects);
	Moveable::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	Static::Register(m_table_objects);
	Static::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	Camera::Register(m_table_objects);
	Camera::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	Sink::Register(m_table_objects);
	Sink::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	AIObject::Register(m_table_objects);
	AIObject::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	SoundSource::Register(m_table_objects);
	SoundSource::SetNameCallbacks(
		[this](auto && ... param) { return AddName(std::forward<decltype(param)>(param)...); },
		[this](auto && ... param) { return RemoveName(std::forward<decltype(param)>(param)...); }
	);

	m_handler.MakeReadOnlyTable(m_table_objects, ScriptReserved_ObjID, kObjIDs);
#endif
}

void ObjectsHandler::TestCollidingObjects()
{
	// remove any items which can't collide
	for (const auto id : m_collidingItemsToRemove)
	{
		m_collidingItems.erase(id);
	}
	m_collidingItemsToRemove.clear();

	for (const auto idOne : m_collidingItems)
	{
		auto item = &g_Level.Items[idOne];
		GetCollidedObjects(item, 0, true, CollidedItems, nullptr, 0, true);
		size_t i = 0;
		while (CollidedItems[i])
		{
			short idTwo = GetIndexByName(CollidedItems[i]->luaName);
			g_GameScript->ExecuteFunction(item->luaCallbackOnCollidedWithObjectName, idOne, idTwo);
			++i;
		}

		if(TestItemRoomCollisionAABB(item))
		{
			//stub
		}

	}

}

//todo document "Lara" obj
void ObjectsHandler::AssignLara()
{
#if TEN_OPTIONAL_LUA
	m_table_objects.set("Lara", Moveable(Lara.itemNumber, false));
#endif
}


bool ObjectsHandler::NotifyKilled(ITEM_INFO* key)
{
#if TEN_OPTIONAL_LUA
	auto it = m_moveables.find(key);
	if (std::end(m_moveables) != it)
	{
		for (auto& m : m_moveables[key])
		{
			m->Invalidate();
		}
		return true;
	}
	return false;
#endif
}

bool ObjectsHandler::AddMoveableToMap(ITEM_INFO* key, Moveable* mov)
{
#if TEN_OPTIONAL_LUA
	std::unordered_set<Moveable*> movVec;
	movVec.insert(mov);
	auto it = m_moveables.find(key);
	if (std::end(m_moveables) == it)
	{
		return m_moveables.insert(std::pair{ key, movVec }).second;
	}
	else
	{
		m_moveables[key].insert(mov);
		return true;
	}
#endif
}

bool ObjectsHandler::RemoveMoveableFromMap(ITEM_INFO* key, Moveable* mov)
{
#if TEN_OPTIONAL_LUA
	//todo why is "lara" destroyed here???
	auto it = m_moveables.find(key);
	if (std::end(m_moveables) != it)
	{
		auto& set = m_moveables[key];
		bool erased = static_cast<bool>(set.erase(mov));
		if (erased && set.empty())
		{
			erased = erased && static_cast<bool>(m_moveables.erase(key));
		}
		return erased;
	}
	return false;
#endif
}


