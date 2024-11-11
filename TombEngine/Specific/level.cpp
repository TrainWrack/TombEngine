#include "framework.h"
#include "Specific/level.h"

#include <process.h>
#include <zlib.h>

#include "Game/animation.h"
#include "Game/animation.h"
#include "Game/control/box.h"
#include "Game/control/control.h"
#include "Game/control/volume.h"
#include "Game/control/lot.h"
#include "Game/items.h"
#include "Game/Lara/lara.h"
#include "Game/Lara/lara_initialise.h"
#include "Game/misc.h"
#include "Game/pickup/pickup.h"
#include "Game/savegame.h"
#include "Game/Setup.h"
#include "Game/spotcam.h"
#include "Objects/Generic/Doors/generic_doors.h"
#include "Objects/Sink.h"
#include "Renderer/Renderer.h"
#include "Scripting/Include/Flow/ScriptInterfaceFlowHandler.h"
#include "Scripting/Include/Objects/ScriptInterfaceObjectsHandler.h"
#include "Scripting/Include/ScriptInterfaceGame.h"
#include "Scripting/Include/ScriptInterfaceLevel.h"
#include "Sound/sound.h"
#include "Specific/Input/Input.h"
#include "Specific/trutils.h"

using TEN::Renderer::g_Renderer;

using namespace TEN::Entities::Doors;
using namespace TEN::Input;
using namespace TEN::Utils;

const std::vector<GAME_OBJECT_ID> BRIDGE_OBJECT_IDS =
{
	ID_EXPANDING_PLATFORM,

	ID_FALLING_BLOCK,
	ID_FALLING_BLOCK2,
	ID_CRUMBLING_FLOOR,
	ID_TRAPDOOR1,
	ID_TRAPDOOR2,
	ID_TRAPDOOR3,
	ID_FLOOR_TRAPDOOR1,
	ID_FLOOR_TRAPDOOR2,
	ID_CEILING_TRAPDOOR1,
	ID_CEILING_TRAPDOOR2,
	ID_SCALING_TRAPDOOR,

	ID_ONEBLOCK_PLATFORM,
	ID_TWOBLOCK_PLATFORM,
	ID_RAISING_BLOCK1,
	ID_RAISING_BLOCK2,
	ID_RAISING_BLOCK3,
	ID_RAISING_BLOCK4,

	ID_PUSHABLE_OBJECT_CLIMBABLE1,
	ID_PUSHABLE_OBJECT_CLIMBABLE2,
	ID_PUSHABLE_OBJECT_CLIMBABLE3,
	ID_PUSHABLE_OBJECT_CLIMBABLE4,
	ID_PUSHABLE_OBJECT_CLIMBABLE5,
	ID_PUSHABLE_OBJECT_CLIMBABLE6,
	ID_PUSHABLE_OBJECT_CLIMBABLE7,
	ID_PUSHABLE_OBJECT_CLIMBABLE8,
	ID_PUSHABLE_OBJECT_CLIMBABLE9,
	ID_PUSHABLE_OBJECT_CLIMBABLE10,

	ID_BRIDGE_FLAT,
	ID_BRIDGE_TILT1,
	ID_BRIDGE_TILT2,
	ID_BRIDGE_TILT3,
	ID_BRIDGE_TILT4,
	ID_BRIDGE_CUSTOM
};

LEVEL g_Level;

std::vector<int> MoveablesIds;
std::vector<int> StaticObjectsIds;
std::vector<int> SpriteSequencesIds;

char* DataPtr;
char* CurrentDataPtr;

bool FirstLevel = true;
int SystemNameHash = 0;
int LastLevelHash  = 0;

std::filesystem::file_time_type LastLevelTimestamp;
std::string LastLevelFilePath;

unsigned char ReadUInt8()
{
	unsigned char value = *(unsigned char*)CurrentDataPtr;
	CurrentDataPtr += 1;
	return value;
}

short ReadInt16()
{
	short value = *(short*)CurrentDataPtr;
	CurrentDataPtr += 2;
	return value;
}

unsigned short ReadUInt16()
{
	unsigned short value = *(unsigned short*)CurrentDataPtr;
	CurrentDataPtr += 2;
	return value;
}

int ReadInt32()
{
	int value = *(int*)CurrentDataPtr;
	CurrentDataPtr += 4;
	return value;
}

float ReadFloat()
{
	float value = *(float*)CurrentDataPtr;
	CurrentDataPtr += 4;
	return value;
}

Vector2 ReadVector2()
{
	Vector2 value;
	value.x = ReadFloat();
	value.y = ReadFloat();
	return value;
}

Vector3 ReadVector3()
{
	Vector3 value;
	value.x = ReadFloat();
	value.y = ReadFloat();
	value.z = ReadFloat();
	return value;
}

Vector4 ReadVector4()
{
	Vector4 value;
	value.x = ReadFloat();
	value.y = ReadFloat();
	value.z = ReadFloat();
	value.w = ReadFloat();
	return value;
}

bool ReadBool()
{
	return bool(ReadUInt8());
}

void ReadBytes(void* dest, int count)
{
	memcpy(dest, CurrentDataPtr, count);
	CurrentDataPtr += count;
}

long long ReadLEB128(bool sign)
{
	long long result = 0;
	int currentShift = 0;

	unsigned char currentByte;
	do
	{
		currentByte = ReadUInt8();

		result |= (long long)(currentByte & 0x7F) << currentShift;
		currentShift += 7;
	} while ((currentByte & 0x80) != 0);

	if (sign) // Sign extend
	{
		int shift = 64 - currentShift;
		if (shift > 0)
			result = (long long)(result << shift) >> shift;
	}

	return result;
}

std::string ReadString()
{
	auto numBytes = ReadLEB128(false);

	if (numBytes <= 0)
		return std::string();
	else
	{
		auto newPtr = CurrentDataPtr + numBytes;
		auto result = std::string(CurrentDataPtr, newPtr);
		CurrentDataPtr = newPtr;
		return result;
	}
}

void LoadItems()
{
	g_Level.NumItems = ReadInt32();
	TENLog("Num items: " + std::to_string(g_Level.NumItems), LogLevel::Info);

	if (g_Level.NumItems == 0)
		return;

	InitializeItemArray(ITEM_COUNT_MAX);

	for (int i = 0; i < g_Level.NumItems; i++)
	{
		auto* item = &g_Level.Items[i];

		item->Data = ItemData{};
		item->ObjectNumber = from_underlying(ReadInt16());
		item->RoomNumber = ReadInt16();
		item->Pose.Position.x = ReadInt32();
		item->Pose.Position.y = ReadInt32();
		item->Pose.Position.z = ReadInt32();
		item->Pose.Orientation.y = ReadInt16();
		item->Pose.Orientation.x = ReadInt16();
		item->Pose.Orientation.z = ReadInt16();
		item->Model.Color = ReadVector4();
		item->TriggerFlags = ReadInt16();
		item->Flags = ReadInt16();
		item->Name = ReadString();
			
		g_GameScriptEntities->AddName(item->Name, (short)i);
		g_GameScriptEntities->TryAddColliding((short)i);

		memcpy(&item->StartPose, &item->Pose, sizeof(Pose));
	}

	// Initialize items.
	for (int i = 0; i <= 1; i++)
	{
		// HACK: Initialize bridges first. Required because other items need final floordata to init properly.
		if (i == 0)
		{
			for (int j = 0; j < g_Level.NumItems; j++)
			{
				const auto& item = g_Level.Items[j];
				if (Contains(BRIDGE_OBJECT_IDS, item.ObjectNumber))
					InitializeItem(j);
			}
		}
		// Initialize non-bridge items second.
		else if (i == 1)
		{
			for (int j = 0; j < g_Level.NumItems; j++)
			{
				const auto& item = g_Level.Items[j];
				if (!item.IsBridge())
					InitializeItem(j);
			}
		}
	}
}

