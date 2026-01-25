#pragma once
#include <string>
#include <vector>
#include "Math/Math.h"

constexpr auto MAX_WAYPOINTS = 1024;

class Pose;

struct WAYPOINT
{
	int x;
	int y;
	int z;
	int roomNumber;
	float rotationX;
	float rotationY;
	float roll;
	unsigned short number;
	int type;
	float radius1;
	float radius2;
	std::string name;
	std::string luaName;
};

extern std::vector<WAYPOINT> WayPoints;

void ClearWayPoints();
Pose CalculateWayPointTransform(const std::string& name, float alpha, bool loop);
