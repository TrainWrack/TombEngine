#include "framework.h"
#include "WayPointHandler.h"
#include "Game/waypoint.h"
#include "Game/debug/debug.h"
#include "WayPointTypes.h"

#include "Scripting/Internal/LuaHandler.h"
#include "Scripting/Internal/ReservedScriptNames.h"
#include "Scripting/Internal/ScriptAssert.h"
#include "Scripting/Internal/ScriptUtil.h"
#include "Scripting/Internal/TEN/Types/Vec3/Vec3.h"
#include "Scripting/Internal/TEN/Types/Rotation/Rotation.h"
#include "Specific/level.h"

using namespace TEN::Debug;

namespace TEN::Scripting::WayPoint
{
	/***
	Waypoint objects for navigation and path traversal.
	
	@tenclass WayPoint.WayPoint
	@pragma nostrip
	*/

	static auto IndexError = IndexErrorMaker(WayPointHandler, ScriptReserved_WayPoint);
	static auto NewIndexError = NewIndexErrorMaker(WayPointHandler, ScriptReserved_WayPoint);

	/// Create a WayPoint handler by waypoint name.
	// @function WayPoint
	// @tparam string name Waypoint name.
	// @treturn WayPoint A new WayPoint handler.
	WayPointHandler::WayPointHandler(const std::string& name) : m_waypoint(nullptr)
	{
		// Find waypoint by name
		for (auto& wp : WayPoints)
		{
			if (wp.name == name)
			{
				m_waypoint = &wp;
				return;
			}
		}
		
		ScriptAssertF(false, "Waypoint with name '{}' not found.", name);
	}

	void WayPointHandler::Register(sol::table& parent)
	{
		using ctors = sol::constructors<WayPointHandler(const std::string&)>;

		parent.new_usertype<WayPointHandler>(
			ScriptReserved_WayPoint,
			ctors(), sol::call_constructor, ctors(),
			sol::meta_function::index, IndexError,
			sol::meta_function::new_index, NewIndexError,

			/// Get the waypoint's position.
			// @function WayPoint:GetPosition
			// @treturn Vec3 Waypoint's position.
			ScriptReserved_GetPosition, &WayPointHandler::GetPosition,

			/// Set the waypoint's position.
			// @function WayPoint:SetPosition
			// @tparam Vec3 position The new position of the waypoint.
			ScriptReserved_SetPosition, &WayPointHandler::SetPosition,

			/// Get the waypoint's unique string identifier.
			// @function WayPoint:GetName
			// @treturn string The waypoint's name.
			ScriptReserved_GetName, &WayPointHandler::GetName,

			/// Get the waypoint's type.
			// @function WayPoint:GetType
			// @treturn int The waypoint's type identifier.
			ScriptReserved_GetType, &WayPointHandler::GetType,

			/// Get the waypoint's number.
			// @function WayPoint:GetSequence
			// @treturn int The waypoint's sequence number.
			ScriptReserved_GetSequence, & WayPointHandler::GetSequence,

			/// Get the waypoint's number.
			// @function WayPoint:GetNumber
			// @treturn int The waypoint's number.
			ScriptReserved_GetNumber, &WayPointHandler::GetNumber,

			/// Get the waypoint's radius1.
			// @function WayPoint:GetRadius1
			// @treturn float The waypoint's radius1.
			ScriptReserved_GetDimension1, &WayPointHandler::GetRadius1,

			/// Set the waypoint's radius1.
			// @function WayPoint:SetRadius1
			// @tparam float radius The waypoint's new radius1.
			ScriptReserved_SetDimension1, &WayPointHandler::SetRadius1,

			/// Get the waypoint's radius2.
			// @function WayPoint:GetRadius2
			// @treturn float The waypoint's radius2.
			ScriptReserved_GetDimension2, &WayPointHandler::GetRadius2,

			/// Set the waypoint's radius2.
			// @function WayPoint:SetRadius2
			// @tparam float radius The waypoint's new radius2.
			ScriptReserved_SetDimension2, &WayPointHandler::SetRadius2,

			/// Get an interpolated position along the waypoint path.
			// @function WayPoint:GetPathPosition
			// @tparam float alpha Progress along the path (0.0 to 1.0).
			// @tparam bool loop Whether to loop the path continuously.
			// @treturn Vec3 Interpolated position at the given alpha.
			ScriptReserved_GetPathPosition, &WayPointHandler::GetPathPosition,

			/// Get an interpolated rotation along the waypoint path.
			// @function WayPoint:GetPathRotation
			// @tparam float alpha Progress along the path (0.0 to 1.0).
			// @tparam bool loop Whether to loop the path continuously.
			// @treturn Rotation Interpolated rotation at the given alpha.
			ScriptReserved_GetPathRotation, &WayPointHandler::GetPathRotation,

			/// Preview/visualize the waypoint for debugging purposes.
			// @function WayPoint:Preview
			// @tparam[opt] Color color Optional color for the preview (defaults to orange).
			ScriptReserved_Preview, &WayPointHandler::Preview);
	}

