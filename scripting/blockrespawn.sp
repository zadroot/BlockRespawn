/**
* DoD:S Block Class Respawn by Root
*
* Description:
*   Prevents immediately re-spawning after changing player class within a spawn area (always or when player is hurt).
*
* Version 3.0
* Changelog & more info at http://goo.gl/4nKhJ
*/

#pragma semicolon 1

// ====[ CONSTANTS ]======================================================================
#define PLUGIN_NAME     "DoD:S Block Class Respawn"
#define PLUGIN_VERSION  "3.0"

// Define the GetEntProp condition for m_iDesiredPlayerClass netprop
#define m_iDesiredPlayerClass(%1) (GetEntProp(%1, Prop_Send, "m_iDesiredPlayerClass"))

enum
{
	CLASS_INIT = 0,
	TEAM_ALLIES = 2,
	TEAM_AXIS = 3,
	TEAM_SIZE = 4,
	MAX_CLASS = 6,
	MAX_HEALTH = 100
};

// ====[ VARIABLES ]======================================================================
static const String:block_cmds[][] = { "cls_random", "joinclass" },
	String:allies_cmds[][]  = { "cls_garand", "cls_tommy", "cls_bar",  "cls_spring", "cls_30cal", "cls_bazooka"  },
	String:axis_cmds[][]    = { "cls_k98",    "cls_mp40",  "cls_mp44", "cls_k98s",   "cls_mg42",  "cls_pschreck" },
	String:allies_cvars[][] =
{
	"mp_limit_allies_rifleman", "mp_limit_allies_assault", "mp_limit_allies_support", "mp_limit_allies_sniper", "mp_limit_allies_mg", "mp_limit_allies_rocket"
},
	String:axis_cvars[][] =
{
	"mp_limit_axis_rifleman", "mp_limit_axis_assault", "mp_limit_axis_support", "mp_limit_axis_sniper", "mp_limit_axis_mg", "mp_limit_axis_rocket"
};

new	classlimit[TEAM_SIZE][MAX_CLASS], Handle:blockchange_mode = INVALID_HANDLE;

// ====[ PLUGIN ]=========================================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Root",
	description = "Prevents immediately re-spawning after changing player class within a spawn area",
	version     = PLUGIN_VERSION,
	url         = "http://dodsplugins.com/"
};


/* OnPluginStart()
 *
 * When the plugin starts up.
 * --------------------------------------------------------------------------------------- */
