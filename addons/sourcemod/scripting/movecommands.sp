#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS

#define MOVECOMMANDS_NAME "Move Commands ( ResetScore, Switch, Spec )"
#define MOVECOMMANDS_VERSION "2.0.1"

Handle hAdminMenu;

ConVar cEnableAdminMenu = null;
ConVar cEnableAFK = null;
ConVar cEnableSpec = null;
ConVar cEnableSwap = null;
ConVar cEnableSwapCT = null;
ConVar cEnableSwapT = null;
ConVar cEnableFSwap = null;
ConVar cEnableSwapRoundEnd = null;
ConVar cEnableSwapDeath = null;
ConVar cEnableResetScore = null;
ConVar cEnableTeamBalance = null;
ConVar cEnableExchangeTeams = null;
ConVar cEnableSwapAllCT = null;
ConVar cEnableSwapAllT = null;
ConVar cEnableSwapAllSpec  = null;

ConVar cBombDrop = null;
ConVar cDefuserDrop = null;


bool g_bSwapRoundEnd[MAXPLAYERS + 1] =  { false, ... };
bool g_bSwapPlayerDeath[MAXPLAYERS + 1] =  { false, ... };

char g_sTag[64];

int g_iTCount;
int g_iCTCount;
bool g_bBalance;

public Plugin myinfo = 
{
	name = MOVECOMMANDS_NAME,
	author = "Bara",
	description = "Plugin to switch player and reset score",
	version = MOVECOMMANDS_VERSION,
	url = "www.bara.in"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("movecommands.phrases");
	
	if(GetEngineVersion() != Engine_CSS && GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Unsupported Game! Only CS:S and CS:GO");
	}
	
	Format(g_sTag, sizeof(g_sTag), "%T", "MessageTag", LANG_SERVER);
	
	CreateConVar("movecommands_version", MOVECOMMANDS_VERSION, MOVECOMMANDS_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Enable/Disable Commands
	cEnableAdminMenu = CreateConVar("movecommands_enable_adminmenu", "1", "Enable / Disable MoveCommands in Adminmenu", _, true, 0.0, true, 1.0);
	cEnableAFK = CreateConVar("movecommands_enable_afk", "1", "Enable / Disable AFK Command", _, true, 0.0, true, 1.0);
	cEnableSpec = CreateConVar("movecommands_enable_spec", "1", "Enable / Disable Spec Command", _, true, 0.0, true, 1.0);
	cEnableSwap = CreateConVar("movecommands_enable_swap", "1", "Enable / Disable Swap Command", _, true, 0.0, true, 1.0);
	cEnableSwapCT = CreateConVar("movecommands_enable_swap_ct", "1", "Enable / Disable Swap CT Command", _, true, 0.0, true, 1.0);
	cEnableSwapT = CreateConVar("movecommands_enable_swap_t", "1", "Enable / Disable Swap T Command", _, true, 0.0, true, 1.0);
	cEnableFSwap = CreateConVar("movecommands_enable_fswap", "1", "Enable / Disable Force Swap Command", _, true, 0.0, true, 1.0);
	cEnableSwapRoundEnd = CreateConVar("movecommands_enable_swaproundend", "1", "Enable / Disable Swap Round End Command", _, true, 0.0, true, 1.0);
	cEnableSwapDeath = CreateConVar("movecommands_enable_swapdeath", "1", "Enable / Disable Swap Player Death Command", _, true, 0.0, true, 1.0);
	cEnableExchangeTeams = CreateConVar("movecommands_enable_exchangeteams", "1", "Enable / Disable Exchange Teams Command", _, true, 0.0, true, 1.0);
	cEnableSwapAllCT = CreateConVar("movecommands_enable_swapallct", "1", "Enable / Disable Swap All Players To CT Command", _, true, 0.0, true, 1.0);
	cEnableSwapAllT = CreateConVar("movecommands_enable_swapallt", "1", "Enable / Disable Swap All Players To T Command", _, true, 0.0, true, 1.0);
	cEnableSwapAllSpec = CreateConVar("movecommands_enable_swapallspec", "1", "Enable / Disable Swap All Players To Spec Command", _, true, 0.0, true, 1.0);

	// Enable/Disable Drops
	cBombDrop = CreateConVar("movecommands_enable_drop_bomb", "1", "Enable / Disable Bomb Drop",_, true, 0.0, true, 1.0);
	cDefuserDrop = CreateConVar("movecommands_enable_drop_defuser", "1", "Enable / Disable Defuser Drop",_, true, 0.0, true, 1.0);
	
	// Enable/Disable Reset Score
	cEnableResetScore = CreateConVar("movecommands_enable_resetscore", "0", "Enable / Disable ResetScore after Swap/Spec Player",_, true, 0.0, true, 1.0);

	// Enable/Disable Team Balancer
	cEnableTeamBalance = CreateConVar("movecommands_enable_teamabalancer", "0", "Enable / Disable Team Balancer",_, true, 0.0, true, 1.0);
	
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

public void OnAllPluginsLoaded()
{
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}

public void OnMapStart()
{
	if(cEnableTeamBalance.BoolValue)
	{
		g_iTCount = 0;
		g_iCTCount = 0;
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsClientValid(i))
				ChangeTeamCount(GetClientTeam(i), 1);
		}
		CheckBalance();
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int killer = GetClientOfUserId(event.GetInt("killer"));
	
	if(IsClientValid(client))
	{
		if(g_bSwapPlayerDeath[client])
		{
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				g_bSwapPlayerDeath[client] = false;
				
				if(cEnableResetScore.BoolValue)
					ResetScore(client);
				
				CreateTimer(0.1, Timer_SwitchPlayerDeathT, GetClientUserId(client));
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				g_bSwapPlayerDeath[client] = false;
				
				if(cEnableResetScore.BoolValue)
					ResetScore(client);
				
				CreateTimer(0.1, Timer_SwitchPlayerDeathCT, GetClientUserId(client));
			}
		}

		if(IsClientValid(killer))
		{
			if(!cEnableTeamBalance.BoolValue)
				return;

			if(g_bBalance)
				return;

			if(client == killer || IsFakeClient(client))
				return;

			int team = GetClientTeam(client);

			if ( team != CS_TEAM_T && team != CS_TEAM_CT )
				return;

			if ( team != ( (g_iTCount > g_iCTCount) ? CS_TEAM_T : CS_TEAM_CT ) )
				return;

			team = team == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T;

			Handle pack = CreateDataPack();
			WritePackCell(pack, GetClientUserId(client));
			WritePackCell(pack, team);
			CreateTimer(0.1, Timer_ChangeClientTeam, pack);
		}
	}
}

