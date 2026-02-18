#include "framework.h"
#include "Scripting/Internal/TEN/Effects/EffectsFunctions.h"

#include "Game/camera.h"
#include "Game/collision/collide_room.h"
#include "Game/control/los.h"
#include "Game/effects/blood.h"
#include "Game/effects/Bubble.h"
#include "Game/effects/DisplaySprite.h"
#include "Game/effects/effects.h"
#include "Game/effects/Electricity.h"
#include "Game/effects/explosion.h"
#include "Game/effects/ParticleGroup.h"
#include "Game/effects/spark.h"
#include "Game/effects/Streamer.h"
#include "Game/effects/tomb4fx.h"
#include "Game/effects/weather.h"
#include "Game/room.h"
#include "Game/Setup.h"
#include "Math/Math.h"
#include "Objects/Utils/object_helper.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Effects/BlendIDs.h"
#include "Scripting/Internal/TEN/Effects/EffectIDs.h"
#include "Scripting/Internal/TEN/Effects/ParticleAnimTypes.h"
#include "Scripting/Internal/TEN/Effects/FeatherModes.h"
#include "Scripting/Internal/TEN/Types/Color/Color.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Vec2/Vec2.h"
#include "Sound/sound.h"
#include "Specific/clock.h"
#include "Specific/trutils.h"
#include <Scripting/Internal/TEN/Objects/Moveable/MoveableObject.h>


/// Functions to generate effects.
// @tentable Effects 
// @pragma nostrip

using namespace TEN::Effects::Blood;
using namespace TEN::Effects::Bubble;
using namespace TEN::Effects::DisplaySprite;
using namespace TEN::Effects::Electricity;
using namespace TEN::Effects::Environment;
using namespace TEN::Effects::Explosion;
using namespace TEN::Effects::ParticleGroups;
using namespace TEN::Effects::Spark;
using namespace TEN::Effects::Streamer;
using namespace TEN::Math;
using namespace TEN::Scripting::Types;

namespace TEN::Scripting::Effects 
{
	/// Emit a lightning arc.  
	// @function EmitLightningArc
	// @tparam Vec3 origin Lightning origin (start) position.
	// @tparam Vec3 target Lightning target (end) position.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color color Color.
	// @tparam[opt=1] float life Lifetime in seconds. Clamped to [0, 4.233] for now because of strange internal maths.
	// @tparam[opt=20] int amplitude Strength of the lightning - the higher the value, the "taller" the arcs. Clamped to [1, 255].
	// @tparam[opt=2] int beamWidth Beam width. Clamped to [1, 127].
	// @tparam[opt=10] int detail Higher numbers equal more segments, but it's not a 1:1 correlation. Clamped to [1, 127].
	// @tparam[opt=false] bool smooth If true, the arc will have large, smooth curves; if false, it will have small, jagged spikes.
	// @tparam[opt=false] bool endDrift If true, the end of the arc will be able to gradually drift away from its destination in a random direction.
	static void EmitLightningArc(const Vec3& origin, const Vec3& target, TypeOrNil<ScriptColor> color, TypeOrNil<float> life, TypeOrNil<int> amplitude,
								 TypeOrNil<int> beamWidth, TypeOrNil<int> segments, TypeOrNil<bool> smooth, TypeOrNil<bool> endDrift)
	{
		constexpr auto LIFE_SEC_MAX = 4.233f;

		auto convertedOrigin = origin.ToVector3();
		auto convertedTarget = target.ToVector3();

		int segs = ValueOr<int>(segments, 10);

		segs = std::clamp(segs, 1, 127);

		int width = ValueOr<int>(beamWidth, 2);

		width = std::clamp(width, 1, 127);

		// Nearest number of milliseconds equating to approx 254, the max even byte value for "life".
		// This takes into account a "hardcoded" FPS of 30 and the fact that
		// lightning loses two "life" each frame.
		float convertedLife = ValueOr<float>(life, 1.0f);
		convertedLife = std::clamp(convertedLife, 0.0f, LIFE_SEC_MAX);

		constexpr float secsPerFrame = 1.0f / (float)FPS;

		// This will put us in the range [0, 127]
		int lifeInFrames = (int)round(convertedLife / secsPerFrame);

		// Multiply by two since a) lightning loses two "life" each frame, and b) it must be
		// an even number to avoid overshooting a value of 0 and wrapping around.
		byte byteLife = lifeInFrames * 2;

		int amp = ValueOr<int>(amplitude, 20);
		byte byteAmp = std::clamp(amp, 1, 255);

		bool isSmooth = ValueOr<bool>(smooth, false);
		bool isDrift = ValueOr<bool>(endDrift, false);

		char flags = 0;
		if (isSmooth)
			flags |= 1;

		if (isDrift)
			flags |= 2;

		auto convertedColor = ValueOr<ScriptColor>(color, ScriptColor(255, 255, 255)).PremultiplyAlpha();

		SpawnElectricity(convertedOrigin, convertedTarget, byteAmp, convertedColor.GetR(), convertedColor.GetG(), convertedColor.GetB(), byteLife, flags, width, segs);
	}

