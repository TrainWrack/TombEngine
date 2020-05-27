#include "framework.h"
#include "setup.h"
#include "draw.h"
#include "collide.h"
#include "effect2.h"
#include "effect.h"
#include "tomb4fx.h"
#include "box.h"
#include "switch.h"
#include "missile.h"
#include "control.h"
#include "pickup.h"
#include "camera.h"
#include "lara1gun.h"
#include "laraflar.h"
#include "larafire.h"
#include "laramisc.h"
#include "objects.h"
#include "door.h"
#include "rope.h"
#include "traps.h"
#include "flmtorch.h"
#include "level.h"
#include "oldobjects.h"
#include "newobjects.h"
#include "tr1_objects.h"
#include "tr2_objects.h"
#include "tr3_objects.h"
#include "tr4_objects.h"
#include "tr5_objects.h"

#include "quad.h"
#include "snowmobile.h"
#include "upv.h"
#include "cannon.h"
#include "minecart.h"
#include "kayak.h"

extern byte SequenceUsed[6];
extern byte SequenceResults[3][3][3];
extern byte Sequences[3];
extern byte CurrentSequence;
extern int NumRPickups;

extern GUNSHELL_STRUCT Gunshells[MAX_GUNSHELL];
extern BLOOD_STRUCT Blood[MAX_SPARKS_BLOOD];
extern FIRE_SPARKS FireSparks[MAX_SPARKS_FIRE];
extern SMOKE_SPARKS SmokeSparks[MAX_SPARKS_SMOKE];
extern DRIP_STRUCT Drips[MAX_DRIPS];
extern SHOCKWAVE_STRUCT ShockWaves[MAX_SHOCKWAVE];
extern FIRE_LIST Fires[MAX_FIRE_LIST];
extern GUNFLASH_STRUCT Gunflashes[MAX_GUNFLASH];
extern SPARKS Sparks[MAX_SPARKS];
extern SPLASH_STRUCT Splashes[MAX_SPLASH];
extern RIPPLE_STRUCT Ripples[MAX_RIPPLES];

ObjectInfo Objects[ID_NUMBER_OBJECTS];
STATIC_INFO StaticObjects[NUM_STATICS];

