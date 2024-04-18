#pragma once
#include "Objects\objectslist.h"
#include <SimpleMath.h>

enum class BlendMode;
struct ItemInfo;

namespace TEN::Effects
{
	using namespace DirectX::SimpleMath;

	struct SimpleParticle
	{
		Vector3 worldPosition;
		float size;
		float age;
		float ageRate;
		float life;
		int room;
		unsigned int sprite;
		GAME_OBJECT_ID sequence;
		bool active;
		BlendMode blendMode;

		Vector3 oldWorldPosition;
		float oldSize;

		void StoreInterpolationData()
		{
			oldWorldPosition = worldPosition;
			oldSize = size;
		}
	};
	extern std::array<SimpleParticle, 15> simpleParticles;

	SimpleParticle& GetFreeSimpleParticle();
	void TriggerSnowmobileSnow(ItemInfo* snowMobile);
	void TriggerSpeedboatFoam(ItemInfo* boat, Vector3 offset);
	void UpdateSimpleParticles();
}