	/// Emit a particle.
	// @function EmitParticle
	// @tparam Vec3 pos World position.
	// @tparam Vec3 vel Directional velocity.
	// @tparam int spriteID Sprite ID in the sprite sequence slot.
	// @tparam[opt=0] float gravity Effect of gravity. Positive value ascends, negative value descends.
	// @tparam[opt=0] float rotVel Rotational velocity in degrees.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color startColor Color at start of life.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color endColor Color at end of life. This will finish long before the end of the particle's life due to internal math.
	// @tparam[opt=TEN.Effects.BlendID.ALPHA_BLEND] Effects.BlendID blendMode Render blend mode.
	// @tparam[opt=10] float startSize Size at start of life. 
	// @tparam[opt=0] float endSize Size at end of life.
	// @tparam[opt=2] float life Lifespan in seconds.
	// @tparam[opt=false] bool damage Harm the player on collision.
	// @tparam[opt=false] bool poison Poison the player on collision.
	// @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteSeqID Sprite sequence slot ID.
	// @tparam[opt=random] float startRot Rotation at start of life.
	// @usage
	// EmitParticle(
	//     pos,
	// 	   Vec3(math.random(), math.random(), math.random()),
	// 	   22, -- spriteID
	// 	   0, -- gravity
	// 	   -2, -- rotVel
	// 	   Color(255, 0, 0), -- startColor
	// 	   Color(0,  255, 0), -- endColor
	// 	   TEN.Effects.BlendID.ADDITIVE, -- blendMode
	// 	   15, -- startSize
	// 	   50, -- endSize
	// 	   20, -- life
	// 	   false, -- damage
	// 	   true, -- poison
	//     Objects.ObjID.DEFAULT_SPRITES, -- spriteSeqID
	//     180) -- startRot
	static void EmitParticle(const Vec3& pos, const Vec3& vel, int spriteID, TypeOrNil<float> gravity, TypeOrNil<float> rotVel,
							 TypeOrNil<ScriptColor> startColor, TypeOrNil<ScriptColor> endColor, TypeOrNil<BlendMode> blendMode, 
							 TypeOrNil<float> startSize, TypeOrNil<float> endSize, TypeOrNil<float> life,
							 TypeOrNil<bool> applyDamage, TypeOrNil<bool> applyPoison, TypeOrNil<GAME_OBJECT_ID> spriteSeqID, TypeOrNil<float> startRot)
	{
		constexpr auto DEFAULT_START_SIZE = 10.0f;
		constexpr auto DEFAULT_LIFE		  = 2.0f;
		constexpr auto SECS_PER_FRAME	  = 1.0f / (float)FPS;

		static const auto DEFAULT_COLOR = ScriptColor(255, 255, 255);

		auto convertedSpriteSeqID = ValueOr<GAME_OBJECT_ID>(spriteSeqID, ID_DEFAULT_SPRITES); 
		if (!CheckIfSlotExists(convertedSpriteSeqID, "EmitParticle() script function."))
			return;

		auto& part = *GetFreeParticle();

		part.on = true;
		part.SpriteSeqID = convertedSpriteSeqID;
		part.SpriteID = spriteID;

		auto convertedBlendMode = ValueOr<BlendMode>(blendMode, BlendMode::AlphaBlend);
		part.blendMode = BlendMode(std::clamp((int)convertedBlendMode, (int)BlendMode::Opaque, (int)BlendMode::AlphaBlend));

		part.x = pos.x;
		part.y = pos.y;
		part.z = pos.z;
		part.roomNumber = FindRoomNumber(Vector3i(pos.x, pos.y, pos.z));

		part.xVel = short(vel.x * 32);
		part.yVel = short(vel.y * 32);
		part.zVel = short(vel.z * 32);

		part.rotAng = ANGLE(ValueOr<float>(startRot, TO_DEGREES(Random::GenerateAngle()))) >> 4;
		part.rotAdd = ANGLE(ValueOr<float>(rotVel, 0.0f)) >> 4;
		
		part.sSize =
		part.size = ValueOr<float>(startSize, DEFAULT_START_SIZE);
		part.dSize = ValueOr<float>(endSize, 0.0f);
		part.scalar = 2;

		part.gravity = (short)std::clamp(ValueOr<float>(gravity, 0.0f), (float)SHRT_MIN, (float)SHRT_MAX);
		part.friction = 0;
		part.maxYvel = 0;

		auto convertedStartColor = ValueOr<ScriptColor>(startColor, DEFAULT_COLOR);
		part.sR = convertedStartColor.GetR();
		part.sG = convertedStartColor.GetG();
		part.sB = convertedStartColor.GetB();

		auto convertedEndColor = ValueOr<ScriptColor>(endColor, DEFAULT_COLOR);
		part.dR = convertedEndColor.GetR();
		part.dG = convertedEndColor.GetG();
		part.dB = convertedEndColor.GetB();

		float convertedLife = std::max(0.1f, ValueOr<float>(life, DEFAULT_LIFE));
		part.life =
		part.sLife = (int)round(convertedLife / SECS_PER_FRAME);
		part.colFadeSpeed = part.life / 2;
		part.fadeToBlack = part.life / 3;

		part.flags = SP_SCALE | SP_ROTATE | SP_DEF | SP_EXPDEF;

		bool convertedApplyPoison = ValueOr<bool>(applyPoison, false);
		if (convertedApplyPoison)
			part.flags |= SP_POISON;

		bool convertedApplyDamage = ValueOr<bool>(applyDamage, false);
		if (convertedApplyDamage)
		{
			part.flags |= SP_DAMAGE;
			part.damage = 2;
		}

		// TODO: Add option to turn off wind.
		if (TestEnvironment(RoomEnvFlags::ENV_FLAG_WIND, part.roomNumber))
			part.flags |= SP_WIND;
	}

	/// Emit a particle with extensive configuration options. Options include sprite sequence animation, lights, sounds, and damage effects.
	// @function EmitAdvancedParticle
	// @tparam ParticleData particleData Table containing particle data.
	// @usage
	// local particle =
	// {
	//     pos = GetMoveableByName("camera_target_6"):GetPosition(), 
	//     vel = Vec3(0, 0, 10),
	//     spriteSeqID = TEN.Objects.ObjID.CUSTOM_BAR_GRAPHIC,
	//     spriteID = 0,
	//     life = 10,
	//     maxYVel = 0,
	//     gravity = 0,
	//     friction = 10,
	//     startRot = 0,
	//     rotVel = 0,
	//     startSize = 80,
	//     endSize = 80,
	//     startColor = TEN.Color(128, 128, 128),
	//     endColor = TEN.Color(128, 128, 128),
	//     blendMode = TEN.Effects.BlendID.ADDITIVE,
	//     wind = false,
	//     damage = true,
	//     poison = false,
	//     burn = false,
	//     damageHit = 80,
	//     soundID = 197,
	//     light = true,
	//     lightRadius = 6, 
	//     lightFlicker = 5, 
	//     animated = true,
	//     frameRate = 0.25,
	//     animType = TEN.Effects.ParticleAnimationType.LOOP,
	// }
	// EmitAdvancedParticle(particle)

