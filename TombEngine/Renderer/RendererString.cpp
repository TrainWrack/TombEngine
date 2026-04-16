#include "framework.h"
#include "Renderer/Renderer.h"

#include <algorithm>

#include "Game/effects/DisplaySprite.h"
#include "Scripting/Include/Flow/ScriptInterfaceFlowHandler.h"
#include "Specific/trutils.h"

using namespace TEN::Effects::DisplaySprite;

namespace TEN::Renderer
{
	void Renderer::AddDebugString(const std::string& string, const Vector2& pos, const Color& color, float scale, RendererDebugPage page)
	{
		constexpr auto FLAGS = (int)PrintStringFlags::Outline | (int)PrintStringFlags::Center;

		if (_isLocked)
			return;

		if (!DebugMode || (_debugPage != page && page != RendererDebugPage::None))
			return;

		AddString(string, pos, color, scale, FLAGS);
	}

	void Renderer::AddString(int x, int y, const std::string& string, D3DCOLOR color, int flags)
	{
		AddString(string, Vector2(x, y), Color(color), 1.0f, flags);
	}

	Vector2 Renderer::GetDisplayStringSize(const std::string& text, const Vector2& scale) const
	{
		if (text.empty() || _gameFont == nullptr)
			return Vector2::Zero;

		auto screenRes = GetScreenResolution();
		auto factor = Vector2((float)screenRes.x / DISPLAY_SPACE_RES.x, (float)screenRes.y / DISPLAY_SPACE_RES.y);
		float uiScale = (screenRes.x > screenRes.y) ? factor.y : factor.x;
		float fontSpacing = _gameFont->GetLineSpacing();
		float fontScale = REFERENCE_FONT_SIZE / fontSpacing;
		auto stringScale = Vector2(uiScale * fontScale) * scale;
		float baseScale = stringScale.y;

		auto wtext = TEN::Utils::ToWString(text);
		auto measured = Vector2(_gameFont->MeasureString(wtext.c_str())) * baseScale;

		// Convert pixel size back to display space (800x600 units).
		return Vector2(measured.x / factor.x, measured.y / factor.y);
	}

	void Renderer::AddString(const std::string& string, const Vector2& pos, const Color& color, float scale, int flags)
	{
		AddString(string, pos, Vector2::Zero, Color(color), scale, flags);
	}

	void Renderer::AddString(const std::string& string, const Vector2& pos, const Vector2& area, const Color& color, float scale, int flags)
	{
		AddString(string, pos, pos, area, color, scale, flags);
	}

	void Renderer::AddString(const std::string& string, const Vector2& pos, const Vector2& prevPos, const Vector2& area,
							const Color& color, const Vector2& scale, float rotation, int flags,
							int priority, BlendMode blendMode)
	{
		AddStringInternal(string, pos, prevPos, area, color, scale, rotation, flags, priority, blendMode);
	}

	void Renderer::AddString(const std::string& string, const Vector2& pos, const Vector2& prevPos, const Vector2& area, const Color& color, float scale, int flags)
	{
		AddStringInternal(string, pos, prevPos, area, color, Vector2(scale), 0.0f, flags, 0, BlendMode::AlphaBlend);
	}

