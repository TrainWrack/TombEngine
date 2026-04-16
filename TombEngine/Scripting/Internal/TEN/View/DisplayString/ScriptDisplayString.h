#pragma once

#include "Scripting/Internal/TEN/Strings/DisplayString/DisplayString.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"

using namespace TEN::Scripting::Types;

namespace TEN::Scripting::DisplayString
{
	class ScriptDisplayString
	{
	public:
		static void Register(sol::state& state, sol::table& parent);

	private:
		// Members
		std::string _text		  = {};
		bool		_isTranslated = false;

		Vec2		_position = Vec2(0.0f, 0.0f);
		float		_rotation = 0.0f;
		Vec2		_scale	  = Vec2(100.0f, 100.0f);
		ScriptColor _color	  = ScriptColor(255, 255, 255, 255);
		Vec2		_area	  = Vec2(0.0f, 0.0f);
		FlagArray	_flags	  = {};

	public:
		// Constructors
		ScriptDisplayString(const std::string& text, const Vec2& pos, float rot, const Vec2& scale, const ScriptColor& color, bool isTranslated);
		ScriptDisplayString(const std::string& text, const Vec2& pos, float rot, const Vec2& scale, const ScriptColor& color);
		ScriptDisplayString(const std::string& text, const Vec2& pos, float rot, const Vec2& scale);
		ScriptDisplayString(const std::string& text, const Vec2& pos);

		// Getters
		std::string GetText() const;
		bool		GetTranslated() const;
		Vec2		GetPosition() const;
		float		GetRotation() const;
		Vec2		GetScale() const;
		ScriptColor GetColor() const;
		Vec2		GetArea() const;
		sol::table	GetFlags(sol::this_state state) const;

		// Setters
		void SetText(const std::string& text);
		void SetTranslated(bool isTranslated);
		void SetPosition(const Vec2& pos);
		void SetRotation(float rot);
		void SetScale(const Vec2& scale);
		void SetColor(const ScriptColor& color);
		void SetArea(const Vec2& area);
		void SetFlags(const sol::table& flags);

		// Utilities
		void Draw(sol::optional<int> priority, sol::optional<int> alignMode,
				  sol::optional<int> blendMode);
	};
}
