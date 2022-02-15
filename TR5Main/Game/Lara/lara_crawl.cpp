#include "framework.h"
#include "Game/Lara/lara_crawl.h"

#include "Game/animation.h"
#include "Game/camera.h"
#include "Game/collision/collide_room.h"
#include "Game/control/control.h"
#include "Game/control/los.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Game/Lara/lara_tests.h"
#include "Game/Lara/lara_collide.h"
#include "Game/Lara/lara_flare.h"
#include "Game/Lara/lara_helpers.h"
#include "Specific/input.h"
#include "Specific/level.h"
#include "Scripting/GameFlowScript.h"

// -----------------------------
// CRAWL & CROUCH
// Control & Collision Functions
// -----------------------------

// -------
// CROUCH:
// -------

// State:		LS_CROUCH_IDLE (71)
// Collision:	lara_col_crouch_idle()
void lara_as_crouch_idle(ITEM_INFO* item, COLL_INFO* coll)
{
	// TODO: Deplete air meter if Lara's head is below the water. Original implementation had a weird buffer zone before
	// wade depth where Lara couldn't crouch at all, and if the player forced her into the crouched state by
	// crouching into the region from a run as late as possible, she wasn't able to turn or begin crawling.
	// Since Lara can now crawl at a considerable depth, a region of peril would make sense. @Sezz 2021.10.21

	auto* info = GetLaraInfo(item);

	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	// TODO: Dispatch pickups from within states.
	if (item->TargetState == LS_PICKUP)
		return;

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	if (TrInput & IN_LOOK)
		LookUpDown();

	if (TrInput & IN_LEFT)
		info->Control.TurnRate = -LARA_CRAWL_TURN_MAX;
	else if (TrInput & IN_RIGHT)
		info->Control.TurnRate = LARA_CRAWL_TURN_MAX;

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll) &&
			info->Control.HandStatus == HandStatus::Free &&
			g_GameFlow->Animations.CrouchRoll)
		{
			item->TargetState = LS_CROUCH_ROLL;
			return;
		}

		if (TrInput & (IN_FORWARD | IN_BACK) && TestLaraCrouchToCrawl(item))
		{
			item->TargetState = LS_CRAWL_IDLE;
			return;
		}

		if (TrInput & IN_LEFT)
		{
			item->TargetState = LS_CROUCH_TURN_LEFT;
			return;
		}
		else if (TrInput & IN_RIGHT)
		{
			item->TargetState = LS_CROUCH_TURN_RIGHT;
			return;
		}

		item->TargetState = LS_CROUCH_IDLE;
		return;
	}

	item->TargetState = LS_IDLE;
}

// State:		LS_CROUCH_IDLE (71)
// Control:		lara_as_crouch_idle()
void lara_col_crouch_idle(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.KeepLow = TestLaraKeepLow(item, coll);
	info->Control.IsLow = true;
	info->Control.MoveAngle = item->Position.yRot;
	info->ExtraTorsoRot = PHD_3DPOS();
	item->Airborne = false;
	item->VerticalVelocity = 0;
	coll->Setup.Height = LARA_HEIGHT_CRAWL;
	coll->Setup.ForwardAngle = item->Position.yRot;
	coll->Setup.LowerFloorBound = CLICK(1) - 1;
	coll->Setup.UpperFloorBound = -(CLICK(1) - 1);
	coll->Setup.LowerCeilingBound = 0;
	coll->Setup.FloorSlopeIsWall = true;
	coll->Setup.FloorSlopeIsPit = true;
	GetCollisionInfo(coll, item);

	if (TestLaraFall(item, coll))
	{
		SetLaraFallState(item);
		info->Control.HandStatus = HandStatus::Free;
		return;
	}

	if (TestLaraSlide(item, coll))
	{
		SetLaraSlideState(item, coll);
		return;
	}

	ShiftItem(item, coll);
	
	if (TestLaraStep(item, coll))
	{
		DoLaraStep(item, coll);
		return;
	}
}

