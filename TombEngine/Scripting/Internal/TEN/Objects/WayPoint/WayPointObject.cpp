#include "framework.h"
#include "WayPointObject.h"
#include "Game/spotcam.h"

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

WayPointObject::WayPointObject(SPOTCAM& ref) : m_waypoint{ref}
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

		/// Get the waypoint's target position.
		// @function WayPoint:GetTarget
		// @treturn Vec3 Waypoint's target position.
		ScriptReserved_GetTarget, &WayPointObject::GetTarget,

		/// Set the waypoint's target position.
		// @function WayPoint:SetTarget
		// @tparam Vec3 target The new target position.
		ScriptReserved_SetTarget, &WayPointObject::SetTarget,

		/// Get the waypoint's unique string identifier.
		// @function WayPoint:GetName
		// @treturn string The waypoint's name.
		ScriptReserved_GetName, &WayPointObject::GetName,

		/// Set the waypoint's name (its unique string identifier).
		// @function WayPoint:SetName
		// @tparam string name The waypoint's new name.
		ScriptReserved_SetName, &WayPointObject::SetName,

		/// Get the waypoint's type/camera number.
		// @function WayPoint:GetType
		// @treturn int The waypoint's type identifier.
		ScriptReserved_GetType, &WayPointObject::GetType,

		/// Set the waypoint's type/camera number.
		// @function WayPoint:SetType
		// @tparam int type The waypoint's new type identifier.
		ScriptReserved_SetType, &WayPointObject::SetType,

		/// Get the waypoint's sequence number.
		// @function WayPoint:GetSequence
		// @treturn int The waypoint's sequence number.
		ScriptReserved_GetSequence, &WayPointObject::GetSequence,

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

Vec3 WayPointObject::GetTarget() const
{
	return Vec3(m_waypoint.tx, m_waypoint.ty, m_waypoint.tz);
}

void WayPointObject::SetTarget(Vec3 const& target)
{
	m_waypoint.tx = target.x;
	m_waypoint.ty = target.y;
	m_waypoint.tz = target.z;
}

std::string WayPointObject::GetName() const
{
	// Generate name based on sequence and camera index
	return "waypoint_" + std::to_string(m_waypoint.sequence) + "_" + std::to_string(m_waypoint.camera);
}

void WayPointObject::SetName(std::string const& id)
{
	if (!ScriptAssert(!id.empty(), "Name cannot be blank. Not setting name."))
		return;

	// Note: SPOTCAM structure doesn't support arbitrary names
	// This would require extending the level format
	TENLog("Setting custom waypoint names is not supported. Waypoint names are auto-generated based on sequence and camera index.", LogLevel::Warning, LogConfig::All);
}

int WayPointObject::GetType() const
{
	return m_waypoint.camera;
}

void WayPointObject::SetType(int type)
{
	m_waypoint.camera = (unsigned char)type;
}

int WayPointObject::GetSequence() const
{
	return m_waypoint.sequence;
}

Vec3 WayPointObject::GetPathPosition(float alpha, bool loop) const
{
	return Vec3(GetCameraTransform(m_waypoint.sequence, alpha, loop).Position);
}

Rotation WayPointObject::GetPathRotation(float alpha, bool loop) const
{
	return Rotation(GetCameraTransform(m_waypoint.sequence, alpha, loop).Orientation);
}