public Action Timer_SwitchPlayerDeathCT(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(IsClientValid(client))
	{
		CS_SwitchTeam(client, CS_TEAM_CT);
		CPrintToChatAll("%t", "MovedCTwithoutAdmin", g_sTag, client);
	}
}

public Action Timer_SwitchPlayerDeathT(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(IsClientValid(client))
	{
		CS_SwitchTeam(client, CS_TEAM_T);
		CPrintToChatAll("%t", "MovedTwithoutAdmin", g_sTag, client);
	}
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int oldTeam = event.GetInt("oldteam");
	int newTeam = event.GetInt("team");
	bool disconnect = event.GetBool("disconnect");

	if(cEnableTeamBalance.BoolValue)
	{
		ChangeTeamCount(oldTeam, -1);

		if(!disconnect)
			ChangeTeamCount(newTeam, 1);

		CheckBalance();
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(g_bSwapRoundEnd[i])
			{
				if(GetClientTeam(i) == CS_TEAM_CT)
				{
					g_bSwapRoundEnd[i] = false;
					
					if(cEnableResetScore.BoolValue)
						ResetScore(i);
					
					CS_SwitchTeam(i, CS_TEAM_T);
					CPrintToChatAll("%t", "MovedTwithoutAdmin", g_sTag, i);
				}
				else if(GetClientTeam(i) == CS_TEAM_T)
				{
					g_bSwapRoundEnd[i] = false;
					
					if(cEnableResetScore.BoolValue)
						ResetScore(i);
					
					CS_SwitchTeam(i, CS_TEAM_CT);
					CPrintToChatAll("%t", "MovedCTwithoutAdmin", g_sTag, i);
				}
			}
		}
	}
}

public Action Command_AFK(int client, int args)
{
	if(!cEnableAFK.BoolValue)
		return;
	
	if(g_bSwapRoundEnd[client])
		return;
	
	if(g_bSwapPlayerDeath[client])
		return;
	
	if(GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		CPrintToChatAll("%t", "AFK", g_sTag, client);
	}
}

public Action Command_Spec(int client, int args)
{
	if(!cEnableSpec.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_spec <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return;
	}

	if(!IsClientValid(target))
	{
		return;
	}
	
	if(g_bSwapRoundEnd[target])
	{
		g_bSwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", g_sTag, target);
		SwitchPlayerSpecTeam(client, target);
	}
	
	if(g_bSwapPlayerDeath[target])
	{
		g_bSwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
		SwitchPlayerSpecTeam(client, target);
	}

	SwitchPlayerSpecTeam(client, target);
}

