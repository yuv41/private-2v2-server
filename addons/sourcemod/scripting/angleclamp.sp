#include <sourcemod>

public Plugin myinfo = 
{ 
	name = "ViewAngle Fix", 
	author = "Alvy Piper / sapphyrus", 
	description = "Normalizes out of bounds viewangles", 
	version = "0.2", 
	url = "github.com/sapphyrus/" 
};

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsPlayerAlive(client)) {
		return Plugin_Continue;
	}

	// clamp pitch
	if (angles[0] > 89.0) {
		angles[0] = 89.0;
	} else if (angles[0] < -89.0) {
		angles[0] = -89.0;
	}

	// normalize yaw
	if (angles[1] > 180.0 || angles[1] < -180.0) {
		float flRevolutions = angles[1] / 360.0;

		if (flRevolutions < 0.0) {
			flRevolutions = -flRevolutions;
		}

		int iRevolutions = RoundToFloor(flRevolutions);

		if (angles[1] > 0.0) {
			angles[1] -= iRevolutions * 360.0;
		} else {
			angles[1] += iRevolutions * 360.0;
		}
	}

	// clamp roll
	if (angles[2] > 50.0) {
		angles[2] = 50.0;
	} else if (angles[2] < -50.0) {
		angles[2] = -50.0;
	}

	return Plugin_Changed;
}