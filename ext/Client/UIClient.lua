class 'FunBotUIClient';

require('UIViews');
require('UISettings');


Language = require('__shared/Language');

function FunBotUIClient:__init()
	self._views = UIViews();

	Events:Subscribe('Client:UpdateInput', self, self._onUpdateInput);
	NetEvents:Subscribe('UI_Toggle', self, self._onUIToggle);
	Events:Subscribe('UI_Toggle', self, self._onUIToggle);
	NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent);
	Events:Subscribe('BotEditor', self, self._onBotEditorEvent);
	NetEvents:Subscribe('UI_Request_Password', self, self._onUIRequestPassword);
	NetEvents:Subscribe('UI_Request_Password_Error', self, self._onUIRequestPasswordError);
	NetEvents:Subscribe('UI_Password_Protection', self, self._onUIPasswordProtection);
	NetEvents:Subscribe('UI_Show_Toolbar', self, self._onUIShowToolbar);
	NetEvents:Subscribe('UI_Settings', self, self._onUISettings);
	Events:Subscribe('UI_Settings', self, self._onUISettings);
	NetEvents:Subscribe('UI_Change_Language', self, self._onUIChangeLanguage);
	Events:Subscribe('UI_Change_Language', self, self._onUIChangeLanguage);
	Events:Subscribe('UI_Save_Settings', self, self._onUISaveSettings);
	Events:Subscribe('UI_Send_Password', self, self._onUISendPassword);

	-- Events from BotManager, TraceManager & Other

	self._views:setLanguage(Config.language);
end

-- Events
function FunBotUIClient:_onUIToggle()
	print('UIClient: UI_Toggle');

	if self._views:isVisible() then
		self._views:close();
	else
		self._views:open();
		self._views:focus();
	end
end

