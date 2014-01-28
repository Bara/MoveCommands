/*
	ToDo:
		- Exchange Teams
		- Swap all Players (CT/T/Both) to CT/T/Spec

	Changes:
		- Use of GetEngineVersion instead of GetFolderName


*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <colors>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <updater>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION "1.2.54"

#define UPDATE_URL    "http://update.bara.in/movecommands.txt"

new Handle:hAdminMenu;

new Handle:hEnableAdminMenu = INVALID_HANDLE;
new Handle:hEnableAFK = INVALID_HANDLE;
new Handle:hEnableResetScoreCommand = INVALID_HANDLE;
new Handle:hEnableSpec = INVALID_HANDLE;
new Handle:hEnableSwap = INVALID_HANDLE;
new Handle:hEnableSwapCT = INVALID_HANDLE;
new Handle:hEnableSwapT = INVALID_HANDLE;
new Handle:hEnableFSwap = INVALID_HANDLE;
new Handle:hEnableSwapRoundEnd = INVALID_HANDLE;
new Handle:hEnableSwapDeath = INVALID_HANDLE;
new Handle:hBombDrop = INVALID_HANDLE;
new Handle:hDefuserDrop = INVALID_HANDLE;
new Handle:hEnableResetScore = INVALID_HANDLE;
new Handle:hEnableTeamBalance = INVALID_HANDLE;

new bool:SwapRoundEnd[MAXPLAYERS+1] = false;
new bool:SwapPlayerDeath[MAXPLAYERS+1] = false;

new String:sMoveTag[64];

new TCount;
new CTCount;
new bool:Balance;

public Plugin:myinfo = 
{
	name = "Move Commands ( ResetScore, Switch, Spec)",
	author = "Bara",
	description = "Plugin to switch player and reset score",
	version = PLUGIN_VERSION,
	url = "www.bara.in"
}

public OnPluginStart()
{
	LoadTranslations("movecommands.phrases");
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	if(GetEngineVersion() != Engine_CSS || GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Unsupported Game! Only CS:S and CS:GO");
	}
	
	Format(sMoveTag, sizeof(sMoveTag), "%T", "MessageTag", LANG_SERVER);
	
	CreateConVar("movecommands_version", PLUGIN_VERSION, "Move Commands", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	AutoExecConfig_SetFile("plugin.movecommands", "sourcemod");
	AutoExecConfig_SetCreateFile(true);
	
	// Enable/Disable Commands
	hEnableAdminMenu = AutoExecConfig_CreateConVar("movecommands_enable_adminmenu", "1", "Enable / Disable MoveCommands in Adminmenu",_, true, 0.0, true, 1.0);
	hEnableResetScoreCommand = AutoExecConfig_CreateConVar("movecommands_enable_resetscore_command", "0", "Enable / Disable ResetScore Command",_, true, 0.0, true, 1.0);
	hEnableAFK = AutoExecConfig_CreateConVar("movecommands_enable_afk", "1", "Enable / Disable AFK Command",_, true, 0.0, true, 1.0);
	hEnableSpec = AutoExecConfig_CreateConVar("movecommands_enable_spec", "1", "Enable / Disable Spec Command",_, true, 0.0, true, 1.0);
	hEnableSwap = AutoExecConfig_CreateConVar("movecommands_enable_swap", "1", "Enable / Disable Swap Command",_, true, 0.0, true, 1.0);
	hEnableSwapCT = AutoExecConfig_CreateConVar("movecommands_enable_swap_ct", "1", "Enable / Disable Swap CT Command",_, true, 0.0, true, 1.0);
	hEnableSwapT = AutoExecConfig_CreateConVar("movecommands_enable_swap_t", "1", "Enable / Disable Swap T Command",_, true, 0.0, true, 1.0);
	hEnableFSwap = AutoExecConfig_CreateConVar("movecommands_enable_fswap", "1", "Enable / Disable Force Swap Command",_, true, 0.0, true, 1.0);
	hEnableSwapRoundEnd = AutoExecConfig_CreateConVar("movecommands_enable_swaproundend", "1", "Enable / Disable Swap Round End Command",_, true, 0.0, true, 1.0);
	hEnableSwapDeath = AutoExecConfig_CreateConVar("movecommands_enable_swapdeath", "1", "Enable / Disable Swap Player Death Command",_, true, 0.0, true, 1.0);
	
	// Enable/Disable Drops
	hBombDrop = AutoExecConfig_CreateConVar("movecommands_enable_drop_bomb", "1", "Enable / Disable Bomb Drop",_, true, 0.0, true, 1.0);
	hDefuserDrop = AutoExecConfig_CreateConVar("movecommands_enable_drop_defuser", "1", "Enable / Disable Defuser Drop",_, true, 0.0, true, 1.0);
	
	// Enable/Disable Reset Score
	hEnableResetScore = AutoExecConfig_CreateConVar("movecommands_enable_resetscore", "0", "Enable / Disable ResetScore after Swap/Spec Player",_, true, 0.0, true, 1.0);

	// Enable/Disable Team Balancer
	hEnableTeamBalance = AutoExecConfig_CreateConVar("movecommands_enable_teamabalancer", "0", "Enable / Disable Team Balancer",_, true, 0.0, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	RegAdminCmd("sm_spec", Command_Spec, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swap", Command_Swap, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swapct", Command_SwapCT, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swapt", Command_SwapT, ADMFLAG_GENERIC);
	RegAdminCmd("sm_fswap", Command_FSwap, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swaproundend", Command_SwapRoundEnd, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swapdeath", Command_SwapPlayerDeath, ADMFLAG_GENERIC);

	RegConsoleCmd("sm_afk", Command_AFK);

	RegConsoleCmd("sm_resetscore", Command_ResetScore);
	RegConsoleCmd("sm_scorereset", Command_ResetScore);
	RegConsoleCmd("sm_rs", Command_ResetScore);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_end", Event_RoundEnd);
	
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public OnMapStart()
{
	if(GetConVarInt(hEnableTeamBalance))
	{
		TCount = 0;
		CTCount = 0;
		for(new i = 1; i <= MaxClients; i++)
		{
			if (IsClientValid(i))
			{
				ChangeTeamCount(GetClientTeam(i), 1);
			}
		}

		CheckBalance();
	}
}

public Event_PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "killer"));
	
	if(IsClientValid(client))
	{
		if(SwapPlayerDeath[client])
		{
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				SwapPlayerDeath[client] = false;
				
				if(GetConVarInt(hEnableResetScore))
				{
					ResetScore(client);
				}
					
				CS_SwitchTeam(client, CS_TEAM_T);
				CPrintToChatAll("%t", "MovedTwithoutAdmin", sMoveTag, client);
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				SwapPlayerDeath[client] = false;
				
				if(GetConVarInt(hEnableResetScore))
				{
					ResetScore(client);
				}
				
				CS_SwitchTeam(client, CS_TEAM_CT);
				CPrintToChatAll("%t", "MovedCTwithoutAdmin", sMoveTag, client);
			}
		}

		if(IsClientValid(killer))
		{
			if(!GetConVarInt(hEnableTeamBalance))
			{
				return;
			}

			if(Balance)
			{
				return;
			}

			if(client == killer || IsFakeClient(client))
			{
				return;
			}

			new team = GetClientTeam(client);

			if ( team != CS_TEAM_T && team != CS_TEAM_CT )
			{
				return;
			}

			if ( team != ( (TCount > CTCount) ? CS_TEAM_T : CS_TEAM_CT ) )
			{
				return;
			}

			team = team == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T;

			new Handle:pack = CreateDataPack();
			WritePackCell(pack, client);
			WritePackCell(pack, team);
			CreateTimer(0.1, Timer_ChangeClientTeam, pack);
		}
	}
}

public Event_PlayerTeam(Handle:event,const String:name[],bool:dontBroadcast)
{
	new oldTeam = GetEventInt(event, "oldteam");
	new newTeam = GetEventInt(event, "team");
	new bool:disconnect = GetEventBool(event, "disconnect");

	if(GetConVarInt(hEnableTeamBalance))
	{
		ChangeTeamCount(oldTeam, -1);

		if(!disconnect)
		{
			ChangeTeamCount(newTeam, 1);
		}

		CheckBalance();
	}
}

public Event_RoundEnd(Handle:event,const String:name[],bool:dontBroadcast)
{	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(SwapRoundEnd[i])
			{
				if(GetClientTeam(i) == CS_TEAM_CT)
				{
					SwapRoundEnd[i] = false;
					
					if(GetConVarInt(hEnableResetScore))
					{
						ResetScore(i);
					}
					
					CS_SwitchTeam(i, CS_TEAM_T);
					CPrintToChatAll("%t", "MovedTwithoutAdmin", sMoveTag, i);
				}
				else if(GetClientTeam(i) == CS_TEAM_T)
				{
					SwapRoundEnd[i] = false;
					
					if(GetConVarInt(hEnableResetScore))
					{
						ResetScore(i);
					}
					
					CS_SwitchTeam(i, CS_TEAM_CT);
					CPrintToChatAll("%t", "MovedCTwithoutAdmin", sMoveTag, i);
				}
			}
		}
	}
}

public Action:Command_AFK(client, args)
{
	if(!GetConVarInt(hEnableAFK))
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[client])
	{
		return Plugin_Handled;
	}
	
	if(SwapPlayerDeath[client])
	{
		return Plugin_Handled;
	}
	
	if(GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		CPrintToChatAll("%t", "AFK", sMoveTag, client);
	}

	return Plugin_Handled;
}

public Action:Command_ResetScore(client, args)
{
	if(!GetConVarInt(hEnableResetScoreCommand))
	{
		return Plugin_Handled;
	}

	if(GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT)
	{
		ResetScore(client);
	}
	else
	{
		CPrintToChat(client, "%t", "WrongTeam", sMoveTag);
	}
	
	return Plugin_Handled;
}

public Action:Command_Spec(client, args)
{
	if(!GetConVarInt(hEnableSpec))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_spec <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[target])
	{
		SwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
		SwitchPlayerSpecTeam(client, target);
	}
	
	if(SwapPlayerDeath[target])
	{
		SwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
		SwitchPlayerSpecTeam(client, target);
	}

	SwitchPlayerSpecTeam(client, target);
	return Plugin_Handled;	
}

public Action:Command_Swap(client, args)
{
	if(!GetConVarInt(hEnableSwap))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swap <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[target])
	{
		SwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	if(SwapPlayerDeath[target])
	{
		SwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	SwitchPlayerOtherTeam(client, target);
	return Plugin_Handled;	
}

public Action:Command_SwapCT(client, args)
{
	if(!GetConVarInt(hEnableSwapCT))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapct <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[target])
	{
		SwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	if(SwapPlayerDeath[target])
	{
		SwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	SwitchPlayerCTTeam(client, target);
	return Plugin_Handled;	
}

public Action:Command_SwapT(client, args)
{
	if(!GetConVarInt(hEnableSwapT))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapt <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[target])
	{
		SwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	if(SwapPlayerDeath[target])
	{
		SwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	SwitchPlayerTTeam(client, target);
	return Plugin_Handled;	
}

public Action:Command_SwapRoundEnd(client, args)
{
	if(!GetConVarInt(hEnableSwapRoundEnd))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swaproundend <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[target])
	{
		CPrintToChat(client, "%t", "SwapRoundEndAlready", sMoveTag, target);
		return Plugin_Handled;
	}
	
	if(SwapPlayerDeath[target])
	{
		CPrintToChat(client, "%t", "SwapPlayerDeathAlready", sMoveTag, target);
		return Plugin_Handled;
	}

	SwitchRoundEndPlayerOtherTeam(client, target);
	return Plugin_Handled;	
}

public Action:Command_SwapPlayerDeath(client, args)
{
	if(!GetConVarInt(hEnableSwapDeath))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapdeath <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}
	
	if(SwapRoundEnd[target])
	{
		CPrintToChat(client, "%t", "SwapRoundEndAlready", sMoveTag, target);
		return Plugin_Handled;
	}
	
	if(SwapPlayerDeath[target])
	{
		CPrintToChat(client, "%t", "SwapPlayerDeathAlready", sMoveTag, target);
		return Plugin_Handled;
	}

	SwitchPlayerDeathPlayerOtherTeam(client, target);
	return Plugin_Handled;	
}

public Action:Command_FSwap(client, args)
{
	if(!GetConVarInt(hEnableFSwap))
	{
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_fswap <#UserID|Name>");
		return Plugin_Handled;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	FSwitchPlayerOtherTeam(client, target);
	return Plugin_Handled;	
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		hAdminMenu = INVALID_HANDLE;
	}
}
 
public OnAdminMenuReady(Handle:topmenu)
{
	if(!GetConVarInt(hEnableAdminMenu))
	{
		return;
	}
	
	if (topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;
	AttachAdminMenu();
}

AttachAdminMenu()
{
	new TopMenuObject:menu_category = AddToTopMenu(hAdminMenu, "movecommands", TopMenuObject_Category, Handle_Category, INVALID_TOPMENUOBJECT, "movecommands", ADMFLAG_GENERIC);
	if( menu_category == INVALID_TOPMENUOBJECT )
	{
		return;
	}
	
	if(GetConVarInt(hEnableSwap))
	{
		AddToTopMenu(hAdminMenu, "sm_swap", TopMenuObject_Item, AdminMenu_SwapPlayer, menu_category, "sm_swap", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapCT))
	{
		AddToTopMenu(hAdminMenu, "sm_swapct", TopMenuObject_Item, AdminMenu_SwapCTPlayer, menu_category, "sm_swapct", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapT))
	{
		AddToTopMenu(hAdminMenu, "sm_swapt", TopMenuObject_Item, AdminMenu_SwapTPlayer, menu_category, "sm_swapt", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableFSwap))
	{
		AddToTopMenu(hAdminMenu, "sm_fswap", TopMenuObject_Item, AdminMenu_FSwapPlayer, menu_category, "sm_fswap", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapRoundEnd))
	{
		AddToTopMenu(hAdminMenu, "sm_swaproundend", TopMenuObject_Item, AdminMenu_SwapRoundEndPlayer, menu_category, "sm_swaproundend", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapDeath))
	{
		AddToTopMenu(hAdminMenu, "sm_swapdeath", TopMenuObject_Item, AdminMenu_SwapDeathPlayer, menu_category, "sm_swapdeath", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSpec))
	{
		AddToTopMenu(hAdminMenu, "sm_spec", TopMenuObject_Item, AdminMenu_SpecPlayer, menu_category, "sm_spec", ADMFLAG_GENERIC);
	}
}

public Handle_Category( Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength )
{
	if(action == TopMenuAction_DisplayTitle)
	{
		Format( buffer, maxlength, "%T", "AdminMenuTitle", param);
	}
	else if(action == TopMenuAction_DisplayOption)
	{
		Format( buffer, maxlength, "%T", "AdminMenuTitle", param);
	}
}

public AdminMenu_SwapPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwap", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SwapDisplayInfoMenu(param);
	}
}

public AdminMenu_SwapCTPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapCT", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SwapCTDisplayInfoMenu(param);
	}
}

public AdminMenu_SwapTPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapT", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SwapTDisplayInfoMenu(param);
	}
}

public AdminMenu_FSwapPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleFSwap", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		FSwapDisplayInfoMenu(param);
	}
}

public AdminMenu_SwapRoundEndPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapRE", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SwapRoundEndDisplayInfoMenu(param);
	}
}

public AdminMenu_SwapDeathPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapPD", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SwapPlayerDeathDisplayInfoMenu(param);
	}
}

public AdminMenu_SpecPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleSpec", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		SpecDisplayInfoMenu(param);
	}
}

SwapDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SwapPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

SwapCTDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SwapCTPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerListCT(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

SwapTDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SwapTPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerListT(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

SwapRoundEndDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SwapRoundEndPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

SwapPlayerDeathDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SwapPlayerDeathPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

FSwapDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_FSwapPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

SpecDisplayInfoMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SpecPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

/*NoPlayersDisplayInfoMenu(client)
{
	decl String:NoPlayer[64];
	Format(NoPlayer, sizeof(NoPlayer), "%t", "AdminMenuNoPlayer");
	
	new Handle:hMenu = CreateMenu(MenuHandler_NoPlayer);
	SetMenuTitle(hMenu, "%t", "AdminMenuTitleNoPlayer");
	SetMenuExitBackButton(hMenu, true);
	AddMenuItem(hMenu, "", NoPlayer);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_NoPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
		}
	}
}*/