// State:		LS_CROUCH_ROLL (72)
// Collision:	lara_as_crouch_roll()
void lara_as_crouch_roll(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.CanLook = false;
	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (TrInput & IN_LEFT)
	{
		info->Control.TurnRate -= LARA_TURN_RATE;
		if (info->Control.TurnRate < -LARA_CROUCH_ROLL_TURN_MAX)
			info->Control.TurnRate = -LARA_CROUCH_ROLL_TURN_MAX;

		DoLaraLean(item, coll, -LARA_LEAN_MAX, LARA_LEAN_RATE);
	}
	else if (TrInput & IN_RIGHT)
	{
		info->Control.TurnRate += LARA_TURN_RATE;
		if (info->Control.TurnRate > LARA_CROUCH_ROLL_TURN_MAX)
			info->Control.TurnRate = LARA_CROUCH_ROLL_TURN_MAX;

		DoLaraLean(item, coll, LARA_LEAN_MAX, LARA_LEAN_RATE);
	}

	item->TargetState = LS_CROUCH_IDLE;
}

// State:		LS_CROUCH_ROLL (72)
// Control:		lara_as_crouch_roll()
void lara_col_crouch_roll(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.KeepLow = TestLaraKeepLow(item, coll);
	info->Control.IsLow = true;
	info->Control.MoveAngle = item->Position.yRot;
	item->Airborne = 0;
	item->VerticalVelocity = 0;
	coll->Setup.Height = LARA_HEIGHT_CRAWL;
	coll->Setup.LowerFloorBound = CLICK(1) - 1;
	coll->Setup.UpperFloorBound = -(CLICK(1) - 1);
	coll->Setup.ForwardAngle = item->Position.yRot;
	coll->Setup.LowerCeilingBound = 0;
	coll->Setup.FloorSlopeIsWall = true;
	GetCollisionInfo(coll, item);

	// TODO: With sufficient speed, Lara can still roll off ledges. This is particularly a problem in the uncommon scenario where
	// she becomes Airborne within a crawlspace; collision handling will push her back very rapidly and potentially cause a softlock. @Sezz 2021.11.02
	if (LaraDeflectEdgeCrawl(item, coll))
	{
		item->Position.xPos = coll->Setup.OldPosition.x;
		item->Position.yPos = coll->Setup.OldPosition.y;
		item->Position.zPos = coll->Setup.OldPosition.z;
	}

	if (TestLaraFall(item, coll))
	{
		SetLaraFallState(item);
		info->Control.HandStatus = HandStatus::Free;
		item->Velocity /= 3;				// Truncate speed to prevent flying off.
		return;
	}

	if (TestLaraSlide(item, coll))
	{
		SetLaraSlideState(item, coll);
		return;
	}

	ShiftItem(item, coll);

	if (TestLaraHitCeiling(coll))
	{
		SetLaraHitCeiling(item, coll);
		return;
	}

	if (TestLaraStep(item, coll))
	{
		DoLaraStep(item, coll);
		return;
	}
}

// State:		LS_CROUCH_TURN_LEFT (105)
// Collision:	lara_col_crouch_turn_left()
void lara_as_crouch_turn_left(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	if (TrInput & IN_LOOK)
		LookUpDown();

	info->Control.TurnRate = -LARA_CRAWL_TURN_MAX;

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll) &&
			g_GameFlow->Animations.CrouchRoll)
		{
			item->TargetState = LS_CROUCH_ROLL;
			return;
		}

		if (TrInput & (IN_FORWARD | IN_BACK) && TestLaraCrouchToCrawl(item))
		{
			item->TargetState = LS_CRAWL_IDLE;
			return;
		}

		if (TrInput & IN_LEFT)
		{
			item->TargetState = LS_CROUCH_TURN_LEFT;
			return;
		}

		item->TargetState = LS_CROUCH_IDLE;
		return;
	}

	item->TargetState = LS_IDLE;
}