	Vec3 WayPointHandler::GetPosition() const
	{
		return Vec3(m_waypoint->x, m_waypoint->y, m_waypoint->z);
	}

	void WayPointHandler::SetPosition(const Vec3& pos)
	{
		m_waypoint->x = pos.x;
		m_waypoint->y = pos.y;
		m_waypoint->z = pos.z;
	}

	std::string WayPointHandler::GetName() const
	{
		return m_waypoint->name;
	}

	int WayPointHandler::GetType() const
	{
		return m_waypoint->type;
	}

	int WayPointHandler::GetSequence() const
	{
		return m_waypoint->sequence;
	}

	int WayPointHandler::GetNumber() const
	{
		return m_waypoint->number;
	}

	float WayPointHandler::GetRadius1() const
	{
		return m_waypoint->radius1;
	}

	void WayPointHandler::SetRadius1(float radius)
	{
		m_waypoint->radius1 = radius;
	}

	float WayPointHandler::GetRadius2() const
	{
		return m_waypoint->radius2;
	}

	void WayPointHandler::SetRadius2(float radius)
	{
		m_waypoint->radius2 = radius;
	}

	Vec3 WayPointHandler::GetPathPosition(float alpha, bool loop) const
	{
		return Vec3(CalculateWayPointTransform(m_waypoint->name, alpha, loop).Position);
	}

	Rotation WayPointHandler::GetPathRotation(float alpha, bool loop) const
	{
		return Rotation(CalculateWayPointTransform(m_waypoint->name, alpha, loop).Orientation);
	}

