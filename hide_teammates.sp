
/*	Copyright (C) 2017 IT-KiLLER
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod> 
#include <sdktools> 
#include <sdkhooks> 
#include <cstrike>
#include <colors_csgo>
#include <clientprefs>
#include <player_distance>
#pragma semicolon 1
#pragma newdecls required
#define TAG_COLOR 	"{green}[SM]{default}"

ConVar sm_hide_enabled, sm_hide_default_enabled, sm_hide_clientprefs_enabled, sm_hide_default_distance,sm_hide_minimum, sm_hide_maximum, sm_hide_team;

Handle g_HideCookie;
bool bEnabled = true;

Handle g_Rules[MAXPLAYERS + 1];

public Plugin myinfo =  
{ 
	name = "[CS:GO] Hide teammates realtime", 
	author = "intellild", 
	description = "A plugin that can !hide teammates with individual distances, in realtime", 
	version = "2.0", 
	url = "https://github.com/intellild/CSGO-Hide-teammates" 
} 

public void OnPluginStart() 
{ 
	RegConsoleCmd("sm_hide", Command_Hide); 
	sm_hide_enabled	= CreateConVar("sm_hide_enabled", "1", "Disabled/enabled [0/1]", _, true, 0.0, true, 1.0);
	sm_hide_default_enabled	= CreateConVar("sm_hide_default_enabled", "0", "Default enabled for each player [0/1]", _, true, 0.0, true, 1.0);
	sm_hide_clientprefs_enabled	= CreateConVar("sm_hide_clientprefs_enabled", "0", "Client preferences enabled [0/1]", _, true, 0.0, true, 1.0);
	sm_hide_default_distance  = CreateConVar("sm_hide_default_distance", "60", "Default distance [0-999]", _, true, 1.0, true, 999.0);
	sm_hide_minimum	= CreateConVar("sm_hide_minimum", "30", "The minimum distance a player can choose [1-999]", _, true, 1.0, true, 999.0);
	sm_hide_maximum	= CreateConVar("sm_hide_maximum", "300", "The maximum distance a player can choose [1-999]", _, true, 1.0, true, 999.0);
	sm_hide_team	= CreateConVar("sm_hide_team", "1", "Which teams should be able to use the command !hide [0=both, 1=CT, 2=T]", _, true, 0.0, true, 2.0);
	sm_hide_enabled.AddChangeHook(OnConVarChange);

	g_HideCookie = RegClientCookie("sm_hide", "hide teammates", CookieAccess_Protected);

	for(int client = 1; client <= MaxClients; client++)
	{
		Handle rule = PlayerDistance_CreateRule(client);
		g_Rules[client] = rule;
		PlayerDistance_SetRuleFlags(rule, EXCLUDE_SELF | EXCLUDE_ENERMY);

		if(IsClientInGame(client)) 
		{
			OnClientPutInServer(client);
			if(AreClientCookiesCached(client))
			{
				OnClientCookiesCached(client);
			}
		}
		else
		{
			PlayerDistance_DisableRule(rule);
		}
	}
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		CloseHandle(g_Rules[client]);
	}
}

public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		PlayerDistance_ResetRule(g_Rules[client]);
	}
}

public void OnClientPutInServer(int client) 
{ 
	if(!bEnabled) return;

	if (!IsFakeClient(client))
	{
		PlayerDistance_EnableRule(g_Rules[client]);
	}

	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client)) return;
	
	char sCookieValue[4];
	GetClientCookie(client, g_HideCookie, sCookieValue, sizeof(sCookieValue));

	Handle rule = g_Rules[client];

	if(sm_hide_clientprefs_enabled.BoolValue && !StrEqual(sCookieValue, ""))
	{
		float value = StringToFloat(sCookieValue);
		PlayerDistance_SettingAll(rule, value);
	}
	else if(sm_hide_default_enabled.BoolValue)
	{
		float value = sm_hide_default_distance.FloatValue;
		PlayerDistance_SettingAll(rule, value);
	}
}

public void OnClientDisconnect(int client)
{
	Handle rule = g_Rules[client];
	PlayerDistance_DisableRule(rule);
}

public void OnConVarChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue)) return;

	if (hCvar == sm_hide_enabled)
	{
		bEnabled = sm_hide_enabled.BoolValue;

		for(int client = 1; client <= MaxClients; client++) 
		{
			PlayerDistance_ResetRule(g_Rules[client]);

			if(IsClientInGame(client)) 
			{
				OnClientCookiesCached(client);
				if(bEnabled)
				{
					SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
				}
				else
				{
					SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
				}
			}
		}
	}

	if(hCvar == sm_hide_default_enabled || hCvar == sm_hide_clientprefs_enabled)
	{
		for(int client = 1; client <= MaxClients; client++) 
		{
			if(IsClientInGame(client)) 
			{
				OnClientCookiesCached(client);
			}
		}
	}
}

public Action Command_Hide(int client, int args) 
{ 
	if(!bEnabled)
	{
		CPrintToChat(client, "%s {red}Currently disabled", TAG_COLOR);
		return Plugin_Handled;
	}

	if(sm_hide_clientprefs_enabled.BoolValue && !AreClientCookiesCached(client))
	{
		CPrintToChat(client, "%s {red}please wait, your settings are retrieved...", TAG_COLOR);
		return Plugin_Handled;
	}

	float customdistance = -1.0;

	if (args == 1) 
	{
		char inputArgs[5];
		GetCmdArg(1, inputArgs, sizeof(inputArgs));
		customdistance = StringToFloat(inputArgs);
	}

	float value = 0.0;

	if((args == 1 ) && ( customdistance == -1.0 || (customdistance >= sm_hide_minimum.IntValue && customdistance <= sm_hide_maximum.IntValue) ) )  
	{
		value = (customdistance >= sm_hide_minimum.FloatValue && customdistance <= sm_hide_maximum.FloatValue) ? customdistance : sm_hide_default_distance.FloatValue;
		CPrintToChat(client,"%s {red}!hide{default} teammates are now {lightgreen}Enabled{default} with distance{orange} %.0f{default}. %s", TAG_COLOR, value, sm_hide_team.IntValue == 1 ? "{lightblue}Only for CTs." : sm_hide_team.IntValue==2 ? "{lightblue}Only for Ts." : "");
	}
	else if (args >=2 || args == 1 ? customdistance != 0.0 && !(customdistance >= sm_hide_minimum.IntValue && customdistance <= sm_hide_maximum.IntValue) : false) 
	{
		CPrintToChat(client,"%s {red}!hide{default} Wrong input, range %d-%d", TAG_COLOR, sm_hide_minimum.IntValue, sm_hide_maximum.IntValue);
	}
	else if (args == 1 && !customdistance) {
		CPrintToChat(client,"%s {red}!hide{default} teammates are now {red}Disabled{default}.", TAG_COLOR);
		value = 0.0;
	}

	if(sm_hide_clientprefs_enabled.BoolValue)
	{
		char sCookieValue[4];
		FormatEx(sCookieValue, sizeof(sCookieValue), "%.0f", value);
		SetClientCookie(client, g_HideCookie, sCookieValue);
	}

	PlayerDistance_SettingAll(g_Rules[client], value);
	return Plugin_Handled;
} 

public Action Hook_SetTransmit(int target, int client) 
{ 
	if(!bEnabled) return Plugin_Continue;

	Handle rule = g_Rules[client];
	if(PlayerDistance_MatchRule(rule, target))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue; 
}  

public bool OnlyTeam(int client, int target)
{
	if(sm_hide_team.IntValue == 1)
	{
		return GetClientTeam(client) == CS_TEAM_CT && CS_TEAM_CT == GetClientTeam(target);
	}
	else if (sm_hide_team.IntValue == 2)
	{
		return GetClientTeam(client) == CS_TEAM_T && CS_TEAM_T == GetClientTeam(target);
	}
	return GetClientTeam(client) == GetClientTeam(target);
}