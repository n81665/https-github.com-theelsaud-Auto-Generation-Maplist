
// ------------------- SETTINGS ---------------------
#define FILE_SORTED_PATH 		"configs/autogen_maplist/sorted.txt"
#define FILE_DELETE_PATH 		"configs/autogen_maplist/delete.txt"

#define DEBUG 0
#define INCLUDE_MAPS 1
#define INCLUDE_WS_MAPS 1
#define ABC_SORT 1

ArrayList g_hMaps;
ArrayList g_hDeleteMaps;
ArrayList g_hSortMaps;

public Plugin myinfo =
{
	name        = 	"Auto Generation MapList",
	author      = 	"FIVE",
	version     = 	"1.0",
	url         = 	"Source: http://hlmod.ru | Support: https://discord.gg/ajW69wN"
};

public void OnPluginStart()
{
	g_hMaps = new ArrayList(ByteCountToCells(64));
	g_hDeleteMaps = new ArrayList(ByteCountToCells(64));
	g_hSortMaps = new ArrayList(ByteCountToCells(64));

	RegServerCmd("sm_update_maplist", cmd_Update);
}

public void OnServerLoad()
{
	fUpdateMapList();
}

Action cmd_Update(int iArgs)
{
	OnServerLoad();
    return Plugin_Handled;
}

void fUpdateMapList()
{
	g_hMaps.Clear();
	g_hDeleteMaps.Clear();
	g_hSortMaps.Clear();

	fLoadCfg(FILE_SORTED_PATH, 0);
	fLoadCfg(FILE_DELETE_PATH, 1);
	
	#if INCLUDE_MAPS == 1
	fLoadMaps();
	#endif

	#if INCLUDE_WS_MAPS == 1
	fLoadWorkshopMaps();
	#endif

	fDeleteMaps();
	fResortMaps();

	fSaveList("maplist.txt");
	fSaveList("mapcycle.txt");

	#if DEBUG == 1
	fPrintDebug();
	#endif
}

stock void fPrintDebug()
{
	PrintToServer("InfoMaps ---------------------");

	char szBuffer[PLATFORM_MAX_PATH];
	int iSize;
	iSize = g_hMaps.Length;
	if(g_hMaps.Length > 0)
	{
		for(int i = 0; i < iSize; i++)
		{
			g_hMaps.GetString(i, szBuffer, sizeof(szBuffer));
			PrintToServer("%i. %s", i, szBuffer);
		}
	}
	else PrintToServer("1. no found files .bsp");
}

stock void fLoadMaps()
{
	PrintToServer("Load Maps ---------------------");
	
	int fileCounter = 0;
	char fileBuffer[256][64];
	if (!DirExists("maps")) return;
	
	
	DirectoryListing dL = OpenDirectory("maps");
	while ( dL.GetNext(fileBuffer[fileCounter], sizeof(fileBuffer[])) ) 
	{
		 // Optional to strip the file Ending
		if(StrContains(fileBuffer[fileCounter], ".bsp") != -1)
		{
			ReplaceString(fileBuffer[fileCounter], sizeof(fileBuffer), ".bsp", "", false);
			g_hMaps.PushString(fileBuffer[fileCounter]);
			//PrintToServer(fileBuffer[fileCounter]);
			fileCounter++;
		}
	} 

	CloseHandle(dL);

	PrintToServer(" Finded %i maps.", fileCounter);
}

stock void fLoadWorkshopMaps()
{
	PrintToServer("Load Workshop Maps ---------------------");

	int fileCounter = 0;
	char fileBuffer[256][64], szPath[PLATFORM_MAX_PATH];
	if (!DirExists("maps/workshop")) return;
	
	
	DirectoryListing dL = OpenDirectory("maps/workshop");
	while ( dL.GetNext(fileBuffer[fileCounter], sizeof(fileBuffer[])) ) 
	{
		if(strcmp(fileBuffer[fileCounter], "..") != 0 && strcmp(fileBuffer[fileCounter], ".") != 0)
		{
			FormatEx(szPath, sizeof(szPath), "maps/workshop/%s", fileBuffer[fileCounter]);
			DirectoryListing dLWS = OpenDirectory(szPath);

			while ( dLWS.GetNext(fileBuffer[fileCounter], sizeof(fileBuffer[])) ) 
			{

				if(StrContains(fileBuffer[fileCounter], ".bsp") != -1 && (strcmp(fileBuffer[fileCounter], "..") != 0 && strcmp(fileBuffer[fileCounter], ".")))
				{
					ReplaceString(fileBuffer[fileCounter], sizeof(fileBuffer), ".bsp", "", false);
					g_hMaps.PushString(fileBuffer[fileCounter]);
					//PrintToServer(fileBuffer[fileCounter]);
					fileCounter++;
				}
			}

			CloseHandle(dLWS);
		}  
	} 

	CloseHandle(dL);

	PrintToServer(" Finded %i workshop maps.", fileCounter);
}

stock void fSaveList(char[] sPath)
{
	PrintToServer("Save List ---------------------");

	Handle hFile = OpenFile(sPath, "w");

	char szBuffer[64];
	int iSize = g_hMaps.Length;
	for(int i = 0; i < iSize; i++)
	{
		g_hMaps.GetString(i, szBuffer, sizeof(szBuffer));
		WriteFileLine(hFile, szBuffer);
	}
	
	CloseHandle(hFile);

	PrintToServer(" Success. Added %i to %s", iSize, sPath);
}

stock void fResortMaps()
{
	PrintToServer("Resort Maps ---------------------");

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
				iCount++;
			}
			
			++x;
		}
	}

	PrintToServer(" Count: %i", iCount);
}

stock void fDeleteMaps()
{
	PrintToServer("Delete Maps ---------------------");

	int iCount, iSize;
	char szBuffer[64];

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
				iCount++;
			}
		}
	}

	PrintToServer(" Count: %i", iCount);
}

stock void fLoadCfg(char szPath[PLATFORM_MAX_PATH], int iType = 0)
{
	char sPath[PLATFORM_MAX_PATH], sMap[128];
	BuildPath(Path_SM, sPath, sizeof(sPath), szPath);

	if(FileExists(sPath))
	{
		PrintToServer("Load: %s ---------------------", szPath);
		File hFile = OpenFile(sPath, "r");
		if (hFile != null)
		{
			while (!hFile.EndOfFile() && hFile.ReadLine(sMap, 128))
			{
				TrimString(sMap);
				//PrintToChatAll(szFeature);
				if (sMap[0])
				{
					if(iType == 0) g_hSortMaps.PushString(sMap);
					else g_hDeleteMaps.PushString(sMap);
				}
			}
			
			delete hFile;
			
			if(iType == 0)
			{
				if ((g_hSortMaps).Length == 0)
				{
					g_hSortMaps.Clear();
				}
			}
			else 
			{
				if ((g_hDeleteMaps).Length == 0)
				{
					g_hDeleteMaps.Clear();
				}
			}
		}
	}
}
