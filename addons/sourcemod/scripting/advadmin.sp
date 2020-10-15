#pragma semicolon 1

#include <multicolors>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <geoip>

public Plugin: myinfo =
{
	name = "[CSGO] Advanced Admin [Removed god]",
	author = "PeEzZ",
	description = "Advanced commands for admins.",
	version = "1.7.2 BETA",
	url = "https://forums.alliedmods.net/showthread.php?t=285493"
};

#define CMD_PREFIX		"[SM] " //Prefix in admin activity messages
#define ROOT_PREFIX		"[R]" //Root admin's (ADMFLAG_ROOT) prefix in the !admins command, "[R]" is the default, "[MASTER]" is the suggested flag here
#define ADMIN_PREFIX	"" //Simple admin's (ADMFLAG_GENERIC) prefix in the !admins command, the default is "", and "[A]" is the old, "[SERVANT]" is the suggested flag here

#define MODEL_CHICKEN "models/chicken/chicken.mdl"
#define MODEL_CHICKEN_ZOMBIE "models/chicken/chicken_zombie.mdl"
#define MODEL_BALL "models/props/de_dust/hr_dust/dust_soccerball/dust_soccer_ball001.mdl"
#define MODEL_SNOW "models/props_holidays/snowball/snowball_pile.mdl"

#define SOUND_SPAWN "player/pl_respawn.wav" //Teleport, respawn, spawn entity sound, leave blank to disable
#define SOUND_BURY "physics/concrete/boulder_impact_hard4.wav" //Bury sound, leave blank to disable

new Handle: CVAR_ADMINS = INVALID_HANDLE,
	Handle: CVAR_ANNOUNCE = INVALID_HANDLE,
	Handle: CVAR_INVALID = INVALID_HANDLE,
	Handle: CVAR_LOG = INVALID_HANDLE;

new Float: g_fSaveVec[MAXPLAYERS + 1][2][3],
	Float: g_fDeathVec[MAXPLAYERS + 1][2][3];

new String: WeaponsList[][] = //VALID WEAPON NAMES HERE
{
	"c4", "healthshot", "tablet", "shield", //misc
	"knife", "knifegg", "fists", "axe", "hammer", "spanner", "taser", "melee", //melee
	"decoy", "flashbang", "hegrenade", "molotov", "incgrenade", "smokegrenade", "tagrenade", "breachcharge", "snowball", "bumpmine", //projectiles
	"usp_silencer", "glock", "tec9", "p250", "hkp2000", "cz75a", "deagle", "revolver", "fiveseven", "elite", //pistoles
	"nova", "xm1014", "sawedoff", "mag7", "m249", "negev", //heavy
	"mp9", "mp7", "mp5sd", "ump45", "p90", "bizon", "mac10", //smgs
	"ak47", "aug", "famas", "sg556", "galilar", "m4a1", "m4a1_silencer", //rifles
	"awp", "ssg08", "scar20", "g3sg1" //snipers
};
new String: ItemsList[][] = //VALID ITEM NAMES HERE, HEAVYASSAULTSUIT ONLY WORKS WHEN ITS ENABLED (mp_max_armor 3 and mp_weapons_allow_heavyassaultsuit 1)
{
	"defuser", "cutters", //defuser and rescue kit
	"kevlar", "assaultsuit", "heavyassaultsuit", //armors
	"nvgs" //nightvision
};

