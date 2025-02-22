#include "framework.h"
#include "Scripting/Internal/TEN/Util/Collision.h"
#include "Scripting/Internal/TEN/Util/FloorMaterial.h"

#include "Game/collision/Point.h"
#include "Game/Lara/lara_climb.h"
#include "Scripting/Internal/TEN/Objects/Moveable/MoveableObject.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"

namespace TEN::Scripting::Util
{
	/// Represents a collision object in the game world.
	// Provides collision information at a given world position.
	//
	// @tenclass Objects.Collision
	// pragma nostrip

    void ScriptCollision::Register(sol::table& parent)
    {
		using ctors = sol::constructors<
			ScriptCollision(const Vec3&, int),
			ScriptCollision(const Vec3&, int, const Vec3&, float),
			ScriptCollision(const Vec3&, int, float, float, float, float, sol::optional<Vec3>&),
			ScriptCollision(const Moveable& mov)>;

		// Register type.
		parent.new_usertype<ScriptCollision>(
			"Collision",
			ctors(), sol::call_constructor, ctors(),

			// Getters

			"GetPosition", &ScriptCollision::GetPosition,
			"GetRoomNumber", &ScriptCollision::GetRoomNumber,
			"GetFloorHeight", &ScriptCollision::GetFloorHeight,
			"GetCeilingHeight", &ScriptCollision::GetCeilingHeight,
			"GetFloorNormal", &ScriptCollision::GetFloorNormal,
			"GetCeilingNormal", &ScriptCollision::GetCeilingNormal,
			"GetWaterSurfaceHeight", &ScriptCollision::GetWaterSurfaceHeight,
			"GetSurfaceMaterial", & ScriptCollision::GetSurfaceMaterial,

			// Inquirers

			"IsWall", &ScriptCollision::IsWall,
			"IsSteepFloor", &ScriptCollision::IsSteepFloor,
			"IsSteepCeiling", &ScriptCollision::IsSteepCeiling,
			"IsClimbableWall", & ScriptCollision::IsClimbableWall,
			"IsMonkeySwing", & ScriptCollision::IsMonkeySwing,
			"IsDeathTile", & ScriptCollision::IsDeath);

    }

	ScriptCollision::ScriptCollision(const Vec3& pos, int roomNumber)
	{
		_pointCollision = GetPointCollision(pos.ToVector3i(), roomNumber);
	}

	ScriptCollision::ScriptCollision(const Moveable& mov)
	{
		// TODO: *MUST* pass native ItemInfo moveable to allow PointCollisionData to handle quirks associated with the way moveable's update their room numebrs.
		// GetPointCollision(mov.GetNativeMoveable());

		_pointCollision = GetPointCollision(mov.GetPosition().ToVector3i(), mov.GetRoomNumber());
	}

	ScriptCollision::ScriptCollision(const Vec3& pos, int roomNumber, const Vec3& dir, float dist)
	{
		_pointCollision = GetPointCollision(pos.ToVector3(), roomNumber, dir.ToVector3(), dist);
	}

	ScriptCollision::ScriptCollision(const Vec3& pos, int roomNumber, float headingAngle, float forward, float down, float right, sol::optional<Vec3>& axis)
	{
		static const auto DEFAULT_AXIS = Vec3(0.0f, 1.0f, 0.0f);

		short convertedAngle = ANGLE(headingAngle);
		auto convertedAxis = axis.value_or(DEFAULT_AXIS).ToVector3();
		_pointCollision = GetPointCollision(pos.ToVector3i(), roomNumber, convertedAngle, forward, down, right, convertedAxis);
	}

	Vec3 ScriptCollision::GetPosition()
	{
		return Vec3(_pointCollision.GetPosition());
	}

	int ScriptCollision::GetRoomNumber()
	{
		return _pointCollision.GetRoomNumber();
	}

	sol::optional<int> ScriptCollision::GetFloorHeight()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		int height = _pointCollision.GetFloorHeight();
		if (height != NO_HEIGHT)
			return height;

		return sol::nullopt;
	}

	sol::optional<int> ScriptCollision::GetCeilingHeight()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		int height = _pointCollision.GetCeilingHeight();
		if (height != NO_HEIGHT)
			return height;

		return sol::nullopt;
	}

	sol::optional<Vec3> ScriptCollision::GetFloorNormal()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		return Vec3(_pointCollision.GetFloorNormal());
	}

	sol::optional<Vec3> ScriptCollision::GetCeilingNormal()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		return Vec3(_pointCollision.GetCeilingNormal());
	}

	sol::optional<int> ScriptCollision::GetWaterSurfaceHeight()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		int height = _pointCollision.GetWaterSurfaceHeight();
		if (height != NO_HEIGHT)
			return height;

		return sol::nullopt;
	}

	sol::optional<MaterialType> ScriptCollision::GetSurfaceMaterial()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;
		
		auto material = (_pointCollision.GetBottomSector().GetSurfaceMaterial(_pointCollision.GetPosition().x, _pointCollision.GetPosition().z, true));
		
		return (MaterialType)material;
	}

	bool ScriptCollision::IsSteepFloor()
	{
		if (_pointCollision.IsWall())
			return false;

		return _pointCollision.IsSteepFloor();
	}

	bool ScriptCollision::IsSteepCeiling()
	{
		if (_pointCollision.IsWall())
			return false;

		return _pointCollision.IsSteepCeiling();
	}

	bool ScriptCollision::IsWall()
	{
		return _pointCollision.IsWall();
	}

	bool ScriptCollision::IsClimbableWall(short angle)
	{
		auto check = (_pointCollision.GetBottomSector().Flags.IsWallClimbable(GetClimbDirectionFlags(ANGLE(angle))));

		return check;
	}

	bool ScriptCollision::IsMonkeySwing()
	{
		auto check = (_pointCollision.GetTopSector().Flags.Monkeyswing);

		return check;
	}

	bool ScriptCollision::IsDeath()
	{
		auto check = (_pointCollision.GetBottomSector().Flags.Death);

		return check;
	}
}