public MenuHandler_SwapPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			SwitchPlayerOtherTeam(param1, target);
			SwapDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			SwitchPlayerOtherTeam(param1, target);
			SwapDisplayInfoMenu(param1);
		}
		else
		{
			SwitchPlayerOtherTeam(param1, target);
			SwapDisplayInfoMenu(param1);
		}
	}
}

public MenuHandler_SwapCTPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			SwitchPlayerCTTeam(param1, target);
			SwapCTDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			SwitchPlayerCTTeam(param1, target);
			SwapCTDisplayInfoMenu(param1);
		}
		else
		{
			SwitchPlayerCTTeam(param1, target);
			SwapCTDisplayInfoMenu(param1);
		}
	}
}

public MenuHandler_SwapTPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			SwitchPlayerTTeam(param1, target);
			SwapTDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			SwitchPlayerTTeam(param1, target);
			SwapTDisplayInfoMenu(param1);
		}
		else
		{
			SwitchPlayerTTeam(param1, target);
			SwapTDisplayInfoMenu(param1);
		}
	}
}

public MenuHandler_SwapRoundEndPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			SwapRoundEndDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			SwapRoundEndDisplayInfoMenu(param1);
		}
		else
		{
			SwitchRoundEndPlayerOtherTeam(param1, target);
			SwapRoundEndDisplayInfoMenu(param1);
		}
	}
}

