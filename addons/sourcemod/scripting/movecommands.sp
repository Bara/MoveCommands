#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <updater>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS

#define MOVECOMMANDS_NAME "Move Commands ( ResetScore, Switch, Spec )"
#define MOVECOMMANDS_VERSION "1.3.4"

#define UPDATE_URL    "https://bara.in/update/movecommands.txt"

new Handle:hAdminMenu;

new Handle:hEnableAdminMenu = INVALID_HANDLE;
new Handle:hEnableAFK = INVALID_HANDLE;
new Handle:hEnableSpec = INVALID_HANDLE;
new Handle:hEnableSwap = INVALID_HANDLE;
new Handle:hEnableSwapCT = INVALID_HANDLE;
new Handle:hEnableSwapT = INVALID_HANDLE;
new Handle:hEnableFSwap = INVALID_HANDLE;
new Handle:hEnableSwapRoundEnd = INVALID_HANDLE;
new Handle:hEnableSwapDeath = INVALID_HANDLE;
new Handle:hEnableResetScore = INVALID_HANDLE;
new Handle:hEnableTeamBalance = INVALID_HANDLE;
new Handle:hEnableExchangeTeams = INVALID_HANDLE;
new Handle:hEnableSwapAllCT = INVALID_HANDLE;
new Handle:hEnableSwapAllT = INVALID_HANDLE;
new Handle:hEnableSwapAllSpec  = INVALID_HANDLE;

new Handle:hBombDrop = INVALID_HANDLE;
new Handle:hDefuserDrop = INVALID_HANDLE;


new bool:SwapRoundEnd[MAXPLAYERS+1] = false;
new bool:SwapPlayerDeath[MAXPLAYERS+1] = false;

new String:sMoveTag[64];

new TCount;
new CTCount;
new bool:Balance;

public Plugin:myinfo = 
{
	name = MOVECOMMANDS_NAME,
	author = "Bara",
	description = "Plugin to switch player and reset score",
	version = MOVECOMMANDS_VERSION,
	url = "www.bara.in"
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("movecommands.phrases");
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	if(GetEngineVersion() != Engine_CSS && GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Unsupported Game! Only CS:S and CS:GO");
	}
	
	Format(sMoveTag, sizeof(sMoveTag), "%T", "MessageTag", LANG_SERVER);
	
	CreateConVar("movecommands_version", MOVECOMMANDS_VERSION, MOVECOMMANDS_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	AutoExecConfig_SetFile("plugin.movecommands", "sourcemod");
	AutoExecConfig_SetCreateFile(true);
	
	// Enable/Disable Commands
	hEnableAdminMenu = AutoExecConfig_CreateConVar("movecommands_enable_adminmenu", "1", "Enable / Disable MoveCommands in Adminmenu", _, true, 0.0, true, 1.0);
	hEnableAFK = AutoExecConfig_CreateConVar("movecommands_enable_afk", "1", "Enable / Disable AFK Command", _, true, 0.0, true, 1.0);
	hEnableSpec = AutoExecConfig_CreateConVar("movecommands_enable_spec", "1", "Enable / Disable Spec Command", _, true, 0.0, true, 1.0);
	hEnableSwap = AutoExecConfig_CreateConVar("movecommands_enable_swap", "1", "Enable / Disable Swap Command", _, true, 0.0, true, 1.0);
	hEnableSwapCT = AutoExecConfig_CreateConVar("movecommands_enable_swap_ct", "1", "Enable / Disable Swap CT Command", _, true, 0.0, true, 1.0);
	hEnableSwapT = AutoExecConfig_CreateConVar("movecommands_enable_swap_t", "1", "Enable / Disable Swap T Command", _, true, 0.0, true, 1.0);
	hEnableFSwap = AutoExecConfig_CreateConVar("movecommands_enable_fswap", "1", "Enable / Disable Force Swap Command", _, true, 0.0, true, 1.0);
	hEnableSwapRoundEnd = AutoExecConfig_CreateConVar("movecommands_enable_swaproundend", "1", "Enable / Disable Swap Round End Command", _, true, 0.0, true, 1.0);
	hEnableSwapDeath = AutoExecConfig_CreateConVar("movecommands_enable_swapdeath", "1", "Enable / Disable Swap Player Death Command", _, true, 0.0, true, 1.0);
	hEnableExchangeTeams = AutoExecConfig_CreateConVar("movecommands_enable_exchangeteams", "1", "Enable / Disable Exchange Teams Command", _, true, 0.0, true, 1.0);
	hEnableSwapAllCT = AutoExecConfig_CreateConVar("movecommands_enable_swapallct", "1", "Enable / Disable Swap All Players To CT Command", _, true, 0.0, true, 1.0);
	hEnableSwapAllT = AutoExecConfig_CreateConVar("movecommands_enable_swapallt", "1", "Enable / Disable Swap All Players To T Command", _, true, 0.0, true, 1.0);
	hEnableSwapAllSpec = AutoExecConfig_CreateConVar("movecommands_enable_swapallspec", "1", "Enable / Disable Swap All Players To Spec Command", _, true, 0.0, true, 1.0);

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
	RegAdminCmd("sm_exchange", Command_ExchangeTeam, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swapallct", Command_SwapAllCT, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swapallt", Command_SwapAllT, ADMFLAG_GENERIC);
	RegAdminCmd("sm_swapallspec", Command_SwapAllSpec, ADMFLAG_GENERIC);

	RegConsoleCmd("sm_afk", Command_AFK);
	
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("round_end", Event_RoundEnd);
}

public OnAllPluginsLoaded()
{
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
				
				CreateTimer(0.1, Timer_SwitchPlayerDeathT, client);
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				SwapPlayerDeath[client] = false;
				
				if(GetConVarInt(hEnableResetScore))
				{
					ResetScore(client);
				}
				
				CreateTimer(0.1, Timer_SwitchPlayerDeathCT, client);
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

public Action:Timer_SwitchPlayerDeathCT(Handle:timer, any:client)
{
	CS_SwitchTeam(client, CS_TEAM_CT);
	CPrintToChatAll("%t", "MovedCTwithoutAdmin", sMoveTag, client);
}

public Action:Timer_SwitchPlayerDeathT(Handle:timer, any:client)
{
	CS_SwitchTeam(client, CS_TEAM_T);
	CPrintToChatAll("%t", "MovedTwithoutAdmin", sMoveTag, client);
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
		return;
	}
	
	if(SwapRoundEnd[client])
	{
		return;
	}
	
	if(SwapPlayerDeath[client])
	{
		return;
	}
	
	if(GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		CPrintToChatAll("%t", "AFK", sMoveTag, client);
	}
}

public Action:Command_Spec(client, args)
{
	if(!GetConVarInt(hEnableSpec))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_spec <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
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
}

public Action:Command_Swap(client, args)
{
	if(!GetConVarInt(hEnableSwap))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swap <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}

	if(GetClientTeam(target) < 2)
	{
		return;
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
}

public Action:Command_SwapCT(client, args)
{
	if(!GetConVarInt(hEnableSwapCT))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapct <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}

	if(GetClientTeam(target) < 2)
	{
		return;
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
}

public Action:Command_SwapT(client, args)
{
	if(!GetConVarInt(hEnableSwapT))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapt <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}

	if(GetClientTeam(target) < 2)
	{
		return;
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
}

public Action:Command_SwapRoundEnd(client, args)
{
	if(!GetConVarInt(hEnableSwapRoundEnd))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swaproundend <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}

	if(GetClientTeam(target) < 2)
	{
		return;
	}
	
	if(SwapRoundEnd[target])
	{
		CPrintToChat(client, "%t", "SwapRoundEndAlready", sMoveTag, target);
		return;
	}
	
	if(SwapPlayerDeath[target])
	{
		CPrintToChat(client, "%t", "SwapPlayerDeathAlready", sMoveTag, target);
		return;
	}

	SwitchRoundEndPlayerOtherTeam(client, target);
}

