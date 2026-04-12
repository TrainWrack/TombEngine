#pragma once

#include "Game/itemdata/creature_info.h"
#include <unordered_map>
#include <string>

/// Constants for creature mood.
// To be used with @{Objects.Creature.GetMood} and @{Objects.Creature.SetMood} functions.
// @enum Objects.CreatureMood
// @pragma nostrip

namespace TEN::Scripting::Objects
{
	static const auto CREATURE_MOOD = std::unordered_map<std::string, MoodType>
	{
		/// Creature is not attacking or stalking any enemies and randomly roams around the area.
		// @mem BORED
		{"BORED", MoodType::Bored},

		/// Creature is searching for an enemy, but does not directly attack it yet.
		// @mem STALK
		{"STALK", MoodType::Stalk},

		/// Creature is attacking an enemy.
		// @mem ATTACK
		{"ATTACK", MoodType::Attack},

		/// Creature is escaping from the enemy and trying to find a safe place.
		// @mem ESCAPE
		{"ESCAPE", MoodType::Escape},
	};
}
