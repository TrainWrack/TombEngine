#include "framework.h"
#include "Objects/TR3/Entity/Lizard.h"

#include "Game/control/box.h"
#include "Game/effects/tomb4fx.h"
#include "Game/Lara/lara_helpers.h"
#include "Game/misc.h"
#include "Game/people.h"
#include "Specific/level.h"

namespace TEN::Entities::Creatures::TR3
{
	constexpr auto LIZARD_ATTACK_1_DAMAGE = 120;
	constexpr auto LIZARD_ATTACK_2_DAMAGE = 100;

	constexpr auto LIZARD_ATTACK_0_RANGE = SQUARE(BLOCK(2.5f));
	constexpr auto LIZARD_ATTACK_1_RANGE = SQUARE(BLOCK(0.75f));
	constexpr auto LIZARD_ATTACK_2_RANGE = SQUARE(BLOCK(1.5f));
	constexpr auto LIZARD_WALK_RANGE	 = SQUARE(BLOCK(2));

	constexpr auto LIZARD_WALK_CHANCE		= 1 / 256.0f;
	constexpr auto LIZARD_BORED_WALK_CHANCE = 1 / 512.0f;
	constexpr auto LIZARD_WAIT_CHANCE		= 1 / 256.0f;

	constexpr auto LIZARD_WALK_TURN_RATE_MAX = ANGLE(10.0f);
	constexpr auto LIZARD_RUN_TURN_RATE_MAX	 = ANGLE(4.0f);

	constexpr auto LIZARD_VAULT_SHIFT = 260;

	const auto LizardBiteAttackBite	 = BiteInfo(Vector3(0.0f, -120.0f, 120.0f), 10);
	const auto LizardSwipeAttackBite = BiteInfo(Vector3::Zero, 5);
	const auto LizardGasBite		 = BiteInfo(Vector3(0.0f, -64.0f, 56.0f), 9);
	const auto LizardSwipeAttackJoints = std::vector<unsigned int>{ 5 };
	const auto LizardBiteAttackJoints  = std::vector<unsigned int>{ 10 };

	enum LizardState
	{
		// No state 0.
		LIZARD_STATE_IDLE = 1,
		LIZARD_STATE_WALK_FORWARD = 2,
		LIZARD_STATE_PUNCH_2 = 3,
		LIZARD_STATE_AIM_2 = 4,
		LIZARD_STATE_WAIT = 5,
		LIZARD_STATE_AIM_1 = 6,
		LIZARD_STATE_AIM_0 = 7,
		LIZARD_STATE_PUNCH_1 = 8,
		LIZARD_STATE_PUNCH_0 = 9,
		LIZARD_STATE_RUN_FORWARD = 10,
		LIZARD_STATE_DEATH = 11,
		LIZARD_STATE_VAULT_3_STEPS_UP = 12,
		LIZARD_STATE_VAULT_1_STEP_UP = 13,
		LIZARD_STATE_VAULT_2_STEPS_UP = 14,
		LIZARD_STATE_VAULT_4_STEPS_DOWN = 15
	};

	enum LizardAnim
	{
		LIZARD_ANIM_SLIDE_1 = 23,
		LIZARD_ANIM_DEATH = 26,
		LIZARD_ANIM_VAULT_4_STEPS_UP = 27,
		LIZARD_ANIM_VAULT_2_STEPS_UP = 28,
		LIZARD_ANIM_VAULT_3_STEPS_UP = 29,
		LIZARD_ANIM_VAULT_4_STEPS_DOWN = 30,
		LIZARD_ANIM_SLIDE_2 = 31
	};

