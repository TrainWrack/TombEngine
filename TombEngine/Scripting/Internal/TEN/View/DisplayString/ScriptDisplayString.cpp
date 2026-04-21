#include "framework.h"
#include "Scripting/Internal/TEN/View/DisplayString/ScriptDisplayString.h"

#include "Game/effects/DisplaySprite.h"
#include "Game/Setup.h"
#include "Renderer/Renderer.h"
#include "Renderer/RendererEnums.h"
#include "Scripting/Include/Flow/ScriptInterfaceFlowHandler.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"
#include "Scripting/Internal/TEN/View/DisplayAnchors/ScriptDisplayAnchors.h"

using namespace TEN::Effects::DisplaySprite;
using namespace TEN::Scripting::Types;
using TEN::Renderer::g_Renderer;

/// Represents a display string.
//
// @tenclass View.DisplayString
// @pragma nostrip

namespace TEN::Scripting::DisplayString
{
	// NOTE: Conversion from 100x100 percent screen space to internal 800x600.
	constexpr auto POS_CONVERSION_COEFF = Vector2(DISPLAY_SPACE_RES.x / 100, DISPLAY_SPACE_RES.y / 100);
	constexpr auto SCALE_CONVERSION_COEFF = 0.01f;

	static int FlagArrayToFlags(const FlagArray& flags)
	{
		int result = 0;

		if (flags[(int)DisplayStringOptions::Center])
			result |= (int)PrintStringFlags::Center;

		if (flags[(int)DisplayStringOptions::Right])
			result |= (int)PrintStringFlags::Right;

		if (flags[(int)DisplayStringOptions::Outline])
			result |= (int)PrintStringFlags::Outline;

		if (flags[(int)DisplayStringOptions::Blink])
			result |= (int)PrintStringFlags::Blink;

		if (flags[(int)DisplayStringOptions::VerticalCenter])
			result |= (int)PrintStringFlags::VerticalCenter;

		if (flags[(int)DisplayStringOptions::VerticalBottom])
			result |= (int)PrintStringFlags::VerticalBottom;

		return result;
	}

	void ScriptDisplayString::Register(sol::state& state, sol::table& parent)
	{
		using ctors = sol::constructors<
			ScriptDisplayString(const std::string&, const Vec2&, float, const Vec2&, const ScriptColor&, bool),
			ScriptDisplayString(const std::string&, const Vec2&, float, const Vec2&, const ScriptColor&),
			ScriptDisplayString(const std::string&, const Vec2&, float, const Vec2&),
			ScriptDisplayString(const std::string&, const Vec2&)>;

		// Register type.
		parent.new_usertype<ScriptDisplayString>(
			ScriptReserved_DisplayString,
			ctors(),
			sol::call_constructor, ctors(),

		ScriptReserved_GetText, &ScriptDisplayString::GetText,
		ScriptReserved_SetText, &ScriptDisplayString::SetText,
		ScriptReserved_GetTranslated, &ScriptDisplayString::GetTranslated,
		ScriptReserved_SetTranslated, &ScriptDisplayString::SetTranslated,
		ScriptReserved_DisplayStringGetPosition, &ScriptDisplayString::GetPosition,
		ScriptReserved_DisplayStringSetPosition, &ScriptDisplayString::SetPosition,
		ScriptReserved_DisplayStringGetRotation, &ScriptDisplayString::GetRotation,
		ScriptReserved_DisplayStringSetRotation, &ScriptDisplayString::SetRotation,
		ScriptReserved_DisplayStringGetScale, &ScriptDisplayString::GetScale,
		ScriptReserved_DisplayStringSetScale, &ScriptDisplayString::SetScale,
		ScriptReserved_DisplayStringGetColor, &ScriptDisplayString::GetColor,
		ScriptReserved_DisplayStringSetColor, &ScriptDisplayString::SetColor,
		ScriptReserved_GetArea, &ScriptDisplayString::GetArea,
		ScriptReserved_SetArea, &ScriptDisplayString::SetArea,
		ScriptReserved_GetFlags, &ScriptDisplayString::GetFlags,
		ScriptReserved_SetFlags, &ScriptDisplayString::SetFlags,
		ScriptReserved_DisplayStringGetAnchors, &ScriptDisplayString::GetAnchors,
		ScriptReserved_DisplaySpriteDraw, &ScriptDisplayString::Draw);
	}