	void WayPointHandler::Preview(sol::optional<Vector4> color) const
	{
		constexpr auto DEFAULT_COLOR = Vector4(1.0f, 0.65f, 0.0f, 1.0f); // Orange
		constexpr auto TARGET_RADIUS = 128.0f;
		constexpr auto NUM_SEGMENTS = 32;
		
		Vector4 previewColor = color.value_or(DEFAULT_COLOR);
		Color drawColor(previewColor.x, previewColor.y, previewColor.z, previewColor.w);
		
		Vector3 centerPos(m_waypoint->x, m_waypoint->y, m_waypoint->z);
		WayPointType wpType = static_cast<WayPointType>(m_waypoint->type);
		
		// Create rotation matrix from waypoint's rotations
		Matrix rotationMatrix = Matrix::CreateRotationX(m_waypoint->rotationX * (float)RADIAN) *
								Matrix::CreateRotationY(m_waypoint->rotationY * (float)RADIAN) *
								Matrix::CreateRotationZ(m_waypoint->roll * (float)RADIAN);
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
				DrawDebugSphere(centerPos, m_waypoint->radius1, drawColor, RendererDebugPage::CollisionStats, true);
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
					
					Vector3 local1(std::cos(angle1) * m_waypoint->radius1, 0.0f, std::sin(angle1) * m_waypoint->radius2);
					Vector3 local2(std::cos(angle2) * m_waypoint->radius1, 0.0f, std::sin(angle2) * m_waypoint->radius2);
					
					Vector3 world1 = Vector3::Transform(local1, rotationMatrix) + centerPos;
					Vector3 world2 = Vector3::Transform(local2, rotationMatrix) + centerPos;
					
					DrawDebugLine(world1, world2, drawColor, RendererDebugPage::CollisionStats);
				}
				break;
			}
			
			case WayPointType::Square:
			{
				// Draw square as four connected lines
				float r = m_waypoint->radius1;
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
				float r1 = m_waypoint->radius1;
				float r2 = m_waypoint->radius2;
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
					if (wp.name == m_waypoint->name)
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
					
					Vector3 pos1 = CalculateWayPointTransform(m_waypoint->name, alpha1, false).Position.ToVector3();
					Vector3 pos2 = CalculateWayPointTransform(m_waypoint->name, alpha2, false).Position.ToVector3();
					
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

	/// Get a waypoint by name.
	// @function GetWayPointByName
	// @tparam string name The waypoint name.
	// @treturn WayPoint The waypoint with the given name, or nil if not found.
	std::unique_ptr<WayPointHandler> GetWayPointByNameAndNumber(const std::string& name)
	{
		// Find waypoint by name
		for (auto& wp : WayPoints)
		{
			if (wp.name == name)
			{
				return std::make_unique<WayPointHandler>(name);
			}
		}
		
		return nullptr;
	}

	std::unique_ptr<WayPointHandler> GetWayPointBySequenceAndNumber(const std::string& name)
	{
		// Find waypoint by name
		for (auto& wp : WayPoints)
		{
			if (wp.name == name)
			{
				return std::make_unique<WayPointHandler>(name);
			}
		}

		return nullptr;
	}

	sol::table GetWayPointsByName(sol::this_state s, int type)
	{
		sol::state_view lua(s);
		sol::table result = lua.create_table();

		int index = 1;
		for (auto& wp : WayPoints)
		{
			if (wp.type == type)
			{
				result[index++] = std::make_unique<WayPointHandler>(wp.name);
			}
		}

		return result;
	}

	sol::table GetWayPointsBySequence(sol::this_state s, int type)
	{
		sol::state_view lua(s);
		sol::table result = lua.create_table();

		int index = 1;
		for (auto& wp : WayPoints)
		{
			if (wp.type == type)
			{
				result[index++] = std::make_unique<WayPointHandler>(wp.name);
			}
		}

		return result;
	}

	/// Get all waypoints with a specific type.
	// @function GetWayPointsByType
	// @tparam int type The waypoint type (use WayPointType enum).
	// @treturn table Table of waypoints with the given type.
	sol::table GetWayPointsByType(sol::this_state s, int type)
	{
		sol::state_view lua(s);
		sol::table result = lua.create_table();
		
		int index = 1;
		for (auto& wp : WayPoints)
		{
			if (wp.type == type)
			{
				result[index++] = std::make_unique<WayPointHandler>(wp.name);
			}
		}
		
		return result;
	}

	void Register(sol::state* state, sol::table& parent)
	{
		auto wpTable = sol::table(state->lua_state(), sol::create);
		parent.set(ScriptReserved_WayPoint, wpTable);

		WayPointHandler::Register(wpTable);

		/// Get a waypoint by name.
		// @function WayPoint.GetWayPointByName
		// @tparam string name The waypoint name.
		// @treturn WayPoint The waypoint with the given name, or nil if not found.
		wpTable.set_function(ScriptReserved_GetWayPointByName, GetWayPointByName);

		/// Get all waypoints with a specific type.
		// @function WayPoint.GetWayPointsByType
		// @tparam int type The waypoint type (use WayPointType enum).
		// @treturn table Table of waypoints with the given type.
		wpTable.set_function(ScriptReserved_GetWayPointsByType, GetWayPointsByType);

		auto handler = LuaHandler(state);
		handler.MakeReadOnlyTable(wpTable, ScriptReserved_WayPointType, WAYPOINT_TYPES);
	}
}
