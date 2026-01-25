#pragma once

#include "Scripting/Internal/TEN/Objects/NamedBase.h"
#include "Math/Math.h"

struct SPOTCAM;

namespace sol
{
	class state;
}
class Vec3;
class Rotation;

class WayPointObject : public NamedBase<WayPointObject, SPOTCAM&>
{
public:
	using IdentifierType = std::reference_wrapper<SPOTCAM>;
	WayPointObject(SPOTCAM& ref);
	~WayPointObject() = default;

	WayPointObject& operator=(WayPointObject const& other) = delete;
	WayPointObject(WayPointObject const& other) = delete;

	static void Register(sol::table&);
	
	Vec3 GetPos() const;
	void SetPos(Vec3 const& pos);
	
	std::string GetName() const;
	void SetName(std::string const&);
	
	int GetType() const;
	void SetType(int type);
	
	int GetSequence() const;
	
	Vec3 GetPathPosition(float alpha, bool loop) const;
	Rotation GetPathRotation(float alpha, bool loop) const;

private:
	SPOTCAM& m_waypoint;
	
	// Helper function to calculate waypoint path transform
	Pose CalculateWayPointTransform(int sequence, float alpha, bool loop) const;
};
