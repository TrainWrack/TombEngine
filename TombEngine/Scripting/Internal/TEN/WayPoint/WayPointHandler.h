#pragma once

#include <string>
#include <optional>
#include "Math/Math.h"

struct WAYPOINT;

namespace sol
{
	class state;
	class table;
}

class Vec3;
class Rotation;

namespace TEN::Scripting::WayPoint
{
	/// Represents a waypoint in the game world for navigation and path traversal.
	// @tenclass WayPoint.WayPoint
	// @pragma nostrip

	class WayPointHandler
	{
	public:
		static void Register(sol::table& parent);

	private:
		WAYPOINT* m_waypoint;

	public:
		// Constructors
		WayPointHandler() = delete;
		WayPointHandler(const std::string& name);
		
		// Getters
		Vec3 GetPosition() const;
		void SetPosition(const Vec3& pos);
		
		std::string GetName() const;
		void SetName(const std::string& name);
		
		int GetType() const;
		void SetType(int type);
		
		int GetNumber() const;
		void SetNumber(int number);
		
		float GetRadius1() const;
		void SetRadius1(float radius);
		
		float GetRadius2() const;
		void SetRadius2(float radius);
		
		Vec3 GetPathPosition(float alpha, bool loop) const;
		Rotation GetPathRotation(float alpha, bool loop) const;
		
		void Preview(sol::optional<Vector4> color) const;
	};

	// Static functions to get waypoints
	std::unique_ptr<WayPointHandler> GetWayPointByName(const std::string& name);
	sol::table GetWayPointsByType(sol::this_state s, int type);

	void Register(sol::state* state, sol::table& parent);
}
