#pragma semicolon 1
#pragma newdecls required
 
#include <sdktools>
#include <multicolors>
public Plugin myinfo = 
{
	name = "Ragequit",
	author = "yuv41",
	description = "",
	version = "1.0",
	url = "https://yuv41.com"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_rq", Command_RageQuit);
	RegConsoleCmd("sm_ragequit", Command_RageQuit);
	LoadTranslations("ragequit.phrases");
}
 

public Action Command_RageQuit(int client, int args)
  
{
	if (!client) return Plugin_Handled;
	
	CPrintToChatAll("%t", "Rage Quitter", client);
	KickClient(client, "Ragequitted");
	return Plugin_Handled;
}
