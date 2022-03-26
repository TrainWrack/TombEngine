#include "framework.h"
#include "tr4_mine.h"
#include "Specific/level.h"
#include "Game/collision/sphere.h"
#include "Sound/sound.h"
#include "Game/effects/effects.h"
#include "Game/effects/tomb4fx.h"
#include "Game/effects/weather.h"
#include "Game/items.h"
#include "Game/collision/collide_item.h"
#include "Objects/objectslist.h"

using namespace TEN::Effects::Environment;

namespace TEN::Entities::TR4
{
	void InitialiseMine(short itemNumber)
	{
		auto* item = &g_Level.Items[itemNumber];

		if (item->TriggerFlags)
			item->MeshBits = 0;
	}

	void MineControl(short itemNumber)
	{
		auto* item = &g_Level.Items[itemNumber];

		int num = GetSpheres(item, CreatureSpheres, SPHERES_SPACE_WORLD, Matrix::Identity);
		if (item->ItemFlags[0] >= 150)
		{
			SoundEffect(SFX_TR4_EXPLOSION1, &item->Position, 0);
			SoundEffect(SFX_TR4_EXPLOSION2, &item->Position, 0);
			SoundEffect(SFX_TR4_EXPLOSION1, &item->Position, 0, 0.7f, 0.5f);

			if (num > 0)
			{
				for (int i = 0; i < num; i++)
				{
					if (i >= 7 && i != 9)
					{
						auto* sphere = &CreatureSpheres[i];

						TriggerExplosionSparks(sphere->x, sphere->y, sphere->z, 3, -2, 0, -item->RoomNumber);
						TriggerExplosionSparks(sphere->x, sphere->y, sphere->z, 3, -1, 0, -item->RoomNumber);
						TriggerShockwave((PHD_3DPOS*)sphere, 48, 304, (GetRandomControl() & 0x1F) + 112, 0, 96, 128, 32, 2048, 0);
					}
				}

				for (int i = 0; i < num; i++)
					ExplodeItemNode(item, i, 0, -128);
			}

			Weather.Flash(255, 192, 64, 0.03f);

			short currentItemNumber = g_Level.Rooms[item->RoomNumber].itemNumber;

			// Make the sentry gun explode?
			while (currentItemNumber != NO_ITEM)
			{
				auto* currentItem = &g_Level.Items[currentItemNumber];

				if (currentItem->ObjectNumber == ID_SENTRY_GUN)
					currentItem->MeshBits &= ~0x40;

				currentItemNumber = currentItem->NextItem;
			}

			KillItem(itemNumber);
		}
		else
		{
			item->ItemFlags[0]++;

			int fireOn = 4 * item->ItemFlags[0];
			if (fireOn > 255)
				fireOn = 0;

			for (int i = 0; i < num; i++)
			{
				if (i == 0 || i > 5)
				{
					auto* sphere = &CreatureSpheres[i];
					AddFire(sphere->x, sphere->y, sphere->z, 2, item->RoomNumber, fireOn);
				}
			}

			SoundEffect(SFX_TR4_LOOP_FOR_SMALL_FIRES, &item->Position, 0);
		}
	}

	void MineCollision(short itemNumber, ITEM_INFO* laraItem, CollisionInfo* coll)
	{
		auto* mineItem = &g_Level.Items[itemNumber];

		if (mineItem->TriggerFlags && !mineItem->ItemFlags[3])
		{
			if (laraItem->Animation.AnimNumber != LA_DETONATOR_USE ||
				laraItem->Animation.FrameNumber < g_Level.Anims[laraItem->Animation.AnimNumber].FrameBase + 57)
			{
				if (TestBoundsCollide(mineItem, laraItem, 512))
				{
					TriggerExplosionSparks(mineItem->Position.xPos, mineItem->Position.yPos, mineItem->Position.zPos, 3, -2, 0, mineItem->RoomNumber);
					for (int i = 0; i < 2; i++)
						TriggerExplosionSparks(mineItem->Position.xPos, mineItem->Position.yPos, mineItem->Position.zPos, 3, -1, 0, mineItem->RoomNumber);

					mineItem->MeshBits = 1;

					ExplodeItemNode(mineItem, 0, 0, 128);
					KillItem(itemNumber);

					laraItem->Animation.AnimNumber = LA_MINE_DEATH;
					laraItem->Animation.FrameNumber = g_Level.Anims[mineItem->Animation.AnimNumber].FrameBase;
					laraItem->Animation.ActiveState = LS_DEATH;
					laraItem->Animation.Velocity = 0;

					SoundEffect(SFX_TR4_MINE_EXP_OVERLAY, &mineItem->Position, 0);
				}
			}
			else
			{
				for (int i = 0; i < g_Level.NumItems; i++)
				{
					auto* currentItem = &g_Level.Items[i];

					// Explode other mines
					if (currentItem->ObjectNumber == ID_MINE &&
						currentItem->Status != ITEM_INVISIBLE &&
						currentItem->TriggerFlags == 0)
					{
						TriggerExplosionSparks(
							currentItem->Position.xPos,
							currentItem->Position.yPos,
							currentItem->Position.zPos,
							3,
							-2,
							0,
							currentItem->RoomNumber);

						for (int j = 0; j < 2; j++)
							TriggerExplosionSparks(
								currentItem->Position.xPos,
								currentItem->Position.yPos,
								currentItem->Position.zPos,
								3,
								-1,
								0,
								currentItem->RoomNumber);

						currentItem->MeshBits = 1;

						ExplodeItemNode(currentItem, 0, 0, -32);
						KillItem(i);

						if (!(GetRandomControl() & 3))
							SoundEffect(SFX_TR4_MINE_EXP_OVERLAY, &currentItem->Position, 0);

						currentItem->Status = ITEM_INVISIBLE;
					}
				}
			}
		}
	}
}
