#include "framework.h"
#include "Game/effects/ParticleGroup.h"

#include "Game/effects/item_fx.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Game/Setup.h"
#include "Math/Math.h"
#include "Specific/clock.h"
#include "Specific/level.h"
#include "Specific/trutils.h"

using namespace TEN::Math;

namespace TEN::Effects::ParticleGroups
{
	std::array<ParticleGroup, MAX_PARTICLE_GROUPS> ParticleGroupList = {};

	int CreateParticleGroup(GAME_OBJECT_ID objectID, int maxParticles)
	{
		maxParticles = std::clamp(maxParticles, 1, MAX_GROUP_PARTICLES);

		// Find inactive slot.
		for (int i = 0; i < MAX_PARTICLE_GROUPS; i++)
		{
			if (!ParticleGroupList[i].Active)
			{
				int nextGen = ParticleGroupList[i].Generation + 1;
				auto& group = ParticleGroupList[i];
				group = ParticleGroup();
				group.Generation = nextGen;
				group.ID = i;
				group.Active = true;
				group.ObjectID = objectID;
				group.MaxParticles = maxParticles;
				group.Particles.reserve(maxParticles);
				return i;
			}
		}

		TENLog("ParticleGroup limit reached.", LogLevel::Warning);
		return -1;
	}

	bool ParticleGroupHandle::IsValid() const
	{
		if (Index < 0 || Index >= MAX_PARTICLE_GROUPS)
			return false;

		const auto& group = ParticleGroupList[Index];
		return group.Active && group.Generation == Generation;
	}

	ParticleGroup* ParticleGroupHandle::Get()
	{
		if (!IsValid())
			return nullptr;

		return &ParticleGroupList[Index];
	}

	const ParticleGroup* ParticleGroupHandle::Get() const
	{
		if (!IsValid())
			return nullptr;

		return &ParticleGroupList[Index];
	}

	bool ParticleGroup::IsMeshGroup() const
	{
		return Objects[ObjectID].loaded && Objects[ObjectID].nmeshes > 0 &&
			   !TEN::Utils::Contains(SpriteSequencesIds, (int)ObjectID);
	}

	void ParticleGroup::Start()
	{
		State = ParticleGroupState::Running;
	}

	void ParticleGroup::Stop()
	{
		State = ParticleGroupState::Stopped;
	}

	void ParticleGroup::Pause()
	{
		if (State == ParticleGroupState::Running)
			State = ParticleGroupState::Paused;
	}

	void ParticleGroup::Resume()
	{
		if (State == ParticleGroupState::Paused)
			State = ParticleGroupState::Running;
	}

	void ParticleGroup::EmitBurst(int count)
	{
		for (int i = 0; i < count; i++)
			EmitParticle();
	}

	void ParticleGroup::EmitParticle()
	{
		// Check particle limit.
		if (_activeCount >= MaxParticles)
			return;

		// Find inactive particle or add new one.
		GroupParticle* particle = nullptr;

		for (auto& p : Particles)
		{
			if (!p.Active)
			{
				particle = &p;
				break;
			}
		}

		if (particle == nullptr)
		{
			if ((int)Particles.size() >= MaxParticles)
				return;

			Particles.emplace_back();
			particle = &Particles.back();
		}

		// Initialize particle.
		*particle = GroupParticle();
		particle->ID = _nextParticleID++;
		particle->Active = true;
		_activeCount++;
		particle->Position = EmitterPosition;
		particle->PrevPosition = EmitterPosition;

		// Velocity with randomization.
		particle->Velocity = InitVelocity;
		if (InitVelocityRandom != Vector3::Zero)
		{
			particle->Velocity.x += Random::GenerateFloat(-InitVelocityRandom.x, InitVelocityRandom.x);
			particle->Velocity.y += Random::GenerateFloat(-InitVelocityRandom.y, InitVelocityRandom.y);
			particle->Velocity.z += Random::GenerateFloat(-InitVelocityRandom.z, InitVelocityRandom.z);
		}

		particle->Acceleration = InitAcceleration;

		// Lifetime.
		particle->Lifetime = Random::GenerateFloat(LifetimeMin, LifetimeMax);
		if (particle->Lifetime <= 0.0f)
			particle->Lifetime = 0.01f;

		// Size.
		particle->Size = Random::GenerateFloat(InitSizeMin, InitSizeMax);
		particle->PrevSize = particle->Size;

		// Color with randomization.
		float r = Random::GenerateFloat(InitColorMin.R(), InitColorMax.R());
		float g = Random::GenerateFloat(InitColorMin.G(), InitColorMax.G());
		float b = Random::GenerateFloat(InitColorMin.B(), InitColorMax.B());
		float a = Random::GenerateFloat(InitColorMin.A(), InitColorMax.A());
		particle->ParticleColor = Color(r, g, b, a);

		// Rotation.
		particle->Rotation = InitRotation;
		particle->PrevRotation = InitRotation;

		// Sprite / Mesh index.
		particle->SpriteIndex    = InitSpriteIndex;
		particle->SpriteSequence = ObjectID;

		// Mesh orientation.
		particle->Orientation = InitOrientation;

		// Gameplay effects.
		particle->Damage        = InitDamage;
		particle->Poison        = InitPoison;
		particle->Fire          = InitFire;
		particle->ContactRadius = InitContactRadius;

		// Room.
		particle->RoomNumber = RoomNumber;

		// Build initial transform for mesh particles.
		if (IsMeshGroup())
		{
			auto rotMatrix   = Matrix::CreateFromYawPitchRoll(
				particle->Orientation.y, particle->Orientation.x, particle->Orientation.z);
			auto scaleMatrix = Matrix::CreateScale(particle->Size);
			particle->Transform = scaleMatrix * rotMatrix * Matrix::CreateTranslation(particle->Position);
			particle->PrevTransform = particle->Transform;
		}
	}