	/// Structure for EmitAdvancedParticle table.
	// @table ParticleData
	// @tfield Vec3 pos World position.
	// @tfield Vec3 vel Directional velocity in world units per second.
	// @tfield[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteSeqID Sprite sequence slot ID.
	// @tfield[opt=0] int spriteID Sprite ID in the sprite sequence slot.
	// @tfield[opt=2] float life Lifespan in seconds.
	// @tfield[opt=0] float maxYVel Maximum vertical velocity in world units per second.
	// @tfield[opt=0] float gravity Effect of gravity in world units per second. Positive value ascend, negative value descend.
	// @tfield[opt=0] float friction Friction affecting velocity over time in world units per second.
	// @tfield[opt=random] float startRot Rotation at start of life.
	// @tfield[opt=0] float rotVel Rotational velocity in degrees per second.
	// @tfield[opt=10] float startSize Size at start of life.
	// @tfield[opt=0] float endSize Size at end of life.
	// @tfield[opt=Color(255&#44; 255&#44; 255)] Color startColor Color at start of life.
	// @tfield[opt=Color(255&#44; 255&#44; 255)] Color endColor Color at end of life. Note that this will finish long before the end of life due to internal math.
	// @tfield[opt=TEN.Effects.BlendID.ALPHA_BLEND] Effects.BlendID blendMode Render blend mode.
	// @tfield[opt=false] bool damage Harm the player on collision.
	// @tfield[opt=false] bool poison Poison the player on collision.
	// @tfield[opt=false] bool burn Burn the player on collision.
	// @tfield[opt=false] bool wind Affect position by wind in outside rooms.
	// @tfield[opt=2] int damageHit Player damage amount on collision.
	// @tfield[opt=false] bool light Emit a colored light. __Caution__: Recommended only for a single particle. Too many particles with lights can overwhelm the lighting system.
	// @tfield[opt=0] int lightRadius Light radius in 1/4 blocks.
	// @tfield[opt=0] int lightFlicker Interval at which the light should flicker.
	// @tfield[opt] int soundID Sound ID to play. __Caution__: Recommended only for a single particle. Too many particles with sounds can overwhelm the sound system.
	// @tfield[opt=false] bool animated Play animates sprite sequence.
	// @tfield[opt=TEN.Effects.ParticleAnimationType.LOOP] Effects.ParticleAnimationType animType Animation type of the sprite sequence.
	// @tfield[opt=1] float frameRate Sprite sequence animation framerate.
	static void EmitAdvancedParticle(const sol::table& table)
	{
		constexpr auto DEFAULT_START_SIZE = 10.0f;
		constexpr auto DEFAULT_LIFE		  = 2.0f;

		auto convertedSpriteSeqID = table.get_or("spriteSeqID", ID_DEFAULT_SPRITES);
		if (!CheckIfSlotExists(convertedSpriteSeqID, "EmitParticle() script function."))
			return;

		auto& part = *GetFreeParticle();

		part.on = true;
		part.SpriteSeqID = convertedSpriteSeqID;
		part.SpriteID = table.get_or("spriteID", 0);

		auto bMode = table.get_or("blendMode", BlendMode::AlphaBlend);
		part.blendMode = bMode;

		auto pos = (Vec3)table["pos"];
		part.x = pos.x;
		part.y = pos.y;
		part.z = pos.z;
		part.roomNumber = FindRoomNumber(pos.ToVector3i());

		auto vel = ((Vec3)table["vel"]) / (float)FPS;
		part.xVel = short(vel.x * 32);
		part.yVel = short(vel.y * 32);
		part.zVel = short(vel.z * 32);

		float startRot = table.get_or("startRot", TO_DEGREES(Random::GenerateAngle()));
		float rotVel = table.get_or("rotVel", 0.0f) / (float)FPS;
		part.rotAng = ANGLE(startRot) >> 4;
		part.rotAdd = ANGLE(rotVel) >> 4;

		part.sSize =
		part.size = table.get_or("startSize", DEFAULT_START_SIZE);
		part.dSize = table.get_or("endSize", 0.0f);
		part.scalar = 2;

		part.gravity = (short)(std::clamp<float>(table.get_or("gravity", 0.0f), SHRT_MIN, SHRT_MAX) / (float)FPS);
		part.friction = table.get_or("friction", 0.0f) / (float)FPS;
		part.maxYvel = table.get_or("maxYVel", 0.0f) / (float)FPS;

		auto convertedStartColor = table.get_or("startColor", ScriptColor(255, 255, 255));
		part.sR = convertedStartColor.GetR();
		part.sG = convertedStartColor.GetG();
		part.sB = convertedStartColor.GetB();

		auto convertedEndColor = table.get_or("endColor", ScriptColor(255, 255, 255));
		part.dR = convertedEndColor.GetR();
		part.dG = convertedEndColor.GetG();
		part.dB = convertedEndColor.GetB();

		float convertedLife = std::max(0.1f, (float)table.get_or("life", DEFAULT_LIFE));
		part.life =
		part.sLife = (int)round(convertedLife / (1.0f / (float)FPS));
		part.colFadeSpeed = part.life / 2;
		part.fadeToBlack = part.life / 3;

		part.flags = SP_SCALE | SP_ROTATE | SP_DEF | SP_EXPDEF;

		part.damage = table.get_or("damageHit", 2);

		bool convertedApplyPoison = table.get_or("poison", false);
		if (convertedApplyPoison)
			part.flags |= SP_POISON;

		bool convertedApplyDamage = table.get_or("damage", false);
		if (convertedApplyDamage)
			part.flags |= SP_DAMAGE;

		bool convertedApplyBurn = table.get_or("burn", false);
		if (convertedApplyBurn)
			part.flags |= SP_FIRE;

		int convertedSoundID = table.get_or("soundID", NO_VALUE);
		if (convertedSoundID != NO_VALUE)
		{
			part.flags |= SP_SOUND;
			part.sound = convertedSoundID;
		}
		bool convertedApplyLight = table.get_or("light", false);
		if (convertedApplyLight)
		{
			part.flags |= SP_LIGHT;
			int lightRadius = table.get_or("lightRadius", 0);
			part.lightRadius = lightRadius * BLOCK(0.25f);
			int flicker = table.get_or("lightFlicker", 0);
			
			if (flicker > 0)
			{
				part.lightFlicker = table.get_or("lightFlicker", 0);
				part.lightFlickerS = table.get_or("lightFlicker", 0);
			}
		}
		bool animatedSpr = table.get_or("animated", false);
		if (animatedSpr)
		{
			auto applyAnim = (ParticleAnimType)table.get_or("animType", ParticleAnimType::Loop);
			float applyFramerate = table.get_or("frameRate", 1.0f);
			part.flags |= SP_ANIMATED;
			part.framerate = applyFramerate;
			part.animationType = ParticleAnimType(std::clamp(int(applyAnim), int(ParticleAnimType::None), int(ParticleAnimType::LifetimeSpread)));

		}

		bool convertedApplyWind = table.get_or("wind", false);
		if (convertedApplyWind)
		{
			if (TestEnvironment(RoomEnvFlags::ENV_FLAG_WIND, part.roomNumber))
				part.flags |= SP_WIND;
		}
	}
	
	/// Emit a shockwave, similar to that seen when a harpy projectile hits something.
	// @function EmitShockwave
	// @tparam Vec3 pos World position.
	// @tparam[opt=0] int innerRadius Initial inner radius of the shockwave circle - 128 will be approx a click, 512 approx a block.
	// @tparam[opt=128] int outerRadius Initial outer radius of the shockwave circle.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color color Color.
	// @tparam[opt=1.0] float lifetime Lifetime in seconds (max 8.5 because of inner maths weirdness).
	// @tparam[opt=50] int speed Initial speed of the shockwave's expansion (the shockwave will always slow as it goes).
	// @tparam[opt=0] int angle Angle about the X axis - a value of 90 will cause the shockwave to be entirely vertical.
	// @tparam[opt=false] bool hurtsLara If true, the shockwave will hurt Lara, with the damage being relative to the shockwave's current speed.
	static void EmitShockwave(Vec3 pos, TypeOrNil<int> innerRadius, TypeOrNil<int> outerRadius, TypeOrNil<ScriptColor> col,
							  TypeOrNil<float> lifetime, TypeOrNil<int> speed, TypeOrNil<int> angle, TypeOrNil<bool> hurtPlayer)
	{
		constexpr auto LIFE_IN_SECONDS_MAX = 8.5f;
		constexpr auto SECONDS_PER_FRAME   = 1 / (float)FPS;

		auto pose = Pose(Vector3i(pos.x, pos.y, pos.z));

		int innerRad = ValueOr<int>(innerRadius, 0);
		int outerRad = ValueOr<int>(outerRadius, 128);

		auto color = ValueOr<ScriptColor>(col, ScriptColor(255, 255, 255)).PremultiplyAlpha();
		int spd = ValueOr<int>(speed, 50);
		int ang = ValueOr<int>(angle, 0);
 
		float life = ValueOr<float>(lifetime, 1.0f);
		life = std::clamp(life, 0.0f, LIFE_IN_SECONDS_MAX);

		// Normalize to range [0, 255].
		int lifeInFrames = (int)round(life / SECONDS_PER_FRAME);

		bool doDamage = ValueOr<bool>(hurtPlayer, false);

		TriggerShockwave(
			&pose, innerRad, outerRad, spd,
			color.GetR(), color.GetG(), color.GetB(),
			lifeInFrames, EulerAngles(ANGLE(ang), 0.0f, 0.0f),
			(short)doDamage, true, false, false, (int)ShockwaveStyle::Normal);
	}