public OnPluginStart()
{
	CreateConVar("dod_blockrespawn_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	blockchange_mode = CreateConVar("dod_blockrespawn", "1", "Determines a mode when prevent player respawning after changing class in a spawn area:\n1 - Prevent respawning when player is hurt\n2 - Always prevent respawning", FCVAR_PLUGIN, true, 0.0, true, 2.0);

	// Commands to block
	for (new i = 0; i < sizeof(block_cmds); i++)
	{
		AddCommandListener(OtherClass, block_cmds[i]);
	}

	// Get all commands and classlimit ConVars for both teams
	for (new i = 0; i < MAX_CLASS; i++)
	{
		// Using RegConsoleCmd to intercept is in poor practice for already existing commands, so hook those commands instead
		AddCommandListener(OnAlliesClass, allies_cmds[i]);
		AddCommandListener(OnAxisClass,   axis_cmds[i]);

		// Initialize team-specified classlimits
		classlimit[TEAM_ALLIES][i] = GetConVarInt(FindConVar(allies_cvars[i]));
		classlimit[TEAM_AXIS][i]   = GetConVarInt(FindConVar(axis_cvars[i]));

		// Hook any changes for classlimit cvars, otherwise we may have some problems in a future usage (some maps have different classlimit configs you know)
		HookConVarChange(FindConVar(allies_cvars[i]), UpdateClassLimits);
		HookConVarChange(FindConVar(axis_cvars[i]),   UpdateClassLimits);
	}
}

/* UpdateClasslimits()
 *
 * Called when value of classlimit convar is changed.
 * --------------------------------------------------------------------------------------- */
public UpdateClassLimits(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for (new i = 0; i < MAX_CLASS; i++)
	{
		// When classlimit value is changed (for any team/any class), just re-init variables again
		classlimit[TEAM_ALLIES][i] = GetConVarInt(FindConVar(allies_cvars[i]));
		classlimit[TEAM_AXIS][i]   = GetConVarInt(FindConVar(axis_cvars[i]));
	}
}

/* OnAlliesClass()
 *
 * Called when a player has executed a join class command for Allies team.
 * --------------------------------------------------------------------------------------- */
public Action:OnAlliesClass(client, const String:command[], argc)
{
	new mode = GetConVarInt(blockchange_mode);
	new team = GetClientTeam(client);

	// Make sure ConVar is initialized and player is alive, otherwise player may not respawn after selecting a team and a class (server may crash)
	if (IsPlayerAlive(client) && mode && team == TEAM_ALLIES)
	{
		new class = CLASS_INIT;
		new cvar  = CLASS_INIT;

		// Loop through available allies class commands
		for (new i = CLASS_INIT; i < sizeof(allies_cmds); i++)
		{
			if (StrEqual(command, allies_cmds[i]))
			{
				class = cvar = i;
				break;
			}
		}

		// Make sure desired player class is available in allies team
		if (IsClassAvailable(client, team, class, cvar))
		{
			switch (mode)
			{
				case 1: // Dont allow player to be respawned if player was being hurt
				{
					// If player is having less than 100 hp, which is used on most servers - block command
					if (GetClientHealth(client) < MAX_HEALTH)
					{
						PrintUserMessage(client, class, command);
						SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
						return Plugin_Handled;
					}
				}
				case 2:
				{
					// Change only 'future class' and block the command here
					PrintUserMessage(client, class, command);
					SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
					return Plugin_Handled;
				}
			}
		}
	}

	return Plugin_Continue;
}

/* OnAxisClass()
 *
 * Called when a player has executed a join class command for Axis team.
 * --------------------------------------------------------------------------------------- */
public Action:OnAxisClass(client, const String:command[], argc)
{
	new mode = GetConVarInt(blockchange_mode);

	// Get the client's team
	new team = GetClientTeam(client);

	// Check if player is using appropriate team class commands, or server may crash in some cases
	if (IsPlayerAlive(client) && mode && team == TEAM_AXIS)
	{
		// Prepare class and convar values
		new class = CLASS_INIT;
		new cvar  = CLASS_INIT;

		for (new i = CLASS_INIT; i < sizeof(axis_cmds); i++)
		{
			// Assign a class and a convar numbers as same than command
			if (StrEqual(command, axis_cmds[i]))
			{
				class = cvar = i;
				break;
			}
		}

		if (IsClassAvailable(client, team, class, cvar))
		{
			// Block immediately player re-spawning depends on mode
			switch (mode)
			{
				case 1:
				{
					if (GetClientHealth(client) < MAX_HEALTH)
					{
						// Notify client about respawning as desired class next time
						PrintUserMessage(client, class, command);
						SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
						return Plugin_Handled;
					}
				}
				case 2: // Dont allow player to respawn at all
				{
					PrintUserMessage(client, class, command);
					SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
					return Plugin_Handled;
				}
			}
		}
	}

	// Actually I wont block class commands at all
	return Plugin_Continue;
}

/* OtherClass()
 *
 * Called when a player has executed a random or other command to change class.
 * --------------------------------------------------------------------------------------- */
public Action:OtherClass(client, const String:command[], argc)
{
	// Block "joinclass/cls_random" commands if value != 0
	return GetConVarInt(blockchange_mode) ? Plugin_Handled : Plugin_Continue;
}

/* IsClassAvailable()
 *
 * Checks whether or not desired class is available via limit cvars.
 * --------------------------------------------------------------------------------------- */
bool:IsClassAvailable(client, team, desiredclass, cvarnumber)
{
	new class = CLASS_INIT;

	// Lets loop through all clients from same team
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			// If any classes which teammates are playing right now and matches with desired, increase amount of classes on every match
			if (m_iDesiredPlayerClass(i) == desiredclass) class++;
		}
	}

	if ((class >= classlimit[team][cvarnumber])         // Amount of classes in client's team is more OR same than value of appropriate ConVar
	&& (classlimit[team][cvarnumber] > -1)              // if ConVar value limit is obviously initialized (more than -1)
	|| (m_iDesiredPlayerClass(client)) == desiredclass) // or if current player's class is not a desired one
	{
		// Class is not available - reset amount of classes then
		class = CLASS_INIT;
		return false;
	}

	// Otherwise player may use this class
	return true;
}

/* PrintUserMessage()
 *
 * Prints default TextMsg usermessage with phrase.
 * --------------------------------------------------------------------------------------- */
PrintUserMessage(client, desiredclass, const String:command[])
{
	// Don't print message if player selected desired class twice
	if (m_iDesiredPlayerClass(client) != desiredclass)
	{
		// Start a simpler TextMsg usermessage for one client
		new Handle:bf = StartMessageOne("TextMsg", client);

		// Write into bitbuffer a "You will respawn as" phrase
		decl String:buffer[128];
		Format(buffer, sizeof(buffer), "\x03#Game_respawn_as");
		BfWriteString(bf, buffer);

		// Also write class string to properly show as which class you will respawn
		Format(buffer, sizeof(buffer), "#%s", command);

		// VALVe just called class names same as command names (check dod_english.txt), it makes name defines way easier
		BfWriteString(bf, buffer);

		// End this message. If message will not be sent, memory leak may occur, and all PrintToChat natives will not work!
		EndMessage();
	}
}