public Action Command_Swap(int client, int args)
{
	if(!cEnableSwap.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swap <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
		return;

	if(!IsClientValid(target))
		return;

	if(GetClientTeam(target) < 2)
		return;
	
	if(g_bSwapRoundEnd[target])
	{
		g_bSwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", g_sTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	if(g_bSwapPlayerDeath[target])
	{
		g_bSwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	SwitchPlayerOtherTeam(client, target);
}

public Action Command_SwapCT(int client, int args)
{
	if(!cEnableSwapCT.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapct <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
		return;

	if(!IsClientValid(target))
		return;

	if(GetClientTeam(target) < 2)
		return;
	
	if(g_bSwapRoundEnd[target])
	{
		g_bSwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", g_sTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	if(g_bSwapPlayerDeath[target])
	{
		g_bSwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	SwitchPlayerCTTeam(client, target);
}

public Action Command_SwapT(int client, int args)
{
	if(!cEnableSwapT.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapt <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
		return;

	if(!IsClientValid(target))
		return;

	if(GetClientTeam(target) < 2)
		return;
	
	if(g_bSwapRoundEnd[target])
	{
		g_bSwapRoundEnd[target] = false;
		CPrintToChat(client, "%t", "SwapRoundEndNoLonger", g_sTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	if(g_bSwapPlayerDeath[target])
	{
		g_bSwapPlayerDeath[target] = false;
		CPrintToChat(client, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
		SwitchPlayerOtherTeam(client, target);
	}
	
	SwitchPlayerTTeam(client, target);
}

public Action Command_SwapRoundEnd(int client, int args)
{
	if(!cEnableSwapRoundEnd.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swaproundend <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
		return;

	if(!IsClientValid(target))
		return;

	if(GetClientTeam(target) < 2)
		return;
	
	if(g_bSwapRoundEnd[target])
	{
		CPrintToChat(client, "%t", "SwapRoundEndAlready", g_sTag, target);
		return;
	}
	
	if(g_bSwapPlayerDeath[target])
	{
		CPrintToChat(client, "%t", "SwapPlayerDeathAlready", g_sTag, target);
		return;
	}

	SwitchRoundEndPlayerOtherTeam(client, target);
}

public Action Command_SwapPlayerDeath(int client, int args)
{
	if(!cEnableSwapDeath.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_swapdeath <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
		return;

	if(!IsClientValid(target))
		return;

	if(GetClientTeam(target) < 2)
		return;
	
	if(g_bSwapRoundEnd[target])
	{
		CPrintToChat(client, "%t", "SwapRoundEndAlready", g_sTag, target);
		return;
	}
	
	if(g_bSwapPlayerDeath[target])
	{
		CPrintToChat(client, "%t", "SwapPlayerDeathAlready", g_sTag, target);
		return;
	}

	SwitchPlayerDeathPlayerOtherTeam(client, target);
}

public Action Command_FSwap(int client, int args)
{
	if(!cEnableFSwap.BoolValue)
		return;
	
	if (args < 1)
	{
		ReplyToCommand(client, "sm_fswap <#UserID|Name>");
		return;
	}
	
	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
		return;

	if(!IsClientValid(target))
		return;

	if(GetClientTeam(target) < 2)
		return;

	FSwitchPlayerOtherTeam(client, target);
}

public Action Command_ExchangeTeam(int client, int args)
{
	if(!cEnableExchangeTeams.BoolValue)
		return;
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_exchange");
		return;
	}
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
			ExchangeTeam(client, i);
	}
}

public Action Command_SwapAllCT(int client, int args)
{
	if(!cEnableSwapAllCT.BoolValue)
		return;
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_swapallct");
		return;
	}
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_T)
				SwapAllPlayer(client, i, CS_TEAM_CT);
		}
	}
}

public Action Command_SwapAllT(int client, int args)
{
	if(!cEnableSwapAllT.BoolValue)
		return;
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_swapallt");
		return;
	}
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT)
				SwapAllPlayer(client, i, CS_TEAM_T);
		}
	}
}

public Action Command_SwapAllSpec(int client, int args)
{
	if(!cEnableSwapAllSpec.BoolValue)
		return;
	
	if (args > 0)
	{
		ReplyToCommand(client, "sm_swapallspec");
		return;
	}
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) == CS_TEAM_CT || GetClientTeam(i) == CS_TEAM_T)
				SwapAllPlayer(client, i, CS_TEAM_SPECTATOR);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		hAdminMenu = null;
}
 
