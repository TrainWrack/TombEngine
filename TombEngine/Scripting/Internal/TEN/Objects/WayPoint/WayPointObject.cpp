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

// Catmull-Rom spline interpolation for waypoint paths
Pose WayPointObject::CalculateWayPointTransform(int sequence, float alpha, bool loop) const
{
	constexpr auto BLEND_RANGE = 0.1f;
	constexpr auto BLEND_START = BLEND_RANGE;
	constexpr auto BLEND_END   = 1.0f - BLEND_RANGE;

	alpha = std::clamp(alpha, 0.0f, 1.0f);

	if (sequence < 0 || sequence >= MAX_SPOTCAMS)
	{
		TENLog("Invalid waypoint sequence number provided for path calculation.", LogLevel::Warning);
		return Pose::Zero;
	}

	// Retrieve waypoint count in sequence
	int waypointCount = CameraCnt[SpotCamRemap[sequence]];
	if (waypointCount < 2)
	{
		TENLog("Not enough waypoints in sequence to calculate the path.", LogLevel::Warning);
		return Pose::Zero;
	}

	// Find first ID for sequence
	int firstSeqID = 0;
	for (int i = 0; i < SpotCamRemap[sequence]; i++)
		firstSeqID += CameraCnt[i];

	// Determine number of spline points and spline position
	int splinePoints = waypointCount + 2;
	int splineAlpha = int(alpha * (float)USHRT_MAX);

	// Extract waypoint positions and rolls into separate vectors for interpolation
	std::vector<int> xPos, yPos, zPos, rolls;
	for (int i = -1; i < (waypointCount + 1); i++)
	{
		int seqID = std::clamp(firstSeqID + i, firstSeqID, (firstSeqID + waypointCount) - 1);

		xPos.push_back(SpotCam[seqID].x);
		yPos.push_back(SpotCam[seqID].y);
		zPos.push_back(SpotCam[seqID].z);
		rolls.push_back(SpotCam[seqID].roll);
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

Vec3 WayPointObject::GetPathPosition(float alpha, bool loop) const
{
	return Vec3(CalculateWayPointTransform(m_waypoint.sequence, alpha, loop).Position);
}

Rotation WayPointObject::GetPathRotation(float alpha, bool loop) const
{
	return Rotation(CalculateWayPointTransform(m_waypoint.sequence, alpha, loop).Orientation);
}