void NewObjects()
{
	ObjectInfo* obj;

	

	obj = &Objects[ID_TIGER];
	if (obj->loaded)
	{
		obj->control = TigerControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 24;
		obj->pivotLength = 200;
		obj->radius = 340;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		Bones[obj->boneIndex + 21 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_COBRA];
	if (obj->loaded)
	{
		obj->initialise = InitialiseCobra;
		obj->control = CobraControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 8;
		obj->radius = 102;
		obj->intelligent = true;
		obj->nonLot = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;

		Bones[obj->boneIndex + 0 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_RAPTOR];
	if (obj->loaded)
	{
		obj->control = Tr3RaptorControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 100;
		obj->radius = 341;
		obj->pivotLength = 600;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;

		Bones[obj->boneIndex + 20 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 21 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 23 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 25 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_SCUBA_DIVER];
	if (obj->loaded)
	{
		obj->control = ScubaControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 20;
		obj->radius = 340;
		obj->intelligent = true;
		obj->waterCreature = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 50;
		obj->zoneType = ZONE_WATER;

		Bones[obj->boneIndex + 10 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 14 * 4] |= ROT_Z;
	}

	obj = &Objects[ID_SCUBA_HARPOON];
	if (obj->loaded)
	{
		obj->control = HarpoonControl;
		obj->collision = ObjectCollision;
		obj->savePosition = true;
	}

	obj = &Objects[ID_TRIBESMAN_WITH_AX];
	if (obj->loaded)
	{
		obj->control = TribemanAxeControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 28;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;

		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_TRIBESMAN_WITH_DARTS];
	if (obj->loaded)
	{
		obj->control = TribesmanDartsControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 28;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;

		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_WOLF];
	if (obj->loaded)
	{
		obj->initialise = InitialiseWolf;
		obj->control = WolfControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 6;
		obj->pivotLength = 375;
		obj->radius = 340;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;

		Bones[obj->boneIndex + 2 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_BEAR];
	if (obj->loaded)
	{
		obj->initialise = InitialiseCreature;
		obj->control = BearControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 20;
		obj->pivotLength = 500;
		obj->radius = 340;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;

		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_TYRANNOSAUR];
	if (obj->loaded)
	{
		obj->control = TyrannosaurControl;
		obj->collision = CreatureCollision;
		obj->hitPoints = 800;
		obj->shadowSize = 64;
		obj->pivotLength = 1800;
		obj->radius = 512;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;

		Bones[obj->boneIndex + 10 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 11 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_APE];
	if (obj->loaded)
	{
		obj->control = ApeControl;
		obj->collision = CreatureCollision;
		obj->hitPoints = 22;
		obj->shadowSize = 128;
		obj->pivotLength = 250;
		obj->radius = 340;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->zoneType = ZONE_APE;
	}

	

	obj = &Objects[ID_GRENADE_GUN_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GRENADE_AMMO1_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GRENADE_AMMO2_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GRENADE_AMMO3_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_CROSSBOW_AMMO3_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GRENADE];
	if (obj->loaded)
	{
		obj->collision = NULL;
		obj->control = ControlGrenade;
	}

	obj = &Objects[ID_HARPOON_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_HARPOON_AMMO_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_HARPOON];
	if (obj->loaded)
	{
		obj->initialise = NULL;
		obj->collision = NULL;
		obj->control = ControlHarpoonBolt;
	}

	obj = &Objects[ID_CROSSBOW_BOLT];
	if (obj->loaded)
	{
		obj->initialise = NULL;
		obj->control = NULL;
		obj->control = ControlCrossbowBolt;
	}

	obj = &Objects[ID_SARCOPHAGUS];
	if (obj->loaded)
	{
		obj->control = AnimatingControl;
		obj->collision = SarcophagusCollision;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_LARA_DOUBLE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseLaraDouble;
		obj->control = LaraDoubleControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = 128;
		obj->hitPoints = 1000;
		obj->pivotLength = 50;
		obj->radius = 128;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_WATERSKIN1_EMPTY];
	if (obj->loaded)
	{
		obj->initialise = InitialisePickup;
		obj->control = PickupControl;
		obj->collision = PickupCollision;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_WATERSKIN2_EMPTY];
	if (obj->loaded)
	{
		obj->initialise = InitialisePickup;
		obj->control = PickupControl;
		obj->collision = PickupCollision;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_FLAMETHROWER_BADDY];
	if (obj->loaded)
	{
		obj->control = FlameThrowerControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 36;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;

		Bones[obj->boneIndex + 0 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 0 * 4] |= ROT_X;
		Bones[obj->boneIndex + 7 * 4] |= ROT_Y;
	}

	

	obj = &Objects[ID_MONKEY];
	if (obj->loaded)
	{
		//if (!Objects[MESHSWAP2].loaded)
		//	S_ExitSystem("FATAL: Monkey requires MESHSWAP2 (Monkey + Pickups)");
		//obj->draw_routine = DrawMonkey;
		obj->initialise = InitialiseMonkey;
		obj->control = MonkeyControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 8;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;

		Bones[obj->boneIndex + 0 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 0 * 4] |= ROT_X;
		Bones[obj->boneIndex + 7 * 4] |= ROT_Y;
	}
	
	obj = &Objects[ID_MP_WITH_GUN];
	if (obj->loaded)
	{
		obj->control = MPGunControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 28;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true; 
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;
		obj->biteOffset = 0;

		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_MP_WITH_STICK];
	if (obj->loaded)
	{
		obj->initialise = InitialiseMPStick;
		obj->control = MPStickControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 28;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;
		obj->zoneType = ZONE_HUMAN_CLASSIC;

		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
	}

	

	

	

}

void BaddyObjects()
{
	ObjectInfo* obj;

	/* Initialise Lara directly since lara will be used all the time. */
	obj = &Objects[ID_LARA];
	if (obj->loaded)
	{
		obj->initialise = InitialiseLaraLoad;
		obj->shadowSize = 160;
		obj->hitPoints = 1000;
		obj->drawRoutine = NULL;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		obj->usingDrawAnimatingItem = false;
	}
	else
	{
		printf("lara not found !");
	}

	obj = &Objects[ID_SAS];
	if (obj->loaded)
	{
		obj->initialise = InitialiseGuard;
		obj->control = GuardControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 40;
		obj->radius = 102;
		obj->pivotLength = 50;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_SWAT];
	if (obj->loaded)
	{
		obj->biteOffset = 0;
		obj->initialise = InitialiseGuard;
		obj->collision = CreatureCollision;
		obj->control = GuardControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_GUARD1];
	if (obj->loaded)
	{
		if (Objects[ID_SWAT].loaded) // object required
			obj->animIndex = Objects[ID_SWAT].animIndex;
		obj->biteOffset = 4;
		obj->initialise = InitialiseGuard;
		obj->collision = CreatureCollision;
		obj->control = GuardControl;
		obj->pivotLength = 50;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_SWAT_PLUS];
	if (obj->loaded)
	{
		short animIndex;
		if (!Objects[ID_SWAT].loaded)
			animIndex = Objects[ID_GUARD1].animIndex;
		else
			animIndex = Objects[ID_SWAT].animIndex;
		obj->animIndex = animIndex;
		obj->biteOffset = 0;
		obj->initialise = InitialiseGuard;
		obj->collision = CreatureCollision;
		obj->control = GuardControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_MAFIA];
	if (obj->loaded)
	{
		short animIndex;
		if (!Objects[ID_SWAT].loaded)
			animIndex = Objects[ID_GUARD1].animIndex;
		else
			animIndex = Objects[ID_SWAT].animIndex;
		obj->animIndex = animIndex;
		obj->biteOffset = 0;
		obj->initialise = InitialiseGuard;
		obj->collision = CreatureCollision;
		obj->control = GuardControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_SCIENTIST];
	if (obj->loaded)
	{
		short animIndex;
		if (!Objects[ID_SWAT].loaded)
			animIndex = Objects[ID_GUARD1].animIndex;
		else
			animIndex = Objects[ID_SWAT].animIndex;
		obj->animIndex = animIndex;
		obj->initialise = InitialiseGuard;
		obj->control = GuardControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[Objects[69].boneIndex + 6 * 4] |= ROT_Y;
		Bones[Objects[69].boneIndex + 6 * 4] |= ROT_X;
		Bones[Objects[69].boneIndex + 13 * 4] |= ROT_Y;
		Bones[Objects[69].boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_GUARD2];
	if (obj->loaded)
	{
		short animIndex;
		if (!Objects[ID_SWAT].loaded)
			animIndex = Objects[ID_GUARD1].animIndex;
		else
			animIndex = Objects[ID_SWAT].animIndex;
		obj->animIndex = animIndex;
		obj->biteOffset = 4;
		obj->initialise = InitialiseGuard;
		obj->control = GuardControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_GUARD3];
	if (obj->loaded)
	{
		short animIndex;
		if (!Objects[ID_SWAT].loaded)
			animIndex = Objects[ID_GUARD1].animIndex;
		else
			animIndex = Objects[ID_SWAT].animIndex;
		obj->animIndex = animIndex;
		obj->biteOffset = 4;
		obj->initialise = InitialiseGuard;
		obj->control = GuardControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_ATTACK_SUB];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSubmarine;
		obj->collision = CreatureCollision;
		obj->control = ControlSubmarine;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 100;
		obj->pivotLength = 200;
		obj->radius = 512;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		obj->waterCreature = true;
		obj->hitEffect = HIT_FRAGMENT;
		obj->zoneType = ZONE_FLYER;
		obj->undead = true;
		Bones[obj->boneIndex] |= ROT_X;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}

	obj = &Objects[ID_CHEF];
	if (obj->loaded)
	{
		obj->initialise = InitialiseChef;
		obj->control = ControlChef;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 35;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->biteOffset = 0;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;

		Bones[obj->boneIndex + 4 * 6] |= ROT_Y;
		Bones[obj->boneIndex + 4 * 6] |= ROT_X;
		Bones[obj->boneIndex + 4 * 13] |= ROT_Y;
		Bones[obj->boneIndex + 4 * 13] |= ROT_X;
	}

	obj = &Objects[ID_LION];
	if (obj->loaded)
	{
		obj->initialise = InitialiseLion;
		obj->collision = CreatureCollision;
		obj->control = LionControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 40;
		obj->pivotLength = 50;
		obj->radius = 341;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 19 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_DOG];
	if (obj->loaded)
	{
		obj->initialise = InitialiseDoberman;
		obj->collision = CreatureCollision;
		obj->control = ControlDoberman;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 18;
		obj->pivotLength = 50;
		obj->radius = 256;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 19 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_HUSKIE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseDog;
		obj->collision = CreatureCollision;
		obj->control = ControlDog;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 256;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 19 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_REAPER];
	if (obj->loaded)
	{
		obj->initialise = InitialiseReaper;
		obj->collision = CreatureCollision;
		obj->control = ControlReaper;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 10;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		obj->hitEffect = HIT_BLOOD;
		obj->waterCreature = true;
		obj->zoneType = ZONE_FLYER;
	}

	obj = &Objects[ID_MAFIA2];
	if (obj->loaded)
	{
		obj->biteOffset = 7;
		obj->initialise = InitialiseMafia2;
		obj->collision = CreatureCollision;
		obj->control = Mafia2Control;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 26;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		obj->meshSwapSlot = ID_MESHSWAP_MAFIA2;

		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_PIERRE];
	if (obj->loaded)
	{
		obj->biteOffset = 1;
		obj->initialise = InitialiseLarson;
		obj->collision = CreatureCollision;
		obj->control = ControlLarson;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 60;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 7 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 7 * 4] |= ROT_X;
	}

	obj = &Objects[ID_LARSON];
	if (obj->loaded)
	{
		obj->biteOffset = 3;
		obj->initialise = InitialiseLarson;
		obj->collision = CreatureCollision;
		obj->control = ControlLarson;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 60;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 7 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 7 * 4] |= ROT_X;
	}

	obj = &Objects[ID_HITMAN];
	if (obj->loaded)
	{
		obj->biteOffset = 5;
		obj->initialise = InitialiseHitman;
		obj->collision = CreatureCollision;
		obj->control = HitmanControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 50;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_FRAGMENT;
		obj->undead = true;
		obj->zoneType = ZONE_HUMAN_CLASSIC;
		obj->meshSwapSlot = ID_MESHSWAP_HITMAN;

		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_SNIPER];
	if (obj->loaded)
	{
		obj->biteOffset = 6;
		obj->initialise = InitialiseSniper;
		obj->collision = CreatureCollision;
		obj->control = SniperControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 35;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->explodableMeshbits = 0x4000;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	obj = &Objects[ID_GUARD_LASER];
	if (obj->loaded)
	{
		obj->biteOffset = 0;
		obj->initialise = InitialiseGuardLaser;
		obj->collision = CreatureCollision;
		//obj->control = GuardControlLaser;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 24;
		obj->pivotLength = 50;
		obj->radius = 128;
		obj->explodableMeshbits = 4;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_FRAGMENT;
		obj->undead = true;
		Bones[obj->boneIndex] |= ROT_Y;
		Bones[obj->boneIndex] |= ROT_X;
		Bones[obj->boneIndex + 4] |= ROT_Y;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}

	obj = &Objects[ID_HYDRA];
	if (obj->loaded)
	{
		obj->initialise = InitialiseHydra;
		obj->collision = CreatureCollision;
		obj->control = ControlHydra;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 30;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->biteOffset = 1024;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_FRAGMENT;
		obj->undead = true;
		Bones[obj->boneIndex + 0] |= ROT_Y;
		Bones[obj->boneIndex + 8 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 8 * 4] |= ROT_X;
		Bones[obj->boneIndex + 8 * 4] |= ROT_Z;
	}

	obj = &Objects[ID_IMP];
	if (obj->loaded)
	{
		obj->biteOffset = 256;
		obj->initialise = InitialiseImp;
		obj->collision = CreatureCollision;
		obj->control = ControlImp;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 12;
		obj->pivotLength = 20;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		obj->meshSwapSlot = ID_MESHSWAP_IMP;

		Bones[obj->meshIndex + 4 * 4] |= ROT_Z;
		Bones[obj->meshIndex + 4 * 4] |= ROT_X;
		Bones[obj->meshIndex + 9 * 4] |= ROT_Z;
		Bones[obj->meshIndex + 9 * 4] |= ROT_X;
	}

	obj = &Objects[ID_WILLOWISP];
	if (obj->loaded)
	{
		obj->biteOffset = 256;
		obj->initialise = InitialiseLightingGuide;
		//obj->control = ControlLightingGuide;
		obj->drawRoutine = NULL;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->radius = 256;
		obj->hitPoints = 16;
		obj->pivotLength = 20;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		obj->zoneType = ZONE_FLYER;
		Bones[obj->boneIndex + 4 * 4] |= ROT_Z;
		Bones[obj->boneIndex + 4 * 4] |= ROT_X;
		Bones[obj->boneIndex + 9 * 4] |= ROT_Z;
		Bones[obj->boneIndex + 9 * 4] |= ROT_X;
	}

	obj = &Objects[ID_BROWN_BEAST];
	if (obj->loaded)
	{
		obj->biteOffset = 256;
		obj->initialise = InitialiseBrownBeast;
		obj->collision = CreatureCollision;
		obj->control = ControlBrowsBeast;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 100;
		obj->pivotLength = 20;
		obj->radius = 341;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 4 * 4] |= ROT_Z;
		Bones[obj->boneIndex + 4 * 4] |= ROT_X;
		Bones[obj->boneIndex + 9 * 4] |= ROT_Z;
		Bones[obj->boneIndex + 9 * 4] |= ROT_X;
	}
	
	obj = &Objects[ID_LAGOON_WITCH];
	if (obj->loaded)
	{
		obj->biteOffset = 256;
		obj->initialise = InitialiseLagoonWitch;
		obj->collision = CreatureCollision;
		obj->control = ControlLagoonWitch;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 100;
		obj->pivotLength = 20;
		obj->radius = 256;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		obj->waterCreature = true;
		obj->zoneType = ZONE_FLYER;

		Bones[obj->boneIndex + 4 * 4] |= ROT_Z;
		Bones[obj->boneIndex + 4 * 4] |= ROT_X;
		Bones[obj->boneIndex + 9 * 4] |= ROT_Z;
		Bones[obj->boneIndex + 9 * 4] |= ROT_X;
	}

	obj = &Objects[ID_INVISIBLE_GHOST];
	if (obj->loaded)
	{
		obj->biteOffset = 256;
		obj->initialise = InitialiseInvisibleGhost;
		obj->collision = CreatureCollision;
		obj->control = ControlInvisibleGhost;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 100;
		obj->pivotLength = 20;
		obj->radius = 256;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 8 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 8 * 4] |= ROT_X;
	}

	obj = &Objects[ID_RATS_EMITTER];
	if (obj->loaded)
	{
		obj->drawRoutine = NULL;
		obj->initialise = InitialiseLittleRats;
		obj->control = ControlLittleRats;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_BATS_EMITTER];
	if (obj->loaded)
	{
		obj->drawRoutine = NULL;
		obj->initialise = InitialiseLittleBats;
		obj->control = ControlLittleBats;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_SPIDERS_EMITTER];
	if (obj->loaded)
	{
		obj->drawRoutine = NULL;
		obj->initialise = InitialiseSpiders;
		obj->control = ControlSpiders;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_GLADIATOR];
	if (obj->loaded)
	{
		obj->biteOffset = 0;
		obj->initialise = InitialiseGladiator;
		obj->control = ControlGladiator;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 20;
		obj->pivotLength = 50;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveHitpoints = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 13 * 4] |= ROT_X;
	}

	for (int i = 0; i < 2; i++)
	{
		obj = &Objects[ID_ROMAN_GOD1 + i];
		if (obj->loaded)
		{
			obj->biteOffset = 0;
			obj->initialise = InitialiseRomanStatue;
			obj->collision = CreatureCollision;
			obj->control = ControlRomanStatue;
			obj->shadowSize = UNIT_SHADOW / 2;
			obj->hitPoints = 300;
			obj->pivotLength = 50;
			obj->radius = 256;
			obj->intelligent = true;
			obj->savePosition = true;
			obj->saveFlags = true;
			obj->saveAnim = true;
			obj->saveHitpoints = true;
			obj->hitEffect = HIT_SMOKE;
			obj->meshSwapSlot = ID_MESHSWAP_ROMAN_GOD1 + i;

			Bones[obj->boneIndex + 24] |= ROT_Y;
			Bones[obj->boneIndex + 24] |= ROT_X;
			Bones[obj->boneIndex + 52] |= ROT_Y;
			Bones[obj->boneIndex + 52] |= ROT_X;
		}
	}

	obj = &Objects[ID_GUARDIAN];
	if (obj->loaded)
	{
		obj->initialise = InitialiseGuardian;
		obj->collision = CreatureCollision;
		obj->control = GuardianControl;
		obj->explodableMeshbits = 6;
		obj->nonLot = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->usingDrawAnimatingItem = false;
		obj->undead = true; 
		obj->unknown = 3;
		obj->hitEffect = HIT_FRAGMENT;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_AUTOGUN];
	if (obj->loaded)
	{
		obj->initialise = InitialiseAutoGuns;
		obj->control = ControlAutoGuns;
		obj->saveHitpoints = true;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->hitEffect = HIT_BLOOD;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 8 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_GUNSHIP];
	if (obj->loaded)
	{
		obj->control = ControlGunShip;
		obj->saveFlags = true;
		obj->saveAnim = true;
		Bones[obj->boneIndex + 0] |= ROT_Y;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}
}

// TODO: add the flags
void ObjectObjects()
{
	ObjectInfo* obj;

	obj = &Objects[ID_CAMERA_TARGET];
	if (obj->loaded)
	{
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_SMASH_OBJECT1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT3];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT4];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT5];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT6];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT7];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_SMASH_OBJECT8];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmashObject;
		obj->collision = ObjectCollision;
		obj->control = SmashObjectControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	obj = &Objects[ID_BRIDGE_FLAT];
	if (obj->loaded)
	{
		obj->floor = BridgeFlatFloor;
		obj->ceiling = BridgeFlatCeiling;
	}

	obj = &Objects[ID_BRIDGE_TILT1];
	if (obj->loaded)
	{
		obj->floor = BridgeTilt1Floor;
		obj->ceiling = BridgeTilt1Ceiling;
	}

	obj = &Objects[ID_BRIDGE_TILT2];
	if (obj->loaded)
	{
		obj->floor = BridgeTilt2Floor;
		obj->ceiling = BridgeTilt2Ceiling;
	}

	obj = &Objects[ID_CRUMBLING_FLOOR];
	if (obj->loaded)
	{
		obj->initialise = InitialiseFallingBlock;
		obj->collision = FallingBlockCollision;
		obj->control = FallingBlockControl;
		obj->floor = FallingBlockFloor;
		obj->ceiling = FallingBlockCeiling;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveMesh = true;
	}

	for (int objNum = ID_SWITCH_TYPE1; objNum <= ID_SWITCH_TYPE16; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->initialise = InitialiseSwitch;
			obj->collision = SwitchCollision;
			obj->control = SwitchControl;
			obj->saveFlags = true;
			obj->saveAnim = true;
			obj->saveMesh = true;
		}
	}

	obj = &Objects[ID_AIRLOCK_SWITCH];
	if (obj->loaded)
	{
		obj->collision = SwitchCollision;
		obj->control = SwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_SEQUENCE_SWITCH1];
	if (obj->loaded)
	{
		obj->collision = FullBlockSwitchCollision;
		obj->control = FullBlockSwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_SEQUENCE_SWITCH2];
	if (obj->loaded)
	{
		obj->collision = FullBlockSwitchCollision;
		obj->control = FullBlockSwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_SEQUENCE_SWITCH3];
	if (obj->loaded)
	{
		obj->collision = FullBlockSwitchCollision;
		obj->control = FullBlockSwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	for (int objNum = ID_UNDERWATER_SWITCH1; objNum <= ID_UNDERWATER_SWITCH4; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->control = SwitchControl;
			obj->collision = UnderwaterSwitchCollision;
			obj->saveFlags = true;
			obj->saveAnim = true;
		}
	}

	obj = &Objects[ID_LEVER_SWITCH];
	if (obj->loaded)
	{
		obj->collision = RailSwitchCollision;
		obj->control = SwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_JUMP_SWITCH];
	if (obj->loaded)
	{
		obj->collision = JumpSwitchCollision;
		obj->control = SwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_CROWBAR_SWITCH];
	if (obj->loaded)
	{
		obj->collision = CrowbarSwitchCollision;
		obj->control = SwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_PULLEY];
	if (obj->loaded)
	{
		obj->initialise = InitialisePulleySwitch;
		obj->control = SwitchControl;
		obj->collision = PulleyCollision;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_COG_SWITCH];
	if (obj->loaded)
	{
		obj->collision = CogSwitchCollision;
		obj->control = CogSwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_CROWDOVE_SWITCH];
	if (obj->loaded)
	{
		obj->initialise = InitialiseCrowDoveSwitch;
		obj->collision = CrowDoveSwitchCollision;
		obj->control = CrowDoveSwitchControl;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
	}

	for (int objNum = ID_DOOR_TYPE1; objNum <= ID_CLOSED_DOOR6; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->initialise = InitialiseDoor;
			obj->control = DoorControl;
			obj->collision = DoorCollision;
			obj->saveAnim = true;
			obj->saveFlags = true;
			obj->saveMesh = true;
		}
	}

	obj = &Objects[ID_LIFT_DOORS1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseDoor;
		obj->control = DoorControl;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_LIFT_DOORS2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseDoor;
		obj->control = DoorControl;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_SEQUENCE_DOOR1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseDoor;
		obj->collision = DoorCollision;
		obj->control = SequenceDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	for (int i = ID_DOUBLE_DOORS1; i <= ID_DOUBLE_DOORS4; i++)
	{
		obj = &Objects[i];
		if (obj->loaded)
		{
			obj->initialise = InitialiseDoor;
			obj->collision = DoubleDoorCollision;
			obj->control = PushPullKickDoorControl;
			obj->saveAnim = true;
			obj->saveFlags = true;
		}
	}

	for (int i = ID_UNDERWATER_DOOR1; i <= ID_UNDERWATER_DOOR4; i++)
	{
		obj = &Objects[i];
		if (obj->loaded)
		{
			obj->initialise = InitialiseDoor;
			obj->collision = UnderwaterDoorCollision;
			obj->control = PushPullKickDoorControl;
			obj->saveAnim = true;
			obj->saveFlags = true;
		}
	}

	for (int objNum = ID_PUSHPULL_DOOR1; objNum <= ID_KICK_DOOR4; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->initialise = InitialiseDoor;
			obj->collision = PushPullKickDoorCollision;
			obj->control = PushPullKickDoorControl;
			obj->saveAnim = true;
			obj->saveFlags = true;
		}
	}

	obj = &Objects[ID_FLOOR_TRAPDOOR1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = FloorTrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_FLOOR_TRAPDOOR2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = FloorTrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_CEILING_TRAPDOOR1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = CeilingTrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_CEILING_TRAPDOOR2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = CeilingTrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_TRAPDOOR1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = TrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_TRAPDOOR2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = TrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_TRAPDOOR3];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTrapDoor;
		obj->collision = TrapDoorCollision;
		obj->control = TrapDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_SEARCH_OBJECT1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSearchObject;
		obj->collision = SearchObjectCollision;
		obj->control = SearchObjectControl;
	}

	obj = &Objects[ID_SEARCH_OBJECT2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSearchObject;
		obj->collision = SearchObjectCollision;
		obj->control = SearchObjectControl;
	}

	obj = &Objects[ID_SEARCH_OBJECT3];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSearchObject;
		obj->collision = SearchObjectCollision;
		obj->control = SearchObjectControl;
	}

	obj = &Objects[ID_SEARCH_OBJECT4];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSearchObject;
		obj->collision = SearchObjectCollision;
		obj->control = SearchObjectControl;
	}

	obj = &Objects[ID_FLARE_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->control = FlareControl;
		//obj->drawRoutine = draw_f;
		obj->pivotLength = 256;
		obj->hitPoints = 256;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_BURNING_TORCH_ITEM];
	if (obj->loaded)
	{
		obj->collision = PickupCollision;
		obj->control = TorchControl;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_TORPEDO];
	if (obj->loaded)
	{
		obj->control = TorpedoControl;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveAnim = true;
	}

	for (int objNum = ID_PUSHABLE_OBJECT1; objNum <= ID_PUSHABLE_OBJECT10; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->initialise = InitialisePushableBlock;
			obj->control = PushableBlockControl;
			obj->collision = PushableBlockCollision;
			obj->saveFlags = true;
			obj->savePosition = true;
			obj->saveAnim = true;
		}
	}

	obj = &Objects[ID_TWOBLOCK_PLATFORM];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTwoBlocksPlatform;
		obj->control = TwoBlocksPlatformControl;
		obj->floor = TwoBlocksPlatformFloor;
		obj->ceiling = TwoBlocksPlatformCeiling;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_RAISING_COG];
	if (obj->loaded)
	{
		obj->initialise = InitialiseRaisingCog;
		obj->control = RaisingCogControl;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveAnim = true;
	}

	obj = &Objects[ID_ELECTRICAL_LIGHT];
	if (obj->loaded)
	{
		obj->control = ElectricalLightControl;
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_PULSE_LIGHT];
	if (obj->loaded)
	{
		obj->control = PulseLightControl;
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_STROBE_LIGHT];
	if (obj->loaded)
	{
		obj->control = StrobeLightControl;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_COLOR_LIGHT];
	if (obj->loaded)
	{
		obj->control = ColorLightControl;
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_BLINKING_LIGHT];
	if (obj->loaded)
	{
		obj->control = BlinkingLightControl;
		obj->saveFlags = true;
	}

	for (int objNum = ID_KEY_HOLE1; objNum <= ID_KEY_HOLE16; objNum++)
	{
		INIT_KEYHOLE(objNum);
	}

	for (int objNum = ID_PUZZLE_HOLE1; objNum <= ID_PUZZLE_HOLE16; objNum++)
	{
		INIT_PUZZLEHOLE(objNum);
	}

	for (int objNum = ID_PUZZLE_DONE1; objNum <= ID_PUZZLE_DONE16; objNum++)
	{
		INIT_PUZZLEDONE(objNum);
	}
	
	for (int objNum = ID_ANIMATING1; objNum <= ID_ANIMATING128; objNum++)
	{
		INIT_ANIMATING(objNum);
	}

	INIT_ANIMATING(ID_GUARDIAN_BASE);
	INIT_ANIMATING(ID_GUARDIAN_TENTACLE);

	obj = &Objects[ID_ANIMATING13];
	if (obj->loaded)
	{
		obj->initialise = InitialiseAnimating;
		obj->control = AnimatingControl;
		obj->collision = NULL;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
		Bones[obj->boneIndex] |= ROT_Y;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}

	obj = &Objects[ID_ANIMATING14];
	if (obj->loaded)
	{
		obj->initialise = InitialiseAnimating;
		obj->control = AnimatingControl;
		obj->collision = NULL;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
		Bones[obj->boneIndex] |= ROT_Y;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}

	obj = &Objects[ID_ANIMATING15];
	if (obj->loaded)
	{
		obj->initialise = InitialiseAnimating;
		obj->control = AnimatingControl;
		obj->collision = NULL;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
		Bones[obj->boneIndex] |= ROT_Y;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}

	obj = &Objects[ID_ANIMATING16];
	if (obj->loaded)
	{
		obj->initialise = InitialiseAnimating;
		obj->control = AnimatingControl;
		obj->collision = NULL;
		obj->saveFlags = true;
		obj->saveAnim = true;
		obj->saveMesh = true;
		Bones[obj->boneIndex] |= ROT_Y;
		Bones[obj->boneIndex + 4] |= ROT_X;
	}

	obj = &Objects[ID_TIGHT_ROPE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTightRope;
		obj->collision = TightRopeCollision;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_PARALLEL_BARS];
	if (obj->loaded)
	{
		obj->collision = ParallelBarsCollision;
	}

	obj = &Objects[ID_STEEL_DOOR];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSteelDoor;
		obj->collision = SteelDoorCollision;
		//obj->control = Legacy_SteelDoorControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveMesh = true;
		obj->savePosition = true;
	}

	/*obj = &Objects[ID_XRAY_CONTROLLER];
	if (obj->loaded)
	{
		obj->initialise = InitialiseXRayMachine;
		obj->control = ControlXRayMachine;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
	}*/

	// by default loaded, explosion time :D
	obj = &Objects[ID_BODY_PART];
	obj->loaded = true;
	obj->control = ControlBodyPart;

	obj = &Objects[ID_EARTHQUAKE];
	if (obj->loaded)
	{
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_HIGH_OBJECT2];
	if (obj->loaded)
	{
		obj->drawRoutine = NULL;
		obj->control = HighObject2Control;
	}

	for (int objNum = ID_RAISING_BLOCK1; objNum <= ID_RAISING_BLOCK4; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->initialise = InitialiseRaisingBlock;
			obj->control = ControlRaisingBlock;
			obj->saveFlags = true;
		}
	}

	obj = &Objects[ID_SMOKE_EMITTER_BLACK];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmokeEmitter;
		obj->control = SmokeEmitterControl;
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_SMOKE_EMITTER_WHITE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmokeEmitter;
		obj->control = SmokeEmitterControl;
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_SMOKE_EMITTER];
	if (obj->loaded)
	{
		obj->initialise = InitialiseSmokeEmitter;
		obj->control = SmokeEmitterControl;
		obj->drawRoutine = NULL;
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_LENS_FLARE];
	if (obj->loaded)
	{
		//obj->drawRoutine = DrawLensFlare;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_ENERGY_BUBBLES];
	if (obj->loaded)
	{
		obj->control = BubblesControl;
	}

	obj = &Objects[ID_BUBBLES];
	if (obj->loaded)
	{
		obj->control = MissileControl;
	}

	obj = &Objects[ID_IMP_ROCK];
	if (obj->loaded)
	{
		obj->control = MissileControl;
	}

	obj = &Objects[ID_WATERFALLMIST];
	if (obj->loaded)
	{
		obj->control = ControlWaterfallMist;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
	}

	for (int objNum = ID_WATERFALL1; objNum <= ID_WATERFALL6; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->control = ControlWaterfall;
			obj->saveFlags = true;
		}
	}

	obj = &Objects[ID_WATERFALLSS1];
	if (obj->loaded)
	{
		obj->control = ControlWaterfall;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_WATERFALLSS2];
	if (obj->loaded)
	{
		obj->control = ControlWaterfall;
		obj->saveFlags = true;
	}

	for (int objNum = ID_SHOOT_SWITCH1; objNum <= ID_SHOOT_SWITCH4; objNum++)
	{
		obj = &Objects[objNum];
		if (obj->loaded)
		{
			obj->initialise = InitialiseShootSwitch;
			obj->control = ControlAnimatingSlots;
			obj->collision = ShootSwitchCollision;
			obj->saveAnim = true;
			obj->saveFlags = true;
			obj->saveMesh = true;
		}
	}

	obj = &Objects[ID_TELEPORTER];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTeleporter;
		obj->control = ControlTeleporter;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
	}
}

