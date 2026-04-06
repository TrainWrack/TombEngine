#pragma once

#include "Game/itemdata/creature_info.h"

#include "Scripting/Internal/TEN/Objects/Moveable/MoveableObject.h"
#include "Scripting/Internal/TEN\Types/Vec3/Vec3.h"
#include "Scripting/Internal/ScriptUtil.h"

namespace sol { class state; };

namespace TEN::Scripting::Objects
{
    class ScriptCreature
    {
    private:
		int _itemNumber = NO_VALUE;
		CreatureInfo* GetCreature() const;

    public:
		static void Register(sol::table& parent);
		static bool TestCreature(int itemNumber);

        // Constructors
		ScriptCreature() = default;
		ScriptCreature(const Moveable& mov);

		// Getters
		std::optional<MoodType> GetMood();
		std::optional<Moveable>	GetTarget();
		std::optional<Vec3> GetTargetPosition();
		std::optional<int>	GetLocationAI();
		std::optional<bool> GetAlerted();
		std::optional<bool> GetFriendly();
		std::optional<bool> GetHurtByPlayer();
		std::optional<bool> GetPoisoned();
		std::optional<bool> GetAtGoal();

		// Setters
		void SetMood(MoodType mood);
		void SetTarget(const TypeOrNil<Moveable*> moveable);
		void SetTargetPosition(const Vec3& position);
		void SetAlerted(bool enabled);
		void SetFriendly(bool enabled);
		void SetHurtByPlayer(bool enabled);
		void SetPoisoned(bool enabled);
		void SetAtGoal(bool enabled);
		void SetLocationAI(int value);

		// Inquirers
		bool GetValid();
		std::optional<bool> GetJumping();
		std::optional<bool> GetMonkeying();
    };
}
