#pragma once
#include "framework.h"
#include "Math/Math.h"


using namespace TEN::Math;

struct CollisionInfo;
struct ItemInfo;

namespace TEN::Entities::Generic
{
	void InitializeLadder(short itemNumber);
	void CollideLadder(short itemNumber, ItemInfo* playerItem, CollisionInfo* coll);
}

