/**
 * [TF2] OnTakeDamage Hooks
 * 
 * Essentially similar to SDKHooks' OnTakeDamage hooks, but also exposes the crit type for
 * plugins to modify and patches the engine up afterwards so it displays correctly.
 */
#pragma semicolon 1
#include <sourcemod>

#include <dhooks>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#include <stocksoup/memory>

#include <classdefs/CTakeDamageInfo.sp>

#define PLUGIN_VERSION "1.3.0"
public Plugin myinfo = {
	name = "[TF2] OnTakeDamage Hooks",
	author = "nosoop",
	description = "Exposes OnTakeDamage with additional TF2-specific settings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFOnTakeDamage"
}

Handle g_FwdOnTakeDamage;
DynamicDetour g_DHookOnTakeDamage, g_DHookOnTakeDamageAlive;
Handle g_FwdDamageModifyRules;
Handle g_FwdOnTakeDamagePost;

int g_ContextCritType;

public APLRes AskPluginLoad2(Handle hPlugin, bool late, char[] error, int maxlen) {
	RegPluginLibrary("tf_ontakedamage");
	return APLRes_Success;
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.ontakedamage");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.ontakedamage).");
	}
	
	g_DHookOnTakeDamage = new DynamicDetour(Address_Null, CallConv_THISCALL,
			ReturnType_Int, ThisPointer_CBaseEntity);
	g_DHookOnTakeDamage.SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::OnTakeDamage()");
	g_DHookOnTakeDamage.AddParam(HookParamType_Int);
	g_DHookOnTakeDamage.Enable(Hook_Pre, Internal_OnTakeDamage);
	g_DHookOnTakeDamage.Enable(Hook_Post, Internal_OnTakeDamagePost);
	
	g_DHookOnTakeDamageAlive = new DynamicDetour(Address_Null, CallConv_THISCALL,
			ReturnType_Int, ThisPointer_CBaseEntity);
	g_DHookOnTakeDamageAlive.SetFromConf(hGameConf, SDKConf_Signature, "CTFPlayer::OnTakeDamage_Alive()");
	g_DHookOnTakeDamageAlive.AddParam(HookParamType_Int);
	g_DHookOnTakeDamageAlive.Enable(Hook_Pre, Internal_OnTakeDamageAlive);
	
	Handle dtModifyRules = DHookCreateFromConf(hGameConf,
			"CTFGameRules::ApplyOnDamageModifyRules()");
	DHookEnableDetour(dtModifyRules, true, OnDamageModifyRules);
	
	delete hGameConf;
	
	g_FwdOnTakeDamage = CreateGlobalForward("TF2_OnTakeDamage", ET_Event,
			Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef,
			Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_CellByRef);
	
	g_FwdOnTakeDamagePost = CreateGlobalForward("TF2_OnTakeDamagePost", ET_Event,
			Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Cell,
			Param_Cell, Param_Array, Param_Array, Param_Cell, Param_Cell);
	
	g_FwdDamageModifyRules = CreateGlobalForward("TF2_OnTakeDamageModifyRules", ET_Event,
			Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef,
			Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_CellByRef);
	
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
}

public MRESReturn Internal_OnTakeDamage(int victim, Handle hReturn, Handle hParams) {
	CTakeDamageInfo info = CTakeDamageInfo.FromAddress(DHookGetParam(hParams, 1));
	CallTakeDamageInfoForward(g_FwdOnTakeDamage, victim, info);
	return MRES_Ignored;
}

public MRESReturn OnDamageModifyRules(Address pGameRules, Handle hReturn, Handle hParams) {
	if (DHookGetReturn(hReturn) == true) {
		CTakeDamageInfo info = CTakeDamageInfo.FromAddress(DHookGetParam(hParams, 1));
		int victim = DHookGetParam(hParams, 2);
		CallTakeDamageInfoForward(g_FwdDamageModifyRules, victim, info);
	}
	return MRES_Ignored;
}

