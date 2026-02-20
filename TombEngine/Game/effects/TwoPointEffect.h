#pragma once

#include "Math/Math.h"
#include "Renderer/RendererEnums.h"

using namespace TEN::Math;

namespace TEN::Effects::TwoPointEffect
{
	struct TwoPointEffectData
	{
		// Core
		Vector3 Origin		 = Vector3::Zero;
		Vector3 Target		 = Vector3::Zero;
		Vector4 Color		 = Vector4::One;
		Vector4 ColorEnd	 = Vector4::One;
		float	Width		 = 8.0f;
		float	WidthEnd	 = 8.0f;
		float	Life		 = 0.0f; // Remaining life in game frames.
		float	LifeMax		 = 0.0f; // Max life in game frames.
		int		Segments	 = 16;
		float	Opacity		 = 1.0f;
		BlendMode Blend		 = BlendMode::AlphaBlend;

		// Shape & Physics
		float	Sag			   = 0.0f;
		Vector3 SagDirection   = Vector3::UnitY;
		float	Tension		   = 1.0f;
		float	Noise		   = 0.0f;
		float	NoiseFrequency = 1.0f;
		float	Twist		   = 0.0f;
		float	ConeAngle	   = 0.0f;

		// Animation
		float	Sway		   = 0.0f;
		float	SwaySpeed	   = 1.0f;
		Vector3 SwayAxis	   = Vector3::UnitX;
		float	Pulse		   = 0.0f;
		float	PulseSpeed	   = 1.0f;
		float	Flicker		   = 0.0f;
		float	FlickerSpeed   = 2.0f;
		float	ScrollSpeed	   = 0.0f;
		float	WaveAmplitude  = 0.0f;
		float	WaveFrequency  = 1.0f;
		float	WaveSpeed	   = 0.0f;

		// Glow
		bool	Glow		   = false;
		float	GlowIntensity  = 1.0f;
		float	GlowWidth	   = 2.0f;
		Vector4 GlowColor	   = Vector4::Zero; // Zero = use main color.

		// Segmentation & Detail
		bool	Segmented	   = false;
		float	SegmentSize	   = 16.0f;
		float	SegmentGap	   = 0.0f;
		bool	Dashed		   = false;
		float	DashLength	   = 16.0f;
		float	DashGap		   = 8.0f;
		float	DashOffset	   = 0.0f;

		// Runtime state
		float	TimeElapsed	   = 0.0f; // Accumulated time for animations.

		// Interpolation data (for high-framerate rendering).
		Vector3 PrevOrigin	   = Vector3::Zero;
		Vector3 PrevTarget	   = Vector3::Zero;
		float	PrevOpacity	   = 1.0f;
		float	PrevLife	   = 0.0f;

		void StoreInterpolationData()
		{
			PrevOrigin  = Origin;
			PrevTarget  = Target;
			PrevOpacity = Opacity;
			PrevLife    = Life;
		}
	};

	class TwoPointEffectController
	{
	private:
		static constexpr auto EFFECT_COUNT_MAX = 128;

		std::vector<TwoPointEffectData> _effects = {};

	public:
		// Getters

		const std::vector<TwoPointEffectData>& GetEffects() const;

		// Utilities

		void Spawn(const TwoPointEffectData& effect);
		void Update();
		void Clear();
	};

	extern TwoPointEffectController TwoPointEffects;
}
