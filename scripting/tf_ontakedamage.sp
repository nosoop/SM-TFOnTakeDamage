/**
 * [TF2] OnTakeDamage Hooks
 * 
 * Essentially similar to SDKHooks' OnTakeDamage hooks, but also exposes the crit type for
 * plugins to modify and patches the engine up afterwards so it displays correctly.
 */
#pragma semicolon 1
#include <sourcemod>

#include <dhooks>
#include <sdkhooks>

#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
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

// whether or not minicrit override was applied
// bool g_bShowMiniCritDeath[MAXPLAYERS + 1];

// determine if OnTakeDamage context overrode crit value
bool g_bScopedMinicritOverride;

public APLRes AskPluginLoad2(Handle hPlugin, bool late, char[] error, int maxlen) {
	RegPluginLibrary("tf_ontakedamage");
	return APLRes_Success;
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("sdkhooks.games/engine.ep2v");
	
	int offs_OnTakeDamage = GameConfGetOffset(hGameConf, "OnTakeDamage");
	if (offs_OnTakeDamage == -1) {
		SetFailState("Missing offset for OnTakeDamage"); 
	}
	
	int offs_OnTakeDamageAlive = GameConfGetOffset(hGameConf, "OnTakeDamage_Alive");
	if (offs_OnTakeDamageAlive == -1) {
		SetFailState("Missing offset for OnTakeDamage_Alive"); 
	}
	
	delete hGameConf;
	
	g_DHookOnTakeDamage = DHookCreate(offs_OnTakeDamage, HookType_Entity, ReturnType_Int,
			ThisPointer_CBaseEntity);
	if (!g_DHookOnTakeDamage) {
		SetFailState("Failed to create DHook for OnTakeDamage_Alive."); 
	}
	DHookAddParam(g_DHookOnTakeDamage, HookParamType_ObjectPtr, .flag = DHookPass_ByRef);
	
	g_DHookOnTakeDamageAlive = DHookCreate(offs_OnTakeDamageAlive, HookType_Entity, ReturnType_Int,
			ThisPointer_CBaseEntity);
	if (!g_DHookOnTakeDamageAlive) {
		SetFailState("Failed to create DHook for OnTakeDamage_Alive."); 
	}
	DHookAddParam(g_DHookOnTakeDamageAlive, HookParamType_ObjectPtr, .flag = DHookPass_ByRef);
	
	g_FwdOnTakeDamage = CreateGlobalForward("TF2_OnTakeDamage", ET_Event,
			Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef,
			Param_CellByRef, Param_Array, Param_Array, Param_Cell, Param_CellByRef);
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
	// DHookEntity(g_DHookOnTakeDamageAlive, true, client, .callback = TF2_OnTakeDamageAlive);
	DHookEntity(g_DHookOnTakeDamageAlive, false, client, .callback = Internal_OnTakeDamageAlivePost);
}

/**
 * CTakeDamageInfo
 * 0 Vector m_vecDamageForce;
 * 12 Vector m_vecDamagePosition;
 * 24 Vector m_vecReportedPosition;
 * 36 EHANDLE m_hInflictor;
 * 40 EHANDLE m_hAttacker;
 * 44 EHANDLE m_hWeapon;
 * 48 float m_flDamage;
 * 52 float m_flMaxDamage;
 * 56 float m_flBaseDamage
 * 60 int m_bitsDamageType;
 * 64 int m_iDamageCustom;
 * 68 int m_iDamageStats;
 * 72 int m_iAmmoType
 * 76 int m_iDamagedOtherPlayers
 * 80 int m_iPlayerPenetrationCount
 * 84 float m_flDamageBonus
 * 88 EHANDLE m_hDamageBonusProvider
 * 92 bool m_bForceFriendlyFire
 * 96 float m_flDamageForForce;
 * 100 ECritType m_eCritType;
 */

