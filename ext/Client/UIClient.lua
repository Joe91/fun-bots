class 'FunBotUIClient';

require('UIViews');
require('UISettings');


Language = require('__shared/Language');

function FunBotUIClient:__init()
	self._views = UIViews();
	self.WaypointEditorTimer = -1
	self.WaypointEditorDelay = 0.25
	
	if Config.disableUserInterface ~= true then
		Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput);
		Events:Subscribe('Engine:Update', self, self._onEngineUpdate)
		
		NetEvents:Subscribe('UI_Password_Protection', self, self._onUIPasswordProtection);
		NetEvents:Subscribe('UI_Request_Password', self, self._onUIRequestPassword);
		NetEvents:Subscribe('UI_Request_Password_Error', self, self._onUIRequestPasswordError);
		Events:Subscribe('UI_Send_Password', self, self._onUISendPassword);
		NetEvents:Subscribe('UI_Toggle', self, self._onUIToggle);
		Events:Subscribe('UI_Toggle', self, self._onUIToggle);
		NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent);
		Events:Subscribe('BotEditor', self, self._onBotEditorEvent);
		NetEvents:Subscribe('UI_Show_Toolbar', self, self._onUIShowToolbar);
		NetEvents:Subscribe('UI_Settings', self, self._onUISettings);
		NetEvents:Subscribe('UI_CommonRose', self, self._onUICommonRose);
		Events:Subscribe('UI_Settings', self, self._onUISettings);
		Events:Subscribe('UI_Save_Settings', self, self._onUISaveSettings);
		NetEvents:Subscribe('UI_Change_Language', self, self._onUIChangeLanguage);
		Events:Subscribe('UI_Change_Language', self, self._onUIChangeLanguage);
		
		NetEvents:Subscribe('UI_Waypoints_Editor', self, self._onUIWaypointsEditor);
		Events:Subscribe('UI_Waypoints_Editor', self, self._onUIWaypointsEditor);
		NetEvents:Subscribe('UI_Trace', self, self._onUITrace);
		Events:Subscribe('UI_Trace', self, self._onUITrace);
		NetEvents:Subscribe('UI_Trace_Index', self, self._onUITraceIndex);
		Events:Subscribe('UI_Trace_Index', self, self._onUITraceIndex);
		NetEvents:Subscribe('UI_Trace_Waypoints', self, self._onUITraceWaypoints);
		Events:Subscribe('UI_Trace_Waypoints', self, self._onUITraceWaypoints);
		
		self._views:setLanguage(Config.language);
	end
end

-- Events
function FunBotUIClient:_onUIToggle()
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Toggle');

	self._views:execute('BotEditor.Hide();');
	self._views:disable();
	--if self._views:isVisible() then
	--	self._views:close();
	--else
	--	self._views:open();
	--	self._views:focus();
	--end
end

function FunBotUIClient:_onUICommonRose(data)
	if data == "false" then
		self._views:execute('BotEditor.setCommonRose(false);');
		--self._views:blur();
		return;
	end
	
	self._views:execute('BotEditor.setCommonRose(\'' .. json.encode(data) .. '\');');
	--self._views:focus();
end

function FunBotUIClient:_onUIWaypointsEditor(state)
	if Config.disableUserInterface == true then
		return;
	end
	
	if state == false then
		print('UIClient: close UI_Waypoints_Editor');
		self._views:hide('waypoint_toolbar');
		self._views:show('toolbar');
		Config.debugTracePaths = false;
		NetEvents:Send('UI_CommoRose_Toggle', false);
		-- @ToDo enable built-in CommonRose from BF3
		return;
	end
	
	print('UIClient: open UI_Waypoints_Editor');
	Config.debugTracePaths = true;
	-- @ToDo disable built-in CommonRose from BF3
	NetEvents:Send('UI_CommoRose_Toggle', true);
	self._views:show('waypoint_toolbar');
	self._views:hide('toolbar');
	self._views:disable();
end

function FunBotUIClient:_onUITraceIndex(index)
	if Config.disableUserInterface == true then
		return;
	end
	
	self._views:execute('BotEditor.updateTraceIndex(' .. tostring(index) .. ');');
end