public OnPluginStart()
{
	CVAR_ADMINS		= CreateConVar("sm_advadmin_admins",		"2",	"Settings of !admins command, 0 - disable, 1 - show fake message, 2 - show online admins", _, true, 0.0, true, 2.0);
	CVAR_ANNOUNCE	= CreateConVar("sm_advadmin_announce",		"2",	"Join announce, 0 - disable, 1 - simple announce, 2 - announce with country name", _, true, 0.0, true, 2.0);
	CVAR_INVALID	= CreateConVar("sm_advadmin_invalid",		"1",	"Invalid given item will show for all players just for fun, 0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
	CVAR_LOG		= CreateConVar("sm_advadmin_log",			"1",	"Enable logging for plugin, 0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
	
	//-----//
	RegAdminCmd("sm_extend",		CMD_Extend,			ADMFLAG_CHANGEMAP,	"Extending the map or the round");
	RegAdminCmd("sm_clearmap",		CMD_ClearMap,		ADMFLAG_GENERIC,	"Deleting dropped weapons, items and chickens without owner from the map");
	RegAdminCmd("sm_restartgame",	CMD_RestartGame,	ADMFLAG_GENERIC,	"Restarting the game after the specified seconds");
	RegAdminCmd("sm_rg",			CMD_RestartGame,	ADMFLAG_GENERIC,	"Restarting the game after the specified seconds");
	RegAdminCmd("sm_restartround",	CMD_RestartRound,	ADMFLAG_GENERIC,	"Restarting the round after the specified seconds");
	RegAdminCmd("sm_rr",			CMD_RestartRound,	ADMFLAG_GENERIC,	"Restarting the round after the specified seconds");
	RegAdminCmd("sm_equipments",	CMD_Equipments,		ADMFLAG_GENERIC,	"Showing the valid equipment names in the console");
	RegAdminCmd("sm_playsound",		CMD_PlaySound,		ADMFLAG_GENERIC,	"Playing a sound for the targets, with custom settings");
	//-----//
	RegAdminCmd("sm_teleport",		CMD_Teleport,		ADMFLAG_BAN,		"Teleporting the target to something");
	RegAdminCmd("sm_tp",			CMD_Teleport,		ADMFLAG_BAN,		"Teleporting the target to something");
	RegAdminCmd("sm_saveloc",		CMD_SaveVec,		ADMFLAG_BAN,		"Saving the current position for the teleport");
	RegAdminCmd("sm_savepos",		CMD_SaveVec,		ADMFLAG_BAN,		"Saving the current position for the teleport");
	//-----//
	RegAdminCmd("sm_team",			CMD_Team,			ADMFLAG_KICK,		"Set the targets team");
	RegAdminCmd("sm_swap",			CMD_Swap,			ADMFLAG_KICK,		"Swap the targets team");
	RegAdminCmd("sm_spec",			CMD_Spec,			ADMFLAG_KICK,		"Set the targets team to spectator");
	RegAdminCmd("sm_scramble",		CMD_Scramble,		ADMFLAG_KICK,		"Scramble the teams by scores");
	RegAdminCmd("sm_balance",		CMD_Balance,		ADMFLAG_KICK,		"Balance the teams by player count");
	//-----//
	RegAdminCmd("sm_give",			CMD_Give,			ADMFLAG_BAN,		"Give something for the targets");
	RegAdminCmd("sm_equip",			CMD_Equip,			ADMFLAG_BAN,		"Equipping something for the targets");
	RegAdminCmd("sm_disarm",		CMD_Disarm,			ADMFLAG_BAN,		"Disarming the targets");
	//-----//
	RegAdminCmd("sm_respawn",		CMD_Respawn,		ADMFLAG_KICK,		"Respawning the targets");
	RegAdminCmd("sm_bury",			CMD_Bury,			ADMFLAG_KICK,		"Burying the targets");
	//-----//
	RegAdminCmd("sm_speed",			CMD_Speed,			ADMFLAG_BAN,		"Set the speed multipiler of the targets");
	RegAdminCmd("sm_helmet",		CMD_Helmet,			ADMFLAG_KICK,		"Set helmet for the targets");
	//-----//
	RegAdminCmd("sm_hp",			CMD_Health,			ADMFLAG_KICK,		"Set the health for the targets");
	RegAdminCmd("sm_health",		CMD_Health,			ADMFLAG_KICK,		"Set the health for the targets");
	RegAdminCmd("sm_armor",			CMD_Armor,			ADMFLAG_KICK,		"Set the armor for the targets");
	RegAdminCmd("sm_cash",			CMD_Cash,			ADMFLAG_BAN,		"Set the cash for the targets");
	//-----//
	RegAdminCmd("sm_setstats",		CMD_SetStats,		ADMFLAG_BAN,		"Set the stats for the targets");
	RegAdminCmd("sm_teamscores",	CMD_TeamScores,		ADMFLAG_BAN,		"Set the teams scores");
	//-----//
	RegAdminCmd("sm_spawnent",		CMD_SpawnEnt,		ADMFLAG_GENERIC,	"Spawning some entity on your aim position");
	
	RegConsoleCmd("sm_admins",		CMD_Admins,			"Showing the online admins");
	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	
	LoadTranslations("common.phrases");
	LoadTranslations("advadmin.phrases");
}

public OnMapStart()
{
	if(!StrEqual(SOUND_SPAWN, "", false))
	{
		PrecacheSound(SOUND_SPAWN, true);
	}
	if(!StrEqual(SOUND_BURY, "", false))
	{
		PrecacheSound(SOUND_BURY, true);
	}
	
	PrecacheModel(MODEL_CHICKEN, true);
	PrecacheModel(MODEL_CHICKEN_ZOMBIE, true);
	PrecacheModel(MODEL_BALL, true);
	PrecacheModel(MODEL_SNOW, true);
	PrecacheModel("models/props_survival/drone/br_drone.mdl", true);
	
	for(new client = 1; client <= MaxClients; client++)
    {
		g_fSaveVec[client][0] = Float: {0, 0, 0};
		g_fSaveVec[client][1] = Float: {0, 0, 0};
		g_fDeathVec[client][0] = Float: {0, 0, 0};
		g_fDeathVec[client][1] = Float: {0, 0, 0};
	}
}

//-----CLIENT_AUTHORIZED-----//
public OnClientAuthorized(client, const String: auth[])
{
	new value = GetConVarInt(CVAR_ANNOUNCE);
	if(value > 0)
	{
		new String: IP[64],
			String: country[64];
		
		if((value == 2) && GetClientIP(client, IP, sizeof(IP)) && GeoipCountry(IP, country, sizeof(country)))
		{
			CPrintToChatAll("%t", "Player_Connected_From", client, country);
		}
		else
		{
			CPrintToChatAll("%t", "Player_Connected", client);
		}
	}
}
//-----EVENTS-----//
public Action: OnPlayerDeath(Handle: event, const String: name[], bool: dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetClientAbsOrigin(client, g_fDeathVec[client][0]);
	GetClientEyeAngles(client, g_fDeathVec[client][1]);
}

//----------------------------//
//=====NON-ADMIN_COMMANDS=====//
public Action: CMD_Admins(client, args) //IF YOU ARE ADMIN, YOU ALWAYS GET THE TRUE, CURRENTLY ONLINE ADMINS! NO MATTER IF THE COMMAND IS DISABLED OR SET TO FAKE ADMINS!
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(!(GetUserFlagBits(client) & ADMFLAG_GENERIC))
	{
		new value = GetConVarInt(CVAR_ADMINS);
		if(value == 0)
		{
			ReplyToCommand(client, "%t", "CMD_Disabled");
			return Plugin_Handled;
		}
		else if(value == 1)
		{
			ReplyToCommand(client, "%t", "CMD_Admins_Offline");
			return Plugin_Handled;
		}
	}
	
	new String: buffer[128],
		String: current[64];
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			new flags = GetUserFlagBits(i);
			if(flags & ADMFLAG_GENERIC)
			{			
				Format(current, sizeof(current), "%s%N", (flags & ADMFLAG_ROOT) ? ROOT_PREFIX : ADMIN_PREFIX, i);
				if(StrEqual(buffer, "", false))
				{
					Format(buffer, sizeof(buffer), "%s", current);
				}
				else
				{
					Format(buffer, sizeof(buffer), "%s, %s", buffer, current);
				}
			}
		}
	}
	
	if(!StrEqual(buffer, "", false))
	{
		ReplyToCommand(client, "%t", "CMD_Admins_Online", buffer);
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Admins_Offline");
	}
	return Plugin_Handled;
}

