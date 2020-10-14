/* <DR.API AFK MANAGER> (c) by <De Battista Clint - (http://doyou.watch)     */
/*                                                                           */
/*                  <DR.API AFK MANAGER> is licensed under a                 */
/* Creative Commons Attribution-NonCommercial-NoDerivs 4.0 Unported License. */
/*																			 */
/*      You should have received a copy of the license along with this       */
/*  work.  If not, see <http://creativecommons.org/licenses/by-nc-nd/4.0/>.  */
//***************************************************************************//
//***************************************************************************//
//****************************DR.API AFK MANAGER*****************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1 

//***********************************//
//*************DEFINE****************//
//***********************************//
#define TAG_AFK_MANAGER_CSGO 			"[AFK MANAGER] - "
#define PLUGIN_VERSION_AFK_MANAGER_CSGO "1.0.1"
#define CVARS 							FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY
#define DEFAULT_FLAGS 					FCVAR_PLUGIN|FCVAR_NOTIFY
#define CHECK_ADMIN_IMMUNITY(%1) 		(C_admin_flag == 0 ? GetUserFlagBits(%1)!=0 : (GetUserFlagBits(%1) & C_admin_flag || GetUserFlagBits(%1) & ADMFLAG_ROOT))
#define AFK_CHECK_INTERVAL_CSGO 		5.0
#define AFK_THRESHOLD_CSGO 				30.0 //AFK_THRESHOLD_CSGO for amount of movement required to mark a player as AFK.

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <autoexec>
#include <csgocolors>

#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_active_afk_manager_csgo;
Handle cvar_active_afk_manager_csgo_dev;

Handle cvar_active_afk_manager_move_min_csgo;
Handle cvar_active_afk_manager_kick_min_csgo;
Handle cvar_active_afk_manager_move_time_csgo;
Handle cvar_active_afk_manager_kick_time_csgo;
Handle cvar_active_afk_manager_warn_time_csgo;
Handle cvar_active_afk_manager_immune_csgo;
Handle cvar_active_afk_manager_immune_flag_csgo;

Handle Forward_MoveSpec;

//Bool
bool B_active_afk_manager_csgo 							= false;
bool B_active_afk_manager_csgo_dev						= false;
bool B_client_is_in[MAXPLAYERS+1]						= false;

bool B_RoundEnd											= false;

//Float
float F_active_afk_manager_move_time_csgo;
float F_active_afk_manager_kick_time_csgo;
float F_active_afk_manager_warn_time_csgo;

float F_client_afk_time_csgo[MAXPLAYERS+1]				= {0.0, ...};
float F_client_eye_position_csgo[MAXPLAYERS+1][3];
float F_client_origin_position_csgo[MAXPLAYERS+1][3];

//Customs
int C_active_afk_manager_move_min_csgo;
int C_active_afk_manager_kick_min_csgo;
int C_active_afk_manager_immune_csgo;

//GetEntProp(client, Prop_Send, "m_iObserverMode");
/* mode 0 = playing view */
/* mode 2 = when die view */
/* mode 4 = first view */
/* mode 5 = third view */
/* mode 6 = free view */

int C_observer_mode_csgo[MAXPLAYERS+1];
int C_observer_target_csgo[MAXPLAYERS+1];
int C_admin_flag;

