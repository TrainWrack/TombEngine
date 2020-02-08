#include "../oldobjects.h"
#include "../../Game/items.h"
#include "../../Game/sphere.h"
#include "../../Game/Box.h"
#include "../../Game/effects.h"
#include "../../Game/effect2.h"
#include "../../Game/people.h"
#include "../../Game/draw.h"

BITE_INFO HydraBite{ 0, 0, 0, 0x0B };

void InitialiseHydra(short itemNum)
{
    ITEM_INFO* item;

    item = &Items[itemNum];
    ClearItem(itemNum);
    item->animNumber = Objects[item->objectNumber].animIndex;
    item->frameNumber = 30 * item->triggerFlags + Anims[item->animNumber].frameBase;
    item->goalAnimState = 0;
    item->currentAnimState = 0;

    if (item->triggerFlags == 1)
        item->pos.zPos += STEPUP_HEIGHT;

    if (item->triggerFlags == 2)
        item->pos.zPos -= STEPUP_HEIGHT;

    item->pos.yRot = ANGLE(90);
    item->pos.xPos -= STEP_SIZE;
}

void HydraBubblesAttack(PHD_3DPOS* pos, short roomNumber, int count)
{
	short fxNum = CreateNewEffect(roomNumber);
	if (fxNum != NO_ITEM)
	{
		FX_INFO* fx = &Effects[fxNum];
		fx->pos.xPos = pos->xPos;
		fx->pos.yPos = pos->yPos - (GetRandomControl() & 0x3F) - 32;
		fx->pos.zPos = pos->zPos;
		fx->pos.xRot = pos->xRot;
		fx->pos.yRot = pos->yRot;
		fx->pos.zRot = 0;
		fx->roomNumber = roomNumber;
		fx->counter = 16 * count + 15;
		fx->flag1 = 0;
		fx->objectNumber = ID_BUBBLES;
		fx->speed = (GetRandomControl() & 0x1F) + 64;
		fx->frameNumber = Objects[ID_BUBBLES].meshIndex + 16;
	}
}

void TriggerHydraSparks(short itemNumber, int frame)
{
	SPARKS* spark = &Sparks[GetFreeSpark()];
	
	spark->on = 1;
	spark->sB = 0;
	spark->sR = (GetRandomControl() & 0x3F) - 96;
	spark->dR = (GetRandomControl() & 0x3F) - 96;
	spark->dB = 0;
	if (frame < 16)
	{
		spark->sR = frame * spark->sR >> 4;
		spark->dR = frame * spark->dR >> 4;
	}
	spark->sG = spark->sR >> 1;
	spark->dG = spark->dR >> 1;
	spark->fadeToBlack = 4;
	spark->colFadeSpeed = (GetRandomControl() & 3) + 8;
	spark->transType = COLADD;
	spark->dynamic = -1;
	spark->life = spark->sLife = (GetRandomControl() & 3) + 32;
	spark->y = 0;
	spark->x = (GetRandomControl() & 0xF) - 8;
	spark->z = (GetRandomControl() & 0xF) - 8;
	spark->yVel = 0;
	spark->xVel = GetRandomControl() - 128;
	spark->friction = 4;
	spark->zVel = GetRandomControl() - 128;
	spark->flags = 4762;
	spark->fxObj = itemNumber;
	spark->nodeNumber = 5;
	spark->rotAng = GetRandomControl() & 0xFFF;
	spark->rotAdd = (GetRandomControl() & 0x3F) - 32;
	spark->maxYvel = 0;
	spark->gravity = -8 - (GetRandomControl() & 7);
	spark->scalar = 0;
	spark->dSize = 4;
	spark->sSize = spark->size = frame * ((GetRandomControl() & 0xF) + 16) >> 4;
}

