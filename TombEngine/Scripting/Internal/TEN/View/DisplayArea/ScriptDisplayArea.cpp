#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayArea/ScriptDisplayArea.h"

#include "Game/effects/DisplaySprite.h"
#include "Renderer/Renderer.h"
#include "Renderer/Structures/RendererRectangle.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"

using namespace TEN::Effects::DisplaySprite;
using namespace TEN::Renderer::Structures;
using namespace TEN::Scripting::Types;
using TEN::Renderer::g_Renderer;

/// Represents a clipping area for display items.
//
// @tenclass View.DisplayArea
// @pragma nostrip

namespace TEN::Scripting::DisplayArea
{
	void ScriptDisplayArea::Register(sol::state& state, sol::table& parent)
	{
		using ctors = sol::constructors<
			ScriptDisplayArea(const Vec2&, const Vec2&),
			ScriptDisplayArea(const Vec2&, const Vec2&, sol::table)>;

		// Register type.
		parent.new_usertype<ScriptDisplayArea>(
			ScriptReserved_DisplayArea,
			ctors(),
			sol::call_constructor, ctors(),

		ScriptReserved_DisplayStringGetPosition, &ScriptDisplayArea::GetPosition,
		ScriptReserved_DisplayStringSetPosition, &ScriptDisplayArea::SetPosition,
		ScriptReserved_GetSize, &ScriptDisplayArea::GetSize,
		ScriptReserved_SetSize, &ScriptDisplayArea::SetSize,
		ScriptReserved_AddItem, &ScriptDisplayArea::AddItem,
		ScriptReserved_RemoveItem, &ScriptDisplayArea::RemoveItem,
		ScriptReserved_Clear, &ScriptDisplayArea::Clear,
		ScriptReserved_Debug, &ScriptDisplayArea::Debug,
		ScriptReserved_DisplaySpriteDraw, &ScriptDisplayArea::Draw);
	}

	/// Create a DisplayArea object.
	// @function DisplayArea
	// @tparam Vec2 pos Top-left position of the area in percent.
	// @tparam Vec2 size Width and height of the area in percent.
	// @tparam[opt] table items Sequence of items. Each entry is either a bare DisplayString or DisplaySprite,
	// or a table { item, { priority, alignMode, scaleMode, blendMode } }.
	// @treturn DisplayArea A new DisplayArea object.
	ScriptDisplayArea::ScriptDisplayArea(const Vec2& pos, const Vec2& size)
	{
		_position = pos;
		_size = size;
	}

	ScriptDisplayArea::ScriptDisplayArea(const Vec2& pos, const Vec2& size, sol::table items)
	{
		_position = pos;
		_size = size;

		for (auto& [key, val] : items)
		{
			// Entry is { item, { args } }.
			if (val.is<sol::table>())
			{
				auto entry = val.as<sol::table>();
				auto entryItem = entry.get<sol::optional<sol::object>>(1);
				auto entryArgs = entry.get<sol::optional<sol::table>>(2);

				if (entryItem.has_value())
					AddItem(entryItem.value(), entryArgs);
			}
			// Entry is a bare item.
			else
			{
				AddItem(val.as<sol::object>(), sol::nullopt);
			}
		}
	}

	/// Get the top-left position of the area in percent.
	// @function DisplayArea:GetPosition
	// @treturn Vec2 Top-left position in percent.
	Vec2 ScriptDisplayArea::GetPosition() const
	{
		return _position;
	}

	/// Get the size of the area in percent.
	// @function DisplayArea:GetSize
	// @treturn Vec2 Width and height in percent.
	Vec2 ScriptDisplayArea::GetSize() const
	{
		return _size;
	}

	/// Set the top-left position of the area in percent.
	// @function DisplayArea:SetPosition
	// @tparam Vec2 position New top-left position in percent.
	void ScriptDisplayArea::SetPosition(const Vec2& pos)
	{
		_position = pos;
	}

	/// Set the size of the area in percent.
	// @function DisplayArea:SetSize
	// @tparam Vec2 size New width and height in percent.
	void ScriptDisplayArea::SetSize(const Vec2& size)
	{
		_size = size;
	}

