#pragma once

#include "Game/waypoint.h"
#include <unordered_map>
#include <string>

namespace TEN::Scripting
{
	/// Constants for waypoint types.
	// To be used with @{Objects.WayPoint.GetType} and @{Objects.WayPoint.SetType} functions.
	// @enum Objects.WayPointType
	// @pragma nostrip

	static const auto WAYPOINT_TYPES = std::unordered_map<std::string, WayPointType>
	{
		/// Single point, no radius. Only can have rotation.
		// @mem POINT
		{ "POINT", WayPointType::Point },

		/// Single point with radius1. Can have rotation, can be rotated on all 3 axes.
		// @mem CIRCLE
		{ "CIRCLE", WayPointType::Circle },

		/// Single point with two radii. Can have rotation, can be rotated on all 3 axes.
		// @mem ELLIPSE
		{ "ELLIPSE", WayPointType::Ellipse },

		/// Single point with radius (rendered as square). Can be rotated on all 3 axes.
		// @mem SQUARE
		{ "SQUARE", WayPointType::Square },

		/// Single point with two radii (rendered as rectangle). Can be rotated on all 3 axes.
		// @mem RECTANGLE
		{ "RECTANGLE", WayPointType::Rectangle },

		/// Multi-point linear path, each point on the path can have a rotation.
		// @mem LINEAR
		{ "LINEAR", WayPointType::Linear },

		/// Multi-point bezier path, each point on the path can have a rotation.
		// @mem BEZIER
		{ "BEZIER", WayPointType::Bezier }
	};
}
