#pragma once
#include "Game/animation.h"
#include "Game/control/trigger.h"
#include "Game/items.h"
#include "Game/room.h"
#include "Math/Math.h"

class FloorInfo;
class GameBoundingBox;
struct AnimData;
struct CollisionInfo;
struct ItemInfo;
struct MESH_INFO;
struct ROOM_INFO;

enum class GameStatus
{
	Normal,
	NewGame,
	HomeLevel,
	LoadGame,
	SaveGame,
	ExitToTitle,
	ExitGame,
	LaraDead,
	LevelComplete
};

enum class LevelLoadType
{
	New,
	Hub,
	Load
};

enum CardinalDirection
{
	NORTH,
	EAST,
	SOUTH,
	WEST
};

enum FadeStatus
{
	FADE_STATUS_NONE,
	FADE_STATUS_FADEIN,
	FADE_STATUS_FADEOUT
};

constexpr int MAX_ROOMS = 1024;

constexpr auto LOOP_FRAME_COUNT = 2;

extern int GameTimer;
extern int RumbleTimer;
extern int GlobalCounter;

extern bool InitializeGame;
extern bool DoTheGame;
extern bool JustLoaded;
extern bool ThreadEnded;

extern int RequiredStartPos;
extern int CurrentLevel;
extern int NextLevel;
extern int SystemNameHash;

extern bool  InItemControlLoop;
extern short ItemNewRoomNo;
extern short ItemNewRooms[MAX_ROOMS];
extern short NextItemActive;
extern short NextItemFree;
extern short NextFxActive;
extern short NextFxFree;

extern int ControlPhaseTime;

extern std::vector<short> OutsideRoomTable[OUTSIDE_SIZE][OUTSIDE_SIZE];

void DrawPhase(bool isTitle, float interpolationFactor);

GameStatus ControlPhase();
GameStatus DoLevel(int levelIndex, bool loadGame = false);
GameStatus DoGameLoop(int levelIndex);
void EndGameLoop(int levelIndex, GameStatus reason);

GameStatus HandleMenuCalls(bool isTitle);
GameStatus HandleGlobalInputEvents(bool isTitle);
void HandleControls(bool isTitle);

int GetRandomControl();
int GetRandomDraw();

void KillMoveItems();
void KillMoveEffects();
void UpdateShatters();

void CleanUp();

void InitializeOrLoadGame(bool loadGame);
void InitializeScripting(int levelIndex, LevelLoadType type);
void DeInitializeScripting(int levelIndex);

void SetupInterpolation();

unsigned CALLBACK GameMain(void*);
