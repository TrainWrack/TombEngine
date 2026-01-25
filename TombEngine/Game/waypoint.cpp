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

// Helper function to check if a waypoint type is singular (non-path)
static bool IsSingularType(WayPointType type)
{
	return type == WayPointType::Point || 
	       type == WayPointType::Circle || 
	       type == WayPointType::Ellipse || 
	       type == WayPointType::Square || 
	       type == WayPointType::Rectangle;
}

// Path interpolation for waypoint paths (Linear and Bezier)
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

	// Check if this is a singular type waypoint (Point, Circle, etc)
	WayPointType waypointType = static_cast<WayPointType>(pathWaypoints[0]->type);
	if (IsSingularType(waypointType))
	{
		const WAYPOINT* wp = pathWaypoints[0];
		Vector3 centerPosition(wp->x, wp->y, wp->z);
		
		// Create rotation matrix from waypoint's rotations
		// Rotations are applied in order: X, Y, Z (Roll)
		Matrix rotationMatrix = Matrix::CreateRotationX(wp->rotationX * (float)RADIAN) *
		                        Matrix::CreateRotationY(wp->rotationY * (float)RADIAN) *
		                        Matrix::CreateRotationZ(wp->roll * (float)RADIAN);
		
		Vector3 localPosition = Vector3::Zero;
		
		// Calculate position on the shape perimeter based on type and alpha
		// Starting at 3 o'clock (local x = radius, z = 0) and rotating clockwise
		switch (waypointType)
		{
			case WayPointType::Point:
				// Point has no shape, return center position
				localPosition = Vector3::Zero;
				break;
				
			case WayPointType::Circle:
			{
				// Circle with radius1
				// Alpha 0.0 = 3 o'clock, rotating clockwise
				float angle = alpha * 2.0f * (float)PI;
				localPosition.x = std::cos(angle) * wp->radius1;
				localPosition.y = 0.0f;
				localPosition.z = std::sin(angle) * wp->radius1;
				break;
			}
			
			case WayPointType::Ellipse:
			{
				// Ellipse with radius1 (x-axis) and radius2 (z-axis)
				float angle = alpha * 2.0f * (float)PI;
				localPosition.x = std::cos(angle) * wp->radius1;
				localPosition.y = 0.0f;
				localPosition.z = std::sin(angle) * wp->radius2;
				break;
			}
			
			case WayPointType::Square:
			{
				// Square with radius1 (half-width/height)
				// Divide perimeter into 4 equal segments
				float r = wp->radius1;
				float segment = alpha * 4.0f;
				int side = (int)segment;
				float t = segment - side;
				
				switch (side)
				{
					case 0: // Right side (3 to 6 o'clock)
						localPosition = Vector3(r, 0.0f, Lerp(-r, r, t));
						break;
					case 1: // Top side (6 to 9 o'clock)
						localPosition = Vector3(Lerp(r, -r, t), 0.0f, r);
						break;
					case 2: // Left side (9 to 12 o'clock)
						localPosition = Vector3(-r, 0.0f, Lerp(r, -r, t));
						break;
					default: // Bottom side (12 to 3 o'clock)
						localPosition = Vector3(Lerp(-r, r, t), 0.0f, -r);
						break;
				}
				break;
			}
			
			case WayPointType::Rectangle:
			{
				// Rectangle with radius1 (half-width x) and radius2 (half-height z)
				float r1 = wp->radius1;
				float r2 = wp->radius2;
				
				// Calculate perimeter segments weighted by side length
				float perimeter = 2.0f * (r1 + r2);
				float distance = alpha * perimeter;
				
				if (distance < r2)
				{
					// Right side (3 to 6 o'clock)
					localPosition = Vector3(r1, 0.0f, Lerp(-r2, r2, distance / r2));
				}
				else if (distance < r2 + r1)
				{
					// Top side (6 to 9 o'clock)
					float t = (distance - r2) / r1;
					localPosition = Vector3(Lerp(r1, -r1, t), 0.0f, r2);
				}
				else if (distance < 2.0f * r2 + r1)
				{
					// Left side (9 to 12 o'clock)
					float t = (distance - r2 - r1) / r2;
					localPosition = Vector3(-r1, 0.0f, Lerp(r2, -r2, t));
				}
				else
				{
					// Bottom side (12 to 3 o'clock)
					float t = (distance - 2.0f * r2 - r1) / r1;
					localPosition = Vector3(Lerp(-r1, r1, t), 0.0f, -r2);
				}
				break;
			}
		}
		
		// Transform local position by rotation matrix and add to center
		Vector3 worldPosition = Vector3::Transform(localPosition, rotationMatrix) + centerPosition;
		
		// Create orientation from waypoint's rotations
		EulerAngles orientation;
		orientation.x = wp->rotationX * (float)RADIAN;
		orientation.y = wp->rotationY * (float)RADIAN;
		orientation.z = wp->roll * (float)RADIAN;
		
		return Pose(worldPosition, orientation);
	}

	// For path types (Linear, Bezier), we need at least 2 points
	if (pathWaypoints.size() < 2)
	{
		TENLog("Not enough waypoints in path to calculate transform for: " + name, LogLevel::Warning);
		return Pose::Zero;
	}

	// Sort waypoints by number
	std::sort(pathWaypoints.begin(), pathWaypoints.end(), 
		[](const WAYPOINT* a, const WAYPOINT* b) { return a->number < b->number; });

	int waypointCount = pathWaypoints.size();
	
	// Handle Linear path type
	if (waypointType == WayPointType::Linear)
	{
		// Linear interpolation between waypoints
		float segmentLength = 1.0f / (waypointCount - 1);
		int segmentIndex = (int)(alpha / segmentLength);
		
		// Handle loop blending
		if (loop && (alpha < BLEND_START || alpha >= BLEND_END))
		{
			float blendFactor = (alpha < BLEND_START) ? 
				(0.5f + ((alpha / BLEND_RANGE) * 0.5f)) : 
				(((alpha - BLEND_END) / BLEND_RANGE) * 0.5f);
			
			// Blend between last and first waypoints
			const WAYPOINT* wp1 = pathWaypoints[waypointCount - 1];
			const WAYPOINT* wp2 = pathWaypoints[0];
			
			Vector3 pos1(wp1->x, wp1->y, wp1->z);
			Vector3 pos2(wp2->x, wp2->y, wp2->z);
			Vector3 position = Vector3::Lerp(pos1, pos2, blendFactor);
			
			// Interpolate rotations
			EulerAngles orient1(wp1->rotationX * (float)RADIAN, wp1->rotationY * (float)RADIAN, wp1->roll * (float)RADIAN);
			EulerAngles orient2(wp2->rotationX * (float)RADIAN, wp2->rotationY * (float)RADIAN, wp2->roll * (float)RADIAN);
			
			EulerAngles orientation;
			orientation.x = Lerp(orient1.x, orient2.x, blendFactor);
			orientation.y = Lerp(orient1.y, orient2.y, blendFactor);
			orientation.z = Lerp(orient1.z, orient2.z, blendFactor);
			
			return Pose(position, orientation);
		}
		
		// Clamp segment index
		segmentIndex = std::clamp(segmentIndex, 0, waypointCount - 2);
		
		// Calculate local alpha within the segment
		float localAlpha = (alpha - (segmentIndex * segmentLength)) / segmentLength;
		localAlpha = std::clamp(localAlpha, 0.0f, 1.0f);
		
		const WAYPOINT* wp1 = pathWaypoints[segmentIndex];
		const WAYPOINT* wp2 = pathWaypoints[segmentIndex + 1];
		
		// Linear interpolation of position
		Vector3 pos1(wp1->x, wp1->y, wp1->z);
		Vector3 pos2(wp2->x, wp2->y, wp2->z);
		Vector3 position = Vector3::Lerp(pos1, pos2, localAlpha);
		
		// Linear interpolation of rotation
		EulerAngles orient1(wp1->rotationX * (float)RADIAN, wp1->rotationY * (float)RADIAN, wp1->roll * (float)RADIAN);
		EulerAngles orient2(wp2->rotationX * (float)RADIAN, wp2->rotationY * (float)RADIAN, wp2->roll * (float)RADIAN);
		
		EulerAngles orientation;
		orientation.x = Lerp(orient1.x, orient2.x, localAlpha);
		orientation.y = Lerp(orient1.y, orient2.y, localAlpha);
		orientation.z = Lerp(orient1.z, orient2.z, localAlpha);
		
		return Pose(position, orientation);
	}
	
	// Handle Bezier path type (using Catmull-Rom spline for smooth curves)
	if (waypointType == WayPointType::Bezier)
	{
		int splinePoints = waypointCount + 2;
		
		// Extract waypoint positions and rotations for interpolation
		std::vector<int> xPos, yPos, zPos;
		std::vector<float> rotX, rotY, rotZ;
		
		for (int i = -1; i < (waypointCount + 1); i++)
		{
			int idx = std::clamp(i, 0, waypointCount - 1);
			const WAYPOINT* wp = pathWaypoints[idx];

			xPos.push_back(wp->x);
			yPos.push_back(wp->y);
			zPos.push_back(wp->z);
			rotX.push_back(wp->rotationX);
			rotY.push_back(wp->rotationY);
			rotZ.push_back(wp->roll);
		}

		// Compute spline interpolation of waypoint parameters
		auto getInterpolatedPoint = [&](float t, std::vector<int>& x, std::vector<int>& y, std::vector<int>& z) 
		{
			int tAlpha = int(t * (float)USHRT_MAX);
			return Vector3(Spline(tAlpha, x.data(), splinePoints),
						   Spline(tAlpha, y.data(), splinePoints),
						   Spline(tAlpha, z.data(), splinePoints));
		};
		
		auto getInterpolatedRotation = [&](float t, std::vector<float>& rot)
		{
			// Linear interpolation for rotations in Bezier mode
			// Note: rot vector has padding (first and last elements duplicated for spline continuity)
			float pos = t * (waypointCount - 1);
			int idx = (int)pos;
			idx = std::clamp(idx, 0, waypointCount - 2);
			float localT = pos - idx;
			// Index offset by 1 because vector has padding at start
			return Lerp(rot[idx + 1], rot[idx + 2], localT);
		};

		auto position = Vector3::Zero;
		EulerAngles orientation;

		// If loop is enabled and alpha is at sequence start or end, blend between last and first waypoints
		if (loop && (alpha < BLEND_START || alpha >= BLEND_END))
		{
			float blendFactor = (alpha < BLEND_START) ? 
				(0.5f + ((alpha / BLEND_RANGE) * 0.5f)) : 
				(((alpha - BLEND_END) / BLEND_RANGE) * 0.5f);

			position = Vector3::Lerp(
				getInterpolatedPoint(BLEND_END, xPos, yPos, zPos), 
				getInterpolatedPoint(BLEND_START, xPos, yPos, zPos), 
				blendFactor);
			
			orientation.x = Lerp(getInterpolatedRotation(BLEND_END, rotX), getInterpolatedRotation(BLEND_START, rotX), blendFactor) * (float)RADIAN;
			orientation.y = Lerp(getInterpolatedRotation(BLEND_END, rotY), getInterpolatedRotation(BLEND_START, rotY), blendFactor) * (float)RADIAN;
			orientation.z = Lerp(getInterpolatedRotation(BLEND_END, rotZ), getInterpolatedRotation(BLEND_START, rotZ), blendFactor) * (float)RADIAN;
		}
		else
		{
			position = getInterpolatedPoint(alpha, xPos, yPos, zPos);
			orientation.x = getInterpolatedRotation(alpha, rotX) * (float)RADIAN;
			orientation.y = getInterpolatedRotation(alpha, rotY) * (float)RADIAN;
			orientation.z = getInterpolatedRotation(alpha, rotZ) * (float)RADIAN;
		}

		return Pose(position, orientation);
	}

	// Default fallback
	TENLog("Unknown waypoint type for path: " + name, LogLevel::Warning);
	return Pose::Zero;
}