// State:		LS_CRAWL_TURN_LEFT (105)
// Control:		lara_as_crouch_turn_left()
void lara_col_crouch_turn_left(ITEM_INFO* item, COLL_INFO* coll)
{
	lara_col_crouch_idle(item, coll);
}

// State:		LS_CROUCH_TURN_RIGHT (106)
// Collision:	lara_col_crouch_turn_right()
void lara_as_crouch_turn_right(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	if (TrInput & IN_LOOK)
		LookUpDown();

	info->Control.TurnRate = LARA_CRAWL_TURN_MAX;

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll) &&
			g_GameFlow->Animations.CrouchRoll)
		{
			item->TargetState = LS_CROUCH_ROLL;
			return;
		}

		if (TrInput & (IN_FORWARD | IN_BACK) && TestLaraCrouchToCrawl(item))
		{
			item->TargetState = LS_CRAWL_IDLE;
			return;
		}

		if (TrInput & IN_RIGHT)
		{
			item->TargetState = LS_CROUCH_TURN_RIGHT;
			return;
		}

		item->TargetState = LS_CROUCH_IDLE;
		return;
	}

	item->TargetState = LS_IDLE;
}

// State:		LS_CRAWL_TURN_RIGHT (106)
// Control:		lara_as_crouch_turn_right()
void lara_col_crouch_turn_right(ITEM_INFO* item, COLL_INFO* coll)
{
	lara_col_crouch_idle(item, coll);
}

// ------
// CRAWL:
// ------

// State:		LS_CRAWL_IDLE (80)
// Collision:	lara_col_crawl_idle()
void lara_as_crawl_idle(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.HandStatus = HandStatus::Busy;
	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	// TODO: Dispatch pickups from within states.
	if (item->TargetState == LS_PICKUP)
		return;

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	if (TrInput & IN_LOOK)
		LookUpDown();

	if (TrInput & IN_LEFT)
		info->Control.TurnRate = -LARA_CRAWL_TURN_MAX;
	else if (TrInput & IN_RIGHT)
		info->Control.TurnRate = LARA_CRAWL_TURN_MAX;

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		// TODO: Flare not working.
		if ((TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll)) ||
			(TrInput & (IN_DRAW | IN_FLARE) &&
			!IsStandingWeapon(info->Control.WeaponControl.GunType) &&
			item->AnimNumber != LA_CROUCH_TO_CRAWL_START)) // Hack.
		{
			item->TargetState = LS_CROUCH_IDLE;
			info->Control.HandStatus = HandStatus::Free;
			return;
		}

		if (TrInput & IN_FORWARD)
		{
			auto crawlVaultResult = TestLaraCrawlVault(item, coll);

			if (TrInput & (IN_ACTION | IN_JUMP) &&
				crawlVaultResult.Success &&
				g_GameFlow->Animations.CrawlExtended)
			{
				item->TargetState = crawlVaultResult.TargetState;
				ResetLaraFlex(item);
				return;
			}
			else if (TestLaraCrawlForward(item, coll)) [[likely]]
			{
				item->TargetState = LS_CRAWL_FORWARD;
				return;
			}
		}
		else if (TrInput & IN_BACK)
		{
			if (TrInput & (IN_ACTION | IN_JUMP) && TestLaraCrawlToHang(item, coll))
			{
				item->TargetState = LS_CRAWL_TO_HANG;
				DoLaraCrawlToHangSnap(item, coll);
				return;
			}
			else if (TestLaraCrawlBack(item, coll)) [[likely]]
			{
				item->TargetState = LS_CRAWL_BACK;
				return;
			}
		}

		if (TrInput & IN_LEFT)
		{
			item->TargetState = LS_CRAWL_TURN_LEFT;
			return;
		}
		else if (TrInput & IN_RIGHT)
		{
			item->TargetState = LS_CRAWL_TURN_RIGHT;
			return;
		}

		item->TargetState = LS_CRAWL_IDLE;
		return;
	}

	item->TargetState = LS_CROUCH_IDLE;
	info->Control.HandStatus = HandStatus::Free;
}

