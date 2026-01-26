#pragma once
#include <string>
#include <vector>
#include "Math/Math.h"

constexpr auto MAX_WAYPOINTS = 1024;

class Pose;

enum class WayPointType
{
	Point = 0,      // Single point, no radius. Only can have rotation
	Circle = 1,     // Single point with radius1. Can have rotation, can be rotated on all 3 axes
	Ellipse = 2,    // Single point with two radii. Can have rotation, can be rotated on all 3 axes
	Square = 3,     // Single point with radius (rendered as square). Can be rotated on all 3 axes
	Rectangle = 4,  // Single point with two radii (rendered as rectangle). Can be rotated on all 3 axes
	Linear = 5,     // Multi-point linear path, each point on the path can have a rotation
	Bezier = 6      // Multi-point bezier path, each point on the path can have a rotation
};

struct WAYPOINT
{
	int x;
	int y;
	int z;
	int roomNumber;
	float rotationX;
	float rotationY;
	float roll;
	unsigned short sequence;
	unsigned short number;
	int type;
	float radius1;
	float radius2;
	std::string name;
};

extern std::vector<WAYPOINT> WayPoints;

void ClearWayPoints();
Pose CalculateWayPointTransform(const std::string& name, float alpha, bool loop);