function FunBotUIClient:_onUISettings(data)
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

	settings:add("GLOBAL", "Boolean", "spawnInSameTeam", Language:I18N("Spawn in Same Team"), data.spawnInSameTeam, false, Language:I18N("If true, Bots spawn in the team of the player"));
	settings:addList("GLOBAL", "botWeapon", "Bot Weapon", BotWeapons, data.botWeapon, "Primary", Language:I18N("Select the weapon the bots use"));
	settings:addList("GLOBAL", "botKit", Language:I18N("Bot Kit"), BotKits, data.botKit, "RANDOM_KIT", Language:I18N("The Kit a bots spawns with."));
	settings:addList("GLOBAL", "botColor", Language:I18N("Bot Color"), BotColors, data.botColor, "RANDOM_COLOR", Language:I18N("The Kit-Color a bots spawns with."));

	settings:add("DIFFICULTY", "Float", "botAimWorsening", Language:I18N("Aim Worsening"), data.botAimWorsening, 0.0, Language:I18N("0 = hard, 1 (or higher) = easy. Only takes effect on level Start"));
	settings:add("DIFFICULTY", "Integer", "bulletDamageBot", Language:I18N("Damage Bot Bullet"), data.bulletDamageBot, 9, Language:I18N("The damage a normal Bullet does"));
	settings:add("DIFFICULTY", "Integer", "bulletDamageBotSniper", Language:I18N("Damage Bot Sniper"), data.bulletDamageBotSniper, 24, Language:I18N("The damage a Sniper-Bullet does"));
	settings:add("DIFFICULTY", "Integer", "meleeDamageBot", Language:I18N("Damage Bot Melee"), data.meleeDamageBot, 42, Language:I18N("The Damage a melee-attack does"));

	settings:add("SPAWN", "Boolean", "spawnOnLevelstart", Language:I18N("Spawn on Levelstart"), data.spawnOnLevelstart, true, Language:I18N("Bots spawn on levelstart (if valid paths are available)"));
	settings:add("SPAWN", "Boolean", "onlySpawnBotsWithPlayers", Language:I18N("Only spawn with players"), data.onlySpawnBotsWithPlayers, true, Language:I18N("Bots only spawn if at least one Player is on the server"));
	settings:add("SPAWN", "Integer", "initNumberOfBots", Language:I18N("Number Bots on Levelstart"), data.initNumberOfBots, 10, Language:I18N("Bots on levelstart"));
	settings:add("SPAWN", "Float", "spawnDelayBots", Language:I18N("Respawn Delay"), data.spawnDelayBots, 2.0, Language:I18N("time till bots respawn, if respawn enabled"));
	settings:add("SPAWN", "Integer", "botTeam", Language:I18N("Default Bot Team"), data.botTeam, 2, Language:I18N("default bot team 1 = US, 2 = RU"));
	settings:add("SPAWN", "Boolean", "respawnWayBots", Language:I18N("Respawn Bots"), data.respawnWayBots, true, Language:I18N("Bots on paths respawn if killed on startup"));
	settings:add("SPAWN", "Boolean", "botNewLoadoutOnSpawn", Language:I18N("New Loadout on Spawn"), data.botNewLoadoutOnSpawn, true, Language:I18N("bots get a new kit and color, if they respawn"));
	settings:add("SPAWN", "Integer", "maxAssaultBots", Language:I18N("Max Assault Bots"), data.maxAssaultBots, -1, Language:I18N("maximum number of Bots with Assault Kit. -1 = unlimited"));
	settings:add("SPAWN", "Integer", "maxEngineerBots", Language:I18N("Max Engineer Bots"), data.maxEngineerBots, -1, Language:I18N("maximum number of Bots with Engineer Kit. -1 = unlimited"));
	settings:add("SPAWN", "Integer", "maxSupportBots", Language:I18N("Max Support Bots"), data.maxSupportBots, -1, Language:I18N("maximum number of Bots with Support Kit. -1 = unlimited"));
	settings:add("SPAWN", "Integer", "maxReconBots", Language:I18N("Max Recon Bots"), data.maxReconBots, -1, Language:I18N("maximum number of Bots with Recon Kit. -1 = unlimited"));

	settings:add("ADVANCED", "Integer", "fovForShooting", Language:I18N("Bot FOV"), data.fovForShooting, 270, Language:I18N("The Field Of View of the bots, where they can detect a player"));
	settings:add("ADVANCED", "Boolean", "shootBackIfHit", Language:I18N("Attack if Hit"), data.shootBackIfHit, true, Language:I18N("Bots imidiatly attack player, if shot by it"));
	settings:add("ADVANCED", "Integer", "maxRaycastDistance", Language:I18N("View Distance Bots"), data.maxRaycastDistance, 125, Language:I18N("The maximum distance a bots starts shooting at a player"));
	settings:add("ADVANCED", "Integer", "distanceForDirectAttack", Language:I18N("Direct Attack Distance"), data.distanceForDirectAttack, 3, Language:I18N("When this close to a bot, he starts attacking"));
	settings:add("ADVANCED", "Boolean", "meleeAttackIfClose", Language:I18N("Attack with Melee"), data.meleeAttackIfClose, true, Language:I18N("Bots attack the playe with the knife, if close"));
	settings:add("ADVANCED", "Boolean", "attackWayBots", Language:I18N("Attack other players"), data.attackWayBots, true, Language:I18N("Bots on paths attack player by default"));
	settings:add("ADVANCED", "Float", "meleeAttackCoolDown", Language:I18N("Melee Cooldown"), data.meleeAttackCoolDown, 3, Language:I18N("the time a Bot waits before attacking with melee again"));
	settings:add("ADVANCED", "Boolean", "jumpWhileShooting", Language:I18N("Allow Jump while shooting"), data.jumpWhileShooting, true, Language:I18N("Bots jump over obstacles while shooting"));
	settings:add("ADVANCED", "Boolean", "jumpWhileMoving", Language:I18N("Allow Jump while moving"), data.jumpWhileMoving, true, Language:I18N("Bots jump while moving. If false, only on obstacles!"));

	settings:add("EXPERT", "Float", "botFirstShotDelay", Language:I18N("First Shot Delay"), data.botFirstShotDelay, 0.2, Language:I18N("delay for first shot"));
	settings:add("EXPERT", "Float", "botMinTimeShootAtPlayer", Language:I18N("Min Time Shoot"), data.botMinTimeShootAtPlayer, 1.0, Language:I18N("the minimum time a Bot shoots at one player"));
	settings:add("EXPERT", "Float", "botFireModeDuration", Language:I18N("First Shot Delay"), data.botFireModeDuration, 5.0, Language:I18N("the minimum time a Bot tries to shoot a player"));
	settings:add("EXPERT", "Float", "maximunYawPerSec", Language:I18N("Maximum Degree per Sec"), data.maximunYawPerSec, 720, Language:I18N("in Degree. Maximum Rotaion-Movement of a Bot per second."));
	settings:add("EXPERT", "Float", "targetDistanceWayPoint", Language:I18N("Target Distance Way-Point"), data.targetDistanceWayPoint, 1.5, Language:I18N("distance the bots have to reach to continue with next Waypoint."));
	settings:add("EXPERT", "Float", "botFireDuration", Language:I18N("Fire Time (Assault/Engi)"), data.botFireDuration, 0.3, Language:I18N("the duration a bot fires (Assault / Engi)"));
	settings:add("EXPERT", "Float", "botFirePause", Language:I18N("Fire Pause (Assalut/Engi)"), data.botFirePause, 0.3, Language:I18N("the duration a bot waits after fire (Assault / Engi)"));
	settings:add("EXPERT", "Float", "botFireDurationSupport", Language:I18N("Fire Time (Support)"), data.botFireDurationSupport, 2.0, Language:I18N("the duration a bot fires (Support)"));
	settings:add("EXPERT", "Float", "botFirePauseSupport", Language:I18N("Fire Pause (Support)"), data.botFirePauseSupport, 0.6, Language:I18N("the duration a Bot waits after fire (Support)"));
	settings:add("EXPERT", "Float", "botFireCycleRecon", Language:I18N("Fire Cycle (Recon)"), data.botFireCycleRecon, 0.4, Language:I18N("the duration of a FireCycle (Recon)"));
	settings:add("EXPERT", "Float", "botFireCyclePistol", Language:I18N("Fire Cycle (Pistol)"), data.botFireCyclePistol, 0.4, Language:I18N("the duration of a FireCycle (Pistol)"));

	settings:add("OTHER", "Boolean", "disableChatCommands", Language:I18N("Disable Chat Commands"), data.disableChatCommands, true, Language:I18N("if true, no chat commands can be used"));
	settings:add("OTHER", "Boolean", "traceUsageAllowed", Language:I18N("Allow Trace Usage"), data.traceUsageAllowed, true, Language:I18N("if false, no traces can be recorded, deleted or saved"));
	settings:addList("OTHER", "language", Language:I18N("Language"), { "de_DE", "cn_CN", "en_US" }, data.language, "en_US", Language:I18N("Select the language of this mod"));
	settings:add("OTHER", "Password", "settingsPassword", Language:I18N("Password"), data.settingsPassword, nil, Language:I18N("Password protection of these Mod"));

	self._views:execute('BotEditor.openSettings(\'' .. settings:getJSON() .. '\');');
	self._views:show('settings');
	self._views:focus();
end

function FunBotUIClient:_onUIChangeLanguage(language)
	self._views:setLanguage(language);
end

function FunBotUIClient:_onUISaveSettings(data)
	print('UIClient: UI_Save_Settings (' .. data .. ')');
	NetEvents:Send('UI_Request_Save_Settings', data);
end

function FunBotUIClient:_onBotEditorEvent(data)
	print('UIClient: BotEditor (' .. data .. ')');

	-- Redirect to Server
	NetEvents:Send('BotEditor', data);
end

function FunBotUIClient:_onUIShowToolbar(data)
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
	print('UIClient: UI_Request_Password_Error');
	self._views:error('password', data);
end

function FunBotUIClient:_onUIRequestPassword(data)
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
	print('UIClient: UI_Send_Password (' .. data .. ')');
	NetEvents:Send('UI_Request_Open', data);
end


function FunBotUIClient:_onUpdateInput(data)
	-- Show or Hide the Bot-Editor by requesting permissions
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
