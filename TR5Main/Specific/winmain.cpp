#include "game.h"
#include "init.h"
#include "winmain.h"
#include <CommCtrl.h>
#include "..\resource.h"

#include <process.h>
#include <crtdbg.h>
#include <stdio.h>
#include <sol.hpp>

#include "..\Game\draw.h"
#include "..\Game\sound.h"
#include "..\Game\inventory.h"
#include "..\Game\control.h"
#include "..\Game\gameflow.h"
#include "..\Game\savegame.h"
#include "..\Specific\roomload.h"

WINAPP	 App;
unsigned int threadId;
uintptr_t hThread;
HACCEL hAccTable;
byte receivedWmClose = false;

extern __int32 IsLevelLoading;
extern GameFlow* g_GameFlow;
extern GameScript* g_GameScript;

__int32 __cdecl WinProcMsg()
{
	int result;
	struct tagMSG Msg;

	DB_Log(2, "WinProcMsg");
	do
	{
		GetMessageA(&Msg, 0, 0, 0);
		if (!TranslateAcceleratorA(WindowsHandle, hAccTable, &Msg))
		{
			TranslateMessage(&Msg);
			DispatchMessageA(&Msg);
		}
		result = Unk_876C48;
	} while (!Unk_876C48 && Msg.message != WM_QUIT);

	return result;
}

void __stdcall HandleWmCommand(unsigned __int16 wParam)
{
	if (wParam == 8)
	{
		DB_Log(5, "Pressed ALT + ENTER");

		if (!IsLevelLoading)
		{
			SuspendThread((HANDLE)hThread);
			DB_Log(5, "Game thread suspended");
			
			g_Renderer->ToggleFullScreen();

			ResumeThread((HANDLE)hThread);
			DB_Log(5, "Game thread resumed");

			if (g_Renderer->IsFullsScreen())
			{
				SetCursor(0);
				ShowCursor(false);
			}
			else
			{
				SetCursor(LoadCursorA(App.hInstance, (LPCSTR)0x68));
				ShowCursor(true);
			}
		}
	}
}

LRESULT CALLBACK WinAppProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	if (msg > 0x10)
	{
		if (msg == WM_COMMAND)
		{
			DB_Log(6, "WM_COMMAND");
			HandleWmCommand((unsigned __int16)wParam);
		}

		return DefWindowProcA(hWnd, msg, wParam, (LPARAM)lParam);
	}

	if (msg == WM_CLOSE)
	{
		DB_Log(6, "WM_CLOSE");
		receivedWmClose = true;
		PostQuitMessage(0);
		return DefWindowProcA(hWnd, 0x10u, wParam, (LPARAM)lParam);
	}

	if (msg == WM_CREATE)
	{
		DB_Log(6, "WM_CREATE");
		// Old renderer setted a counter, not used anymore
		return DefWindowProcA(hWnd, 1u, wParam, (LPARAM)lParam);
	}

	if (msg == WM_MOVE)
	{
		DB_Log(6, "WM_MOVE");
		// With DX6 it was needed to handle DirectDraw surface move, not needed with DX9
		return DefWindowProcA(hWnd, msg, wParam, (LPARAM)lParam);
	}

	if (msg != WM_ACTIVATE)
	{
		return DefWindowProcA(hWnd, msg, wParam, (LPARAM)lParam);
	}

	DB_Log(6, "WM_ACTIVATE");

	if (receivedWmClose)
	{
		return DefWindowProcA(hWnd, msg, wParam, (LPARAM)lParam);
	}

	if (App_Unk00D9AC2B)
		return 0;

	if ((__int16)wParam)
	{
		if ((signed __int32)(unsigned __int16)wParam > 0 && (signed __int32)(unsigned __int16)wParam <= 2)
		{
			DB_Log(6, "WM_ACTIVE");

			if (App_Unk00D9AC19)
			{
				//AcquireDirectInput(true);
				ResumeThread((HANDLE)hThread);
				App_Unk00D9ABFD = 0;

				DB_Log(5, "Game Thread Resumed");

				return 0;
			}
		}
	}
	else
	{
		DB_Log(6, "WM_INACTIVE");

		if (App_Unk00D9AC19)
		{
			//AcquireDirectInput(false);

			DB_Log(5, "HangGameThread");

			//if (ptr_ctx->isInScene)
			//	WaitForInSceneMaybe();
			App_Unk00D9ABFD = 1;
			//if (!ptr_ctx->isInScene)
			//	WaitForInSceneMaybe();

			SuspendThread((HANDLE)hThread);

			DB_Log(5, "Game Thread Suspended");
		}
	}
	return 0;
}