public Action:Command_SwapPlayerDeath(client, args)
{
	if(!GetConVarInt(hEnableSwapDeath))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapdeath <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}

	if(GetClientTeam(target) < 2)
	{
		return;
	}
	
	if(SwapRoundEnd[target])
	{
		CPrintToChat(client, "%t", "SwapRoundEndAlready", sMoveTag, target);
		return;
	}
	
	if(SwapPlayerDeath[target])
	{
		CPrintToChat(client, "%t", "SwapPlayerDeathAlready", sMoveTag, target);
		return;
	}

	SwitchPlayerDeathPlayerOtherTeam(client, target);
}

public Action:Command_FSwap(client, args)
{
	if(!GetConVarInt(hEnableFSwap))
	{
		return;
	}
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_fswap <#UserID|Name>");
		return;
	}
	
	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	new target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}

	if(GetClientTeam(target) < 2)
	{
		return;
	}

	FSwitchPlayerOtherTeam(client, target);
}

public Action:Command_ExchangeTeam(client, args)
{
	if(!GetConVarInt(hEnableExchangeTeams))
	{
		return;
	}
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_exchange");
		return;
	}
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			ExchangeTeam(client, i);
		}
	}
}

public Action:Command_SwapAllCT(client, args)
{
	if(!GetConVarInt(hEnableSwapAllCT))
	{
		return;
	}
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_swapallct");
		return;
	}
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				SwapAllPlayer(client, i, CS_TEAM_CT);
			}
		}
	}
}

public Action:Command_SwapAllT(client, args)
{
	if(!GetConVarInt(hEnableSwapAllT))
	{
		return;
	}
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_swapallt");
		return;
	}
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT)
			{
				SwapAllPlayer(client, i, CS_TEAM_T);
			}
		}
	}
}

public Action:Command_SwapAllSpec(client, args)
{
	if(!GetConVarInt(hEnableSwapAllSpec))
	{
		return;
	}
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_swapallspec");
		return;
	}
	
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT || GetClientTeam(i) == CS_TEAM_T)
			{
				SwapAllPlayer(client, i, CS_TEAM_SPECTATOR);
			}
		}
	}
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
	if(topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;
	CreateTimer(1.0, Timer_AttachAdminMenu);
}