	/// Add a display item to the area.
	// Items can be View.DisplayString or View.DisplaySprite objects.
	// Arguments are forwarded to the item's Draw() method.
	// @function DisplayArea:AddItem
	// @tparam object item A DisplayString or DisplaySprite to clip within this area.
	// @tparam[opt] table args Draw arguments forwarded to the item, e.g. { priority, alignMode, scaleMode, blendMode }.
	void ScriptDisplayArea::AddItem(sol::object item, sol::optional<sol::table> args)
	{
		auto argsObj = args.has_value() ? sol::object(args.value()) : sol::object(sol::lua_nil);
		_items.push_back({ item, argsObj });
	}

	/// Remove a display item from the area.
	// @function DisplayArea:RemoveItem
	// @tparam object item The item to remove.
	void ScriptDisplayArea::RemoveItem(sol::object item)
	{
		for (auto it = _items.begin(); it != _items.end(); ++it)
		{
			if (it->first == item)
			{
				_items.erase(it);
				return;
			}
		}
	}

	/// Remove all display items from the area.
	// @function DisplayArea:Clear
	void ScriptDisplayArea::Clear()
	{
		_items.clear();
	}

	/// Draw all items in the area, clipped to the area bounds.
	// @function DisplayArea:Draw
	void ScriptDisplayArea::Draw()
	{
		if (_items.empty())
			return;

		// Convert percent to pixel coordinates.
		auto screenRes = g_Renderer.GetScreenResolution();
		float screenWidth = (float)screenRes.x;
		float screenHeight = (float)screenRes.y;

		int left   = (int)(_position.x * screenWidth / 100.0f);
		int top	   = (int)(_position.y * screenHeight / 100.0f);
		int right  = (int)((_position.x + _size.x) * screenWidth / 100.0f);
		int bottom = (int)((_position.y + _size.y) * screenHeight / 100.0f);

		auto scissorRect = RendererRectangle(left, top, right, bottom);

		// Activate scissor for all items queued during this scope.
		SetActiveDisplayScissor(scissorRect);

		for (auto& [item, args] : _items)
		{
			// Retrieve the Draw method via __index (works for both tables and userdata).
			auto* L = item.lua_state();
			item.push(L);                                           // stack: [obj]
			lua_getfield(L, -1, ScriptReserved_DisplaySpriteDraw);  // stack: [obj, func]

			if (lua_isnil(L, -1))
			{
				lua_pop(L, 2);
				continue;
			}

			// Anchor the function in the registry before clearing the stack.
			auto drawFunc = sol::protected_function(L, -1);
			lua_pop(L, 2);                                          // stack: []

			sol::protected_function_result result;

			if (args.is<sol::table>())
			{
				auto argsTable = args.as<sol::table>();
				auto argCount = (int)argsTable.size();

				std::vector<sol::object> argVec;
				argVec.reserve(argCount);
				for (int i = 1; i <= argCount; i++)
					argVec.push_back(argsTable.raw_get<sol::object>(i));

				result = drawFunc(item, sol::as_args(argVec));
			}
			else
			{
				result = drawFunc(item);
			}

			if (!result.valid())
			{
				sol::error err = result;
				TENLog(std::string("DisplayArea: Error drawing item: ") + err.what(), LogLevel::Warning);
			}
		}

		ClearActiveDisplayScissor();
	}

	/// Draw a debug overlay showing the area bounds for the current frame.
	// @function DisplayArea:Debug
	// @tparam[opt=Color(255, 0, 0, 128)] Color color Fill color of the debug overlay.
	void ScriptDisplayArea::Debug(sol::optional<ScriptColor> colorOpt)
	{
		auto color = colorOpt.value_or(ScriptColor(255, 0, 0, 128));

		auto screenRes = g_Renderer.GetScreenResolution();
		float screenWidth  = (float)screenRes.x;
		float screenHeight = (float)screenRes.y;

		int left   = (int)(_position.x * screenWidth  / 100.0f);
		int top    = (int)(_position.y * screenHeight / 100.0f);
		int right  = (int)((_position.x + _size.x) * screenWidth  / 100.0f);
		int bottom = (int)((_position.y + _size.y) * screenHeight / 100.0f);

		auto rect  = RendererRectangle(left, top, right, bottom);
		auto rgba  = Vector4(color.GetR(), color.GetG(), color.GetB(), color.GetA()) / (float)UCHAR_MAX;

		g_Renderer.AddDebugDisplayRect(rect, rgba);
	}
}
