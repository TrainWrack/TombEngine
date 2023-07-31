#include "framework.h"
#include "Objects/Generic/Object/Pushables/PushableObject_BridgeCol.h"

#include "Game/collision/floordata.h"
#include "Objects/Generic/Object/Pushables/PushableObject.h"
#include "Specific/level.h"

using namespace TEN::Collision::Floordata;

namespace TEN::Entities::Generic
{

	void InitializeClimbablePushable(int itemNumber)
	{
		//TEN::Collision::Floordata::AddBridge(itemNumber);
	}


	void ActivateClimbablePushableCollider(int itemNumber)
	{
		AddBridge(itemNumber);
	}

	void DeactivateClimbablePushableCollider(int itemNumber)
	{
		RemoveBridge(itemNumber);
	}

	void RefreshClimbablePushableCollider(int itemNumber)
	{
		UpdateBridgeItem(itemNumber);
	}

	std::optional<int> ClimbablePushableFloor(int itemNumber, int x, int y, int z)
	{
		auto& pushableItem = g_Level.Items[itemNumber];
		auto& pushable = GetPushableInfo(pushableItem);

		auto boxHeight = GetBridgeItemIntersect(itemNumber, x, y, z, false);

		if (pushableItem.Status != ITEM_INVISIBLE && pushable.UsesRoomCollision && boxHeight.has_value())
		{
			int height = pushableItem.Pose.Position.y - GetPushableHeight(pushableItem);
			return std::optional{ height };
		}

		return std::nullopt;
	}

	std::optional<int> ClimbablePushableCeiling(int itemNumber, int x, int y, int z)
	{
		auto& pushableItem = g_Level.Items[itemNumber];
		auto& pushable = GetPushableInfo(pushableItem);

		auto boxHeight = GetBridgeItemIntersect(itemNumber, x, y, z, true);

		if (pushableItem.Status != ITEM_INVISIBLE && pushable.UsesRoomCollision && boxHeight.has_value())
			return std::optional{ pushableItem.Pose.Position.y };

		return std::nullopt;
	}

	int ClimbablePushableFloorBorder(int itemNumber)
	{
		auto& pushableItem = g_Level.Items[itemNumber];

		auto height = pushableItem.Pose.Position.y - GetPushableHeight(pushableItem);
		return height;
	}

	int ClimbablePushableCeilingBorder(int itemNumber)
	{
		auto& pushableItem = g_Level.Items[itemNumber];

		return pushableItem.Pose.Position.y;
	}
}
