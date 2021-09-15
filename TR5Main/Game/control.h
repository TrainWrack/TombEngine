#pragma once

#include "Specific\phd_global.h"
#include "items.h"
#include "room.h"
#include "control\trigger.h"

struct BOUNDING_BOX;
struct ITEM_INFO;
struct COLL_INFO;
class FLOOR_INFO;
struct ANIM_STRUCT;
struct MESH_INFO;
struct ROOM_INFO;

enum GAME_STATUS
{
	GAME_STATUS_NONE,
	GAME_STATUS_NEW_GAME,
	GAME_STATUS_LOAD_GAME,
	GAME_STATUS_SAVE_GAME,
	GAME_STATUS_EXIT_TO_TITLE,
	GAME_STATUS_EXIT_GAME,
	GAME_STATUS_LARA_DEAD,
	GAME_STATUS_LEVEL_COMPLETED
};

enum HEADINGS
{
	NORTH,
	EAST,
	SOUTH,
	WEST
};

enum COMMAND_TYPES
{
	COMMAND_NULL = 0,
	COMMAND_MOVE_ORIGIN,
	COMMAND_JUMP_VELOCITY,
	COMMAND_ATTACK_READY,
	COMMAND_DEACTIVATE,
	COMMAND_SOUND_FX,
	COMMAND_EFFECT
};

#define OUTSIDE_Z 64
#define OUTSIDE_SIZE 108

extern bool InItemControlLoop;
extern short ItemNewRoomNo;
extern short ItemNewRooms[512];
extern short NextFxActive;
extern short NextFxFree;
extern short NextItemActive;
extern short NextItemFree;
extern bool DisableLaraControl;
extern int WeatherType;
extern int LaraDrawType;
extern int Wibble;
extern int GameTimer;
extern short GlobalCounter;
extern int LevelComplete;
#ifndef NEW_INV
extern int LastInventoryItem;
#endif
extern bool InitialiseGame;
extern int RequiredStartPos;
extern int WeaponDelay;
extern int WeaponEnemyTimer;
extern int CurrentLevel;
extern bool DoTheGame;
extern bool ThreadEnded;
extern bool JustLoaded;
extern bool OldLaraBusy;
extern std::vector<short> OutsideRoomTable[OUTSIDE_SIZE][OUTSIDE_SIZE];
extern short IsRoomOutsideNo;

GAME_STATUS DoTitle(int index);
GAME_STATUS DoLevel(int index, std::string ambient, bool loadFromSavegame);
GAME_STATUS ControlPhase(int numFrames, int demoMode);

int GetRandomControl();
int GetRandomDraw();

int GetChange(ITEM_INFO* item, ANIM_STRUCT* anim);
void AnimateItem(ITEM_INFO* item);
void TranslateItem(ITEM_INFO* item, int x, int y, int z);
void KillMoveItems();
void KillMoveEffects();

int IsObjectInRoom(short roomNumber, short objectNumber);
int IsRoomOutside(int x, int y, int z);

void RumbleScreen();
void RefreshCamera(short type, short* data);

void ResetGlobals();

void AnimateWaterfalls();

void AlterFloorHeight(ITEM_INFO* item, int height);
int GetFloorHeight(FLOOR_INFO* floor, int x, int y, int z);
FLOOR_INFO* GetFloor(int x, int y, int z, short* roomNumber);
int GetCeiling(FLOOR_INFO* floor, int x, int y, int z);

int ExplodeItemNode(ITEM_INFO* item, int Node, int NoXZVel, int bits);

int GetWaterSurface(int x, int y, int z, short roomNumber);
int GetWaterHeight(int x, int y, int z, short roomNumber);


unsigned CALLBACK GameMain(void*);