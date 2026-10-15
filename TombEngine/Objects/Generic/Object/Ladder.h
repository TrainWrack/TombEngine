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

	// Test whether the player can keep climbing the ladder object they are mounted on.
	bool TestLadderClimb(const ItemInfo& playerItem, bool goingUp);
}

