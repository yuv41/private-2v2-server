#include <cstrike>
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <pugsetup>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = {
    name = "CS:GO PugSetup: Score",
    author = "Techno, yuv41",
    description = "Prints the current match score at the end of a round.",
    version = PLUGIN_VERSION,
    url = ""
}

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (PugSetup_GetGameState() != GameState_Live) {
        return Plugin_Continue;
    }

    int ctScore = CS_GetTeamScore(CS_TEAM_CT);
    int tScore = CS_GetTeamScore(CS_TEAM_T);

    char ctName[64];
    char tName[64];

    GetTeamName(CS_TEAM_CT, ctName, sizeof(ctName));
    GetTeamName(CS_TEAM_T, tName, sizeof(tName));

    if ((tScore + ctScore) > 0) {
        if (tScore > ctScore) {
            PugSetup_MessageToAll("\x04[NewVision] \x0B%s \x07%i\x01 - \x04%i\x01 \x09%s", ctName, ctScore, tScore, tName);
        } else if (ctScore == tScore) {
            PugSetup_MessageToAll("\x04[NewVision] \x0B%s \x10%i\x01 - \x10%i\x01 \x09%s", ctName, ctScore, tScore, tName);
        } else {
            PugSetup_MessageToAll("\x04[NewVision] \x0B%s \x04%i\x01 - \x07%i\x01 \x09%s", ctName, ctScore, tScore, tName);
        }
    }

    return Plugin_Continue;
}