public MRESReturn Internal_OnTakeDamage(int victim, Handle hReturn, Handle hParams) {
	float damageForce[3], damagePosition[3];
	GetDamageInfoVector(hParams, 0, damageForce);
	GetDamageInfoVector(hParams, 12, damagePosition);
	
	int inflictor = GetDamageInfoHandle(hParams, 36);
	int attacker = GetDamageInfoHandle(hParams, 40);
	int weapon = GetDamageInfoHandle(hParams, 44);
	
	float flDamage = GetDamageInfoFloat(hParams, 48);
	int bitsDamageType = GetDamageInfoInt(hParams, 60);
	int damagecustom = GetDamageInfoInt(hParams, 64);
	int critType = GetDamageInfoInt(hParams, 100);
	
	int origCritType = critType;
	
	Action result = CallOnTakeDamage(victim, attacker, inflictor, flDamage,
			bitsDamageType, weapon, damageForce, damagePosition, damagecustom, critType);
	
	if (result > Plugin_Continue) {
		switch (critType) {
			case 0, 1: {
				// strip crit flag on non-full crits
				bitsDamageType &= ~DMG_CRIT;
				g_bScopedMinicritOverride = origCritType != critType && critType == 1;
			}
			case 2: {
				bitsDamageType |= DMG_CRIT;
			}
		}
		
		SetDamageInfoVector(hParams, 0, damageForce);
		SetDamageInfoVector(hParams, 12, damagePosition);
		
		SetDamageInfoHandle(hParams, 36, inflictor);
		SetDamageInfoHandle(hParams, 40, attacker);
		SetDamageInfoHandle(hParams, 44, weapon);
		
		SetDamageInfoFloat(hParams, 48, flDamage);
		SetDamageInfoInt(hParams, 60, bitsDamageType);
		SetDamageInfoInt(hParams, 64, damagecustom);
		SetDamageInfoInt(hParams, 100, critType);
	}
	
	return MRES_Ignored;
}

public MRESReturn Internal_OnTakeDamageAlivePost(int victim, Handle hReturn, Handle hParams) {
	int critType = GetDamageInfoInt(hParams, 100);
	
	if (g_bScopedMinicritOverride && critType == 1) {
		// restrip crit flag post-damage so the minicrit shows up client-side
		int bitsDamageType = GetDamageInfoInt(hParams, 60);
		SetDamageInfoInt(hParams, 60, bitsDamageType & ~DMG_CRIT);
	}
	
	g_bScopedMinicritOverride = false;
	return MRES_Ignored;
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

int GetDamageInfoHandle(Handle hParams, int offset) {
	return DHookGetParamObjectPtrVar(hParams, 1, offset, ObjectValueType_Ehandle);
}

void SetDamageInfoHandle(Handle hParams, int offset, int entity) {
	DHookSetParamObjectPtrVar(hParams, 1, offset, ObjectValueType_Ehandle, entity);
}

float GetDamageInfoFloat(Handle hParams, int offset) {
	return DHookGetParamObjectPtrVar(hParams, 1, offset, ObjectValueType_Float);
}

void SetDamageInfoFloat(Handle hParams, int offset, float value) {
	DHookSetParamObjectPtrVar(hParams, 1, offset, ObjectValueType_Float, value);
}

int GetDamageInfoInt(Handle hParams, int offset) {
	return DHookGetParamObjectPtrVar(hParams, 1, offset, ObjectValueType_Int);
}

void SetDamageInfoInt(Handle hParams, int offset, int value) {
	DHookSetParamObjectPtrVar(hParams, 1, offset, ObjectValueType_Int, value);
}

void GetDamageInfoVector(Handle hParams, int offset, float vec[3]) {
	/* ret */ DHookGetParamObjectPtrVarVector(hParams, 1, offset, ObjectValueType_Vector, vec);
}

void SetDamageInfoVector(Handle hParams, int offset, float vec[3]) {
	DHookSetParamObjectPtrVarVector(hParams, 1, offset, ObjectValueType_Vector, vec);
}