// State:		LS_CRAWL_IDLE (80)
// Control:		lara_as_crawl_idle()
void lara_col_crawl_idle(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.KeepLow = TestLaraKeepLow(item, coll);
	info->Control.IsLow = true;
	info->Control.MoveAngle = item->Position.yRot;
	info->ExtraTorsoRot = PHD_3DPOS();
	item->VerticalVelocity = 0;
	item->Airborne = false;
	coll->Setup.ForwardAngle = info->Control.MoveAngle;
	coll->Setup.Radius = LARA_RAD_CRAWL;
	coll->Setup.Height = LARA_HEIGHT_CRAWL;
	coll->Setup.LowerFloorBound = CLICK(1) - 1;
	coll->Setup.UpperFloorBound = -(CLICK(1) - 1);
	coll->Setup.LowerCeilingBound = LARA_HEIGHT_CRAWL;
	coll->Setup.FloorSlopeIsWall = true;
	coll->Setup.FloorSlopeIsPit = true;
	GetCollisionInfo(coll, item);

	if (TestLaraFall(item, coll))
	{
		SetLaraFallState(item);
		return;
	}

	if (TestLaraSlide(item, coll))
	{
		SetLaraSlideState(item, coll);
		return;
	}

	ShiftItem(item, coll);
	
	if (TestLaraStep(item, coll))
	{
		DoLaraStep(item, coll);
		return;
	}
}

// State:		LS_CRAWL_FORWARD (81)
// Collision:	lara_col_crawl_forward()
void lara_as_crawl_forward(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.HandStatus = HandStatus::Busy;
	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	if (TrInput & IN_LEFT)
	{
		info->Control.TurnRate -= LARA_CRAWL_MOVE_TURN_RATE;
		if (info->Control.TurnRate < -LARA_CRAWL_MOVE_TURN_MAX)
			info->Control.TurnRate = -LARA_CRAWL_MOVE_TURN_MAX;

		DoLaraCrawlFlex(item, coll, -LARA_CRAWL_FLEX_MAX, LARA_CRAWL_FLEX_RATE);
	}
	else if (TrInput & IN_RIGHT)
	{
		info->Control.TurnRate += LARA_CRAWL_MOVE_TURN_RATE;
		if (info->Control.TurnRate > LARA_CRAWL_MOVE_TURN_MAX)
			info->Control.TurnRate = LARA_CRAWL_MOVE_TURN_MAX;

		DoLaraCrawlFlex(item, coll, LARA_CRAWL_FLEX_MAX, LARA_CRAWL_FLEX_RATE);
	}

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll))
		{
			item->TargetState = LS_CRAWL_IDLE;
			return;
		}

		if (TrInput & IN_FORWARD)
		{
			item->TargetState = LS_CRAWL_FORWARD;
			return;
		}

		item->TargetState = LS_CRAWL_IDLE;
		return;
	}

	item->TargetState = LS_CRAWL_IDLE;
}

// State:		LS_CRAWL_FORWARD (81)
// Control:		lara_as_crawl_forward()
void lara_col_crawl_forward(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.KeepLow = TestLaraKeepLow(item, coll);
	info->Control.IsLow = true;
	info->Control.MoveAngle = item->Position.yRot;
	info->ExtraTorsoRot = PHD_3DPOS();
	item->Airborne = false;
	item->VerticalVelocity = 0;
	coll->Setup.Radius = LARA_RAD_CRAWL;
	coll->Setup.Height = LARA_HEIGHT_CRAWL;
	coll->Setup.LowerFloorBound = CLICK(1) - 1;		// Offset of 1 is required or Lara will crawl up/down steps.
	coll->Setup.UpperFloorBound = -(CLICK(1) - 1);		// TODO: Stepping approach is different from walk/run because crawl step anims do not submerge Lara. Resolve this someday. @Sezz 2021.10.31
	coll->Setup.LowerCeilingBound = LARA_HEIGHT_CRAWL;
	coll->Setup.FloorSlopeIsPit = true;
	coll->Setup.FloorSlopeIsWall = true;
	coll->Setup.DeathFlagIsPit = true;
	coll->Setup.ForwardAngle = info->Control.MoveAngle;
	GetCollisionInfo(coll, item, true);

	if (LaraDeflectEdgeCrawl(item, coll))
		LaraCollideStopCrawl(item, coll);
	
	if (TestLaraFall(item, coll))
	{
		SetLaraFallState(item);
		return;
	}
	
	if (TestLaraSlide(item, coll))
	{
		SetLaraSlideState(item, coll);
		return;
	}

	ShiftItem(item, coll);

	if (TestLaraStep(item, coll))
	{
		DoLaraStep(item, coll);
		return;
	}
}

