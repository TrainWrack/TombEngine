#include "framework.h"
#include "Game/collision/PointCollision.h"

#include "Game/collision/collide_room.h"
#include "Game/collision/floordata.h"
#include "Game/items.h"
#include "Game/room.h"
#include "Math/Math.h"
#include "Specific/level.h"

using namespace TEN::Collision::Floordata;
using namespace TEN::Collision::Room;
using namespace TEN::Math;

namespace TEN::Collision
{
	PointCollisionData::PointCollisionData(const Vector3i& pos, int roomNumber) :
		Position(pos),
		RoomNumber(roomNumber)
	{
	}

	FloorInfo& PointCollisionData::GetSector()
	{
		if (SectorPtr != nullptr)
			return *SectorPtr;

		// Set current sector pointer.
		short probeRoomNumber = RoomNumber;
		SectorPtr = GetFloor(Position.x, Position.y, Position.z, &probeRoomNumber);

		return *SectorPtr;
	}

	FloorInfo& PointCollisionData::GetTopSector()
	{
		if (TopSectorPtr != nullptr)
			return *TopSectorPtr;

		// Set top sector pointer.
		auto* topSectorPtr = &GetSector();
		auto roomNumberAbove = topSectorPtr->GetRoomNumberAbove(Position.x, Position.y, Position.z);
		while (roomNumberAbove.has_value())
		{
			auto& room = g_Level.Rooms[roomNumberAbove.value_or(topSectorPtr->Room)];
			topSectorPtr = Room::GetSector(&room, Position.x - room.x, Position.z - room.z);

			roomNumberAbove = topSectorPtr->GetRoomNumberAbove(Position.x, Position.y, Position.z);
		}
		TopSectorPtr = topSectorPtr;

		return *TopSectorPtr;
	}

	FloorInfo& PointCollisionData::GetBottomSector()
	{
		if (BottomSectorPtr != nullptr)
			return *BottomSectorPtr;

		// Set bottom sector pointer.
		auto* bottomSectorPtr = &GetSector();
		auto roomNumberBelow = bottomSectorPtr->GetRoomNumberBelow(Position.x, Position.y, Position.z);
		while (roomNumberBelow.has_value())
		{
			auto& room = g_Level.Rooms[roomNumberBelow.value_or(bottomSectorPtr->Room)];
			bottomSectorPtr = Room::GetSector(&room, Position.x - room.x, Position.z - room.z);

			roomNumberBelow = bottomSectorPtr->GetRoomNumberBelow(Position.x, Position.y, Position.z);
		}
		BottomSectorPtr = bottomSectorPtr;

		return *BottomSectorPtr;
	}

	int PointCollisionData::GetFloorHeight()
	{
		if (FloorHeight.has_value())
			return *FloorHeight;

		// Set floor height.
		auto roomVector = RoomVector(GetSector().Room, Position.y);
		FloorHeight = Floordata::GetFloorHeight(roomVector, Position.x, Position.z).value_or(NO_HEIGHT);
		
		return *FloorHeight;
	}
	
	int PointCollisionData::GetCeilingHeight()
	{
		if (CeilingHeight.has_value())
			return *CeilingHeight;

		// Set ceiling height.
		auto roomVector = RoomVector(GetSector().Room, Position.y);
		CeilingHeight = Floordata::GetCeilingHeight(roomVector, Position.x, Position.z).value_or(NO_HEIGHT);
		
		return *CeilingHeight;
	}

	Vector3 PointCollisionData::GetFloorNormal()
	{
		if (FloorNormal.has_value())
			return *FloorNormal;

		// Set floor normal.
		if (GetFloorBridgeEntityID() != NO_ITEM)
		{
			// TODO: Get bridge normal.
			FloorNormal = -Vector3::UnitY;
		}
		else
		{
			auto floorTilt = GetBottomSector().GetSurfaceTilt(Position.x, Position.z, true);
			FloorNormal = GetSurfaceNormal(floorTilt, true);
		}

		return *FloorNormal;
	}

