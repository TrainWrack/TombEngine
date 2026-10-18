#pragma once
#include "framework.h"
#include "Math/Math.h"


using namespace TEN::Math;

struct CollisionInfo;
struct ItemInfo;

namespace TEN::Entities::Generic
{
	class LadderObject
	{
	private:
		int _baseItemNumber = NO_VALUE;	// Lowest ladder item of the stack.
		int _topY = 0;					// Stack top, relative to the base item position.
		int _bottomY = 0;				// Stack bottom, relative to the base item position.
		bool _isDoubleSided = false;

	public:
		// Constructors
		LadderObject(int itemNumber);

		// Inquirers
		int GetBaseItemNumber() const;
		bool IsDoubleSided() const;
		int GetHeight() const;

		// Positions resolve from the live base item position, so moving the stack moves the ladder.
		Vector3i GetBasePosition() const;
		Vector3i GetTopPosition() const;

		// Resolves a world Y position to the rung the player should snap to. Never returns a height above
		// the point where the top dismount can fire.
		int GetAttachmentHeight(int positionY) const;

		// Test whether a world Y position lies between the top and the bottom of the ladder stack.
		bool IsHeightWithin(int positionY) const;
	};

	LadderObject& GetLadderObject(const ItemInfo& item);

	void InitializeLadder(short itemNumber);
	void CollideLadder(short itemNumber, ItemInfo* playerItem, CollisionInfo* coll);
}