	/// Create a DisplayString object.
	// @function DisplayString
	// @tparam string text Text to display, or a translation key if isTranslated is true.
	// @tparam Vec2 pos Display position in percent.
	// @tparam[opt=0] float rot Rotation in degrees.
	// @tparam[opt=Vec2(100, 100)] Vec2 scale Horizontal and vertical scale in percent.
	// @tparam[opt=Color(255, 255, 255)] Color color Color.
	// @tparam[opt=false] bool isTranslated Whether the text is a translation key.
	// @treturn DisplayString A new DisplayString object.
	ScriptDisplayString::ScriptDisplayString(const std::string& text, const Vec2& pos, float rot, const Vec2& scale, const ScriptColor& color, bool isTranslated)
	{
		_text = text;
		_position = pos;
		_rotation = rot;
		_scale = scale;
		_color = color;
		_isTranslated = isTranslated;
	}

	ScriptDisplayString::ScriptDisplayString(const std::string& text, const Vec2& pos, float rot, const Vec2& scale, const ScriptColor& color)
	{
		*this = ScriptDisplayString(text, pos, rot, scale, color, false);
	}

	ScriptDisplayString::ScriptDisplayString(const std::string& text, const Vec2& pos, float rot, const Vec2& scale)
	{
		*this = ScriptDisplayString(text, pos, rot, scale, ScriptColor(255, 255, 255, 255), false);
	}

	ScriptDisplayString::ScriptDisplayString(const std::string& text, const Vec2& pos)
	{
		*this = ScriptDisplayString(text, pos, 0.0f, Vec2(100.0f, 100.0f), ScriptColor(255, 255, 255, 255), false);
	}

	/// Get the text of the display string.
	// @function DisplayString:GetText
	// @treturn string Text or translation key.
	std::string ScriptDisplayString::GetText() const
	{
		return _text;
	}

	/// Get whether the text is a translation key.
	// @function DisplayString:GetTranslated
	// @treturn bool True if the text is a translation key.
	bool ScriptDisplayString::GetTranslated() const
	{
		return _isTranslated;
	}

	/// Get the display position in percent.
	// @function DisplayString:GetPosition
	// @treturn Vec2 Display position in percent.
	Vec2 ScriptDisplayString::GetPosition() const
	{
		return _position;
	}

	/// Get the rotation in degrees.
	// @function DisplayString:GetRotation
	// @treturn float Rotation in degrees.
	float ScriptDisplayString::GetRotation() const
	{
		return _rotation;
	}

	/// Get the scale in percent.
	// @function DisplayString:GetScale
	// @treturn Vec2 Horizontal and vertical scale in percent.
	Vec2 ScriptDisplayString::GetScale() const
	{
		return _scale;
	}

	/// Get the color.
	// @function DisplayString:GetColor
	// @treturn Color Color.
	ScriptColor ScriptDisplayString::GetColor() const
	{
		return _color;
	}

	/// Get the text wrapping area in percent.
	// Vec2(0, 0) means no wrapping.
	// @function DisplayString:GetArea
	// @treturn Vec2 Wrapping area in percent.
	Vec2 ScriptDisplayString::GetArea() const
	{
		return _area;
	}

	/// Get the display string option flags.
	// @function DisplayString:GetFlags
	// @treturn table Array of DisplayStringOption values.
	sol::table ScriptDisplayString::GetFlags(sol::this_state state) const
	{
		auto table = sol::state_view(state).create_table();
		for (int i = 0; i < (int)_flags.size(); i++)
		{
			if (_flags[i])
				table.add(i);
		}
		return table;
	}

	/// Set the text of the display string.
	// @function DisplayString:SetText
	// @tparam string text New text or translation key.
	void ScriptDisplayString::SetText(const std::string& text)
	{
		_text = text;
	}

	/// Set whether the text is a translation key.
	// @function DisplayString:SetTranslated
	// @tparam bool isTranslated True if the text is a translation key.
	void ScriptDisplayString::SetTranslated(bool isTranslated)
	{
		_isTranslated = isTranslated;
	}

	/// Set the display position in percent.
	// @function DisplayString:SetPosition
	// @tparam Vec2 position New display position in percent.
	void ScriptDisplayString::SetPosition(const Vec2& pos)
	{
		_position = pos;
	}

