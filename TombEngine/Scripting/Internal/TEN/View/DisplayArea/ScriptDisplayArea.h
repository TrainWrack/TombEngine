#pragma once

#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"

using namespace TEN::Scripting::Types;

namespace TEN::Scripting::DisplayArea
{
	class ScriptDisplayArea
	{
	public:
		static void Register(sol::state& state, sol::table& parent);

	private:
		// Members
		Vec2 _position = Vec2(0.0f, 0.0f);
		Vec2 _size	   = Vec2(100.0f, 100.0f);

		// Each entry: { drawable object, optional args table }.
		std::vector<std::pair<sol::object, sol::object>> _items = {};

	public:
		// Constructors
		ScriptDisplayArea(const Vec2& pos, const Vec2& size);
		ScriptDisplayArea(const Vec2& pos, const Vec2& size, sol::table items);

		// Getters
		Vec2 GetPosition() const;
		Vec2 GetSize() const;

		// Setters
		void SetPosition(const Vec2& pos);
		void SetSize(const Vec2& size);

		// Item management
		void AddItem(sol::object item, sol::optional<sol::table> args);
		void RemoveItem(sol::object item);
		void Clear();

		// Utilities
		void Draw();
	};
}