//------------------------//
//=====ADMIN_COMMANDS=====//
public Action: CMD_Extend(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Extend_Usage");
		return Plugin_Handled;
	}
	
	new String: buffer[6];
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "map", false))
	{
		ExtendMapTimeLimit(value * 60);
		
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_ExtendMap", value);
		LogActionEx(client, "%t", "CMD_ExtendMap", value);
	}
	else if(StrEqual(buffer, "round", false))
	{
		GameRules_SetProp("m_iRoundTime", GameRules_GetProp("m_iRoundTime") + value); //Extending with seconds
		//GameRules_SetProp("m_iRoundTime", GameRules_GetProp("m_iRoundTime") + (value * 60)); //Extending with minutes
		
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_ExtendRound", value);
		LogActionEx(client, "%t", "CMD_ExtendRound", value);
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Extend_Usage");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}
public Action: CMD_ClearMap(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	new String: buffer[64],
		value;
		
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "weapons", false))
	{
		value = 1;
	}
	else if(StrEqual(buffer, "chickens", false))
	{
		value = 2;
	}
	else
	{
		value = 0;
	}
	
	for(new entity = MaxClients; entity < GetMaxEntities(); entity++)
	{
		if(IsValidEntity(entity))
		{
			GetEntityClassname(entity, buffer, sizeof(buffer));
			if((((StrContains(buffer, "game", false) == -1) && (StrContains(buffer, "weapon_", false) != -1) && (GetEntProp(entity, Prop_Data, "m_iState") == 0) && (GetEntProp(entity, Prop_Data, "m_spawnflags") != 1)) || (StrEqual(buffer, "item_", false))) && (value <= 1))
			{
				AcceptEntityInput(entity, "Kill");
			}
			if(StrEqual(buffer, "chicken", false) && (GetEntPropEnt(entity, Prop_Send, "m_leader") == -1) && (value != 1))
			{
				AcceptEntityInput(entity, "Kill");
			}
		}
	}
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_ClearMap");
	LogActionEx(client, "%t", "CMD_ClearMap");
	return Plugin_Handled;
}
public Action: CMD_RestartGame(client, args)
{
	new time;
	if(args)
	{
		new String: buffer[4];
		GetCmdArg(1, buffer, sizeof(buffer));
		time = StringToInt(buffer);
	}
	
	if(time > 0)
	{
		ServerCommand("mp_restartgame %i", time);
	}
	else
	{
		CS_TerminateRound(0.0, CSRoundEnd_GameStart);
	}
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_RestartGame");
	LogActionEx(client, "%t", "CMD_RestartGame");
	return Plugin_Handled;
}
public Action: CMD_RestartRound(client, args)
{
	new time;
	if(args)
	{
		new String: buffer[4];
		GetCmdArg(1, buffer, sizeof(buffer));
		time = StringToInt(buffer);
	}
	CS_TerminateRound(float(time), CSRoundEnd_Draw);
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_RestartRound");
	LogActionEx(client, "%t", "CMD_RestartRound");
	return Plugin_Handled;
}
public Action: CMD_Equipments(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	new String: buffer[512];
	for(new i = 0; i < sizeof(WeaponsList); i++)
	{
		if(StrEqual(buffer, "", false))
		{
			Format(buffer, sizeof(buffer), "%s", WeaponsList[i]);
		}
		else
		{
			Format(buffer, sizeof(buffer), "%s, %s", buffer, WeaponsList[i]);
		}
	}
	PrintToConsole(client, "%t", "CMD_Equipments_Weapons", buffer);
	
	buffer = "";
	
	for(new i = 0; i < sizeof(ItemsList); i++)
	{
		if(StrEqual(buffer, "", false))
		{
			Format(buffer, sizeof(buffer), "%s", ItemsList[i]);
		}
		else
		{
			Format(buffer, sizeof(buffer), "%s, %s", buffer, ItemsList[i]);
		}
	}
	PrintToConsole(client, "%t", "CMD_Equipments_Items", buffer);
	ReplyToCommand(client, "%t", "CMD_Equipments_Printed");
	return Plugin_Handled;
}
public Action: CMD_PlaySound(client, args)
{
	if(args < 2)
	{
		ReplyToCommand(client, "%t", "CMD_PlaySound_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[512],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	new value[3];
	GetCmdArg(3, buffer, sizeof(buffer));
	value[0] = StringToInt(buffer);
	if((value[0] < 50) || (value[0] > 250))
	{
		value[0] = 100;
	}
	
	GetCmdArg(4, buffer, sizeof(buffer));
	value[1] = StringToInt(buffer);
	if((value[1] < 1) || (value[1] > 100))
	{
		value[1] = 100;
	}
	
	GetCmdArg(5, buffer, sizeof(buffer));
	value[2] = StringToInt(buffer);
	if((value[2] < 1) || (value[2] > 10))
	{
		value[2] = 1;
	}
	
	new String: file[512];
	GetCmdArg(2, buffer, sizeof(buffer));
	Format(file, sizeof(file), "sound/%s", buffer);
	if(!FileExists(file))
	{
		ReplyToCommand(client, "%t", "CMD_PlaySound_NoFile", buffer);
		return Plugin_Handled;
	}
	
	PrecacheSound(buffer, true);
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			for(new n = 0; n < value[2]; n++)
			{
				EmitSoundToClient(target_list[i], buffer, _, _, _, _, value[1] * 0.01, value[0]);
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_PlaySound", target_name, buffer, value[0], value[1], value[2]);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_PlaySound", "_s", target_name, buffer, value[0], value[1], value[2]);
	}
	return Plugin_Handled;
}

//=========CLIENT=========//
public Action: CMD_Teleport(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Teleport_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
		
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	new Float: vec[2][3];
	GetCmdArg(2, buffer, sizeof(buffer));
	if(!StrEqual(buffer, "", false))
	{
		if(StrEqual(buffer, "@blink", false))
		{
			GetClientEyePosition(client, vec[0]);
			GetClientEyeAngles(client, vec[1]);
			
			new Handle: trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);
			if(!TR_DidHit(trace))
			{
				return Plugin_Handled;
			}
			TR_GetEndPosition(vec[0], trace);
			CloseHandle(trace);
			
			vec[1][0] = vec[1][2] = 0.0;
			
			if(tn_is_ml)
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Blink", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Blink", target_name);
			}
			else
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Blink", "_s", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Blink", "_s", target_name);
			}
		}
		else
		{
			new target = FindTarget(client, buffer, false, false);
			if(!IsClientValid(target) || !IsClientInGame(target))
			{
				return Plugin_Handled;
			}
			
			GetClientAbsOrigin(target, vec[0]);
			GetClientEyeAngles(target, vec[1]);
			
			if(tn_is_ml)
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Player", target_name, target);
				LogActionEx(client, "%t", "CMD_Teleport_To_Player", target_name, target);
			}
			else
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Player", "_s", target_name, target);
				LogActionEx(client, "%t", "CMD_Teleport_To_Player", "_s", target_name, target);
			}
		}
	}
	else
	{
		if((FloatAbs(g_fSaveVec[client][0][0]) + FloatAbs(g_fSaveVec[client][0][1]) + FloatAbs(g_fSaveVec[client][0][2])) == 0)
		{
			ReplyToCommand(client, "%t", "CMD_Teleport_NoSaved");
			return Plugin_Handled;
		}
		else
		{
			vec[0] = g_fSaveVec[client][0];
			vec[1] = g_fSaveVec[client][1];
			
			if(tn_is_ml)
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Saved", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Saved", target_name);
			}
			else
			{
				ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Teleport_To_Saved", "_s", target_name);
				LogActionEx(client, "%t", "CMD_Teleport_To_Saved", "_s", target_name);
			}
		}
	}
	
	vec[0][2] = vec[0][2] + 2.0;
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			TeleportEntity(target_list[i], vec[0], vec[1], Float: {0, 0, 0});
		}
	}
	
	if(!StrEqual(SOUND_SPAWN, "", false))
	{
		EmitSoundToAll(SOUND_SPAWN, target_list[target_count - 1]); //Only play the sound once, and only the last one teleported player.
	}
	return Plugin_Handled;
}
public Action: CMD_SaveVec(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	GetClientAbsOrigin(client, g_fSaveVec[client][0]);
	GetClientEyeAngles(client, g_fSaveVec[client][1]);
	
	g_fSaveVec[client][1][2] = 0.0;
	
	ReplyToCommand(client, "%t", "CMD_SaveVec");
	return Plugin_Handled;
}