	/// Emit dynamic light that lasts for a single frame.
	// If you want a light that sticks around, you must call this each frame.
	// @function EmitLight
	// @tparam Vec3 pos World position of the light.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color color Light color.
	// @tparam[opt=20] int radius Measured in "clicks" or 256 world units.
	// @tparam[opt=false] bool shadows Determines whether light should generate dynamic shadows for applicable moveables.
	// @tparam[opt] string name If provided, engine will interpolate this light for high framerate mode (be careful not to use same name for different lights).
	static void EmitLight(Vec3 pos, TypeOrNil<ScriptColor> col, TypeOrNil<int> radius, TypeOrNil<bool> castShadows, TypeOrNil<std::string> name)
	{
		auto color = ValueOr<ScriptColor>(col, ScriptColor(255, 255, 255)).PremultiplyAlpha();
		int rad = (float)(ValueOr<int>(radius, 20) * BLOCK(0.25f));
		SpawnDynamicPointLight(pos.ToVector3(), color, rad, ValueOr<bool>(castShadows, false), GetHash(ValueOr<std::string>(name, std::string())));
	}

	/// Emit dynamic directional spotlight that lasts for a single frame.
	// If you want a light that sticks around, you must call this each frame.
	// @function EmitSpotLight
	// @tparam Vec3 pos World position of the light.
	// @tparam Vec3 dir Normal which indicates light direction.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color color Light color.
	// @tparam[opt=10] int radius Overall radius at the endpoint of a light cone, measured in "clicks" or 256 world units.
	// @tparam[opt=5] int falloff Radius, at which light starts to fade out, measured in "clicks".
	// @tparam[opt=20] int distance Distance, at which light cone fades out, measured in "clicks".
	// @tparam[opt=false] bool shadows Determines whether light should generate dynamic shadows for applicable moveables.
	// @tparam[opt] string name If provided, engine will interpolate this light for high framerate mode (be careful not to use same name for different lights).
	static void EmitSpotLight(Vec3 pos, Vec3 dir, TypeOrNil<ScriptColor> col, TypeOrNil<int> radius, TypeOrNil<int> falloff, TypeOrNil<int> distance, TypeOrNil<bool> castShadows, TypeOrNil<std::string> name)
	{
		auto color = ValueOr<ScriptColor>(col, ScriptColor(255, 255, 255)).PremultiplyAlpha();
		int rad =	  (float)(ValueOr<int>(radius,   10) * BLOCK(0.25f));
		int fallOff = (float)(ValueOr<int>(falloff,   5) * BLOCK(0.25f));
		int dist =	  (float)(ValueOr<int>(distance, 20) * BLOCK(0.25f));
		SpawnDynamicSpotLight(pos.ToVector3(), dir.ToVector3(), color, rad, fallOff, dist, ValueOr<bool>(castShadows, false), GetHash(ValueOr<std::string>(name, std::string())));
	}

	/// Emit dynamic fog bulb that lasts for a single frame.
	// If you want a fog bulb that sticks around, you must call this each frame.
	// @function EmitFogBulb
	// @tparam Vec3 pos Position of the fog bulb.
	// @tparam[opt=20] int radius Radius measured in "clicks" or 256 world units.
	// @tparam[opt=255] int density Density, ranging from 0 to 255.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color color Color.
	// @tparam[opt] string name If provided, engine will interpolate this fog bulb for high framerate mode (be careful not to use same name for different fogbulbs)
	static void EmitFogBulb(Vec3 pos, TypeOrNil<int> radius, TypeOrNil<int> density, TypeOrNil<ScriptColor> col, TypeOrNil<std::string> name)
	{
		constexpr auto DEFAULT_DENSITY = 255;

		auto color = ValueOr<ScriptColor>(col, ScriptColor(255, 255, 255)).PremultiplyAlpha();
		int rad = (float)(ValueOr<int>(radius, 20));
		int dens = (float)(ValueOr<int>(density, DEFAULT_DENSITY));
		SpawnDynamicFogBulb(pos.ToVector3(), rad, dens, color, GetHash(ValueOr<std::string>(name, std::string())));
	}

	/// Emit blood.
	// @function EmitBlood
	// @tparam Vec3 pos World position.
	// @tparam[opt=1] int count Blood sprite count.
	static void EmitBlood(const Vec3& pos, TypeOrNil<int> count)
	{
		int roomNumber = FindRoomNumber(pos.ToVector3i());
		const auto& room = g_Level.Rooms[roomNumber];
		if (room.flags & ENV_FLAG_WATER)
			SpawnUnderwaterBloodCloud(pos, roomNumber, (GetRandomControl() & 7) + 8, ValueOr<int>(count, 1));
		else
			TriggerBlood(pos.x, pos.y, pos.z, -1, ValueOr<int>(count, 1));
	}

	/// Emit an air bubble in a water room.
	// @function EmitAirBubble
	// @tparam Vec3 pos World position where the effect will be spawned. Must be in a water room.
	// @tparam[opt=32] float size Sprite size.
	// @tparam[opt=32] float amp Oscillation amplitude.
	static void EmitAirBubble(const Vec3& pos, TypeOrNil<float> size, TypeOrNil<float> amp)
	{
		constexpr auto DEFAULT_SIZE = 128.0f;
		constexpr auto DEFAULT_AMP	= 32.0f;

		int roomNumber = FindRoomNumber(pos.ToVector3i());
		float convertedSize = ValueOr<float>(size, DEFAULT_SIZE);
		float convertedAmp = ValueOr<float>(amp, DEFAULT_AMP);
		SpawnBubble(pos.ToVector3(), roomNumber, convertedSize, convertedAmp);
	}