//Informations plugin
public Plugin myinfo =
{
	name = "DR.API AFK MANAGER",
	author = "Dr. Api",
	description = "DR.API AFK MANAGER by Dr. Api",
	version = PLUGIN_VERSION_AFK_MANAGER_CSGO,
	url = "http://doyou.watch"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	AutoExecConfig_SetFile("drapi_afk_manager", "sourcemod/drapi");
	
	LoadTranslations("drapi/drapi_afk_manager.phrases");
	
	AutoExecConfig_CreateConVar("drapi_afk_manager_version", PLUGIN_VERSION_AFK_MANAGER_CSGO, "Version", CVARS);
	
	cvar_active_afk_manager_csgo 					= AutoExecConfig_CreateConVar("drapi_active_afk_manager",  				"1", 					"Enable/Disable AFK Manager", 											DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	cvar_active_afk_manager_csgo_dev				= AutoExecConfig_CreateConVar("drapi_active_afk_manager_dev", 			"0", 					"Enable/Disable AFK Manager Dev Mod", 									DEFAULT_FLAGS, 		true, 0.0, 		true, 1.0);
	
	cvar_active_afk_manager_move_min_csgo			= AutoExecConfig_CreateConVar("drapi_afk_manager_move_min", 			"4", 					"Minimum player to move player", 										DEFAULT_FLAGS);
	cvar_active_afk_manager_kick_min_csgo			= AutoExecConfig_CreateConVar("drapi_afk_manager_kick_min", 			"6", 					"Minimum player to kick player", 										DEFAULT_FLAGS);
	cvar_active_afk_manager_move_time_csgo			= AutoExecConfig_CreateConVar("drapi_afk_manager_move_time", 			"60.0", 				"Time to move player", 													DEFAULT_FLAGS);
	cvar_active_afk_manager_kick_time_csgo			= AutoExecConfig_CreateConVar("drapi_afk_manager_kick_time", 			"120.0", 				"Time to kick player", 													DEFAULT_FLAGS);
	cvar_active_afk_manager_warn_time_csgo			= AutoExecConfig_CreateConVar("drapi_afk_manager_warn_time", 			"30.0", 				"Time to show warining message", 										DEFAULT_FLAGS);
	cvar_active_afk_manager_immune_csgo				= AutoExecConfig_CreateConVar("drapi_afk_manager_immune", 				"1", 					"AFK admins immunity: 0 = DISABLED, 1 = COMPLETE, 2 = KICK, 3 = MOVE", 	DEFAULT_FLAGS);
	cvar_active_afk_manager_immune_flag_csgo		= AutoExecConfig_CreateConVar("drapi_afk_manager_immune_flag", 			"", 					"Admin flag for immunity, blank=any flag", 								DEFAULT_FLAGS);
	
	SetImmuneFlagCsgo(cvar_active_afk_manager_immune_flag_csgo);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	
	
	
	HookEvents();
	
	AddCommandListener(Command_AfkManagerCsgoSay, "say");
	AddCommandListener(Command_AfkManagerCsgoSay, "say_team");
	
	RegAdminCmd("sm_afkcheck",		Command_AfkManagerCsgo, 		ADMFLAG_CHANGEMAP, 		"Display afk manager infos.");
	
	Forward_MoveSpec = CreateGlobalForward("AFK_OnMoveToSpec", ET_Ignore, Param_Cell);
	
	AutoExecConfig_ExecuteFile();
}

/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEvents()
{
	HookConVarChange(cvar_active_afk_manager_csgo, 				Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_csgo_dev, 			Event_CvarChange);
	
	HookConVarChange(cvar_active_afk_manager_move_min_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_kick_min_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_move_time_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_kick_time_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_warn_time_csgo, 	Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_immune_csgo, 		Event_CvarChange);
	HookConVarChange(cvar_active_afk_manager_immune_flag_csgo, 	Event_CvarChange);
}

/***********************************************************/
/******************** WHEN CVARS CHANGE ********************/
/***********************************************************/
public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue)
{
	UpdateState();
}