void LoadObjects()
{
	Objects.Initialize();
	std::memset(StaticObjects, 0, sizeof(StaticInfo) * MAX_STATICS);

	int numMeshes = ReadInt32();
	TENLog("Num meshes: " + std::to_string(numMeshes), LogLevel::Info);

	g_Level.Meshes.reserve(numMeshes);
	for (int i = 0; i < numMeshes; i++)
	{
		MESH mesh;

		mesh.lightMode = (LightMode)ReadUInt8();

		mesh.sphere.Center.x = ReadFloat();
		mesh.sphere.Center.y = ReadFloat();
		mesh.sphere.Center.z = ReadFloat();
		mesh.sphere.Radius = ReadFloat();

		int numVertices = ReadInt32();

		mesh.positions.resize(numVertices);
		ReadBytes(mesh.positions.data(), 12 * numVertices);

		mesh.colors.resize(numVertices);
		ReadBytes(mesh.colors.data(), 12 * numVertices);

		mesh.effects.resize(numVertices);
		ReadBytes(mesh.effects.data(), 12 * numVertices);

		mesh.bones.resize(numVertices);
		ReadBytes(mesh.bones.data(), 4 * numVertices);
		
		int numBuckets = ReadInt32();
		mesh.buckets.reserve(numBuckets);
		for (int j = 0; j < numBuckets; j++)
		{
			BUCKET bucket;

			bucket.texture = ReadInt32();
			bucket.blendMode = (BlendMode)ReadUInt8();
			bucket.animated = ReadBool();
			bucket.numQuads = 0;
			bucket.numTriangles = 0;

			int numPolygons = ReadInt32();
			bucket.polygons.reserve(numPolygons);
			for (int k = 0; k < numPolygons; k++)
			{
				POLYGON poly;

				poly.shape = ReadInt32();
				poly.animatedSequence = ReadInt32();
				poly.animatedFrame = ReadInt32();
				poly.shineStrength = ReadFloat();
				int count = (poly.shape == 0 ? 4 : 3);
				poly.indices.resize(count);
				poly.textureCoordinates.resize(count);
				poly.normals.resize(count);
				poly.tangents.resize(count);
				poly.binormals.resize(count);
				
				for (int n = 0; n < count; n++)
					poly.indices[n] = ReadInt32();
				for (int n = 0; n < count; n++)
					poly.textureCoordinates[n] = ReadVector2();
				for (int n = 0; n < count; n++)
					poly.normals[n] = ReadVector3();
				for (int n = 0; n < count; n++)
					poly.tangents[n] = ReadVector3();
				for (int n = 0; n < count; n++)
					poly.binormals[n] = ReadVector3();

				bucket.polygons.push_back(poly);

				if (poly.shape == 0)
					bucket.numQuads++;
				else
					bucket.numTriangles++;
			}

			mesh.buckets.push_back(bucket);
		}

		g_Level.Meshes.push_back(mesh);
	}

	int numAnimations = ReadInt32();
	TENLog("Num animations: " + std::to_string(numAnimations), LogLevel::Info);

	g_Level.Anims.resize(numAnimations);
	for (int i = 0; i < numAnimations; i++)
	{
		auto* anim = &g_Level.Anims[i];

		anim->FramePtr = ReadInt32();
		anim->Interpolation = ReadInt32();
		anim->ActiveState = ReadInt32();
		anim->VelocityStart = ReadVector3();
		anim->VelocityEnd = ReadVector3();
		anim->frameBase = ReadInt32();
		anim->frameEnd = ReadInt32();
		anim->JumpAnimNum = ReadInt32();
		anim->JumpFrameNum = ReadInt32();
		anim->NumStateDispatches = ReadInt32();
		anim->StateDispatchIndex = ReadInt32();
		anim->NumCommands = ReadInt32();
		anim->CommandIndex = ReadInt32();
	}

	int numChanges = ReadInt32();
	g_Level.Changes.resize(numChanges);
	ReadBytes(g_Level.Changes.data(), sizeof(StateDispatchData) * numChanges);

	int numRanges = ReadInt32();
	g_Level.Ranges.resize(numRanges);
	ReadBytes(g_Level.Ranges.data(), sizeof(StateDispatchRangeData) * numRanges);

	int numCommands = ReadInt32();
	g_Level.Commands.resize(numCommands);
	ReadBytes(g_Level.Commands.data(), sizeof(short) * numCommands);

	int numBones = ReadInt32();
	g_Level.Bones.resize(numBones);
	ReadBytes(g_Level.Bones.data(), 4 * numBones);

	int numFrames = ReadInt32();
	g_Level.Frames.resize(numFrames);
	for (int i = 0; i < numFrames; i++)
	{
		auto* frame = &g_Level.Frames[i];

		frame->BoundingBox.X1 = ReadInt16();
		frame->BoundingBox.X2 = ReadInt16();
		frame->BoundingBox.Y1 = ReadInt16();
		frame->BoundingBox.Y2 = ReadInt16();
		frame->BoundingBox.Z1 = ReadInt16();
		frame->BoundingBox.Z2 = ReadInt16();

		// NOTE: Braces are necessary to ensure correct value init order.
		frame->Offset = Vector3{ (float)ReadInt16(), (float)ReadInt16(), (float)ReadInt16() };

		int numAngles = ReadInt16();
		frame->BoneOrientations.resize(numAngles);
		for (int j = 0; j < numAngles; j++)
		{
			auto* q = &frame->BoneOrientations[j];
			q->x = ReadFloat();
			q->y = ReadFloat();
			q->z = ReadFloat();
			q->w = ReadFloat();
		}
	}

	int numModels = ReadInt32();
	TENLog("Num models: " + std::to_string(numModels), LogLevel::Info);

	for (int i = 0; i < numModels; i++)
	{
		int objNum = ReadInt32();
		MoveablesIds.push_back(objNum);

		Objects[objNum].loaded = true;
		Objects[objNum].nmeshes = ReadInt32();
		Objects[objNum].meshIndex = ReadInt32();
		Objects[objNum].boneIndex = ReadInt32();
		Objects[objNum].frameBase = ReadInt32();
		Objects[objNum].animIndex = ReadInt32();

		Objects[objNum].loaded = true;
	}

	TENLog("Initializing objects...", LogLevel::Info);
	InitializeObjects();

	int numStatics = ReadInt32();
	TENLog("Num statics: " + std::to_string(numStatics), LogLevel::Info);

	for (int i = 0; i < numStatics; i++)
	{
		int meshID = ReadInt32();

		if (meshID >= MAX_STATICS)
		{
			TENLog("Static with ID " + std::to_string(meshID) + " detected, while maximum is " + std::to_string(MAX_STATICS) + ". " +
				   "Change static mesh ID in WadTool to a value below maximum.", LogLevel::Warning);
			
			meshID = 0;
		}

		StaticObjectsIds.push_back(meshID);

		StaticObjects[meshID].meshNumber = (short)ReadInt32();

		StaticObjects[meshID].visibilityBox.X1 = ReadInt16();
		StaticObjects[meshID].visibilityBox.X2 = ReadInt16();
		StaticObjects[meshID].visibilityBox.Y1 = ReadInt16();
		StaticObjects[meshID].visibilityBox.Y2 = ReadInt16();
		StaticObjects[meshID].visibilityBox.Z1 = ReadInt16();
		StaticObjects[meshID].visibilityBox.Z2 = ReadInt16();

		StaticObjects[meshID].collisionBox.X1 = ReadInt16();
		StaticObjects[meshID].collisionBox.X2 = ReadInt16();
		StaticObjects[meshID].collisionBox.Y1 = ReadInt16();
		StaticObjects[meshID].collisionBox.Y2 = ReadInt16();
		StaticObjects[meshID].collisionBox.Z1 = ReadInt16();
		StaticObjects[meshID].collisionBox.Z2 = ReadInt16();

		StaticObjects[meshID].flags = (short)ReadInt16();

		StaticObjects[meshID].shatterType = (ShatterType)ReadInt16();
		StaticObjects[meshID].shatterSound = (short)ReadInt16();
	}
}