//==========//
public Action: CMD_Team(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 2) && (args != 3))
	{
		ReplyToCommand(client, "%t", "CMD_Team_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	new team;
	GetCmdArg(2, buffer, sizeof(buffer));
	if(StrEqual(buffer, "spectator", false) || StrEqual(buffer, "spec", false) || StrEqual(buffer, "1", false))
	{
		team = CS_TEAM_SPECTATOR;
		if(tn_is_ml)
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", target_name);
			LogActionEx(client, "%t", "CMD_Team_Spec", target_name);
		}
		else
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", "_s", target_name);
			LogActionEx(client, "%t", "CMD_Team_Spec", "_s", target_name);
		}
	}
	else if(StrEqual(buffer, "t", false) || StrEqual(buffer, "2", false))
	{
		team = CS_TEAM_T;
		if(tn_is_ml)
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_T", target_name);
			LogActionEx(client, "%t", "CMD_Team_T", target_name);
		}
		else
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_T", "_s", target_name);
			LogActionEx(client, "%t", "CMD_Team_T", "_s", target_name);
		}
	}
	else if(StrEqual(buffer, "ct", false) || StrEqual(buffer, "3", false))
	{
		team = CS_TEAM_CT;
		if(tn_is_ml)
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_CT", target_name);
			LogActionEx(client, "%t", "CMD_Team_CT", target_name);
		}
		else
		{
			ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_CT", "_s", target_name);
			LogActionEx(client, "%t", "CMD_Team_CT", "_s", target_name);
		}
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Invalid_Team");
		return Plugin_Handled;
	}
	
	GetCmdArg(3, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(!value)
			{
				if(team != 1)
				{
					CS_SwitchTeam(target_list[i], team);
					if(IsPlayerAlive(target_list[i]))
					{
						CS_RespawnPlayer(target_list[i]);
					}
				}
				else
				{
					ChangeClientTeam(target_list[i], team);
				}
			}
			else
			{
				SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", team);
			}
		}
	}
	return Plugin_Handled;
}
public Action: CMD_Swap(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Swap_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "@spec", false) || StrEqual(buffer, "@spectator", false))
	{
		ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
		return Plugin_Handled;
	}
	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer),
		team;
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			team = GetClientTeam(target_list[i]);
			if(team >= 2)
			{
				if(!value)
				{
					if(team == CS_TEAM_T)
					{
						CS_SwitchTeam(target_list[i], CS_TEAM_CT);
					}
					else
					{
						CS_SwitchTeam(target_list[i], CS_TEAM_T);
					}
					if(IsPlayerAlive(target_list[i]))
					{
						CS_RespawnPlayer(target_list[i]);
					}
				}
				else
				{
					if(team == CS_TEAM_T)
					{
						SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_CT);
					}
					else
					{
						SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_T);
					}
				}
			}
			else if(!tn_is_ml)
			{
				ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
				return Plugin_Handled;
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Swap", target_name);
		LogActionEx(client, "%t", "CMD_Swap", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Swap", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Swap", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action: CMD_Spec(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Team_Spec_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(!value)
			{
				ChangeClientTeam(target_list[i], CS_TEAM_SPECTATOR);
			}
			else
			{
				SetEntProp(target_list[i], Prop_Data, "m_iPendingTeamNum", CS_TEAM_SPECTATOR);
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", target_name);
		LogActionEx(client, "%t", "CMD_Team_Spec", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Team_Spec", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Team_Spec", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action: CMD_Scramble(client, args) /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	ServerCommand("mp_scrambleteams");
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Scramble");
	LogActionEx(client, "%t", "CMD_Scramble");
	return Plugin_Handled;
}

public Action: CMD_Balance(client, args) /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	ServerCommand("mp_scrambleteams");
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Balance");
	LogActionEx(client, "%t", "CMD_Balance");
	return Plugin_Handled;
}

//==========//
public Action: CMD_Give(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Give_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[128],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	if(StrEqual(buffer, "", false))
	{
		Format(buffer, sizeof(buffer), "knife");
	}
	
	new type = ItemType(buffer);
	if(!type)
	{
		if(GetConVarBool(CVAR_INVALID))
		{
			if(tn_is_ml)
			{
				CPrintToChatAll("%s%t", CMD_PREFIX, "CMD_Give", target_name, buffer);
			}
			else
			{
				CPrintToChatAll("%s%t", CMD_PREFIX, "CMD_Give", "_s", target_name, buffer);
			}
		}
		ReplyToCommand(client, "%t", "CMD_Invalid_Weapon");
		return Plugin_Handled;
	}
	
	for(new i = 0; i < target_count; i++)
	{
		if((StrEqual(buffer, "knife", false) || StrEqual(buffer, "knifegg", false) || StrEqual(buffer, "melee", false) || StrEqual(buffer, "spanner", false) || StrEqual(buffer, "hammer", false) || StrEqual(buffer, "axe", false)) && !GetConVarBool(FindConVar("mp_drop_knife_enable")))
		{
			new knife = -1;
			while((knife = GetPlayerWeaponSlot(target_list[i], 2)) != -1)
			{
				if(IsValidEntity(knife))
				{
					RemovePlayerItem(target_list[i], knife);
				}
			}
		}
		//new value;
		GivePlayerWeapon(target_list[i], buffer, type);///////////////////////////////////////////////////////////////////////////////////////////////
		//if()
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Give", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Give", target_name, buffer);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Give", "_s", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Give", "_s", target_name, buffer);
	}
	return Plugin_Handled;
}
public Action: CMD_Equip(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Equip_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[128],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
		
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	if(StrEqual(buffer, "", false))
	{
		Format(buffer, sizeof(buffer), "knife");
	}
	
	new type = ItemType(buffer);
	if(!type)
	{
		if(GetConVarBool(CVAR_INVALID))
		{
			if(tn_is_ml)
			{
				CPrintToChatAll("%s%t", CMD_PREFIX, "CMD_Equip", target_name, buffer);
			}
			else
			{
				CPrintToChatAll("%s%t", CMD_PREFIX, "CMD_Equip", "_s", target_name, buffer);
			}
		}
		ReplyToCommand(client, "%t", "CMD_Invalid_Weapon");
		return Plugin_Handled;
	}
	
	for(new i = 0; i < target_count; i++)
	{
		DisarmPlayer(target_list[i]);
		GivePlayerWeapon(target_list[i], buffer, type);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Equip", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Equip", target_name, buffer);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Equip", "_s", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Equip", "_s", target_name, buffer);
	}
	return Plugin_Handled;
}
public Action: CMD_Disarm(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		ReplyToCommand(client, "%t", "CMD_Disarm_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for(new i = 0; i < target_count; i++)
	{
		DisarmPlayer(target_list[i]);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Disarm", target_name);
		LogActionEx(client, "%t", "CMD_Disarm", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Disarm", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Disarm", "_s", target_name);
	}
	return Plugin_Handled;
}

//==========//
public Action: CMD_Respawn(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Respawn_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if(StrEqual(buffer, "@spec", false) || StrEqual(buffer, "@spectator", false))
	{
		ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
		return Plugin_Handled;
	}
	
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(GetClientTeam(target_list[i]) >= 2)
			{
				CS_RespawnPlayer(target_list[i]);
				
				if(value && ((FloatAbs(g_fDeathVec[target_list[i]][0][0]) + FloatAbs(g_fDeathVec[target_list[i]][0][1]) + FloatAbs(g_fDeathVec[target_list[i]][0][2])) != 0))
				{
					TeleportEntity(target_list[i], g_fDeathVec[target_list[i]][0], g_fDeathVec[target_list[i]][1], NULL_VECTOR);
				}
				
				if(!StrEqual(SOUND_SPAWN, "", false))
				{
					EmitSoundToAll(SOUND_SPAWN, target_list[i]);
				}
			}
			else if(!tn_is_ml)
			{
				ReplyToCommand(client, "%t", "CMD_OnlyInTeam");
				return Plugin_Handled;
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Respawn", target_name);
		LogActionEx(client, "%t", "CMD_Respawn", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Respawn", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Respawn", "_s", target_name);
	}
	return Plugin_Handled;
}
public Action: CMD_Bury(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if((args != 1) && (args != 2))
	{
		ReplyToCommand(client, "%t", "CMD_Bury_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	new Float: pos[3];
	for(new i = 0; i < target_count; i++)
	{
		GetClientAbsOrigin(target_list[i], pos);
		if(value == 0)
		{
			pos[2] -= 36.5;
		}
		else
		{
			pos[2] += 36.5;
		}
		TeleportEntity(target_list[i], pos, NULL_VECTOR, Float: {0, 0, 0});
		if(!StrEqual(SOUND_BURY, "", false))
		{
			EmitSoundToAll(SOUND_BURY, target_list[i], _, _, _, _, _, GetRandomInt(95, 105));
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Bury", target_name);
		LogActionEx(client, "%t", "CMD_Bury", target_name);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Bury", "_s", target_name);
		LogActionEx(client, "%t", "CMD_Bury", "_s", target_name);
	}
	return Plugin_Handled;
}
//==========//
public Action: CMD_Speed(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Speed_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new Float: value = StringToFloat(buffer);
	if((value < 0.0) || (value > 500.0))
	{
		ReplyToCommand(client, "%t", "CMD_Speed_Usage");
		return Plugin_Handled;
	}
	
	for(new i = 0; i < target_count; i++)
	{
		SetEntPropFloat(target_list[i], Prop_Data, "m_flLaggedMovementValue", value);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Speed", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Speed", target_name, buffer);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Speed", "_s", target_name, buffer);
		LogActionEx(client, "%t", "CMD_Speed", "_s", target_name, buffer);
	}
	return Plugin_Handled;
}
public Action: CMD_Helmet(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Helmet_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	if((value != 0) && (value != 1))
	{
		ReplyToCommand(client, "%t", "CMD_Helmet_Usage");
		return Plugin_Handled;
	}
	
	for(new i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Send, "m_bHasHelmet", value);
	}

	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Helmet", target_name, value);
		LogActionEx(client, "%t", "CMD_Helmet", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Helmet", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Helmet", "_s", target_name, value);
	}
	return Plugin_Handled;
}

//==========//
public Action: CMD_Health(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Health_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	for(new i = 0; i < target_count; i++)
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetEntProp(target_list[i], Prop_Data, "m_iHealth");
		}
		SetEntProp(target_list[i], Prop_Data, "m_iHealth", value);
		//SetEntProp(target_list[i], Prop_Data, "m_iMaxHealth", value);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Health", target_name, value);
		LogActionEx(client, "%t", "CMD_Health", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Health", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Health", "_s", target_name, value);
	}
	return Plugin_Handled;
}
public Action: CMD_Armor(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Armor_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	for(new i = 0; i < target_count; i++)
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetEntProp(target_list[i], Prop_Send, "m_ArmorValue");
		}
		SetEntProp(target_list[i], Prop_Send, "m_ArmorValue", value);
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Armor", target_name, value);
		LogActionEx(client, "%t", "CMD_Armor", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Armor", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Armor", "_s", target_name, value);
	}
	return Plugin_Handled;
}
public Action: CMD_Cash(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_Cash_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer, sizeof(buffer));
	if((target_count = ProcessTargetString(buffer, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if((buffer[0] == '+') || (buffer[0] == '-'))
			{
				value = value + GetEntProp(target_list[i], Prop_Send, "m_iAccount");
			}
			SetEntProp(target_list[i], Prop_Send, "m_iAccount", value);
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Cash", target_name, value);
		LogActionEx(client, "%t", "CMD_Cash", target_name, value);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_Cash", "_s", target_name, value);
		LogActionEx(client, "%t", "CMD_Cash", "_s", target_name, value);
	}
	return Plugin_Handled;
}
//==========//
public Action: CMD_SetStats(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 3)
	{
		ReplyToCommand(client, "%t", "CMD_SetStats_Usage");
		return Plugin_Handled;
	}
	
	new String: target_name[MAX_TARGET_LENGTH],
		String: buffer[2][64],
		target_list[MAXPLAYERS],
		bool: tn_is_ml,
		target_count;
	
	GetCmdArg(1, buffer[0], sizeof(buffer[]));
	if((target_count = ProcessTargetString(buffer[0], client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer[0], sizeof(buffer[]));
	GetCmdArg(3, buffer[1], sizeof(buffer[]));
	new value = StringToInt(buffer[1]);
	
	for(new i = 0; i < target_count; i++)
	{
		if(IsClientInGame(target_list[i]))
		{
			if(StrEqual(buffer[0], "kills"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + GetEntProp(target_list[i], Prop_Data, "m_iFrags");
				}
				SetEntProp(target_list[i], Prop_Data, "m_iFrags", value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "assists"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + CS_GetClientAssists(target_list[i]);
				}
				CS_SetClientAssists(target_list[i], value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "deaths"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + GetEntProp(target_list[i], Prop_Data, "m_iDeaths");
				}
				SetEntProp(target_list[i], Prop_Data, "m_iDeaths", value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "mvps"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + CS_GetMVPCount(target_list[i]);
				}
				CS_SetMVPCount(target_list[i], value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "scores"))
			{
				if((buffer[1][0] == '+') || (buffer[1][0] == '-'))
				{
					value = value + CS_GetClientContributionScore(target_list[i]);
				}
				CS_SetClientContributionScore(target_list[i], value);
				Format(buffer[1], sizeof(buffer[]), "%i", value);
			}
			else if(StrEqual(buffer[0], "clan"))
			{
				CS_SetClientClanTag(target_list[i], buffer[1]);
			}
			else
			{
				ReplyToCommand(client, "%t", "CMD_SetStats_Usage");
				return Plugin_Handled;
			}
		}
	}
	
	if(tn_is_ml)
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SetStats", target_name, buffer[0], buffer[1]);
		LogActionEx(client, "%t", "CMD_SetStats", target_name, buffer[0], buffer[1]);
	}
	else
	{
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SetStats", "_s", target_name, buffer[0], buffer[1]);
		LogActionEx(client, "%t", "CMD_SetStats", "_s", target_name, buffer[0], buffer[1]);
	}
	return Plugin_Handled;
}
public Action: CMD_TeamScores(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args != 2)
	{
		ReplyToCommand(client, "%t", "CMD_TeamScores_Usage");
		return Plugin_Handled;
	}
	
	new String: team[8],
		String: buffer[64];
	
	GetCmdArg(1, team, sizeof(team));
	GetCmdArg(2, buffer, sizeof(buffer));
	new value = StringToInt(buffer);
	
	if(StrEqual(team, "t", false) || StrEqual(team, "2", false))
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetTeamScore(CS_TEAM_T);
		}
		SetTeamScore(CS_TEAM_T, value);
		
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_TeamScores_T", value);
		LogActionEx(client, "%t", "CMD_TeamScores_T", value);
	}
	else if(StrEqual(team, "ct", false) || StrEqual(team, "3", false))
	{
		if((buffer[0] == '+') || (buffer[0] == '-'))
		{
			value = value + GetTeamScore(CS_TEAM_CT);
		}
		SetTeamScore(CS_TEAM_CT, value);
		
		ShowActivity2(client, CMD_PREFIX, "%t", "CMD_TeamScores_CT", value);
		LogActionEx(client, "%t", "CMD_TeamScores_CT", value);
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_Invalid_Team");
	}
	return Plugin_Handled;
}