MRESReturn Internal_OnTakeDamagePost(int victim, Handle hReturn, Handle hParams) {
	CTakeDamageInfo info = CTakeDamageInfo.FromAddress(DHookGetParam(hParams, 1));
	CallTakeDamageInfoPostForward(g_FwdOnTakeDamagePost, victim, info);
	return MRES_Ignored;
}

void CallTakeDamageInfoForward(Handle fwd, int victim, CTakeDamageInfo info) {
	float damageForce[3], damagePosition[3];
	info.m_vecDamageForce.Get(damageForce);
	info.m_vecDamagePosition.Get(damagePosition);
	
	int inflictor = EHandleToEntRef(info.m_hInflictor);
	int attacker  = EHandleToEntRef(info.m_hAttacker);
	int weapon    = EHandleToEntRef(info.m_hWeapon);
	
	float flDamage     = info.m_flDamage;
	int bitsDamageType = info.m_bitsDamageType;
	int damagecustom   = info.m_iDamageCustom;
	int critType       = info.m_eCritType;
	
	Call_StartForward(fwd);
	Call_PushCell(victim);
	Call_PushCellRef(attacker);
	Call_PushCellRef(inflictor);
	Call_PushFloatRef(flDamage);
	Call_PushCellRef(bitsDamageType);
	Call_PushCellRef(weapon);
	Call_PushArrayEx(damageForce, 3, SM_PARAM_COPYBACK);
	Call_PushArrayEx(damagePosition, 3, SM_PARAM_COPYBACK);
	Call_PushCell(damagecustom);
	Call_PushCellRef(critType);
	
	Action result;
	Call_Finish(result);
	
	if (result > Plugin_Continue) {
		switch (critType) {
			case 2: {
				bitsDamageType |= DMG_CRIT;
			}
			default: {
				bitsDamageType &= ~DMG_CRIT;
			}
		}
		
		info.m_vecDamageForce.Set(damageForce);
		info.m_vecDamagePosition.Set(damagePosition);
		
		info.m_hInflictor = EntityToEHandle(inflictor);
		info.m_hAttacker  = EntityToEHandle(attacker);
		info.m_hWeapon    = EntityToEHandle(weapon);
		
		info.m_flDamage       = flDamage;
		info.m_bitsDamageType = bitsDamageType,
		info.m_iDamageCustom  = damagecustom;
		info.m_eCritType      = critType;
	}
}

void CallTakeDamageInfoPostForward(Handle fwd, int victim, CTakeDamageInfo info) {
	float damageForce[3], damagePosition[3];
	info.m_vecDamageForce.Get(damageForce);
	info.m_vecDamagePosition.Get(damagePosition);
	
	int inflictor = EHandleToEntRef(info.m_hInflictor);
	int attacker  = EHandleToEntRef(info.m_hAttacker);
	int weapon    = EHandleToEntRef(info.m_hWeapon);
	
	float flDamage     = info.m_flDamage;
	int bitsDamageType = info.m_bitsDamageType;
	int damagecustom   = info.m_iDamageCustom;
	int critType       = info.m_eCritType;
	
	Call_StartForward(fwd);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushCell(inflictor);
	Call_PushFloat(flDamage);
	Call_PushCell(bitsDamageType);
	Call_PushCell(weapon);
	Call_PushArray(damageForce, 3);
	Call_PushArray(damagePosition, 3);
	Call_PushCell(damagecustom);
	Call_PushCell(critType);
	
	Call_Finish();
}

public MRESReturn Internal_OnTakeDamageAlive(int victim, Handle hReturn, Handle hParams) {
	CTakeDamageInfo info = CTakeDamageInfo.FromAddress(DHookGetParam(hParams, 1));
	g_ContextCritType = info.m_eCritType;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if (g_ContextCritType != 1) {
		return Plugin_Continue;
	}
	
	event.SetInt("crit", 1);
	event.SetInt("minicrit", 1);
	event.SetInt("bonuseffect", 1);
	return Plugin_Changed;
}

int EHandleToEntRef(int ehandle) {
	return ehandle | (1 << 31);
}

int EntityToEHandle(int entity) {
	return IsValidEntity(entity)? EntIndexToEntRef(entity) & ~(1 << 31) : 0;
}
