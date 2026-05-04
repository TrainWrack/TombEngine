#include "framework.h"
#include "Scripting/Internal/TEN/Effects/ParticleGroupFunctions.h"

#include "Game/effects/ParticleGroup.h"
#include "Game/Setup.h"
#include "Math/Math.h"
#include "Objects/Utils/object_helper.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Effects/BlendIDs.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Specific/level.h"

using namespace TEN::Effects::ParticleGroups;
using namespace TEN::Math;
using namespace TEN::Scripting::Types;

/// Functions to generate effects.
// @tentable Effects.ParticleGroups 
// @pragma nostrip

namespace TEN::Scripting::Effects::ParticleGroups
{
	/// Create a particle group for managing collections of particles with Lua-driven behavior.
	// If the specified object ID is a sprite sequence, particles render as sprites.
	// If it is a mesh object (moveable), particles render as 3D meshes, and the sprite index
	// selects which mesh within the object to draw.
	// @function CreateParticleGroup
	// @tparam Objects.ObjID objectID Object slot ID (sprite sequence or mesh object).
	// @tparam int maxParticles Maximum number of particles in the group.
	// @treturn ParticleGroup A new ParticleGroup handle, or nil on failure.
	static ParticleGroupHandle LuaCreateParticleGroup(GAME_OBJECT_ID objectID, int maxParticles)
	{
		if (!CheckIfSlotExists(objectID, "CreateParticleGroup"))
			return ParticleGroupHandle{};

		int id = CreateParticleGroup(objectID, maxParticles);
		if (id < 0)
			return ParticleGroupHandle{};

		return ParticleGroupHandle{ id, TEN::Effects::ParticleGroups::ParticleGroupList[id].Generation };
	}

