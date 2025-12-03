#include "framework.h"
#include "Objects/TR4/Floor/BurningFloor.h"

#include "Game/collision/collide_item.h"
#include "Game/control/trigger.h"
#include "Game/effects/debris.h"
#include "Game/effects/item_fx.h"
#include "Game/effects/tomb4fx.h"
#include "Game/effects/weather.h"
#include "Game/Lara/lara.h"
#include "Game/Lara/lara_helpers.h"
#include "Game/Setup.h"
#include "Specific/level.h"


using namespace TEN::Effects::Environment;
using namespace TEN::Effects::Items;

enum BurningFloorItemFlags
{
	LowerMesh = 0,
	UpperMesh = 1,
	StartMesh = 2,
	Timeout = 3
};

namespace TEN::Entities::TR4
{
	void InitializeBurningFloor(short itemNumber)
	{
		auto item = &g_Level.Items[itemNumber];
		item->Animation.TargetState = 127;
		item->Status = ITEM_ACTIVE;
	}

	void BurningFloorControl(short itemNumber)
	{
		short deadly_floor_fires[4 * 2] =	//4 points on the burning floor that kill Lara if she is too close at explode time
		{
			//xoff, zoff
			-512, -512,
			0, 0,
			512, 512,
			0, 768
		};

		short floor_fires[16 * 3] =		//16 points on the burning floor that spawn fires!
		{
			//xoff, zoff, size
			-96, 1216, 2,
			560, 736, 2,
			-432, -976, 2,
			-64, -128, 2,
			824, 64, 2,
			456, -352, 1,
			392, 352, 1,
			1096, 608, 1,
			-424, -416, 1,
			520, 1152, 1,
			-248, 516, 1,
			-808, 80, 1,
			-1192, -384, 0,
			-904, -864, 0,
			-136, -912, 0,
			184, 608, 0
		};

		bool spheresComputed = false;
		std::vector<BoundingSphere> nSpheres;
		long dx, dy, dz;
		short torch_num, xoff, zoff, size;
		auto* item = &g_Level.Items[itemNumber];;
		auto flipMap = item->TriggerFlags;

		if (!item->ItemFlags[3])
		{
			spheresComputed = false;
			torch_num = g_Level.Rooms[item->RoomNumber].itemNumber;

			while (true)
			{
				auto torch = &g_Level.Items[torch_num];

				if (torch->ObjectNumber == ID_BURNING_TORCH_ITEM && !torch->Animation.Velocity.z && !torch->Animation.Velocity.y && torch->ItemFlags[3])
				{	
					if (!spheresComputed)
					{
						nSpheres = item->GetSpheres();
						spheresComputed = true;
					}

					for (int i = 0; i < nSpheres.size(); i++)
					{
						auto sphere = &nSpheres[i];
						dx = sphere->Center.x - torch->Pose.Position.x;
						dy = sphere->Center.y - torch->Pose.Position.y;
						dz = sphere->Center.z - torch->Pose.Position.z;

						if (SQUARE(dx) + SQUARE(dy) + SQUARE(dz) > SQUARE(sphere->Radius + 32))
						{
							item->ItemFlags[3] = 1;
							KillItem(torch_num);
							return;
						}
					}
				}

				torch_num = torch->NextItem;

				if (torch_num == NO_VALUE)
					return;
			}
		}

		for (int i = 0; i < 15; i++)
		{
			xoff = floor_fires[(i * 3) + 0];
			zoff = floor_fires[(i * 3) + 1];
			size = floor_fires[(i * 3) + 2];

			if (item->ItemFlags[size])
			{
				TENLog("Fire addition started", LogLevel::Warning);
				AddFire(item->Pose.Position.x + xoff, item->Pose.Position.y - (size << 6) - 64, item->Pose.Position.z + zoff,
					item->RoomNumber, size, item->ItemFlags[size]);
			}
		}

		if (LaraItem->Effect.Type != EffectType::Fire)
		{
			for (int i = 0; i < 3; i++)
			{
				xoff = deadly_floor_fires[(i * 2) + 0];
				zoff = deadly_floor_fires[(i * 2) + 1];
				dx = abs(item->Pose.Position.x + xoff - LaraItem->Pose.Position.x);
				dy = abs(item->Pose.Position.y - LaraItem->Pose.Position.y);
				dz = abs(item->Pose.Position.z + zoff - LaraItem->Pose.Position.z);

				if (dx < 200 && dy < 200 && dz < 200)
				{
					ItemBurn(LaraItem);
					LaraItem->HitPoints = 100;
					item->ItemFlags[3] = 450;
					item->ItemFlags[0] = 2;
					item->ItemFlags[1] = 2;
					item->ItemFlags[2] = 2;
					Weather.Flash(255, 64, 0, 0.5);
				}
			}
		}

		if (item->ItemFlags[3] < 450)
		{
			item->ItemFlags[0] += 4;

			if (item->ItemFlags[3] > 30)
				item->ItemFlags[1] += 4;

			if (item->ItemFlags[3] > 60)
				item->ItemFlags[2] += 8;

			if (item->ItemFlags[0] > 255)
				item->ItemFlags[0] = 255;

			if (item->ItemFlags[1] > 255)
				item->ItemFlags[1] = 255;

			if (item->ItemFlags[2] > 255)
				item->ItemFlags[2] = 255;

			item->ItemFlags[3]++;
			item->Animation.TargetState = 127 - item->ItemFlags[3] / 6;
		}
		else
		{
			item->ItemFlags[0] -= 4;
			item->ItemFlags[1] -= 3;
			item->ItemFlags[2] -= 2;

			if (item->ItemFlags[0] < 2)
				item->ItemFlags[0] = 2;

			if (item->ItemFlags[1] < 2)
				item->ItemFlags[1] = 2;

			if (item->ItemFlags[2] < 2)
				item->ItemFlags[2] = 2;

			if (item->ItemFlags[0] == 2 && item->ItemFlags[1] == 2 && item->ItemFlags[2] == 2)
			{
				DoFlipMap(flipMap);
				ExplodeItemNode(item, 0, 1, -24);
				ExplodeItemNode(item, 1, 1, -24);
				ExplodeItemNode(item, 2, 1, -24);
				ExplodeItemNode(item, 3, 1, -24);
				ExplodeItemNode(item, 4, 1, -32);
				KillItem(itemNumber);
			}
		}
	}
}