
// ------------------- SETTINGS ---------------------
#define FILE_SORTED_PATH 		"configs/autogen_maplist/sorted.txt"
#define FILE_DELETE_PATH 		"configs/autogen_maplist/delete.txt"
#define FILE_DISABLED_PATH 		"configs/autogen_maplist/disabled.txt"

#define DEBUG 			1 	// Включает режим дебага
#define ABC_SORT 		0 	// Сортировать карты по алфавиту (Если включён данный пункт, то сортировка из файла sorted.txt не будет работать...)
#define DELETE_MAPS 	0 	// 1 - удаляет карту из сервера и maplist, 0 - удаляет только из списка
#define CLEAR_DIRMAP	0	// Не добавлять карты в директории maps из списка maplist.txt
// ---------------------------------------------------
// Ниже ничего не трогаем!
// ---------------------------------------------------

ArrayList 	g_hMaps, 
			g_hMapsPath,
			g_hDeleteMaps,
			g_hSortMaps,
			g_hDisablePath;

public Plugin myinfo =
{
	name        = 	"Auto Generation MapList",
	author      = 	"FIVE",
	version     = 	"1.1",
	url         = 	"Source: http://hlmod.ru | Support: https://discord.gg/ajW69wN"
};

public void OnPluginStart()
{
	g_hMaps = new ArrayList(ByteCountToCells(64));
	g_hMapsPath = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hDeleteMaps = new ArrayList(ByteCountToCells(64));
	g_hSortMaps = new ArrayList(ByteCountToCells(64));
	g_hDisablePath = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	RegServerCmd("sm_update_maplist", cmd_Update);
}

public void OnServerLoad()
{
	fUpdateMapList();
}

Action cmd_Update(int iArgs)
{
	fUpdateMapList();
	return Plugin_Handled;
}

void fUpdateMapList()
{
	g_hMaps.Clear();
	g_hMapsPath.Clear();
	g_hDeleteMaps.Clear();
	g_hSortMaps.Clear();
	g_hDisablePath.Clear();

	fLoadCfg(FILE_SORTED_PATH, 0);
	fLoadCfg(FILE_DELETE_PATH, 1);
	fLoadCfg(FILE_DISABLED_PATH, 2);
	
	fLoadMaps("maps");

	#if DEBUG == 2
	fPrintDebug();
	return;
	#endif


	fClearDisabledPath();
	fDeleteMaps();

	#if ABC_SORT == 1
	g_hMaps.Sort(Sort_Ascending, Sort_String);
	#else
	fResortMaps();
	#endif

	fSaveList("maplist.txt");
	fSaveList("mapcycle.txt");

	#if DEBUG == 1
	fPrintDebug();
	#endif
}

stock void fLoadMaps(const char[] sPath)
{
	FileType iType;
	int fileCounter = 0;
	char sPathFull[PLATFORM_MAX_PATH], sFileName[64];
	
	DirectoryListing dL = OpenDirectory(sPath);

	while ( dL.GetNext(sFileName, sizeof(sFileName), iType) ) 
	{
		if(sFileName[0] == '.') continue;

		Format(sPathFull, sizeof sPathFull, "%s/%s", sPath, sFileName);
		switch(iType)
		{
			case FileType_Directory:
			{
				fLoadMaps(sPathFull);
			}
			case FileType_File:
			{
				if(StrContains(sPathFull, ".bsp") != -1)
				{
					ReplaceString(sFileName, sizeof(sFileName), ".bsp", "", false);
					g_hMaps.PushString(sFileName);
					g_hMapsPath.PushString(sPath);
					//g_hMapsPath.PushString(sPathFull);
					fileCounter++;
				}
			}
		}

		 // Optional to strip the file Ending
		
	} 

	delete dL;

	#if DEBUG == 1
	PrintToServer(" Finded %i maps (on - %s)", fileCounter, sPath);
	#endif
}

stock bool IsDisabledPath(const char[] sPath)
{
	#if CLEAR_DIRMAP == 1
	if(!strcmp(sPath, "maps")) return true;
	#endif
	
	char szBuffer[PLATFORM_MAX_PATH];
	int iSize = g_hDisablePath.Length;
	if(g_hDisablePath.Length > 0)
	{
		for(int i = 0; i < iSize; i++)
		{
			g_hDisablePath.GetString(i, szBuffer, sizeof(szBuffer));

			
			if(StrContains(sPath, szBuffer, true) != -1) 
			{
				// Если впишут maps
				// if(!strcmp(szBuffer, "maps") && !strcmp(sPath, szBuffer)) continue;
				
				return true;
			}
		}
	}
	
	return false;
}