public MenuHandler_SwapPlayerDeathPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			SwapPlayerDeathDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			SwapPlayerDeathDisplayInfoMenu(param1);
		}
		else
		{
			SwitchPlayerDeathPlayerOtherTeam(param1, target);
			SwapPlayerDeathDisplayInfoMenu(param1);
		}
	}
}

public MenuHandler_FSwapPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			FSwitchPlayerOtherTeam(param1, target);
			FSwapDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			FSwitchPlayerOtherTeam(param1, target);
			FSwapDisplayInfoMenu(param1);
		}
		else
		{
			FSwitchPlayerOtherTeam(param1, target);
			FSwapDisplayInfoMenu(param1);
		}
	}
}

public MenuHandler_SpecPlayer(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != INVALID_HANDLE)
			{
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			}
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		new userid = StringToInt(info);
		new target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(SwapRoundEnd[target])
		{
			SwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", sMoveTag, target);
			SwitchPlayerSpecTeam(param1, target);
			SpecDisplayInfoMenu(param1);
		}
		else if(SwapPlayerDeath[target])
		{
			SwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", sMoveTag, target);
			SwitchPlayerSpecTeam(param1, target);
			SpecDisplayInfoMenu(param1);
		}
		else
		{
			SwitchPlayerSpecTeam(param1, target);
			SpecDisplayInfoMenu(param1);
		}
	}
}

SwitchPlayerOtherTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);
			if(GetConVarInt(hDefuserDrop))
			{
				GivePlayerItem(target, "item_defuser");
			}
			ForcePlayerSuicide(target);
			LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
		{
			ChangeClientTeam(target, CS_TEAM_T);
			LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		}
		
		CPrintToChatAll("%t", "MovedT", sMoveTag, client, target);
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		ChangeClientTeam(target, CS_TEAM_CT);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedCT", sMoveTag, client, target);
	}
	
	return;
}

SwitchPlayerCTTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	if(GetClientTeam(target) != CS_TEAM_CT)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_CT);
			if(GetConVarInt(hDefuserDrop))
			{
				GivePlayerItem(target, "item_defuser");
			}
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
		{
			CS_SwitchTeam(target, CS_TEAM_CT);
		}
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedCT", sMoveTag, client, target);
	}
	else
	{
		CPrintToChat(client, "%t", "PlayerInvalid", sMoveTag);
	}
	
	return;
}

SwitchPlayerTTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	if(GetClientTeam(target) != CS_TEAM_T)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);
			if(GetConVarInt(hDefuserDrop))
			{
				GivePlayerItem(target, "item_defuser");
			}
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
		{
			CS_SwitchTeam(target, CS_TEAM_T);
		}
		LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		CS_UpdateClientModel(target);
		CPrintToChatAll("%t", "MovedT", sMoveTag, client, target);
	}
	else
	{
		CPrintToChat(client, "%t", "PlayerInvalid", sMoveTag);
	}
	
	return;
}

SwitchRoundEndPlayerOtherTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		if(!IsPlayerAlive(target))
		{
			SwitchPlayerOtherTeam(client, target);
		}
		else
		{
			SwapRoundEnd[target] = true;
			LogAction(client, target, "\"%L\" was moved to T by \"%L\" on Round End", target, client);
			CPrintToChatAll("%t", "MovedTRE", sMoveTag, target, client);
		}
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		if(!IsPlayerAlive(target))
		{
			SwitchPlayerOtherTeam(client, target);
		}
		else
		{
			SwapRoundEnd[target] = true;
			LogAction(client, target, "\"%L\" was moved to CT by \"%L\" on Round End", target, client);
			CPrintToChatAll("%t", "MovedCTRE", sMoveTag, target, client);
		}
	}
	
	return;
}

SwitchPlayerDeathPlayerOtherTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		if(!IsPlayerAlive(target))
		{
			SwitchPlayerOtherTeam(client, target);
		}
		else
		{
			SwapPlayerDeath[target] = true;
			LogAction(client, target, "\"%L\" was moved to T by \"%L\" on Player Death", target, client);
			CPrintToChatAll("%t", "MovedTPD", sMoveTag, target, client, target);
		}
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		if(!IsPlayerAlive(target))
		{
			SwitchPlayerOtherTeam(client, target);
		}
		else
		{
			SwapPlayerDeath[target] = true;
			LogAction(client, target, "\"%L\" was moved to CT by \"%L\" on Player Death", target, client);
			CPrintToChatAll("%t", "MovedCTPD", sMoveTag, target, client, target);
		}
	}
	
	return;
}

FSwitchPlayerOtherTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);
			if(GetConVarInt(hDefuserDrop))
			{
				GivePlayerItem(target, "item_defuser");
			}
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
		{
			CS_SwitchTeam(target, CS_TEAM_T);
		}
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedT", sMoveTag, client, target);
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		CS_SwitchTeam(target, CS_TEAM_CT);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		CS_UpdateClientModel(target);
		
		CPrintToChatAll("%t", "MovedCT", sMoveTag, client, target);
	}
	
	return;
}

SwitchPlayerSpecTeam(client, target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	if (GetClientTeam(target) != CS_TEAM_SPECTATOR)
	{
		SwapPlayerDeath[target] = false;
		SwapRoundEnd[target] = false;
		
		if(GetConVarInt(hEnableResetScore))
		{
			ResetScore(target);
		}
		
		ChangeClientTeam(target, CS_TEAM_SPECTATOR);
		LogAction(client, target, "\"%L\" was moved to Spec by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedSpec", sMoveTag, client, target);
	}
	return;
}

CheckClients(client, target)
{
	if (target == 0)
	{
		CPrintToChat(client, "%t", "PlayerNoLongerValid", sMoveTag);
	}
	else if (!CanUserTarget(client, target))
	{
		CPrintToChat(client, "%t", "PlayerInvalid", sMoveTag);
	}
}

AddPlayerList(Handle:hMenu)
{
	decl String:name[MAX_NAME_LENGTH];
	decl String:listname[128];
	decl String:target[32];
	decl String:TeamName[5];
	decl String:SwapTyp[32];
	new id;
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) < 2)
			{
				continue;
			}
			
			if(SwapRoundEnd[i])
			{
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypeRE");
			}
			
			if(SwapPlayerDeath[i])
			{
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypePD");
			}
			
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamCTName");
			}
			
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamTName");
			}
			
			GetClientName(i, name, 31);
			id = GetClientUserId(i);
			IntToString(id, target, sizeof(target));
			
			if(SwapRoundEnd[i] || SwapPlayerDeath[i])
			{
				Format(listname, sizeof(listname),"[%s] %s (%s) [%s]", SwapTyp, name, target, TeamName);
			}
			
			if(!SwapRoundEnd[i] && !SwapPlayerDeath[i])
			{
				Format(listname, sizeof(listname),"%s (%s) [%s]", name, target, TeamName);
			}
			
			AddMenuItem(hMenu, target, listname);
		}
	}
}

