#include "framework.h"
#include "WayPointObject.h"
#include "Game/waypoint.h"
#include "Game/debug/debug.h"

#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptAssert.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"
#include "Specific/level.h"

using namespace TEN::Debug;

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
		ScriptReserved_GetPathRotation, &WayPointObject::GetPathRotation,

		/// Preview/visualize the waypoint for debugging purposes.
		// @function WayPoint:Preview
		// @tparam[opt] Color color Optional color for the preview (defaults to orange).
		ScriptReserved_Preview, &WayPointObject::Preview);
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

void WayPointObject::Preview(sol::optional<Vector4> color) const
{
	constexpr auto DEFAULT_COLOR = Vector4(1.0f, 0.65f, 0.0f, 1.0f); // Orange
	constexpr auto TARGET_RADIUS = 128.0f;
	constexpr auto NUM_SEGMENTS = 32;
	
	Vector4 previewColor = color.value_or(DEFAULT_COLOR);
	Color drawColor(previewColor.x, previewColor.y, previewColor.z, previewColor.w);
	
	Vector3 centerPos(m_waypoint.x, m_waypoint.y, m_waypoint.z);
	WayPointType wpType = static_cast<WayPointType>(m_waypoint.type);
	
	// Create rotation matrix from waypoint's rotations
	Matrix rotationMatrix = Matrix::CreateRotationX(m_waypoint.rotationX * (float)RADIAN) *
	                        Matrix::CreateRotationY(m_waypoint.rotationY * (float)RADIAN) *
	                        Matrix::CreateRotationZ(m_waypoint.roll * (float)RADIAN);
	Quaternion orient = Quaternion::CreateFromRotationMatrix(rotationMatrix);
	
	switch (wpType)
	{
		case WayPointType::Point:
			// Draw a target marker for a single point
			DrawDebugTarget(centerPos, orient, TARGET_RADIUS, drawColor, RendererDebugPage::CollisionStats);
			break;
			
		case WayPointType::Circle:
		{
			// Draw a sphere to represent the circle
			DrawDebugSphere(centerPos, m_waypoint.radius1, drawColor, RendererDebugPage::CollisionStats, true);
			break;
		}
		
		case WayPointType::Ellipse:
		{
			// Draw ellipse as a series of lines
			// Since there's no direct ellipse function, we'll draw it as connected line segments
			for (int i = 0; i < NUM_SEGMENTS; i++)
			{
				float angle1 = (i / (float)NUM_SEGMENTS) * 2.0f * (float)PI;
				float angle2 = ((i + 1) / (float)NUM_SEGMENTS) * 2.0f * (float)PI;
				
				Vector3 local1(std::cos(angle1) * m_waypoint.radius1, 0.0f, std::sin(angle1) * m_waypoint.radius2);
				Vector3 local2(std::cos(angle2) * m_waypoint.radius1, 0.0f, std::sin(angle2) * m_waypoint.radius2);
				
				Vector3 world1 = Vector3::Transform(local1, rotationMatrix) + centerPos;
				Vector3 world2 = Vector3::Transform(local2, rotationMatrix) + centerPos;
				
				DrawDebugLine(world1, world2, drawColor, RendererDebugPage::CollisionStats);
			}
			break;
		}
		
		case WayPointType::Square:
		{
			// Draw square as four connected lines
			float r = m_waypoint.radius1;
			Vector3 corners[5] = {
				Vector3(-r, 0.0f, -r),
				Vector3(r, 0.0f, -r),
				Vector3(r, 0.0f, r),
				Vector3(-r, 0.0f, r),
				Vector3(-r, 0.0f, -r) // Close the loop
			};
			
			for (int i = 0; i < 4; i++)
			{
				Vector3 world1 = Vector3::Transform(corners[i], rotationMatrix) + centerPos;
				Vector3 world2 = Vector3::Transform(corners[i + 1], rotationMatrix) + centerPos;
				DrawDebugLine(world1, world2, drawColor, RendererDebugPage::CollisionStats);
			}
			break;
		}
		
		case WayPointType::Rectangle:
		{
			// Draw rectangle as four connected lines
			float r1 = m_waypoint.radius1;
			float r2 = m_waypoint.radius2;
			Vector3 corners[5] = {
				Vector3(-r1, 0.0f, -r2),
				Vector3(r1, 0.0f, -r2),
				Vector3(r1, 0.0f, r2),
				Vector3(-r1, 0.0f, r2),
				Vector3(-r1, 0.0f, -r2) // Close the loop
			};
			
			for (int i = 0; i < 4; i++)
			{
				Vector3 world1 = Vector3::Transform(corners[i], rotationMatrix) + centerPos;
				Vector3 world2 = Vector3::Transform(corners[i + 1], rotationMatrix) + centerPos;
				DrawDebugLine(world1, world2, drawColor, RendererDebugPage::CollisionStats);
			}
			break;
		}
		
		case WayPointType::Linear:
		case WayPointType::Bezier:
		{
			// Draw path as connected line segments
			// Find all waypoints with the same name
			std::vector<const WAYPOINT*> pathWaypoints;
			for (const auto& wp : WayPoints)
			{
				if (wp.name == m_waypoint.name)
					pathWaypoints.push_back(&wp);
			}
			
			if (pathWaypoints.size() < 2)
			{
				// If there's only one waypoint, just draw a target
				DrawDebugTarget(centerPos, orient, TARGET_RADIUS, drawColor, RendererDebugPage::CollisionStats);
				break;
			}
			
			// Sort by number
			std::sort(pathWaypoints.begin(), pathWaypoints.end(), 
				[](const WAYPOINT* a, const WAYPOINT* b) { return a->number < b->number; });
			
			// Draw lines between waypoints or interpolated path
			constexpr int PATH_SEGMENTS = 50;
			for (int i = 0; i < PATH_SEGMENTS; i++)
			{
				float alpha1 = i / (float)PATH_SEGMENTS;
				float alpha2 = (i + 1) / (float)PATH_SEGMENTS;
				
				Vector3 pos1 = CalculateWayPointTransform(m_waypoint.name, alpha1, false).Position;
				Vector3 pos2 = CalculateWayPointTransform(m_waypoint.name, alpha2, false).Position;
				
				DrawDebugLine(pos1, pos2, drawColor, RendererDebugPage::CollisionStats);
			}
			
			// Draw markers at each waypoint position
			for (const auto* wp : pathWaypoints)
			{
				Vector3 wpPos(wp->x, wp->y, wp->z);
				DrawDebugSphere(wpPos, 32.0f, drawColor, RendererDebugPage::CollisionStats, true);
			}
			break;
		}
	}
}