void LoadResolutionsInCombobox(HWND handle, __int32 index)
{
	HWND cbHandle = GetDlgItem(handle, IDC_CB_MODES);

	SendMessageA(cbHandle, CB_RESETCONTENT, 0, 0);

	auto adapters = g_Renderer->GetAdapters();
	auto adapter = (*adapters)[index];

	for (__int32 i = 0; i < adapter->DisplayModes.size(); i++)
	{
		auto mode = (adapter->DisplayModes)[i];

		char* str = (char*)malloc(255);
		ZeroMemory(str, 255);
		sprintf(str, "%d x %d (%d Hz)", mode->Width, mode->Height, mode->RefreshRate);

		SendMessageA(cbHandle, CB_ADDSTRING, i, (LPARAM)(str));
		
		free(str);
	}

	SendMessageA(cbHandle, CB_SETCURSEL, 0, 0);
}

void LoadAdaptersInCombobox(HWND handle)
{
	HWND cbHandle = GetDlgItem(handle, IDC_CB_ADAPTERS);

	SendMessageA(cbHandle, CB_RESETCONTENT, 0, 0);

	auto adapters = g_Renderer->GetAdapters();
	for (__int32 i = 0; i < adapters->size(); i++)
	{
		SendMessageA(cbHandle, CB_ADDSTRING, i, (LPARAM)(*adapters)[i]->Name.c_str());
	}

	SendMessageA(cbHandle, CB_SETCURSEL, 0, 0);
	LoadResolutionsInCombobox(handle, 0);
}

BOOL CALLBACK DialogProc(HWND handle, UINT msg, WPARAM wParam, LPARAM lParam)
{
	HWND ctlHandle;

	switch (msg)
	{
	case WM_INITDIALOG:
		DB_Log(6, "WM_INITDIALOG");

		LoadAdaptersInCombobox(handle);

		break;

	case WM_COMMAND:
		DB_Log(6, "WM_COMMAND");

		break;

	default:
		return 0;
	}
}

__int32 SetupDialog()
{
	InitCommonControls();
	HRSRC res = FindResource(g_DllHandle, MAKEINTRESOURCE(IDD_SETUP_WINDOW), RT_DIALOG);

	ShowCursor(true);
	__int32 result = DialogBoxParamA(g_DllHandle, MAKEINTRESOURCE(IDD_SETUP_WINDOW), 0, (DLGPROC)DialogProc, 0);
	ShowCursor(false);
	
	//printf("%d\n", GetLastError());

	//ShowWindow(result, SW_SHOW);

	return true;
}