// State:		LS_CRAWL_BACK (86)
// Collision:	lara_col_crawl_back()
void lara_as_crawl_back(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.CanLook = false;
	info->Control.HandStatus = HandStatus::Busy;
	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	if (TrInput & IN_LEFT)
	{
		info->Control.TurnRate -= LARA_CRAWL_MOVE_TURN_RATE;
		if (info->Control.TurnRate < -LARA_CRAWL_MOVE_TURN_MAX)
			info->Control.TurnRate = -LARA_CRAWL_MOVE_TURN_MAX;

		DoLaraCrawlFlex(item, coll, LARA_CRAWL_FLEX_MAX, LARA_CRAWL_FLEX_RATE);
	}
	else if (TrInput & IN_RIGHT)
	{
		info->Control.TurnRate += LARA_CRAWL_MOVE_TURN_RATE;
		if (info->Control.TurnRate > LARA_CRAWL_MOVE_TURN_MAX)
			info->Control.TurnRate = LARA_CRAWL_MOVE_TURN_MAX;

		DoLaraCrawlFlex(item, coll, -LARA_CRAWL_FLEX_MAX, LARA_CRAWL_FLEX_RATE);
	}

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_BACK)
		{
			item->TargetState = LS_CRAWL_BACK;
			return;
		}

		item->TargetState = LS_CRAWL_IDLE;
		return;
	}

	item->TargetState = LS_CRAWL_IDLE;
}

// State:		LS_CRAWL_BACK (86)
// Control:		lara_as_crawl_back()
void lara_col_crawl_back(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.KeepLow = TestLaraKeepLow(item, coll);
	info->Control.IsLow = true;
	info->Control.MoveAngle = item->Position.yRot + ANGLE(180.0f);
	item->Airborne = false;
	item->VerticalVelocity = 0;
	coll->Setup.Radius = LARA_RAD_CRAWL;
	coll->Setup.Height = LARA_HEIGHT_CRAWL;
	coll->Setup.LowerFloorBound = CLICK(1) - 1;		// Offset of 1 is required or Lara will crawl up/down steps.
	coll->Setup.UpperFloorBound = -(CLICK(1) - 1);
	coll->Setup.LowerCeilingBound = LARA_HEIGHT_CRAWL;
	coll->Setup.FloorSlopeIsPit = true;
	coll->Setup.FloorSlopeIsWall = true;
	coll->Setup.DeathFlagIsPit = true;
	coll->Setup.ForwardAngle = info->Control.MoveAngle;
	GetCollisionInfo(coll, item, true);

	if (LaraDeflectEdgeCrawl(item, coll))
		LaraCollideStopCrawl(item, coll);

	if (TestLaraFall(item, coll))
	{
		SetLaraFallState(item);
		return;
	}

	if (TestLaraSlide(item, coll))
	{
		SetLaraSlideState(item, coll);
		return;
	}

	ShiftItem(item, coll);

	if (TestLaraStep(item, coll))
	{
		DoLaraStep(item, coll);
		return;
	}
}

