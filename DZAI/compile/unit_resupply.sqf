/*
	unit_resupply
	
	Credits:  Basic script concept adapted from Sarge AI.
	
	Description: Handles AI ammo reload, self-healing, zombie hostility. Called by fnc_createGroup upon AI unit creation.
	
	Last updated: 12:49 AM 11/19/2013
*/
private["_unit","_currentWeapon","_weaponMagazine","_needsReload","_nearbyZeds","_marker","_markername","_lastBandage","_bandages","_unitGroup","_needsHeal","_weapongrade","_unitWeapons","_unitMagazines"];
if (!isServer) exitWith {};
if (DZAI_debugLevel > 1) then {diag_log "DZAI Extended Debug: AI resupply script active.";};

_unit = _this select 0;								//Unit to monitor/reload ammo
_weapongrade = if ((count _this) > 1) then {_this select 1} else {0};

if (_unit getVariable ["rearmEnabled",false]) exitWith {};
_unit setVariable ["rearmEnabled",true];

//Initialize medical variables
if (isNil {_unit getVariable "unithealth"}) then {_unit setVariable ["unithealth",[12000,0,0,false,false]]};
if (isNil {_unit getVariable "unconscious"}) then {_unit setVariable ["unconscious",false]};

_lastBandage = 0;
_bandages = ((_weapongrade + 1) min 3);
_needsHeal = false;

_currentWeapon = currentWeapon _unit;									//Retrieve unit's current weapon
waitUntil {sleep 0.1; !isNil "_currentWeapon"};
_weaponMagazine = (getArray (configFile >> "CfgWeapons" >> _currentWeapon >> "magazines") select 0);	//Retrieve ammo used by unit's current weapon
waitUntil {sleep 0.1; !isNil "_weaponMagazine"};
_unitWeapons = [_currentWeapon]; _currentWeapon = nil;
_unitMagazines = [_weaponMagazine]; _weaponMagazine = nil;

_unitGroup = (group _unit);

if ((((units _unitGroup) select 0) == _unit) && (_weapongrade in DZAI_launcherLevels) && ((count DZAI_launcherTypes) > 0)) then {
	private ["_launchWeapon","_launchAmmo"];
	_launchWeapon = DZAI_launcherTypes call BIS_fnc_selectRandom2;
	_launchAmmo = getArray (configFile >> "CfgWeapons" >> _launchWeapon >> "magazines") select 0;
	_unit addWeapon _launchWeapon; _unitWeapons set [1,_launchWeapon];
	_unit addMagazine _launchAmmo; _unitMagazines set [1,_launchAmmo];
};

while {(alive _unit)&&(!(isNull _unit))} do {	
	if (DZAI_zombieEnemy && ((leader _unitGroup) == _unit)) then {
		_nearbyZeds = (getPosATL _unit) nearEntities ["zZombie_Base",DZAI_zDetectRange];
		{
			if (rating _x > -30000) then {
                _x addrating -30000;
            };
			if ((_unit knowsAbout _x) < 1.5) then {
				_unitGroup reveal [_x,4];
			};
		} forEach _nearbyZeds;
		if (DZAI_passiveAggro) then {
			if ((count _nearbyZeds) > 0) then {_nul = [_unit,75,false,(getPosATL _unit)] spawn ai_alertzombies;};
		};
	};
	if !(_unit getVariable ["unconscious",false]) then {
		for "_i" from 0 to ((count _unitWeapons) -1) do {
			private ["_needsReload"];
			_needsReload = true;
			if ((_unitMagazines select _i) in magazines _unit) then {						//If unit already has at least one magazine, assume reload is not needed
				_needsReload = false;
			}; 
			if ((_unit ammo (_unitWeapons select _i) == 0) || (_needsReload))  then {		//If active weapon has no ammunition, or AI has no magazines, remove empty magazines and add a new magazine.
				_unit removeMagazines (_unitMagazines select _i);
				_unit addMagazine (_unitMagazines select _i);
				if (DZAI_debugLevel > 1) then {diag_log format ["DZAI Extended Debug: AI ammo depleted, added magazine %1 to AI %2.",(_unitMagazines select _i),_unit];};
			};
		};
		if (_bandages > 0) then {
			private ["_health"];
			_health = _unit getVariable "unithealth";
			if (_needsHeal) then {
				private ["_healTimes"];
				_bandages = _bandages - 1;
				_unit disableAI "TARGET"; _unit disableAI "AUTOTARGET"; _unit disableAI "MOVE";
				_unit playActionNow "Medic";
				_healTimes = 0;
				while {(!(_unit getVariable ["unconscious",false]))&&(_healTimes < 3)&&(alive _unit)} do {
					sleep 2;
					_health set [0,(((_health select 0) + 2000) min 12000)];
					_healTimes = _healTimes + 1;
					if ((_healTimes == 3)&&(alive _unit)) then {
						_health set [1,0];
						_health set [2,0];
						_health set [3,false];
						_health set [4,false];
						_unit setDamage 0;
					};
				};
				
				_unit enableAI "TARGET"; _unit enableAI "AUTOTARGET"; _unit enableAI "MOVE";
				_lastBandage = time;
				_needsHeal = false;
			} else {
				private ["_lowblood","_brokenbones"];
				_lowblood = ((_health select 0) < 7200);
				_brokenbones = ((_health select 3) or (_health select 4));
				if ((_lowblood or _brokenbones) && (time - _lastBandage) > 60) then {
					_needsHeal = true;
				};
			};
		};
	};
	sleep DZAI_refreshRate;										//Check again in x seconds.
};
sleep 0.5;
if (DZAI_debugLevel > 1) then {diag_log "DZAI Extended Debug: AI resupply script deactivated.";};