	void Renderer::AddStringInternal(const std::string& string, const Vector2& pos, const Vector2& prevPos, const Vector2& area,
									 const Color& color, const Vector2& scale, float rotation, int flags,
									 int priority, BlendMode blendMode)
	{
		if (_isLocked)
			return;

		if (string.empty())
			return;

		try
		{
			auto screenRes = GetScreenResolution();
			auto factor = Vector2(screenRes.x / DISPLAY_SPACE_RES.x, screenRes.y / DISPLAY_SPACE_RES.y);
			float uiScale = (screenRes.x > screenRes.y) ? factor.y : factor.x;
			float fontSpacing = _gameFont->GetLineSpacing();
			float fontScale = REFERENCE_FONT_SIZE / fontSpacing;
			auto stringScale = Vector2(uiScale * fontScale) * scale;
			float baseScale = stringScale.y;
			float spaceWidth = Vector3(_gameFont->MeasureString(L" ")).x * baseScale;

			std::vector<std::wstring> stringLines;

			if (area.x > 0)
			{
				// Split the string into native lines first.
				auto inputLines = SplitString(TEN::Utils::ToWString(string));

				for (const auto& inputLine : inputLines)
				{
					if (inputLine.empty())
					{
						// Preserve empty lines.
						stringLines.push_back(L"");
						continue;
					}

					auto words = SplitWords(inputLine);
					std::wstring currentLine;
					float currentLineWidth = 0.0f;

					for (const auto& word : words)
					{
						float wordWidth = Vector3(_gameFont->MeasureString(word.c_str())).x * baseScale;

						if (!currentLine.empty() && (currentLineWidth + wordWidth + spaceWidth > area.x * factor.x))
						{
							stringLines.push_back(currentLine);
							currentLine.clear();
							currentLineWidth = 0.0f;
						}

						if (!currentLine.empty())
						{
							currentLine += L" ";
							currentLineWidth += spaceWidth;
						}

						currentLine += word;
						currentLineWidth += wordWidth;
					}

					if (!currentLine.empty())
						stringLines.push_back(currentLine);
				}
			}
			else
			{
				stringLines = SplitString(TEN::Utils::ToWString(string));
			}

			// Calculate total height for vertical centering.
			float totalHeight = 0.0f;
			for (const auto& line : stringLines)
			{
				if (line.empty())
					totalHeight += fontSpacing * baseScale;
				else
					totalHeight += Vector2(_gameFont->MeasureString(line.c_str())).y * baseScale;
			}

			// Calculate maximum textbox height.
			float maxHeight = (area.y > 0.0f) ? area.y * factor.y : 0.0f;
			if (maxHeight > 0.0f && totalHeight > maxHeight)
				totalHeight = maxHeight;

			// Compute vertical offset based on alignment flags.
			float yBase = pos.y * uiScale;
			float yBasePrev = prevPos.y * uiScale;

			if (flags & (int)PrintStringFlags::VerticalBottom)
			{
				yBase -= totalHeight;
				yBasePrev -= totalHeight;
			}
			else if (flags & (int)PrintStringFlags::VerticalCenter)
			{
				yBase -= totalHeight / 2.0f;
				yBasePrev -= totalHeight / 2.0f;
			}

			float yOffset = 0.0f;
			for (const auto& line : stringLines)
			{
				// Prepare structure for renderer.
				RendererStringToDraw rString;
				rString.String = line;
				rString.Flags = flags;
				rString.Position = Vector2::Zero;
				rString.Color = color;
				rString.Scale = stringScale;
				rString.Rotation = rotation;
				rString.Priority = priority;
				rString.Blend = blendMode;
				rString.HasScissor = HasActiveDisplayScissor();
				if (rString.HasScissor)
					rString.ScissorRect = GetActiveDisplayScissor();

				// Measure string.
				auto stringSize = line.empty() ? Vector2(0, fontSpacing * baseScale) : Vector2(_gameFont->MeasureString(line.c_str())) * baseScale;

				// If height clipping enabled, stop drawing when exceeding maxHeight.
				if (maxHeight > 0.0f && (yOffset + stringSize.y) > maxHeight)
					break;

				// X position.
				if (flags & (int)PrintStringFlags::Center)
				{
					rString.Position.x = (pos.x * factor.x) - (stringSize.x / 2.0f);
					rString.PrevPosition.x = (prevPos.x * factor.x) - (stringSize.x / 2.0f);
				}
				else if (flags & (int)PrintStringFlags::Right)
				{
					rString.Position.x = (pos.x * factor.x) - stringSize.x;
					rString.PrevPosition.x = (prevPos.x * factor.x) - stringSize.x;
				}
				else
				{
					// Calculate indentation to account for string scaling.
					auto indent = line.empty() ? 0 : _gameFont->FindGlyph(line.at(0))->XAdvance * baseScale;

					rString.Position.x = pos.x * factor.x + indent;
					rString.PrevPosition.x = prevPos.x * factor.x + indent;
				}

				// Y position.
				rString.Position.y = yBase + yOffset;
				rString.PrevPosition.y = yBasePrev + yOffset;

				// Blink the string, if flag is set.
				if (flags & (int)PrintStringFlags::Blink)
					rString.Color *= _blinkColorValue;

				// Advance vertical offset and add current substring.
				yOffset += stringSize.y;
				_stringsToDraw.push_back(rString);
			}
		}
		catch (std::exception& ex)
		{
			TENLog(std::string("Unable to process string: '") + string + "'. Exception: " + std::string(ex.what()), LogLevel::Error);
		}
	}