void LoadCameras()
{
	int numCameras = ReadInt32();
	TENLog("Num cameras: " + std::to_string(numCameras), LogLevel::Info);

	g_Level.Cameras.reserve(numCameras);
	for (int i = 0; i < numCameras; i++)
	{
		auto& camera = g_Level.Cameras.emplace_back();
		camera.Index = i;
		camera.Position.x = ReadInt32();
		camera.Position.y = ReadInt32();
		camera.Position.z = ReadInt32();
		camera.RoomNumber = ReadInt32();
		camera.Flags = ReadInt32();
		camera.Speed = ReadInt32();
		camera.Name = ReadString();

		g_GameScriptEntities->AddName(camera.Name, camera);
	}

	NumberSpotcams = ReadInt32();

	// TODO: Read properly!
	if (NumberSpotcams != 0)
		ReadBytes(SpotCam, NumberSpotcams * sizeof(SPOTCAM));

	int numSinks = ReadInt32();
	TENLog("Num sinks: " + std::to_string(numSinks), LogLevel::Info);

	g_Level.Sinks.reserve(numSinks);
	for (int i = 0; i < numSinks; i++)
	{
		auto& sink = g_Level.Sinks.emplace_back();
		sink.Position.x = ReadInt32();
		sink.Position.y = ReadInt32();
		sink.Position.z = ReadInt32();
		sink.Strength = ReadInt32();
		sink.BoxIndex = ReadInt32();
		sink.Name = ReadString();

		g_GameScriptEntities->AddName(sink.Name, sink);
	}
}

void LoadTextures()
{
	TENLog("Loading textures... ", LogLevel::Info);

	int size;

	int numTextures = ReadInt32();
	TENLog("Num room textures: " + std::to_string(numTextures), LogLevel::Info);

	g_Level.RoomTextures.reserve(numTextures);
	for (int i = 0; i < numTextures; i++)
	{
		TEXTURE texture;

		texture.width = ReadInt32();
		texture.height = ReadInt32();

		size = ReadInt32();
		texture.colorMapData.resize(size);
		ReadBytes(texture.colorMapData.data(), size);
		
		bool hasNormalMap = ReadBool();
		if (hasNormalMap)
		{
			size = ReadInt32();
			texture.normalMapData.resize(size);
			ReadBytes(texture.normalMapData.data(), size);
		}

		g_Level.RoomTextures.push_back(texture);
	}

	numTextures = ReadInt32();
	TENLog("Num object textures: " + std::to_string(numTextures), LogLevel::Info);

	g_Level.MoveablesTextures.reserve(numTextures);
	for (int i = 0; i < numTextures; i++)
	{
		TEXTURE texture;

		texture.width = ReadInt32();
		texture.height = ReadInt32();

		size = ReadInt32();
		texture.colorMapData.resize(size);
		ReadBytes(texture.colorMapData.data(), size);

		bool hasNormalMap = ReadBool();
		if (hasNormalMap)
		{
			size = ReadInt32();
			texture.normalMapData.resize(size);
			ReadBytes(texture.normalMapData.data(), size);
		}

		g_Level.MoveablesTextures.push_back(texture);
	}

	numTextures = ReadInt32();
	TENLog("Num static textures: " + std::to_string(numTextures), LogLevel::Info);

	g_Level.StaticsTextures.reserve(numTextures);
	for (int i = 0; i < numTextures; i++)
	{
		TEXTURE texture;

		texture.width = ReadInt32();
		texture.height = ReadInt32();

		size = ReadInt32();
		texture.colorMapData.resize(size);
		ReadBytes(texture.colorMapData.data(), size);

		bool hasNormalMap = ReadBool();
		if (hasNormalMap)
		{
			size = ReadInt32();
			texture.normalMapData.resize(size);
			ReadBytes(texture.normalMapData.data(), size);
		}

		g_Level.StaticsTextures.push_back(texture);
	}

	numTextures = ReadInt32();
	TENLog("Num anim textures: " + std::to_string(numTextures), LogLevel::Info);

	g_Level.AnimatedTextures.reserve(numTextures);
	for (int i = 0; i < numTextures; i++)
	{
		TEXTURE texture;

		texture.width = ReadInt32();
		texture.height = ReadInt32();

		size = ReadInt32();
		texture.colorMapData.resize(size);
		ReadBytes(texture.colorMapData.data(), size);

		bool hasNormalMap = ReadBool();
		if (hasNormalMap)
		{
			size = ReadInt32();
			texture.normalMapData.resize(size);
			ReadBytes(texture.normalMapData.data(), size);
		}

		g_Level.AnimatedTextures.push_back(texture);
	}

	numTextures = ReadInt32();
	TENLog("Num sprite textures: " + std::to_string(numTextures), LogLevel::Info);

	g_Level.SpritesTextures.reserve(numTextures);
	for (int i = 0; i < numTextures; i++)
	{
		TEXTURE texture;

		texture.width = ReadInt32();
		texture.height = ReadInt32();

		size = ReadInt32();
		texture.colorMapData.resize(size);
		ReadBytes(texture.colorMapData.data(), size);

		g_Level.SpritesTextures.push_back(texture);
	}

	g_Level.SkyTexture.width = ReadInt32();
	g_Level.SkyTexture.height = ReadInt32();
	size = ReadInt32();
	g_Level.SkyTexture.colorMapData.resize(size);
	ReadBytes(g_Level.SkyTexture.colorMapData.data(), size);
}