	Vector3 PointCollisionData::GetCeilingNormal()
	{
		if (CeilingNormal.has_value())
			return *CeilingNormal;

		// Set ceiling normal.
		if (GetCeilingBridgeEntityID() != NO_ITEM)
		{
			// TODO: Get bridge normal.
			CeilingNormal = Vector3::UnitY;
		}
		else
		{
			auto ceilingTilt = GetTopSector().GetSurfaceTilt(Position.x, Position.z, false);
			CeilingNormal = GetSurfaceNormal(ceilingTilt, false);
		}

		return *CeilingNormal;
	}

	int PointCollisionData::GetFloorBridgeEntityID()
	{
		if (FloorBridgeEntityID.has_value())
			return *FloorBridgeEntityID;

		// Set floor bridge entity ID.
		int floorHeight = GetFloorHeight();
		FloorBridgeEntityID = GetBottomSector().GetInsideBridgeItemNumber(Position.x, floorHeight, Position.z, true, false);;

		return *FloorBridgeEntityID;
	}
	
	int PointCollisionData::GetCeilingBridgeEntityID()
	{
		if (CeilingBridgeEntityID.has_value())
			return *CeilingBridgeEntityID;

		// Set ceiling bridge entity ID.
		int ceilingHeight = GetCeilingHeight();
		CeilingBridgeEntityID = GetTopSector().GetInsideBridgeItemNumber(Position.x, ceilingHeight, Position.z, false, true);;

		return *CeilingBridgeEntityID;
	}

	int PointCollisionData::GetWaterSurfaceHeight()
	{
		if (WaterSurfaceHeight.has_value())
			return *WaterSurfaceHeight;

		// Set water surface height.
		WaterSurfaceHeight = GetWaterSurface(Position.x, Position.y, Position.z, RoomNumber);

		return *WaterSurfaceHeight;
	}

	int PointCollisionData::GetWaterTopHeight()
	{
		if (WaterTopHeight.has_value())
			return *WaterTopHeight;

		// Set water top height.
		WaterTopHeight = GetWaterHeight(Position.x, Position.y, Position.z, RoomNumber);

		return *WaterTopHeight;
	}

	int PointCollisionData::GetWaterBottomHeight()
	{
		if (WaterBottomHeight.has_value())
			return *WaterBottomHeight;

		// Set water bottom height.
		WaterBottomHeight = GetWaterDepth(Position.x, Position.y, Position.z, RoomNumber);

		return *WaterBottomHeight;
	}

	bool PointCollisionData::IsWall()
	{
		return (GetFloorHeight() == NO_HEIGHT || GetCeilingHeight() == NO_HEIGHT);
	}

	bool PointCollisionData::IsSlipperyFloor(short slopeAngleMin)
	{
		// Get floor slope angle.
		auto floorNormal = GetFloorNormal();
		auto slopeAngle = Geometry::GetSurfaceSlopeAngle(floorNormal);

		// TODO: Slippery bridges.
		return (GetFloorBridgeEntityID() == NO_ITEM && abs(slopeAngle) >= slopeAngleMin);
	}

	bool PointCollisionData::IsSlipperyCeiling(short slopeAngleMin)
	{
		// Get ceiling slope angle.
		auto ceilingNormal = GetCeilingNormal();
		auto slopeAngle = Geometry::GetSurfaceSlopeAngle(ceilingNormal, -Vector3::UnitY);

		// TODO: Slippery bridges.
		return (GetCeilingBridgeEntityID() == NO_ITEM && abs(slopeAngle) >= slopeAngleMin);
	}

	bool PointCollisionData::IsDiagonalStep()
	{
		return GetBottomSector().IsSurfaceDiagonalStep(true);
	}

	bool PointCollisionData::HasDiagonalSplit()
	{
		constexpr auto DIAGONAL_SPLIT_0 = 45.0f * RADIAN;
		constexpr auto DIAGONAL_SPLIT_1 = 135.0f * RADIAN;

		float splitAngle = GetBottomSector().FloorCollision.SplitAngle;
		return (splitAngle == DIAGONAL_SPLIT_0 || splitAngle == DIAGONAL_SPLIT_1);
	}

	bool PointCollisionData::HasFlippedDiagonalSplit()
	{
		constexpr auto DIAGONAL_SPLIT_0 = 45.0f * RADIAN;

		float splitAngle = GetBottomSector().FloorCollision.SplitAngle;
		return (HasDiagonalSplit() && splitAngle != DIAGONAL_SPLIT_0);
	}