/***********************************************************/
/*********************** UPDATE STATE **********************/
/***********************************************************/
void UpdateState()
{
	B_active_afk_manager_csgo 					= GetConVarBool(cvar_active_afk_manager_csgo);
	B_active_afk_manager_csgo_dev 				= GetConVarBool(cvar_active_afk_manager_csgo_dev);
	
	C_active_afk_manager_move_min_csgo 			= GetConVarInt(cvar_active_afk_manager_move_min_csgo);
	C_active_afk_manager_kick_min_csgo 			= GetConVarInt(cvar_active_afk_manager_kick_min_csgo);
	C_active_afk_manager_immune_csgo 			= GetConVarInt(cvar_active_afk_manager_immune_csgo);
	
	F_active_afk_manager_move_time_csgo 		= GetConVarFloat(cvar_active_afk_manager_move_time_csgo);
	F_active_afk_manager_kick_time_csgo 		= GetConVarFloat(cvar_active_afk_manager_kick_time_csgo);
	F_active_afk_manager_warn_time_csgo 		= GetConVarFloat(cvar_active_afk_manager_warn_time_csgo);
	
	SetImmuneFlagCsgo(cvar_active_afk_manager_immune_flag_csgo);
	
	if(B_active_afk_manager_csgo)
	{
		CreateTimer(AFK_CHECK_INTERVAL_CSGO, Timer_CheckPlayerAfkManagerCsgo, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		for (int i=1; i<=MaxClients; i++)
		{
			B_client_is_in[i] = false;
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			{
				InitializePlayerCsgo(i);
			}
		}
	}
}

/***********************************************************/
/******************* WHEN CONFIG EXECUTED ******************/
/***********************************************************/
public void OnConfigsExecuted()
{
	//UpdateState();
}

/***********************************************************/
/********************* WHEN MAP START **********************/
/***********************************************************/
public void OnMapStart()
{
	UpdateState();
}

/***********************************************************/
/************ WHEN CLIENT CONNECT WITH CHECKING ************/
/***********************************************************/
public void OnClientPostAdminCheck(int client)
{
	if(B_active_afk_manager_csgo)
	{
		if(!IsFakeClient(client))
		{
			B_client_is_in[client] = true;
		}
	}
}

/***********************************************************/
/***************** WHEN CLIENT DISCONNECT ******************/
/***********************************************************/
public void OnClientDisconnect(int client)
{
	if(B_active_afk_manager_csgo)
	{
		B_client_is_in[client] = false;
	}
}

/***********************************************************/
/******************** WHEN PLAYER SPAWN ********************/
/***********************************************************/
public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if(B_active_afk_manager_csgo)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if(Client_IsIngame(client) && !IsFakeClient(client) && !IsClientObserver(client) && IsPlayerAlive(client))
		{
			ResetPlayerInfosCsgo(client);
			
			if(B_active_afk_manager_csgo_dev)
			{
				PrintToChatAll("%sClient spawn, is alive so we reset infos.", TAG_AFK_MANAGER_CSGO);
			}
		}
	}
}

/***********************************************************/
/***************** WHEN PLAYER CHANGE TEAM *****************/
/***********************************************************/
public void Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	if(B_active_afk_manager_csgo)
	{
		int client 	= GetClientOfUserId(GetEventInt(event, "userid"));
		int team 	= GetEventInt(event, "team");
		if(Client_IsIngame(client) && !IsFakeClient(client))
		{
			if(!B_client_is_in[client])
			{
				InitializePlayerCsgo(client);
				
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sClient not in so we init him.", TAG_AFK_MANAGER_CSGO);
				}
			}
			
			if(team != 1)
			{
				if(B_client_is_in[client])
				{
					ResetPlayerInfosCsgo(client);
					
					if(B_active_afk_manager_csgo_dev)
					{
						PrintToChatAll("%sTeam != Spec and client is in.", TAG_AFK_MANAGER_CSGO);
					}
				}
			}
			else
			{
				GetClientEyeAngles(client, F_client_eye_position_csgo[client]);
				C_observer_mode_csgo[client] 	= GetEntProp(client, Prop_Send, "m_iObserverMode");
				C_observer_target_csgo[client] 	= GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sEye Angles:%f, Mode:%i, Target:%i", TAG_AFK_MANAGER_CSGO, F_client_eye_position_csgo[client], C_observer_mode_csgo[client] , C_observer_target_csgo[client]);
				}
			}
		}
		CreateTimer(2.0, Timer_CheckAlivePlayers);
	}
}

