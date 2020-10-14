#include <sourcemod>

public Plugin:myinfo = 
{ 
	name = "ViewAngle Fix", 
	author = "Alvy Piper", 
	description = "Normalizes out of bounds viewangles, and does a hacky teleport fix.", 
	version = "0.1", 
	url = "github.com/AlvyPiper/" 
};

new Float:currentpos[3];
new Float:oldpos[3];


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	new bool:alive = IsPlayerAlive(client);

	if (cmdnum <= 0)
	{
		return Plugin_Handled;
	}
	
	if(!alive)
	{
		return Plugin_Continue;
	}
	
	if(alive)
	{
		GetClientAbsOrigin(client, currentpos);
		
		if(currentpos[0] == 0 && oldpos[0] != 0 && currentpos[1] == 0 && oldpos[1] != 0)
		{
			KickClient(client, "Teleporting");
			return Plugin_Handled;
		}
		
		oldpos[0] = currentpos[0];
		oldpos[1] = currentpos[1];
		oldpos[2] = currentpos[2];
		
		if (angles[0] > 89.0)
		{
			angles[0] = 89.0;
		}
			
		if (angles[0] < -89.0)
		{
			angles[0] = -89.0;
		}
				
		while (angles[1] > 180.0)
		{
			angles[1] -= 360.0;
		}
		
		while(angles[1] < -180.0)
		{
			angles[1] += 360.0;
		}
			
		if(angles[2] != 0.0)
		{
			angles[2] = 0.0;
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}