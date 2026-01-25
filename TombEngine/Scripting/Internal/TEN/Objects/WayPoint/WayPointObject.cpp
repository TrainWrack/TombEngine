#include "framework.h"
#include "WayPointObject.h"
#include "Game/waypoint.h"

#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptAssert.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"
#include "Specific/level.h"

/***
Waypoint objects for navigation and path traversal.

@tenclass Objects.WayPoint
@pragma nostrip
*/

static auto IndexError = IndexErrorMaker(WayPointObject, ScriptReserved_WayPoint);
static auto NewIndexError = NewIndexErrorMaker(WayPointObject, ScriptReserved_WayPoint);

WayPointObject::WayPointObject(WAYPOINT& ref) : m_waypoint{ref}
{};

void WayPointObject::Register(sol::table& parent)
{
	parent.new_usertype<WayPointObject>(ScriptReserved_WayPoint,
		sol::no_constructor,
		sol::meta_function::index, IndexError,
		sol::meta_function::new_index, NewIndexError,

		/// Get the waypoint's position.
		// @function WayPoint:GetPosition
		// @treturn Vec3 Waypoint's position.
		ScriptReserved_GetPosition, &WayPointObject::GetPos,

		/// Set the waypoint's position.
		// @function WayPoint:SetPosition
		// @tparam Vec3 position The new position of the waypoint.
		ScriptReserved_SetPosition, &WayPointObject::SetPos,

		/// Get the waypoint's unique string identifier.
		// @function WayPoint:GetName
		// @treturn string The waypoint's name.
		ScriptReserved_GetName, &WayPointObject::GetName,

		/// Set the waypoint's name (its unique string identifier).
		// @function WayPoint:SetName
		// @tparam string name The waypoint's new name.
		ScriptReserved_SetName, &WayPointObject::SetName,

		/// Get the waypoint's type.
		// @function WayPoint:GetType
		// @treturn int The waypoint's type identifier.
		ScriptReserved_GetType, &WayPointObject::GetType,

		/// Set the waypoint's type.
		// @function WayPoint:SetType
		// @tparam int type The waypoint's new type identifier.
		ScriptReserved_SetType, &WayPointObject::SetType,

		/// Get the waypoint's number.
		// @function WayPoint:GetNumber
		// @treturn int The waypoint's number.
		ScriptReserved_GetNumber, &WayPointObject::GetNumber,

		/// Set the waypoint's number.
		// @function WayPoint:SetNumber
		// @tparam int number The waypoint's new number.
		ScriptReserved_SetNumber, &WayPointObject::SetNumber,

		/// Get the waypoint's radius1.
		// @function WayPoint:GetRadius1
		// @treturn float The waypoint's radius1.
		ScriptReserved_GetRadius1, &WayPointObject::GetRadius1,

		/// Set the waypoint's radius1.
		// @function WayPoint:SetRadius1
		// @tparam float radius The waypoint's new radius1.
		ScriptReserved_SetRadius1, &WayPointObject::SetRadius1,

		/// Get the waypoint's radius2.
		// @function WayPoint:GetRadius2
		// @treturn float The waypoint's radius2.
		ScriptReserved_GetRadius2, &WayPointObject::GetRadius2,

		/// Set the waypoint's radius2.
		// @function WayPoint:SetRadius2
		// @tparam float radius The waypoint's new radius2.
		ScriptReserved_SetRadius2, &WayPointObject::SetRadius2,

		/// Get an interpolated position along the waypoint path.
		// @function WayPoint:GetPathPosition
		// @tparam float alpha Progress along the path (0.0 to 1.0).
		// @tparam bool loop Whether to loop the path continuously.
		// @treturn Vec3 Interpolated position at the given alpha.
		ScriptReserved_GetPathPosition, &WayPointObject::GetPathPosition,

		/// Get an interpolated rotation along the waypoint path.
		// @function WayPoint:GetPathRotation
		// @tparam float alpha Progress along the path (0.0 to 1.0).
		// @tparam bool loop Whether to loop the path continuously.
		// @treturn Rotation Interpolated rotation at the given alpha.
		ScriptReserved_GetPathRotation, &WayPointObject::GetPathRotation);
}

Vec3 WayPointObject::GetPos() const
{
	return Vec3(m_waypoint.x, m_waypoint.y, m_waypoint.z);
}

void WayPointObject::SetPos(Vec3 const& pos)
{
	m_waypoint.x = pos.x;
	m_waypoint.y = pos.y;
	m_waypoint.z = pos.z;
}

std::string WayPointObject::GetName() const
{
	return m_waypoint.name;
}

void WayPointObject::SetName(std::string const& id)
{
	if (!ScriptAssert(!id.empty(), "Name cannot be blank. Not setting name."))
		return;

	if (_callbackSetName(id, m_waypoint))
	{
		// Remove old name if it exists
		_callbackRemoveName(m_waypoint.name);
		m_waypoint.name = id;
	}
	else
	{
		ScriptAssertF(false, "Could not add name {} - does a waypoint with this name already exist?", id);
		TENLog("Name will not be set", LogLevel::Warning, LogConfig::All);
	}
}

int WayPointObject::GetType() const
{
	return m_waypoint.type;
}

void WayPointObject::SetType(int type)
{
	m_waypoint.type = type;
}

int WayPointObject::GetNumber() const
{
	return m_waypoint.number;
}

void WayPointObject::SetNumber(int number)
{
	m_waypoint.number = (unsigned short)number;
}

float WayPointObject::GetRadius1() const
{
	return m_waypoint.radius1;
}

void WayPointObject::SetRadius1(float radius)
{
	m_waypoint.radius1 = radius;
}

float WayPointObject::GetRadius2() const
{
	return m_waypoint.radius2;
}

void WayPointObject::SetRadius2(float radius)
{
	m_waypoint.radius2 = radius;
}

Vec3 WayPointObject::GetPathPosition(float alpha, bool loop) const
{
	return Vec3(CalculateWayPointTransform(m_waypoint.name, alpha, loop).Position);
}

Rotation WayPointObject::GetPathRotation(float alpha, bool loop) const
{
	return Rotation(CalculateWayPointTransform(m_waypoint.name, alpha, loop).Orientation);
}