// The way floordata "planes" were previously stored was non-standard.
// Instead of a Plane object with a normal + distance,
// they used a Vector3 object with data laid out as follows:
// x: X tilt grade (0.25f = 1/4 block).
// y: Z tilt grade (0.25f = 1/4 block).
// z: Plane's absolute height at the sector's center (i.e. distance in regular plane terms).
static Plane ConvertFakePlaneToPlane(const Vector3& fakePlane, bool isFloor)
{
	// Calculate normal from tilt grades.
	int sign = isFloor ? -1 : 1;
	auto normal = Vector3(-fakePlane.x, 1.0f, -fakePlane.y) * sign;
	normal.Normalize();

	// Determine distance.
	float dist = fakePlane.z;

	// Return plane.
	return Plane(normal, dist);
}

void LoadDynamicRoomData()
{
	int roomCount = ReadInt32();

	if (g_Level.Rooms.size() != roomCount)
		throw std::exception("Dynamic room data count is inconsistent with room count");

	for (int i = 0; i < roomCount; i++)
	{
		auto& room = g_Level.Rooms[i];

		room.Name = ReadString();

		int tagCount = ReadInt32();
		room.Tags.resize(0);
		room.Tags.reserve(tagCount);

		for (int j = 0; j < tagCount; j++)
			room.Tags.push_back(ReadString());

		room.ambient = ReadVector3();

		room.flippedRoom = ReadInt32();
		room.flags = ReadInt32();
		room.meshEffect = ReadInt32();
		room.reverbType = (ReverbType)ReadInt32();
		room.flipNumber = ReadInt32();

		int staticCount = ReadInt32();
		room.mesh.resize(0);
		room.mesh.reserve(staticCount);

		for (int j = 0; j < staticCount; j++)
		{
			auto& mesh = room.mesh.emplace_back();

			mesh.roomNumber = i;
			mesh.pos.Position.x = ReadInt32();
			mesh.pos.Position.y = ReadInt32();
			mesh.pos.Position.z = ReadInt32();
			mesh.pos.Orientation.y = ReadUInt16();
			mesh.pos.Orientation.x = ReadUInt16();
			mesh.pos.Orientation.z = ReadUInt16();
			mesh.scale = ReadFloat();
			mesh.flags = ReadUInt16();
			mesh.color = ReadVector4();
			mesh.staticNumber = ReadUInt16();
			mesh.HitPoints = ReadInt16();
			mesh.Name = ReadString();

			g_GameScriptEntities->AddName(mesh.Name, mesh);
		}

		int triggerVolumeCount = ReadInt32();
		room.TriggerVolumes.resize(0);
		room.TriggerVolumes.reserve(triggerVolumeCount);

		for (int j = 0; j < triggerVolumeCount; j++)
		{
			auto& volume = room.TriggerVolumes.emplace_back();

			volume.Type = (VolumeType)ReadInt32();

			auto pos = ReadVector3();
			auto orient = ReadVector4();
			auto scale = ReadVector3();

			volume.Enabled = ReadBool();
			volume.DetectInAdjacentRooms = ReadBool();

			volume.Name = ReadString();
			volume.EventSetIndex = ReadInt32();

			volume.Box = BoundingOrientedBox(pos, scale, orient);
			volume.Sphere = BoundingSphere(pos, scale.x);

			volume.StateQueue.reserve(VOLUME_STATE_QUEUE_SIZE);

			g_GameScriptEntities->AddName(volume.Name, volume);
		}

		g_GameScriptEntities->AddName(room.Name, room);

		room.itemNumber = NO_VALUE;
		room.fxNumber = NO_VALUE;
	}
}