function FunBotUIClient:_onUITraceWaypoints(count)
	if Config.disableUserInterface == true then
		return;
	end
	
	self._views:execute('BotEditor.updateTraceWaypoints(' .. tostring(count) .. ');');
end

function FunBotUIClient:_onUITraceWaypointsDistance(distance)
	if Config.disableUserInterface == true then
		return;
	end
	
	self._views:execute('BotEditor.updateTraceWaypointsDistance(' .. string.format('%4.2f', distance) .. ');');
end

function FunBotUIClient:_onUITrace(state)
	if Config.disableUserInterface == true then
		return;
	end
	
	self._views:execute('BotEditor.toggleTraceRun(' .. tostring(state) .. ');');
	self._views:disable();
end

function FunBotUIClient:_onUISettings(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	if data == false then
		print('UIClient: close UI_Settings');
		self._views:hide('settings');
		--self._views:blur();
		return;
	end

	print('UIClient: UI_Settings (' .. json.encode(data) .. ')');

	local settings = UISettings();

	-- Samples
	-- add(<category>, <types>, <name>, <title>, <value>, <default>, <description>)
	-- addList(<category>, <name>, <title>, <list>, <value>, <default>, <description>)

	settings:addList("GLOBAL", "botWeapon", Language:I18N("Bot Weapon"), BotWeapons, data.botWeapon, "Primary", Language:I18N("Select the weapon the bots use"));
	settings:addList("GLOBAL", "botKit", Language:I18N("Bot Kit"), BotKits, data.botKit, "RANDOM_KIT", Language:I18N("The Kit a bots spawns with."));
	settings:addList("GLOBAL", "botColor", Language:I18N("Bot Color"), BotColors, data.botColor, "RANDOM_COLOR", Language:I18N("The Kit-Color a bots spawns with."));
	settings:add("GLOBAL", "Boolean", "zombieMode", Language:I18N("Zombie Mode"), data.zombieMode, false, Language:I18N("Bots act like zombies"));

	settings:add("DIFFICULTY", "Float", "botAimWorsening", Language:I18N("Aim Worsening"), data.botAimWorsening, 0.6, Language:I18N("0 = hard, 1 (or higher) = easy"));
	settings:add("DIFFICULTY", "Float", "botSniperAimWorsening", Language:I18N("Aim Worsening Sniper"), data.botSniperAimWorsening, 0.2, Language:I18N("0 = hard, 1 (or higher) = easy"));
	settings:add("DIFFICULTY", "Float", "damageFactorAssault", Language:I18N("Factor for Assault-Weapon-Damage"), data.damageFactorAssault, 0.5, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorCarabine", Language:I18N("Factor for Carabine-Weapon-Damage"), data.damageFactorCarabine, 0.5, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorPDW", Language:I18N("Factor for PDW-Weapon-Damage"), data.damageFactorPDW, 0.5, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorLMG", Language:I18N("Factor for LMG-Weapon-Damage"), data.damageFactorLMG, 0.5, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorSniper", Language:I18N("Factor for Sniper-Weapon-Damage"), data.damageFactorSniper, 0.8, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorShotgun", Language:I18N("Factor for Shotgun-Weapon-Damage"), data.damageFactorShotgun, 0.5, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorPistol", Language:I18N("Factor for Pistol-Weapon-Damage"), data.damageFactorPistol, 0.8, Language:I18N("Origninal Damage from bots gets multiplied by this"));
	settings:add("DIFFICULTY", "Float", "damageFactorKnife", Language:I18N("Factor for Knife-Weapon-Damage"), data.damageFactorKnife, 1.2, Language:I18N("Origninal Damage from bots gets multiplied by this"));

	settings:addList("SPAWN", "spawnMode", Language:I18N("Spawn Mode"), SpawnModes, data.spawnMode, "increment_with_players", Language:I18N("Mode the bots spawn with"));
	settings:add("SPAWN", "Boolean", "spawnInBothTeams", Language:I18N("Spawn in both teams"), data.spawnInBothTeams, true, Language:I18N("Bots spawn in both teams"));
	settings:add("SPAWN", "Integer", "initNumberOfBots", Language:I18N("Number of Bots for Spawn-Mode"), data.initNumberOfBots, 5, Language:I18N("Bots for the spawnmode"));
	settings:add("SPAWN", "Integer", "newBotsPerNewPlayer", Language:I18N("Number Bots on new Player"), data.newBotsPerNewPlayer, 2, Language:I18N("number to increase Bots, when new players join, if mode is selected"));
	settings:add("SPAWN", "Float", "spawnDelayBots", Language:I18N("Respawn Delay"), data.spawnDelayBots, 10.0, Language:I18N("time till bots respawn, if respawn enabled"));
	settings:add("SPAWN", "Integer", "botTeam", Language:I18N("Default Bot Team"), data.botTeam, 0, Language:I18N("default bot team. 0 = auto, 1 = US (forced), 2 = RU (forced)"));
	settings:add("SPAWN", "Boolean", "botNewLoadoutOnSpawn", Language:I18N("New Loadout on Spawn"), data.botNewLoadoutOnSpawn, true, Language:I18N("bots get a new kit and color, if they respawn"));
	settings:add("SPAWN", "Integer", "maxAssaultBots", Language:I18N("Max Assault Bots"), data.maxAssaultBots, -1, Language:I18N("maximum number of Bots with Assault Kit. -1 = unlimited"));
	settings:add("SPAWN", "Integer", "maxEngineerBots", Language:I18N("Max Engineer Bots"), data.maxEngineerBots, -1, Language:I18N("maximum number of Bots with Engineer Kit. -1 = unlimited"));
	settings:add("SPAWN", "Integer", "maxSupportBots", Language:I18N("Max Support Bots"), data.maxSupportBots, -1, Language:I18N("maximum number of Bots with Support Kit. -1 = unlimited"));
	settings:add("SPAWN", "Integer", "maxReconBots", Language:I18N("Max Recon Bots"), data.maxReconBots, -1, Language:I18N("maximum number of Bots with Recon Kit. -1 = unlimited"));

	settings:add("WEAPONS", "Boolean", "useRandomWeapon", Language:I18N("Random Weapon"), data.useRandomWeapon, true, Language:I18N("use a random weapon out of the class list"));
	settings:addList("WEAPONS", "pistol", Language:I18N("Bot Pistol"), PistoWeapons, data.pistol, "M1911_Lit", Language:I18N("Pistol of Bots"));
	settings:addList("WEAPONS", "knife", Language:I18N("Bot Knife"), KnifeWeapons, data.knife, "Razor", Language:I18N("Knife of Bots"));
	settings:addList("WEAPONS", "assaultWeapon",  Language:I18N("Weapon Assault"), WeaponsAssault, data.assaultWeapon, "M416", Language:I18N("Weapon of Assault class"));
	settings:addList("WEAPONS", "engineerWeapon",  Language:I18N("Weapon Engineer"), WeaponsEngineer, data.engineerWeapon, "M4A1", Language:I18N("Weapon of Engineer class"));
	settings:addList("WEAPONS", "supportWeapon",  Language:I18N("Weapon Support"), WeaponsSupport, data.supportWeapon, "M249", Language:I18N("Weapon of Support class"));
	settings:addList("WEAPONS", "reconWeapon",  Language:I18N("Weapon Recon"), WeaponsRecon, data.reconWeapon, "L96_6x", Language:I18N("Weapon of Recon class"));
	settings:addList("WEAPONS", "assaultWeaponSet",  Language:I18N("Weaponset of Assault"), WeaponSets, data.assaultWeaponSet, "Class", Language:I18N("Weaponset of Assault class"));
	settings:addList("WEAPONS", "engineerWeaponSet",  Language:I18N("Weaponset Engineer"), WeaponSets, data.engineerWeaponSet, "Class_PDW", Language:I18N("Weaponset of Engineer class"));
	settings:addList("WEAPONS", "supportWeaponSet",  Language:I18N("Weaponset Support"), WeaponSets, data.supportWeaponSet, "Class_Shotgun", Language:I18N("Weaponset of Support class"));
	settings:addList("WEAPONS", "reconWeaponSet",  Language:I18N("Weaponset Recon"), WeaponSets, data.reconWeaponSet, "Class", Language:I18N("Weaponset of Recon class"));

	settings:add("BEHAVIOUR", "Integer", "fovForShooting", Language:I18N("Bot FOV"), data.fovForShooting, 200, Language:I18N("The Field Of View of the bots, where they can detect a player"));
	settings:add("BEHAVIOUR", "Integer", "maxRaycastDistance", Language:I18N("View Distance Bots"), data.maxRaycastDistance, 150, Language:I18N("The maximum distance a Sniper Bot starts shooting at a player"));
	settings:add("BEHAVIOUR", "Integer", "maxShootDistanceNoSniper", Language:I18N("Attack Distance no Sniper"), data.maxShootDistanceNoSniper, 70, Language:I18N("The maximum distance a non Sniper Bot starts shooting at a player"));
	settings:addList("BEHAVIOUR", "botAttackMode", Language:I18N("Bot Attack Mode"), BotAttackModes, data.botAttackMode, "Random", Language:I18N("Mode the Bots attack with. Crouch or Stand"));
	settings:add("BEHAVIOUR", "Boolean", "shootBackIfHit", Language:I18N("Attack if Hit"), data.shootBackIfHit, true, Language:I18N("Bots imidiatly attack player, if shot by it"));
	settings:add("BEHAVIOUR", "Boolean", "botsAttackBots", Language:I18N("Bots Attack Bots"), data.botsAttackBots, true, Language:I18N("Bots attack bots from other team"));
	settings:add("BEHAVIOUR", "Boolean", "meleeAttackIfClose", Language:I18N("Attack with Melee"), data.meleeAttackIfClose, true, Language:I18N("Bots attack the playe with the knife, if close"));
	settings:add("BEHAVIOUR", "Boolean", "botCanKillHimself", Language:I18N("Bots can kill themself"), data.botCanKillHimself, false, Language:I18N("If false, Bots take no fall or Frag damage"));

	settings:add("ADVANCED", "Float", "distanceForDirectAttack", Language:I18N("Direct Attack Distance"), data.distanceForDirectAttack, 5, Language:I18N("When this close to a bot, he starts attacking"));
	settings:add("ADVANCED", "Integer", "maxBotAttackBotDistance", Language:I18N("Distance Bot Bot attack"), data.maxBotAttackBotDistance, 30, Language:I18N("The maximum distance a Bot attacks an other Bot"));
	settings:add("ADVANCED", "Float", "meleeAttackCoolDown", Language:I18N("Melee Cooldown"), data.meleeAttackCoolDown, 3, Language:I18N("the time a Bot waits before attacking with melee again"));
	settings:add("ADVANCED", "Boolean", "aimForHead", Language:I18N("Aim for Head"), data.aimForHead, false, Language:I18N("Bots aim for the head. If false for the body"));
	settings:add("ADVANCED", "Boolean", "jumpWhileShooting", Language:I18N("Allow Jump while shooting"), data.jumpWhileShooting, true, Language:I18N("Bots jump over obstacles while shooting"));
	settings:add("ADVANCED", "Boolean", "jumpWhileMoving", Language:I18N("Allow Jump while moving"), data.jumpWhileMoving, true, Language:I18N("Bots jump while moving. If false, only on obstacles!"));
	settings:add("ADVANCED", "Integer", "overWriteBotSpeedMode", Language:I18N("Overwrite Speed-Mode"), data.overWriteBotSpeedMode, 0, Language:I18N("0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run"));
	settings:add("ADVANCED", "Integer", "overWriteBotAttackMode", Language:I18N("Overwrite Attack-Speed-Mode"), data.overWriteBotAttackMode, 0, Language:I18N("!!Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk, 4 = run"));
	settings:add("ADVANCED", "Float", "speedFactor", Language:I18N("Speed Reduction"), data.speedFactor, 1.0, Language:I18N("reduces the movementspeed. 1 = normal, 0.1 = slow"));
	settings:add("ADVANCED", "Float", "speedFactorAttack", Language:I18N("Speed Reduction Attack"), data.speedFactorAttack, 0.6, Language:I18N("reduces the movementspeed while attacking. 1 = normal, 0.1 = slow."));

	settings:add("TRACE", "Boolean", "debugTracePaths", Language:I18N("Debug Trace Paths"), data.debugTracePaths, false, Language:I18N("Enable Trace Path Editing and Visualizations"));
	settings:add("TRACE", "Integer", "waypointRange", Language:I18N("Waypoint Range"), data.waypointRange, 100, Language:I18N("Set how far away waypoints are visible (meters)"));
	settings:add("TRACE", "Boolean", "drawWaypointLines", Language:I18N("Draw Waypoint Lines"), data.drawWaypointLines, true, Language:I18N("Draw waypoint connection Lines"));
	settings:add("TRACE", "Integer", "lineRange", Language:I18N("Line Range"), data.lineRange, 15, Language:I18N("Set how far away waypoint lines are visible (meters)"));
	settings:add("TRACE", "Boolean", "drawWaypointIDs", Language:I18N("Draw Waypoint IDs"), data.drawWaypointIDs, true, Language:I18N("Draw waypoint IDs"));
	settings:add("TRACE", "Integer", "textRange", Language:I18N("Text Range"), data.textRange, 3, Language:I18N("Set how far away waypoint text is visible (meters)"));
	settings:add("TRACE", "Boolean", "debugSelectionRaytraces", Language:I18N("Debug Selection Raytraces"), data.debugSelectionRaytraces, false, Language:I18N("Shows the last trace line and search area from Commo Rose selection"));
	settings:add("TRACE", "Float", "traceDelta", Language:I18N("Trace Delta time"), data.traceDelta, 0.2, Language:I18N("update intervall of trace"))

	settings:add("EXPERT", "Float", "botFirstShotDelay", Language:I18N("First Shot Delay"), data.botFirstShotDelay, 0.2, Language:I18N("delay for first shot"));
	settings:add("EXPERT", "Float", "botMinTimeShootAtPlayer", Language:I18N("Min Time Shoot"), data.botMinTimeShootAtPlayer, 1.0, Language:I18N("the minimum time a Bot shoots at one player"));
	settings:add("EXPERT", "Float", "botFireModeDuration", Language:I18N("First Shot Delay"), data.botFireModeDuration, 5.0, Language:I18N("the minimum time a Bot tries to shoot a player"));
	settings:add("EXPERT", "Float", "maximunYawPerSec", Language:I18N("Maximum Degree per Sec"), data.maximunYawPerSec, 540, Language:I18N("in Degree. Maximum Rotaion-Movement of a Bot per second."));
	settings:add("EXPERT", "Float", "targetDistanceWayPoint", Language:I18N("Target Distance Way-Point"), data.targetDistanceWayPoint, 1.2, Language:I18N("distance the bots have to reach to continue with next Waypoint."));
	settings:add("EXPERT", "Boolean", "keepOneSlotForPlayers", Language:I18N("Keep one Player-Slot"), data.keepOneSlotForPlayers, true, Language:I18N("always keep one slot for new Players to join"));
	settings:add("EXPERT", "Integer", "distanceToSpawnBots", Language:I18N("Distance to Spawn Bots"), data.distanceToSpawnBots, 30, Language:I18N("distance to spawn Bots away from players"));
	settings:add("EXPERT", "Float", "heightDistanceToSpawn", Language:I18N("Height to Spawn Bots"), data.heightDistanceToSpawn, 2.5, Language:I18N("distance vertically, Bots should spawn away, if closer than distance"));
	settings:add("EXPERT", "Integer", "distanceToSpawnReduction", Language:I18N("Reduce Distance on Fail"), data.distanceToSpawnReduction, 5, Language:I18N("reduce distance if not possible"));
	settings:add("EXPERT", "Integer", "maxTrysToSpawnAtDistance", Language:I18N("Max Retrys on Distance"), data.maxTrysToSpawnAtDistance, 3, Language:I18N("try this often to spawn a bot away from players"));
	settings:add("EXPERT", "Float", "headShotFactorBots", Language:I18N("Factor for HeadShot"), data.headShotFactorBots, 0.8, Language:I18N("Factor for damage if Bot does a headshot"));
	settings:add("EXPERT", "Boolean", "respawnWayBots", Language:I18N("Respawn Bots"), data.respawnWayBots, true, Language:I18N("Bots on paths respawn if killed on startup"));
	settings:add("EXPERT", "Boolean", "attackWayBots", Language:I18N("Attack other players"), data.attackWayBots, true, Language:I18N("Bots on paths attack player by default"));

	settings:add("OTHER", "Boolean", "disableChatCommands", Language:I18N("Disable Chat Commands"), data.disableChatCommands, true, Language:I18N("if true, no chat commands can be used"));
	settings:add("OTHER", "Boolean", "traceUsageAllowed", Language:I18N("Allow Trace Usage"), data.traceUsageAllowed, true, Language:I18N("if false, no traces can be recorded, deleted or saved"));
	settings:addList("OTHER", "language", Language:I18N("Language"), { "de_DE", "cn_CN", "en_US" }, data.language, "en_US", Language:I18N("Select the language of this mod"));
	settings:add("OTHER", "Password", "settingsPassword", Language:I18N("Password"), data.settingsPassword, nil, Language:I18N("Password protection of these Mod"));

	self._views:execute('BotEditor.openSettings(\'' .. settings:getJSON() .. '\');');
	self._views:show('settings');
	self._views:focus();
end

function FunBotUIClient:_onUIChangeLanguage(language)
	if Config.disableUserInterface == true then
		return;
	end
	
	self._views:setLanguage(language);
end

function FunBotUIClient:_onUISaveSettings(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Save_Settings (' .. data .. ')');
	NetEvents:Send('UI_Request_Save_Settings', data);
end

function FunBotUIClient:_onBotEditorEvent(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: BotEditor (' .. data .. ')');

	-- Redirect to Server
	NetEvents:Send('BotEditor', data);
end

function FunBotUIClient:_onUIShowToolbar(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Show_Toolbar (' .. tostring(data) .. ')');

	if (data == 'true') then
		self._views:show('toolbar');
		self._views:focus();
	else
		self._views:hide('toolbar');
		self._views:blur();
	end
end

function FunBotUIClient:_onUIPasswordProtection(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Password_Protection (' .. tostring(data) .. ')');

	if (data == 'true') then
		self._views:show('password_protection');
		self._views:focus();
	else
		self._views:hide('password_protection');
		self._views:blur();
	end
end

function FunBotUIClient:_onUIRequestPasswordError(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Request_Password_Error');
	self._views:error('password', data);
end

function FunBotUIClient:_onUIRequestPassword(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Request_Password (' .. tostring(data) .. ')');

	if (data == 'true') then
		self._views:show('password');
		self._views:focus();
	else
		self._views:hide('password');
		self._views:blur();
	end
end

function FunBotUIClient:_onUISendPassword(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	print('UIClient: UI_Send_Password (' .. data .. ')');
	NetEvents:Send('UI_Request_Open', data);
end

function FunBotUIClient:_onEngineUpdate(delta, simDelta)
	if (Config.debugTracePaths) then
		if (self.WaypointEditorTimerActive) then
			self.WaypointEditorTimer = self.WaypointEditorTimer + delta
		end
		if (self.WaypointEditorTimer >= self.WaypointEditorDelay) then
			self:_onUIWaypointsEditor()
			self._views:focus()
			self.WaypointEditorTimerActive = false
			self.WaypointEditorTimer = 0
		end
	end
end

function FunBotUIClient:_onUpdateInput(data)
	if Config.disableUserInterface == true then
		return;
	end
	
	-- Show or Hide the Bot-Editor
	local Comm1 = InputManager:IsDown(InputConceptIdentifiers.ConceptCommMenu1)
	local Comm2 = InputManager:IsDown(InputConceptIdentifiers.ConceptCommMenu2)
	local Comm3 = InputManager:IsDown(InputConceptIdentifiers.ConceptCommMenu3)
	local commButtonDown = (Comm1 or Comm2 or Comm3)

	Comm1 = InputManager:WentUp(InputConceptIdentifiers.ConceptCommMenu1)
	Comm2 = InputManager:WentUp(InputConceptIdentifiers.ConceptCommMenu2)
	Comm3 = InputManager:WentUp(InputConceptIdentifiers.ConceptCommMenu3)
	local commButtonUp = (Comm1 or Comm2 or Comm3)

	if Config.debugTracePaths then
		self.WaypointEditorTimerActive = commButtonDown

		if (commButtonUp) then
			self.WaypointEditorTimer = 0
			self._views:blur()
		end
	end
		
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		print('Client send: UI_Request_Open');

		-- This request can use for UI-Toggle
		NetEvents:Send('UI_Request_Open');
	end
end

if (g_FunBotUIClient == nil) then
	g_FunBotUIClient = FunBotUIClient();
end

return g_FunBotUIClient;