	void LizardControl(short itemNumber)
	{
		if (!CreatureActive(itemNumber))
			return;

		auto& item = g_Level.Items[itemNumber];
		auto& creature = *GetCreatureInfo(&item);

		short headingAngle = 0;
		short tiltAngle = 0;
		auto headOrient = EulerAngles::Zero;

		if (item.HitPoints <= 0)
		{
			// Avoid doing the death animation if summoned.
			if (item.Animation.ActiveState != LIZARD_STATE_DEATH)
				SetAnimation(&item, LIZARD_ANIM_DEATH);

			// Explode if summoned.
			if (item.TestFlagEqual(0, 1) && item.Animation.FrameNumber == GetFrameNumber(&item, 50))
				CreatureDie(itemNumber, true);
		}
		else
		{
			AI_INFO AI;
			CreatureAIInfo(&item, &AI);
			GetCreatureMood(&item, &AI, true);
			CreatureMood(&item, &AI, true);

			if (IsLizardTargetBlocked(item))
				creature.Mood = MoodType::Attack;

			headingAngle = CreatureTurn(&item, creature.MaxTurn);

			// NOTE: Avoid turning the head when he is climbing or falling.
			if (AI.ahead && item.Animation.ActiveState < LIZARD_STATE_DEATH)
			{
				headOrient.x = AI.xAngle;
				headOrient.y = AI.angle;
			}

			bool isLaraPoisonedOrTargetBlocked = 
				(creature.Enemy != nullptr && GetLaraInfo(creature.Enemy)->PoisonPotency < 256) ||
				IsLizardTargetBlocked(item);

			switch (item.Animation.ActiveState)
			{
			case LIZARD_STATE_IDLE:
				creature.MaxTurn = 0;
				creature.Flags = 0;

				if (creature.Mood == MoodType::Escape)
				{
					item.Animation.TargetState = LIZARD_STATE_RUN_FORWARD;
				}
				else if (creature.Mood == MoodType::Bored)
				{
					if (item.Animation.RequiredState)
					{
						item.Animation.TargetState = item.Animation.RequiredState;
					}
					else if (Random::TestProbability(LIZARD_BORED_WALK_CHANCE))
					{
						item.Animation.TargetState = LIZARD_STATE_WALK_FORWARD;
					}
					else
					{
						item.Animation.TargetState = LIZARD_STATE_WAIT;
					}
				}
				else if (AI.bite && AI.distance < LIZARD_ATTACK_1_RANGE)
				{
					item.Animation.TargetState = LIZARD_STATE_AIM_1;
				}
				else if (Targetable(&item, &AI) && AI.bite &&
					AI.distance < LIZARD_ATTACK_0_RANGE && isLaraPoisonedOrTargetBlocked)
				{
					item.Animation.TargetState = LIZARD_STATE_AIM_0;
				}
				else
				{
					item.Animation.TargetState = LIZARD_STATE_RUN_FORWARD;
				}

				break;

			case LIZARD_STATE_WAIT:
				creature.MaxTurn = 0;

				if (creature.Mood != MoodType::Bored)
				{
					item.Animation.TargetState = LIZARD_STATE_IDLE;
				}
				else if (Random::TestProbability(LIZARD_WALK_CHANCE))
				{
					item.Animation.RequiredState = LIZARD_STATE_WALK_FORWARD;
					item.Animation.TargetState = LIZARD_STATE_IDLE;
				}

				break;

			case LIZARD_STATE_WALK_FORWARD:
				if (TestAnimNumber(item, LIZARD_ANIM_SLIDE_1) || TestAnimNumber(item, LIZARD_ANIM_SLIDE_2))
					creature.MaxTurn = 0;
				else
					creature.MaxTurn = LIZARD_WALK_TURN_RATE_MAX;

				if (creature.Mood == MoodType::Escape)
				{
					item.Animation.TargetState = LIZARD_STATE_RUN_FORWARD;
				}
				else if (creature.Mood == MoodType::Bored)
				{
					if (Random::TestProbability(LIZARD_WAIT_CHANCE))
					{
						item.Animation.RequiredState = LIZARD_STATE_WAIT;
						item.Animation.TargetState = LIZARD_STATE_IDLE;
					}
				}
				else if (AI.bite && AI.distance < LIZARD_ATTACK_1_RANGE)
				{
					item.Animation.TargetState = LIZARD_STATE_IDLE;
				}
				else if (AI.bite && AI.distance < LIZARD_ATTACK_2_RANGE)
				{
					item.Animation.TargetState = LIZARD_STATE_AIM_2;
				}
				else if (Targetable(&item, &AI) && AI.distance < LIZARD_ATTACK_0_RANGE &&
					isLaraPoisonedOrTargetBlocked)
				{
					item.Animation.TargetState = LIZARD_STATE_IDLE;
				}
				else if (AI.distance > LIZARD_WALK_RANGE)
				{
					item.Animation.TargetState = LIZARD_STATE_RUN_FORWARD;
				}

				break;

			case LIZARD_STATE_RUN_FORWARD:
				creature.MaxTurn = LIZARD_RUN_TURN_RATE_MAX;
				tiltAngle = headingAngle / 2;

				if (creature.Mood == MoodType::Escape)
				{
					break;
				}
				else if (creature.Mood == MoodType::Bored)
				{
					item.Animation.TargetState = LIZARD_STATE_WALK_FORWARD;
				}
				else if (AI.bite && AI.distance < LIZARD_ATTACK_1_RANGE)
				{
					item.Animation.TargetState = LIZARD_STATE_IDLE;
				}
				else if (Targetable(&item, &AI) && AI.distance < LIZARD_ATTACK_0_RANGE &&
					isLaraPoisonedOrTargetBlocked)
				{
					item.Animation.TargetState = LIZARD_STATE_IDLE;
				}
				else if (AI.ahead && AI.distance < LIZARD_WALK_RANGE)
				{
					item.Animation.TargetState = LIZARD_STATE_WALK_FORWARD;
				}

				break;

			case LIZARD_STATE_AIM_0:
				creature.MaxTurn = 0;
				creature.Flags = 0;

				if (abs(AI.angle) < LIZARD_RUN_TURN_RATE_MAX)
				{
					item.Pose.Orientation.y += AI.angle;
				}
				else if (AI.angle < 0)
				{
					item.Pose.Orientation.y -= LIZARD_RUN_TURN_RATE_MAX;
				}
				else
				{
					item.Pose.Orientation.y += LIZARD_RUN_TURN_RATE_MAX;
				}

				// Maybe we should add targetable as well? -- TokyoSU
				if (AI.bite && AI.distance < LIZARD_ATTACK_0_RANGE && isLaraPoisonedOrTargetBlocked)
					item.Animation.TargetState = LIZARD_STATE_PUNCH_0;
				else
					item.Animation.TargetState = LIZARD_STATE_IDLE;

				break;

			case LIZARD_STATE_AIM_1:
				creature.MaxTurn = LIZARD_WALK_TURN_RATE_MAX;
				creature.Flags = 0;

				if (AI.ahead && AI.distance < LIZARD_ATTACK_1_RANGE)
					item.Animation.TargetState = LIZARD_STATE_PUNCH_1;
				else
					item.Animation.TargetState = LIZARD_STATE_IDLE;

				break;

			case LIZARD_STATE_AIM_2:
				creature.MaxTurn = LIZARD_WALK_TURN_RATE_MAX;
				creature.Flags = 0;

				if (AI.ahead && AI.distance < LIZARD_ATTACK_2_RANGE)
					item.Animation.TargetState = LIZARD_STATE_PUNCH_2;
				else
					item.Animation.TargetState = LIZARD_STATE_IDLE;

				break;

			case LIZARD_STATE_PUNCH_0:
				creature.MaxTurn = 0;

				if (abs(AI.angle) < LIZARD_RUN_TURN_RATE_MAX)
				{
					item.Pose.Orientation.y += AI.angle;
				}
				else if (AI.angle < 0)
				{
					item.Pose.Orientation.y -= LIZARD_RUN_TURN_RATE_MAX;
				}
				else
				{
					item.Pose.Orientation.y += LIZARD_RUN_TURN_RATE_MAX;
				}

				if (TestAnimFrameRange(item, 7, 28))
				{
					if (creature.Flags < 24)
						creature.Flags += 2;

					if (creature.Flags < 24)
						SpawnLizardGas(itemNumber, LizardGasBite, creature.Flags);
					else
						SpawnLizardGas(itemNumber, LizardGasBite, (GetRandomControl() & 15) + 8);
				}

				if (TestAnimFrame(item, 28))
					creature.Flags = 0;

				break;

			case LIZARD_STATE_PUNCH_1:
				creature.MaxTurn = 0;

				if (!creature.Flags && item.TouchBits.Test(LizardSwipeAttackJoints))
				{
					DoDamage(creature.Enemy, LIZARD_ATTACK_1_DAMAGE);
					CreatureEffect(&item, LizardSwipeAttackBite, DoBloodSplat);
					SoundEffect(SFX_TR4_LARA_THUD, &item.Pose);
					creature.Flags = 1;
				}

				if (AI.distance < LIZARD_ATTACK_2_RANGE)
					item.Animation.TargetState = LIZARD_STATE_PUNCH_2;

				break;

			case LIZARD_STATE_PUNCH_2:
				creature.MaxTurn = 0;

				if (creature.Flags != 2 && item.TouchBits.Test(LizardBiteAttackJoints))
				{
					DoDamage(creature.Enemy, LIZARD_ATTACK_2_DAMAGE);
					CreatureEffect(&item, LizardSwipeAttackBite, DoBloodSplat);
					SoundEffect(SFX_TR4_LARA_THUD, &item.Pose);
					creature.Flags = 2;
				}

				break;
			}
		}

		CreatureTilt(&item, tiltAngle);
		CreatureJoint(&item, 0, headOrient.x);
		CreatureJoint(&item, 1, headOrient.y);

		if (item.Animation.ActiveState < LIZARD_STATE_DEATH)
		{
			switch (CreatureVault(itemNumber, headingAngle, 2, LIZARD_VAULT_SHIFT))
			{
			case 2:
				SetAnimation(&item, LIZARD_ANIM_VAULT_2_STEPS_UP);
				creature.MaxTurn = 0;
				break;

			case 3:
				SetAnimation(&item, LIZARD_ANIM_VAULT_3_STEPS_UP);
				creature.MaxTurn = 0;
				break;

			case 4:
				SetAnimation(&item, LIZARD_ANIM_VAULT_4_STEPS_UP);
				creature.MaxTurn = 0;
				break;

			case -4:
				SetAnimation(&item, LIZARD_ANIM_VAULT_4_STEPS_DOWN);
				creature.MaxTurn = 0;
				break;
			}
		}
		else
		{
			CreatureAnimation(itemNumber, headingAngle, 0);
		}
	}

	bool IsLizardTargetBlocked(ItemInfo& item)
	{
		auto& creature = *GetCreatureInfo(&item);

		return (creature.Enemy && creature.Enemy->BoxNumber != NO_BOX &&
				(g_Level.Boxes[creature.Enemy->BoxNumber].flags & BLOCKABLE));
	}

	void SpawnLizardGas(int itemNumber, const BiteInfo& bite, int speed)
	{
		for (int i = 0; i < 2; i++)
			ThrowPoison(itemNumber, bite.meshNum, Vector3i(bite.Position), Vector3i(0, -100, speed << 2), Vector3(0, 1, 0));

		ThrowPoison(itemNumber, bite.meshNum, Vector3i(bite.Position), Vector3i(0, -100, speed << 1), Vector3(0, 1, 0));
	}
}
