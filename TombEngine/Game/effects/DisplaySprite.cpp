#include "framework.h"
#include "Game/effects/DisplaySprite.h"

#include "Game/effects/effects.h"
#include "Game/Setup.h"
#include "Math/Math.h"
#include "Objects/objectslist.h"
#include "Renderer/Renderer.h"

using namespace TEN::Math;

namespace TEN::Effects::DisplaySprite
{
	std::vector<DisplaySprite> DisplaySprites = {};

	static bool g_hasActiveDisplayScissor = false;
	static TEN::Renderer::Structures::RendererRectangle g_activeDisplayScissorRect = {};

	void SetActiveDisplayScissor(const TEN::Renderer::Structures::RendererRectangle& rect)
	{
		g_hasActiveDisplayScissor = true;
		g_activeDisplayScissorRect = rect;
	}

	void ClearActiveDisplayScissor()
	{
		g_hasActiveDisplayScissor = false;
	}

	bool HasActiveDisplayScissor()
	{
		return g_hasActiveDisplayScissor;
	}

	const TEN::Renderer::Structures::RendererRectangle& GetActiveDisplayScissor()
	{
		return g_activeDisplayScissorRect;
	}

	void AddDisplaySprite(GAME_OBJECT_ID objectID, int spriteID, const Vector2& pos, short orient, const Vector2& scale, const Vector4& color,
						  int priority, DisplaySpriteAlignMode alignMode, DisplaySpriteScaleMode scaleMode, 
						  BlendMode blendMode, DisplaySpritePhase source)
	{
		auto displaySprite = DisplaySprite{};
		displaySprite.ObjectID = objectID;
		displaySprite.SpriteID = spriteID;
		displaySprite.Position = pos;
		displaySprite.Orientation = orient;
		displaySprite.Scale = scale;
		displaySprite.Color = color;
		displaySprite.Priority = priority;
		displaySprite.AlignMode = alignMode;
		displaySprite.ScaleMode = scaleMode;
		displaySprite.BlendMode = blendMode;
		displaySprite.Source = source;
		displaySprite.HasScissor = g_hasActiveDisplayScissor;
		displaySprite.ScissorRect = g_activeDisplayScissorRect;

		DisplaySprites.push_back(displaySprite);
	}

	void ClearAllDisplaySprites()
	{
		DisplaySprites.clear();
	}

	void ClearDrawPhaseDisplaySprites()
	{
		DisplaySprites.erase(
			std::remove_if(
				DisplaySprites.begin(), DisplaySprites.end(),
				[](const DisplaySprite& displaySprite)
				{
					return (displaySprite.Source == DisplaySpritePhase::Draw);
				}),
			DisplaySprites.end());
	}
}
