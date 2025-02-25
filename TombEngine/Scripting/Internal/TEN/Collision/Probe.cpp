#include "framework.h"
#include "Scripting/Internal/TEN/Collision/Probe.h"
#include "Scripting/Internal/TEN/Collision/MaterialTypes.h"

#include "Game/collision/Point.h"
#include "Game/Lara/lara_climb.h"
#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/TEN/Objects/Moveable/MoveableObject.h"
#include "Scripting/Internal/TEN/Objects/Room/RoomObject.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"
#include "Specific/level.h"

using namespace TEN::Collision::Point;

namespace TEN::Scripting::Collision
{
	/// Represents a collision probe in the game world.
	// Provides collision information from a reference world position.
	//
	// @tenclass Collision.Probe
	// pragma nostrip

	void Probe::Register(sol::table& parent)
	{
		using ctors = sol::constructors<
			Probe(const Vec3&, int),
			Probe(const Vec3&, int, const Vec3&, float),
			Probe(const Vec3&, int, const Rotation&, float),
			Probe(const Vec3&, int, const Rotation&, const Vec3&)>;

		// Register type.
		parent.new_usertype<Probe>(
			"Probe",
			ctors(), sol::call_constructor, ctors(),

			// Getters
			"GetPosition", &Probe::GetPosition,
			"GetRoomNumber", &Probe::GetRoomNumber,
			"GetRoomName", &Probe::GetRoomName,
			"GetRoom", & Probe::GetRoom,
			"GetFloorHeight", &Probe::GetFloorHeight,
			"GetCeilingHeight", &Probe::GetCeilingHeight,
			"GetWaterSurfaceHeight", &Probe::GetWaterSurfaceHeight,
			"GetFloorNormal", &Probe::GetFloorNormal,
			"GetCeilingNormal", &Probe::GetCeilingNormal,
			"GetFloorMaterialType", &Probe::GetFloorMaterialType,
			"GetCeilingMaterialType", &Probe::GetCeilingMaterialType,

			// Inquirers
			"IsSteepFloor", &Probe::IsSteepFloor,
			"IsSteepCeiling", &Probe::IsSteepCeiling,
			"IsWall", &Probe::IsWall,
			"IsInsideSolidGeometry", &Probe::IsInsideSolidGeometry,
			"IsClimbableWall", &Probe::IsClimbableWall,
			"IsMonkeySwing", &Probe::IsMonkeySwing,
			"IsDeathTile", &Probe::IsDeath);
	}

	/// Create a Probe at a specified world position in a room.
	// @function Probe
	// @tparam Vec3 pos World position.
	// @tparam int roomNumber Room number.
	// @treturn Probe A new Probe.
	Probe::Probe(const Vec3& pos, int roomNumber)
	{
		_pointCollision = GetPointCollision(pos.ToVector3i(), roomNumber);
	}

	/// Create a Probe that casts from an origin world position in a room in a given direction for a specified distance.
	// Required to correctly traverse between rooms.
	// @function Probe
	// @tparam Vec3 pos Origin world position to cast from.
	// @tparam int originRoomNumber Origin's room number.
	// @tparam Vec3 dir Direction in which to cast.
	// @tparam float dist Distance to cast.
	// @treturn Probe A new Probe.
	Probe::Probe(const Vec3& origin, int originRoomNumber, const Vec3& dir, float dist)
	{
		_pointCollision = GetPointCollision(origin.ToVector3i(), originRoomNumber, dir.ToVector3(), dist);
	}

	/// Create a Probe that casts from an origin world position in a room in the direction of a given Rotation for a specified distance.
	// Required to correctly traverse between rooms.
	// @function Probe
	// @tparam Vec3 Origin world position to cast from.
	// @tparam int originRoomNumber Origin's room number.
	// @tparam Rotation rot Rotation defining the direction in which to cast.
	// @tparam float dist Distance to cast.
	// @treturn Probe A new Probe.
	Probe::Probe(const Vec3& origin, int originRoomNumber, const Rotation& rot, float dist)
	{
		auto dir = rot.ToEulerAngles().ToDirection();
		_pointCollision = GetPointCollision(origin.ToVector3(), originRoomNumber, dir, dist);
	}