	/// Emit waterfall mist.
	// @function EmitWaterfallMist
	// @tparam Vec3 pos World position where the effect will be spawned.
	// @tparam[opt=64] float size Effect size.
	// @tparam[opt=32] float width Width of the effect.
	// @tparam[opt=0] float rot Rotation of effect in degrees.
	// @tparam[opt=Color(255&#44; 255&#44; 255&#44; 255)] Color color Color of the effect.
	static void EmitWaterfallMist(const Vec3& pos, TypeOrNil<int> size, TypeOrNil<int> width, TypeOrNil<float> angle, TypeOrNil<ScriptColor> color)
	{
		constexpr auto DEFAULT_SIZE = 64;
		constexpr auto DEFAULT_WIDTH = 32;

		auto convertedAngle = ANGLE(ValueOr<float>(angle, 0.0f));
		auto convertedSize = ValueOr<int>(size, DEFAULT_SIZE);
		auto convertedWidth = ValueOr<int>(width, DEFAULT_WIDTH);
		auto _color = ValueOr<ScriptColor>(color, ScriptColor(255, 255, 255)).PremultiplyAlpha();
		auto convertedColor = Vector4(_color.GetR(), _color.GetG(), _color.GetB(), _color.GetA()) / UCHAR_MAX;

		TriggerWaterfallMist(pos, convertedSize, convertedWidth, convertedAngle, convertedColor);
	}

	/// Emit fire for a single frame. Will not hurt player. Call this each frame if you want a continuous fire.
	// @function EmitFire
	// @tparam Vec3 pos World position.
	// @tparam[opt=1] float size Fire size.
	static void EmitFire(const Vec3& pos, TypeOrNil<float> size)
	{
		AddFire(pos.x, pos.y, pos.z, FindRoomNumber(pos.ToVector3i()), ValueOr<float>(size, 1));
	}

	/// Emit an extending streamer effect.
	// @function EmitStreamer
	// @tparam Moveable mov Moveable object with which to associate the effect.
	// @tparam int tag Numeric tag with which to associate the effect on the moveable.
	// @tparam Vec3 pos World position.
	// @tparam Vec3 dir Direction vector of movement velocity.
	// @tparam[opt=0] float rot Start rotation in degrees.
	// @tparam[opt=Color(255&#44; 255&#44; 255)] Color startColor Color at the start of life.
	// @tparam[opt=Color(0&#44; 0&#44; 0)] Color endColor Color at the end of life.
	// @tparam[opt=0] float width Width in world units.
	// @tparam[opt=1] float life Lifetime in seconds.
	// @tparam[opt=0] float vel Movement velocity in world units per second.
	// @tparam[opt=0] float expRate Width expansion rate in world units per second.
	// @tparam[opt=0] float rotRate Rotation rate in degrees per second.
	// @tparam[opt=Effects.StreamerFeatherMode.NONE] Effects.StreamerFeatherMode edgeFeatherMode Edge feather mode.
	// @tparam[opt=Effects.StreamerFeatherMode.LEFT] Effects.StreamerFeatherMode lengthFeatherMode Length feather mode. _Not yet implemented._
	// @tparam[opt=Effects.BlendID.ALPHA_BLEND] Effects.BlendID blendID Renderer blend ID.
	static void EmitStreamer(const Moveable& mov, TypeOrNil<int> tag, const Vec3& pos, const Vec3& dir, TypeOrNil<float> rot, TypeOrNil<ScriptColor> startColor, TypeOrNil<ScriptColor> endColor,
							 TypeOrNil<float> width, TypeOrNil<float> life, TypeOrNil<float> vel, TypeOrNil<float> expRate, TypeOrNil<float> rotRate,
							 TypeOrNil<StreamerFeatherMode> edgeFeatherMode, TypeOrNil<StreamerFeatherMode> lengthFeatherMode, TypeOrNil<BlendMode> blendID)
	{
		int movID = mov.GetIndex();
		int convertedTag = ValueOr<int>(tag, 0);
		auto convertedPos = pos.ToVector3();
		auto convertedDir = dir.ToVector3();
		auto convertedRot = ANGLE(ValueOr<float>(rot, 0));
		auto convertedStartColor = ValueOr<ScriptColor>(startColor, ScriptColor(255, 255, 255, 255));
		auto convertedEndColor = ValueOr<ScriptColor>(endColor, ScriptColor(0, 0, 0, 0));

		auto convertedWidth = ValueOr<float>(width, 0.0f);
		auto convertedLife = ValueOr<float>(life, 1.0f);
		auto convertedVel = ValueOr<float>(vel, 0.0f) / (float)FPS;
		auto convertedExpRate = ValueOr<float>(expRate, 0.0f) / (float)FPS;
		auto convertedRotRate = ANGLE(ValueOr<float>(rotRate, 0.0f) / (float)FPS);

		auto convertedEdgeFeatherID = ValueOr<StreamerFeatherMode>(edgeFeatherMode, StreamerFeatherMode::None);
		auto convertedLengthFeatherID = ValueOr<StreamerFeatherMode>(lengthFeatherMode, StreamerFeatherMode::Left);
		auto convertedBlendID = ValueOr<BlendMode>(blendID, BlendMode::AlphaBlend);

		StreamerEffect.Spawn(
			movID, convertedTag, convertedPos, convertedDir, convertedRot, convertedStartColor, convertedEndColor,
			convertedWidth, convertedLife, convertedVel, convertedExpRate, convertedRotRate,
			convertedEdgeFeatherID, /*convertedLengthFeatherID, */convertedBlendID);
	}

