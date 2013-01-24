/**
* DoD:S Block Class Respawn by Root
*
* Description:
*   Prevent immediately re-spawning after changing class (always or when player is hurt).
*
* Version 2.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ INCLUDES ]======================================================
#include <sourcemod>

// ====[ CONSTANTS ]=====================================================
#define PLUGIN_NAME     "DoD:S Block Class Respawn"
#define PLUGIN_VERSION  "2.0"

static const class_array[]    = { 6, 0, 0, 6 },
	String:class_names[][]    = { "Rifleman", "Assault", "Support", "Sniper", "Machine Gunner", "Rocket" },
	String:class_commands[][] =
{
	"cls_garand", "cls_tommy", "cls_bar",  "cls_spring", "cls_30cal", "cls_bazooka",
	"cls_k98",    "cls_mp40",  "cls_mp44", "cls_k98s",   "cls_mg42",  "cls_pschreck"
};

// ====[ VARIABLES ]=====================================================
new	Handle:blockchange_mode = INVALID_HANDLE;

// ====[ PLUGIN ]========================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Prevent immediately re-spawning after changing class",
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
	CreateConVar("dod_blockrespawn_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_SPONLY);
	blockchange_mode = CreateConVar("dod_blockrespawn", "1", "Determines when block immediately respawning after changing class within a respawn area:\n1 - When player is hurt\n2 - All times", FCVAR_PLUGIN, true, 0.0, true, 2.0);

	// Get all commands that changing player class
	for (new i = 0; i < sizeof(class_commands); i++)
	{
		// Using Reg*Cmd to intercept is in poor practice for already existing commands
		AddCommandListener(OnJoinClass, class_commands[i]);
	}
}

/* OnJoinClass()
 *
 * Called when a player has executed a join class command.
 * ---------------------------------------------------------------------- */
public Action:OnJoinClass(client, const String:command[], argc)
{
	// Make sure player is alive. Otherwise player may not respawn on joining team
	if (IsPlayerAlive(client))
	{
		// Get client's team
		new team = GetClientTeam(client);

		// Define a HEX-color code depends on client's team. Needed to show colored player class
		decl String:color[11];
		Format(color, sizeof(color), "%s", team == 2 ? "\x074D7942" : "\x07FF4040");

		// Once again loop all commands and check their matching
		for (new i = 0; i < sizeof(class_commands); i++)
		{
			// This thing is needed to convert commands as a integer
			if (StrEqual(command, class_commands[i]))
			{
				// And here we can realize that for: 1) Correctly setting player class 2) Showing that player will respawn as a desired class
				new desiredclass = i - class_array[team];

				// Block immediate re-spawning depends on mode
				switch (GetConVarInt(blockchange_mode))
				{
					case 1: // Dont allow player to be respawned if player was being hurt
					{
						if (GetClientHealth(client) < 100)
						{
							// Notify client about respawning next time
							PrintToChat(client, "\x01*You will respawn as %s%s", color, class_names[desiredclass]);
							SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", desiredclass);
							return Plugin_Handled;
						}
					}
					case 2: // Dont allow player to respawn at all
					{
						PrintToChat(client, "\x01*You will respawn as %s%s", color, class_names[desiredclass]);

						// Let's change only 'future class' depends on command, and block it
						SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", desiredclass);
						return Plugin_Handled;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}