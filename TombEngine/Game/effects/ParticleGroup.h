#pragma once

#include "Objects/objectslist.h"
#include "Renderer/RendererEnums.h"

namespace TEN::Effects::ParticleGroups
{
	using namespace DirectX::SimpleMath;

	// Constants.
	constexpr auto MAX_PARTICLE_GROUPS	  = 64;
	constexpr auto MAX_GROUP_PARTICLES	  = 256;
	constexpr auto DEFAULT_RENDER_DISTANCE = 32768.0f;

	enum class ParticleGroupState
	{
		Stopped,
		Running,
		Paused
	};

	struct GroupParticle
	{
		// Identity
		int	 ID	    = 0;
		bool Active = false;

		// Physics
		Vector3 Position     = Vector3::Zero;
		Vector3 Velocity     = Vector3::Zero;
		Vector3 Acceleration = Vector3::Zero;

		// Visuals
		Color   ParticleColor = Color(1.0f, 1.0f, 1.0f, 1.0f);
		float   Size          = 1.0f;
		float   Rotation      = 0.0f;
		int     SpriteIndex   = 0;

		// Lifetime
		float Age           = 0.0f;
		float Lifetime      = 1.0f;
		float AgeNormalized = 0.0f;

		// Room
		short RoomNumber = 0;

		// Interpolation
		Vector3 PrevPosition = Vector3::Zero;
		float   PrevSize     = 0.0f;
		float   PrevRotation = 0.0f;

		void StoreInterpolationData()
		{
			PrevPosition = Position;
			PrevSize     = Size;
			PrevRotation = Rotation;
		}
	};

	class ParticleGroup
	{
	public:
		// Identity
		int	 ID     = 0;
		bool Active = false;

		// Sprite
		GAME_OBJECT_ID SpriteSeqID = GAME_OBJECT_ID::ID_DEFAULT_SPRITES;
		int            MaxParticles = MAX_GROUP_PARTICLES;

		// Emission state
		ParticleGroupState State         = ParticleGroupState::Stopped;
		float              EmissionRate  = 10.0f;
		float              EmissionAccum = 0.0f;

		// Position (emission point)
		Vector3 EmitterPosition = Vector3::Zero;

		// Initial particle templates
		Vector3 InitVelocity       = Vector3::Zero;
		Vector3 InitVelocityRandom = Vector3::Zero;
		Vector3 InitAcceleration   = Vector3::Zero;
		float   LifetimeMin        = 1.0f;
		float   LifetimeMax        = 1.0f;
		float   InitSizeMin        = 16.0f;
		float   InitSizeMax        = 16.0f;
		Color   InitColorMin       = Color(1.0f, 1.0f, 1.0f, 1.0f);
		Color   InitColorMax       = Color(1.0f, 1.0f, 1.0f, 1.0f);
		float   InitRotation       = 0.0f;
		float   InitRotationVel    = 0.0f;
		int     InitSpriteIndex    = 0;

		// Rendering
		BlendMode RenderBlendMode  = BlendMode::AlphaBlend;
		float     RenderDistance    = DEFAULT_RENDER_DISTANCE;

		// Room
		short RoomNumber = 0;

		// Particles
		std::vector<GroupParticle> Particles = {};

		// Interpolation
		Vector3 PrevEmitterPosition = Vector3::Zero;

		// Construction
		ParticleGroup() = default;

		// Emission control
		void Start();
		void Stop();
		void Pause();
		void Resume();
		void EmitBurst(int count);

		// Update
		void Update(float dt);

		// Queries
		int GetActiveCount() const;

		void StoreInterpolationData();

	private:
		int  _nextParticleID = 0;

		void EmitParticle();
	};

	// Global particle group storage.
	extern std::array<ParticleGroup, MAX_PARTICLE_GROUPS> ParticleGroupList;

	// Management functions.
	int  CreateParticleGroup(GAME_OBJECT_ID spriteSeqID, int maxParticles);
	void UpdateParticleGroups();
	void ClearParticleGroups();
}