	/// Emit a particle flowing effect.
	// @function EmitFlow
	// @tparam Vec3 pos World position.
	// @tparam Vec3 dir Directional velocity of the particles in world units per second.
	// @tparam[opt=512] float radius Radius of emitter. The particles will be emitted inside the circle of provided radius measured from centre of world position.
	// @tparam[opt=1] float life Lifespan in seconds.
	// @tparam[opt=0] float friction Friction affecting velocity over time in world units per second.
	// @tparam[opt=25] float maxSize Max size of the particle.
	// @tparam[opt=Color(128&#44; 128&#44; 128)] Color startColor Color at start of life.
	// @tparam[opt=Color(0&#44; 0&#44; 0)] Color endColor Color at end of life.
	// @tparam[opt=Objects.ObjID.DEFAULT_SPRITES] Objects.ObjID spriteSeqID Sprite sequence slot ID.
	// @tparam[opt=14 (UNDERWATER_DUST)] int spriteID Sprite ID in the sprite sequence slot.
	static void EmitFlow(const Vec3& pos, const Vec3& dir, TypeOrNil<float> radius, TypeOrNil<float> life, TypeOrNil<float> friction, TypeOrNil<float> maxSize, TypeOrNil<ScriptColor> startColor, TypeOrNil<ScriptColor> endColor, TypeOrNil<GAME_OBJECT_ID> spriteSeqID, TypeOrNil<int> spriteID)
	{
		constexpr auto DEFAULT_LIFE = 1.0f;
		constexpr auto SECS_PER_FRAME = 1.0f / (float)FPS;
		constexpr auto DUST_SIZE_MAX = 25.0f;

		auto convertedSpriteSeqID = ValueOr<GAME_OBJECT_ID>(spriteSeqID, ID_DEFAULT_SPRITES);
		if (!CheckIfSlotExists(convertedSpriteSeqID, "EmitParticle() script function."))
			return;

		auto convertedPos = pos.ToVector3();
		auto convertedDir = dir.ToVector3() / (float)FPS;
		auto convertedRad = ValueOr<float>(radius, BLOCK(0.5f));
		auto convertedLife = std::max(0.1f, ValueOr<float>(life, DEFAULT_LIFE));
		auto convertedFriction = ValueOr<float>(friction, 0) / (float)FPS;
		auto convertedMaxSize = std::max(0.1f, ValueOr<float>(maxSize, DUST_SIZE_MAX));
		auto convertedStartColor = ValueOr<ScriptColor>(startColor, ScriptColor(128, 128, 128, 255));
		auto convertedEndColor = ValueOr<ScriptColor>(endColor, ScriptColor(0, 0, 0, 255));
		auto convertedSpriteID = ValueOr<int>(spriteID, SPRITE_TYPES::SPR_UNDERWATERDUST);

		auto& part = *GetFreeParticle();

		part.on = true;
		part.SpriteSeqID = convertedSpriteSeqID;
		part.SpriteID = convertedSpriteID;
		part.blendMode = BlendMode::Additive;

		// Set particle colors
		part.sR = convertedStartColor.GetR();
		part.sG = convertedStartColor.GetG();
		part.sB = convertedStartColor.GetB();

		part.dR = convertedEndColor.GetR();
		part.dG = convertedEndColor.GetG();
		part.dB = convertedEndColor.GetB();

		part.life =
			part.sLife = (int)round(convertedLife / SECS_PER_FRAME);
		part.colFadeSpeed = part.life / 2;
		part.fadeToBlack = part.life / 3;

		// Randomize position within the given radius
		float angle = TO_DEGREES(Random::GenerateAngle());
		float randRadius = sqrt(Random::GenerateFloat()) * convertedRad;

		part.x = convertedPos.x + randRadius * cos(angle);
		part.y = convertedPos.y + (Random::GenerateFloat() * 2.0f - 1.0f) * convertedRad;
		part.z = convertedPos.z + randRadius * sin(angle);
		part.roomNumber = FindRoomNumber(Vector3i(part.x, part.y, part.z));

		part.xVel = convertedDir.x * 32;
		part.yVel = convertedDir.y * 32;
		part.zVel = convertedDir.z * 32;

		part.rotAng = ANGLE(0.0f) >> 4;
		part.rotAdd = ANGLE(0.0f) >> 4;

		// Other properties
		part.friction = convertedFriction;
		part.maxYvel = 0;
		part.gravity = 0;
		part.flags = SP_SCALE | SP_ROTATE | SP_DEF | SP_EXPDEF;
		part.scalar = 2;
		part.sSize = part.size = part.dSize = Random::GenerateFloat(convertedMaxSize / 2, convertedMaxSize);
	}

	/// Make an explosion. Does not hurt Lara
	// @function MakeExplosion 
	// @tparam Vec3 pos World position.
	// @tparam[opt=512] float size Size of the shockwave if enabled.
	// @tparam[opt=false] bool shockwave If true, creates a very faint shockwave which will not hurt Lara.
	// For underwater rooms, it creates a splash if `pos` is near the surface. Shockwave uses `mainColor` if provided.
	// @tparam[opt] Color mainColor Main color of the explosion and the shockwave. If not provided, default explosion color will be used. Must be provided for colored explosions.
	// @tparam[opt] Color additionalColor Additional color of the explosion. If provided, explosion would randomly use the main or the additional color. If not provided, only main color will be used.
	static void MakeExplosion(Vec3 pos, TypeOrNil<float> size, TypeOrNil<bool> shockwave, TypeOrNil<ScriptColor> mainColor, TypeOrNil<ScriptColor> additionalColor)
	{
		auto convertedShockwave = ValueOr<bool>(shockwave, false);
		auto convertedSize = ValueOr<float>(size, 512.0f);

		auto convertedMainColor = ValueOr<ScriptColor>(mainColor, ScriptColor(0, 0, 0));
		auto convertedAdditionalColor = ValueOr<ScriptColor>(additionalColor, convertedMainColor);

		int roomNumber = FindRoomNumber(pos.ToVector3i());
		const auto& room = g_Level.Rooms[roomNumber];

		if (room.flags & ENV_FLAG_WATER)
			TriggerUnderwaterExplosion(pos.ToVector3(), ValueOr<bool>(shockwave, false), Vector3(convertedMainColor), Vector3(convertedAdditionalColor));
		else
		{
			TriggerExplosionSparks(pos.x, pos.y, pos.z, 3, -2, 0, FindRoomNumber(Vector3i(pos.x, pos.y, pos.z)), Vector3(convertedMainColor), Vector3(convertedAdditionalColor));

			if (convertedShockwave)
			{
				auto shockPos = Pose(Vector3i(pos));

				if (Vector3(convertedMainColor) == Vector3::Zero)
					TriggerShockwave(&shockPos, 0, convertedSize, 64, 128, 96, 0, 30, EulerAngles(rand() & 0xFFFF, 0.0f, 0.0f), 0, true, false, false, (int)ShockwaveStyle::Normal);
				else
					TriggerShockwave(&shockPos, 0, convertedSize, 64, convertedMainColor.GetR(), convertedMainColor.GetG(), convertedMainColor.GetB(), 30, EulerAngles(rand() & 0xFFFF, 0.0f, 0.0f), 0, true, false, false, (int)ShockwaveStyle::Normal);
			}

		}
	}

	/// Make an earthquake.
	// @function MakeEarthquake 
	// @tparam[opt=100] int strength How strong should the earthquake be? Increasing this value also increases the lifespan of the earthquake.
	static void Earthquake(TypeOrNil<int> strength)
	{
		int str = ValueOr<int>(strength, 100);
		Camera.bounce = -str;
	}

	/// Get the wind vector for the current game frame.
	// This represents the 3D displacement applied by the engine on things like particles affected by wind.
	// @function GetWind()
	// @treturn Vec3 Wind vector.
	static Vec3 GetWind()
	{
		return Vec3(Weather.Wind());
	}

	// ========================
	// ParticleGroup Lua API
	// ========================

	/// Create a particle group for managing collections of particles with Lua-driven behavior.
	// @function CreateParticleGroup
	// @tparam Objects.ObjID spriteSeqID Sprite sequence slot ID.
	// @tparam int maxParticles Maximum number of particles in the group.
	// @treturn ParticleGroup A new ParticleGroup object, or nil on failure.
	static ParticleGroup* LuaCreateParticleGroup(GAME_OBJECT_ID spriteSeqID, int maxParticles)
	{
		if (!CheckIfSlotExists(spriteSeqID, "CreateParticleGroup"))
			return nullptr;

		int id = CreateParticleGroup(spriteSeqID, maxParticles);
		if (id < 0)
			return nullptr;

		return &ParticleGroupList[id];
	}