public Action: CMD_SpawnEnt(client, args)
{
	if(!IsClientValid(client) || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(args < 1)
	{
		ReplyToCommand(client, "%t", "CMD_SpawnEnt_Usage");
		return Plugin_Handled;
	}
	
	new Float: vec[2][3];
	GetClientEyePosition(client, vec[0]);
	GetClientEyeAngles(client, vec[1]);
	
	new Handle: trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);
	if(!TR_DidHit(trace))
	{
		return Plugin_Handled;
	}
	TR_GetEndPosition(vec[0], trace);
	CloseHandle(trace);
	
	vec[1][0] = vec[1][2] = 0.0;
	
	new String: buffer[2][16],
		entity;
	
	GetCmdArg(1, buffer[0], sizeof(buffer[]));
	
	if(StrEqual(buffer[0], "chicken"))
	{
		entity = CreateEntityByName("chicken");
		if(!IsValidEntity(entity))
		{
			return Plugin_Handled;
		}
		DispatchSpawn(entity);
		
		new value;
		GetCmdArg(2, buffer[1], sizeof(buffer[]));
		value = StringToInt(buffer[1]);
		
		if((value > 0) && (value <= 5)) 
		{
			SetEntProp(entity, Prop_Data, "m_nBody", value);
			SetEntProp(entity, Prop_Data, "m_nSkin", GetRandomInt(0, 1));
		}
		else if(value == 6)
		{
			SetEntityModel(entity, MODEL_CHICKEN_ZOMBIE);
		}
		
		GetCmdArg(3, buffer[1], sizeof(buffer[]));
		value = StringToInt(buffer[1]);
		
		if((value > 0) && (value <= 9999))
		{
			SetEntPropFloat(entity, Prop_Data, "m_explodeDamage", float(value));
			SetEntPropFloat(entity, Prop_Data, "m_explodeRadius", 0.0);
		}
		else if(value == -1)
		{
			SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		}
		
		vec[0][2] = vec[0][2] + 10.0;
	}
	else if(StrEqual(buffer[0], "ball"))
	{
		entity = CreateEntityByName("prop_physics_multiplayer");
		if(!IsValidEntity(entity))
		{
			return Plugin_Handled;
		}
		
		DispatchKeyValue(entity, "model", MODEL_BALL);
		DispatchKeyValue(entity, "physicsmode", "2");
		DispatchSpawn(entity);
		
		new value;
		GetCmdArg(2, buffer[1], sizeof(buffer[]));
		value = StringToInt(buffer[1]);
		
		if(value == 1)
		{
			SetEntProp(entity, Prop_Data, "m_nSkin", value);
		}
		
		vec[0][2] = vec[0][2] + 16.0;
	}
	else if(StrEqual(buffer[0], "snow"))
	{
		entity = CreateEntityByName("ent_snowball_pile");
		if(!IsValidEntity(entity))
		{
			return Plugin_Handled;
		}
		DispatchSpawn(entity);
	}
	else if(StrEqual(buffer[0], "dronegun"))//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		entity = CreateEntityByName("dronegun");
		if(!IsValidEntity(entity))
		{
			return Plugin_Handled;
		}
		DispatchSpawn(entity);
		
		//SetEntPropEnt(entity, Prop_Data, "m_iTeamNum", GetClientTeam(client));
		SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
		
		//PROP SEND m_vecAttentionTarget m_vecTargetOffset m_bHasTarget
		
		SetEntProp(entity, Prop_Data, "m_nHighlightColorB", 255);
		
		vec[0][2] = vec[0][2] + 8.0;
	}
	else if(StrEqual(buffer[0], "drone"))//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	{
		entity = CreateEntityByName("drone");
		if(!IsValidEntity(entity))
		{
			return Plugin_Handled;
		}
		DispatchSpawn(entity);
		
		SetEntProp(entity, Prop_Send, "m_bPilotTakeoverAllowed", 1);
		SetEntPropEnt(entity, Prop_Send, "m_hCurrentPilot", client);
		//SetEntProp(entity, Prop_Data, "m_bThrownByPlayer", 1);
		
		SetEntPropEnt(entity, Prop_Send, "m_hMoveToThisEntity", client);
		//SetEntPropEnt(entity, Prop_Send, "m_hPotentialCargo", client);
		//SetEntPropEnt(entity, Prop_Send, "m_hDeliveryCargo", client); //ROPES TO THE PACKAGE
		
		//SetEntPropEnt(entity, Prop_Data, "m_hFlareEnt", client);
		
		//SetEntPropEnt(client, Prop_Data, "m_hViewEntity", entity);
		//SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
		
		vec[0][2] = vec[0][2] + 8.0;
	}
	else
	{
		ReplyToCommand(client, "%t", "CMD_SpawnEnt_Usage");
		return Plugin_Handled;
	}
	
	TeleportEntity(entity, vec[0], vec[1], NULL_VECTOR);
	
	if(!StrEqual(SOUND_SPAWN, "", false))
	{
		EmitSoundToAll(SOUND_SPAWN, entity);
	}
	
	ShowActivity2(client, CMD_PREFIX, "%t", "CMD_SpawnEnt", buffer[0]);
	LogActionEx(client, "%t", "CMD_SpawnEnt", buffer[0]);
	return Plugin_Handled;
}