	void Renderer::DrawAllStrings()
	{
		if (_stringsToDraw.empty())
			return;

		// Sort by priority (lower priority draws first, i.e. behind higher).
		std::stable_sort(_stringsToDraw.begin(), _stringsToDraw.end(),
			[](const auto& a, const auto& b) { return a.Priority < b.Priority; });

		float shadowOffset = 1.5f / (REFERENCE_FONT_SIZE / _gameFont->GetLineSpacing());
		auto shadowColor = (Vector4)g_GameFlow->GetSettings()->UI.ShadowTextColor;

		ResetScissor();
		_spriteBatch->Begin(SpriteSortMode_Deferred, nullptr, nullptr, nullptr, _cullNoneRasterizerState.Get());

		auto currentBlend = BlendMode::AlphaBlend;
		SetBlendMode(currentBlend);

		bool currentHasScissor = false;
		auto currentScissor = RendererRectangle{};

		for (const auto& rString : _stringsToDraw)
		{
			// Switch blend mode per string if needed.
			if (rString.Blend != currentBlend)
			{
				_spriteBatch->End();
				currentBlend = rString.Blend;
				SetBlendMode(currentBlend);
				_spriteBatch->Begin(SpriteSortMode_Deferred, nullptr, nullptr, nullptr, _cullNoneRasterizerState.Get());
			}

			// Handle scissor rect changes.
			bool scissorChanged = (rString.HasScissor != currentHasScissor) ||
								  (rString.HasScissor &&
								   (rString.ScissorRect.Left != currentScissor.Left ||
									rString.ScissorRect.Top != currentScissor.Top ||
									rString.ScissorRect.Right != currentScissor.Right ||
									rString.ScissorRect.Bottom != currentScissor.Bottom));

			if (scissorChanged)
			{
				_spriteBatch->End();

				if (rString.HasScissor)
					SetScissor(rString.ScissorRect);
				else
					ResetScissor();

				currentHasScissor = rString.HasScissor;
				currentScissor = rString.ScissorRect;
				_spriteBatch->Begin(SpriteSortMode_Deferred, nullptr, nullptr, nullptr, _cullNoneRasterizerState.Get());
			}

			auto drawPos = Vector2::Lerp(rString.PrevPosition, rString.Position, GetInterpolationFactor());

			// Draw shadow.
			if (rString.Flags & (int)PrintStringFlags::Outline)
			{
				auto shadowPos = Vector2(drawPos.x + shadowOffset * rString.Scale.y, drawPos.y + shadowOffset * rString.Scale.y);

				_gameFont->DrawString(
					_spriteBatch.get(), rString.String.c_str(),
					shadowPos,
					(shadowColor * rString.Color.w * shadowColor.w) * ScreenFadeCurrent,
					rString.Rotation, Vector2::Zero, rString.Scale);
			}

			// Draw string.
			_gameFont->DrawString(
				_spriteBatch.get(), rString.String.c_str(),
				drawPos,
				(rString.Color * rString.Color.w) * ScreenFadeCurrent,
				rString.Rotation, Vector2::Zero, rString.Scale);
		}

		_spriteBatch->End();

		// Reset scissor if it was active.
		if (currentHasScissor)
			ResetScissor();
	}
}