/***********************************************************/
/******************** WHEN PLAYER DEATH ********************/
/***********************************************************/
public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(B_active_afk_manager_csgo)
	{
		int client 	= GetClientOfUserId(GetEventInt(event, "userid"));
		ResetPlayerInfosCsgo(client);
		
		if(B_active_afk_manager_csgo_dev)
		{
			PrintToChatAll("%sPlayer die so we reset infos.", TAG_AFK_MANAGER_CSGO);
		}
		
		CreateTimer(2.0, Timer_CheckAlivePlayers);
	}
}

/***********************************************************/
/************************ ROUND START **********************/
/***********************************************************/
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	B_RoundEnd = false;
}

/***********************************************************/
/************************* ROUND END ***********************/
/***********************************************************/
public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	B_RoundEnd = true;
}

/***********************************************************/
/**************** TIMER CHECK PLAYER ALIVE *****************/
/***********************************************************/
public Action Timer_CheckAlivePlayers(Handle timer)
{
	int ct = GetPlayersAlive(CS_TEAM_CT, "both");
	int t = GetPlayersAlive(CS_TEAM_T, "both");
	int players = ct + t;
	if(players <= 0 && !B_RoundEnd)
	{
		CS_TerminateRound(1.0, CSRoundEnd_Draw);
	}
}

/***********************************************************/
/********************* IF PLAYER WRITE *********************/
/***********************************************************/
public Action Command_AfkManagerCsgoSay(int client, const char[] command, int args)
{
	if(B_active_afk_manager_csgo)
	{
		ResetPlayerInfosCsgo(client);
		
		if(B_active_afk_manager_csgo_dev)
		{
			PrintToChatAll("%sClient write so we reset infos.", TAG_AFK_MANAGER_CSGO);
		}
	}
}
/***********************************************************/
/******************** RESET PLAYER INFOS *******************/
/***********************************************************/
void ResetPlayerInfosCsgo(int client)
{
	F_client_afk_time_csgo[client] 		= 0.0;
	F_client_eye_position_csgo[client] 	= view_as<float>{0.0,0.0,0.0};
	C_observer_mode_csgo[client] 		= C_observer_target_csgo[client] = 0;
}

/***********************************************************/
/************************ INIT PLAYER **********************/
/***********************************************************/
void InitializePlayerCsgo(int client)
{
	if (!(C_active_afk_manager_immune_csgo == 1 && CHECK_ADMIN_IMMUNITY(client)))
	{
		B_client_is_in[client] = true;
		ResetPlayerInfosCsgo(client);
	}
}

/***********************************************************/
/********************** SET IMMUNE FLAG ********************/
/***********************************************************/
void SetImmuneFlagCsgo(Handle cvar=INVALID_HANDLE)
{
	char S_flags[4];
	AdminFlag C_flag;
	GetConVarString(cvar, S_flags, sizeof(S_flags));
	if (S_flags[0]!='\0' && FindFlagByChar(S_flags[0], C_flag))
	{
		 C_admin_flag = FlagToBit(C_flag);
	}
	else 
	{
		C_admin_flag = 0;
	}
}