void ControlHydra(short itemNumber)
{
	if (CreatureActive(itemNumber))
	{
		short tilt = 0;
		short joint3 = 0;
		short joint2 = 0;
		short joint1 = 0;
		short joint0 = 0;
		
		ITEM_INFO* item = &Items[itemNumber];
		CREATURE_INFO* creature = (CREATURE_INFO*)item->data;

		if (item->hitPoints > 0)
		{
			if (item->aiBits)
			{
				GetAITarget(creature);
			}
			else if (creature->hurtByLara)
			{
				creature->enemy = LaraItem;
			}

			AI_INFO info;
			CreatureAIInfo(item, &info);

			GetCreatureMood(item, &info, VIOLENT);
			CreatureMood(item, &info, VIOLENT);

			if (item->currentAnimState != 5 && item->currentAnimState != 10 && item->currentAnimState != 11)
			{
				if (abs(info.angle) >= ANGLE(1))
				{
					if (info.angle > 0)
						item->pos.yRot += ANGLE(1);
					else
						item->pos.yRot -= ANGLE(1);
				}
				else
				{
					item->pos.yRot += info.angle;
				}

				if (item->triggerFlags == 1)
				{
					tilt = -512;
				}
				else if (item->triggerFlags == 2)
				{
					tilt = 512;
				}
			}

			if (item->currentAnimState != 12)
			{
				joint1 = info.angle >> 1;
				joint3 = info.angle >> 1;
				joint2 = -info.xAngle;
			}

			joint0 = -joint1;

			int distance, damage, frame;
			PHD_VECTOR pos1, pos2;
			short angles[2];
			short roomNumber;
			PHD_3DPOS pos;

			switch (item->currentAnimState)
			{
			case 0:
				creature->maximumTurn = ANGLE(1);
				creature->flags = 0;
				
				if (item->triggerFlags == 1)
				{
					tilt = -512;
				}
				else if (item->triggerFlags == 2)
				{
					tilt = 512;
				}

				if (info.distance >= SQUARE(1792) && GetRandomControl() & 0x1F)
				{
					if (info.distance >= SQUARE(2048) && GetRandomControl() & 0x1F)
					{
						if (!(GetRandomControl() & 0xF))
							item->goalAnimState = 2;
					}
					else
					{
						item->goalAnimState = 1;
					}
				}
				else
				{
					item->goalAnimState = 6;
				}
				break;

			case 1:
			case 7:
			case 8:
			case 9:	
				creature->maximumTurn = 0;
				
				if (creature->flags == 0)
				{
					if (item->touchBits & 0x400)
					{
						LaraItem->hitPoints -= 120;
						LaraItem->hitStatus = true;
						CreatureEffect2(item, &HydraBite, 10, item->pos.yRot, DoBloodSplat);
						creature->flags = 1;
					}
					if (item->hitStatus && info.distance < SQUARE(1792))
					{
						distance = SQRT_ASM(info.distance);
						damage = 5 - distance / 1024;

						if (Lara.gunType == WEAPON_SHOTGUN)
							damage *= 3;

						if (damage > 0)
						{
							item->hitPoints -= damage;
							item->goalAnimState = 4;
							CreatureEffect2(item, &HydraBite, 10 * damage, item->pos.yRot, DoBloodSplat);
						}
					}
				}
				break;

			case 2:
				creature->maximumTurn = 0;

				if (item->hitStatus)
				{
					damage = 6 - SQRT_ASM(info.distance) / 1024;

					if (Lara.gunType == WEAPON_SHOTGUN)
						damage *= 3;

					if ((GetRandomControl() & 0xF) < damage && info.distance < SQUARE(10240) && damage > 0)
					{
						item->hitPoints -= damage;
						item->goalAnimState = 4;
						CreatureEffect2(item, &HydraBite, 10 * damage, item->pos.yRot, DoBloodSplat);
					}
				}

				if (item->triggerFlags == 1)
				{
					tilt = -512;
				}
				else if (item->triggerFlags == 2)
				{
					tilt = 512;
				}

				if (!(GlobalCounter & 3))
				{
					frame = ((Anims[item->animNumber].frameBase - item->frameNumber) >> 3) + 1;
					if (frame > 16)
						frame = 16;
					TriggerHydraSparks(itemNumber, frame);
				}
				break;

			case 3:
				if (item->frameNumber == Anims[item->animNumber].frameBase)
				{
					pos1.x = 0;
					pos1.y = 1024;
					pos1.z = 40;
					GetJointAbsPosition(item, &pos1, 10);

					pos2.x = 0;
					pos2.y = 144;
					pos2.z = 40;
					GetJointAbsPosition(item, &pos2, 10);

					phd_GetVectorAngles(pos1.x - pos2.x, pos1.y - pos2.y, pos1.z - pos2.z, angles);
					
					pos.xPos = pos1.x;
					pos.yPos = pos1.y;
					pos.zPos = pos1.z;
					pos.xRot = angles[1];
					pos.yRot = angles[2];
					pos.zRot = 0;
					
					roomNumber = item->roomNumber;
					GetFloor(pos2.x, pos2.y, pos2.z, &roomNumber);
					
					HydraBubblesAttack(&pos, roomNumber, 1);
				}
				break;

			case 6:
				creature->maximumTurn = ANGLE(1);
				creature->flags = 0;
				
				if (item->triggerFlags == 1)
				{
					tilt = -512;
				}
				else if (item->triggerFlags == 2)
				{
					tilt = 512;
				}

				if (info.distance >= SQUARE(768))
				{
					if (info.distance >= SQUARE(1280))
					{
						if (info.distance >= SQUARE(1792))
							item->goalAnimState = 0;
						else
							item->goalAnimState = 9;
					}
					else
					{
						item->goalAnimState = 8;
					}
				}
				else
				{
					item->goalAnimState = 7;
				}
				break;

			default:
				break;

			}
		}
		else
		{
			item->hitPoints = 0;

			if (item->currentAnimState != 11)
			{
				item->animNumber = Objects[item->objectNumber].animIndex + 15;		
				item->currentAnimState = 11;
				item->frameNumber = Anims[item->animNumber].frameBase;
			}

			if (!((item->frameNumber - Anims[item->animNumber].frameBase) & 7))
			{
				if (item->itemFlags[3] < 12)
				{
					ExplodeItemNode(item, 11 - item->itemFlags[3], 0, 64);
					SoundEffect(SFX_SMASH_ROCK, &item->pos, 0);
					item->itemFlags[3]++;
				}
			}
		}

		CreatureTilt(item, tilt);
		CreatureJoint(item, 0, joint0);
		CreatureJoint(item, 1, joint1);
		CreatureJoint(item, 2, joint2);
		CreatureJoint(item, 3, joint3);
		CreatureAnimation(itemNumber, 0, 0);
	}
}