	/// Set the rotation in degrees.
	// @function DisplayString:SetRotation
	// @tparam float rotation New rotation in degrees.
	void ScriptDisplayString::SetRotation(float rot)
	{
		_rotation = rot;
	}

	/// Set the scale in percent.
	// @function DisplayString:SetScale
	// @tparam Vec2 scale New horizontal and vertical scale in percent.
	void ScriptDisplayString::SetScale(const Vec2& scale)
	{
		_scale = scale;
	}

	/// Set the color.
	// @function DisplayString:SetColor
	// @tparam Color color New color.
	void ScriptDisplayString::SetColor(const ScriptColor& color)
	{
		_color = color;
	}

	/// Set the text wrapping area in percent.
	// Vec2(0, 0) means no wrapping.
	// @function DisplayString:SetArea
	// @tparam Vec2 area New wrapping area in percent.
	void ScriptDisplayString::SetArea(const Vec2& area)
	{
		_area = area;
	}

	/// Set the display string option flags.
	// @function DisplayString:SetFlags
	// @tparam table flags Array of DisplayStringOption values.
	void ScriptDisplayString::SetFlags(const sol::table& flags)
	{
		_flags = {};
		for (const auto& val : flags)
		{
			auto i = val.second.as<size_t>();
			if (i < _flags.size())
				_flags[i] = true;
		}
	}

	/// Get the anchors of the display string.
	// Returns the nine anchor points of the display string bounding box in percent.
	// @function DisplayString:GetAnchors
	// @tparam[opt=View.AlignMode.Center] View.AlignMode alignMode Alignment mode.
	// @tparam[opt=View.ScaleMode.Fit] View.ScaleMode scaleMode Scaling mode.
	// @treturn View.DisplayAnchors An object containing the anchor points of the display string bounding box.
	ScriptDisplayAnchors ScriptDisplayString::GetAnchors(sol::optional<DisplaySpriteAlignMode> alignModeOpt, sol::optional<DisplaySpriteScaleMode> scaleModeOpt) const
	{
		constexpr auto DISPLAY_ASPECT = DISPLAY_SPACE_RES.x / DISPLAY_SPACE_RES.y;
		constexpr auto DEFAULT_ALIGN_MODE = DisplaySpriteAlignMode::Center;
		constexpr auto DEFAULT_SCALE_MODE = DisplaySpriteScaleMode::Fit;

		auto resolvedText = _isTranslated ? std::string(g_GameFlow->GetString(_text.c_str())) : _text;

		// Measure text in display space units (800x600).
		auto convertedScale = Vector2(_scale.x, _scale.y) * SCALE_CONVERSION_COEFF;
		auto textSize = g_Renderer.GetDisplayStringSize(resolvedText, convertedScale);

		// Text bounding box aspect ratio.
		float textAspect = (textSize.y > 0.0f) ? (textSize.x / textSize.y) : 1.0f;

		// Screen aspect data.
		auto screenRes = Vector2((float)g_Configuration.ScreenWidth, (float)g_Configuration.ScreenHeight);
		float screenAspect = screenRes.x / screenRes.y;
		float aspectCorrectionBase = screenAspect / DISPLAY_ASPECT;

		// Convert position and rotation.
		auto convertedPos = Vector2(_position.x, _position.y) * POS_CONVERSION_COEFF;
		short convertedRot = ANGLE(_rotation);

		// Get modes.
		auto alignMode = alignModeOpt.value_or(DEFAULT_ALIGN_MODE);
		auto scaleMode = scaleModeOpt.value_or(DEFAULT_SCALE_MODE);

		// Calculate layout using shared helper.
		auto layout = CalculateDisplaySpriteLayout(
			textAspect, convertedScale, convertedRot,
			alignMode, scaleMode, screenAspect, aspectCorrectionBase);

		// Calculate final position and size.
		auto position = convertedPos + layout.Offset;
		auto size = layout.HalfSize * 2.0f;

		// Build vertices centered around origin (top-left, top-right, bottom-right, bottom-left).
		std::array<Vector2, 4> vertices = {
			size / 2.0f,
			Vector2(-size.x,  size.y) / 2.0f,
			-size / 2.0f,
			Vector2(size.x, -size.y) / 2.0f
		};

		// Apply rotation + aspect correction + position offset.
		auto rotMatrix = Matrix::CreateRotationZ(TO_RAD(convertedRot + ANGLE(180.0f)));
		for (auto& vertex : vertices)
		{
			vertex = Vector2::Transform(vertex, rotMatrix);
			vertex *= layout.AspectCorrection;
			vertex += position;
		}

		// Scale to screen resolution.
		auto screenScale = screenRes / DISPLAY_SPACE_RES;
		for (auto& vertex : vertices)
		{
			vertex.x *= screenScale.x;
			vertex.y *= screenScale.y;
		}

		auto toPercent = [&screenRes](const Vector2& pos) -> Vec2
		{
			return Vec2(std::round((pos.x / screenRes.x) * 10000.0f) / 100.0f, std::round((pos.y / screenRes.y) * 10000.0f) / 100.0f);
		};

		// Calculate edge midpoints.
		auto center = (vertices[0] + vertices[2]) / 2.0f;
		auto centerTop = (vertices[0] + vertices[1]) / 2.0f;
		auto centerLeft = (vertices[0] + vertices[3]) / 2.0f;
		auto centerRight = (vertices[1] + vertices[2]) / 2.0f;
		auto centerBottom = (vertices[2] + vertices[3]) / 2.0f;

		// Populate and return anchors.
		ScriptDisplayAnchors anchors;
		anchors.TOP_LEFT = toPercent(vertices[0]);
		anchors.TOP_CENTER = toPercent(centerTop);
		anchors.TOP_RIGHT = toPercent(vertices[1]);
		anchors.CENTER_LEFT = toPercent(centerLeft);
		anchors.CENTER = toPercent(center);
		anchors.CENTER_RIGHT = toPercent(centerRight);
		anchors.BOTTOM_RIGHT = toPercent(vertices[2]);
		anchors.BOTTOM_CENTER = toPercent(centerBottom);
		anchors.BOTTOM_LEFT = toPercent(vertices[3]);

		return anchors;
	}