/***********************************************************/
/*********************** CHECK IF AFK **********************/
/***********************************************************/
bool CheckObserverAFKCsgo(int client)
{
	int C_last_observer_target; 
	int C_last_observer_mode 	= C_observer_mode_csgo[client];
	C_observer_mode_csgo[client] 	= GetEntProp(client, Prop_Send, "m_iObserverMode");
	if(C_last_observer_mode > 0 && C_observer_mode_csgo[client] != C_last_observer_mode)
	{
		if(B_active_afk_manager_csgo_dev)
		{
			PrintToChatAll("%sObserver mode changed: Last mode:%i, new mode: %i | Client is not AFK", TAG_AFK_MANAGER_CSGO, C_last_observer_mode, C_observer_mode_csgo);
		}
		return false;
	}

	float F_client_eye_location[3];
	F_client_eye_location = F_client_eye_position_csgo[client];
	
	if(C_observer_mode_csgo[client] == 6)
	{
		if(B_active_afk_manager_csgo_dev)
		{
			PrintToChatAll("%sObserver mode: Free view", TAG_AFK_MANAGER_CSGO);
		}
		GetClientEyeAngles(client, F_client_eye_position_csgo[client]);
	}
	else
	{
		C_last_observer_target 		= C_observer_target_csgo[client];
		C_observer_target_csgo[client] 	= GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

		if(C_last_observer_mode == 0 && C_last_observer_target == 0)
		{
			if(B_active_afk_manager_csgo_dev)
			{
				PrintToChatAll("%sObserver mode: 0, observer target: 0 | Client is AFK", TAG_AFK_MANAGER_CSGO);
			}
			return true;
		}

		if(C_last_observer_target > 0 && C_observer_target_csgo[client] != C_last_observer_target)
		{
			if (C_last_observer_target > MaxClients || !IsClientConnected(C_last_observer_target) || !IsClientInGame(C_last_observer_target))
			{
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sObserver target: Old target:%i, new target:%i | Client is not AFK", TAG_AFK_MANAGER_CSGO, C_last_observer_target, C_observer_target_csgo);
				}
				return false;
			}
			if(B_active_afk_manager_csgo_dev)
			{
				PrintToChatAll("%sObserver target: Target is not available anymore. | Client is not AFK", TAG_AFK_MANAGER_CSGO, C_last_observer_target, C_observer_target_csgo);
			}
			return (!IsPlayerAlive(C_last_observer_target));
		}
	}

	if((F_client_eye_position_csgo[client][0] == F_client_eye_location[0]) && (F_client_eye_position_csgo[client][1] == F_client_eye_location[1]) && (F_client_eye_position_csgo[client][2] == F_client_eye_location[2]))
	{
		if(B_active_afk_manager_csgo_dev)
		{
			PrintToChatAll("%sClient look the same place. | Client is AFK", TAG_AFK_MANAGER_CSGO, C_last_observer_target, C_observer_target_csgo);
		}
		return true;
	}
	
	return false;
}