// State:		LS_CRAWL_TURN_LEFT (84)
// Collision:	lara_col_crawl_turn_left()
void lara_as_crawl_turn_left(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.HandStatus = HandStatus::Busy;
	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	info->Control.TurnRate = -LARA_CRAWL_TURN_MAX;

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll))
		{
			item->TargetState = LS_CRAWL_IDLE;
			return;
		}

		if (TrInput & IN_FORWARD && TestLaraCrawlForward(item, coll))
		{
			item->TargetState = LS_CRAWL_FORWARD;
			return;
		}

		if (TrInput & IN_BACK && TestLaraCrawlBack(item, coll))
		{
			item->TargetState = LS_CRAWL_BACK;
			return;
		}

		if (TrInput & IN_LEFT)
		{
			item->TargetState = LS_CRAWL_TURN_LEFT;
			return;
		}

		item->TargetState = LS_CRAWL_IDLE;
		return;
	}

	item->TargetState = LS_CRAWL_IDLE;
}

// State:		LS_CRAWL_TURN_LEFT (84)
// Control:		lara_as_crawl_turn_left()
void lara_col_crawl_turn_left(ITEM_INFO* item, COLL_INFO* coll)
{
	lara_col_crawl_idle(item, coll);
}

// State:		LS_CRAWL_TURN_RIGHT (85)
// Collision:	lara_col_crawl_turn_right()
void lara_as_crawl_turn_right(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	info->Control.HandStatus = HandStatus::Busy;
	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetElevation = -ANGLE(24.0f);

	if (item->HitPoints <= 0)
	{
		item->TargetState = LS_DEATH;
		return;
	}

	info->Control.TurnRate = LARA_CRAWL_TURN_MAX;

	if ((TrInput & IN_CROUCH || info->Control.KeepLow) &&
		info->Control.WaterStatus != WaterStatus::Wade)
	{
		if (TrInput & IN_SPRINT && TestLaraCrouchRoll(item, coll))
		{
			item->TargetState = LS_CRAWL_IDLE;
			return;
		}

		if (TrInput & IN_FORWARD && TestLaraCrawlForward(item, coll))
		{
			item->TargetState = LS_CRAWL_FORWARD;
			return;
		}

		if (TrInput & IN_BACK && TestLaraCrawlBack(item, coll))
		{
			item->TargetState = LS_CRAWL_BACK;
			return;
		}

		if (TrInput & IN_RIGHT)
		{
			item->TargetState = LS_CRAWL_TURN_RIGHT;
			return;
		}

		item->TargetState = LS_CRAWL_IDLE;
		return;
	}

	item->TargetState = LS_CRAWL_IDLE;
}

// State:		LS_CRAWL_TURN_RIGHT (85)
// Control:		lara_as_crawl_turn_right()
void lara_col_crawl_turn_right(ITEM_INFO* item, COLL_INFO* coll)
{
	lara_col_crawl_idle(item, coll);
}

void lara_col_crawl_to_hang(ITEM_INFO* item, COLL_INFO* coll)
{
	auto* info = GetLaraInfo(item);

	coll->Setup.EnableObjectPush = true;
	coll->Setup.EnableSpasm = false;
	Camera.targetAngle = 0;
	Camera.targetElevation = -ANGLE(45.0f);

	if (item->AnimNumber == LA_CRAWL_TO_HANG_END)
	{
		info->Control.MoveAngle = item->Position.yRot;
		coll->Setup.Height = LARA_HEIGHT_STRETCH;
		coll->Setup.LowerFloorBound = NO_LOWER_BOUND;
		coll->Setup.UpperFloorBound = -STEPUP_HEIGHT;
		coll->Setup.LowerCeilingBound = BAD_JUMP_CEILING;
		coll->Setup.ForwardAngle = info->Control.MoveAngle;

		MoveItem(item, item->Position.yRot, -CLICK(1));
		GetCollisionInfo(coll, item);
		SnapItemToLedge(item, coll);
		SetAnimation(item, LA_REACH_TO_HANG, 12);

		GetCollisionInfo(coll, item);
		info->Control.HandStatus = HandStatus::Busy;
		item->Position.yPos += coll->Front.Floor - GetBoundsAccurate(item)->Y1 - 20;
		item->Airborne = true;
		item->Velocity = 2;
		item->VerticalVelocity = 1;
	}
}
