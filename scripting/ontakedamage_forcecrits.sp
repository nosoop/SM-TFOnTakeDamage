#pragma semicolon 1
#include <sourcemod>

#pragma newdecls required

#include <tf_ontakedamage>

ConVar g_ConVarForceCritType;

public void OnPluginStart() {
	g_ConVarForceCritType = CreateConVar("tf_forcecrittype", "-1", "Set damage crit type.");
}

public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
		int &damagetype, int &weapon, float damageForce[3], float damagePosition[3],
		int damagecustom, CritType &critType) {
	int newCritType = g_ConVarForceCritType.IntValue;
	if (newCritType == -1) {
		return Plugin_Continue;
	}
	
	critType = view_as<CritType>(newCritType);
	return Plugin_Changed;
}