public Action:Timer_AttachAdminMenu(Handle:timer)
{
	if(!GetConVarInt(hEnableAdminMenu))
	{
		return;
	}

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
	if(GetConVarInt(hEnableExchangeTeams))
	{
		AddToTopMenu(hAdminMenu, "sm_exchange", TopMenuObject_Item, AdminMenu_ExchangeTeam, menu_category, "sm_exchange", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapAllCT))
	{
		AddToTopMenu(hAdminMenu, "sm_swapallct", TopMenuObject_Item, AdminMenu_SwapAllCT, menu_category, "sm_swapallct", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapAllT))
	{
		AddToTopMenu(hAdminMenu, "sm_swapallt", TopMenuObject_Item, AdminMenu_SwapAllT, menu_category, "sm_swapallt", ADMFLAG_GENERIC);
	}
	if(GetConVarInt(hEnableSwapAllSpec))
	{
		AddToTopMenu(hAdminMenu, "sm_swapallspec", TopMenuObject_Item, AdminMenu_SwapAllSpec, menu_category, "sm_swapallspec", ADMFLAG_GENERIC);
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

public AdminMenu_ExchangeTeam(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleExchange", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		for(new i = 1; i < MaxClients; i++)
		{
			ExchangeTeam(param, i);
		}
	}
}

public AdminMenu_SwapAllCT(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleAllCT", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		for(new i = 1; i < MaxClients; i++)
		{
			if(IsClientValid(i) && IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T)
			{
				SwapAllPlayer(param, i, CS_TEAM_CT);
			}
		}
	}
}

public AdminMenu_SwapAllT(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleAllT", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		for(new i = 1; i < MaxClients; i++)
		{
			if(IsClientValid(i) && IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT)
			{
				SwapAllPlayer(param, i, CS_TEAM_T);
			}
		}
	}
}

public AdminMenu_SwapAllSpec(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "AdminMenuTitleAllSpec", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		for(new i = 1; i < MaxClients; i++)
		{
			if(IsClientValid(i))
			{
				if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT)
				{
					SwapAllPlayer(param, i, CS_TEAM_SPECTATOR);
				}
			}
		}
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

stock SwitchPlayerOtherTeam(client, target)
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
}

stock SwitchPlayerCTTeam(client, target)
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
}

stock SwitchPlayerTTeam(client, target)
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
}

stock SwitchRoundEndPlayerOtherTeam(client, target)
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
}

stock SwitchPlayerDeathPlayerOtherTeam(client, target)
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
}

stock FSwitchPlayerOtherTeam(client, target)
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
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		
		CPrintToChatAll("%t", "MovedCT", sMoveTag, client, target);
	}
}

stock SwapAllPlayer(client, target, team)
{
	if(!IsClientValid(client) || !IsClientValid(target))
	{
		return;
	}
	
	SwapPlayerDeath[target] = false;
	SwapRoundEnd[target] = false;
	
	if(GetConVarInt(hEnableResetScore))
	{
		ResetScore(target);
	}

	if(team == 1) // Spectator
	{
		ChangeClientTeam(target, CS_TEAM_SPECTATOR);

		SetEntPropEnt(target, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(target, Prop_Send, "m_iObserverMode", 4);

		CPrintToChat(target, "%T", "MoveAllSpec", target, sMoveTag, client);
	}
	else if(team == 2) // Terrorist
	{
		DropBomb(target);
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, team);
			if(GetConVarInt(hDefuserDrop))
			{
				GivePlayerItem(target, "item_defuser");
			}
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
		{
			CS_SwitchTeam(target, team);
		}
		CS_UpdateClientModel(target);
		CPrintToChat(target, "%T", "MoveAllT", target, sMoveTag, client);
	}
	else if(team == 3) // Counter-Terrorist
	{
		DropBomb(target);
		CS_SwitchTeam(target, team);
		CS_UpdateClientModel(target);
		CPrintToChat(target, "%T", "MoveAllCT", target, sMoveTag, client);
	}
}

stock ExchangeTeam(client, target)
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
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
	}
	CPrintToChat(target, "%T", "ExchangeTeams", target, sMoveTag, client);
}

stock SwitchPlayerSpecTeam(client, target)
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
}

stock CheckClients(client, target)
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

stock AddPlayerList(Handle:hMenu)
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

stock AddPlayerListCT(Handle:hMenu)
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

stock AddPlayerListT(Handle:hMenu)
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

stock ResetScore(client)
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

stock NoPlayer(param1)
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

stock CheckBalance()
{
	new diff = TCount - CTCount;
	if ( diff < 0 ) diff = -diff;
	Balance = diff <= 1;
}

stock ChangeTeamCount(team, diff)
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

stock bool:IsClientValid(client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	return false;
}

stock DropBomb(client)
{
	if(GetConVarInt(hBombDrop))
	{
		if(IsPlayerAlive(client) && GetPlayerWeaponSlot(client, CS_SLOT_C4) != -1)
		{
			CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_C4), true, true);
		}
	}
}