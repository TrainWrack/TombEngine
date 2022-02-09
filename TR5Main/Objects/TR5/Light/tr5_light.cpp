#include "framework.h"
#include "tr5_light.h"
#include "Specific/level.h"
#include "Game/control/los.h"
#include "Game/effects/effects.h"
#include "Sound/sound.h"
#include "Specific/trmath.h"
#include "Game/animation.h"
#include "Game/items.h"

void PulseLightControl(short itemNumber)
{
	ITEM_INFO* item = &g_Level.Items[itemNumber];

	if (TriggerActive(item))
	{
		item->ItemFlags[0] -= 1024;

		long pulse = 256 * phd_sin(item->ItemFlags[0] + 4 * (item->Position.yPos & 0x3FFF));
		pulse = abs(pulse);
		if (pulse > 255)
			pulse = 255;

		TriggerDynamicLight(
			item->Position.xPos,
			item->Position.yPos,
			item->Position.zPos,
			24,
			(pulse * 8 * (item->TriggerFlags & 0x1F)) / 512,
			(pulse * ((item->TriggerFlags / 4) & 0xF8)) / 512,
			(pulse * ((item->TriggerFlags / 128) & 0xF8)) / 512);
	}
}

void TriggerAlertLight(int x, int y, int z, int r, int g, int b, int angle, short room, int falloff)
{
	GAME_VECTOR source, target;

	source.x = x;
	source.y = y;
	source.z = z;
	GetFloor(x, y, z, &room);
	source.roomNumber = room;
	target.x = x + 16384 * phd_sin(16 * angle);
	target.y = y;
	target.z = z + 16384 * phd_cos(16 * angle);
	if (!LOS(&source, &target))
		TriggerDynamicLight(target.x, target.y, target.z, falloff, r, g, b);
}

void StrobeLightControl(short itemNumber)
{
	ITEM_INFO* item = &g_Level.Items[itemNumber];

	if (TriggerActive(item))
	{
		item->Position.yRot += ANGLE(16.0f);

		byte r = 8 * (item->TriggerFlags & 0x1F);
		byte g = (item->TriggerFlags / 4) & 0xF8;
		byte b = (item->TriggerFlags / 128) & 0xF8;

		TriggerAlertLight(
			item->Position.xPos,
			item->Position.yPos - 512,
			item->Position.zPos,
			r, g, b,
			((item->Position.yRot + 22528) / 16) & 0xFFF,
			item->RoomNumber,
			12);

		TriggerDynamicLight(
			item->Position.xPos + 256 * phd_sin(item->Position.yRot + 22528),
			item->Position.yPos - 768,
			item->Position.zPos + 256 * phd_cos(item->Position.yRot + 22528),
			8,
			r, g, b);
	}
}

void ColorLightControl(short itemNumber)
{
	ITEM_INFO* item = &g_Level.Items[itemNumber];

	if (TriggerActive(item))
	{
		TriggerDynamicLight(
			item->Position.xPos,
			item->Position.yPos,
			item->Position.zPos,
			24,
			8 * (item->TriggerFlags & 0x1F),
			(item->TriggerFlags / 4) & 0xF8,
			(item->TriggerFlags / 128) & 0xF8);
	}
}

void ElectricalLightControl(short itemNumber)
{
	ITEM_INFO* item = &g_Level.Items[itemNumber];

	if (!TriggerActive(item))
	{
		item->ItemFlags[0] = 0;
		return;
	}

	int intensity = 0;

	if (item->TriggerFlags > 0)
	{
		if (item->ItemFlags[0] < 16)
		{
			intensity = 4 * (GetRandomControl() & 0x3F);
			item->ItemFlags[0]++;
		}
		else if (item->ItemFlags[0] >= 96)
		{
			if (item->ItemFlags[0] >= 160)
			{
				intensity = 255 - (GetRandomControl() & 0x1F);
			}
			else
			{
				intensity = 96 - (GetRandomControl() & 0x1F);
				if (!(GetRandomControl() & 0x1F) && item->ItemFlags[0] > 128)
				{
					item->ItemFlags[0] = 160;
				}
				else
				{
					item->ItemFlags[0]++;
				}
			}
		}
		else
		{
			if (Wibble & 0x3F && GetRandomControl() & 7)
			{
				intensity = GetRandomControl() & 0x3F;
				item->ItemFlags[0]++;
			}
			else
			{
				intensity = 192 - (GetRandomControl() & 0x3F);
				item->ItemFlags[0]++;
			}
		}
	}
	else
	{
		if (item->ItemFlags[0] <= 0)
		{
			item->ItemFlags[0] = (GetRandomControl() & 3) + 4;
			item->ItemFlags[1] = (GetRandomControl() & 0x7F) + 128;
			item->ItemFlags[2] = GetRandomControl() & 1;
		}

		item->ItemFlags[0]--;

		if (!item->ItemFlags[2])
		{
			item->ItemFlags[0]--;

			intensity = item->ItemFlags[1] - (GetRandomControl() & 0x7F);
			if (intensity > 64)
				SoundEffect(SFX_TR5_ELEC_LIGHT_CRACKLES, &item->Position, 32 * (intensity & 0xFFFFFFF8) | 8);
		}
		else
		{
			return;
		}
	}

	TriggerDynamicLight(
		item->Position.xPos,
		item->Position.yPos,
		item->Position.zPos,
		24,
		(intensity * 8 * (item->TriggerFlags & 0x1F)) / 256,
		(intensity * ((item->TriggerFlags / 4) & 0xF8)) / 256,
		(intensity * ((item->TriggerFlags / 128) & 0xF8)) / 256);
}

void BlinkingLightControl(short itemNumber)
{
	ITEM_INFO* item = &g_Level.Items[itemNumber];

	if (TriggerActive(item))
	{
		item->ItemFlags[0]--;

		if (item->ItemFlags[0] >= 3)
		{
			item->MeshBits = 1;
		}
		else
		{
			PHD_VECTOR pos;
			pos.x = 0;
			pos.y = 0;
			pos.z = 0;
			GetJointAbsPosition(item, &pos, 0);

			TriggerDynamicLight(
				pos.x,
				pos.y,
				pos.z,
				16,
				8 * (item->TriggerFlags & 0x1F),
				(item->TriggerFlags / 4) & 0xF8,
				(item->TriggerFlags / 128) & 0xF8);

			item->MeshBits = 2;

			if (item->ItemFlags[0] < 0)
				item->ItemFlags[0] = 30;
		}
	}
}