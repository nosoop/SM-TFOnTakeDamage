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

#include <dhook_takedamageinfo>

#define PLUGIN_VERSION "1.0.1"
public Plugin myinfo = {
	name = "[TF2] OnTakeDamage Hooks",
	author = "nosoop",
	description = "Exposes OnTakeDamage with additional TF2-specific settings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFOnTakeDamage"
}

enum CritType {
	CritType_None = 0,
	CritType_MiniCrit,
	CritType_Crit
};

Handle g_FwdOnTakeDamage;
Handle g_DHookOnTakeDamage, g_DHookOnTakeDamageAlive;

int g_ContextCritType;

public APLRes AskPluginLoad2(Handle hPlugin, bool late, char[] error, int maxlen) {
	RegPluginLibrary("tf_ontakedamage");
	return APLRes_Success;
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("sdkhooks.games/engine.ep2v");
	
	g_DHookOnTakeDamage = DHookCreate(0, HookType_Entity, ReturnType_Int,
			ThisPointer_CBaseEntity);
	if (!g_DHookOnTakeDamage) {
		SetFailState("Failed to create DHook for OnTakeDamage."); 
	}
	DHookSetFromConf(g_DHookOnTakeDamage, hGameConf, SDKConf_Virtual, "OnTakeDamage");
	DHookAddParam(g_DHookOnTakeDamage, HookParamType_ObjectPtr, .flag = DHookPass_ByRef);
	
	g_DHookOnTakeDamageAlive = DHookCreate(0, HookType_Entity, ReturnType_Int,
			ThisPointer_CBaseEntity);
	if (!g_DHookOnTakeDamageAlive) {
		SetFailState("Failed to create DHook for OnTakeDamage_Alive."); 
	}
	DHookSetFromConf(g_DHookOnTakeDamageAlive, hGameConf, SDKConf_Virtual,
			"OnTakeDamage_Alive");
	DHookAddParam(g_DHookOnTakeDamageAlive, HookParamType_ObjectPtr, .flag = DHookPass_ByRef);
	
	delete hGameConf;
	
	g_FwdOnTakeDamage = CreateGlobalForward("TF2_OnTakeDamage", ET_Event,
			Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef,
			Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_CellByRef);
	
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
}

public void OnMapStart() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			HookTFOnTakeDamage(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	HookTFOnTakeDamage(client);
}

void HookTFOnTakeDamage(int client) {
	DHookEntity(g_DHookOnTakeDamage, false, client, .callback = Internal_OnTakeDamage);
	DHookEntity(g_DHookOnTakeDamageAlive, false, client, .callback = Internal_OnTakeDamageAlive);
}

public MRESReturn Internal_OnTakeDamage(int victim, Handle hReturn, Handle hParams) {
	SetTakeDamageInfoContext(hParams, 1);
	
	float damageForce[3], damagePosition[3];
	GetDamageInfoVector(TakeDamageInfo_DamageForce, damageForce);
	GetDamageInfoVector(TakeDamageInfo_DamagePosition, damagePosition);
	
	int inflictor = GetDamageInfoHandle(TakeDamageInfo_Inflictor);
	int attacker = GetDamageInfoHandle(TakeDamageInfo_Attacker);
	int weapon = GetDamageInfoHandle(TakeDamageInfo_Weapon);
	
	float flDamage = GetDamageInfoFloat(TakeDamageInfo_Damage);
	int bitsDamageType = GetDamageInfoInt(TakeDamageInfo_BitsDamageType);
	int damagecustom = GetDamageInfoInt(TakeDamageInfo_DamageCustom);
	int critType = GetDamageInfoInt(TakeDamageInfo_CritType);
	
	Action result = CallOnTakeDamage(victim, attacker, inflictor, flDamage,
			bitsDamageType, weapon, damageForce, damagePosition, damagecustom, critType);
	
	if (result > Plugin_Continue) {
		switch (critType) {
			case 2: {
				bitsDamageType |= DMG_CRIT;
			}
			default: {
				bitsDamageType &= ~DMG_CRIT;
			}
		}
		
		SetDamageInfoVector(TakeDamageInfo_DamageForce, damageForce);
		SetDamageInfoVector(TakeDamageInfo_DamagePosition, damagePosition);
		
		SetDamageInfoHandle(TakeDamageInfo_Inflictor, inflictor);
		SetDamageInfoHandle(TakeDamageInfo_Attacker, attacker);
		SetDamageInfoHandle(TakeDamageInfo_Weapon, weapon);
		
		SetDamageInfoFloat(TakeDamageInfo_Damage, flDamage);
		SetDamageInfoInt(TakeDamageInfo_BitsDamageType, bitsDamageType);
		SetDamageInfoInt(TakeDamageInfo_DamageCustom, damagecustom);
		SetDamageInfoInt(TakeDamageInfo_CritType, critType);
	}
	return MRES_Ignored;
}

public MRESReturn Internal_OnTakeDamageAlive(int victim, Handle hReturn, Handle hParams) {
	SetTakeDamageInfoContext(hParams, 1);
	g_ContextCritType = GetDamageInfoInt(TakeDamageInfo_CritType);
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

Action CallOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
		int &damagetype, int &weapon, float damageForce[3], float damagePosition[3],
		int damagecustom, int &critType) {
	Call_StartForward(g_FwdOnTakeDamage);
	Call_PushCell(victim);
	Call_PushCellRef(attacker);
	Call_PushCellRef(inflictor);
	Call_PushFloatRef(damage);
	Call_PushCellRef(damagetype);
	Call_PushCellRef(weapon);
	Call_PushArrayEx(damageForce, 3, SM_PARAM_COPYBACK);
	Call_PushArrayEx(damagePosition, 3, SM_PARAM_COPYBACK);
	Call_PushCell(damagecustom);
	Call_PushCellRef(critType);
	
	Action result;
	Call_Finish(result);
	return result;
}
