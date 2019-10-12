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

#define PLUGIN_VERSION "1.0.2-inlined-reads"
public Plugin myinfo = {
	name = "[TF2] OnTakeDamage Hooks",
	author = "nosoop",
	description = "Exposes OnTakeDamage with additional TF2-specific settings.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFOnTakeDamage"
}

enum eTakeDamageInfo: (+= 0x04) {
	// vectors
	m_DamageForce,
	m_DamagePosition = 12,
	m_ReportedPosition = 24,

	m_Inflictor = 36,
	m_Attacker,
	m_Weapon,
	m_Damage,
	m_MaxDamage,
	m_BaseDamage,
	m_BitsDamageType,
	m_DamageCustom,
	m_DamageStats,
	m_AmmoType,
	m_DamagedOtherPlayers,
	m_PlayerPenetrationCount,
	m_DamageBonus,
	m_DamageBonusProvider,
	m_ForceFriendlyFire,
	m_DamageForForce,
	m_CritType
};

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
	DHookAddParam(g_DHookOnTakeDamage, HookParamType_Int);
	
	g_DHookOnTakeDamageAlive = DHookCreate(0, HookType_Entity, ReturnType_Int,
			ThisPointer_CBaseEntity);
	if (!g_DHookOnTakeDamageAlive) {
		SetFailState("Failed to create DHook for OnTakeDamage_Alive."); 
	}
	DHookSetFromConf(g_DHookOnTakeDamageAlive, hGameConf, SDKConf_Virtual,
			"OnTakeDamage_Alive");
	DHookAddParam(g_DHookOnTakeDamageAlive, HookParamType_Int);
	
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
	Address pTakeDamageInfo = DHookGetParam(hParams, 1);
	
	float damageForce[3], damagePosition[3];
	LoadFloatVectorFromAddress(AddressOffset(pTakeDamageInfo, m_DamageForce), damageForce);
	LoadFloatVectorFromAddress(AddressOffset(pTakeDamageInfo, m_DamagePosition),
			damagePosition);
	
	int inflictor = LoadEntityHandleFromAddress(AddressOffset(pTakeDamageInfo, m_Inflictor));
	int attacker  = LoadEntityHandleFromAddress(AddressOffset(pTakeDamageInfo, m_Attacker));
	int weapon    = LoadEntityHandleFromAddress(AddressOffset(pTakeDamageInfo, m_Weapon));
	
	float flDamage = view_as<float>(
			LoadFromAddress(AddressOffset(pTakeDamageInfo, m_Damage), NumberType_Int32));
	int bitsDamageType =
			LoadFromAddress(AddressOffset(pTakeDamageInfo, m_BitsDamageType), NumberType_Int32);
	int damagecustom =
			LoadFromAddress(AddressOffset(pTakeDamageInfo, m_DamageCustom), NumberType_Int32);
	int critType =
			LoadFromAddress(AddressOffset(pTakeDamageInfo, m_CritType), NumberType_Int32);
	
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
		
		StoreFloatVectorToAddress(AddressOffset(pTakeDamageInfo, m_DamageForce), damageForce);
		StoreFloatVectorToAddress(AddressOffset(pTakeDamageInfo, m_DamagePosition),
				damagePosition);
		
		StoreEntityHandleToAddress(AddressOffset(pTakeDamageInfo, m_Inflictor), inflictor);
		StoreEntityHandleToAddress(AddressOffset(pTakeDamageInfo, m_Attacker), attacker);
		StoreEntityHandleToAddress(AddressOffset(pTakeDamageInfo, m_Weapon), weapon);
		
		StoreToAddress(AddressOffset(pTakeDamageInfo, m_Damage), view_as<int>(flDamage),
				NumberType_Int32);
		StoreToAddress(AddressOffset(pTakeDamageInfo, m_BitsDamageType), bitsDamageType,
				NumberType_Int32);
		StoreToAddress(AddressOffset(pTakeDamageInfo, m_DamageCustom), damagecustom,
				NumberType_Int32);
		StoreToAddress(AddressOffset(pTakeDamageInfo, m_CritType), critType,
				NumberType_Int32);
	}
	return MRES_Ignored;
}

public MRESReturn Internal_OnTakeDamageAlive(int victim, Handle hReturn, Handle hParams) {
	Address pTakeDamageInfo = DHookGetParam(hParams, 1);
	g_ContextCritType =
			LoadFromAddress(AddressOffset(pTakeDamageInfo, m_CritType), NumberType_Int32);
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

void LoadFloatVectorFromAddress(Address addr, float vec[3]) {
	for (int i; i < 3; i++) {
		vec[i] = view_as<float>(LoadFromAddress(AddressOffset(addr, i * 4), NumberType_Int32));
	}
}

void StoreFloatVectorToAddress(Address addr, const float vec[3]) {
	for (int i; i < 3; i++) {
		StoreToAddress(AddressOffset(addr, i * 4), view_as<int>(vec[i]), NumberType_Int32);
	}
}

/**
 * SourceMod retagging pain
 */
Address AddressOffset(Address addr, int offs) {
	return addr + view_as<Address>(offs);
}