void LoadStaticRoomData()
{
	constexpr auto ILLEGAL_FLOOR_SLOPE_ANGLE   = ANGLE(36.0f);
	constexpr auto ILLEGAL_CEILING_SLOPE_ANGLE = ANGLE(45.0f);

	int roomCount = ReadInt32();
	TENLog("Rooms: " + std::to_string(roomCount), LogLevel::Info);

	g_Level.Rooms.reserve(roomCount);
	for (int i = 0; i < roomCount; i++)
	{
		auto& room = g_Level.Rooms.emplace_back();
		
		room.Position.x = ReadInt32();
		room.Position.y = 0;
		room.Position.z = ReadInt32();
		room.BottomHeight = ReadInt32();
		room.TopHeight = ReadInt32();

		int vertexCount = ReadInt32();

		room.positions.reserve(vertexCount);
		for (int j = 0; j < vertexCount; j++)
			room.positions.push_back(ReadVector3());

		room.colors.reserve(vertexCount);
		for (int j = 0; j < vertexCount; j++)
			room.colors.push_back(ReadVector3());

		room.effects.reserve(vertexCount);
		for (int j = 0; j < vertexCount; j++)
			room.effects.push_back(ReadVector3());

		int bucketCount = ReadInt32();
		room.buckets.reserve(bucketCount);
		for (int j = 0; j < bucketCount; j++)
		{
			auto bucket = BUCKET{};

			bucket.texture = ReadInt32();
			bucket.blendMode = (BlendMode)ReadUInt8();
			bucket.animated = ReadBool();
			bucket.numQuads = 0;
			bucket.numTriangles = 0;

			int polyCount = ReadInt32();
			bucket.polygons.reserve(polyCount);
			for (int k = 0; k < polyCount; k++)
			{
				auto poly = POLYGON{};
				
				poly.shape = ReadInt32();
				poly.animatedSequence = ReadInt32();
				poly.animatedFrame = ReadInt32();

				int count = (poly.shape == 0 ? 4 : 3);
				poly.indices.resize(count);
				poly.textureCoordinates.resize(count);
				poly.normals.resize(count);
				poly.tangents.resize(count);
				poly.binormals.resize(count);

				for (int l = 0; l < count; l++)
					poly.indices[l] = ReadInt32();

				for (int n = 0; n < count; n++)
					poly.textureCoordinates[n] = ReadVector2();

				for (int n = 0; n < count; n++)
					poly.normals[n] = ReadVector3();

				for (int n = 0; n < count; n++)
					poly.tangents[n] = ReadVector3();

				for (int n = 0; n < count; n++)
					poly.binormals[n] = ReadVector3();

				bucket.polygons.push_back(poly);

				(poly.shape == 0) ? bucket.numQuads++ : bucket.numTriangles++;
			}

			room.buckets.push_back(bucket);
		}

		int portalCount = ReadInt32();
		for (int j = 0; j < portalCount; j++)
			LoadPortal(room);

		room.ZSize = ReadInt32();
		room.XSize = ReadInt32();
		auto roomPos = Vector2i(room.Position.x, room.Position.z);

		room.Sectors.reserve(room.XSize * room.ZSize);
		for (int x = 0; x < room.XSize; x++)
		{
			for (int z = 0; z < room.ZSize; z++)
			{
				auto sector = FloorInfo{};

				sector.Position = roomPos + Vector2i(BLOCK(x), BLOCK(z));
				sector.RoomNumber = i;

				sector.TriggerIndex = ReadInt32();
				sector.PathfindingBoxID = ReadInt32();

				sector.FloorSurface.Triangles[0].Material =
				sector.FloorSurface.Triangles[1].Material =
				sector.CeilingSurface.Triangles[0].Material =
				sector.CeilingSurface.Triangles[1].Material = (MaterialType)ReadInt32();

				sector.Stopper = (bool)ReadInt32();

				sector.FloorSurface.SplitAngle = FROM_RAD(ReadFloat());
				sector.FloorSurface.Triangles[0].SteepSlopeAngle = ILLEGAL_FLOOR_SLOPE_ANGLE;
				sector.FloorSurface.Triangles[1].SteepSlopeAngle = ILLEGAL_FLOOR_SLOPE_ANGLE;
				sector.FloorSurface.Triangles[0].PortalRoomNumber = ReadInt32();
				sector.FloorSurface.Triangles[1].PortalRoomNumber = ReadInt32();
				sector.FloorSurface.Triangles[0].Plane = ConvertFakePlaneToPlane(ReadVector3(), true);
				sector.FloorSurface.Triangles[1].Plane = ConvertFakePlaneToPlane(ReadVector3(), true);

				sector.CeilingSurface.SplitAngle = FROM_RAD(ReadFloat());
				sector.CeilingSurface.Triangles[0].SteepSlopeAngle = ILLEGAL_CEILING_SLOPE_ANGLE;
				sector.CeilingSurface.Triangles[1].SteepSlopeAngle = ILLEGAL_CEILING_SLOPE_ANGLE;
				sector.CeilingSurface.Triangles[0].PortalRoomNumber = ReadInt32();
				sector.CeilingSurface.Triangles[1].PortalRoomNumber = ReadInt32();
				sector.CeilingSurface.Triangles[0].Plane = ConvertFakePlaneToPlane(ReadVector3(), false);
				sector.CeilingSurface.Triangles[1].Plane = ConvertFakePlaneToPlane(ReadVector3(), false);

				sector.SidePortalRoomNumber = ReadInt32();
				sector.Flags.Death = ReadBool();
				sector.Flags.Monkeyswing = ReadBool();
				sector.Flags.ClimbNorth = ReadBool();
				sector.Flags.ClimbSouth = ReadBool();
				sector.Flags.ClimbEast = ReadBool();
				sector.Flags.ClimbWest = ReadBool();
				sector.Flags.MarkTriggerer = ReadBool();
				sector.Flags.MarkTriggererActive = 0; // TODO: Needs to be written to and read from savegames.
				sector.Flags.MarkBeetle = ReadBool();

				room.Sectors.push_back(sector);
			}
		}

		int lightCount = ReadInt32();
		room.lights.reserve(lightCount);
		for (int j = 0; j < lightCount; j++)
		{
			auto light = ROOM_LIGHT{};

			light.x = ReadInt32();
			light.y = ReadInt32();
			light.z = ReadInt32();
			light.dx = ReadFloat();
			light.dy = ReadFloat();
			light.dz = ReadFloat();
			light.r = ReadFloat();
			light.g = ReadFloat();
			light.b = ReadFloat();
			light.intensity = ReadFloat();
			light.in = ReadFloat();
			light.out = ReadFloat();
			light.length = ReadFloat();
			light.cutoff = ReadFloat();
			light.type = ReadUInt8();
			light.castShadows = ReadBool();

			room.lights.push_back(light);
		}

		room.RoomNumber = i;
	}
}

void LoadRooms()
{
	TENLog("Loading rooms... ", LogLevel::Info);
	
	Wibble = 0;

	LoadStaticRoomData();
	BuildOutsideRoomsTable();

	int numFloorData = ReadInt32(); 
	g_Level.FloorData.resize(numFloorData);
	ReadBytes(g_Level.FloorData.data(), numFloorData * sizeof(short));
}

void FreeLevel(bool partial)
{
	if (FirstLevel)
	{
		FirstLevel = false;
		return;
	}

	// Should happen before resetting items.
	if (partial)
		ResetRoomData();

	g_Level.Items.resize(0);
	g_Level.AIObjects.resize(0);
	g_Level.Cameras.resize(0);
	g_Level.Sinks.resize(0);
	g_Level.SoundSources.resize(0);
	g_Level.VolumeEventSets.resize(0);
	g_Level.GlobalEventSets.resize(0);
	g_Level.LoopedEventSetIndices.resize(0);

	g_GameScript->FreeLevelScripts();
	g_GameScriptEntities->FreeEntities();

	if (partial)
		return;

	g_Renderer.FreeRendererData();

	MoveablesIds.resize(0);
	StaticObjectsIds.resize(0);
	SpriteSequencesIds.resize(0);

	g_Level.RoomTextures.resize(0);
	g_Level.MoveablesTextures.resize(0);
	g_Level.StaticsTextures.resize(0);
	g_Level.AnimatedTextures.resize(0);
	g_Level.SpritesTextures.resize(0);
	g_Level.AnimatedTexturesSequences.resize(0);
	g_Level.Rooms.resize(0);
	g_Level.Bones.resize(0);
	g_Level.Meshes.resize(0);
	g_Level.PathfindingBoxes.resize(0);
	g_Level.Overlaps.resize(0);
	g_Level.Anims.resize(0);
	g_Level.Changes.resize(0);
	g_Level.Ranges.resize(0);
	g_Level.Commands.resize(0);
	g_Level.Frames.resize(0);
	g_Level.Sprites.resize(0);
	g_Level.SoundDetails.resize(0);
	g_Level.SoundMap.resize(0);
	g_Level.FloorData.resize(0);

	for (int i = 0; i < 2; i++)
	{
		for (int j = 0; j < (int)ZoneType::MaxZone; j++)
			g_Level.Zones[j][i].clear();
	}

	FreeSamples();
}

size_t ReadFileEx(void* ptr, size_t size, size_t count, FILE* stream)
{
	_lock_file(stream);
	size_t result = fread(ptr, size, count, stream);
	_unlock_file(stream);
	return result;
}

