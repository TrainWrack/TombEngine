#include "framework.h"
#include "Game/misc.h"

#include "Game/animation.h"
#include "Game/Lara/lara.h"
#include "Game/itemdata/creature_info.h"
#include "Game/items.h"
#include "Specific/setup.h"
#include "Specific/level.h"

using std::vector;

CREATURE_INFO* GetCreatureInfo(ITEM_INFO* item)
{
    return (CREATURE_INFO*)item->Data;
}

void TargetNearestEntity(ITEM_INFO* item, CREATURE_INFO* creature)
{
	int bestDistance = MAXINT;
	for (int i = 0; i < g_Level.NumItems; i++)
	{
		auto* target = &g_Level.Items[i];

		if (target == nullptr)
			continue;

		if (target != item &&
			target->HitPoints > 0 &&
			target->Status != ITEM_INVISIBLE)
		{
			int x = target->Position.xPos - item->Position.xPos;
			int y = target->Position.yPos - item->Position.yPos;
			int z = target->Position.zPos - item->Position.zPos;

			int distance = pow(x, 2) + pow(y, 2) + pow(z, 2);
			if (distance < bestDistance)
			{
				creature->enemy = target;
				bestDistance = distance;
			}
		}
	}
}