	/// Create a Probe that casts from an origin world position, where a given relative offset is rotated according to a given Rotation.
	// Required to correctly traverse between rooms.
	// @function Probe
	// @tparam Vec3 Origin world position to cast from.
	// @tparam int originRoomNumber Origin's room number.
	// @tparam Rotation rot Rotation according to which the input relative offset is rotated.
	// @tparam Vec3 relOffset Relative offset to cast.
	// @treturn Probe A new Probe.
	Probe::Probe(const Vec3& origin, int originRoomNumber, const Rotation& rot, const Vec3& relOffset)
	{
		auto target = Geometry::TranslatePoint(origin.ToVector3(), rot.ToEulerAngles(), relOffset.ToVector3());
		float dist = Vector3::Distance(origin.ToVector3(), target);

		auto dir = target - origin.ToVector3();
		dir.Normalize();

		_pointCollision = GetPointCollision(origin.ToVector3(), originRoomNumber, dir, dist);
	}

	/// Get the world position of this Probe.
	// @function GetPosition
	// @treturn Vec3 World position.
	Vec3 Probe::GetPosition()
	{
		return Vec3(_pointCollision.GetPosition());
	}


	/// Get the room number of this Probe.
	// @treturn int Room number.
	int Probe::GetRoomNumber()
	{
		return _pointCollision.GetRoomNumber();
	}

	
	/// Get the room name of this Probe.
	// @function GetRoomName
	// @treturn string Room name.
	std::string Probe::GetRoomName()
	{
		int roomNumber = _pointCollision.GetRoomNumber();
		const auto& room = g_Level.Rooms[roomNumber];

		return room.Name;
	}

	/// Get the room object of this Probe.
	// @function GetRoom
	// @treturn Room Room Object
	std::unique_ptr<Room> Probe::GetRoom()
	{
		int roomNumber = _pointCollision.GetRoomNumber();
		return std::make_unique<Room>(g_Level.Rooms[roomNumber]);
	}

	/// Get the floor height at this Probe.
	// @function GetFloorHeight
	// @treturn int Floor height. __nil: no floor exists.__
	sol::optional<int> Probe::GetFloorHeight()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		int height = _pointCollision.GetFloorHeight();
		if (height != NO_HEIGHT)
			return height;