	/// Draw the display string in display space for the current frame.
	// @function DisplayString:Draw
	// @tparam[opt=0] int priority Draw priority. Can be thought of as a layer, with higher values having precedence.
	// @tparam[opt=View.AlignMode.CENTER] View.AlignMode alignMode Horizontal alignment mode. Overrides CENTER and RIGHT flags.
	// @tparam[opt=Effects.BlendID.ALPHABLEND] Effects.BlendID blendMode Blend mode.
	void ScriptDisplayString::Draw(sol::optional<int> priority, sol::optional<int> alignMode,
								   sol::optional<int> blendMode)
	{
		// Resolve text.
		auto resolvedText = _isTranslated ? std::string(g_GameFlow->GetString(_text.c_str())) : _text;

		if (resolvedText.empty())
			return;

		// Convert percent to display space.
		auto convertedPos = Vector2(_position.x, _position.y) * POS_CONVERSION_COEFF;
		auto convertedArea = Vector2(_area.x, _area.y) * POS_CONVERSION_COEFF;
		auto convertedScale = Vector2(_scale.x, _scale.y) * SCALE_CONVERSION_COEFF;
		auto convertedColor = Vector4(_color.GetR(), _color.GetG(), _color.GetB(), _color.GetA()) / (float)UCHAR_MAX;
		float convertedRotation = _rotation * (DirectX::XM_PI / 180.0f);

		// Build flags from FlagArray.
		int flags = FlagArrayToFlags(_flags);

		// Override alignment with alignMode if provided.
		if (alignMode.has_value())
		{
			flags &= ~((int)PrintStringFlags::Center | (int)PrintStringFlags::Right);

			switch (alignMode.value())
			{
			case (int)DisplaySpriteAlignMode::Center:
			case (int)DisplaySpriteAlignMode::CenterTop:
			case (int)DisplaySpriteAlignMode::CenterBottom:
				flags |= (int)PrintStringFlags::Center;
				break;

			case (int)DisplaySpriteAlignMode::CenterRight:
			case (int)DisplaySpriteAlignMode::TopRight:
			case (int)DisplaySpriteAlignMode::BottomRight:
				flags |= (int)PrintStringFlags::Right;
				break;
			}
		}

		g_Renderer.AddString(
			resolvedText, convertedPos, convertedPos, convertedArea,
			Color(convertedColor), convertedScale, convertedRotation, flags,
			priority.value_or(0),
			(BlendMode)blendMode.value_or((int)BlendMode::AlphaBlend));
	}
}