public void OnAdminMenuReady(Handle topmenu)
{
	if(topmenu == hAdminMenu)
		return;
	
	hAdminMenu = topmenu;
	CreateTimer(1.0, Timer_AttachAdminMenu);
}

public Action Timer_AttachAdminMenu(Handle timer)
{
	if(!cEnableAdminMenu.BoolValue)
		return;

	TopMenuObject menu_category = AddToTopMenu(hAdminMenu, "movecommands", TopMenuObject_Category, Handle_Category, INVALID_TOPMENUOBJECT, "movecommands", ADMFLAG_GENERIC);
	if( menu_category == INVALID_TOPMENUOBJECT )
		return;
	
	if(cEnableSwap.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swap", TopMenuObject_Item, AdminMenu_SwapPlayer, menu_category, "sm_swap", ADMFLAG_GENERIC);
	
	if(cEnableSwapCT.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swapct", TopMenuObject_Item, AdminMenu_SwapCTPlayer, menu_category, "sm_swapct", ADMFLAG_GENERIC);
	
	if(cEnableSwapT.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swapt", TopMenuObject_Item, AdminMenu_SwapTPlayer, menu_category, "sm_swapt", ADMFLAG_GENERIC);
	
	if(cEnableFSwap.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_fswap", TopMenuObject_Item, AdminMenu_FSwapPlayer, menu_category, "sm_fswap", ADMFLAG_GENERIC);
	
	if(cEnableSwapRoundEnd.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swaproundend", TopMenuObject_Item, AdminMenu_SwapRoundEndPlayer, menu_category, "sm_swaproundend", ADMFLAG_GENERIC);
	
	if(cEnableSwapDeath.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swapdeath", TopMenuObject_Item, AdminMenu_SwapDeathPlayer, menu_category, "sm_swapdeath", ADMFLAG_GENERIC);
	
	if(cEnableSpec.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_spec", TopMenuObject_Item, AdminMenu_SpecPlayer, menu_category, "sm_spec", ADMFLAG_GENERIC);
	
	if(cEnableExchangeTeams.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_exchange", TopMenuObject_Item, AdminMenu_ExchangeTeam, menu_category, "sm_exchange", ADMFLAG_GENERIC);
	
	if(cEnableSwapAllCT.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swapallct", TopMenuObject_Item, AdminMenu_SwapAllCT, menu_category, "sm_swapallct", ADMFLAG_GENERIC);
	
	if(cEnableSwapAllT.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swapallt", TopMenuObject_Item, AdminMenu_SwapAllT, menu_category, "sm_swapallt", ADMFLAG_GENERIC);
	
	if(cEnableSwapAllSpec.BoolValue)
		AddToTopMenu(hAdminMenu, "sm_swapallspec", TopMenuObject_Item, AdminMenu_SwapAllSpec, menu_category, "sm_swapallspec", ADMFLAG_GENERIC);
}

public void Handle_Category(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if(action == TopMenuAction_DisplayTitle)
		Format(buffer, maxlength, "%T", "AdminMenuTitle", param);
	else if(action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitle", param);
}

public void AdminMenu_SwapPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwap", param);
	else if (action == TopMenuAction_SelectOption)
		SwapDisplayInfoMenu(param);
}

public void AdminMenu_SwapCTPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapCT", param);
	else if (action == TopMenuAction_SelectOption)
		SwapCTDisplayInfoMenu(param);
}

public void AdminMenu_SwapTPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapT", param);
	else if (action == TopMenuAction_SelectOption)
		SwapTDisplayInfoMenu(param);
}

public void AdminMenu_FSwapPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleFSwap", param);
	else if (action == TopMenuAction_SelectOption)
		FSwapDisplayInfoMenu(param);
}

public void AdminMenu_SwapRoundEndPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapRE", param);
	else if (action == TopMenuAction_SelectOption)
		SwapRoundEndDisplayInfoMenu(param);
}

public void AdminMenu_SwapDeathPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleSwapPD", param);
	else if (action == TopMenuAction_SelectOption)
		SwapPlayerDeathDisplayInfoMenu(param);
}

public void AdminMenu_SpecPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleSpec", param);
	else if (action == TopMenuAction_SelectOption)
		SpecDisplayInfoMenu(param);
}

public void AdminMenu_ExchangeTeam(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleExchange", param);
	else if (action == TopMenuAction_SelectOption)
	{
		for(int i = 1; i < MaxClients; i++)
			ExchangeTeam(param, i);
	}
}

public void AdminMenu_SwapAllCT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleAllCT", param);
	else if (action == TopMenuAction_SelectOption)
	{
		for(int i = 1; i < MaxClients; i++)
		{
			if(IsClientValid(i) && IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T)
				SwapAllPlayer(param, i, CS_TEAM_CT);
		}
	}
}

public void AdminMenu_SwapAllT(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleAllT", param);
	else if (action == TopMenuAction_SelectOption)
	{
		for(int i = 1; i < MaxClients; i++)
		{
			if(IsClientValid(i) && IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT)
				SwapAllPlayer(param, i, CS_TEAM_T);
		}
	}
}

public void AdminMenu_SwapAllSpec(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "%T", "AdminMenuTitleAllSpec", param);
	else if (action == TopMenuAction_SelectOption)
	{
		for(int i = 1; i < MaxClients; i++)
		{
			if(IsClientValid(i))
			{
				if(IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT)
					SwapAllPlayer(param, i, CS_TEAM_SPECTATOR);
			}
		}
	}
}

void SwapDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_SwapPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

void SwapCTDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_SwapCTPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerListCT(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

void SwapTDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_SwapTPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerListT(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

void SwapRoundEndDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_SwapRoundEndPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

void SwapPlayerDeathDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_SwapPlayerDeathPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

void FSwapDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_FSwapPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

void SpecDisplayInfoMenu(int client)
{
	Handle hMenu = CreateMenu(MenuHandler_SpecPlayer);
	SetMenuTitle(hMenu, "%T", "AdminMenuTitlePlayerChoose", client);
	SetMenuExitBackButton(hMenu, true);
	AddPlayerList(hMenu);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

/*void NoPlayersDisplayInfoMenu(int client)
{
	char NoPlayer[64];
	Format(NoPlayer, sizeof(NoPlayer), "%t", "AdminMenuNoPlayer");
	
	Handle hMenu = CreateMenu(MenuHandler_NoPlayer);
	SetMenuTitle(hMenu, "%t", "AdminMenuTitleNoPlayer");
	SetMenuExitBackButton(hMenu, true);
	AddMenuItem(hMenu, "", NoPlayer);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_NoPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
			DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
	}
}*/

public int MenuHandler_SwapPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			SwitchPlayerOtherTeam(param1, target);
			SwapDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
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

public int MenuHandler_SwapCTPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			SwitchPlayerCTTeam(param1, target);
			SwapCTDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
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

public int MenuHandler_SwapTPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			SwitchPlayerTTeam(param1, target);
			SwapTDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
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

public int MenuHandler_SwapRoundEndPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			SwapRoundEndDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
			SwapRoundEndDisplayInfoMenu(param1);
		}
		else
		{
			SwitchRoundEndPlayerOtherTeam(param1, target);
			SwapRoundEndDisplayInfoMenu(param1);
		}
	}
}

public int MenuHandler_SwapPlayerDeathPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			SwapPlayerDeathDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
			SwapPlayerDeathDisplayInfoMenu(param1);
		}
		else
		{
			SwitchPlayerDeathPlayerOtherTeam(param1, target);
			SwapPlayerDeathDisplayInfoMenu(param1);
		}
	}
}

