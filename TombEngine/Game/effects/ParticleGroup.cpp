#include "framework.h"
#include "Game/effects/ParticleGroup.h"

#include "Math/Math.h"
#include "Specific/clock.h"

using namespace TEN::Math;

namespace TEN::Effects::ParticleGroups
{
	std::array<ParticleGroup, MAX_PARTICLE_GROUPS> ParticleGroupList = {};

	int CreateParticleGroup(GAME_OBJECT_ID spriteSeqID, int maxParticles)
	{
		maxParticles = std::clamp(maxParticles, 1, MAX_GROUP_PARTICLES);

		// Find inactive slot.
		for (int i = 0; i < MAX_PARTICLE_GROUPS; i++)
		{
			if (!ParticleGroupList[i].Active)
			{
				auto& group = ParticleGroupList[i];
				group = ParticleGroup();
				group.ID = i;
				group.Active = true;
				group.SpriteSeqID = spriteSeqID;
				group.MaxParticles = maxParticles;
				group.Particles.reserve(maxParticles);
				return i;
			}
		}

		TENLog("ParticleGroup limit reached.", LogLevel::Warning);
		return -1;
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
		if (GetActiveCount() >= MaxParticles)
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

		// Sprite.
		particle->SpriteIndex = InitSpriteIndex;

		// Room.
		particle->RoomNumber = RoomNumber;
	}

	void ParticleGroup::Update(float dt)
	{
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
				continue;
			}

			// Update physics.
			p.Velocity += p.Acceleration * dt;
			p.Position += p.Velocity * dt;

			// Update rotation.
			p.Rotation += InitRotationVel * dt;
		}
	}

	int ParticleGroup::GetActiveCount() const
	{
		int count = 0;
		for (const auto& p : Particles)
		{
			if (p.Active)
				count++;
		}

		return count;
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