/***********************************************************/
/******************* TIMER CHECK PLAYER ********************/
/***********************************************************/
public Action Timer_CheckPlayerAfkManagerCsgo(Handle timer, any data)
{
	int client; 
	int clients = 0; 
	int C_team_num; 
	float F_time_left;
	bool B_move_players = false;
	bool B_kick_players = false;
	
	float F_eye_location[3]; 
	float F_map_location[3];
	
	clients = GetPlayersInGame(CS_TEAM_T, "player") + GetPlayersInGame(CS_TEAM_CT, "player");
	
	if(B_active_afk_manager_csgo_dev)
	{
		PrintToChatAll("%sClients: %i", TAG_AFK_MANAGER_CSGO, clients);
	}
	
	B_move_players = (clients >= C_active_afk_manager_move_min_csgo && F_active_afk_manager_move_time_csgo > 0.0);
	B_kick_players = (clients >= C_active_afk_manager_kick_min_csgo && F_active_afk_manager_kick_time_csgo > 0.0);
			
	for(client = 1; client <= MaxClients; client++)
	{
		if (!B_client_is_in[client] || !IsClientInGame(client)) // Is this player actually in the game?
		{
			continue;
		}
		
		C_team_num = GetClientTeam(client);
		
		// Check for AFK
		if (IsClientObserver(client))
		{	
			// Unassigned, Spectator or Dead Player
			if (C_team_num > 1 && !IsPlayerAlive(client))
			{
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sPlayer is not a spectator", TAG_AFK_MANAGER_CSGO);
				}
				continue; // Exclude dead players: player is not a spectator = he is dead
			}
			
			if (C_team_num == 0 || CheckObserverAFKCsgo(client))
			{
				F_client_afk_time_csgo[client] += AFK_CHECK_INTERVAL_CSGO;
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sAFK Time: %i", TAG_AFK_MANAGER_CSGO, F_client_afk_time_csgo[client]);
				}
			}
			else
			{
				F_client_afk_time_csgo[client] = 0.0;

				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sAFK Time reset", TAG_AFK_MANAGER_CSGO);
				}
				continue;
			}
		}
		else
		{	// Normal player
			F_eye_location = F_client_eye_position_csgo[client]; // Store Previous Eye Angle/Origin & Map Location Values
			F_map_location = F_client_origin_position_csgo[client];
			GetClientEyeAngles(client, F_client_eye_position_csgo[client]);// Get New
			GetClientAbsOrigin(client, F_client_origin_position_csgo[client]);

			// Check Location (Origin) including thresholds && Check Eye Angles && Check if player is frozen
			if ((F_client_eye_position_csgo[client][0] == F_eye_location[0]) && 
				(F_client_eye_position_csgo[client][1] == F_eye_location[1]) &&
				(F_client_eye_position_csgo[client][2] == F_eye_location[2]) &&
				(FloatAbs(F_client_origin_position_csgo[client][0] - F_map_location[0]) < AFK_THRESHOLD_CSGO) &&
				(FloatAbs(F_client_origin_position_csgo[client][1] - F_map_location[1]) < AFK_THRESHOLD_CSGO) &&
				(FloatAbs(F_client_origin_position_csgo[client][2] - F_map_location[2]) < AFK_THRESHOLD_CSGO) &&
				!(GetEntityFlags(client) & FL_FROZEN))
			{
				F_client_afk_time_csgo[client] += AFK_CHECK_INTERVAL_CSGO;
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sAFK cause same location: %f", TAG_AFK_MANAGER_CSGO, F_client_afk_time_csgo[client]);
				}
			}
			else
			{
				F_client_afk_time_csgo[client] = 0.0;
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sAFK Time reset cause location changed", TAG_AFK_MANAGER_CSGO);
				}
				continue;
			}
		}
		
		// Warn/Move/Kick client. If client isn't ab AFK, we will never be here
		if (B_move_players && C_team_num > 1 && ( !C_active_afk_manager_immune_csgo || C_active_afk_manager_immune_csgo == 2 || !CHECK_ADMIN_IMMUNITY(client)))
		{
			F_time_left = F_active_afk_manager_move_time_csgo - F_client_afk_time_csgo[client];
			if (F_time_left > 0.0)
			{
				if(F_time_left <= F_active_afk_manager_warn_time_csgo)
				{
					if(B_active_afk_manager_csgo_dev)
					{
						PrintToChatAll("%sYou are AFK need to move you", TAG_AFK_MANAGER_CSGO);
					}
					CPrintToChat(client, "%t", "Move_Warning", RoundToFloor(F_time_left));
				}
			}
			else
			{
				char S_client_name[MAX_NAME_LENGTH+4];
				Format(S_client_name,sizeof(S_client_name),"%N",client);
				
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sOne player move to spectator", TAG_AFK_MANAGER_CSGO);
				}

				CPrintToChatAll("%t", "Move_Announce", S_client_name);	
				
				int death = GetEntProp(client, Prop_Data, "m_iDeaths");
				int frags = GetEntProp(client, Prop_Data, "m_iFrags");
				
				//FakeClientCommand(client, "jointeam 1");
				//ForcePlayerSuicide(client);
				//CS_SwitchTeam(client, 1);
				ChangeClientTeam(client, 1);
				SetEntProp(client, Prop_Data, "m_iFrags", frags);
				SetEntProp(client, Prop_Data, "m_iDeaths", death);
				
				Call_StartForward(Forward_MoveSpec);
				Call_PushCell(GetClientUserId(client));
				Call_Finish();
				
			}
		}
		else if (B_kick_players && (!C_active_afk_manager_immune_csgo || C_active_afk_manager_immune_csgo == 3 || !CHECK_ADMIN_IMMUNITY(client)))
		{
			F_time_left = F_active_afk_manager_kick_time_csgo - F_client_afk_time_csgo[client];
			if (F_time_left > 0.0)
			{
				if (F_time_left <= F_active_afk_manager_warn_time_csgo)
				{
					if(B_active_afk_manager_csgo_dev)
					{
						PrintToChatAll("%sYou are AFK need to kick you", TAG_AFK_MANAGER_CSGO);
					}
					CPrintToChat(client, "%t", "Kick_Warning", RoundToFloor(F_time_left));
				}
			}
			else
			{
				char S_client_name[MAX_NAME_LENGTH+4];
				Format(S_client_name,sizeof(S_client_name),"%N",client);
				
				if(B_active_afk_manager_csgo_dev)
				{
					PrintToChatAll("%sOne player has been kicked", TAG_AFK_MANAGER_CSGO);
				}
				CPrintToChatAll("%t", "Kick_Announce", S_client_name);
				KickClient(client, "%t", "Kick_Message");
			}
		}
	}
	return Plugin_Continue;
}
/***********************************************************/
/****************** COMMANDE AFK MANAGER *******************/
/***********************************************************/
public Action Command_AfkManagerCsgo(int client, int args) 
{
	int m_iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	int m_hObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	int C_team_num = GetClientTeam(client);
	
	PrintToChat(client, "%sMode:%i, Taget:%i, Team:%i", TAG_AFK_MANAGER_CSGO, m_iObserverMode, m_hObserverTarget, C_team_num);
	CheckObserverAFKCsgo(client);
	return Plugin_Handled;
}