public int MenuHandler_FSwapPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			FSwitchPlayerOtherTeam(param1, target);
			FSwapDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
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

public int MenuHandler_SpecPlayer(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
	else if (action == MenuAction_Cancel)
	{
		if(IsClientValid(param1))
		{
			if (param2 == MenuCancel_ExitBack && hAdminMenu != null)
				DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
			
			NoPlayer(param1);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		int userid = StringToInt(info);
		int target = target = GetClientOfUserId(userid);

		CheckClients(param1, target);
		
		if(g_bSwapRoundEnd[target])
		{
			g_bSwapRoundEnd[target] = false;
			CPrintToChat(param1, "%t", "SwapRoundEndNoLonger", g_sTag, target);
			SwitchPlayerSpecTeam(param1, target);
			SpecDisplayInfoMenu(param1);
		}
		else if(g_bSwapPlayerDeath[target])
		{
			g_bSwapPlayerDeath[target] = false;
			CPrintToChat(param1, "%t", "SwapPlayerDeathNoLonger", g_sTag, target);
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

void SwitchPlayerOtherTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (!CanTargetPlayer(client, target))
		return;
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);

			if(cDefuserDrop.BoolValue)
				GivePlayerItem(target, "item_defuser");

			ForcePlayerSuicide(target);
			LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
		{
			ChangeClientTeam(target, CS_TEAM_T);
			LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		}
		
		CPrintToChatAll("%t", "MovedT", g_sTag, client, target);
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		ChangeClientTeam(target, CS_TEAM_CT);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedCT", g_sTag, client, target);
	}
}

void SwitchPlayerCTTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (!CanTargetPlayer(client, target))
		return;
	
	if(GetClientTeam(target) != CS_TEAM_CT)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_CT);
			if(cDefuserDrop.BoolValue)
				GivePlayerItem(target, "item_defuser");
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
			CS_SwitchTeam(target, CS_TEAM_CT);
		
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedCT", g_sTag, client, target);
	}
	else
		CPrintToChat(client, "%t", "PlayerInvalid", g_sTag);
}

void SwitchPlayerTTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (!CanTargetPlayer(client, target))
		return;
	
	if(GetClientTeam(target) != CS_TEAM_T)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
				
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);
			
			if(cDefuserDrop.BoolValue)
				GivePlayerItem(target, "item_defuser");
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
			CS_SwitchTeam(target, CS_TEAM_T);
		
		LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		CS_UpdateClientModel(target);
		CPrintToChatAll("%t", "MovedT", g_sTag, client, target);
	}
	else
		CPrintToChat(client, "%t", "PlayerInvalid", g_sTag);
}

void SwitchRoundEndPlayerOtherTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (!CanTargetPlayer(client, target))
		return;
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		if(!IsPlayerAlive(target))
			SwitchPlayerOtherTeam(client, target);
		else
		{
			g_bSwapRoundEnd[target] = true;
			LogAction(client, target, "\"%L\" was moved to T by \"%L\" on Round End", target, client);
			CPrintToChatAll("%t", "MovedTRE", g_sTag, target, client);
		}
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		if(!IsPlayerAlive(target))
			SwitchPlayerOtherTeam(client, target);
		else
		{
			g_bSwapRoundEnd[target] = true;
			LogAction(client, target, "\"%L\" was moved to CT by \"%L\" on Round End", target, client);
			CPrintToChatAll("%t", "MovedCTRE", g_sTag, target, client);
		}
	}
}

void SwitchPlayerDeathPlayerOtherTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (!CanTargetPlayer(client, target))
		return;
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		if(!IsPlayerAlive(target))
			SwitchPlayerOtherTeam(client, target);
		else
		{
			g_bSwapPlayerDeath[target] = true;
			LogAction(client, target, "\"%L\" was moved to T by \"%L\" on Player Death", target, client);
			CPrintToChatAll("%t", "MovedTPD", g_sTag, target, client, target);
		}
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		if(!IsPlayerAlive(target))
			SwitchPlayerOtherTeam(client, target);
		else
		{
			g_bSwapPlayerDeath[target] = true;
			LogAction(client, target, "\"%L\" was moved to CT by \"%L\" on Player Death", target, client);
			CPrintToChatAll("%t", "MovedCTPD", g_sTag, target, client, target);
		}
	}
}

void FSwitchPlayerOtherTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (!CanTargetPlayer(client, target))
		return;
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);
			
			if(cDefuserDrop.BoolValue)
				GivePlayerItem(target, "item_defuser");
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
			CS_SwitchTeam(target, CS_TEAM_T);
		
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedT", g_sTag, client, target);
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		CS_SwitchTeam(target, CS_TEAM_CT);
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
		
		CPrintToChatAll("%t", "MovedCT", g_sTag, client, target);
	}
}

void SwapAllPlayer(int client, int target, int team)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	g_bSwapPlayerDeath[target] = false;
	g_bSwapRoundEnd[target] = false;
	
	if(cEnableResetScore.BoolValue)
		ResetScore(target);

	if (!CanTargetPlayer(client, target))
		return;
	
	if(team == 1) // Spectator
	{
		ChangeClientTeam(target, CS_TEAM_SPECTATOR);

		SetEntPropEnt(target, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(target, Prop_Send, "m_iObserverMode", 4);

		CPrintToChat(target, "%T", "MoveAllSpec", target, g_sTag, client);
	}
	else if(team == 2) // Terrorist
	{
		DropBomb(target);
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, team);
			
			if(cDefuserDrop.BoolValue)
				GivePlayerItem(target, "item_defuser");
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
			CS_SwitchTeam(target, team);
		
		CS_UpdateClientModel(target);
		CPrintToChat(target, "%T", "MoveAllT", target, g_sTag, client);
	}
	else if(team == 3) // Counter-Terrorist
	{
		DropBomb(target);
		CS_SwitchTeam(target, team);
		CS_UpdateClientModel(target);
		CPrintToChat(target, "%T", "MoveAllCT", target, g_sTag, client);
	}
}

void ExchangeTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if(GetClientTeam(target) == CS_TEAM_CT)
	{
		if (!CanTargetPlayer(client, target))
			return;
		
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		// Thanks Peace-Maker
		if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 1)
		{
			SetEntProp(target, Prop_Send, "m_bHasDefuser", 0);
			CS_SwitchTeam(target, CS_TEAM_T);
			
			if(cDefuserDrop.BoolValue)
				GivePlayerItem(target, "item_defuser");
		}
		else if(GetEntProp(target, Prop_Send, "m_bHasDefuser") == 0)
			CS_SwitchTeam(target, CS_TEAM_T);
		
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to T by \"%L\"", target, client);
	}
	else if(GetClientTeam(target) == CS_TEAM_T)
	{
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		DropBomb(target);
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		CS_SwitchTeam(target, CS_TEAM_CT);
		CS_UpdateClientModel(target);
		LogAction(client, target, "\"%L\" was moved to CT by \"%L\"", target, client);
	}
	CPrintToChat(target, "%T", "ExchangeTeams", target, g_sTag, client);
}

void SwitchPlayerSpecTeam(int client, int target)
{
	if(!IsClientValid(client) || !IsClientValid(target))
		return;
	
	if (GetClientTeam(target) != CS_TEAM_SPECTATOR)
	{
		if (!CanTargetPlayer(client, target))
			return;
		
		g_bSwapPlayerDeath[target] = false;
		g_bSwapRoundEnd[target] = false;
		
		if(cEnableResetScore.BoolValue)
			ResetScore(target);
		
		ChangeClientTeam(target, CS_TEAM_SPECTATOR);
		LogAction(client, target, "\"%L\" was moved to Spec by \"%L\"", target, client);
		CPrintToChatAll("%t", "MovedSpec", g_sTag, client, target);
	}
}

void CheckClients(int client, int target)
{
	if (target == 0)
		CPrintToChat(client, "%t", "PlayerNoLongerValid", g_sTag);
	else if (!CanUserTarget(client, target))
		CPrintToChat(client, "%t", "PlayerInvalid", g_sTag);
}

void AddPlayerList(Handle hMenu)
{
	char name[MAX_NAME_LENGTH];
	char listname[128];
	char target[32];
	char TeamName[5];
	char SwapTyp[32];
	int id;
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) < 2)
				continue;
			
			if(g_bSwapRoundEnd[i])
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypeRE");
			
			if(g_bSwapPlayerDeath[i])
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypePD");
			
			if(GetClientTeam(i) == CS_TEAM_CT)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamCTName");
			
			if(GetClientTeam(i) == CS_TEAM_T)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamTName");
			
			GetClientName(i, name, 31);
			id = GetClientUserId(i);
			IntToString(id, target, sizeof(target));
			
			if(g_bSwapRoundEnd[i] || g_bSwapPlayerDeath[i])
				Format(listname, sizeof(listname),"[%s] %s (%s) [%s]", SwapTyp, name, target, TeamName);
			
			if(!g_bSwapRoundEnd[i] && !g_bSwapPlayerDeath[i])
				Format(listname, sizeof(listname),"%s (%s) [%s]", name, target, TeamName);
			
			AddMenuItem(hMenu, target, listname);
		}
	}
}

void AddPlayerListCT(Handle hMenu)
{
	char name[MAX_NAME_LENGTH];
	char listname[128];
	char target[32];
	char TeamName[5];
	char SwapTyp[32];
	int id;
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) != CS_TEAM_T)
				continue;
			
			if(g_bSwapRoundEnd[i])
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypeRE");
			
			if(g_bSwapPlayerDeath[i])
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypePD");
			
			if(GetClientTeam(i) == CS_TEAM_CT)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamCTName");
			
			if(GetClientTeam(i) == CS_TEAM_T)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamTName");
			
			if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamSpecName");
			
			GetClientName(i, name, 31);
			id = GetClientUserId(i);
			IntToString(id, target, sizeof(target));
			
			if(g_bSwapRoundEnd[i] || g_bSwapPlayerDeath[i])
				Format(listname, sizeof(listname),"[%s] %s (%s) [%s]", SwapTyp, name, target, TeamName);
			
			if(!g_bSwapRoundEnd[i] && !g_bSwapPlayerDeath[i])
				Format(listname, sizeof(listname),"%s (%s) [%s]", name, target, TeamName);
			
			AddMenuItem(hMenu, target, listname);
		}
	}
}