	void Register(sol::state* state, sol::table& parent) 
	{
		auto tableEffects = sol::table(state->lua_state(), sol::create);
		parent.set(ScriptReserved_Effects, tableEffects);

		// Register ParticleGroup usertype.
		parent.new_usertype<ParticleGroup>(
			ScriptReserved_ParticleGroup,

			/// Start emitting particles.
			// @function ParticleGroup:Start
			"Start", &ParticleGroup::Start,

			/// Stop emitting particles. Existing particles continue until they expire.
			// @function ParticleGroup:Stop
			"Stop", &ParticleGroup::Stop,

			/// Pause emission. Existing particles freeze.
			// @function ParticleGroup:Pause
			"Pause", &ParticleGroup::Pause,

			/// Resume emission after pause.
			// @function ParticleGroup:Resume
			"Resume", &ParticleGroup::Resume,

			/// Emit a burst of particles immediately.
			// @function ParticleGroup:EmitBurst
			// @tparam int count Number of particles to emit.
			"EmitBurst", &ParticleGroup::EmitBurst,

			/// Get number of active particles.
			// @function ParticleGroup:GetActiveCount
			// @treturn int Number of active particles.
			"GetActiveCount", &ParticleGroup::GetActiveCount,

			/// Set the emission rate.
			// @function ParticleGroup:SetEmissionRate
			// @tparam float rate Particles per second.
			"SetEmissionRate", [](ParticleGroup& self, float rate) { self.EmissionRate = std::max(0.0f, rate); },

			/// Set the emitter position.
			// @function ParticleGroup:SetPosition
			// @tparam Vec3 pos World position.
			"SetPosition", [](ParticleGroup& self, const Vec3& pos)
			{
				self.EmitterPosition = pos.ToVector3();
				self.RoomNumber = FindRoomNumber(Vector3i((int)pos.x, (int)pos.y, (int)pos.z));
			},

			/// Get the emitter position.
			// @function ParticleGroup:GetPosition
			// @treturn Vec3 World position.
			"GetPosition", [](const ParticleGroup& self) { return Vec3(self.EmitterPosition); },

			/// Set initial velocity for new particles.
			// @function ParticleGroup:SetInitialVelocity
			// @tparam Vec3 vel Velocity vector.
			"SetInitialVelocity", [](ParticleGroup& self, const Vec3& vel) { self.InitVelocity = vel.ToVector3(); },

			/// Set random range added to initial velocity.
			// @function ParticleGroup:SetInitialVelocityRandom
			// @tparam Vec3 range Random range per axis (value is +/- range).
			"SetInitialVelocityRandom", [](ParticleGroup& self, const Vec3& range) { self.InitVelocityRandom = range.ToVector3(); },

			/// Set initial acceleration for new particles.
			// @function ParticleGroup:SetInitialAcceleration
			// @tparam Vec3 accel Acceleration vector.
			"SetInitialAcceleration", [](ParticleGroup& self, const Vec3& accel) { self.InitAcceleration = accel.ToVector3(); },

			/// Set fixed lifetime for new particles.
			// @function ParticleGroup:SetLifetime
			// @tparam float seconds Lifetime in seconds.
			"SetLifetime", [](ParticleGroup& self, float seconds)
			{
				seconds = std::max(0.01f, seconds);
				self.LifetimeMin = seconds;
				self.LifetimeMax = seconds;
			},

			/// Set lifetime range for new particles.
			// @function ParticleGroup:SetLifetimeRange
			// @tparam float minSeconds Minimum lifetime.
			// @tparam float maxSeconds Maximum lifetime.
			"SetLifetimeRange", [](ParticleGroup& self, float minSec, float maxSec)
			{
				self.LifetimeMin = std::max(0.01f, minSec);
				self.LifetimeMax = std::max(self.LifetimeMin, maxSec);
			},

			/// Set fixed initial size for new particles.
			// @function ParticleGroup:SetInitialSize
			// @tparam float size Particle size.
			"SetInitialSize", [](ParticleGroup& self, float size)
			{
				self.InitSizeMin = size;
				self.InitSizeMax = size;
			},

			/// Set initial size range for new particles.
			// @function ParticleGroup:SetInitialSizeRange
			// @tparam float min Minimum size.
			// @tparam float max Maximum size.
			"SetInitialSizeRange", [](ParticleGroup& self, float min, float max)
			{
				self.InitSizeMin = min;
				self.InitSizeMax = std::max(min, max);
			},

			/// Set initial color for new particles.
			// @function ParticleGroup:SetInitialColor
			// @tparam Color color Particle color.
			"SetInitialColor", [](ParticleGroup& self, const ScriptColor& color)
			{
				self.InitColorMin = Color(color);
				self.InitColorMax = Color(color);
			},

			/// Set initial color range for new particles.
			// @function ParticleGroup:SetInitialColorRange
			// @tparam Color min Minimum color.
			// @tparam Color max Maximum color.
			"SetInitialColorRange", [](ParticleGroup& self, const ScriptColor& min, const ScriptColor& max)
			{
				self.InitColorMin = Color(min);
				self.InitColorMax = Color(max);
			},

			/// Set initial rotation for new particles (degrees).
			// @function ParticleGroup:SetInitialRotation
			// @tparam float rotation Rotation in degrees.
			"SetInitialRotation", [](ParticleGroup& self, float rotation) { self.InitRotation = rotation * RADIAN; },

			/// Set initial rotational velocity for new particles (degrees/sec).
			// @function ParticleGroup:SetInitialRotationVelocity
			// @tparam float rotVel Rotational velocity in degrees per second.
			"SetInitialRotationVelocity", [](ParticleGroup& self, float rotVel) { self.InitRotationVel = rotVel * RADIAN; },

			/// Set blend mode for rendering.
			// @function ParticleGroup:SetBlendMode
			// @tparam Effects.BlendID mode Blend mode.
			"SetBlendMode", [](ParticleGroup& self, BlendMode mode) { self.RenderBlendMode = mode; },

			/// Set sprite sequence for the group.
			// @function ParticleGroup:SetSpriteSequence
			// @tparam Objects.ObjID spriteSeqID Sprite sequence slot ID.
			"SetSpriteSequence", [](ParticleGroup& self, GAME_OBJECT_ID spriteSeqID)
			{
				if (CheckIfSlotExists(spriteSeqID, "ParticleGroup:SetSpriteSequence"))
					self.SpriteSeqID = spriteSeqID;
			},

			/// Set sprite index for new particles within the sprite sequence.
			// @function ParticleGroup:SetSpriteIndex
			// @tparam int index Sprite index.
			"SetSpriteIndex", [](ParticleGroup& self, int index) { self.InitSpriteIndex = index; },

			/// Set render distance.
			// @function ParticleGroup:SetRenderDistance
			// @tparam float distance Maximum render distance.
			"SetRenderDistance", [](ParticleGroup& self, float distance) { self.RenderDistance = std::max(0.0f, distance); },

			/// Get a specific particle's data as a table.
			// @function ParticleGroup:GetParticle
			// @tparam int index Particle index (0-based).
			// @treturn table Particle data table with position, velocity, size, color, age, etc.
			"GetParticle", [](ParticleGroup& self, int index, sol::this_state s) -> sol::object
			{
				if (index < 0 || index >= (int)self.Particles.size() || !self.Particles[index].Active)
					return sol::nil;

				const auto& p = self.Particles[index];
				sol::state_view lua(s);
				auto tbl = lua.create_table();
				tbl["id"] = p.ID;
				tbl["position"] = Vec3(p.Position);
				tbl["velocity"] = Vec3(p.Velocity);
				tbl["acceleration"] = Vec3(p.Acceleration);
				tbl["size"] = p.Size;
				tbl["rotation"] = p.Rotation;
				tbl["age"] = p.Age;
				tbl["lifetime"] = p.Lifetime;
				tbl["ageNormalized"] = p.AgeNormalized;
				tbl["spriteIndex"] = p.SpriteIndex;
				return tbl;
			},

			/// Set a specific particle's properties from a table.
			// @function ParticleGroup:SetParticle
			// @tparam int index Particle index (0-based).
			// @tparam table data Table with properties to set (position, velocity, size, color, rotation, spriteIndex, acceleration).
			"SetParticle", [](ParticleGroup& self, int index, sol::table data)
			{
				if (index < 0 || index >= (int)self.Particles.size() || !self.Particles[index].Active)
					return;

				auto& p = self.Particles[index];

				if (auto pos = data.get<sol::optional<Vec3>>("position"))
					p.Position = pos->ToVector3();
				if (auto vel = data.get<sol::optional<Vec3>>("velocity"))
					p.Velocity = vel->ToVector3();
				if (auto accel = data.get<sol::optional<Vec3>>("acceleration"))
					p.Acceleration = accel->ToVector3();
				if (auto size = data.get<sol::optional<float>>("size"))
					p.Size = *size;
				if (auto rot = data.get<sol::optional<float>>("rotation"))
					p.Rotation = *rot;
				if (auto sprite = data.get<sol::optional<int>>("spriteIndex"))
					p.SpriteIndex = *sprite;
				if (auto color = data.get<sol::optional<ScriptColor>>("color"))
					p.ParticleColor = Color(*color);
			},

			/// Iterate over all active particles, calling a function for each.
			// @function ParticleGroup:ForEachParticle
			// @tparam function callback Function receiving (index, particleTable) for each active particle.
			"ForEachParticle", [](ParticleGroup& self, sol::function callback, sol::this_state s)
			{
				sol::state_view lua(s);
				for (int i = 0; i < (int)self.Particles.size(); i++)
				{
					if (!self.Particles[i].Active)
						continue;

					const auto& p = self.Particles[i];
					auto tbl = lua.create_table();
					tbl["id"] = p.ID;
					tbl["position"] = Vec3(p.Position);
					tbl["velocity"] = Vec3(p.Velocity);
					tbl["acceleration"] = Vec3(p.Acceleration);
					tbl["size"] = p.Size;
					tbl["rotation"] = p.Rotation;
					tbl["age"] = p.Age;
					tbl["lifetime"] = p.Lifetime;
					tbl["ageNormalized"] = p.AgeNormalized;
					tbl["spriteIndex"] = p.SpriteIndex;

					auto result = callback(i, tbl);

					// If callback returns a table, apply changes back.
					if (result.valid() && result.get_type() == sol::type::table)
					{
						sol::table changes = result;
						auto& mp = self.Particles[i];

						if (auto pos = changes.get<sol::optional<Vec3>>("position"))
							mp.Position = pos->ToVector3();
						if (auto vel = changes.get<sol::optional<Vec3>>("velocity"))
							mp.Velocity = vel->ToVector3();
						if (auto accel = changes.get<sol::optional<Vec3>>("acceleration"))
							mp.Acceleration = accel->ToVector3();
						if (auto size = changes.get<sol::optional<float>>("size"))
							mp.Size = *size;
						if (auto rot = changes.get<sol::optional<float>>("rotation"))
							mp.Rotation = *rot;
						if (auto sprite = changes.get<sol::optional<int>>("spriteIndex"))
							mp.SpriteIndex = *sprite;
						if (auto color = changes.get<sol::optional<ScriptColor>>("color"))
							mp.ParticleColor = Color(*color);
					}
				}
			},

			/// (int) Unique group ID. Read-only.
			// @mem id
			"id", sol::readonly(&ParticleGroup::ID),

			/// (bool) Whether the group is active. Read-only.
			// @mem active
			"active", sol::readonly(&ParticleGroup::Active));

		// Emitters
		tableEffects.set_function(ScriptReserved_EmitLightningArc, &EmitLightningArc);
		tableEffects.set_function(ScriptReserved_EmitParticle, &EmitParticle);
		tableEffects.set_function(ScriptReserved_EmitAdvancedParticle, &EmitAdvancedParticle);
		tableEffects.set_function(ScriptReserved_EmitShockwave, &EmitShockwave);
		tableEffects.set_function(ScriptReserved_EmitLight, &EmitLight);
		tableEffects.set_function(ScriptReserved_EmitSpotLight, &EmitSpotLight);
		tableEffects.set_function(ScriptReserved_EmitFogBulb, &EmitFogBulb);
		tableEffects.set_function(ScriptReserved_EmitBlood, &EmitBlood);
		tableEffects.set_function(ScriptReserved_EmitAirBubble, &EmitAirBubble);
		tableEffects.set_function(ScriptReserved_EmitStreamer, &EmitStreamer);
		tableEffects.set_function(ScriptReserved_EmitFire, &EmitFire);
		tableEffects.set_function(ScriptReserved_EmitWaterfallMist, &EmitWaterfallMist);
		tableEffects.set_function(ScriptReserved_EmitFlow, &EmitFlow);
		tableEffects.set_function(ScriptReserved_MakeExplosion, &MakeExplosion);
		tableEffects.set_function(ScriptReserved_MakeEarthquake, &Earthquake);
		tableEffects.set_function(ScriptReserved_GetWind, &GetWind);

		// Particle groups
		tableEffects.set_function(ScriptReserved_CreateParticleGroup, &LuaCreateParticleGroup);

		auto handler = LuaHandler(state);
		handler.MakeReadOnlyTable(tableEffects, ScriptReserved_BlendID, BLEND_IDS);
		handler.MakeReadOnlyTable(tableEffects, ScriptReserved_EffectID, EFFECT_IDS);
		handler.MakeReadOnlyTable(tableEffects, ScriptReserved_FeatherMode, FEATHER_MODES);
		handler.MakeReadOnlyTable(tableEffects, ScriptReserved_ParticleAnimationType, PARTICLE_ANIM_TYPES);
	}
}