stock void fPrintDebug()
{
	PrintToServer("InfoMaps ---------------------");

	char szBuffer[2][PLATFORM_MAX_PATH];
	int iSize = g_hMaps.Length;
	if(iSize > 0)
	{
		for(int i = 0; i < iSize; i++)
		{
			g_hMaps.GetString(i, szBuffer[0], sizeof(szBuffer[]));
			g_hMapsPath.GetString(i, szBuffer[1], sizeof(szBuffer[]));
			PrintToServer("%i. %s (%s/%s.bsp)", i, szBuffer[0], szBuffer[1], szBuffer[0]);
		}
	}
	else PrintToServer("1. no found files .bsp");

	/*
	PrintToServer(">>>>>>>>>>>>>>>>>>>>>>");

	iSize = g_hMapsPath.Length;

	if(iSize > 0)
	{
		for(int i = 0; i < iSize; i++)
		{
			g_hMapsPath.GetString(i, szBuffer[1], sizeof(szBuffer[]));
			PrintToServer("%i, %s", i, szBuffer[1]);
		}
	}
	*/
}

stock void fSaveList(char[] sPath)
{
	char szBuffer[64];
	Handle hFile = OpenFile(sPath, "w");

	if(hFile)
	{
		
		int iSize = g_hMaps.Length;
		for(int i = 0; i < iSize; i++)
		{
			g_hMaps.GetString(i, szBuffer, sizeof(szBuffer));
			WriteFileLine(hFile, szBuffer);
		}
		
		CloseHandle(hFile);

		Format(szBuffer, sizeof(szBuffer), "[Save List] Success. Added %i to %s", iSize, sPath);
		LogMessage(szBuffer);
	}
	else 
	{
		Format(szBuffer, sizeof(szBuffer), "[Save List] Failed to access %s", sPath);
		LogMessage(szBuffer);
	}
	
}

stock void fResortMaps()
{
	if (g_hMaps.Length < 2 || !g_hSortMaps) return;

	int i, x, iSize, index, iCount;
	iSize = g_hSortMaps.Length;

	x = 0;
	char szItemInfo[128];
	for (i = 0; i < iSize; ++i)
	{
		g_hSortMaps.GetString(i, szItemInfo, sizeof(szItemInfo));
		index = g_hMaps.FindString(szItemInfo);
		if (index != -1)
		{
			if (index != x)
			{
				g_hMaps.SwapAt(index, x);
				g_hMapsPath.SwapAt(index, x);
				iCount++;
			}
			
			++x;
		}
	}

	PrintToServer("[Resort Maps] Count: %i", iCount);
}

stock void fClearDisabledPath()
{
	int iCount, iSize;
	char szBuffer[64];

	iSize = g_hMapsPath.Length;
	if(iSize > 0)
	{
		for(int i = 0; i < iSize; i++)
		{
			g_hMapsPath.GetString(i, szBuffer, sizeof(szBuffer));
			if(IsDisabledPath(szBuffer)) 
			{
				g_hMaps.Erase(i);
				g_hMapsPath.Erase(i);
				i--;
				iSize--;
				iCount++;
			}
		}
	}

	PrintToServer("[Clear Disabled Path] Count: %i", iCount);
}

stock void fDeleteMaps()
{
	int iCount, iSize;
	char szBuffer[64], sPath[PLATFORM_MAX_PATH];

	iSize = g_hDeleteMaps.Length;
	if(iSize > 0)
	{
		for(int i = 0; i < iSize; i++)
		{
			g_hDeleteMaps.GetString(i, szBuffer, sizeof(szBuffer));
			int index = g_hMaps.FindString(szBuffer);
			if(index != -1) 
			{
				g_hMaps.Erase(index);
				g_hMapsPath.GetString(index, sPath, sizeof(sPath));
				Format(szBuffer, sizeof(szBuffer), "%s/%s.bsp", sPath, szBuffer);
				
				#if DELETE_MAPS == 1
				DeleteFile(szBuffer);
				#endif

				g_hMapsPath.Erase(index);
				iCount++;
			}
		}
	}

	PrintToServer("[Delete Maps] Count: %i", iCount);
}

stock void fLoadCfg(char szPath[PLATFORM_MAX_PATH], int iType = 0)
{
	char sPath[PLATFORM_MAX_PATH], sMap[128];
	BuildPath(Path_SM, sPath, sizeof(sPath), szPath);

	if(FileExists(sPath))
	{
		PrintToServer("Loaded: %s ---------------------", szPath);
		File hFile = OpenFile(sPath, "r");
		if (hFile != null)
		{
			while (!hFile.EndOfFile() && hFile.ReadLine(sMap, 128))
			{
				TrimString(sMap);
				if (sMap[0])
				{
					switch(iType)
					{
						case 0: g_hSortMaps.PushString(sMap);
						case 1: g_hDeleteMaps.PushString(sMap);
						case 2: g_hDisablePath.PushString(sMap);
					}
				}
			}
			
			delete hFile;
			
			switch(iType)
			{
				case 0: if ((g_hSortMaps).Length == 0) g_hSortMaps.Clear();
				case 1: if ((g_hDeleteMaps).Length == 0) g_hDeleteMaps.Clear();
				case 2: if ((g_hDisablePath).Length == 0) g_hDisablePath.Clear();
			}
		}
	}
	else PrintToServer("Failed Loaded: %s ---------------------", szPath);
}