__int32 __stdcall WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, __int32 nShowCmd)
{
	int RetVal;
	int n;

	// Clear Application Structure
	memset(&App, 0, sizeof(WINAPP));

	_CrtSetReportMode(0, 2);
	_CrtSetDbgFlag(-1);
	 
	// TODO: deprecated
	LoadGameflow();
	LoadSettings();

	// Initialise the new scripting system
	sol::state luaState;
	luaState.open_libraries(sol::lib::base);

	g_GameFlow = new GameFlow(&luaState);
	g_GameFlow->ExecuteScript("Scripts\\English.lua");
	g_GameFlow->ExecuteScript("Scripts\\Settings.lua");
	g_GameFlow->ExecuteScript("Scripts\\Gameflow.lua");

	g_GameScript = new GameScript(&luaState);

	// Initialise chunks for savegames
	SaveGame::Start();

	App.hInstance = hInstance;
	App.WindowClass.hIcon = NULL;
	App.WindowClass.lpszMenuName = NULL;
	App.WindowClass.lpszClassName = "TR5Main";
	App.WindowClass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
	App.WindowClass.hInstance = hInstance;
	App.WindowClass.style = CS_VREDRAW | CS_HREDRAW;
	App.WindowClass.lpfnWndProc = (WNDPROC)WinAppProc;
	App.WindowClass.cbClsExtra = 0;
	App.WindowClass.cbWndExtra = 0;
	App.WindowClass.hCursor = LoadCursor(App.hInstance, IDC_ARROW);

	if (!RegisterClass(&App.WindowClass))
	{
		printf("Unable To Register Window Class\n");
		return FALSE;
	}

	tagRECT Rect;

	Rect.left = 0;
	Rect.top = 0;
	Rect.right = g_GameFlow->GetSettings()->ScreenWidth;
	Rect.bottom = g_GameFlow->GetSettings()->ScreenHeight;

	AdjustWindowRect(&Rect, WS_CAPTION, false);

	App.WindowHandle = CreateWindowEx(
		WS_THICKFRAME,
		"TR5Main",
		g_GameFlow->GetSettings()->WindowTitle.c_str(),
		WS_BORDER,
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		Rect.right - Rect.left,
		Rect.bottom - Rect.top,
		nullptr,
		nullptr,
		App.hInstance,
		nullptr
	);

	if (!App.WindowHandle)
	{
		printf("Unable To Create Window: %d\n", GetLastError());
		return FALSE;
	}

	// TODO: load settings from Windows registry
	OptionAutoTarget = 1;

	// Create the renderer and enumerate adapters and video modes
	g_Renderer = new Renderer();
	g_Renderer->Create();
	g_Renderer->EnumerateVideoModes();

	// Now show the setup dialog
	SetupDialog();

	PhdWidth = g_GameFlow->GetSettings()->ScreenWidth;
	PhdHeight = g_GameFlow->GetSettings()->ScreenHeight;

	// Initialise the renderer
	g_Renderer->Initialise(g_GameFlow->GetSettings()->ScreenWidth, g_GameFlow->GetSettings()->ScreenHeight, true, App.WindowHandle);

	// Initialize audio
	Sound_Init();

	// Initialise the new inventory
	g_Inventory = new Inventory();

	SetWindowPos(App.WindowHandle, 0, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE);

	WindowsHandle = App.WindowHandle;

	App.bNoFocus = false;
	App.isInScene = false;

	UpdateWindow(WindowsHandle);
	ShowWindow(WindowsHandle, nShowCmd);

	SetCursor(0);
	ShowCursor(0);
	hAccTable = LoadAcceleratorsA(hInstance, (LPCSTR)0x65);

	SoundActive = false;
	DoTheGame = true;

	Unk_876C48 = false;
	hThread = _beginthreadex(0, 0, &GameMain, 0, 0, &threadId);
	WinProcMsg();
	Unk_876C48 = true;

	while (DoTheGame);
	
	WinClose();

	return 0;
}

__int32 __cdecl WinClose()
{
	DB_Log(2, "WinClose - DLL");

	DestroyAcceleratorTable(hAccTable);
	
	delete g_Renderer;
	delete g_Inventory;
	delete g_GameFlow;

	SaveGame::End();

	return 0;
}


void Inject_WinMain()
{
	INJECT(0x004D23E0, WinClose);
	INJECT(0x004D24C0, WinProcMsg);
	INJECT(0x004D1C00, WinMain);
}