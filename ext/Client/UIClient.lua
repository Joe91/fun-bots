class 'FunBotUIClient';

require('UIViews');
require('UISettings');

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
	print('UIClient: UI_Settings (' .. json.encode(data) .. ')');
	
	local settings = UISettings();
	
	-- Samples
	-- add(<category>, <types>, <name>, <title>, <value>, <default>, <description>)
	-- addList(<category>, <name>, <title>, <list>, <value>, <default>, <description>)
	
	settings:add("GLOBAL", "Boolean", "spawnInSameTeam", "Spawn in Same Team", data.spawnInSameTeam, false, "If true, Bots spawn in the team of the player");
	settings:add("GLOBAL", "Boolean", "meleeAttackIfClose", "Attack with Melee", data.meleeAttackIfClose, true, "Bots attack the playe with the knife, if close");
	settings:add("GLOBAL", "Boolean", "shootBackIfHit", "Attack if Hit", data.shootBackIfHit, true, "Bots imidiatly attack player, if shot by it");
	settings:add("GLOBAL", "Boolean", "useKnifeOnly", "Knive Only", data.useKnifeOnly, false, "Bots do not shoot but try to attack with the knive");
	settings:addList("GLOBAL", "botKit", "Bot Kit", Kits, data.botKit, "RANDOM_KIT", "The Kit a bots spawns with.");
	settings:addList("GLOBAL", "botColor", "Bot Color", Colors, data.botColor, "RANDOM_COLOR", "The Kit-Color a bots spawns with.");
	settings:add("DIFFICULTY", "Number", "botAimWorsening", "Aim Worsening", data.botAimWorsening * 100, 0, "0 = hard, 100 (or higher) = easy. Only takes effect on level Start");
	settings:add("DIFFICULTY", "Number", "maxRaycastDistance", "View Distance Bots", data.maxRaycastDistance, 125, "The maximum distance a bots starts shooting at a player");
	settings:add("DIFFICULTY", "Number", "distanceForDirectAttack", "Direct Attack Distance", data.distanceForDirectAttack, 3, "When this close to a bot, he starts attacking");
	settings:add("DIFFICULTY", "Number", "fovForShooting", "Bot FOV", data.fovForShooting, 270, "The Field Of View of the bots, where they can detect a player");
	settings:add("DIFFICULTY", "Number", "bulletDamageBot", "Damage Bot Bullet", data.bulletDamageBot, 9, "The damage a normal Bullet does");
	settings:add("DIFFICULTY", "Number", "bulletDamageBotSniper", "Damage Bot Sniper", data.bulletDamageBotSniper, 24, "The damage a Sniper-Bullet does");
	settings:add("DIFFICULTY", "Number", "meleeDamageBot", "Damage Bot Melee", data.meleeDamageBot, 42, "The Damage a melee-attack does");
	settings:add("OTHER", "Boolean", "disableChatCommands", "Disable Chat Commands", data.disableChatCommands, true, "if true, no chat commands can be used");
	settings:addList("OTHER", "language", "Language", { "de_DE", "cn_CN", "en_US" }, data.language, "en_US", "Select the language of this mod");
	settings:add("OTHER", "Password", "settingsPassword", "Password", data.settingsPassword, nil, "Password protection of these Mod");
	
	self._views:execute('BotEditor.openSettings(\'' .. settings:getJSON() .. '\');');
	self._views:show('settings');
	self._views:focus();
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
