#include "framework.h"
#include "Game/effects/chaffFX.h"

#include "Game/animation.h"
#include "Game/collision/collide_room.h"
#include "Game/control/control.h"
#include "Game/effects/bubble.h"
#include "Game/effects/smoke.h"
#include "Game/effects/spark.h"
#include "Game/effects/tomb4fx.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Math/Math.h"
#include "Specific/level.h"
#include "Specific/setup.h"
#include "Renderer/Renderer11Enums.h"
#include "Sound/sound.h"

using namespace TEN::Math;

#define	MAX_TRIGGER_RANGE 0x4000

void TriggerChaffEffects(int flareLife)
{
	auto pos = GetJointPosition(LaraItem, LM_LHAND, Vector3i(8, 36, 32));
	auto vect = GetJointPosition(LaraItem, LM_LHAND, Vector3i(8, 36, 1024 + Random::GenerateInt(0, 256)));
	auto vel = vect - pos;
	TriggerChaffEffects(*LaraItem, pos, vel, LaraItem->Animation.Velocity.z, TestEnvironment(ENV_FLAG_WATER, LaraItem->RoomNumber), flareLife);
}

void TriggerChaffEffects(ItemInfo& item, int age)
{
	auto world = Matrix::CreateTranslation(-6, 6, 32) * item.Pose.Orientation.ToRotationMatrix();
	auto pos = item.Pose.Position + Vector3i(world.Translation());

	world = Matrix::CreateTranslation(-6, 6, 32) *
		Matrix::CreateTranslation((GetRandomDraw() & 127) - 64, (GetRandomDraw() & 127) - 64, (GetRandomDraw() & 511) + 512) *
		item.Pose.Orientation.ToRotationMatrix();

	auto vel = Vector3i(world.Translation());
	TriggerChaffEffects(item, pos, vel, item.Animation.Velocity.z, TestEnvironment(ENV_FLAG_WATER, &item), age);
}

void TriggerChaffEffects(ItemInfo& item, const Vector3i& pos, const Vector3i& vel, int speed, bool isUnderwater, int age)
{
	auto pose = item.Pose;
	if (item.IsLara())
	{
		auto handPos = GetJointPosition(&item, LM_RHAND);
		pose.Position = handPos;
		pose.Position.y -= 64;
	}

	auto cond = TestEnvironment(RoomEnvFlags::ENV_FLAG_WATER, pose.Position, item.RoomNumber);
	SoundEffect(cond ? SFX_TR4_FLARE_BURN_UNDERWATER : SFX_TR4_FLARE_BURN_DRY, &pose, SoundEnvironment::Always, 1.0f, 0.5f);

	if (!age)
		return;

	int numSparks = Random::GenerateInt(1, 3);

	for (int i = 0; i < numSparks; i++)
	{
		long dx, dz;

		dx = item.Pose.Position.x - pos.x;
		dz = item.Pose.Position.z - pos.z;

		if (dx < -MAX_TRIGGER_RANGE || dx > MAX_TRIGGER_RANGE || dz < -MAX_TRIGGER_RANGE || dz > MAX_TRIGGER_RANGE)
			return;

		ColorData color;
		color.r = 255;
		color.g = (GetRandomDraw() & 127) + 64;
		color.b = 192 - color.g;

		TriggerChaffSparkles(pos, vel, color, age, item);

		if (isUnderwater)
		{
			TriggerChaffBubbles(pos, item.RoomNumber);
		}
		else
		{
			auto direction = vel.ToVector3();
			direction.Normalize();
			TEN::Effects::Smoke::TriggerFlareSmoke(pos.ToVector3() + direction * 20, direction, age, item.RoomNumber);
		}
	}
}

void TriggerChaffSparkles(const Vector3i& pos, const Vector3i& vel, const ColorData& color, int age, const ItemInfo& item)
{
	TEN::Effects::Spark::TriggerFlareSparkParticles(pos, vel, color, item.RoomNumber);
}

