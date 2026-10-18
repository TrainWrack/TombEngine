#include "framework.h"
#include "Objects/Generic/Object/Ladder.h"

#include "Game/collision/collide_item.h"
#include "Game/collision/collide_room.h"
#include "Game/collision/Interaction.h"
#include "Game/collision/sphere.h"
#include "Game/control/box.h"
#include "Game/control/control.h"
#include "Game/control/lot.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Game/Lara/lara_helpers.h"
#include "Game/Lara/lara_struct.h"
#include "Game/Lara/lara_tests.h"
#include "Math/Math.h"
#include "Objects/game_object_ids.h"
#include "Renderer/Renderer.h"
#include "Specific/Input/Input.h"
#include "Specific/level.h"
#include "Specific/trutils.h"

using namespace TEN::Collision::Interaction;
using namespace TEN::Collision::Sphere;
using namespace TEN::Input;
using namespace TEN::Math;
using namespace TEN::Renderer;
using namespace TEN::Utils;

// NOTES:
// TriggerFlags:
//	1: is double-sided.

namespace TEN::Entities::Generic
{
	constexpr auto LADDER_STEP_HEIGHT = CLICK(0.5f);
	constexpr auto PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD = LARA_LEAN_MAX;

	enum class LadderMountType
	{
		None,
		TopFront,
		TopBack,
		Front,
		Back,
		Left,
		Right,
		JumpUp,
		JumpReach
	};

	const auto LadderMountedPlayerStates = std::vector<int>
	{
		LS_LADDERX_IDLE,
		LS_LADDERX_UP,
		LS_LADDERX_DOWN
	};
	const auto LadderGroundedMountPlayerStates = std::vector<int>
	{
		LS_IDLE,
		LS_TURN_LEFT_SLOW,
		LS_TURN_RIGHT_SLOW,
		LS_TURN_LEFT_FAST,
		LS_TURN_RIGHT_FAST,
		LS_WALK_FORWARD,
		LS_RUN_FORWARD
	};
	const auto LadderAirborneMountPlayerStates = std::vector<int>
	{
		LS_REACH,
		LS_JUMP_UP
	};

	const auto LadderMountedOffset2D = Vector3i(0, 0, -LARA_RADIUS * 1.5f);
	const auto LadderMountedOffsetTopFront2D = Vector3i(0, 0, 51.0f);//54
	const auto LadderMountedOffsetTopBack2D = Vector3i(0, 0, 79.0f);//82
	const auto LadderInteractBounds2D = GameBoundingBox(
		-BLOCK(0.25f), BLOCK(0.25f),
		0, 0,
		-BLOCK(3 / 8.0f), BLOCK(3 / 8.0f));
	const auto LadderInteractBox2D = LadderInteractBounds2D.ToBoundingOrientedBox(Pose::Zero);

	// Side mount interaction box. Sits beside the ladder (local +X) so a player standing
	// against the ladder's edge is picked up instead of one standing in front of it.
	const auto LadderInteractRightBounds2D = GameBoundingBox(
		BLOCK(0.25f), BLOCK(0.75f),
		0, 0,
		-BLOCK(3 / 8.0f), BLOCK(3 / 8.0f));
	const auto LadderInteractRightBox2D = LadderInteractRightBounds2D.ToBoundingOrientedBox(Pose::Zero);

	// Side mount interaction box. Sits beside the ladder (local -X).
	const auto LadderInteractLeftBounds2D = GameBoundingBox(
		-BLOCK(0.75f), -BLOCK(0.25f),
		0, 0,
		-BLOCK(3 / 8.0f), BLOCK(3 / 8.0f));
	const auto LadderInteractLeftBox2D = LadderInteractLeftBounds2D.ToBoundingOrientedBox(Pose::Zero);