	bool PointCollisionData::HasEnvironmentFlag(RoomEnvFlags envFlag)
	{
		const auto& room = g_Level.Rooms[RoomNumber];
		return ((room.flags & envFlag) == envFlag);
	}

	PointCollisionData GetPointCollision(const Vector3i& pos, int roomNumber)
	{
		// HACK: This function takes arguments for a *current* position and room number.
		// However, since some calls to the previous implementation (GetCollision()) had *vertically projected*
		// positions passed to it, for now the room number must be corrected to account for such cases.
		// They are primarily found in camera.cpp.
		short correctedRoomNumber = roomNumber;
		GetFloor(pos.x, pos.y, pos.z, &correctedRoomNumber);

		return PointCollisionData(pos, correctedRoomNumber);
	}

	PointCollisionData GetPointCollision(const Vector3i& pos, int roomNumber, const Vector3& dir, float dist)
	{
		// Get "location".
		short tempRoomNumber = roomNumber;
		const auto& sector = *GetFloor(pos.x, pos.y, pos.z, &tempRoomNumber);
		auto location = RoomVector(sector.Room, pos.y);

		// Calculate probe position.
		auto probePos = Geometry::TranslatePoint(pos, dir, dist);

		// Get probe position's room number.
		short probeRoomNumber = GetRoom(location, pos.x, probePos.y, pos.z).RoomNumber;
		GetFloor(probePos.x, probePos.y, probePos.z, &probeRoomNumber);

		return PointCollisionData(probePos, probeRoomNumber);
	}

	PointCollisionData GetPointCollision(const Vector3i& pos, int roomNumber, short headingAngle, float forward, float down, float right)
	{
		// Get "location".
		short tempRoomNumber = roomNumber;
		const auto& sector = *GetFloor(pos.x, pos.y, pos.z, &tempRoomNumber);
		auto location = RoomVector(sector.Room, pos.y);

		// Calculate probe position.
		auto probePos = Geometry::TranslatePoint(pos, headingAngle, forward, down, right);

		// Get probe position's room number.
		short probeRoomNumber = GetRoom(location, pos.x, probePos.y, pos.z).RoomNumber;
		GetFloor(probePos.x, probePos.y, probePos.z, &probeRoomNumber);

		return PointCollisionData(probePos, probeRoomNumber);
	}

	PointCollisionData GetPointCollision(const ItemInfo& item)
	{
		return PointCollisionData(item.Pose.Position, item.RoomNumber);
	}

	// TODO: Find cleaner solution. Constructing a "location" on the spot for the player
	// can result in a stumble when climbing onto thin platforms. -- Sezz 2022.06.14
	static RoomVector GetEntityLocation(const ItemInfo& item)
	{
		if (item.IsLara())
			return item.Location;

		short tempRoomNumber = item.RoomNumber;
		const auto& sector = *GetFloor(item.Pose.Position.x, item.Pose.Position.y, item.Pose.Position.z, &tempRoomNumber);

		return RoomVector(sector.Room, item.Pose.Position.y);
	}

	PointCollisionData GetPointCollision(const ItemInfo& item, const Vector3& dir, float dist)
	{
		// Get "location".
		auto location = GetEntityLocation(item);

		// Calculate probe position.
		auto probePos = Geometry::TranslatePoint(item.Pose.Position, dir, dist);

		// Get probe position's room number.
		short probeRoomNumber = GetRoom(location, item.Pose.Position.x, probePos.y, item.Pose.Position.z).RoomNumber;
		GetFloor(probePos.x, probePos.y, probePos.z, &probeRoomNumber);

		return PointCollisionData(probePos, probeRoomNumber);
	}

	PointCollisionData GetPointCollision(const ItemInfo& item, short headingAngle, float forward, float down, float right)
	{
		// Get "location".
		auto location = GetEntityLocation(item);

		// Calculate probe position.
		auto probePos = Geometry::TranslatePoint(item.Pose.Position, headingAngle, forward, down, right);

		// Get probe position's room number.
		short probeRoomNumber = GetRoom(location, item.Pose.Position.x, probePos.y, item.Pose.Position.z).RoomNumber;
		GetFloor(probePos.x, probePos.y, probePos.z, &probeRoomNumber);

		return PointCollisionData(probePos, probeRoomNumber);
	}
}