	void Register(sol::table& parent)
	{
		// Register ParticleGroup usertype backed by the stable handle.
		// All methods validate the handle before accessing the underlying group.
		// Rotation fields are exposed in degrees for consistency with SetInitialRotation.
		// Blend mode for mesh groups is defined per material; SetBlendMode applies to sprite groups only.
		parent.new_usertype<ParticleGroupHandle>(
			ScriptReserved_ParticleGroup,

			/// Start emitting particles.
			// @function ParticleGroup:Start
			ScriptReserved_ParticleGroupStart, [](ParticleGroupHandle& handle)
			{
				if (auto* group = handle.Get()) group->Start();
			},

			/// Stop emitting particles. Existing particles continue until they expire.
			// @function ParticleGroup:Stop
			ScriptReserved_ParticleGroupStop, [](ParticleGroupHandle& handle)
			{
				if (auto* group = handle.Get()) group->Stop();
			},

			/// Pause the group. Stops emission and freezes all existing particles in place.
			// @function ParticleGroup:Pause
			ScriptReserved_ParticleGroupPause, [](ParticleGroupHandle& handle)
			{
				if (auto* group = handle.Get()) group->Pause();
			},

			/// Resume a paused group.
			// @function ParticleGroup:Resume
			ScriptReserved_ParticleGroupResume, [](ParticleGroupHandle& handle)
			{
				if (auto* group = handle.Get()) group->Resume();
			},

			/// Emit a burst of particles immediately.
			// @function ParticleGroup:EmitBurst
			// @tparam int count Number of particles to emit.
			ScriptReserved_ParticleGroupEmitBurst, [](ParticleGroupHandle& handle, int count)
			{
				if (auto* group = handle.Get()) group->EmitBurst(count);
			},

			/// Get number of active particles.
			// @function ParticleGroup:GetActiveCount
			// @treturn int Number of active particles.
			ScriptReserved_ParticleGroupGetActiveCount, [](const ParticleGroupHandle& handle) -> int
			{
				const auto* group = handle.Get();
				return group ? group->GetActiveCount() : 0;
			},

			/// Set the emission rate.
			// @function ParticleGroup:SetEmissionRate
			// @tparam float rate Particles per second.
			ScriptReserved_ParticleGroupSetEmissionRate, [](ParticleGroupHandle& handle, float rate)
			{
				if (auto* group = handle.Get()) group->EmissionRate = std::max(0.0f, rate);
			},

			/// Set the emitter position.
			// @function ParticleGroup:SetPosition
			// @tparam Vec3 pos World position.
			ScriptReserved_ParticleGroupSetPosition, [](ParticleGroupHandle& handle, const Vec3& pos)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				group->EmitterPosition = pos.ToVector3();
				group->RoomNumber = FindRoomNumber(Vector3i((int)pos.x, (int)pos.y, (int)pos.z));
			},

			/// Get the emitter position.
			// @function ParticleGroup:GetPosition
			// @treturn Vec3 World position.
			ScriptReserved_ParticleGroupGetPosition, [](const ParticleGroupHandle& handle) -> sol::optional<Vec3>
			{
				const auto* group = handle.Get();
				if (!group)
					return sol::nullopt;

				return Vec3(group->EmitterPosition);
			},

			/// Set initial velocity for new particles.
			// @function ParticleGroup:SetInitialVelocity
			// @tparam Vec3 vel Velocity vector.
			ScriptReserved_ParticleGroupSetInitialVelocity, [](ParticleGroupHandle& handle, const Vec3& vel)
			{
				if (auto* group = handle.Get()) group->InitVelocity = vel.ToVector3();
			},

			/// Set random range added to initial velocity.
			// @function ParticleGroup:SetInitialVelocityRandom
			// @tparam Vec3 range Random range per axis (value is +/- range).
			ScriptReserved_ParticleGroupSetVelocityRandom, [](ParticleGroupHandle& handle, const Vec3& range)
			{
				if (auto* group = handle.Get()) group->InitVelocityRandom = range.ToVector3();
			},

			/// Set initial acceleration for new particles.
			// @function ParticleGroup:SetInitialAcceleration
			// @tparam Vec3 accel Acceleration vector.
			ScriptReserved_ParticleGroupSetInitialAcceleration, [](ParticleGroupHandle& handle, const Vec3& accel)
			{
				if (auto* group = handle.Get()) group->InitAcceleration = accel.ToVector3();
			},

			/// Set a fixed lifetime for new particles.
			// @function ParticleGroup:SetLifetime
			// @tparam float seconds Lifetime in seconds.
			ScriptReserved_ParticleGroupSetLifetime, [](ParticleGroupHandle& handle, float seconds)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				seconds = std::max(0.01f, seconds);
				group->LifetimeMin = seconds;
				group->LifetimeMax = seconds;
			},

