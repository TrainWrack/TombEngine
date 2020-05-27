#pragma once
#include "types.h"

struct BOSS_STRUCT
{
	PHD_VECTOR BeamTarget;
	bool DroppedIcon;
	bool IsInvincible;
	bool DrawExplode; // allow explosion geometry
	bool Charged;
	bool Dead;
	short AttackCount;
	short DeathCount;
	short AttackFlag;
	short AttackType;
	short AttackHeadCount;
	short RingCount;
	short ExplodeCount;
	short LizmanItem, LizmanRoom;
	short HpCounter;
};

struct SHIELD_POINTS
{
	short x;
	short y;
	short z;
	unsigned char rsub;
	unsigned char gsub;
	unsigned char bsub;
	unsigned char pad[3];
	long rgb;
};

struct EXPLOSION_VERTS
{
	short x;
	short z;
	long rgb;
};

struct EXPLOSION_RING
{
	short on;
	short life;   // 0 - 32.
	short speed;
	short radius; // Width is 1/4 of radius.
	short xrot;
	short zrot;
	int x;
	int y;
	int z;
	EXPLOSION_VERTS	verts[16];
};