		return sol::nullopt;
	}

	/// Get the ceiling height at this Probe.
	// @function GetCeilingHeight
	// @treturn int Ceiling height. __nil: no ceiling exists.__
	sol::optional<int> Probe::GetCeilingHeight()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		int height = _pointCollision.GetCeilingHeight();
		if (height != NO_HEIGHT)
			return height;

		return sol::nullopt;
	}

	/// Get the water surface height at this Probe.
	// @function GetWaterSurfaceHeight
	// @treturn int Water surface height. __nil: no water surface exists.__
	sol::optional<int> Probe::GetWaterSurfaceHeight()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		int height = _pointCollision.GetWaterSurfaceHeight();
		if (height != NO_HEIGHT)
			return height;

		return sol::nullopt;
	}

	/// Get the normal of the floor at this Probe.
	// @function GetFloorNormal
	// @treturn Vec3 Floor normal. __nil: no floor exists.__
	sol::optional<Vec3> Probe::GetFloorNormal()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		return Vec3(_pointCollision.GetFloorNormal());
	}

	/// Get the normal of the ceiling at this Probe.
	// @function GetCeilingNormal
	// @treturn Vec3 Ceiling normal. __nil: no ceiling exists.__
	sol::optional<Vec3> Probe::GetCeilingNormal()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;

		return Vec3(_pointCollision.GetCeilingNormal());
	}

	/// Get the material type of the floor at this Probe.
	// @function GetFloorMaterialType
	// @treturn Collision.MaterialType Floor material type. __nil: no floor exists.__
	sol::optional<MaterialType> Probe::GetFloorMaterialType()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;
		
		const auto& sector = _pointCollision.GetBottomSector();
		auto material = sector.GetSurfaceMaterial(_pointCollision.GetPosition().x, _pointCollision.GetPosition().z, true);
		return material;
	}

	/// Get the material type of the ceiling at this Probe.
	// @function GetCeilingMaterialType
	// @treturn Collision.MaterialType Ceiling material type. __nil: no ceiling exists.__
	sol::optional<MaterialType> Probe::GetCeilingMaterialType()
	{
		if (_pointCollision.IsWall())
			return sol::nullopt;
		
		const auto& sector = _pointCollision.GetTopSector();
		auto material = sector.GetSurfaceMaterial(_pointCollision.GetPosition().x, _pointCollision.GetPosition().z, false);
		return material;
	}

	/// Check if the floor at this Probe is steep.
	// @function IsSteepFloor
	// @treturn bool Steep floor status. __true: is a steep floor, false: isn't a steep floor, nil: no floor exists.__
	sol::optional<bool> Probe::IsSteepFloor()
	{
		if (_pointCollision.IsWall())
			return false;

		return _pointCollision.IsSteepFloor();
	}

	/// Check if the ceiling at this Probe is steep.
	// @function IsSteepCeiling
	// @treturn bool Steep ceiling status. __true: is a steep ceiling, false: isn't a steep ceiling, nil: no ceiling exists.__
	sol::optional<bool> Probe::IsSteepCeiling()
	{
		if (_pointCollision.IsWall())
			return false;

		return _pointCollision.IsSteepCeiling();
	}

	/// Check if the Probe is inside a wall. Can be used to determine if a wall and ceiling exist.
	// @function IsWall
	// @treturn bool Wall status. __true: is a wall, false: isn't a wall__
	bool Probe::IsWall()
	{
		return _pointCollision.IsWall();
	}

	/// Check if this Probe is inside solid geometry, i.e. below a floor, above a ceiling, or inside a wall.
	// @function IsInsideSolidGeometry
	// @treturn bool Inside geometry status. __true: is inside, false: is outside__
	bool Probe::IsInsideSolidGeometry()
	{
		if (_pointCollision.IsWall() ||
			_pointCollision.GetPosition().y > _pointCollision.GetFloorHeight() ||
			_pointCollision.GetPosition().y < _pointCollision.GetCeilingHeight())
		{
			return true;
		}

		return false;
	}

	/// Check if there is a climbable wall in the given heading angle at this Probe.
	// @function IsClimbableWall
	// @tparam float headingAngle Heading angle at which to check for a climbable wall.
	// @treturn bool Climbable wall status. __true: is climbable, false: isn't climbable__
	bool Probe::IsClimbableWall(float headingAngle)
	{
		const auto& sector = _pointCollision.GetBottomSector();
		auto dirFlag = GetClimbDirectionFlags(ANGLE(headingAngle));
		return sector.Flags.IsWallClimbable(dirFlag);
	}

	/// Check if there is a monkey swing at this Probe.
	// @function IsMonkeySwing
	// @treturn bool Monkey swing status. __true: is a monkey swing, false: isn't a monkey swing__
	bool Probe::IsMonkeySwing()
	{
		const auto& sector = _pointCollision.GetTopSector();
		return sector.Flags.Monkeyswing;
	}

	/// Check if there is a death tile at this Probe.
	// @function IsDeath
	// @treturn bool Death tile status. __true: is a death tile, false: isn't a death tile__
	bool Probe::IsDeath()
	{
		const auto& sector = _pointCollision.GetBottomSector();
		return sector.Flags.Death;
	}

	void Register(sol::state* state, sol::table& parent)
	{
		auto tableCollision= sol::table(state->lua_state(), sol::create);
		parent.set("Collision", tableCollision);

		auto handler = LuaHandler{ state };
		handler.MakeReadOnlyTable(tableCollision, "MaterialType", SCRIPT_MATERIAL_TYPES);
	}
}