void LoadSoundSources()
{
	int numSoundSources = ReadInt32();
	TENLog("Num sound sources: " + std::to_string(numSoundSources), LogLevel::Info);

	g_Level.SoundSources.reserve(numSoundSources);
	for (int i = 0; i < numSoundSources; i++)
	{
		auto& source = g_Level.SoundSources.emplace_back(SoundSourceInfo{});

		source.Position.x = ReadInt32();
		source.Position.y = ReadInt32();
		source.Position.z = ReadInt32();
		source.SoundID = ReadInt32();
		source.Flags = ReadInt32();
		source.Name = ReadString();

		g_GameScriptEntities->AddName(source.Name, source);
	}
}

void LoadAnimatedTextures()
{
	int numAnimatedTextures = ReadInt32();
	TENLog("Num anim textures: " + std::to_string(numAnimatedTextures), LogLevel::Info);

	for (int i = 0; i < numAnimatedTextures; i++)
	{
		ANIMATED_TEXTURES_SEQUENCE sequence;
		sequence.atlas = ReadInt32();
		sequence.Fps = ReadInt32();
		sequence.numFrames = ReadInt32();

		for (int j = 0; j < sequence.numFrames; j++)
		{
			ANIMATED_TEXTURES_FRAME frame;
			frame.x1 = ReadFloat();
			frame.y1 = ReadFloat();
			frame.x2 = ReadFloat();
			frame.y2 = ReadFloat();
			frame.x3 = ReadFloat();
			frame.y3 = ReadFloat();
			frame.x4 = ReadFloat();
			frame.y4 = ReadFloat();
			sequence.frames.push_back(frame);
		}

		g_Level.AnimatedTexturesSequences.push_back(sequence);
	}
}

void LoadAIObjects()
{
	int nAIObjects = ReadInt32();
	TENLog("Num AI objects: " + std::to_string(nAIObjects), LogLevel::Info);

	g_Level.AIObjects.reserve(nAIObjects);
	for (int i = 0; i < nAIObjects; i++)
	{
		auto& obj = g_Level.AIObjects.emplace_back();

		obj.objectNumber = (GAME_OBJECT_ID)ReadInt16();
		obj.roomNumber = ReadInt16();
		obj.pos.Position.x = ReadInt32();
		obj.pos.Position.y = ReadInt32();
		obj.pos.Position.z = ReadInt32();
		obj.pos.Orientation.y = ReadInt16();
		obj.pos.Orientation.x = ReadInt16();
		obj.pos.Orientation.z = ReadInt16();
		obj.triggerFlags = ReadInt16();
		obj.flags = ReadInt16();
		obj.boxNumber = ReadInt32();
		obj.Name = ReadString();

		g_GameScriptEntities->AddName(obj.Name, obj);
	}
}

void LoadEvent(EventSet& eventSet)
{
	int eventType = ReadInt32();

	if (eventType >= (int)EventType::Count)
	{
		TENLog("Unknown event type detected for event set " + eventSet.Name + ". Fall back to default.", LogLevel::Warning);
		eventType = (int)EventType::Enter;
	}

	auto& evt = eventSet.Events[eventType];

	evt.Mode = (EventMode)ReadInt32();
	evt.Function = ReadString();
	evt.Data = ReadString();
	evt.CallCounter = ReadInt32();
}

void LoadEventSets()
{
	int eventSetCount = ReadInt32();
	if (eventSetCount == 0)
		return;

	int globalEventSetCount = ReadInt32();
	TENLog("Num global event sets: " + std::to_string(globalEventSetCount), LogLevel::Info);

	for (int i = 0; i < globalEventSetCount; i++)
	{
		auto eventSet = EventSet();

		eventSet.Name = ReadString();

		int eventCount = ReadInt32();
		for (int j = 0; j < eventCount; j++)
			LoadEvent(eventSet);

		g_Level.GlobalEventSets.push_back(eventSet);

		if (!eventSet.Events[(int)EventType::Loop].Function.empty())
			g_Level.LoopedEventSetIndices.push_back(i);
	}

	int volumeEventSetCount = ReadInt32();
	TENLog("Num volume event sets: " + std::to_string(volumeEventSetCount), LogLevel::Info);

	for (int i = 0; i < volumeEventSetCount; i++)
	{
		auto eventSet = EventSet();

		eventSet.Name = ReadString();
		eventSet.Activators = (ActivatorFlags)ReadInt32();

		int eventCount = ReadInt32();
		for (int j = 0; j < eventCount; j++)
			LoadEvent(eventSet);

		g_Level.VolumeEventSets.push_back(eventSet);
	}
}

FILE* FileOpen(const char* fileName)
{
	FILE* ptr = fopen(fileName, "rb");
	return ptr;
}

void FileClose(FILE* ptr)
{
	fclose(ptr);
}

bool Decompress(byte* dest, byte* src, unsigned long compressedSize, unsigned long uncompressedSize)
{
	z_stream strm;
	ZeroMemory(&strm, sizeof(z_stream));
	strm.avail_in = compressedSize;
	strm.avail_out = uncompressedSize;
	strm.next_out = (BYTE*)dest;
	strm.next_in = (BYTE*)src;

	inflateInit(&strm);
	inflate(&strm, Z_FULL_FLUSH);

	if (strm.total_out == uncompressedSize)
	{
		inflateEnd(&strm);
		return true;
	}

	return false;
}

bool ReadCompressedBlock(FILE* filePtr, bool skip)
{
	int compressedSize = 0;
	int uncompressedSize = 0;

	ReadFileEx(&uncompressedSize, 1, 4, filePtr);
	ReadFileEx(&compressedSize, 1, 4, filePtr);

	if (skip) 
	{
		fseek(filePtr, compressedSize, SEEK_CUR);
		return false;
	}

	auto compressedBuffer = (char*)malloc(compressedSize);
	ReadFileEx(compressedBuffer, compressedSize, 1, filePtr);
	DataPtr = (char*)malloc(uncompressedSize);
	Decompress((byte*)DataPtr, (byte*)compressedBuffer, compressedSize, uncompressedSize);
	free(compressedBuffer);

	CurrentDataPtr = DataPtr;

	return true;
}

void FinalizeBlock()
{
	if (DataPtr == nullptr)
		return;

	free(DataPtr);
	DataPtr = nullptr;
	CurrentDataPtr = nullptr;
}

void UpdateProgress(float progress, bool skip = false)
{
	if (skip)
		return;

	g_Renderer.UpdateProgress(progress);
}