AddPlayerListCT(Handle:hMenu)
{
	decl String:name[MAX_NAME_LENGTH];
	decl String:listname[128];
	decl String:target[32];
	decl String:TeamName[5];
	decl String:SwapTyp[32];
	new id;
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) != CS_TEAM_T)
			{
				continue;
			}
			
			if(SwapRoundEnd[i])
			{
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypeRE");
			}
			
			if(SwapPlayerDeath[i])
			{
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypePD");
			}
			
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamCTName");
			}
			
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamTName");
			}
			
			if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamSpecName");
			}
			
			GetClientName(i, name, 31);
			id = GetClientUserId(i);
			IntToString(id, target, sizeof(target));
			
			if(SwapRoundEnd[i] || SwapPlayerDeath[i])
			{
				Format(listname, sizeof(listname),"[%s] %s (%s) [%s]", SwapTyp, name, target, TeamName);
			}
			
			if(!SwapRoundEnd[i] && !SwapPlayerDeath[i])
			{
				Format(listname, sizeof(listname),"%s (%s) [%s]", name, target, TeamName);
			}
			
			AddMenuItem(hMenu, target, listname);
		}
	}
}

AddPlayerListT(Handle:hMenu)
{
	decl String:name[MAX_NAME_LENGTH];
	decl String:listname[128];
	decl String:target[32];
	decl String:TeamName[12];
	decl String:SwapTyp[32];
	new id;
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) != CS_TEAM_CT)
			{
				continue;
			}
			
			if(SwapRoundEnd[i])
			{
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypeRE");
			}
			
			if(SwapPlayerDeath[i])
			{
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypePD");
			}
			
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamCTName");
			}
			
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamTName");
			}
			
			if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
			{
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamSpecName");
			}
			
			GetClientName(i, name, 31);
			id = GetClientUserId(i);
			IntToString(id, target, sizeof(target));
			
			if(SwapRoundEnd[i] || SwapPlayerDeath[i])
			{
				Format(listname, sizeof(listname),"[%s] %s (%s) [%s]", SwapTyp, name, target, TeamName);
			}
			
			if(!SwapRoundEnd[i] && !SwapPlayerDeath[i])
			{
				Format(listname, sizeof(listname),"%s (%s) [%s]", name, target, TeamName);
			}
			
			AddMenuItem(hMenu, target, listname);
		}
	}
}

ResetScore(client)
{
	if(GetEngineVersion() == Engine_CSS)
	{
		if(GetClientFrags(client) == 0 && GetClientDeaths(client) == 0)
		{
			PrintToChat(client, "%t", "AlreadyReset", sMoveTag);
		}
		else
		{
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
			SetEntProp(client, Prop_Data, "m_iDeaths", 0);
			CPrintToChatAll("%t", "ResetScore", sMoveTag, client);

		}
	}
	else if(GetEngineVersion() == Engine_CSGO)
	{
		if(GetClientFrags(client) == 0 && GetClientDeaths(client) == 0 && CS_GetClientAssists(client) == 0)
		{
			PrintToChat(client, "%t", "AlreadyReset", sMoveTag);
		}
		else
		{
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
			SetEntProp(client, Prop_Data, "m_iDeaths", 0);
			CS_SetClientAssists(client, 0);
			CPrintToChatAll("%t", "ResetScore", sMoveTag, client);
		}
	}
}

NoPlayer(param1)
{
	DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
	CPrintToChat(param1, "%t", "AdminMenuNoPlayer", sMoveTag);
}

public Action:Timer_ChangeClientTeam(Handle:timer, any:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new team = ReadPackCell(pack);
	CloseHandle(pack);
	ChangeClientTeam(client, team);
}

CheckBalance()
{
	new diff = TCount - CTCount;
	if ( diff < 0 ) diff = -diff;
	Balance = diff <= 1;
}

ChangeTeamCount(team, diff)
{
	if(team == CS_TEAM_T)
	{
		TCount += diff;
	}
	else if(team == CS_TEAM_CT)
	{
		CTCount += diff;
	}
}

public bool:IsClientAdmin(client, Handle:hFlag)
{
	if (IsClientValid(client))
	{
		new AdminId:adminid = GetUserAdmin(client);
		new AdminFlag:flag;
		decl String:sAdminFlag[3];
		GetConVarString(hFlag, sAdminFlag, sizeof(sAdminFlag));
		FindFlagByChar(sAdminFlag[0], flag);
		if (GetAdminFlag(adminid, flag))
		{
			return true;
		}
		return false;
	}
	return false;
}

public bool:IsClientValid(client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}

DropBomb(client)
{
	if(GetConVarInt(hBombDrop))
	{
		if(GetPlayerWeaponSlot(client, CS_SLOT_C4) != -1)
		{
			CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_C4), true, true);
		}
	}
}