//-----STOCKS-----//
GivePlayerWeapon(client, String: weapon[], type)
{
	new String: buffer[64];
	if(type == 1)
	{
		Format(buffer, sizeof(buffer), "weapon_%s", weapon);
	}
	else
	{
		Format(buffer, sizeof(buffer), "item_%s", weapon);
	}
	return GivePlayerItem(client, buffer);
}

DisarmPlayer(client)
{
	for(new i = 0; i < 5; i++)
	{
		new weapon = -1;
		while((weapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			if(IsValidEntity(weapon))
			{
				RemovePlayerItem(client, weapon);
			}
		}
	}
	SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
	SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", 0);
	SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
	SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
}

LogActionEx(client, String: message[], any: ...)
{
	if(GetConVarBool(CVAR_LOG))
	{
		new String: buffer[256];
		SetGlobalTransTarget(LANG_SERVER);
		VFormat(buffer, sizeof(buffer), message, 3);
		LogMessage("%N: %s", client, buffer);
	}
}

bool: IsClientValid(client)
{
	return ((client > 0) && (client <= MaxClients));
}

ItemType(String: itemname[])
{
	for(new i = 0; i < sizeof(WeaponsList); i++)
	{
		if(StrEqual(itemname, WeaponsList[i], false))
		{
			return 1;
		}
	}
	for(new i = 0; i < sizeof(ItemsList); i++)
	{
		if(StrEqual(itemname, ItemsList[i], false))
		{
			return 2;
		}
	}
	return 0;
}

//-----FILTERS-----//
public bool: Filter_ExcludePlayers(entity, contentsMask, any: data)
{
	return !((entity > 0) && (entity <= MaxClients));
}