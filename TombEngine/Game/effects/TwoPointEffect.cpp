#include "framework.h"
#include "Game/effects/TwoPointEffect.h"

#include "Specific/clock.h"

namespace TEN::Effects::TwoPointEffect
{
	TwoPointEffectController TwoPointEffects = {};

	const std::vector<TwoPointEffectData>& TwoPointEffectController::GetEffects() const
	{
		return _effects;
	}

	void TwoPointEffectController::Spawn(const TwoPointEffectData& effect)
	{
		if (_effects.size() >= EFFECT_COUNT_MAX)
			return;

		_effects.push_back(effect);

		// Initialize interpolation data for new effect.
		auto& newEffect = _effects.back();
		newEffect.PrevOrigin  = newEffect.Origin;
		newEffect.PrevTarget  = newEffect.Target;
		newEffect.PrevOpacity = newEffect.Opacity;
		newEffect.PrevLife    = newEffect.Life;
	}

	void TwoPointEffectController::Update()
	{
		for (auto& effect : _effects)
		{
			effect.StoreInterpolationData();

			// Decrement life (0 = infinite).
			if (effect.LifeMax > 0.0f)
			{
				effect.Life -= 1.0f;

				// Fade opacity proportional to remaining life.
				if (effect.LifeMax > 0.0f)
					effect.Opacity = std::max(0.0f, effect.Life / effect.LifeMax);
			}

			// Advance animation time.
			effect.TimeElapsed += DELTA_TIME;
		}

		// Remove expired effects.
		_effects.erase(
			std::remove_if(_effects.begin(), _effects.end(),
				[](const TwoPointEffectData& e) { return e.LifeMax > 0.0f && e.Life <= 0.0f; }),
			_effects.end());
	}

	void TwoPointEffectController::Clear()
	{
		_effects.clear();
	}
}