	const auto LadderMountTopFrontBasis = InteractionBasis(
		LadderMountedOffsetTopFront2D,
		EulerAngles(0, ANGLE(180.0f), 0),
		LadderInteractBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(180.0f) - LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(180.0f) + LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	const auto LadderMountTopBackBasis = InteractionBasis(
		LadderMountedOffsetTopBack2D,
		LadderInteractBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, -LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	const auto LadderMountFrontBasis = InteractionBasis(
		LadderMountedOffset2D,
		LadderInteractBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, -LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	const auto LadderMountBackBasis = InteractionBasis(
		LadderMountedOffset2D,
		EulerAngles(0, ANGLE(180.0f), 0),
		LadderInteractBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(180.0f) - LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(180.0f) + LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	const auto LadderMountLeftBasis = InteractionBasis(
		LadderMountedOffset2D + Vector3i(-BLOCK(0.25f), 0, 0),
		EulerAngles(0, ANGLE(90.0f), 0),
		LadderInteractLeftBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(90.0f) - LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(90.0f) + LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	const auto LadderMountRightBasis = InteractionBasis(
		LadderMountedOffset2D + Vector3i(BLOCK(0.25f), 0, 0),
		EulerAngles(0, ANGLE(-90.0f), 0),
		LadderInteractRightBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(-90.0f) - LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(-90.0f) + LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	LadderObject::LadderObject(int itemNumber)
	{
		constexpr auto ALIGN_XZ_TOLERANCE = BLOCK(0.25f);
		constexpr auto ALIGN_YAW_TOLERANCE = ANGLE(5.0f);

		auto& ladderItem = g_Level.Items[itemNumber];
		auto bounds = GameBoundingBox(&ladderItem);

		int topY = bounds.Y1;
		int bottomY = bounds.Y2;
		short lowestItemNumber = itemNumber;

		// The stack is probed from the item list directly: room item lists are still being populated while
		// items are initialized, so a collision query would only see part of the stack.
		for (int i = 0; i < g_Level.NumItems; i++)
		{
			auto& item = g_Level.Items[i];

			if (item.ObjectNumber != ID_LADDER_ONE_SIDED &&
				item.ObjectNumber != ID_LADDER_DOUBLE_SIDED)
			{
				continue;
			}

			// Only merge ladders that are horizontally aligned and share the same yaw.
			if (abs(item.Pose.Position.x - ladderItem.Pose.Position.x) > ALIGN_XZ_TOLERANCE ||
				abs(item.Pose.Position.z - ladderItem.Pose.Position.z) > ALIGN_XZ_TOLERANCE ||
				abs(Geometry::GetShortestAngle(item.Pose.Orientation.y, ladderItem.Pose.Orientation.y)) > ALIGN_YAW_TOLERANCE)
			{
				continue;
			}

			// Merge the neighbour's vertical extents into this ladder's local space.
			int relY = item.Pose.Position.y - ladderItem.Pose.Position.y;
			auto itemBounds = GameBoundingBox(&item);
			topY = std::min(topY, relY + itemBounds.Y1);

			if ((relY + itemBounds.Y2) > bottomY)
			{
				bottomY = relY + itemBounds.Y2;
				lowestItemNumber = item.Index;
			}
		}

		// Rebase the extents on the lowest ladder item of the stack.
		int baseShift = g_Level.Items[lowestItemNumber].Pose.Position.y - ladderItem.Pose.Position.y;

		_baseItemNumber = lowestItemNumber;
		_topY = topY - baseShift;
		_bottomY = bottomY - baseShift;
		_isDoubleSided = ((ladderItem.TriggerFlags & (1 << 0)) == 1);
	}

	int LadderObject::GetBaseItemNumber() const
	{
		return _baseItemNumber;
	}

	bool LadderObject::IsDoubleSided() const
	{
		return _isDoubleSided;
	}

	int LadderObject::GetHeight() const
	{
		return _bottomY -_topY;
	}

	Vector3i LadderObject::GetBasePosition() const
	{
		auto pos = g_Level.Items[_baseItemNumber].Pose.Position;
		pos.y += _bottomY;
		return pos;
	}

	Vector3i LadderObject::GetTopPosition() const
	{
		auto pos = g_Level.Items[_baseItemNumber].Pose.Position;
		pos.y += _topY;
		return pos;
	}

	int LadderObject::GetAttachmentHeight(int positionY) const
	{
		int step = (int)LADDER_STEP_HEIGHT;
		int baseY = GetBasePosition().y;

		// Snap to the closest rung.
		int relY = positionY - baseY;
		int snappedY = (int)round((float)relY / step) * step;

		// Never grab above the height where the top dismount can fire; otherwise she'd climb past it and get stuck.
		int topGrabY = _topY + (int)LARA_HEIGHT;

		return (baseY + std::max(snappedY, topGrabY));
	}

	bool LadderObject::IsHeightWithin(int positionY) const
	{
		int topY = GetTopPosition().y;
		int baseY = GetBasePosition().y;

		return (positionY >= topY && positionY <= baseY);
	}

	LadderObject& GetLadderObject(const ItemInfo& item)
	{
		return (LadderObject&)item.Data;
	}

	void InitializeLadder(short itemNumber)
	{
		auto& ladderItem = g_Level.Items[itemNumber];

		ladderItem.Data = LadderObject(itemNumber);

		AddActiveItem(itemNumber);
	}

	static void DrawLadderDebug(ItemInfo& ladderItem)
	{
		// Draw collision bounds.
		auto bounds = GameBoundingBox(&ladderItem);
		auto box = bounds.ToBoundingOrientedBox(ladderItem.Pose);
		//g_Renderer.AddDebugBox(box, Vector4(1, 0, 0, 1), RendererDebugPage::None);

		// Draw interaction bounds.
		auto interactBounds = LadderInteractBounds2D + GameBoundingBox(0, 0, bounds.Y1, bounds.Y2, 0, 0);
		auto interactBox = interactBounds.ToBoundingOrientedBox(ladderItem.Pose);
		//g_Renderer.AddDebugBox(interactBox, Vector4(0, 1, 1, 1), RendererDebugPage::None);

		// Draw stack bounds. Only the base item of the stack draws them, so overlapping ladders don't
		// produce duplicate boxes.
		const auto& ladder = GetLadderObject(ladderItem);
		if (ladderItem.Index != ladder.GetBaseItemNumber())
			return;

		const auto& baseItem = g_Level.Items[ladder.GetBaseItemNumber()];
		auto baseBounds = GameBoundingBox(&baseItem);

		int topRelY = ladder.GetTopPosition().y - baseItem.Pose.Position.y;
		int bottomRelY = ladder.GetBasePosition().y - baseItem.Pose.Position.y;

		auto stackBounds = GameBoundingBox(baseBounds.X1, baseBounds.X2, topRelY, bottomRelY, baseBounds.Z1, baseBounds.Z2);
		auto stackBox = stackBounds.ToBoundingOrientedBox(baseItem.Pose);
		g_Renderer.AddDebugBox(stackBox, Vector4(0, 1, 0, 1), RendererDebugPage::None);
	}

	static bool TestLadderMount(const ItemInfo& ladderItem, const ItemInfo& playerItem, bool groundMount)
	{
		const auto& player = GetLaraInfo(playerItem);

		// 1) Check ladder usability.
		if (ladderItem.Flags & IFLAG_INVISIBLE)
			return false;

		// 2) Check hand status.
		if (player.Control.HandStatus != HandStatus::Free)
			return false;

		// 3) Test active player state for the requested mount type.
		if (groundMount)
		{
			if (!TestState(playerItem.Animation.ActiveState, LadderGroundedMountPlayerStates))
				return false;
		}
		else
		{
			if (!playerItem.Animation.IsAirborne ||
				!TestState(playerItem.Animation.ActiveState, LadderAirborneMountPlayerStates))
			{
				return false;
			}
		}

		// 4) Test for input action. A grounded mount needs a FRESH Action press, so simply holding
		// Action (e.g. straight after a top dismount) doesn't immediately re-mount. An airborne grab
		// may hold Action from the jump, and an in-progress walk-to-ladder interaction keeps its mount.
		bool isInteracting = (groundMount && player.Control.IsMoving && player.Context.InteractedItem == ladderItem.Index);
		if (!isInteracting && !(groundMount ? IsClicked(In::Action) : IsHeld(In::Action)))
			return false;

		// TODO: Assess whether ladder is in front.

		return true;
	}

	static LadderMountType GetLadderMountType(ItemInfo& ladderItem, const ItemInfo& playerItem)
	{
		auto bounds = GameBoundingBox(&ladderItem);
		// Get the vertical extents of the whole ladder stack, then extend the interaction box to cover it
		// (plus one step below) so detection works across stacked ladder objects.
		//auto stackExtents = GetLadderStackExtents(ladderItem);
		auto boundsExtension = GameBoundingBox(0, 0, bounds.Y1, bounds.Y2 + LADDER_STEP_HEIGHT, 0, 0).ToBoundingOrientedBox(Pose::Zero);

		// Air mounts. Front face only.
		if (TestLadderMount(ladderItem, playerItem, false))
		{
			// Front mount.
			if (TestInteraction(playerItem, ladderItem, LadderMountFrontBasis, boundsExtension))
			{
				// Jump case.
				if (playerItem.Animation.Velocity.y > 0.0f)
				{
					if (playerItem.Animation.ActiveState == LS_JUMP_UP)
					{
						return LadderMountType::JumpUp;
					}
					else if (playerItem.Animation.ActiveState == LS_REACH)
					{
						return LadderMountType::JumpReach;
					}
				}
			}

			return LadderMountType::None;
		}

		// Ground mounts.
		if (!TestLadderMount(ladderItem, playerItem, true))
			return LadderMountType::None;

		// Top mounts broken at the moment: only when Lara is standing at the top of the stack.
		int stackTopWorldY = ladderItem.Pose.Position.y + bounds.Y1;
		if (abs(playerItem.Pose.Position.y - stackTopWorldY) <= LADDER_STEP_HEIGHT)
		{
			if (TestInteraction(playerItem, ladderItem, LadderMountTopFrontBasis, boundsExtension))
				return LadderMountType::TopFront;

			if (TestInteraction(playerItem, ladderItem, LadderMountTopBackBasis, boundsExtension))
				return LadderMountType::TopBack;
		}

		// Front mount.
		if (TestInteraction(playerItem, ladderItem, LadderMountFrontBasis, boundsExtension))
			return LadderMountType::Front;

		if (TestInteraction(playerItem, ladderItem, LadderMountBackBasis, boundsExtension))
			return LadderMountType::Back;

		if (TestInteraction(playerItem, ladderItem, LadderMountLeftBasis, boundsExtension))
			return LadderMountType::Left;

		if (TestInteraction(playerItem, ladderItem, LadderMountRightBasis, boundsExtension))
			return LadderMountType::Right;

		return LadderMountType::None;
	}

	static void SetPlayerLadderMountInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_FRONT);
		interactor.Animation.IsAirborne = false;
	}

	static void SetPlayerLadderMountRightInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_RIGHT);
		interactor.Animation.IsAirborne = false;
	}

	static void SetPlayerLadderMountLeftInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_LEFT);
		interactor.Animation.IsAirborne = false;
	}

	static void SetPlayerLadderMountTopFrontInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_TOP_FRONT);
		interactor.Animation.IsAirborne = false;
	}

	static void SetPlayerLadderMountTopBackInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_TOP_BACK);
		interactor.Animation.IsAirborne = false;
	}

	static void SetPlayerLadderAirGrabInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_JUMP_UP);
		interactor.Animation.IsAirborne = false;
	}

	static void SetPlayerLadderAirReachInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_JUMP_REACH);
		interactor.Animation.IsAirborne = false;
	}

	static void HandleLadderMount(ItemInfo& ladderItem, ItemInfo& playerItem, LadderMountType mountType)
	{
		auto& player = *GetLaraInfo(&playerItem);

		// Avoid interference if already interacting.
		if (playerItem.OffsetBlend.IsActive)
			player.Context.InteractedItem = ladderItem.Index;

		auto bounds = GameBoundingBox(&ladderItem);

		switch (mountType)
		{
		default:
		case LadderMountType::None:
			return;

		case LadderMountType::TopFront:
		{
			auto extraPosOffset = Vector3i(0, bounds.Y1, 0);
			SetInteraction(playerItem, ladderItem, LadderMountTopFrontBasis, SetPlayerLadderMountTopFrontInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}

		case LadderMountType::TopBack:
		{
			auto extraPosOffset = Vector3i(0, bounds.Y1, 0);
			SetInteraction(playerItem, ladderItem, LadderMountTopBackBasis, SetPlayerLadderMountTopBackInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}

		case LadderMountType::Front:
		{
			auto extraPosOffset = Vector3i(0, 0, bounds.Z1);
			SetInteraction(playerItem, ladderItem, LadderMountFrontBasis, SetPlayerLadderMountInteraction, InteractionBasisType::Walk, extraPosOffset);
			break;
		}

		case LadderMountType::Back:
		{
			auto extraPosOffset = Vector3i(0, 0, bounds.Z2);
			SetInteraction(playerItem, ladderItem, LadderMountBackBasis, SetPlayerLadderMountInteraction, InteractionBasisType::Walk, extraPosOffset);
			break;
		}

		case LadderMountType::Left:
		{
			auto extraPosOffset = Vector3i(0, playerItem.Pose.Position.y, bounds.Z1);
			SetInteraction(playerItem, ladderItem, LadderMountLeftBasis, SetPlayerLadderMountLeftInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}

		case LadderMountType::Right:
		{
			auto extraPosOffset = Vector3i(0, playerItem.Pose.Position.y, bounds.Z1);
			SetInteraction(playerItem, ladderItem, LadderMountRightBasis, SetPlayerLadderMountRightInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}

		case LadderMountType::JumpUp:
		{
			auto& ladder = GetLadderObject(ladderItem);

			// Snap her feet to the rung closest to her current height.
			int attachmentY = ladder.GetAttachmentHeight(playerItem.Pose.Position.y);
			auto extraPosOffset = Vector3i(0, attachmentY - ladderItem.Pose.Position.y, bounds.Z1);

			SetInteraction(playerItem, ladderItem, LadderMountFrontBasis, SetPlayerLadderAirGrabInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}
		case LadderMountType::JumpReach:
		{
			auto& ladder = GetLadderObject(ladderItem);

			// Snap her feet to the rung closest to her current height.
			int attachmentY = ladder.GetAttachmentHeight(playerItem.Pose.Position.y);
			auto extraPosOffset = Vector3i(0, attachmentY - ladderItem.Pose.Position.y, bounds.Z1);

			SetInteraction(playerItem, ladderItem, LadderMountFrontBasis, SetPlayerLadderAirReachInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}
		}

		playerItem.Parenting.Attach(ladderItem);
		player.Control.IsMoving = false;
		player.Control.HandStatus = HandStatus::Busy;
	}

	void CollideLadder(short itemNumber, ItemInfo* playerItem, CollisionInfo* coll)
	{
		auto& ladderItem = g_Level.Items[itemNumber];

		DrawLadderDebug(ladderItem);

		// Try to mount the ladder.
		auto mountType = GetLadderMountType(ladderItem, *playerItem);
		if (mountType != LadderMountType::None)
		{
			HandleLadderMount(ladderItem, *playerItem, mountType);
			return;
		}

		// Player is not mounting the ladder; do regular object collision.
		if (!TestState(playerItem->Animation.ActiveState, LadderMountedPlayerStates) &&
			playerItem->Animation.ActiveState != LS_JUMP_BACK) // TODO: Player can jump through ladders.
		{
			ObjectCollision(itemNumber, playerItem, coll);
		}
	}
}