			/// Set lifetime range for new particles.
			// @function ParticleGroup:SetLifetimeRange
			// @tparam float minSeconds Minimum lifetime.
			// @tparam float maxSeconds Maximum lifetime.
			ScriptReserved_ParticleGroupSetLifetimeRange, [](ParticleGroupHandle& handle, float minSec, float maxSec)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				group->LifetimeMin = std::max(0.01f, minSec);
				group->LifetimeMax = std::max(group->LifetimeMin, maxSec);
			},

			/// Set fixed initial size for new particles.
			// @function ParticleGroup:SetInitialSize
			// @tparam float size Particle size.
			ScriptReserved_ParticleGroupSetInitialSize, [](ParticleGroupHandle& handle, float size)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				group->InitSizeMin = size;
				group->InitSizeMax = size;
			},

			/// Set initial size range for new particles.
			// @function ParticleGroup:SetInitialSizeRange
			// @tparam float min Minimum size.
			// @tparam float max Maximum size.
			ScriptReserved_ParticleGroupSetInitialSizeRange, [](ParticleGroupHandle& handle, float minSize, float maxSize)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				group->InitSizeMin = minSize;
				group->InitSizeMax = std::max(minSize, maxSize);
			},

			/// Set initial color for new particles.
			// @function ParticleGroup:SetInitialColor
			// @tparam Color color Particle color.
			ScriptReserved_ParticleGroupSetInitialColor, [](ParticleGroupHandle& handle, const ScriptColor& color)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				group->InitColorMin = Color(color);
				group->InitColorMax = Color(color);
			},

			/// Set initial color range for new particles.
			// @function ParticleGroup:SetInitialColorRange
			// @tparam Color min Minimum color.
			// @tparam Color max Maximum color.
			ScriptReserved_ParticleGroupSetInitialColorRange, [](ParticleGroupHandle& handle, const ScriptColor& minColor, const ScriptColor& maxColor)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				group->InitColorMin = Color(minColor);
				group->InitColorMax = Color(maxColor);
			},

			/// Set initial rotation for new particles.
			// @function ParticleGroup:SetInitialRotation
			// @tparam float rotation Rotation in degrees.
			ScriptReserved_ParticleGroupSetInitialRotation, [](ParticleGroupHandle& handle, float rotation)
			{
				if (auto* group = handle.Get()) group->InitRotation = rotation * RADIAN;
			},

			/// Set initial rotational velocity for new particles.
			// @function ParticleGroup:SetInitialRotationVelocity
			// @tparam float rotVel Rotational velocity in degrees per second.
			ScriptReserved_ParticleGroupSetInitialRotVel, [](ParticleGroupHandle& handle, float rotVel)
			{
				if (auto* group = handle.Get()) group->InitRotationVel = rotVel * RADIAN;
			},

			/// Set blend mode for rendering. Applies to sprite groups only.
			// Mesh groups always use their per-material blend modes.
			// @function ParticleGroup:SetBlendMode
			// @tparam Effects.BlendID mode Blend mode.
			ScriptReserved_ParticleGroupSetBlendMode, [](ParticleGroupHandle& handle, BlendMode mode)
			{
				if (auto* group = handle.Get()) group->RenderBlendMode = mode;
			},

			/// Set object (sprite sequence or mesh object) for the group.
			// For sprite sequences, the sprite index selects which sprite to draw.
			// For mesh objects, the sprite index selects which mesh to draw.
			// @function ParticleGroup:SetSpriteSequence
			// @tparam Objects.ObjID objectID Object slot ID.
			ScriptReserved_ParticleGroupSetSpriteSequence, [](ParticleGroupHandle& handle, GAME_OBJECT_ID objectID)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				if (CheckIfSlotExists(objectID, "ParticleGroup:SetSpriteSequence"))
					group->ObjectID = objectID;
			},

			/// Set sprite/mesh index for newly emitted particles.
			// For sprite sequences, this selects the sprite within the sequence.
			// For mesh objects, this selects which mesh to draw.
			// @function ParticleGroup:SetSpriteIndex
			// @tparam int index Sprite or mesh index.
			ScriptReserved_ParticleGroupSetSpriteIndex, [](ParticleGroupHandle& handle, int index)
			{
				if (auto* group = handle.Get()) group->InitSpriteIndex = index;
			},

			/// Get the current sprite/mesh index used for new particles.
			// @function ParticleGroup:GetSpriteIndex
			// @treturn int Current sprite or mesh index.
			ScriptReserved_ParticleGroupGetSpriteIndex, [](const ParticleGroupHandle& handle) -> sol::optional<int>
			{
				const auto* group = handle.Get();
				if (!group)
					return sol::nullopt;

				return group->InitSpriteIndex;
			},

			/// Get the current object ID.
			// @function ParticleGroup:GetSpriteSequence
			// @treturn Objects.ObjID Current object slot ID.
			ScriptReserved_ParticleGroupGetSpriteSequence, [](const ParticleGroupHandle& handle) -> sol::optional<GAME_OBJECT_ID>
			{
				const auto* group = handle.Get();
				if (!group)
					return sol::nullopt;

				return group->ObjectID;
			},

			/// Check if this group renders meshes (true) or sprites (false).
			// @function ParticleGroup:IsMeshGroup
			// @treturn bool True if particles render as 3D meshes.
			ScriptReserved_ParticleGroupIsMeshGroup, [](const ParticleGroupHandle& handle) -> bool
			{
				const auto* group = handle.Get();
				return group ? group->IsMeshGroup() : false;
			},

			/// Set initial orientation for mesh particles (degrees: x=pitch, y=yaw, z=roll).
			// Only affects mesh groups; ignored for sprite groups.
			// @function ParticleGroup:SetInitialOrientation
			// @tparam Vec3 orientation Orientation in degrees (pitch, yaw, roll).
			ScriptReserved_ParticleGroupSetInitialOrientation, [](ParticleGroupHandle& handle, const Vec3& orient)
			{
				if (auto* group = handle.Get())
				{
					group->InitOrientation = Vector3(
						orient.x * RADIAN, orient.y * RADIAN, orient.z * RADIAN);
				}
			},

			/// Set the HP damage dealt to Lara per second when a particle is in contact.
			// Set to 0 to disable. New particles inherit this value.
			// @function ParticleGroup:SetDamage
			// @tparam float damage HP per second. Use 0 to disable.
			ScriptReserved_ParticleGroupSetDamage, [](ParticleGroupHandle& handle, float damage)
			{
				if (auto* group = handle.Get()) group->InitDamage = std::max(0.0f, damage);
			},

			/// Set the poison level applied to Lara per second when a particle is in contact.
			// Clamped to [0, LARA_POISON_MAX]. Set to 0 to disable. New particles inherit this value.
			// @function ParticleGroup:SetPoison
			// @tparam int poison Poison units per second. Use 0 to disable.
			ScriptReserved_ParticleGroupSetPoison, [](ParticleGroupHandle& handle, int poison)
			{
				if (auto* group = handle.Get()) group->InitPoison = std::max(0, poison);
			},

			/// Set whether particles set Lara on fire on contact.
			// New particles inherit this value.
			// @function ParticleGroup:SetFire
			// @tparam bool enabled True to enable fire on contact.
			ScriptReserved_ParticleGroupSetFire, [](ParticleGroupHandle& handle, bool enabled)
			{
				if (auto* group = handle.Get()) group->InitFire = enabled;
			},

			/// Get a specific particle's data as a table.
			// @function ParticleGroup:GetParticle
			// @tparam int index Particle index (0-based).
			// @treturn table|nil Particle data table with fields: position, velocity, acceleration,
			// size, rotation (in degrees), color, age, lifetime, ageNormalized, spriteIndex, spriteSequence,
			// orientation (in degrees), damage, poison, fire.
			// Returns nil if the index is out of range, the particle is inactive, or the group is invalid.
			ScriptReserved_ParticleGroupGetParticle, [](ParticleGroupHandle& handle, int index, sol::this_state s) -> sol::object
			{
				auto* group = handle.Get();
				if (!group)
					return sol::nil;

				if (index < 0 || index >= (int)group->Particles.size() || !group->Particles[index].Active)
					return sol::nil;

				const auto& particle = group->Particles[index];
				sol::state_view lua(s);
				auto tbl = lua.create_table();
				tbl["id"]             = particle.ID;
				tbl["position"]       = Vec3(particle.Position);
				tbl["velocity"]       = Vec3(particle.Velocity);
				tbl["acceleration"]   = Vec3(particle.Acceleration);
				tbl["size"]           = particle.Size;
				tbl["rotation"]       = particle.Rotation / RADIAN;
				tbl["color"]          = ScriptColor(particle.ParticleColor);
				tbl["age"]            = particle.Age;
				tbl["lifetime"]       = particle.Lifetime;
				tbl["ageNormalized"]  = particle.AgeNormalized;
				tbl["spriteIndex"]    = particle.SpriteIndex;
				tbl["spriteSequence"] = particle.SpriteSequence;
				tbl["orientation"]    = Vec3(particle.Orientation.x / RADIAN, particle.Orientation.y / RADIAN, particle.Orientation.z / RADIAN);
				tbl["damage"]         = particle.Damage;
				tbl["poison"]         = particle.Poison;
				tbl["fire"]           = particle.Fire;
				return tbl;
			},

			/// Set a specific particle's properties from a table.
			// All rotation and orientation values are in degrees.
			// @function ParticleGroup:SetParticle
			// @tparam int index Particle index (0-based).
			// @tparam table data Table with properties to set: position, velocity, acceleration,
			// size, color, rotation (degrees), spriteIndex, spriteSequence, orientation (degrees),
			// damage, poison, fire.
			ScriptReserved_ParticleGroupSetParticle, [](ParticleGroupHandle& handle, int index, sol::table data)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				if (index < 0 || index >= (int)group->Particles.size() || !group->Particles[index].Active)
					return;

				auto& particle = group->Particles[index];

				if (auto pos = data.get<sol::optional<Vec3>>("position"))
					particle.Position = pos->ToVector3();
				if (auto vel = data.get<sol::optional<Vec3>>("velocity"))
					particle.Velocity = vel->ToVector3();
				if (auto accel = data.get<sol::optional<Vec3>>("acceleration"))
					particle.Acceleration = accel->ToVector3();
				if (auto size = data.get<sol::optional<float>>("size"))
					particle.Size = *size;
				if (auto rot = data.get<sol::optional<float>>("rotation"))
					particle.Rotation = *rot * RADIAN;
				if (auto sprite = data.get<sol::optional<int>>("spriteIndex"))
					particle.SpriteIndex = *sprite;
				if (auto seq = data.get<sol::optional<GAME_OBJECT_ID>>("spriteSequence"))
					particle.SpriteSequence = *seq;
				if (auto color = data.get<sol::optional<ScriptColor>>("color"))
					particle.ParticleColor = Color(*color);
				if (auto orient = data.get<sol::optional<Vec3>>("orientation"))
					particle.Orientation = Vector3(orient->x * RADIAN, orient->y * RADIAN, orient->z * RADIAN);
				if (auto dmg = data.get<sol::optional<float>>("damage"))
					particle.Damage = std::max(0.0f, *dmg);
				if (auto psn = data.get<sol::optional<int>>("poison"))
					particle.Poison = std::max(0, *psn);
				if (auto fire = data.get<sol::optional<bool>>("fire"))
					particle.Fire = *fire;
			},

			/// Iterate over all active particles, calling a function for each.
			// @function ParticleGroup:ForEachParticle
			// @tparam function callback Function receiving (index, particleTable) for each active particle.
			// The table contains the same fields as GetParticle. If the callback returns a table,
			// those fields are applied back to the particle. All rotation/orientation values are in degrees.
			ScriptReserved_ParticleGroupForEachParticle, [](ParticleGroupHandle& handle, sol::function callback, sol::this_state s)
			{
				auto* group = handle.Get();
				if (!group)
					return;

				sol::state_view lua(s);
				for (int i = 0; i < (int)group->Particles.size(); i++)
				{
					if (!group->Particles[i].Active)
						continue;

					const auto& particle = group->Particles[i];
					auto tbl = lua.create_table();
					tbl["id"]             = particle.ID;
					tbl["position"]       = Vec3(particle.Position);
					tbl["velocity"]       = Vec3(particle.Velocity);
					tbl["acceleration"]   = Vec3(particle.Acceleration);
					tbl["size"]           = particle.Size;
					tbl["rotation"]       = particle.Rotation / RADIAN;
					tbl["color"]          = ScriptColor(particle.ParticleColor);
					tbl["age"]            = particle.Age;
					tbl["lifetime"]       = particle.Lifetime;
					tbl["ageNormalized"]  = particle.AgeNormalized;
					tbl["spriteIndex"]    = particle.SpriteIndex;
					tbl["spriteSequence"] = particle.SpriteSequence;
					tbl["orientation"]    = Vec3(particle.Orientation.x / RADIAN, particle.Orientation.y / RADIAN, particle.Orientation.z / RADIAN);
					tbl["damage"]         = particle.Damage;
					tbl["poison"]         = particle.Poison;
					tbl["fire"]           = particle.Fire;

					auto result = callback(i, tbl);

					// If the callback returns a table, apply changes back to the particle.
					if (result.valid() && result.get_type() == sol::type::table)
					{
						sol::table changes = result;
						auto& mp = group->Particles[i];

						if (auto pos = changes.get<sol::optional<Vec3>>("position"))
							mp.Position = pos->ToVector3();
						if (auto vel = changes.get<sol::optional<Vec3>>("velocity"))
							mp.Velocity = vel->ToVector3();
						if (auto accel = changes.get<sol::optional<Vec3>>("acceleration"))
							mp.Acceleration = accel->ToVector3();
						if (auto size = changes.get<sol::optional<float>>("size"))
							mp.Size = *size;
						if (auto rot = changes.get<sol::optional<float>>("rotation"))
							mp.Rotation = *rot * RADIAN;
						if (auto sprite = changes.get<sol::optional<int>>("spriteIndex"))
							mp.SpriteIndex = *sprite;
						if (auto seq = changes.get<sol::optional<GAME_OBJECT_ID>>("spriteSequence"))
							mp.SpriteSequence = *seq;
						if (auto color = changes.get<sol::optional<ScriptColor>>("color"))
							mp.ParticleColor = Color(*color);
						if (auto orient = changes.get<sol::optional<Vec3>>("orientation"))
							mp.Orientation = Vector3(orient->x * RADIAN, orient->y * RADIAN, orient->z * RADIAN);
						if (auto dmg = changes.get<sol::optional<float>>("damage"))
							mp.Damage = std::max(0.0f, *dmg);
						if (auto psn = changes.get<sol::optional<int>>("poison"))
							mp.Poison = std::max(0, *psn);
						if (auto fire = changes.get<sol::optional<bool>>("fire"))
							mp.Fire = *fire;
					}
				}
			},

			/// (int) Unique group ID. Read-only. Returns -1 if the handle is stale.
			// @mem id
			ScriptReserved_ParticleGroupId, sol::property([](const ParticleGroupHandle& handle) -> int
			{
				const auto* group = handle.Get();
				return group ? group->ID : -1;
			}),

			/// (bool) Whether the handle refers to a valid active group.
			// @mem active
			ScriptReserved_ParticleGroupActive, sol::property([](const ParticleGroupHandle& handle)
			{
				return handle.IsValid();
			}));

		/// Structure for a Particle table.
		// @table Particle
		// @tfield int id Unique particle ID. Read-only.
		// @tfield Vec3 position World position of the particle.
		// @tfield Vec3 velocity Directional velocity in world units per second.
		// @tfield Vec3 acceleration Acceleration applied to velocity in world units per second squared.
		// @tfield float size Current size of the particle in world units. For mesh particles, this also controls the uniform mesh scale.
		// @tfield float rotation Current rotation in degrees. Applies to sprite particles only.
		// @tfield Color color Current color of the particle.
		// @tfield float age Current age of the particle in seconds. Read-only.
		// @tfield float lifetime Total lifespan of the particle in seconds. Read-only.
		// @tfield float ageNormalized Current age as a normalized value between 0 and 1, where 0 is birth and 1 is death. Read-only.
		// @tfield int spriteIndex Current sprite or mesh index within the sprite sequence or mesh object.
		// @tfield Objects.ObjID spriteSequence Object slot used to render this particle. Overrides the group default per particle.
		// @tfield Vec3 orientation Current orientation in degrees along the X, Y, and Z axes. Applies to mesh particles only.
		// @tfield float damage HP damage dealt to Lara per second when this particle is in contact. Use 0 to disable.
		// @tfield int poison Poison units added to Lara per second when this particle is in contact. Use 0 to disable.
		// @tfield bool fire If true, sets Lara on fire while this particle is in contact.
		
		// Register CreateParticleGroup as a free function.
		parent.set_function(ScriptReserved_CreateParticleGroup, &LuaCreateParticleGroup);
	}
}
