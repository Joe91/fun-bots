---@class WeaponList
WeaponList = class('WeaponList')

require('__shared/WeaponClass')
require('__shared/Config')
require('__shared/Constants/WeaponTypes')
require('__shared/WeaponLists/CustomWeaponsAssaultUs')
require('__shared/WeaponLists/CustomWeaponsAssaultRu')
require('__shared/WeaponLists/CustomWeaponsEngineerUs')
require('__shared/WeaponLists/CustomWeaponsEngineerRu')
require('__shared/WeaponLists/CustomWeaponsReconUs')
require('__shared/WeaponLists/CustomWeaponsReconRu')
require('__shared/WeaponLists/CustomWeaponsSupportUs')
require('__shared/WeaponLists/CustomWeaponsSupportRu')

---@type Logger
local m_Logger = Logger("WeaponList", Debug.Shared.MODIFICATIONS)

-- create globals
AllWeapons = {}
KnifeWeapons = {}
PistoWeapons = {}
Weapons = {}

AssaultPrimary = {}
EngineerPrimary = {}
SupportPrimary = {}
ReconPrimary = {}

function WeaponList:__init()
	self._weapons = {
		---------------------------
		-- shotguns

		Weapon('DAO-12_Flechette', '', {'Weapons/DAO-12/U_DAO-12_Flechette', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/DAO-12/U_DAO-12'),
		Weapon('DAO-12_Frag', '', {'Weapons/DAO-12/U_DAO-12_Frag', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/DAO-12/U_DAO-12'),
		Weapon('DAO-12_Slug', '', {'Weapons/DAO-12/U_DAO-12_Slug', 'Kobra', 'TargetPointer'}, WeaponTypes.Shotgun, 'Weapons/DAO-12/U_DAO-12'),
		Weapon('Jackhammer_Flechette', 'XP1', {'Weapons/XP1_Jackhammer/U_Jackhammer_Flechette', 'Kobra', 'ExtendedMag', 'Weapons/XP1_Jackhammer/U_JACKHAMMER_CAMO_1'}, WeaponTypes.Shotgun, 'Weapons/XP1_Jackhammer/U_Jackhammer'),
		Weapon('Jackhammer_Frag', 'XP1', {'Weapons/XP1_Jackhammer/U_Jackhammer_Frag', 'Kobra', 'ExtendedMag', 'Weapons/XP1_Jackhammer/U_JACKHAMMER_CAMO_2'}, WeaponTypes.Shotgun, 'Weapons/XP1_Jackhammer/U_Jackhammer'),
		Weapon('Jackhammer_Slug', 'XP1', {'Weapons/XP1_Jackhammer/U_Jackhammer_Slug', 'Kobra', 'TargetPointer', 'Weapons/XP1_Jackhammer/U_JACKHAMMER_CAMO_1'}, WeaponTypes.Shotgun, 'Weapons/XP1_Jackhammer/U_Jackhammer'),
		Weapon('Saiga20_Flechette', '', {'Weapons/SAIGA20K/U_Saiga_20k_Flechette', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/SAIGA20K/U_SAIGA_20K'),
		Weapon('Saiga20_Frag', '', {'Weapons/SAIGA20K/U_Saiga_20k_Frag', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/SAIGA20K/U_SAIGA_20K'),
		Weapon('Saiga20_Slug', '', {'Weapons/SAIGA20K/U_Saiga_20k_Slug', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/SAIGA20K/U_SAIGA_20K'),
		Weapon('SPAS12_Flechette', 'XP2', {'Weapons/XP2_SPAS12/U_SPAS12_Flechette', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/XP2_SPAS12/U_SPAS12'),
		Weapon('SPAS12_Frag', 'XP2', {'Weapons/XP2_SPAS12/U_SPAS12_Frag', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/XP2_SPAS12/U_SPAS12'),
		--TODO: Get Damage-Values and Speed of other ammo
		Weapon('SPAS12_Slug', 'XP2', {'Weapons/XP2_SPAS12/U_SPAS12_Slug', 'Kobra', 'ExtendedMag'}, WeaponTypes.Shotgun, 'Weapons/XP2_SPAS12/U_SPAS12'),
		Weapon('USAS-12_Flechette', '', {'Weapons/USAS-12/U_USAS-12_Flechette', 'ExtendedMag', 'Kobra'}, WeaponTypes.Shotgun, 'Weapons/USAS-12/U_USAS-12'),
		Weapon('USAS-12_Frag', '', {'Weapons/USAS-12/U_USAS-12_Frag', 'ExtendedMag', 'Kobra'}, WeaponTypes.Shotgun, 'Weapons/USAS-12/U_USAS-12'),
		Weapon('USAS-12_Slug', '', {'Weapons/USAS-12/U_USAS-12_Slug', 'ExtendedMag', 'Kobra'}, WeaponTypes.Shotgun, 'Weapons/USAS-12/U_USAS-12'),
		Weapon('M1014_Flechette', '', {'Weapons/M1014/U_M1014_Flechette', 'ExtendedMag', 'RX01'}, WeaponTypes.Shotgun, 'Weapons/M1014/U_M1014'),
		Weapon('M1014_Frag', '', {'Weapons/M1014/U_M1014_Frag', 'ExtendedMag', 'RX01'}, WeaponTypes.Shotgun, 'Weapons/M1014/U_M1014'),
		Weapon('M1014_Slug', '', {'Weapons/M1014/U_M1014_Slug', 'ExtendedMag', 'RX01'}, WeaponTypes.Shotgun, 'Weapons/M1014/U_M1014'),
		Weapon('870M_Flechette', '', {'Weapons/Remington870/U_870_Flechette', 'ExtendedMag', 'RX01'}, WeaponTypes.Shotgun, 'Weapons/Remington870/U_870'),
		Weapon('870M_Frag', '', {'Weapons/Remington870/U_870_Frag', 'ExtendedMag', 'RX01'}, WeaponTypes.Shotgun, 'Weapons/Remington870/U_870'),
		Weapon('870M_Slug', '', {'Weapons/Remington870/U_870_Slug', 'ExtendedMag', 'RX01'}, WeaponTypes.Shotgun, 'Weapons/Remington870/U_870'),
		---------------------------
		--assault

		Weapon('AEK971_Kobra', '', {'Kobra', 'Weapons/Common/NoSecondaryRail', 'Flashsuppressor'}, WeaponTypes.Assault, 'Weapons/AEK971/U_AEK971'),
		Weapon('AEK971_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Assault, 'Weapons/AEK971/U_AEK971'),
		Weapon('AN94_Kobra', '', {'Kobra', 'Foregrip', 'Flashsuppressor'}, WeaponTypes.Assault, 'Weapons/AN94/U_AN94'),
		Weapon('AN94_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Assault, 'Weapons/AN94/U_AN94'),
		Weapon('AK74M_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Assault, 'Weapons/AK74M/U_AK74M'),
		Weapon('AK74M_RX01', '', {'RX_01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Assault, 'Weapons/AK74M/U_AK74M'),
		Weapon('SteyrAug_RX01', 'XP2', {'RX01', 'Foregrip', 'Heavy_Barrel'},WeaponTypes.Assault, 'Weapons/XP2_SteyrAug/U_SteyrAug'),
		Weapon('SteyrAug_Kobra', 'XP2', {'Kobra', 'Foregrip', 'Heavy_Barrel'},WeaponTypes.Assault, 'Weapons/XP2_SteyrAug/U_SteyrAug'),
		Weapon('F2000_RX01', '', {'RX01', 'Foregrip', 'Heavy_Barrel', 'Weapons/F2000/U_F2000_Camo_NWU'},WeaponTypes.Assault, 'Weapons/F2000/U_F2000'),
		Weapon('F2000_Kobra', '', {'Kobra', 'Foregrip', 'Heavy_Barrel', 'Weapons/F2000/U_F2000_Camo_PARTIZAN'},WeaponTypes.Assault, 'Weapons/F2000/U_F2000'),
		Weapon('FAMAS_RX01', 'XP1', {'RX01', 'Foregrip', 'HeavyBarrel'}, WeaponTypes.Assault, 'Weapons/XP1_FAMAS/U_FAMAS'),
		Weapon('FAMAS_Kobra', 'XP1', {'Kobra', 'Foregrip', 'HeavyBarrel'}, WeaponTypes.Assault, 'Weapons/XP1_FAMAS/U_FAMAS'),
		Weapon('G3A3_RX01', '', {'RX01', 'Target_Pointer', 'Foregrip'}, WeaponTypes.Assault, 'Weapons/G3A3/U_G3A3'),
		Weapon('G3A3_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Assault, 'Weapons/G3A3/U_G3A3'),
		Weapon('KH2002_Kobra', '', {'Kobra', 'Foregrip', 'Heavy_Barrel'}, WeaponTypes.Assault, 'Weapons/KH2002/U_KH2002'),
		Weapon('KH2002_RX01', '', {'RX01', 'Foregrip', 'Heavy_Barrel'}, WeaponTypes.Assault, 'Weapons/KH2002/U_KH2002'),
		Weapon('L85A2_RX01', 'XP1', {'RX01', 'HeavyBarrel', 'ForeGrip', 'Weapons/XP1_L85A2/U_L85A2_CAMO_1'},WeaponTypes.Assault, 'Weapons/XP1_L85A2/U_L85A2'),
		Weapon('L85A2_Kobra', 'XP1', {'Kobra', 'HeavyBarrel', 'ForeGrip', 'Weapons/XP1_L85A2/U_L85A2_CAMO_2'},WeaponTypes.Assault, 'Weapons/XP1_L85A2/U_L85A2'),
		Weapon('M16A4_RX01', '', {'RX01', 'HeavyBarrel', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault, 'Weapons/M16A4/U_M16A4'),
		Weapon('M16A4_Kobra', '', {'Kobra', 'HeavyBarrel', 'Weapons/Common/NoSecondaryRail'}, WeaponTypes.Assault, 'Weapons/M16A4/U_M16A4'),
		Weapon('M16-Burst_RX01', '', {'Weapons/M16A4/U_M16A4_RX01', 'Weapons/M16A4/U_M16A4_HeavyBarrel', 'Weapons/M16A4/U_M16A4_Foregrip'}, WeaponTypes.Assault, 'Weapons/M16A4/U_M16_Burst'),
		Weapon('M16-Burst_Kobra', '', {'Weapons/M16A4/U_M16A4_Kobra', 'Weapons/M16A4/U_M16A4_HeavyBarrel', 'Weapons/M16A4/U_M16A4_Foregrip'}, WeaponTypes.Assault, 'Weapons/M16A4/U_M16_Burst'),
		Weapon('M416_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip', 'Weapons/M416/U_M416_CAMO_1'},WeaponTypes.Assault, 'Weapons/M416/U_M416'),
		Weapon('M416_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip', 'Weapons/M416/U_M416_CAMO_2'},WeaponTypes.Assault, 'Weapons/M416/U_M416'),
		Weapon('SCAR-L_EOTech', 'XP2', {'EOTech', 'Foregrip', 'HeavyBarrel'},WeaponTypes.Assault, 'Weapons/XP2_SCAR-L/U_SCAR-L'),
		Weapon('SCAR-L_Kobra', 'XP2', {'Kobra', 'Foregrip', 'HeavyBarrel'},WeaponTypes.Assault, 'Weapons/XP2_SCAR-L/U_SCAR-L'),

		---------------------------
		-- PDW --------------------

		Weapon('ASVal_Kobra', '', {'Kobra', 'ExtendedMag', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW, 'Weapons/ASVal/U_ASVal'),
		Weapon('ASVal_RX01', '', {'RX01', 'ExtendedMag', 'Weapons/Common/NoSecondaryAccessory'}, WeaponTypes.PDW, 'Weapons/ASVal/U_ASVal'),
		Weapon('MP7_RX01', '', {'RX01', 'ExtendedMag', 'Targetpointer'}, WeaponTypes.PDW, 'Weapons/MP7/U_MP7'),
		Weapon('MP7_Kobra', '', {'Kobra', 'ExtendedMag', 'Targetpointer'}, WeaponTypes.PDW, 'Weapons/MP7/U_MP7'),
		Weapon('P90_RX01', '', {'RX01', 'Targetpointer', 'Flashsuppressor'}, WeaponTypes.PDW, 'Weapons/P90/U_P90'),
		Weapon('P90_Kobra', '', {'Kobra', 'Targetpointer', 'Flashsuppressor'}, WeaponTypes.PDW, 'Weapons/P90/U_P90'),
		Weapon('PP-19_Kobra', 'XP1', {'Kobra', 'FlashSuppressor', 'Targetpointer', 'Weapons/XP1_PP-19/U_PP-19_CAMO_2'}, WeaponTypes.PDW, 'Weapons/XP1_PP-19/U_PP-19'),
		Weapon('PP-19_RX01', 'XP1', {'RX01', 'FlashSuppressor', 'Targetpointer', 'Weapons/XP1_PP-19/U_PP-19_CAMO_1'}, WeaponTypes.PDW, 'Weapons/XP1_PP-19/U_PP-19'),
		Weapon('PP2000_Kobra', '', {'Kobra', 'Flashsuppressor', 'Targetpointer'}, WeaponTypes.PDW, 'Weapons/PP2000/U_PP2000'),
		Weapon('PP2000_RX01', '', {'RX01', 'Flashsuppressor', 'Targetpointer'}, WeaponTypes.PDW, 'Weapons/PP2000/U_PP2000'),
		Weapon('UMP45_RX01', '', {'RX01', 'Flashsuppressor', 'Targetpointer', 'Weapons/UMP45/U_UMP45_CAMO_1'}, WeaponTypes.PDW, 'Weapons/UMP45/U_UMP45'),
		Weapon('UMP45_Kobra', '', {'Kobra', 'Flashsuppressor', 'Targetpointer', 'Weapons/UMP45/U_UMP45_CAMO_2'}, WeaponTypes.PDW, 'Weapons/UMP45/U_UMP45'),
		Weapon('MP5K_RX01', 'XP2', {'RX01', 'Flashsuppressor', 'ExtendedMags'}, WeaponTypes.PDW, 'Weapons/XP2_MP5K/U_MP5K'),
		Weapon('MP5K_Kobra', 'XP2', {'Kobra', 'Flashsuppressor', 'ExtendedMags'}, WeaponTypes.PDW, 'Weapons/XP2_MP5K/U_MP5K'),
		Weapon('MagpulPDR_Kobra', '', {'Kobra', 'Flashsuppressor', 'Targetpointer'}, WeaponTypes.PDW, 'Weapons/MagpulPDR/U_MagpulPDR'),
		Weapon('MagpulPDR_RX01', '', {'RX01', 'Flashsuppressor', 'Targetpointer'}, WeaponTypes.PDW, 'Weapons/MagpulPDR/U_MagpulPDR'),
		Weapon('Crossbow_Kobra', '', {}, WeaponTypes.PDW, 'Weapons/XP4_Crossbow_Prototype/U_Crossbow_Scoped_Cobra'),
		Weapon('Crossbow_RifleScope', '', {}, WeaponTypes.PDW, 'Weapons/XP4_Crossbow_Prototype/U_Crossbow_Scoped_RifleScope'),

		---------------------------
		--Carbines

		Weapon('A91_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/A91/U_A91'),
		Weapon('A91_RX01', '', {'RX_01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/A91/U_A91'),
		Weapon('ACR_RX01', 'XP2', {'RX01', 'HeavyBarrel', 'Foregrip', 'Weapons/XP2_ACR/U_ACR_CAMO_1'}, WeaponTypes.Carabine, 'Weapons/XP2_ACR/U_ACR'),
		Weapon('ACR_Kobra', 'XP2', {'Kobra', 'HeavyBarrel', 'Foregrip', 'Weapons/XP2_ACR/U_ACR_CAMO_2'}, WeaponTypes.Carabine, 'Weapons/XP2_ACR/U_ACR'),
		Weapon('AKS74u_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/AKS74u/U_AKS74u'),
		Weapon('AKS74u_RX01', '', {'RX_01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/AKS74u/U_AKS74u'),
		Weapon('G36C_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/G36C/U_G36C'),
		Weapon('G36C_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/G36C/U_G36C'),
		Weapon('HK53_RX01', 'XP1', {'RX01', 'HeavyBarrel', 'Foregrip', 'Weapons/XP1_HK53/U_HK53_CAMO_1'}, WeaponTypes.Carabine, 'Weapons/XP1_HK53/U_HK53'),
		Weapon('HK53_Kobra', 'XP1', {'Kobra', 'HeavyBarrel', 'Foregrip', 'Weapons/XP1_HK53/U_HK53_CAMO_2'}, WeaponTypes.Carabine, 'Weapons/XP1_HK53/U_HK53'),
		Weapon('M4A1_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/M4A1/U_M4A1'),
		Weapon('M4A1_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/M4A1/U_M4A1'),
		Weapon('M4_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/M4A1/U_M4'),
		Weapon('M4_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/M4A1/U_M4'),
		Weapon('MTAR_RX01', 'XP2', {'RX_01', 'HeavyBarrel', 'Foregrip', 'Weapons/XP2_MTAR/U_MTAR_CAMO_1'}, WeaponTypes.Carabine, 'Weapons/XP2_MTAR/U_MTAR'),
		Weapon('MTAR_Kobra', 'XP2', {'Kobra', 'HeavyBarrel', 'Foregrip', 'Weapons/XP2_MTAR/U_MTAR_CAMO_2'}, WeaponTypes.Carabine, 'Weapons/XP2_MTAR/U_MTAR'),
		Weapon('QBZ-95B_Kobra', 'XP1', {'Kobra', 'HeavyBarrel', 'TargetPointer'}, WeaponTypes.Carabine, 'Weapons/XP1_QBZ-95B/U_QBZ-95B'),
		Weapon('QBZ-95B_RX01', 'XP1', {'RX01', 'HeavyBarrel', 'TargetPointer'}, WeaponTypes.Carabine, 'Weapons/XP1_QBZ-95B/U_QBZ-95B'),
		Weapon('SCAR-H_EOTech', '', {'EOTech', 'HeavyBarrel','Foregrip', 'Weapons/SCAR-H/U_SCAR-H_CAMO_DSRTTIGER'}, WeaponTypes.Carabine, 'Weapons/SCAR-H/U_SCAR-H'),
		Weapon('SCAR-H_Kobra', '', {'Kobra', 'HeavyBarrel','Foregrip', 'Weapons/SCAR-H/U_SCAR-H_CAMO_BERKUT'}, WeaponTypes.Carabine, 'Weapons/SCAR-H/U_SCAR-H'),
		Weapon('SG553LB_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/SG553LB/U_SG553LB'),
		Weapon('SG553LB_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'}, WeaponTypes.Carabine, 'Weapons/SG553LB/U_SG553LB'),

		---------------------------
		--LMG

		Weapon('L86_RX01', 'XP2', {'RX01', 'HeavyBarrel', 'Foregrip'},WeaponTypes.LMG, 'Weapons/XP2_L86/U_L86'),
		Weapon('L86_Kobra', 'XP2', {'Kobra', 'HeavyBarrel', 'Foregrip'},WeaponTypes.LMG, 'Weapons/XP2_L86/U_L86'),
		Weapon('LSAT_RX01', 'XP2', {'RX01', 'ExtendedMag', 'Foregrip', 'Weapons/XP2_LSAT/U_LSAT_CAMO_1'},WeaponTypes.LMG, 'Weapons/XP2_LSAT/U_LSAT'),
		Weapon('LSAT_Kobra', 'XP2', {'Kobra', 'ExtendedMag', 'Foregrip', 'Weapons/XP2_LSAT/U_LSAT_CAMO_2'},WeaponTypes.LMG, 'Weapons/XP2_LSAT/U_LSAT'),
		Weapon('M249_RX01', '', {'RX01', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG, 'Weapons/M249/U_M249'),
		Weapon('M249_Kobra', '', {'Kobra', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG, 'Weapons/M249/U_M249'),
		Weapon('M27IAR_RX01', '', {'RX01', 'HeavyBarrel', 'Foregrip'},WeaponTypes.LMG, 'Weapons/M27IAR/U_M27IAR'),
		Weapon('M27IAR_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'},WeaponTypes.LMG, 'Weapons/M27IAR/U_M27IAR'),
		Weapon('M60_EOTech', '', {'EOTech', 'Foregrip', 'TargetPointer'}, WeaponTypes.LMG, 'Weapons/M60/U_M60'),
		Weapon('M60_Kobra', '', {'Kobra', 'Foregrip', 'TargetPointer'}, WeaponTypes.LMG, 'Weapons/M60/U_M60'),
		Weapon('MG36_RX01', 'XP1', {'RX01', 'Foregrip', 'HeavyBarrel'}, WeaponTypes.LMG, 'Weapons/XP1_MG36/U_MG36'),
		Weapon('MG36_Kobra', 'XP1', {'Kobra', 'Foregrip', 'HeavyBarrel'}, WeaponTypes.LMG, 'Weapons/XP1_MG36/U_MG36'),
		Weapon('Pecheneg_Kobra', '', {'Kobra', 'Foregrip', 'ExtendedMag', 'Weapons/Pecheneg/U_Peceheneg_Camo_KAMYSH'},WeaponTypes.LMG, 'Weapons/Pecheneg/U_Pecheneg'),
		Weapon('Pecheneg_RX01', '', {'RX01', 'Foregrip', 'ExtendedMag', 'Weapons/Pecheneg/U_Peceheneg_Camo_ATACS'},WeaponTypes.LMG, 'Weapons/Pecheneg/U_Pecheneg'),
		Weapon('QBB-95_Kobra', 'XP1', {'Kobra', 'Foregrip', 'HeavyBarrel', 'Weapons/XP1_QBB-95/U_QBB-95_CAMO_2'},WeaponTypes.LMG, 'Weapons/XP1_QBB-95/U_QBB-95'),
		Weapon('QBB-95_RX01', 'XP1', {'RX01', 'Foregrip', 'HeavyBarrel', 'Weapons/XP1_QBB-95/U_QBB-95_CAMO_1'},WeaponTypes.LMG, 'Weapons/XP1_QBB-95/U_QBB-95'),
		Weapon('Type88_Kobra', '', {'Kobra', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG, 'Weapons/Type88/U_Type88'),
		Weapon('Type88_RX01', '', {'RX01', 'ExtendedMag', 'Foregrip'},WeaponTypes.LMG, 'Weapons/Type88/U_Type88'),
		Weapon('RPK_Kobra', '', {'Kobra', 'HeavyBarrel', 'Foregrip'},WeaponTypes.LMG, 'Weapons/RPK/U_RPK-74M'),
		Weapon('RPK_RXO1', '', {'RXO1', 'HeavyBarrel', 'Foregrip'},WeaponTypes.LMG, 'Weapons/RPK/U_RPK-74M'),
		Weapon('M240_RX01', '', {'RX01', 'ExtendedMag', 'Foregrip', 'Weapons/M240/U_M240_CAMO_1'}, WeaponTypes.LMG, 'Weapons/M240/U_M240'),
		Weapon('M240_Kobra', '', {'Kobra', 'ExtendedMag', 'Foregrip', 'Weapons/M240/U_M240_CAMO_2'}, WeaponTypes.LMG, 'Weapons/M240/U_M240'),

		---------------------------
		-- Sniper

		Weapon('JNG90_Kobra', 'XP2', {'Kobra', 'StraightPull', 'Target_Pointer', 'Weapons/XP2_JNG90/U_JNG90_CAMO_2'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90'),
		Weapon('JNG90_PSO-1', 'XP2', {'PSO-1', 'StraightPull', 'Target_Pointer', 'Weapons/XP2_JNG90/U_JNG90_CAMO_2'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90'),
		Weapon('JNG90_RifleScope', 'XP2', {'Rifle_Scope', 'StraightPull', 'Target_Pointer', 'Weapons/XP2_JNG90/U_JNG90_CAMO_1'}, WeaponTypes.Sniper, 'Weapons/XP2_JNG90/U_JNG90'),
		Weapon('L96_EOTech', 'XP1', {'EOTech', 'StraightPull', 'TargetPointer', 'Weapons/XP1_L96/U_L96_CAMO_ABU'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96'),
		Weapon('L96_Acog', 'XP1', {'Acog', 'StraightPull', 'TargetPointer', 'Weapons/XP1_L96/U_L96_CAMO_ABU'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96'),
		Weapon('L96_RifleScope', 'XP1', {'Rifle_Scope', 'StraightPull', 'TargetPointer', 'Weapons/XP1_L96/U_L96_CAMO_DIGIFLORA'}, WeaponTypes.Sniper, 'Weapons/XP1_L96/U_L96'),
		Weapon('M98B_EOTech', '', {'EOTech', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B'),
		Weapon('M98B_Acog', '', {'Acog', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B'),
		Weapon('M98B_RifleScope', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/Model98B/U_M98B'),
		Weapon('M40A5_EOTech', '', {'EOTech', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5'),
		Weapon('M40A5_Acog', '', {'Acog', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5'),
		Weapon('M40A5_RifleScope', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/M40A5/U_M40A5'),
		Weapon('SV98_Kobra', '', {'Kobra', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SV98/U_SV98'),
		Weapon('SV98_PSO-1', '', {'PSO-1', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SV98/U_SV98'),
		Weapon('SV98_RifleScope', '', {'Rifle_Scope', 'StraightPull', 'Target_Pointer'}, WeaponTypes.Sniper, 'Weapons/SV98/U_SV98'),
		Weapon('M39EBR_EOTech', '', {'EOTech', 'Target_pointer', 'Flashsuppressor', 'Weapons/M39EBR/U_M39EBR_CAMO_1'}, WeaponTypes.Sniper, 'Weapons/M39EBR/U_M39EBR'),
		Weapon('M39EBR_Acog', '', {'Acog', 'Target_pointer', 'Flashsuppressor', 'Weapons/M39EBR/U_M39EBR_CAMO_1'}, WeaponTypes.Sniper, 'Weapons/M39EBR/U_M39EBR'),
		Weapon('M39EBR_RifleScope', '', {'Rifle_Scope', 'Target_pointer', 'Flashsuppressor', 'Weapons/M39EBR/U_M39EBR_CAMO_2'}, WeaponTypes.Sniper, 'Weapons/M39EBR/U_M39EBR'),
		Weapon('HK417_EOTech', 'XP2', {'EOTech', 'Target_pointer', 'HeavyBarrel'}, WeaponTypes.Sniper, 'Weapons/XP2_HK417/U_HK417'),
		Weapon('HK417_Acog', 'XP2', {'Acog', 'Target_pointer', 'HeavyBarrel'}, WeaponTypes.Sniper, 'Weapons/XP2_HK417/U_HK417'),
		Weapon('HK417_RifleScope', 'XP2', {'Rifle_Scope', 'Target_pointer', 'HeavyBarrel'}, WeaponTypes.Sniper, 'Weapons/XP2_HK417/U_HK417'),
		Weapon('MK11_EOTech', '', {'EOTech', 'Target_pointer', 'Flashsuppressor'}, WeaponTypes.Sniper, 'Weapons/MK11/U_MK11'),
		Weapon('MK11_Acog', '', {'Acog', 'Target_pointer', 'Flashsuppressor'}, WeaponTypes.Sniper, 'Weapons/MK11/U_MK11'),
		Weapon('MK11_RifleScope', '', {'Rifle_Scope', 'Target_pointer', 'Flashsuppressor'}, WeaponTypes.Sniper, 'Weapons/MK11/U_MK11'),
		Weapon('SKS_Kobra', '', {'Kobra', 'Target_pointer', 'Heavy_Barrel', 'Weapons/SKS/U_SKS_CAMO_2'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS'),
		Weapon('SKS_PSO-1', '', {'PSO-1', 'Target_pointer', 'Heavy_Barrel', 'Weapons/SKS/U_SKS_CAMO_2'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS'),
		Weapon('SKS_RifleScope', '', {'Rifle_Scope', 'Target_pointer', 'Heavy_Barrel', 'Weapons/SKS/U_SKS_CAMO_1'}, WeaponTypes.Sniper, 'Weapons/SKS/U_SKS'),
		Weapon('SVD_Kobra', '', {'Kobra', 'Target_pointer', 'Flashsuppressor'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD'),
		Weapon('SVD_PSO-1', '', {'PSO-1', 'Target_pointer', 'Flashsuppressor'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD'),
		Weapon('SVD_RifleScope', '', {'Rifle_Scope', 'Target_pointer', 'Flashsuppressor'}, WeaponTypes.Sniper, 'Weapons/SVD/U_SVD'),

		---------------------------
		-- pistols

		Weapon('Glock17', '', {}, WeaponTypes.Pistol, 'Weapons/Glock17/U_Glock17'),
		Weapon('Glock17_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/Glock17/U_Glock17_Silenced'),
		Weapon('Glock18', '', {}, WeaponTypes.Pistol, 'Weapons/Glock18/U_Glock18'),
		Weapon('Glock18_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/Glock18/U_Glock18_Silenced'),
		Weapon('M1911_Lit', '', {}, WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Lit'),
		Weapon('M1911_Silenced', '', {},WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Silenced'),
		Weapon('M1911_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/M1911/U_M1911_Tactical'),
		Weapon('M9', '', {}, WeaponTypes.Pistol, 'Weapons/M9/U_M9'),
		Weapon('M9_Silenced', '', {},WeaponTypes.Pistol, 'Weapons/M9/U_M9_Silenced'),
		Weapon('M9_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/M9/U_M9_TacticalLight'),
		Weapon('M93R', '', {}, WeaponTypes.Pistol, 'Weapons/M93R/U_M93R'),
		Weapon('MP412Rex', '', {}, WeaponTypes.Pistol, 'Weapons/MP412Rex/U_MP412Rex'),
		Weapon('Taurus44', '', {}, WeaponTypes.Pistol, 'Weapons/Taurus44/U_Taurus44'),
		Weapon('Taurus44_Scoped', '', {}, WeaponTypes.Pistol, 'Weapons/Taurus44/U_Taurus44_Scoped'),
		Weapon('MP443', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443'),
		Weapon('MP443_Tactical', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443_TacticalLight'),
		Weapon('MP443_Silenced', '', {}, WeaponTypes.Pistol, 'Weapons/MP443/U_MP443_Silenced'),

		---------------------------
		-- knifes

		Weapon('Razor', '', {}, WeaponTypes.Knife, 'Weapons/XP2_Knife_RazorBlade/U_Knife_Razor'),
		Weapon('Knife', '', {}, WeaponTypes.Knife),

		---------------------------
		-- Sidearms

		-- only rockets supported for engineers right now
		Weapon('SMAW', '', {}, WeaponTypes.Rocket),
		-- only rockets supported for engineers right now
		Weapon('RPG7', '', {}, WeaponTypes.Rocket),
		Weapon('Repairtool', '', {}, WeaponTypes.Torch, 'Weapons/Gadgets/Repairtool/U_Repairtool'),
		Weapon('Defib', '', {}, WeaponTypes.Defibrillator, 'Weapons/Gadgets/Defibrillator/U_Defib'),
		Weapon('Medkit', '', {}, WeaponTypes.Medkit, 'Weapons/Gadgets/Medicbag/U_Medkit'),
		Weapon('Ammobag', '', {}, WeaponTypes.Ammobag, 'Weapons/Gadgets/Ammobag/U_Ammobag'),
		Weapon('Claymore', '', {}, WeaponTypes.Claymore, 'Weapons/Gadgets/Claymore/U_Claymore'),
		Weapon('C4', '', {}, WeaponTypes.C4, 'Weapons/Gadgets/C4/U_C4'),
		Weapon('Tug', '', {}, WeaponTypes.Tugs, 'Weapons/Gadgets/T-UGS/U_UGS'),
		Weapon('Beacon', '', {}, WeaponTypes.Beacon, 'Weapons/Gadgets/RadioBeacon/U_RadioBeacon'),
		Weapon('M67', '', {}, WeaponTypes.Grenade)
	}

	self:updateWeaponList()
end

function WeaponList:_isCustomWeapon(p_Class, p_Name, p_Team)
	local s_CustomWeaponList = nil
	local s_IsCustomWeapon = false

	if p_Team == "US" then
		if p_Class == BotKits.Assault then
			s_CustomWeaponList = CustomWeaponsAssaultUs
		elseif p_Class == BotKits.Engineer then
			s_CustomWeaponList = CustomWeaponsEngineerUs
		elseif p_Class == BotKits.Support then
			s_CustomWeaponList = CustomWeaponsSupportUs
		elseif p_Class == BotKits.Recon then
			s_CustomWeaponList = CustomWeaponsReconUs
		end
	else
		if p_Class == BotKits.Assault then
			s_CustomWeaponList = CustomWeaponsAssaultRu
		elseif p_Class == BotKits.Engineer then
			s_CustomWeaponList = CustomWeaponsEngineerRu
		elseif p_Class == BotKits.Support then
			s_CustomWeaponList = CustomWeaponsSupportRu
		elseif p_Class == BotKits.Recon then
			s_CustomWeaponList = CustomWeaponsReconRu
		end
	end

	for _, l_CustomName in pairs(s_CustomWeaponList) do
		if l_CustomName == p_Name or string.find(p_Name, l_CustomName.."_") ~= nil then -- use all fitting weapon-variants of this type
			s_IsCustomWeapon = true
			break
		end
	end

	return s_IsCustomWeapon
end

function WeaponList:_useWeaponType(p_Class, p_Type, p_Name, p_Team)
	local s_UseThisWeapon = false
	local s_IsClassWeapon = false
	local s_WeaponSet = ""

	if p_Class == BotKits.Assault then
		s_WeaponSet = Config.AssaultWeaponSet

		if p_Type == WeaponTypes.Assault then
			s_IsClassWeapon = true
		end
	elseif p_Class == BotKits.Engineer then
		s_WeaponSet = Config.EngineerWeaponSet

		if p_Type == WeaponTypes.Carabine then
			s_IsClassWeapon = true
		end
	elseif p_Class == BotKits.Support then
		s_WeaponSet = Config.SupportWeaponSet

		if p_Type == WeaponTypes.LMG then
			s_IsClassWeapon = true
		end
	else --if p_Class == BotKits.Recon then
		s_WeaponSet = Config.ReconWeaponSet

		if p_Type == WeaponTypes.Sniper then
			s_IsClassWeapon = true
		end
	end

	-- check for custom-weapon
	if s_WeaponSet == WeaponSets.Custom then
		s_UseThisWeapon = self:_isCustomWeapon(p_Class, p_Name, p_Team)
	else -- check for other p_Classes
		if p_Type == WeaponTypes.PDW then
			if s_WeaponSet == WeaponSets.PDW or
			s_WeaponSet == WeaponSets.Class_PDW or
			s_WeaponSet == WeaponSets.Class_PDW_Shotgun or
			s_WeaponSet == WeaponSets.PDW_Shotgun then
				s_UseThisWeapon = true
			end
		elseif p_Type == WeaponTypes.Shotgun then
			if s_WeaponSet == WeaponSets.Shotgun or
			s_WeaponSet == WeaponSets.Class_Shotgun or
			s_WeaponSet == WeaponSets.Class_PDW_Shotgun or
			s_WeaponSet == WeaponSets.PDW_Shotgun then
				s_UseThisWeapon = true
			end
		elseif p_Type == WeaponTypes.Assault or p_Type == WeaponTypes.Carabine or p_Type == WeaponTypes.LMG or p_Type == WeaponTypes.Sniper then
			if s_WeaponSet == WeaponSets.Class or
			s_WeaponSet == WeaponSets.Class_Shotgun or
			s_WeaponSet == WeaponSets.Class_PDW_Shotgun or
			s_WeaponSet == WeaponSets.Class_PDW then
				if s_IsClassWeapon then
					s_UseThisWeapon = true
				end
			end
		else
			-- for all other weapons - use p_Class-list
			s_UseThisWeapon = self:_isCustomWeapon(p_Class, p_Name, p_Team)
		end
	end

	return s_UseThisWeapon
end

function WeaponList:_insertWeapon(p_Kit, p_WeaponType, p_WeaponName, p_Team)
	local s_BotWeaponType = nil
	-- translate type to BotWeapon
	if p_WeaponType == WeaponTypes.Assault or
	p_WeaponType == WeaponTypes.Carabine or
	p_WeaponType == WeaponTypes.LMG or
	p_WeaponType == WeaponTypes.Sniper or
	p_WeaponType == WeaponTypes.Shotgun or
	p_WeaponType == WeaponTypes.PDW then
		s_BotWeaponType = BotWeapons.Primary
	elseif p_WeaponType == WeaponTypes.Pistol then
		s_BotWeaponType = BotWeapons.Pistol
	elseif p_WeaponType == WeaponTypes.Medkit or
	p_WeaponType == WeaponTypes.Torch or
	p_WeaponType == WeaponTypes.Ammobag or
	p_WeaponType == WeaponTypes.Tugs then
		s_BotWeaponType = BotWeapons.Gadget1
	elseif p_WeaponType == WeaponTypes.Defibrillator or
	p_WeaponType == WeaponTypes.Rocket or
	p_WeaponType == WeaponTypes.Claymore or
	p_WeaponType == WeaponTypes.C4 or
	p_WeaponType == WeaponTypes.Beacon then
		s_BotWeaponType = BotWeapons.Gadget2
	elseif p_WeaponType == WeaponTypes.Grenade then
		s_BotWeaponType = BotWeapons.Grenade
	elseif p_WeaponType == WeaponTypes.Knife then
		s_BotWeaponType = BotWeapons.Knife
	end

	if s_BotWeaponType ~= nil then
		table.insert(Weapons[p_Kit][s_BotWeaponType][p_Team], p_WeaponName)
	end

	if s_BotWeaponType == BotWeapons.Primary then
		if p_Kit == BotKits.Assault then
			table.insert(AssaultPrimary, p_WeaponName)
		elseif p_Kit == BotKits.Engineer then
			table.insert(EngineerPrimary, p_WeaponName)
		elseif p_Kit == BotKits.Support then
			table.insert(SupportPrimary, p_WeaponName)
		else
			table.insert(ReconPrimary, p_WeaponName)
		end
	end
end


function WeaponList:updateWeaponList()
	AllWeapons = {}
	KnifeWeapons = {}
	PistoWeapons = {}
	AssaultPrimary = {}
	EngineerPrimary = {}
	SupportPrimary = {}
	ReconPrimary = {}

	Weapons = {}
	-- clear-weapons-table
	for l_Key, l_Value in pairs(BotKits) do
		if l_Value ~= BotKits.Count and l_Value ~= BotKits.RANDOM_KIT then
			Weapons[l_Value] = {}
		end
	end
	for l_Class,_ in pairs(Weapons) do
		local s_TempTable = {}
		for l_key, l_Value in pairs(BotWeapons) do
			if l_Value ~= BotWeapons.Auto then
				s_TempTable[l_Value] = {}
			end
		end

		for l_Weapon,_ in pairs(s_TempTable) do
			s_TempTable[l_Weapon] = {
				US = {},
				RU = {}
			}
		end
		Weapons[l_Class] = s_TempTable
	end

	for i = 1, #self._weapons do
		local s_Wep = self._weapons[i]
		table.insert(AllWeapons, s_Wep.name)

		if (s_Wep.type == WeaponTypes.Knife) then
			table.insert(KnifeWeapons, s_Wep.name)
		elseif (s_Wep.type == WeaponTypes.Pistol) then
			table.insert(PistoWeapons, s_Wep.name)
		end

		for _, l_BotKit in pairs(BotKits) do
			if l_BotKit ~= BotKits.Count and l_BotKit ~= BotKits.RANDOM_KIT then
				if self:_useWeaponType(l_BotKit, s_Wep.type, s_Wep.name, "US") then
					self:_insertWeapon(l_BotKit, s_Wep.type, s_Wep.name, "US")
				end
				if self:_useWeaponType(l_BotKit, s_Wep.type, s_Wep.name, "RU") then
					self:_insertWeapon(l_BotKit, s_Wep.type, s_Wep.name, "RU")
				end
			end
		end
	end
end

function WeaponList:getWeapon(p_Name)
	local s_RetWeapon = nil
	local s_AllPossibleWeapons = {}
	if p_Name == nil then
		m_Logger:Warning('Invalid Parameter')
		return nil
	end
	for _, l_Weapon in pairs(self._weapons) do
		if string.find(l_Weapon.name, p_Name.."_") ~= nil then -- check for weapon-variant
			table.insert(s_AllPossibleWeapons, l_Weapon)
		end
		if l_Weapon.name == p_Name then
			s_RetWeapon = l_Weapon
			break
		end
	end

	if s_RetWeapon ~= nil then
		return s_RetWeapon
	elseif #s_AllPossibleWeapons > 0 then
		return s_AllPossibleWeapons[MathUtils:GetRandomInt(1, #s_AllPossibleWeapons)]
	else
		m_Logger:Warning('Weapon not found: '..tostring(p_Name))
		return nil
	end
end

function WeaponList:onLevelLoaded()
	for _, l_Weapon in pairs(self._weapons) do
		if l_Weapon.needvalues then
			l_Weapon:learnStatsValues()
		end
	end
end

if g_WeaponList == nil then
	---@type WeaponList
	g_WeaponList = WeaponList()
end

return g_WeaponList
