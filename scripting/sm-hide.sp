#include <sourcemod> 
#include <sdktools> 
#include <sdkhooks> 

#pragma semicolon 1
#pragma newdecls required

#define MESSAGE_PREFIX "[\x02Hide\x01]"

bool b_IsHidden[MAXPLAYERS+1];

ConVar b_OnlyForAdmins;
ConVar b_Enabled;
ConVar b_OnlyTeammates;
ConVar b_DisableSounds;

public Plugin myinfo = 
{
	name = "Hide Other Players",
	author = "stephen473(Hardy), B3none",
	description = "Players/admins can hide other players",
	version = "1.3.1",
	url = "https://github.com/b3none"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_hide", Command_Hide); 
	RegConsoleCmd("sm_hideplayers", Command_Hide);
	
	b_Enabled = CreateConVar("sm_hideplayers_enable", "1", "Enable/Disable Plugin | 1 = Enable | 0 = Disable");
	b_OnlyForAdmins = CreateConVar("sm_hideplayers_only_admin", "0", "Only admins can use sm_hide command? | 1 = Only Admins | 0 = All Players");
	b_OnlyTeammates = CreateConVar("sm_hideplayers_only_teammates", "1", "Hide only teammates of client? | 1 = Yes | 0 = No");
	b_DisableSounds = CreateConVar("sm_hideplayers_mutesounds", "1", "Mute other player weapons sound? | 1 = Yes | 0 = No");
	
	AutoExecConfig(true, "sm_hide");
	CheckBool();
}

public void CheckBool()
{
	if (b_DisableSounds.BoolValue) {
		AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
		AddNormalSoundHook(Hook_NormalSound);		
	}
}

public void OnClientPutInServer(int client)
{		
	SDKHook(client, SDKHook_SetTransmit, SetTransmit);
}

public Action SetTransmit(int entity, int client) 
{ 
    if (IsClientInGame(client))
    {
    	if (b_IsHidden[client])
    	{
    		if (client != entity && 0 < entity <= MaxClients)
    		{
    			if(!b_OnlyTeammates.BoolValue)
    			{		
    				return Plugin_Handled;
    			}
    			else if (GetClientTeam(client) == GetClientTeam(entity))
    			{
    				return Plugin_Handled;
    			}
    		}
    	}			
	}		
    
    return Plugin_Continue; 
}  

public Action Command_Hide(int client, int args) 
{
	if (IsClientInGame(client))
	{
		if(b_Enabled.BoolValue)
		{
			if(b_OnlyForAdmins.BoolValue)
			{
				AdminId b_Admin = GetUserAdmin(client);
				
				if (b_Admin != INVALID_ADMIN_ID)
				{
					if (b_IsHidden[client] == false)
    				{	
    					b_IsHidden[client] = true;
   					}
					else if (b_IsHidden[client] == true)
					{
						b_IsHidden[client] = false;
					}
	
					PrintToChat(client, "%s %s", MESSAGE_PREFIX, b_IsHidden[client] ? "You're hided the players.":"You will see other players after this!");		
				}
				else
				{
					PrintToChat(client, "%s You must be admin to use this command.", MESSAGE_PREFIX);
				}
			}				
				
			else
			{
				if (b_IsHidden[client] == false)
    			{
    				b_IsHidden[client] = true;
   				}
				else if (b_IsHidden[client] == true)
				{
					b_IsHidden[client] = false;
				}

				PrintToChat(client, "%s %s", MESSAGE_PREFIX, b_IsHidden[client] ? "You're hided the players.":"You will see other players after this!");
			}			
			
		}	

		else
		{
			PrintToChat(client, "%s Plugin disabled.", MESSAGE_PREFIX);
		}
	}
	
	else
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
} 

public Action Hook_NormalSound(clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{	
	int i, j;
	
	for (i = 0; i < numClients; i++)
	{
		if (b_IsHidden[clients[i]] && GetClientTeam(clients[i]) == GetClientTeam(clients[i]))
		{
			// Remove the client from the array.
			for (j = i; j < numClients-1; j++)
			{
				clients[j] = clients[j+1];
			}
			
			numClients--;
			i--;
		}
	}
	
	return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public Action CSS_Hook_ShotgunShot(const char[] te_name, const Players[], int numClients, float delay)
{
	// Check which clients need to be excluded.
	int[] newClients = new int[MaxClients];
	int client;
	int i;
	int newTotal = 0;
	
	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (!b_IsHidden[client])
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
	{
		return Plugin_Continue;
	}
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
	{
		return Plugin_Stop;
	}
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}