bool LoadLevel(std::string path, bool partial)
{
	FILE* filePtr = nullptr;
	bool loadedSuccessfully = false;

	try
	{
		filePtr = FileOpen(path.c_str());

		if (!filePtr)
			throw std::exception{ (std::string{ "Unable to read level file: " } + path).c_str() };

		char header[4];
		unsigned char version[4];
		int systemHash = 0;
		int levelHash = 0;

		// Read file header
		ReadFileEx(&header, 1, 4, filePtr);
		ReadFileEx(&version, 1, 4, filePtr);
		ReadFileEx(&systemHash, 1, 4, filePtr);
		ReadFileEx(&levelHash, 1, 4, filePtr);

		// Check file header.
		if (std::string(header) != "TEN")
			throw std::invalid_argument("Level file header is not valid! Must be TEN. Probably old level version?");

		// Check level file integrity to allow or disallow fast reload.
		if (partial && levelHash != LastLevelHash)
		{
			TENLog("Level file has changed since the last load; fast reload is not possible.", LogLevel::Warning);
			partial = false;
			FreeLevel(false); // Erase all precached data.
		}

		// Store information about last loaded level file.
		LastLevelFilePath = path;
		LastLevelHash = levelHash;
		LastLevelTimestamp = std::filesystem::last_write_time(path);
		
		TENLog("Level compiler version: " + std::to_string(version[0]) + "." + std::to_string(version[1]) + "." + std::to_string(version[2]), LogLevel::Info);

		// Check if level version is higher than engine version
		auto assemblyVersion = TEN::Utils::GetProductOrFileVersion(true);
		for (int i = 0; i < assemblyVersion.size(); i++)
		{
			if (assemblyVersion[i] < version[i])
			{
				TENLog("Level version is different from TEN version.", LogLevel::Warning);
				break;
			}
		}

		// Check system name hash and reset it if it's valid (because we use build & play feature only once)
		if (SystemNameHash != 0) 
		{
			if (SystemNameHash != systemHash)
				throw std::exception("An attempt was made to use level debug feature on a different system.");

			InitializeGame = true;
			SystemNameHash = 0;
		}

		if (partial)
		{
			TENLog("Loading same level. Skipping media and geometry data.", LogLevel::Info);
			SetScreenFadeOut(FADE_SCREEN_SPEED * 2, true);
		}
		else
		{
			SetScreenFadeIn(FADE_SCREEN_SPEED, true);
		}

		UpdateProgress(0);

		// Media block
		if (ReadCompressedBlock(filePtr, partial))
		{
			LoadTextures();
			UpdateProgress(30);

			LoadSamples();
			UpdateProgress(40);

			FinalizeBlock();
		}

		// Geometry block
		if (ReadCompressedBlock(filePtr, partial))
		{
			LoadRooms();
			UpdateProgress(50);

			LoadObjects();
			UpdateProgress(60);

			LoadSprites();
			LoadBoxes();
			LoadAnimatedTextures();
			UpdateProgress(70);

			FinalizeBlock();
		}

		// Dynamic data block
		if (ReadCompressedBlock(filePtr, false))
		{
			LoadDynamicRoomData();
			LoadItems();
			LoadAIObjects();
			LoadCameras();
			LoadSoundSources();
			LoadEventSets();
			UpdateProgress(80, partial);

			FinalizeBlock();
		}

		TENLog("Initializing level...", LogLevel::Info);

		// Initialize game.
		InitializeGameFlags();
		InitializeLara(!InitializeGame && CurrentLevel > 0);
		InitializeNeighborRoomList();
		GetCarriedItems();
		GetAIPickups();
		g_GameScriptEntities->AssignLara();
		UpdateProgress(90, partial);

		if (!partial)
		{
			g_Renderer.PrepareDataForTheRenderer();
			SetScreenFadeOut(FADE_SCREEN_SPEED, true);
			StopSoundTracks(SOUND_XFADETIME_BGM_START);
		}
		else
		{
			SetScreenFadeIn(FADE_SCREEN_SPEED, true);
			StopSoundTracks(SOUND_XFADETIME_LEVELJUMP);
		}

		UpdateProgress(100, partial);

		TENLog("Level loading complete.", LogLevel::Info);

		loadedSuccessfully = true;
	}
	catch (std::exception& ex)
	{
		FinalizeBlock();
		StopSoundTracks(SOUND_XFADETIME_LEVELJUMP);

		TENLog("Error while loading level: " + std::string(ex.what()), LogLevel::Error);
		loadedSuccessfully = false;
		SystemNameHash = 0;
	}

	// Now the entire level is decompressed, we can close it
	FileClose(filePtr);
	filePtr = nullptr;

	return loadedSuccessfully;
}

void LoadSamples()
{
	TENLog("Loading samples... ", LogLevel::Info);

	int soundMapSize = ReadInt16();
	TENLog("Sound map size: " + std::to_string(soundMapSize), LogLevel::Info);

	g_Level.SoundMap.resize(soundMapSize);
	ReadBytes(g_Level.SoundMap.data(), soundMapSize * sizeof(short));

	int numSampleInfos = ReadInt32();
	if (!numSampleInfos)
	{
		TENLog("No samples were found and loaded.", LogLevel::Warning);
		return;
	}

	TENLog("Num sample infos: " + std::to_string(numSampleInfos), LogLevel::Info);

	g_Level.SoundDetails.resize(numSampleInfos);
	ReadBytes(g_Level.SoundDetails.data(), numSampleInfos * sizeof(SampleInfo));

	int numSamples = ReadInt32();
	if (numSamples <= 0)
		return;

	TENLog("Num samples: " + std::to_string(numSamples), LogLevel::Info);

	int uncompressedSize;
	int compressedSize;
	char* buffer = (char*)malloc(2 * 1024 * 1024);

	for (int i = 0; i < numSamples; i++)
	{
		uncompressedSize = ReadInt32();
		compressedSize = ReadInt32();
		ReadBytes(buffer, compressedSize);
		LoadSample(buffer, compressedSize, uncompressedSize, i);
	}

	free(buffer);
}

void LoadBoxes()
{
	// Read boxes
	int numBoxes = ReadInt32();
	TENLog("Num boxes: " + std::to_string(numBoxes), LogLevel::Info);
	g_Level.PathfindingBoxes.resize(numBoxes);
	ReadBytes(g_Level.PathfindingBoxes.data(), numBoxes * sizeof(BOX_INFO));

	// Read overlaps
	int numOverlaps = ReadInt32();
	TENLog("Num overlaps: " + std::to_string(numOverlaps), LogLevel::Info);
	g_Level.Overlaps.resize(numOverlaps);
	ReadBytes(g_Level.Overlaps.data(), numOverlaps * sizeof(OVERLAP));

	// Read zones
	int numZoneGroups = ReadInt32();
	TENLog("Num zone groups: " + std::to_string(numZoneGroups), LogLevel::Info);

	for (int i = 0; i < 2; i++)
	{
		for (int j = 0; j < numZoneGroups; j++)
		{
			if (j >= (int)ZoneType::MaxZone)
			{
				int excessiveZoneGroups = numZoneGroups - j + 1;
				TENLog("Level file contains extra pathfinding data, number of excessive zone groups is " + 
					std::to_string(excessiveZoneGroups) + ". These zone groups will be ignored.", LogLevel::Warning);
				CurrentDataPtr += numBoxes * sizeof(int);
			}
			else
			{
				g_Level.Zones[j][i].resize(numBoxes);
				ReadBytes(g_Level.Zones[j][i].data(), numBoxes * sizeof(int));
			}
		}
	}

	// By default all blockable boxes are blocked
	for (int i = 0; i < numBoxes; i++)
	{
		if (g_Level.PathfindingBoxes[i].flags & BLOCKABLE)
			g_Level.PathfindingBoxes[i].flags |= BLOCKED;
	}
}

