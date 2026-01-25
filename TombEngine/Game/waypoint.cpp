#include "framework.h"
#include "waypoint.h"
#include "Game/spotcam.h"
#include "Specific/logging.h"

// Conversion constant: degrees to angle units (used in roll calculations)
constexpr float DEGREES_TO_ANGLE_UNITS = 182.0444f;

std::vector<WAYPOINT> WayPoints;

void ClearWayPoints()
{
	WayPoints.clear();
}

// Catmull-Rom spline interpolation for waypoint paths
Pose CalculateWayPointTransform(const std::string& name, float alpha, bool loop)
{
	constexpr auto BLEND_RANGE = 0.1f;
	constexpr auto BLEND_START = BLEND_RANGE;
	constexpr auto BLEND_END   = 1.0f - BLEND_RANGE;

	alpha = std::clamp(alpha, 0.0f, 1.0f);

	// Find all waypoints with the given name
	std::vector<const WAYPOINT*> pathWaypoints;
	for (const auto& wp : WayPoints)
	{
		if (wp.name == name)
			pathWaypoints.push_back(&wp);
	}

	if (pathWaypoints.empty())
	{
		TENLog("No waypoints found with name: " + name, LogLevel::Warning);
		return Pose::Zero;
	}

	if (pathWaypoints.size() < 2)
	{
		TENLog("Not enough waypoints in path to calculate transform for: " + name, LogLevel::Warning);
		return Pose::Zero;
	}

	// Sort waypoints by number
	std::sort(pathWaypoints.begin(), pathWaypoints.end(), 
		[](const WAYPOINT* a, const WAYPOINT* b) { return a->number < b->number; });

	int waypointCount = pathWaypoints.size();
	int splinePoints = waypointCount + 2;
	int splineAlpha = int(alpha * (float)USHRT_MAX);

	// Extract waypoint positions and rolls into separate vectors for interpolation
	std::vector<int> xPos, yPos, zPos, rolls;
	for (int i = -1; i < (waypointCount + 1); i++)
	{
		int idx = std::clamp(i, 0, waypointCount - 1);
		const WAYPOINT* wp = pathWaypoints[idx];

		xPos.push_back(wp->x);
		yPos.push_back(wp->y);
		zPos.push_back(wp->z);
		rolls.push_back((int)(wp->roll * DEGREES_TO_ANGLE_UNITS));
	}

	// Compute spline interpolation of waypoint parameters
	auto getInterpolatedPoint = [&](float t, std::vector<int>& x, std::vector<int>& y, std::vector<int>& z) 
	{
		int tAlpha = int(t * (float)USHRT_MAX);
		return Vector3(Spline(tAlpha, x.data(), splinePoints),
					   Spline(tAlpha, y.data(), splinePoints),
					   Spline(tAlpha, z.data(), splinePoints));
	};

	auto getInterpolatedRoll = [&](float t)
	{
		int tAlpha = int(t * (float)USHRT_MAX);
		return Spline(tAlpha, rolls.data(), splinePoints);
	};

	auto position = Vector3::Zero;
	short orientZ = 0;

	// If loop is enabled and alpha is at sequence start or end, blend between last and first waypoints
	if (loop && (alpha < BLEND_START || alpha >= BLEND_END))
	{
		float blendFactor = (alpha < BLEND_START) ? (0.5f + ((alpha / BLEND_RANGE) * 0.5f)) : (((alpha - BLEND_END) / BLEND_START) * 0.5f);

		position = Vector3::Lerp(getInterpolatedPoint(BLEND_END, xPos, yPos, zPos), getInterpolatedPoint(BLEND_START, xPos, yPos, zPos), blendFactor);
		orientZ = Lerp(getInterpolatedRoll(BLEND_END), getInterpolatedRoll(BLEND_START), blendFactor);
	}
	else
	{
		position = getInterpolatedPoint(alpha, xPos, yPos, zPos);
		orientZ = getInterpolatedRoll(alpha);
	}

	// Calculate direction from current position to next position for orientation
	// For waypoints, we compute the forward direction based on the path tangent
	float deltaAlpha = 0.01f; // Small delta for tangent calculation
	float nextAlpha = std::min(alpha + deltaAlpha, 1.0f);
	auto nextPosition = getInterpolatedPoint(nextAlpha, xPos, yPos, zPos);
	auto direction = nextPosition - position;
	
	if (direction.LengthSquared() < 0.0001f)
	{
		// If positions are too close, use previous point
		float prevAlpha = std::max(alpha - deltaAlpha, 0.0f);
		auto prevPosition = getInterpolatedPoint(prevAlpha, xPos, yPos, zPos);
		direction = position - prevPosition;
	}

	auto pose = Pose(position, EulerAngles(direction));
	pose.Orientation.z = orientZ;
	return pose;
}
