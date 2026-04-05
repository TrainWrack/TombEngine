#include "framework.h"
#include "Scripting/Internal/TEN/Objects/Creature/Creature.h"
#include "Scripting/Internal/TEN/Objects/Creature/CreatureStates.h"

#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Objects/Moveable/MoveableObject.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Specific/level.h"
#include <Game/misc.h>

namespace TEN::Scripting::Objects
{
	/// Represents the AI and behavior state of a creature in the game.
	//
	// @tenclass Objects.CreatureInfo
	// @pragma nostrip

	void ScriptCreatureInfo::Register(sol::table& parent)
	{
		using ctors = sol::constructors<
			ScriptCreatureInfo(const Moveable& mov)>;

		// Register type.
		parent.new_usertype<ScriptCreatureInfo>(ScriptReserved_CreatureInfo,
			ctors(), sol::call_constructor, ctors(),

			// Getters
			ScriptReserved_GetMood, &ScriptCreatureInfo::GetMood,
			ScriptReserved_GetCreatureTarget, &ScriptCreatureInfo::GetTarget,
			ScriptReserved_GetTargetPosition, &ScriptCreatureInfo::GetTargetPosition,
			ScriptReserved_SetCreatureTarget, &ScriptCreatureInfo::SetTarget,
			ScriptReserved_SetTargetPosition, &ScriptCreatureInfo::SetTargetPosition,
			ScriptReserved_ClearTarget, &ScriptCreatureInfo::ClearTarget,
			ScriptReserved_IsAlerted, &ScriptCreatureInfo::IsAlerted,
			ScriptReserved_IsFriendly, &ScriptCreatureInfo::IsFriendly,
			ScriptReserved_IsHurtByPlayer, &ScriptCreatureInfo::IsHurtByPlayer,
			ScriptReserved_IsPoisoned, &ScriptCreatureInfo::IsPoisoned,
			ScriptReserved_IsAtGoal, &ScriptCreatureInfo::IsAtGoal);
			
	}

	/// Create creature info for the provided moveable.
	// @function CreatureInfo
	// @tparam Objects.Moveable mov Moveable object to probe creature info. Must be an active enemy.
	// @treturn CreatureInfo Creature info for the moveable.
	ScriptCreatureInfo::ScriptCreatureInfo(const Moveable& mov)
	{
			auto* item = &g_Level.Items[mov.GetIndex()];

			if (!item->Active)
			{
				TENLog("Specified creature is not active in function TEN.Objects.CreatureInfo", LogLevel::Warning);
				m_Creature = nullptr;
				return;
			}

			if (item->IsCreature())
			m_Creature = GetCreatureInfo(item);
	}

	/// Gets the current mood of the creature.
	// @function GetMood
	// @treturn Objects.CreatureMood The current mood of the creature. If creature is not active, it returns Bored status.
	MoodType ScriptCreatureInfo::GetMood()
	{
		if (m_Creature != nullptr)
			return m_Creature->Mood;
		else
			return MoodType::Bored;
	}

	/// Gets the current target of the creature.
	// @function GetTarget
	// @treturn Objects.Moveable The moveable object representing the target, or null if no target is set.
	std::optional<Moveable> ScriptCreatureInfo::GetTarget()
	{
		if (m_Creature != nullptr)
		{
			auto enemy = m_Creature->Enemy;
			return Moveable(enemy->Index);
		}
		else 
			return std::nullopt;
	}

	/// Gets the current target position of the creature.
	// @function GetTargetPosition
	// @treturn Vec3 The position of the creature's target.
	Vec3 ScriptCreatureInfo::GetTargetPosition()
	{
		if (m_Creature != nullptr)
			return m_Creature->Target;
		else
			return Vec3(0, 0, 0);
	}

	/// Sets a new target for the creature.
	// @function SetTarget
	// @tparam Objects.Moveable mov The moveable object to set as the target.
	void ScriptCreatureInfo::SetTarget(Moveable& mov)
	{	
		if (m_Creature != nullptr)
		{
			auto* item = &g_Level.Items[mov.GetIndex()];
			m_Creature->Enemy = item;
		}
	}

	/// Sets the position of the creature's target.
	// @function SetTargetPosition
	// @tparam Vec3 position The target position to set.
	void ScriptCreatureInfo::SetTargetPosition(Vec3& position)
	{
		if (m_Creature != nullptr)
			m_Creature->Target = position.ToVector3i();
	}

	/// Clears the current target of the creature.
	// @function ClearTarget
	void ScriptCreatureInfo::ClearTarget()
	{
		if (m_Creature != nullptr)
			m_Creature->Enemy = nullptr;
	}

	/// Checks if the creature is in an alerted state.
	// @function IsAlerted
	// @treturn bool Creature alert state. __true: if the creature is alerted, false: not alerted__
	bool ScriptCreatureInfo::IsAlerted()
	{
		if (m_Creature != nullptr)
			return m_Creature->Alerted;
		else
			return false;
	}

	/// Checks if the creature is friendly. Only returns true for friendly creatures like monks (TR2) or troops (TR4).
	// @function IsFriendly
	// @treturn Creature friendly status. bool __true: if the creature is friendly, false: not friendly__
	bool ScriptCreatureInfo::IsFriendly()
	{
		if (m_Creature != nullptr)
			return m_Creature->Friendly;
		else
			return false;
	}

	/// Checks if the creature has been hurt by player.
	// @function IsHurtByPlayer
	// @treturn bool Creature hit status. __true: is hit, false: isn't hit__
	bool ScriptCreatureInfo::IsHurtByPlayer()
	{
		if (m_Creature != nullptr)
			return m_Creature->HurtByLara;
		else
			return false;
	}

	/// Checks if the creature is poisoned.
	// @function IsPoisoned
	// @treturn bool Creature poison status. __true: is poisoned, false: isn't poisoned__
	bool ScriptCreatureInfo::IsPoisoned()
	{
		if (m_Creature != nullptr)
			return m_Creature->Poisoned;
		else
			return false;
	}

	/// Checks if the creature has reached its goal.
	// @function IsAtGoal
	// @treturn bool Creature position status. __true: is at its goal, false: isn't at its goal__.
	bool ScriptCreatureInfo::IsAtGoal()
	{
		if (m_Creature != nullptr)
			return m_Creature->ReachedGoal;
		else
			return false;
	}
}