void TrapObjects()
{
	ObjectInfo* obj;

	obj = &Objects[ID_ELECTRICAL_CABLES];
	if (obj->loaded)
	{
		obj->control = ElectricityWiresControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_ROME_HAMMER];
	if (obj->loaded)
	{
		obj->initialise = InitialiseRomeHammer;
		obj->collision = GenericSphereBoxCollision;
		obj->control = AnimatingControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_ZIPLINE_HANDLE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseDeathSlide;
		obj->collision = DeathSlideCollision;
		obj->control = ControlDeathSlide;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_ROLLINGBALL];
	if (obj->loaded)
	{
		obj->collision = RollingBallCollision;
		obj->control = RollingBallControl;
		obj->savePosition = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_KILL_ALL_TRIGGERS];
	if (obj->loaded)
	{
		obj->control = KillAllCurrentItems;
		obj->drawRoutine = NULL;
		obj->hitPoints = 0;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_FALLING_CEILING];
	if (obj->loaded)
	{
		obj->collision = TrapCollision;
		obj->control = FallingCeilingControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_FALLING_BLOCK];
	if (obj->loaded)
	{
		obj->initialise = InitialiseFallingBlock;
		obj->collision = FallingBlockCollision;
		obj->control = FallingBlockControl;
		obj->floor = FallingBlockFloor;
		obj->ceiling = FallingBlockCeiling;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_FALLING_BLOCK2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseFallingBlock;
		obj->collision = FallingBlockCollision;
		obj->control = FallingBlockControl;
		obj->floor = FallingBlockFloor;
		obj->ceiling = FallingBlockCeiling;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_DARTS];
	if (obj->loaded)
	{
		obj->shadowSize = UNIT_SHADOW / 2;
		//obj->drawRoutine = DrawDart;
		obj->collision = ObjectCollision;
		obj->control = DartControl;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_DART_EMITTER];
	if (obj->loaded)
	{
		obj->control = DartEmitterControl;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_HOMING_DART_EMITTER];
	if (obj->loaded)
	{
		obj->control = DartEmitterControl;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	// Flame is always loaded
	obj = &Objects[ID_FLAME];
	{
		obj->control = FlameControl;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_FLAME_EMITTER];
	if (obj->loaded)
	{
		obj->initialise = InitialiseFlameEmitter;
		obj->collision = FlameEmitterCollision;
		obj->control = FlameEmitterControl;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_FLAME_EMITTER2];
	if (obj->loaded)
	{
		obj->initialise = InitialiseFlameEmitter2;
		obj->collision = FlameEmitterCollision;
		obj->control = FlameEmitter2Control;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_FLAME_EMITTER3];
	if (obj->loaded)
	{
		obj->control = FlameEmitter3Control;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_GEN_SLOT1];
	if (obj->loaded)
	{
		obj->control = GenSlot1Control;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GEN_SLOT2];
	if (obj->loaded)
	{
		/*obj->initialise = InitialiseGenSlot2;
		obj->control = GenSlot2Control;
		obj->drawRoutine = DrawGenSlot2;*/
		obj->usingDrawAnimatingItem = false;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GEN_SLOT3];
	if (obj->loaded)
	{
		obj->initialise = InitialiseGenSlot3;
		obj->collision = HybridCollision;
		obj->control = AnimatingControl;
		obj->saveAnim = true;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_GEN_SLOT4];
	if (obj->loaded)
	{
		//obj->initialise = InitialiseGenSlot4;
		//obj->control = GenSlot4Control;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_HIGH_OBJECT1];
	if (obj->loaded)
	{
		obj->initialise = InitialiseHighObject1;
		obj->control = ControlHighObject1;
		obj->collision = ObjectCollision;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_PORTAL];
	if (obj->loaded)
	{
		//obj->initialise = InitialisePortal;
		//obj->control = PortalControl;        // TODO: found the control procedure !
		obj->drawRoutine = NULL;             // go to nullsub_44() !
		obj->saveFlags = true; 
		obj->usingDrawAnimatingItem = false;
	}
	
	obj = &Objects[ID_TRIGGER_TRIGGERER];
	if (obj->loaded)
	{
		obj->control = ControlTriggerTriggerer;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	//FIXME
	//InitialiseRopeTrap();

	obj = &Objects[ID_ROPE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseRope;
		obj->control = RopeControl;
		obj->collision = RopeCollision;
		obj->drawRoutine = NULL;
		obj->saveFlags = true;
		obj->usingDrawAnimatingItem = false;
	}

	obj = &Objects[ID_POLEROPE];
	if (obj->loaded)
	{
		obj->collision = PoleCollision;
		obj->saveFlags = true;
	}

	obj = &Objects[ID_WRECKING_BALL];
	if (obj->loaded)
	{
		obj->initialise = InitialiseWreckingBall;
		obj->collision = WreckingBallCollision;
		obj->control = WreckingBallControl;
		//obj->drawRoutineExtra = DrawWreckingBall;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
	}

	obj = &Objects[ID_PROPELLER_H];
	if (obj->loaded)
	{
		obj->initialise = InitialiseVentilator;
		obj->control = VentilatorControl;
	}

	obj = &Objects[ID_PROPELLER_V];
	if (obj->loaded)
	{
		obj->initialise = InitialiseVentilator;
		obj->control = VentilatorControl;
	}

	obj = &Objects[ID_TEETH_SPIKES];
	if (obj->loaded)
	{
		obj->initialise = InitialiseTeethSpikes;
		obj->control = ControlTeethSpikes;
		//obj->drawRoutine = DrawScaledSpike;
	}
}

void InitialiseSpecialEffects()
{
	int i;
	SPARKS* sptr;

	memset(&Sparks, 0, MAX_SPARKS * sizeof(SPARKS));
	memset(&FireSparks, 0, MAX_SPARKS_FIRE * sizeof(FIRE_SPARKS));
	memset(&SmokeSparks, 0, MAX_SPARKS_SMOKE * sizeof(SMOKE_SPARKS));
	memset(&Gunshells, 0, MAX_GUNSHELL * sizeof(GUNSHELL_STRUCT));
	memset(&Gunflashes, 0, (MAX_GUNFLASH * sizeof(GUNFLASH_STRUCT)));
	memset(&Blood, 0, MAX_SPARKS_BLOOD * sizeof(BLOOD_STRUCT));
	memset(&Splashes, 0, MAX_SPLASH * sizeof(SPLASH_STRUCT));
	memset(&Ripples, 0, MAX_RIPPLES * sizeof(RIPPLE_STRUCT));
	memset(&Drips, 0, MAX_DRIPS * sizeof(DRIP_STRUCT));
	memset(&ShockWaves, 0, MAX_SHOCKWAVE * sizeof(SHOCKWAVE_STRUCT));

	sptr = &Sparks[0];
	for (i = 0; i < MAX_SPARKS; i++)
	{
		sptr->on = false;
		sptr->dynamic = -1;
		sptr++;
	}

	NextFireSpark = 1;
	NextSmokeSpark = 0;
	NextGunShell = 0;
	NextBubble = 0;
	NextDrip = 0;
	NextBlood = 0;
	WBRoom = -1;
}

void PickupObjects()
{
	ObjectInfo* obj;

	for (int objNum = ID_PUZZLE_ITEM1; objNum <= ID_EXAMINE8_COMBO2; objNum++)
	{
		INIT_PICKUP(objNum);
	}

	INIT_PICKUP(ID_GAME_PIECE1);
	INIT_PICKUP(ID_GAME_PIECE2);
	INIT_PICKUP(ID_GAME_PIECE3);
	INIT_PICKUP(ID_HAMMER_ITEM);
	INIT_PICKUP(ID_CROWBAR_ITEM);
	INIT_PICKUP(ID_PISTOLS_ITEM);
	INIT_PICKUP(ID_PISTOLS_AMMO_ITEM);
	INIT_PICKUP(ID_UZI_ITEM);
	INIT_PICKUP(ID_UZI_AMMO_ITEM);
	INIT_PICKUP(ID_SHOTGUN_ITEM);
	INIT_PICKUP(ID_SHOTGUN_AMMO1_ITEM);
	INIT_PICKUP(ID_SHOTGUN_AMMO2_ITEM);
	INIT_PICKUP(ID_CROSSBOW_ITEM);
	INIT_PICKUP(ID_CROSSBOW_AMMO1_ITEM);
	INIT_PICKUP(ID_CROSSBOW_AMMO2_ITEM);
	INIT_PICKUP(ID_CROSSBOW_AMMO3_ITEM);
	INIT_PICKUP(ID_GRENADE_GUN_ITEM);
	INIT_PICKUP(ID_GRENADE_AMMO1_ITEM);
	INIT_PICKUP(ID_GRENADE_AMMO2_ITEM);
	INIT_PICKUP(ID_GRENADE_AMMO3_ITEM);
	INIT_PICKUP(ID_HARPOON_ITEM);
	INIT_PICKUP(ID_HARPOON_AMMO_ITEM);
	INIT_PICKUP(ID_ROCKET_LAUNCHER_ITEM);
	INIT_PICKUP(ID_ROCKET_LAUNCHER_AMMO_ITEM);
	INIT_PICKUP(ID_HK_ITEM);
	INIT_PICKUP(ID_HK_AMMO_ITEM);
	INIT_PICKUP(ID_REVOLVER_ITEM);
	INIT_PICKUP(ID_REVOLVER_AMMO_ITEM);
	INIT_PICKUP(ID_BIGMEDI_ITEM);
	INIT_PICKUP(ID_SMALLMEDI_ITEM);
	INIT_PICKUP(ID_LASERSIGHT_ITEM);
	INIT_PICKUP(ID_BINOCULARS_ITEM);
	INIT_PICKUP(ID_SILENCER_ITEM);
	INIT_PICKUP(ID_FLARE_INV_ITEM);
	INIT_PICKUP(ID_WATERSKIN1_EMPTY);
	INIT_PICKUP(ID_WATERSKIN2_EMPTY);
	INIT_PICKUP(ID_CLOCKWORK_BEETLE);
	INIT_PICKUP(ID_CLOCKWORK_BEETLE_COMBO1);
	INIT_PICKUP(ID_CLOCKWORK_BEETLE_COMBO2);
	INIT_PICKUP(ID_GOLDROSE_ITEM);
}

void CustomObjects()
{
	ObjectInfo* obj;

	obj = &Objects[ID_SHIVA];
	if (obj->loaded)
	{
		obj->initialise = InitialiseShiva;
		obj->collision = CreatureCollision;
		obj->control = ShivaControl;
		//obj->drawRoutine = DrawStatue;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 100;
		obj->pivotLength = 0;
		obj->radius = 256;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->saveHitpoints = true;
		obj->savePosition = true;
		Bones[obj->boneIndex + 6 * 4] |= (ROT_X | ROT_Y);
		Bones[obj->boneIndex + 25 * 4] |= (ROT_X | ROT_Y);
	}

	obj = &Objects[ID_SOPHIA_LEE_BOSS];
	if (obj->loaded)
	{
		obj->initialise = InitialiseLondonBoss;
		obj->collision = CreatureCollision;
		obj->control = LondonBossControl;
		obj->drawRoutine = S_DrawLondonBoss;
		obj->shadowSize = 0;
		obj->pivotLength = 50;
		obj->hitPoints = 300;
		obj->radius = 102;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
	}

	obj = &Objects[ID_NATLA];
	if (obj->loaded)
	{
		obj->initialise = InitialiseCreature;
		obj->collision = CreatureCollision;
		obj->control = NatlaControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 400;
		obj->radius = 204;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		Bones[obj->boneIndex + 2 * 4] |= (ROT_Z|ROT_X);
	}

	obj = &Objects[ID_WINGED_NATLA];
	if (obj->loaded)
	{
		obj->initialise = InitialiseCreature;
		obj->collision = CreatureCollision;
		obj->control = NatlaEvilControl;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 500;
		obj->radius = 341;
		obj->intelligent = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		Bones[obj->boneIndex + 1 * 4] |= ROT_Y;
	}

	// FIXME: evil lara not work correctly.
	obj = &Objects[ID_EVIL_LARA];
	if (obj->loaded)
	{
		// use lara animation.
		if (Objects[ID_LARA].loaded)
		{
			obj->animIndex = Objects[ID_LARA].animIndex;
			obj->frameBase = Objects[ID_LARA].frameBase;
		}

		obj->initialise = InitialiseEvilLara;
		obj->collision = CreatureCollision;
		obj->control = LaraEvilControl;
		//obj->drawRoutine = DrawEvilLara;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 1000;
		obj->radius = 102;
		//obj->intelligent = true;
		obj->saveFlags = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
	}
	
	obj = &Objects[ID_CIVVIE];
	if (obj->loaded)
	{
		obj->initialise = InitialiseCivvy;
		obj->control = CivvyControl;
		obj->collision = CreatureCollision;
		obj->shadowSize = UNIT_SHADOW / 2;
		obj->hitPoints = 15;
		obj->radius = 102;
		obj->intelligent = true;
		obj->savePosition = true;
		obj->saveHitpoints = true;
		obj->saveAnim = true;
		obj->saveFlags = true;
		obj->pivotLength = 0;
		Bones[obj->boneIndex + 6 * 4] |= ROT_Y;
		Bones[obj->boneIndex + 6 * 4] |= ROT_X;
		Bones[obj->boneIndex + 13 * 4] |= ROT_Y;
	}
}

static void InitialiseTR5Objects()
{
	BaddyObjects();
	ObjectObjects();
	TrapObjects();
	PickupObjects();
}

void InitialiseObjects()
{
	ObjectInfo* obj;

	for (int i = 0; i < ID_NUMBER_OBJECTS; i++)
	{
		obj = &Objects[i];
		obj->initialise = NULL;
		obj->collision = NULL;
		obj->control = NULL;
		obj->floor = NULL;
		obj->ceiling = NULL;
		obj->drawRoutine = DrawAnimatingItem;
		obj->drawRoutineExtra = NULL;
		obj->pivotLength = 0;
		obj->radius = DEFAULT_RADIUS;
		obj->shadowSize = NO_SHADOW;
		obj->hitPoints = -16384;
		obj->hitEffect = HIT_NONE;
		obj->explodableMeshbits = NULL;
		obj->intelligent = false;
		obj->waterCreature = false;
		obj->saveMesh = false;
		obj->saveAnim = false;
		obj->saveFlags = false;
		obj->saveHitpoints = false;
		obj->savePosition = false;
		obj->nonLot = true;
		obj->usingDrawAnimatingItem = true;
		obj->semiTransparent = false;
		obj->undead = false;
		obj->zoneType = ZONE_NULL;
		obj->biteOffset = -1;
		obj->meshSwapSlot = -1;
		obj->frameBase += (short)Frames;
	}

	InitialiseTR1Objects(); // Standard TR1 objects
	InitialiseTR2Objects(); // Standard TR2 objects
	InitialiseTR3Objects(); // Standard TR3 objects
	InitialiseTR4Objects(); // Standard TR4 objects
	InitialiseTR5Objects(); // Standard TR5 objects

	// New objects imported from old TRs
	NewObjects();

	// User defined objects
	CustomObjects();

	InitialiseHair();
	InitialiseSpecialEffects();

	NumRPickups = 0;
	CurrentSequence = 0;
	SequenceResults[0][1][2] = 0;
	SequenceResults[0][2][1] = 1;
	SequenceResults[1][0][2] = 2;
	SequenceResults[1][2][0] = 3;
	SequenceResults[2][0][1] = 4;
	SequenceResults[2][1][0] = 5;
	SequenceUsed[0] = 0;
	SequenceUsed[1] = 0;
	SequenceUsed[2] = 0;
	SequenceUsed[3] = 0;
	SequenceUsed[4] = 0;
	SequenceUsed[5] = 0;

	if (Objects[ID_BATS_EMITTER].loaded)
		Bats = (BAT_STRUCT*)game_malloc(NUM_BATS * sizeof(BAT_STRUCT));

	if (Objects[ID_SPIDERS_EMITTER].loaded)
		Spiders = (SPIDER_STRUCT*)game_malloc(NUM_SPIDERS * sizeof(SPIDER_STRUCT));

	if (Objects[ID_RATS_EMITTER].loaded)
		Rats = (RAT_STRUCT*)game_malloc(NUM_RATS * sizeof(RAT_STRUCT));
}

void InitialiseGameFlags()
{
	ZeroMemory(FlipMap, 255 * sizeof(int));
	ZeroMemory(FlipStats, 255 * sizeof(int));
	
	FlipEffect = -1;
	FlipStatus = 0;
	IsAtmospherePlaying = 0;
	Camera.underwater = 0;
}