/***********************************************************/
/********************* IS VALID CLIENT *********************/
/***********************************************************/
stock bool Client_IsValid(int client, bool checkConnected=true)
{
	if (client > 4096) 
	{
		client = EntRefToEntIndex(client);
	}

	if (client < 1 || client > MaxClients) 
	{
		return false;
	}

	if (checkConnected && !IsClientConnected(client)) 
	{
		return false;
	}
	
	return true;
}

/***********************************************************/
/******************** IS CLIENT IN GAME ********************/
/***********************************************************/
stock bool Client_IsIngame(int client)
{
	if (!Client_IsValid(client, false)) 
	{
		return false;
	}

	return IsClientInGame(client);
} 

/***********************************************************/
/******************** GET PLAYER ALIVE *********************/
/***********************************************************/
stock int GetPlayersInGame(int team, char[] bot)
{
	int iCount; iCount = 0; 

	for(int i = 1; i <= MaxClients; i++) 
	{
		if(StrEqual(bot, "player", false))
		{
			if( Client_IsIngame(i) && !IsFakeClient(i) && GetClientTeam(i) == team) 
			{
				iCount++; 
			}
		}
		else if(StrEqual(bot, "bot", false))
		{
			if( Client_IsIngame(i) && IsFakeClient(i) && GetClientTeam(i) == team) 
			{
				iCount++; 
			}
		}
		else if(StrEqual(bot, "both", false))
		{
			if( Client_IsIngame(i) && GetClientTeam(i) == team) 
			{
				iCount++; 
			}
		}
	}
	
	return iCount; 
}

/***********************************************************/
/******************** GET PLAYER ALIVE *********************/
/***********************************************************/
stock int GetPlayersAlive(int team, char[] bot)
{
	int iCount; iCount = 0; 

	for(int i = 1; i <= MaxClients; i++) 
	{
		if(StrEqual(bot, "player", false))
		{
			if( Client_IsIngame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) 
			{
				iCount++; 
			}
		}
		else if(StrEqual(bot, "bot", false))
		{
			if( Client_IsIngame(i) && IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) 
			{
				iCount++; 
			}
		}
		else if(StrEqual(bot, "both", false))
		{
			if( Client_IsIngame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) 
			{
				iCount++; 
			}
		}
	}
	
	return iCount; 
}