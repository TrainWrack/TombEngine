#pragma once
#include "Game/collision/floordata.h"
#include "Math/Math.h"
#include "Objects/game_object_ids.h"

enum RoomEnvFlags;
class FloorInfo;
struct ItemInfo;
struct MESH_INFO;
struct ROOM_INFO;

using namespace TEN::Collision::Floordata;
using namespace TEN::Math;

constexpr auto NO_LOWER_BOUND = -NO_HEIGHT;	// Used by coll->Setup.LowerFloorBound.
constexpr auto NO_UPPER_BOUND = NO_HEIGHT;	// Used by coll->Setup.UpperFloorBound.
constexpr auto COLLISION_CHECK_DISTANCE = BLOCK(8);

constexpr auto DEFAULT_ILLEGAL_FLOOR_SLOPE_ANGLE   = ANGLE(36.0f);
constexpr auto DEFAULT_ILLEGAL_CEILING_SLOPE_ANGLE = ANGLE(45.0f);

enum CollisionType
{
	CT_NONE		 = 0,
	CT_FRONT	 = (1 << 0),
	CT_LEFT		 = (1 << 1),
	CT_RIGHT	 = (1 << 2),
	CT_TOP		 = (1 << 3),
	CT_TOP_FRONT = (1 << 4),
	CT_CLAMP	 = (1 << 5)
};

enum class CollisionProbeMode
{
	Quadrants,
	FreeForward,
	FreeFlat
};

enum class CornerType
{
	None,
	Inner,
	Outer
};

struct CollisionPositionData
{
	int	  Floor		   = 0;
	int	  Ceiling	   = 0;
	int	  Bridge	   = 0;
	short SplitAngle   = 0;
	bool  FloorSlope   = false;
	bool  CeilingSlope = false;
	bool  DiagonalStep = false;

	bool HasDiagonalSplit()		   { return ((SplitAngle == SectorSurfaceData::SPLIT_ANGLE_0) || (SplitAngle == SectorSurfaceData::SPLIT_ANGLE_1)); }
	bool HasFlippedDiagonalSplit() { return (HasDiagonalSplit() && (SplitAngle != SectorSurfaceData::SPLIT_ANGLE_0)); }
};

struct CollisionSetupData
{
	CollisionProbeMode Mode = CollisionProbeMode::Quadrants; // Probe rotation mode
	int   Radius	   = 0;									 // Collision bounds horizontal size
	int   Height	   = 0;									 // Collision bounds vertical size
	short ForwardAngle = 0;									 // Forward angle direction

	int LowerFloorBound	  = 0; // Borderline floor step-up height 
	int UpperFloorBound	  = 0; // Borderline floor step-down height
	int LowerCeilingBound = 0; // Borderline ceiling step-up height
	int UpperCeilingBound = 0; // Borderline ceiling step-down height

	bool BlockFloorSlopeUp	  = false; // Treat steep slopes as walls
	bool BlockFloorSlopeDown  = false; // Treat steep slopes as pits
	bool BlockCeilingSlope	  = false; // Treat steep slopes on ceilings as walls
	bool BlockDeathFloorDown  = false; // Treat death sectors as pits
	bool BlockMonkeySwingEdge = false; // Treat non-monkey sectors as walls
	
	bool EnableObjectPush = false; // Can be pushed by objects
	bool EnableSpasm	  = false; // Convulse when pushed

	// Preserve previous parameters to restore later.
	Vector3i	   PrevPosition		= Vector3i::Zero;
	GAME_OBJECT_ID PrevAnimObjectID = ID_NO_OBJECT;
	int			   PrevAnimNumber	= 0;
	int			   PrevFrameNumber	= 0;
	int			   PrevState		= 0;
};

struct CollisionInfo
{
	CollisionSetupData Setup = {}; // In parameters

