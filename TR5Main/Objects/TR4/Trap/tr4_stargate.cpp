#include "framework.h"
#include "tr4_stargate.h"
#include "Specific/level.h"
#include "Game/control/control.h"
#include "Sound/sound.h"
#include "Game/collision/collide_room.h"
#include "Game/collision/collide_item.h"
#include "Game/collision/sphere.h"
#include "Game/Lara/lara.h"
#include "Game/effects/effects.h"
#include "Game/animation.h"
#include "Game/items.h"

namespace TEN::Entities::TR4
{
	short StargateBounds[24] =
	{
		-512, 512, -1024, 
		-896, -96, 96, 
		-512, 512, -128, 
		0, -96, 96, 
		-512, -384, -1024, 
		0, -96, 96, 
		384, 512, -1024, 
		0, -96, 96
	};

	void StargateControl(short itemNum)
	{
		ITEM_INFO* item = &g_Level.Items[itemNum];
		item->ItemFlags[3] = 50;

		if (TriggerActive(item))
		{
			SoundEffect(SFX_TR4_STARGATE_SWIRL, &item->Position, 0);
			item->ItemFlags[0] = 0x36DB600;
			AnimateItem(item);
		}
		else
		{
			item->ItemFlags[0] = 0;
		}
	}

	void StargateCollision(short itemNum, ITEM_INFO* l, COLL_INFO* c)
	{
		ITEM_INFO* item = &g_Level.Items[itemNum];

		if (item->Status == ITEM_INVISIBLE)
			return;

		if (TestBoundsCollide(item, l, c->Setup.Radius))
		{
			for (int i = 0; i < 8; i++)
			{
				GlobalCollisionBounds.X1 = StargateBounds[3 * i + 0];
				GlobalCollisionBounds.Y1 = StargateBounds[3 * i + 1];
				GlobalCollisionBounds.Z1 = StargateBounds[3 * i + 2];

				if (TestWithGlobalCollisionBounds(item, l, c))
					ItemPushItem(item, l, c, 0, 2);
			}

			int result = TestCollision(item, l);
			if (result)
			{
				result &= item->ItemFlags[0];
				int flags = item->ItemFlags[0];

				if (result)
				{
					int j = 0;
					do
					{
						if (result & 1)
						{
							GlobalCollisionBounds.X1 = CreatureSpheres[j].x - CreatureSpheres[j].r - item->Position.xPos;
							GlobalCollisionBounds.Y1 = CreatureSpheres[j].y - CreatureSpheres[j].r - item->Position.yPos;
							GlobalCollisionBounds.Z1 = CreatureSpheres[j].z - CreatureSpheres[j].r - item->Position.zPos;
							GlobalCollisionBounds.X2 = CreatureSpheres[j].x + CreatureSpheres[j].r - item->Position.xPos;
							GlobalCollisionBounds.Y2 = CreatureSpheres[j].y + CreatureSpheres[j].r - item->Position.yPos;
							GlobalCollisionBounds.Z2 = CreatureSpheres[j].z + CreatureSpheres[j].r - item->Position.zPos;

							int oldX = LaraItem->Position.xPos;
							int oldY = LaraItem->Position.yPos;
							int oldZ = LaraItem->Position.zPos;

							if (ItemPushItem(item, l, c, flags & 1, 2))
							{
								if ((flags & 1) &&
									(oldX != LaraItem->Position.xPos 
									|| oldY != LaraItem->Position.yPos 
									|| oldZ != LaraItem->Position.zPos) &&
									TriggerActive(item))
								{
									DoBloodSplat((GetRandomControl() & 0x3F) + l->Position.xPos - 32,
										(GetRandomControl() & 0x1F) + CreatureSpheres[j].y - 16,
										(GetRandomControl() & 0x3F) + l->Position.zPos - 32,
										(GetRandomControl() & 3) + 2,
										2 * GetRandomControl(),
										l->RoomNumber);
									LaraItem->HitPoints -= 100;
								}
							}
						}

						result /= 2;
						j++;
						flags /= 2;

					} while (result);
				}
			}
		}
	}
}