void AddPlayerListT(Handle hMenu)
{
	char name[MAX_NAME_LENGTH];
	char listname[128];
	char target[32];
	char TeamName[12];
	char SwapTyp[32];
	int id;
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			if(GetClientTeam(i) != CS_TEAM_CT)
				continue;
			
			if(g_bSwapRoundEnd[i])
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypeRE");
			
			if(g_bSwapPlayerDeath[i])
				Format(SwapTyp, sizeof(SwapTyp), "%t", "AdminMenuMoveTypePD");
			
			if(GetClientTeam(i) == CS_TEAM_CT)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamCTName");
			
			if(GetClientTeam(i) == CS_TEAM_T)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamTName");
			
			if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
				Format(TeamName, sizeof(TeamName), "%t", "AdminMenuTeamSpecName");
			
			GetClientName(i, name, 31);
			id = GetClientUserId(i);
			IntToString(id, target, sizeof(target));
			
			if(g_bSwapRoundEnd[i] || g_bSwapPlayerDeath[i])
				Format(listname, sizeof(listname),"[%s] %s (%s) [%s]", SwapTyp, name, target, TeamName);
			
			if(!g_bSwapRoundEnd[i] && !g_bSwapPlayerDeath[i])
				Format(listname, sizeof(listname),"%s (%s) [%s]", name, target, TeamName);
			
			AddMenuItem(hMenu, target, listname);
		}
	}
}

void ResetScore(int client)
{
	if(GetEngineVersion() == Engine_CSS)
	{
		if(GetClientFrags(client) == 0 && GetClientDeaths(client) == 0)
			PrintToChat(client, "%t", "AlreadyReset", g_sTag);
		else
		{
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
			SetEntProp(client, Prop_Data, "m_iDeaths", 0);
			CPrintToChatAll("%t", "ResetScore", g_sTag, client);

		}
	}
	else if(GetEngineVersion() == Engine_CSGO)
	{
		if(GetClientFrags(client) == 0 && GetClientDeaths(client) == 0 && CS_GetClientAssists(client) == 0 && CS_GetMVPCount(client) == 0)
			PrintToChat(client, "%t", "AlreadyReset", g_sTag);
		else
		{
			SetEntProp(client, Prop_Data, "m_iFrags", 0);
			SetEntProp(client, Prop_Data, "m_iDeaths", 0);
			CS_SetClientAssists(client, 0);
			CS_SetMVPCount(client, 0);
			CPrintToChatAll("%t", "ResetScore", g_sTag, client);
		}
	}
}

void NoPlayer(int param1)
{
	DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
	CPrintToChat(param1, "%t", "AdminMenuNoPlayer", g_sTag);
}

public Action Timer_ChangeClientTeam(Handle timer, any pack)
{
	ResetPack(pack);
	int client = GetClientOfUserId(ReadPackCell(pack));
	int team = ReadPackCell(pack);
	delete view_as<Handle>(pack);
	
	if(IsClientValid(client))
		ChangeClientTeam(client, team);
}

void CheckBalance()
{
	int diff = g_iTCount - g_iCTCount;
	if ( diff < 0 ) diff = -diff;
	g_bBalance = diff <= 1;
}

void ChangeTeamCount(int team, int diff)
{
	if(team == CS_TEAM_T)
		g_iTCount += diff;
	else if(team == CS_TEAM_CT)
		g_iCTCount += diff;
}

bool IsClientValid(int client)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
		return true;
	return false;
}

void DropBomb(int client)
{
	if(cBombDrop.BoolValue)
	{
		if(IsPlayerAlive(client) && GetPlayerWeaponSlot(client, CS_SLOT_C4) != -1)
			CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_C4), true, true);
	}
}

bool CanTargetPlayer(int client, int target)
{
	char saID[32], stID[32], sSteam[32] = "steam";
	GetClientAuthId(client, AuthId_Steam2, saID, sizeof(saID));
	GetClientAuthId(target, AuthId_Steam2, stID, sizeof(stID));
	
	AdminId aID = FindAdminByIdentity(sSteam, saID);
	AdminId tID = FindAdminByIdentity(sSteam, stID);
	
	return CanAdminTarget(aID, tID);
}