bool LoadLevelFile(int levelIndex)
{
	const auto& level = *g_GameFlow->GetLevel(levelIndex);

	auto assetDir = g_GameFlow->GetGameDir();
	auto levelPath = assetDir + level.FileName;

	if (!std::filesystem::is_regular_file(levelPath))
	{
		TENLog("Level file not found: " + levelPath, LogLevel::Error);
		return false;
	}

	TENLog("Loading level file: " + levelPath, LogLevel::Info);

	auto timestamp  = std::filesystem::last_write_time(levelPath);
	bool fastReload = (g_GameFlow->GetSettings()->FastReload && levelIndex == CurrentLevel && timestamp == LastLevelTimestamp && levelPath == LastLevelFilePath);

	// Dumping game scene right after engine launch is impossible, as no scene exists.
	if (!FirstLevel && fastReload)
		g_Renderer.DumpGameScene();

	auto loadingScreenPath = TEN::Utils::ToWString(assetDir + level.LoadScreenFileName);
	g_Renderer.SetLoadingScreen(fastReload ? std::wstring{} : loadingScreenPath);

	BackupLara();
	StopAllSounds();
	CleanUp();
	FreeLevel(fastReload);
	
	LevelLoadTask = std::async(std::launch::async, LoadLevel, levelPath, fastReload);

	return LevelLoadTask.get();
}

void LoadSprites()
{
	int numSprites = ReadInt32();
	g_Level.Sprites.resize(numSprites);

	TENLog("Num sprites: " + std::to_string(numSprites), LogLevel::Info);

	for (int i = 0; i < numSprites; i++)
	{
		auto* spr = &g_Level.Sprites[i];
		spr->tile = ReadInt32();
		spr->x1 = ReadFloat();
		spr->y1 = ReadFloat();
		spr->x2 = ReadFloat();
		spr->y2 = ReadFloat();
		spr->x3 = ReadFloat();
		spr->y3 = ReadFloat();
		spr->x4 = ReadFloat();
		spr->y4 = ReadFloat();
	}

	int numSequences = ReadInt32();

	TENLog("Num sprite sequences: " + std::to_string(numSequences), LogLevel::Info);

	for (int i = 0; i < numSequences; i++)
	{
		int spriteID = ReadInt32();
		short negLength = ReadInt16();
		short offset = ReadInt16();
		if (spriteID >= ID_NUMBER_OBJECTS)
			StaticObjects[spriteID - ID_NUMBER_OBJECTS].meshNumber = offset;
		else
		{
			Objects[spriteID].nmeshes = negLength;
			Objects[spriteID].meshIndex = offset;
			Objects[spriteID].loaded = true;

			SpriteSequencesIds.push_back(spriteID);
		}
	}
}

void GetCarriedItems()
{
	for (int i = 0; i < g_Level.NumItems; ++i)
		g_Level.Items[i].CarriedItem = NO_VALUE;

	for (int i = 0; i < g_Level.NumItems; ++i)
	{
		auto& item = g_Level.Items[i];
		const auto& object = Objects[item.ObjectNumber];

		if (object.intelligent ||
			(item.ObjectNumber >= ID_SEARCH_OBJECT1 && item.ObjectNumber <= ID_SEARCH_OBJECT3) ||
			(item.ObjectNumber == ID_SARCOPHAGUS))
		{
			for (short linkNumber = g_Level.Rooms[item.RoomNumber].itemNumber; linkNumber != NO_VALUE; linkNumber = g_Level.Items[linkNumber].NextItem)
			{
				auto& item2 = g_Level.Items[linkNumber];

				if (abs(item2.Pose.Position.x - item.Pose.Position.x) < CLICK(2) &&
					abs(item2.Pose.Position.z - item.Pose.Position.z) < CLICK(2) &&
					abs(item2.Pose.Position.y - item.Pose.Position.y) < CLICK(1) &&
					Objects[item2.ObjectNumber].isPickup)
				{
					item2.CarriedItem = item.CarriedItem;
					item.CarriedItem = linkNumber;
					RemoveDrawnItem(linkNumber);
					item2.RoomNumber = NO_VALUE;
				}
			}
		}
	}
}

void GetAIPickups()
{
	for (int i = 0; i < g_Level.NumItems; ++i)
	{
		auto* item = &g_Level.Items[i];
		if (Objects[item->ObjectNumber].intelligent)
		{
			item->AIBits = 0;

			for (int number = 0; number < g_Level.AIObjects.size(); ++number)
			{
				auto* object = &g_Level.AIObjects[number];

				if (abs(object->pos.Position.x - item->Pose.Position.x) < CLICK(2) &&
					abs(object->pos.Position.z - item->Pose.Position.z) < CLICK(2) &&
					object->roomNumber == item->RoomNumber &&
					object->objectNumber < ID_AI_PATROL2)
				{
					item->AIBits = (1 << (object->objectNumber - ID_AI_GUARD)) & 0x1F;
					item->ItemFlags[3] = object->triggerFlags;

					if (object->objectNumber != ID_AI_GUARD)
						object->roomNumber = NO_VALUE;
				}
			}

			if (item->Data.is<CreatureInfo>())
			{
				auto* creature = GetCreatureInfo(item);
				creature->Tosspad |= item->AIBits << 8 | (char)item->ItemFlags[3];
			}
		}
	}
}

void BuildOutsideRoomsTable()
{
	for (int x = 0; x < OUTSIDE_SIZE; x++)
	{
		for (int z = 0; z < OUTSIDE_SIZE; z++)
			OutsideRoomTable[x][z].clear();
	}

	for (int i = 0; i < g_Level.Rooms.size(); i++)
	{
		auto* room = &g_Level.Rooms[i];

		int rx = (room->Position.x / BLOCK(1));
		int rz = (room->Position.z / BLOCK(1));

		for (int x = 0; x < OUTSIDE_SIZE; x++)
		{
			if (x < (rx + 1) || x > (rx + room->XSize - 2))
				continue;

			for (int z = 0; z < OUTSIDE_SIZE; z++)
			{
				if (z < (rz + 1) || z > (rz + room->ZSize - 2))
					continue;

				OutsideRoomTable[x][z].push_back(i);
			}
		}
	}
}

void LoadPortal(ROOM_INFO& room) 
{
	ROOM_DOOR door;

	door.room = ReadInt16();
	door.normal.x = ReadInt32();
	door.normal.y = ReadInt32();
	door.normal.z = ReadInt32();

	for (int k = 0; k < 4; k++)
	{
		door.vertices[k].x = ReadInt32();
		door.vertices[k].y = ReadInt32();
		door.vertices[k].z = ReadInt32();
	}

	room.doors.push_back(door);
}