	void ParticleGroup::Update(float dt)
	{
		if (State == ParticleGroupState::Paused)
			return;

		// Emit new particles if running.
		if (State == ParticleGroupState::Running && EmissionRate > 0.0f)
		{
			EmissionAccum += EmissionRate * dt;

			while (EmissionAccum >= 1.0f)
			{
				EmitParticle();
				EmissionAccum -= 1.0f;
			}
		}

		bool isMesh = IsMeshGroup();

		// Update existing particles.
		for (auto& p : Particles)
		{
			if (!p.Active)
				continue;

			p.StoreInterpolationData();

			// Update lifetime.
			p.Age += dt;
			p.AgeNormalized = p.Age / p.Lifetime;

			if (p.Age >= p.Lifetime)
			{
				p.Active = false;
				_activeCount--;
				continue;
			}

			// Update physics.
			p.Velocity += p.Acceleration * dt;
			p.Position += p.Velocity * dt;

			// Update rotation.
			p.Rotation += InitRotationVel * dt;

			// Rebuild transform for mesh particles.
			if (isMesh)
			{
				auto rotMatrix   = Matrix::CreateFromYawPitchRoll(
					p.Orientation.y, p.Orientation.x, p.Orientation.z);
				auto scaleMatrix = Matrix::CreateScale(p.Size);
				p.Transform = scaleMatrix * rotMatrix * Matrix::CreateTranslation(p.Position);
			}

			// Apply gameplay effects on Lara contact.
			if ((p.Damage > 0.0f || p.Poison > 0 || p.Fire) && LaraItem.Get() != nullptr)
			{
				float dist = Vector3::Distance(p.Position, LaraItem->Pose.Position.ToVector3());
				if (dist <= p.ContactRadius)
				{
					if (p.Fire)
						TEN::Effects::Items::ItemBurn(LaraItem);

					p.EffectTimer += dt;
					if (p.EffectTimer >= 1.0f)
					{
						p.EffectTimer -= 1.0f;
						if (p.Damage > 0.0f)
							DoDamage(LaraItem, (int)p.Damage);
						if (p.Poison > 0)
							Lara.Status.Poison = std::min(Lara.Status.Poison + p.Poison, (int)LARA_POISON_MAX);
					}
				}
				else
				{
					p.EffectTimer = 0.0f;
				}
			}
		}
	}

	int ParticleGroup::GetActiveCount() const
	{
		return _activeCount;
	}

	void ParticleGroup::StoreInterpolationData()
	{
		PrevEmitterPosition = EmitterPosition;

		for (auto& p : Particles)
		{
			if (p.Active)
				p.StoreInterpolationData();
		}
	}

	void UpdateParticleGroups()
	{
		for (auto& group : ParticleGroupList)
		{
			if (!group.Active)
				continue;

			group.Update(DELTA_TIME);

			// Deactivate group if stopped and no active particles remain.
			if (group.State == ParticleGroupState::Stopped && group.GetActiveCount() == 0)
				group.Active = false;
		}
	}

	void ClearParticleGroups()
	{
		for (auto& group : ParticleGroupList)
		{
			group = ParticleGroup();
		}
	}
}
