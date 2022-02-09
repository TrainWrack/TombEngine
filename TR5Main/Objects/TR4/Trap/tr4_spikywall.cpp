#include "framework.h"
#include "tr4_spikywall.h"
#include "Specific/level.h"
#include "Game/control/control.h"
#include "Sound/sound.h"
#include "Game/Lara/lara.h"
#include "Game/items.h"
#include "Game/effects/effects.h"

void ControlSpikyWall(short itemNum)
{
	ITEM_INFO* item = &g_Level.Items[itemNum];

	/* Move wall */
	if (TriggerActive(item) && item->Status != ITEM_DEACTIVATED)
	{
		int x = item->Position.xPos + phd_sin(item->Position.yRot);
		int z = item->Position.zPos + phd_cos(item->Position.yRot);

		short roomNumber = item->RoomNumber;
		FLOOR_INFO* floor = GetFloor(x, item->Position.yPos, z, &roomNumber);

		if (GetFloorHeight(floor, x, item->Position.yPos, z) != item->Position.yPos)
		{
			item->Status = ITEM_DEACTIVATED;
			StopSoundEffect(SFX_TR4_ROLLING_BALL);
		}
		else
		{
			item->Position.xPos = x;
			item->Position.zPos = z;
			if (roomNumber != item->RoomNumber)
				ItemNewRoom(itemNum, roomNumber);
			SoundEffect(SFX_TR4_ROLLING_BALL, &item->Position, 0);
		}
	}

	if (item->TouchBits)
	{
		LaraItem->HitPoints -= 15;
		LaraItem->HitStatus = true;

		DoLotsOfBlood(LaraItem->Position.xPos, LaraItem->Position.yPos - 512, LaraItem->Position.zPos, 4, item->Position.yRot, LaraItem->RoomNumber, 3);
		item->TouchBits = 0;

		SoundEffect(56, &item->Position, 0);
	}
}