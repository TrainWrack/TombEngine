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
	const auto LadderMountedOffsetTop2D = Vector3i(0, 0, 150);
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
		LadderMountedOffset2D,
		EulerAngles(0, ANGLE(180.0f), 0),
		LadderInteractBox2D,
		std::pair(
			EulerAngles(-PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(180.0f) - LARA_GRAB_THRESHOLD, -PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD),
			EulerAngles(PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD, ANGLE(180.0f) + LARA_GRAB_THRESHOLD, PLAYER_MOUNT_LEAN_ANGLE_THRESHOLD)));

	const auto LadderMountTopBackBasis = InteractionBasis(
		LadderMountedOffsetTop2D,
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

	void InitializeLadder(short itemNumber)
	{
		auto& ladderItem = g_Level.Items[itemNumber];

		bool isDoubleSided = ((ladderItem.TriggerFlags & (1 << 0)) == 1);

		AddActiveItem(itemNumber);
	}

	static void DrawLadderDebug(ItemInfo& ladderItem)
	{
		// Draw collision bounds.
		auto bounds = GameBoundingBox(&ladderItem);
		auto box = bounds.ToBoundingOrientedBox(ladderItem.Pose);
		g_Renderer.AddDebugBox(box, Vector4(1, 0, 0, 1), RendererDebugPage::None);

		// Draw interaction bounds.
		auto interactBounds = LadderInteractBounds2D + GameBoundingBox(0, 0, bounds.Y1, bounds.Y2, 0, 0);
		auto interactBox = interactBounds.ToBoundingOrientedBox(ladderItem.Pose);
		g_Renderer.AddDebugBox(interactBox, Vector4(0, 1, 1, 1), RendererDebugPage::None);
	}

	struct LadderStackExtents
	{
		int TopY	= 0;
		int BottomY = 0;
	};

	// Get the vertical extents of the whole ladder stack (relative to the given ladder), by probing
	// nearby horizontally-aligned ladder objects. Mirrors the vertical pole's segment detection.
	static LadderStackExtents GetLadderStackExtents(ItemInfo& ladderItem)
	{
		constexpr auto ALIGN_XZ_TOLERANCE  = BLOCK(0.25f);
		constexpr auto ALIGN_YAW_TOLERANCE = ANGLE(5.0f);

		auto bounds = GameBoundingBox(&ladderItem);
		auto extents = LadderStackExtents{ bounds.Y1, bounds.Y2 };

		auto collObjects = GetCollidedObjects(ladderItem, true, true, COLLISION_CHECK_DISTANCE, ObjectCollectionMode::Items);
		for (const auto* itemPtr : collObjects.Items)
		{
			if (itemPtr->ObjectNumber != ID_LADDER_ONE_SIDED &&
				itemPtr->ObjectNumber != ID_LADDER_DOUBLE_SIDED)
			{
				continue;
			}

			// Only merge ladders that are horizontally aligned and share the same yaw.
			if (abs(itemPtr->Pose.Position.x - ladderItem.Pose.Position.x) > ALIGN_XZ_TOLERANCE ||
				abs(itemPtr->Pose.Position.z - ladderItem.Pose.Position.z) > ALIGN_XZ_TOLERANCE ||
				abs(Geometry::GetShortestAngle(itemPtr->Pose.Orientation.y, ladderItem.Pose.Orientation.y)) > ALIGN_YAW_TOLERANCE)
			{
				continue;
			}

			// Merge the neighbour's vertical extents into this ladder's local space.
			int relY = itemPtr->Pose.Position.y - ladderItem.Pose.Position.y;
			auto itemBounds = GameBoundingBox(itemPtr);
			extents.TopY = std::min(extents.TopY, relY + itemBounds.Y1);
			extents.BottomY = std::max(extents.BottomY, relY + itemBounds.Y2);
		}

		return extents;
	}

	static bool TestLadderMount(const ItemInfo& ladderItem, const ItemInfo& playerItem)
	{
		const auto& player = GetLaraInfo(playerItem);

		// 1) Check ladder usability.
		if (ladderItem.Flags & IFLAG_INVISIBLE)
			return false;

		// 2) Check hand status.
		if (player.Control.HandStatus != HandStatus::Free)
			return false;

		// 3) Test active player state. Accept either a grounded or airborne mount state.
		bool isGroundedMount = TestState(playerItem.Animation.ActiveState, LadderGroundedMountPlayerStates);
		bool isAirborneMount = playerItem.Animation.IsAirborne &&
			TestState(playerItem.Animation.ActiveState, LadderAirborneMountPlayerStates);
		if (!isGroundedMount && !isAirborneMount)
			return false;

		// 4) Test for input action. A grounded mount needs a FRESH Action press, so simply holding
		// Action (e.g. straight after a top dismount) doesn't immediately re-mount. An airborne grab
		// may hold Action from the jump, and an in-progress walk-to-ladder interaction keeps its mount.
		bool isInteracting = (player.Control.IsMoving && player.Context.InteractedItem == ladderItem.Index);
		if (!isInteracting && !(isAirborneMount ? IsHeld(In::Action) : IsClicked(In::Action)))
			return false;

		// TODO: Assess whether ladder is in front.

		return true;
	}

	static LadderMountType GetLadderMountType(ItemInfo& ladderItem, const ItemInfo& playerItem)
	{
		// Test ladder mountability.
		if (!TestLadderMount(ladderItem, playerItem))
			return LadderMountType::None;

		// Get the vertical extents of the whole ladder stack, then extend the interaction box to cover it
		// (plus one step below) so detection works across stacked ladder objects.
		auto stackExtents = GetLadderStackExtents(ladderItem);
		auto boundsExtension = GameBoundingBox(0, 0, stackExtents.TopY, stackExtents.BottomY + LADDER_STEP_HEIGHT, 0, 0).ToBoundingOrientedBox(Pose::Zero);

		// Top mounts: only when Lara is standing at the top of the stack.
		int stackTopWorldY = ladderItem.Pose.Position.y + stackExtents.TopY;
		if (abs(playerItem.Pose.Position.y - stackTopWorldY) <= LADDER_STEP_HEIGHT)
		{
			if (TestInteraction(playerItem, ladderItem, LadderMountTopFrontBasis, boundsExtension))
				return LadderMountType::TopFront;

			if (TestInteraction(playerItem, ladderItem, LadderMountTopBackBasis, boundsExtension))
				return LadderMountType::TopBack;
		}

		// Front mount.
		if (TestInteraction(playerItem, ladderItem, LadderMountFrontBasis, boundsExtension))
		{
			// Jump case.
			if (playerItem.Animation.IsAirborne && playerItem.Animation.Velocity.y > 0.0f)
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
			// Regular case.
			else
			{
				return LadderMountType::Front;
			}
		}

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
	}

	static void SetPlayerLadderMountRightInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_RIGHT);
	}

	static void SetPlayerLadderMountLeftInteraction(ItemInfo& interactor, ItemInfo&)
	{
		SetAnimation(&interactor, LA_LADDERX_MOUNT_LEFT);
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

		// Vertical extents of the whole ladder stack.
		auto stackExtents = GetLadderStackExtents(ladderItem);

		switch (mountType)
		{
		default:
		case LadderMountType::None:
			return;

		case LadderMountType::TopFront:
		{
			auto extraPosOffset = Vector3i(0, stackExtents.TopY, bounds.Z1);
			SetInteraction(playerItem, ladderItem, LadderMountTopFrontBasis, SetPlayerLadderMountTopFrontInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}

		case LadderMountType::TopBack:
		{
			auto extraPosOffset = Vector3i(0, stackExtents.TopY, bounds.Z2);
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
			auto extraPosOffset = Vector3i(0, 0, bounds.Z1);
			SetInteraction(playerItem, ladderItem, LadderMountLeftBasis, SetPlayerLadderMountLeftInteraction, InteractionBasisType::Walk, extraPosOffset);
			break;
		}

		case LadderMountType::Right:
		{
			auto extraPosOffset = Vector3i(0, 0, bounds.Z1);
			SetInteraction(playerItem, ladderItem, LadderMountRightBasis, SetPlayerLadderMountRightInteraction, InteractionBasisType::Walk, extraPosOffset);
			break;
		}

		case LadderMountType::JumpUp:
		{
			// Snap Lara's feet to the closest ladder step at her current height instead of the ladder base.
			int step = (int)LADDER_STEP_HEIGHT;
			int relY = playerItem.Pose.Position.y - ladderItem.Pose.Position.y;
			int snappedY = (int)round((float)relY / step) * step;
			//Trainwreck the snapped height needs to be a few rungs below the top.
			// Never grab above the height where the top dismount can fire; otherwise she'd climb past it and get stuck.
			int topGrabY = stackExtents.TopY + (int)LARA_HEIGHT;
			snappedY = std::max(snappedY, topGrabY);

			auto extraPosOffset = Vector3i(0, snappedY, bounds.Z1);

			SetInteraction(playerItem, ladderItem, LadderMountFrontBasis, SetPlayerLadderAirGrabInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}
		case LadderMountType::JumpReach:
		{
			// Snap Lara's feet to the closest ladder step at her current height instead of the ladder base.
			int step = (int)LADDER_STEP_HEIGHT;
			int relY = playerItem.Pose.Position.y - ladderItem.Pose.Position.y;
			int snappedY = (int)round((float)relY / step) * step;
			//Trainwreck the snapped height needs to be a few rungs below the top.
			// Never grab above the height where the top dismount can fire; otherwise she'd climb past it and get stuck.
			int topGrabY = stackExtents.TopY + (int)LARA_HEIGHT;
			snappedY = std::max(snappedY, topGrabY);

			auto extraPosOffset = Vector3i(0, snappedY, bounds.Z1);

			SetInteraction(playerItem, ladderItem, LadderMountFrontBasis, SetPlayerLadderAirReachInteraction, InteractionBasisType::Latch, extraPosOffset);
			break;
		}
		}

		playerItem.Parenting.Attach(ladderItem);
		player.Control.IsMoving = false;
		player.Control.HandStatus = HandStatus::Busy;
	}

	bool TestLadderClimb(const ItemInfo& playerItem, bool goingUp)
	{
		const auto& player = GetLaraInfo(playerItem);

		if (player.Context.InteractedItem == NO_VALUE)
			return false;

		auto& ladderItem = g_Level.Items[player.Context.InteractedItem];
		if (ladderItem.ObjectNumber != ID_LADDER_ONE_SIDED &&
			ladderItem.ObjectNumber != ID_LADDER_DOUBLE_SIDED)
		{
			return false;
		}

		auto stackExtents = GetLadderStackExtents(ladderItem);

		// Lara can keep climbing while her feet remain within the ladder stack.
		if (goingUp)
			return (playerItem.Pose.Position.y >= (ladderItem.Pose.Position.y + stackExtents.TopY));

		return (playerItem.Pose.Position.y <= (ladderItem.Pose.Position.y + stackExtents.BottomY));
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