void TriggerChaffSmoke(const Vector3i& pos, const Vector3i& vel, int speed, bool isMoving, bool wind)
{
	SMOKE_SPARKS* smoke;

	int rnd = 0;
	BYTE trans, size;
	
	smoke = &SmokeSparks[GetFreeSmokeSpark()];

	smoke->on = true;

	smoke->sShade = 0;
	if (isMoving)
	{
		trans = (speed << 7) >> 5;
		smoke->dShade = trans;
	}
	else
		smoke->dShade = 64 + (GetRandomDraw() & 7);

	smoke->colFadeSpeed = 4 + (GetRandomDraw() & 3);
	smoke->fadeToBlack = 4;

	rnd = (GetRandomControl() & 3) - (speed >> 12) + 20;
	if (rnd < 9)
	{
		smoke->life = 9;
		smoke->sLife = 9;
	}
	else
	{
		smoke->life = rnd;
		smoke->sLife = rnd;
	}

	smoke->blendMode = BLEND_MODES::BLENDMODE_ADDITIVE;
	
	smoke->x = pos.x + (GetRandomControl() & 7) - 3;
	smoke->y = pos.y + (GetRandomControl() & 7) - 3;
	smoke->z = pos.z + (GetRandomControl() & 7) - 3;
	smoke->xVel = vel.x + ((GetRandomDraw() & 63) - 32);
	smoke->yVel = vel.y;
	smoke->zVel = vel.z + ((GetRandomDraw() & 63) - 32);
	smoke->friction = 4;

	if (GetRandomControl() & 1)
	{
		smoke->flags = SP_EXPDEF | SP_ROTATE | SP_DEF | SP_SCALE;
		smoke->rotAng = (GetRandomControl() & 0xFFF);
		if (GetRandomControl() & 1)
			smoke->rotAdd = (GetRandomControl() & 7) - 24;
		else
			smoke->rotAdd = (GetRandomControl() & 7) + 24;
	}
	else
		smoke->flags = SP_EXPDEF | SP_DEF | SP_SCALE;

	if (wind)
		smoke->flags |= SP_WIND;

	smoke->scalar = 1;
	smoke->gravity = (GetRandomControl() & 3) - 4;
	smoke->maxYvel = 0;
	size = (GetRandomControl() & 7) + (speed >> 7) + 32;
	smoke->sSize = size >> 2;
	smoke->size = smoke->dSize = size;
}

void TriggerChaffBubbles(const Vector3i& pos, int roomNumber)
{
	auto& bubble = Bubbles[GetFreeBubble()];

	bubble = {};
	bubble.active = true;
	bubble.size = 0;
	bubble.age = 0;
	bubble.speed = Random::GenerateFloat(4.0f, 16.0f);
	bubble.sourceColor = Vector4(0, 0, 0, 0);
	float shade = Random::GenerateFloat(0.3f, 0.8f);
	bubble.destinationColor = Vector4(shade, shade, shade, 0.8f);
	bubble.color = bubble.sourceColor;
	bubble.destinationSize = Random::GenerateFloat(32.0f, 96.0f);
	bubble.spriteNum = SPR_BUBBLES;
	bubble.rotation = 0;
	bubble.worldPosition = pos.ToVector3();
	float maxAmplitude = 64;
	bubble.amplitude = Vector3(Random::GenerateFloat(-maxAmplitude, maxAmplitude), Random::GenerateFloat(-maxAmplitude, maxAmplitude), Random::GenerateFloat(-maxAmplitude, maxAmplitude));
	bubble.worldPositionCenter = bubble.worldPosition;
	bubble.wavePeriod = Vector3(Random::GenerateFloat(-PI, PI), Random::GenerateFloat(-PI, PI), Random::GenerateFloat(-PI, PI));
	bubble.waveSpeed = Vector3(1 / Random::GenerateFloat(8, 16), 1 / Random::GenerateFloat(8, 16), 1 / Random::GenerateFloat(8, 16));
	bubble.roomNumber = roomNumber;
}
