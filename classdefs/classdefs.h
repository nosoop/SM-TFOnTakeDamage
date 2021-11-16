typedef u1 bool;
typedef int EHANDLE;

typedef int ECritType;

struct CTakeDamageInfo {
	float m_vecDamageForce[3];
	float m_vecDamagePosition[3];
	float m_vecReportedPosition[3];
	EHANDLE m_hInflictor;
	EHANDLE m_hAttacker;
	EHANDLE m_hWeapon;
	float m_flDamage;
	float m_flMaxDamage;
	float m_flBaseDamage;
	int m_bitsDamageType;
	int m_iDamageCustom;
	int m_iDamageStats;
	int m_iAmmoType;
	int m_iDamagedOtherPlayers;
	int m_iPlayerPenetrationCount;
	float m_flDamageBonus;
	EHANDLE m_hDamageBonusProvider;
	bool m_bForceFriendlyFire;
	
	// alignment rules aren't implemented in dissect.cstruct AFAIK
	// the name __padding is specifically ignored in generate_classes.py
	bool __padding[3];
	
	float m_flDamageForForce;
	
	ECritType m_eCritType;
};
