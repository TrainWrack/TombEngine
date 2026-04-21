#pragma once
#include <SimpleMath.h>

#include "Renderer/RendererEnums.h"
#include "Renderer/Structures/RendererRectangle.h"

namespace TEN::Renderer::Structures
{
	using namespace DirectX::SimpleMath;

	struct RendererStringToDraw
	{
		Vector2 Position;
		Vector2 PrevPosition;
		int Flags;
		std::wstring String;
		Vector4 Color;
		Vector2 Scale;
		float Rotation	  = 0.0f;
		int Priority	  = 0;
		BlendMode Blend	  = BlendMode::AlphaBlend;

		bool HasScissor				 = false;
		RendererRectangle ScissorRect = {};
	};
}