	CollisionPositionData Middle	  = {};
	CollisionPositionData MiddleLeft  = {};
	CollisionPositionData MiddleRight = {};
	CollisionPositionData Front		  = {};
	CollisionPositionData FrontLeft	  = {};
	CollisionPositionData FrontRight  = {};

	CollisionType CollisionType = CT_NONE;
	Pose		  Shift			= Pose::Zero;

	Vector3 FloorNormal			 = Vector3::Zero;
	Vector3 CeilingNormal		 = Vector3::Zero;
	Vector2 FloorTilt			 = Vector2::Zero; // NOTE: Deprecated.
	Vector2 CeilingTilt			 = Vector2::Zero; // NOTE: Deprecated.
	short	NearestLedgeAngle	 = 0;
	float	NearestLedgeDistance = 0.0f;

	int  LastBridgeItemNumber = 0;
	Pose LastBridgeItemPose	  = Pose::Zero;

	bool HitStatic	   = false;
	bool HitTallObject = false;

	bool TriangleAtRight()	   { return ((MiddleRight.SplitAngle != 0) && (MiddleRight.SplitAngle == Middle.SplitAngle)); }
	bool TriangleAtLeft()	   { return ((MiddleLeft.SplitAngle != 0) && (MiddleLeft.SplitAngle == Middle.SplitAngle)); }
	bool DiagonalStepAtRight() { return (MiddleRight.DiagonalStep && TriangleAtRight() && (NearestLedgeAngle % ANGLE(90.0f))); }
	bool DiagonalStepAtLeft()  { return (MiddleLeft.DiagonalStep && TriangleAtLeft() && (NearestLedgeAngle % ANGLE(90.0f))); }
};

[[nodiscard]] bool TestItemRoomCollisionAABB(ItemInfo* item);

void  GetCollisionInfo(CollisionInfo* coll, ItemInfo* item, bool resetRoom = false);
void  GetCollisionInfo(CollisionInfo* coll, ItemInfo* item, const Vector3i& offset, bool resetRoom = false);
int	  GetQuadrant(short angle);
short GetNearestLedgeAngle(ItemInfo* item, CollisionInfo* coll, float& distance);

FloorInfo* GetFloor(int x, int y, int z, short* roomNumber);
int GetFloorHeight(FloorInfo* floor, int x, int y, int z);
int GetCeiling(FloorInfo* floor, int x, int y, int z);
int GetDistanceToFloor(int itemNumber, bool precise = true);

int GetWaterSurface(int x, int y, int z, short roomNumber);
int GetWaterSurface(ItemInfo* item);
int GetWaterDepth(int x, int y, int z, short roomNumber);
int GetWaterDepth(ItemInfo* item);
int GetWaterHeight(int x, int y, int z, short roomNumber);
int GetWaterHeight(ItemInfo* item);

int  FindGridShift(int x, int z);
void ShiftItem(ItemInfo* item, CollisionInfo* coll);
void SnapItemToLedge(ItemInfo* item, CollisionInfo* coll, float offsetMultiplier = 0.0f, bool snapToAngle = true);
void SnapItemToLedge(ItemInfo* item, CollisionInfo* coll, short angle, float offsetMultiplier = 0.0f);
void SnapItemToGrid(ItemInfo* item, CollisionInfo* coll);

void AlignEntityToSurface(ItemInfo* item, const Vector2& ellipse, float alpha = 0.75f, short constraintAngle = ANGLE(70.0f));

// TODO: Deprecated.
bool TestEnvironment(RoomEnvFlags environmentType, int x, int y, int z, int roomNumber);
bool TestEnvironment(RoomEnvFlags environmentType, const Vector3i& pos, int roomNumber);
bool TestEnvironment(RoomEnvFlags environmentType, const ItemInfo* item);
bool TestEnvironment(RoomEnvFlags environmentType, int roomNumber);
bool TestEnvironment(RoomEnvFlags environmentType, ROOM_INFO* room);
bool TestEnvironmentFlags(RoomEnvFlags environmentType, int flags);
