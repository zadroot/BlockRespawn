/**
* Block Class Respawn by Root
*
* Description:
*   Prevent class respawning within a respawn area (always or when player is hurt).
*
* Version 1.0.1
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ INCLUDES ]======================================================
#include <sourcemod>
#include <sdktools_functions>
#include <dodhooks>

// ====[ CONSTANTS ]=====================================================
#define PLUGIN_NAME     "Block Class Respawn"
#define PLUGIN_VERSION  "1.0.1"
#define MAX_SPAWNPOINTS 64

static const String:pointentity[][] = {"info_player_allies", "info_player_axis"};

// ====[ VARIABLES ]=====================================================
new	Handle:blockchange_mode = INVALID_HANDLE,
	Float:spawnposition[2][MAX_SPAWNPOINTS][3],
	sp_count[2],
	g_iOffset_Origin;

// ====[ PLUGIN ]========================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Prevent class respawning within a respawn area",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};


/* OnPluginStart()
 *
 * When the plugin starts up.
 * ---------------------------------------------------------------------- */
public OnPluginStart()
{
	// Create ConVars
	CreateConVar("dod_blockrespawn_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED);
	blockchange_mode = CreateConVar("dod_blockrespawn", "1", "Specified when block class changing within a respawn area:\n1 - When player is hurt\n2 - All times", FCVAR_PLUGIN, true, 0.0, true, 2.0);

	// Returns the offset of the specified network property
	if ((g_iOffset_Origin = FindSendPropOffs("CBaseEntity", "m_vecOrigin")) == -1)
		SetFailState("Fatal Error: Unable to find prop offset \"CBaseEntity::m_vecOrigin\"!");
}

/* OnMapStart()
 *
 * When the map starts.
 * ---------------------------------------------------------------------- */
public OnMapStart()
{
	for (new i = 0; i < sizeof(pointentity); i++)
	{
		// Team specified spawns entities: to start search set it to -1
		new entity = -1;

		// Every map has unique spawn points, so now we gonna reset all previous
		sp_count[i] = 0;

		// Searches for an entity by classname
		while ((entity = FindEntityByClassname(entity, pointentity[i])) != -1)
		{
			// Got a number of spawnareas. Store all the info_player_* vectors in an array
			if (sp_count[i] < MAX_SPAWNPOINTS)
				GetEntDataVector(entity, g_iOffset_Origin, spawnposition[i][sp_count[i]++]);
		}
	}
}

/* OnJoinClass()
 *
 * Called when a player has executed a join class command.
 * ---------------------------------------------------------------------- */
public Action:OnJoinClass(client, &playerClass)
{
	// Checking if player alive and around respawn area
	if (IsPlayerAlive(client) && IsPlayerNearSpawn(client))
	{
		// Block re-spawning depends on mode (when player is hurt or block changing in respawn at all)
		switch (GetConVarInt(blockchange_mode))
		{
			case 1: if (GetClientHealth(client) < 100) return Plugin_Handled;
			case 2: return Plugin_Handled;
		}
	}

	// Continue, otherwise we will not respawn even
	return Plugin_Continue;
}

/* IsPlayerNearSpawn()
 *
 * Checks if player is around respawn area.
 * ---------------------------------------------------------------------- */
bool:IsPlayerNearSpawn(client)
{
	// When storing make sure you don't include the index then returns the client's origin vector
	decl Float:distance[3];
	GetClientAbsOrigin(client, distance);

	// Since info_player_allies = 0 and info_player_axis equal to 1, subtract team offset to get team spawn points for a player
	new team = GetClientTeam(client) - 2;

	for (new i = 0; i < sp_count[team]; i++)
	{
		// Yeah player is within a respawn area - so check if distance from last spawn point is more than 500 units (float)
		if (GetVectorDistance(spawnposition[team][i], distance) <= 500.0)
			return true;
	}

	return false;
}