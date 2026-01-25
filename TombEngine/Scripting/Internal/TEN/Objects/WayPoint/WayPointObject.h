#pragma once

#include "Scripting/Internal/TEN/Objects/NamedBase.h"
#include "Math/Math.h"

struct WAYPOINT;

namespace sol
{
	class state;
}
class Vec3;
class Rotation;

class WayPointObject : public NamedBase<WayPointObject, WAYPOINT&>
{
public:
	using IdentifierType = std::reference_wrapper<WAYPOINT>;
	WayPointObject(WAYPOINT& ref);
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
	
	int GetNumber() const;
	void SetNumber(int number);
	
	float GetRadius1() const;
	void SetRadius1(float radius);
	
	float GetRadius2() const;
	void SetRadius2(float radius);
	
	Vec3 GetPathPosition(float alpha, bool loop) const;
	Rotation GetPathRotation(float alpha, bool loop) const;

private:
	WAYPOINT& m_waypoint;
};
