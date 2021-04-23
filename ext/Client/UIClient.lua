class 'FunBotUIClient'

require('UIViews')
require('UISettings')
require('ClientNodeEditor')

local m_Language = require('__shared/Language')

function FunBotUIClient:__init()
	self._views = UIViews()

	if Config.DisableUserInterface ~= true then
		NetEvents:Subscribe('UI_Password_Protection', self, self._onUIPasswordProtection)
		NetEvents:Subscribe('UI_Request_Password', self, self._onUIRequestPassword)
		NetEvents:Subscribe('UI_Request_Password_Error', self, self._onUIRequestPasswordError)
		Events:Subscribe('UI_Send_Password', self, self._onUISendPassword)
		NetEvents:Subscribe('UI_Toggle', self, self._onUIToggle)
		Events:Subscribe('UI_Toggle', self, self._onUIToggle)
		NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent)
		Events:Subscribe('BotEditor', self, self._onBotEditorEvent)
		NetEvents:Subscribe('UI_Show_Toolbar', self, self._onUIShowToolbar)
		NetEvents:Subscribe('UI_Settings', self, self._onUISettings)
		NetEvents:Subscribe('UI_CommonRose', self, self._onUICommonRose)
		Events:Subscribe('UI_Settings', self, self._onUISettings)
		Events:Subscribe('UI_Save_Settings', self, self._onUISaveSettings)
		NetEvents:Subscribe('UI_Change_Language', self, self._onUIChangeLanguage)
		Events:Subscribe('UI_Change_Language', self, self._onUIChangeLanguage)

		NetEvents:Subscribe('UI_Waypoints_Editor', self, self._onUIWaypointsEditor)
		Events:Subscribe('UI_Waypoints_Editor', self, self._onUIWaypointsEditor)
		NetEvents:Subscribe('UI_Trace', self, self._onUITrace)
		Events:Subscribe('UI_Trace', self, self._onUITrace)
		NetEvents:Subscribe('UI_Trace_Index', self, self._onUITraceIndex)
		Events:Subscribe('UI_Trace_Index', self, self._onUITraceIndex)
		NetEvents:Subscribe('UI_Trace_Waypoints', self, self._onUITraceWaypoints)
		Events:Subscribe('UI_Trace_Waypoints', self, self._onUITraceWaypoints)

		self._views:setLanguage(Config.Language)
	end
end

-- Events
function FunBotUIClient:_onUIToggle()
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Toggle')
	end

	self._views:execute('BotEditor.Hide()')
	self._views:disable()
	--if self._views:isVisible() then
	--	self._views:close()
	--else
	--	self._views:open()
	--	self._views:focus()
	--end
end

function FunBotUIClient:_onUICommonRose(p_Data)
	if p_Data == "false" then
		self._views:execute('BotEditor.setCommonRose(false)')
		self._views:blur()
		return
	end

	self._views:execute('BotEditor.setCommonRose(\'' .. json.encode(p_Data) .. '\')')
	self._views:focus()
end

function FunBotUIClient:_onSetOperationControls(p_Data)
	self._views:execute('BotEditor.setOperationControls(\'' .. json.encode(p_Data) .. '\')')
end

function FunBotUIClient:_onUIWaypointsEditor(p_State)
	if Config.DisableUserInterface == true then
		return
	end

	if p_State == false then
		if Debug.Client.UI then
			print('UIClient: close UI_Waypoints_Editor')
		end

		self._views:hide('waypoint_toolbar')
		self._views:show('toolbar')
		Config.DebugTracePaths = false
		NetEvents:Send('UI_CommoRose_Enabled', false)
		return
	end

	if Debug.Client.UI then
		print('UIClient: open UI_Waypoints_Editor')
	end

	Config.DebugTracePaths = true
	NetEvents:Send('UI_CommoRose_Enabled', true)
	g_ClientNodeEditor:_onSetEnabled(true)
	self._views:show('waypoint_toolbar')
	self._views:hide('toolbar')
	self._views:disable()
end

function FunBotUIClient:_onUITraceIndex(p_Index)
	if Config.DisableUserInterface == true then
		return
	end

	self._views:execute('BotEditor.updateTraceIndex(' .. tostring(p_Index) .. ')')
end

function FunBotUIClient:_onUITraceWaypoints(p_Count)
	if Config.DisableUserInterface == true then
		return
	end

	self._views:execute('BotEditor.updateTraceWaypoints(' .. tostring(p_Count) .. ')')
end

function FunBotUIClient:_onUITraceWaypointsDistance(p_Distance)
	if Config.DisableUserInterface == true then
		return
	end

	self._views:execute('BotEditor.updateTraceWaypointsDistance(' .. string.format('%4.2f', p_Distance) .. ')')
end

function FunBotUIClient:_onUITrace(p_State)
	if Config.DisableUserInterface == true then
		return
	end

	self._views:execute('BotEditor.toggleTraceRun(' .. tostring(p_State) .. ')')
	self._views:disable()
end

function FunBotUIClient:_onUISettings(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if p_Data == false then
		if Debug.Client.UI then
			print('UIClient: close UI_Settings')
		end

		self._views:hide('settings')
		--self._views:blur()
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Settings (' .. json.encode(p_Data) .. ')')
	end

	local settings = UISettings()

	-- Samples
	-- add(<category>, <types>, <name>, <title>, <value>, <default>, <description>)
	-- addList(<category>, <name>, <title>, <list>, <value>, <default>, <description>)

	settings:addList("GLOBAL", "botWeapon", m_Language:I18N("Bot Weapon"), BotWeapons, p_Data.botWeapon, "Auto", m_Language:I18N("Select the weapon the bots use"))
	settings:addList("GLOBAL", "botKit", m_Language:I18N("Bot Kit"), BotKits, p_Data.botKit, "RANDOM_KIT", m_Language:I18N("The Kit a bots spawns with."))
	settings:addList("GLOBAL", "botColor", m_Language:I18N("Bot Color"), BotColors, p_Data.botColor, "RANDOM_COLOR", m_Language:I18N("The Kit-Color a bots spawns with."))
	settings:add("GLOBAL", "Boolean", "zombieMode", m_Language:I18N("Zombie Mode"), p_Data.zombieMode, false, m_Language:I18N("Bots act like zombies"))

	settings:add("DIFFICULTY", "Float", "botAimWorsening", m_Language:I18N("Aim Worsening"), p_Data.botAimWorsening, 0.6, m_Language:I18N("0 = hard, 1 (or higher) = easy"))
	settings:add("DIFFICULTY", "Float", "botSniperAimWorsening", m_Language:I18N("Aim Worsening Sniper"), p_Data.botSniperAimWorsening, 0.2, m_Language:I18N("0 = hard, 1 (or higher) = easy"))
	settings:add("DIFFICULTY", "Float", "damageFactorAssault", m_Language:I18N("Factor for Assault-Weapon-Damage"), p_Data.damageFactorAssault, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorCarabine", m_Language:I18N("Factor for Carabine-Weapon-Damage"), p_Data.damageFactorCarabine, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorPDW", m_Language:I18N("Factor for PDW-Weapon-Damage"), p_Data.damageFactorPDW, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorLMG", m_Language:I18N("Factor for LMG-Weapon-Damage"), p_Data.damageFactorLMG, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorSniper", m_Language:I18N("Factor for Sniper-Weapon-Damage"), p_Data.damageFactorSniper, 0.8, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorShotgun", m_Language:I18N("Factor for Shotgun-Weapon-Damage"), p_Data.damageFactorShotgun, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorPistol", m_Language:I18N("Factor for Pistol-Weapon-Damage"), p_Data.damageFactorPistol, 0.8, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	settings:add("DIFFICULTY", "Float", "damageFactorKnife", m_Language:I18N("Factor for Knife-Weapon-Damage"), p_Data.damageFactorKnife, 1.2, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))

	settings:addList("SPAWN", "spawnMode", m_Language:I18N("Spawn Mode"), SpawnModes, p_Data.spawnMode, "increment_with_players", m_Language:I18N("Mode the bots spawn with"))
	settings:add("SPAWN", "Boolean", "spawnInBothTeams", m_Language:I18N("Spawn in both teams"), p_Data.spawnInBothTeams, true, m_Language:I18N("Bots spawn in both teams"))
	settings:add("SPAWN", "Integer", "initNumberOfBots", m_Language:I18N("Number of Bots for Spawn-Mode"), p_Data.initNumberOfBots, 5, m_Language:I18N("Bots for the spawnmode"))
	settings:add("SPAWN", "Integer", "newBotsPerNewPlayer", m_Language:I18N("Number Bots on new Player"), p_Data.newBotsPerNewPlayer, 2, m_Language:I18N("number to increase Bots, when new players join, if mode is selected"))
	settings:add("SPAWN", "Float", "spawnDelayBots", m_Language:I18N("Respawn Delay"), p_Data.spawnDelayBots, 10.0, m_Language:I18N("time till bots respawn, if respawn enabled"))
	settings:add("SPAWN", "Integer", "botTeam", m_Language:I18N("Default Bot Team"), p_Data.botTeam, 0, m_Language:I18N("default bot team. 0 = auto, 1 = US (forced), 2 = RU (forced)"))
	settings:add("SPAWN", "Boolean", "botNewLoadoutOnSpawn", m_Language:I18N("New Loadout on Spawn"), p_Data.botNewLoadoutOnSpawn, true, m_Language:I18N("bots get a new kit and color, if they respawn"))
	settings:add("SPAWN", "Integer", "maxAssaultBots", m_Language:I18N("Max Assault Bots"), p_Data.maxAssaultBots, -1, m_Language:I18N("maximum number of Bots with Assault Kit. -1 = unlimited"))
	settings:add("SPAWN", "Integer", "maxEngineerBots", m_Language:I18N("Max Engineer Bots"), p_Data.maxEngineerBots, -1, m_Language:I18N("maximum number of Bots with Engineer Kit. -1 = unlimited"))
	settings:add("SPAWN", "Integer", "maxSupportBots", m_Language:I18N("Max Support Bots"), p_Data.maxSupportBots, -1, m_Language:I18N("maximum number of Bots with Support Kit. -1 = unlimited"))
	settings:add("SPAWN", "Integer", "maxReconBots", m_Language:I18N("Max Recon Bots"), p_Data.maxReconBots, -1, m_Language:I18N("maximum number of Bots with Recon Kit. -1 = unlimited"))

	settings:add("WEAPONS", "Boolean", "useRandomWeapon", m_Language:I18N("Random Weapon"), p_Data.useRandomWeapon, true, m_Language:I18N("use a random weapon out of the class list"))
	settings:addList("WEAPONS", "pistol", m_Language:I18N("Bot Pistol"), PistoWeapons, p_Data.pistol, "M1911_Lit", m_Language:I18N("Pistol of Bots"))
	settings:addList("WEAPONS", "knife", m_Language:I18N("Bot Knife"), KnifeWeapons, p_Data.knife, "Razor", m_Language:I18N("Knife of Bots"))
	settings:addList("WEAPONS", "assaultWeapon",  m_Language:I18N("Weapon Assault"), AssaultPrimary, p_Data.assaultWeapon, "M416", m_Language:I18N("Weapon of Assault class"))
	settings:addList("WEAPONS", "engineerWeapon",  m_Language:I18N("Weapon Engineer"), EngineerPrimary, p_Data.engineerWeapon, "M4A1", m_Language:I18N("Weapon of Engineer class"))
	settings:addList("WEAPONS", "supportWeapon",  m_Language:I18N("Weapon Support"), SupportPrimary, p_Data.supportWeapon, "M249", m_Language:I18N("Weapon of Support class"))
	settings:addList("WEAPONS", "reconWeapon",  m_Language:I18N("Weapon Recon"), ReconPrimary, p_Data.reconWeapon, "L96_6x", m_Language:I18N("Weapon of Recon class"))
	settings:addList("WEAPONS", "assaultWeaponSet",  m_Language:I18N("Weaponset of Assault"), WeaponSets, p_Data.assaultWeaponSet, "Class", m_Language:I18N("Weaponset of Assault class"))
	settings:addList("WEAPONS", "engineerWeaponSet",  m_Language:I18N("Weaponset Engineer"), WeaponSets, p_Data.engineerWeaponSet, "Class_PDW", m_Language:I18N("Weaponset of Engineer class"))
	settings:addList("WEAPONS", "supportWeaponSet",  m_Language:I18N("Weaponset Support"), WeaponSets, p_Data.supportWeaponSet, "Class_Shotgun", m_Language:I18N("Weaponset of Support class"))
	settings:addList("WEAPONS", "reconWeaponSet",  m_Language:I18N("Weaponset Recon"), WeaponSets, p_Data.reconWeaponSet, "Class", m_Language:I18N("Weaponset of Recon class"))

	settings:add("BEHAVIOUR", "Integer", "fovForShooting", m_Language:I18N("Bot FOV"), p_Data.fovForShooting, 200, m_Language:I18N("The Field Of View of the bots, where they can detect a player"))
	settings:add("BEHAVIOUR", "Integer", "maxRaycastDistance", m_Language:I18N("View Distance Bots"), p_Data.maxRaycastDistance, 150, m_Language:I18N("The maximum distance a Sniper Bot starts shooting at a player"))
	settings:add("BEHAVIOUR", "Integer", "maxShootDistanceNoSniper", m_Language:I18N("Attack Distance no Sniper"), p_Data.maxShootDistanceNoSniper, 70, m_Language:I18N("The maximum distance a non Sniper Bot starts shooting at a player"))
	settings:addList("BEHAVIOUR", "botAttackMode", m_Language:I18N("Bot Attack Mode"), BotAttackModes, p_Data.botAttackMode, "Random", m_Language:I18N("Mode the Bots attack with. Crouch or Stand"))
	settings:add("BEHAVIOUR", "Boolean", "shootBackIfHit", m_Language:I18N("Attack if Hit"), p_Data.shootBackIfHit, true, m_Language:I18N("Bots imidiatly attack player, if shot by it"))
	settings:add("BEHAVIOUR", "Boolean", "botsAttackBots", m_Language:I18N("Bots Attack Bots"), p_Data.botsAttackBots, true, m_Language:I18N("Bots attack bots from other team"))
	settings:add("BEHAVIOUR", "Boolean", "meleeAttackIfClose", m_Language:I18N("Attack with Melee"), p_Data.meleeAttackIfClose, true, m_Language:I18N("Bots attack the playe with the knife, if close"))
	settings:add("BEHAVIOUR", "Boolean", "botCanKillHimself", m_Language:I18N("Bots can kill themself"), p_Data.botCanKillHimself, false, m_Language:I18N("If false, Bots take no fall or Frag damage"))

	settings:add("ADVANCED", "Float", "distanceForDirectAttack", m_Language:I18N("Direct Attack Distance"), p_Data.distanceForDirectAttack, 5, m_Language:I18N("When this close to a bot, he starts attacking"))
	settings:add("ADVANCED", "Integer", "maxBotAttackBotDistance", m_Language:I18N("Distance Bot Bot attack"), p_Data.maxBotAttackBotDistance, 30, m_Language:I18N("The maximum distance a Bot attacks an other Bot"))
	settings:add("ADVANCED", "Float", "meleeAttackCoolDown", m_Language:I18N("Melee Cooldown"), p_Data.meleeAttackCoolDown, 3, m_Language:I18N("the time a Bot waits before attacking with melee again"))
	settings:add("ADVANCED", "Boolean", "aimForHead", m_Language:I18N("Aim for Head"), p_Data.aimForHead, false, m_Language:I18N("Bots aim for the head. If false for the body"))
	settings:add("ADVANCED", "Boolean", "jumpWhileShooting", m_Language:I18N("Allow Jump while shooting"), p_Data.jumpWhileShooting, true, m_Language:I18N("Bots jump over obstacles while shooting"))
	settings:add("ADVANCED", "Boolean", "jumpWhileMoving", m_Language:I18N("Allow Jump while moving"), p_Data.jumpWhileMoving, true, m_Language:I18N("Bots jump while moving. If false, only on obstacles!"))
	settings:add("ADVANCED", "Integer", "overWriteBotSpeedMode", m_Language:I18N("Overwrite Speed-Mode"), p_Data.overWriteBotSpeedMode, 0, m_Language:I18N("0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run"))
	settings:add("ADVANCED", "Integer", "overWriteBotAttackMode", m_Language:I18N("Overwrite Attack-Speed-Mode"), p_Data.overWriteBotAttackMode, 0, m_Language:I18N("!!Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk, 4 = run"))
	settings:add("ADVANCED", "Float", "speedFactor", m_Language:I18N("Speed Reduction"), p_Data.speedFactor, 1.0, m_Language:I18N("reduces the movementspeed. 1 = normal, 0.1 = slow"))
	settings:add("ADVANCED", "Float", "speedFactorAttack", m_Language:I18N("Speed Reduction Attack"), p_Data.speedFactorAttack, 0.6, m_Language:I18N("reduces the movementspeed while attacking. 1 = normal, 0.1 = slow."))

	settings:add("TRACE", "Boolean", "debugTracePaths", m_Language:I18N("Debug Trace Paths"), p_Data.debugTracePaths, false, m_Language:I18N("Enable Trace Path Editing and Visualizations"))
	settings:add("TRACE", "Integer", "waypointRange", m_Language:I18N("Waypoint Range"), p_Data.waypointRange, 100, m_Language:I18N("Set how far away waypoints are visible (meters)"))
	settings:add("TRACE", "Boolean", "drawWaypointLines", m_Language:I18N("Draw Waypoint Lines"), p_Data.drawWaypointLines, true, m_Language:I18N("Draw waypoint connection Lines"))
	settings:add("TRACE", "Integer", "lineRange", m_Language:I18N("Line Range"), p_Data.lineRange, 15, m_Language:I18N("Set how far away waypoint lines are visible (meters)"))
	settings:add("TRACE", "Boolean", "drawWaypointIDs", m_Language:I18N("Draw Waypoint IDs"), p_Data.drawWaypointIDs, true, m_Language:I18N("Draw waypoint IDs"))
	settings:add("TRACE", "Integer", "textRange", m_Language:I18N("Text Range"), p_Data.textRange, 3, m_Language:I18N("Set how far away waypoint text is visible (meters)"))
	settings:add("TRACE", "Boolean", "debugSelectionRaytraces", m_Language:I18N("Debug Selection Raytraces"), p_Data.debugSelectionRaytraces, false, m_Language:I18N("Shows the last trace line and search area from Commo Rose selection"))
	settings:add("TRACE", "Float", "traceDelta", m_Language:I18N("Trace Delta time"), p_Data.traceDelta, 0.2, m_Language:I18N("update intervall of trace"))

	settings:add("EXPERT", "Float", "botFirstShotDelay", m_Language:I18N("First Shot Delay"), p_Data.botFirstShotDelay, 0.2, m_Language:I18N("delay for first shot"))
	settings:add("EXPERT", "Float", "botMinTimeShootAtPlayer", m_Language:I18N("Min Time Shoot"), p_Data.botMinTimeShootAtPlayer, 1.0, m_Language:I18N("the minimum time a Bot shoots at one player"))
	settings:add("EXPERT", "Float", "botFireModeDuration", m_Language:I18N("Fire Mode Duration"), p_Data.botFireModeDuration, 5.0, m_Language:I18N("the minimum time a Bot tries to shoot a player"))
	settings:add("EXPERT", "Float", "maximunYawPerSec", m_Language:I18N("Maximum Degree per Sec"), p_Data.maximunYawPerSec, 540, m_Language:I18N("in Degree. Maximum Rotaion-Movement of a Bot per second."))
	settings:add("EXPERT", "Float", "targetDistanceWayPoint", m_Language:I18N("Target Distance Way-Point"), p_Data.targetDistanceWayPoint, 1.2, m_Language:I18N("distance the bots have to reach to continue with next Waypoint."))
	settings:add("EXPERT", "Boolean", "keepOneSlotForPlayers", m_Language:I18N("Keep one Player-Slot"), p_Data.keepOneSlotForPlayers, true, m_Language:I18N("always keep one slot for new Players to join"))
	settings:add("EXPERT", "Integer", "distanceToSpawnBots", m_Language:I18N("Distance to Spawn Bots"), p_Data.distanceToSpawnBots, 30, m_Language:I18N("distance to spawn Bots away from players"))
	settings:add("EXPERT", "Float", "heightDistanceToSpawn", m_Language:I18N("Height to Spawn Bots"), p_Data.heightDistanceToSpawn, 2.5, m_Language:I18N("distance vertically, Bots should spawn away, if closer than distance"))
	settings:add("EXPERT", "Integer", "distanceToSpawnReduction", m_Language:I18N("Reduce Distance on Fail"), p_Data.distanceToSpawnReduction, 5, m_Language:I18N("reduce distance if not possible"))
	settings:add("EXPERT", "Integer", "maxTrysToSpawnAtDistance", m_Language:I18N("Max Retrys on Distance"), p_Data.maxTrysToSpawnAtDistance, 3, m_Language:I18N("try this often to spawn a bot away from players"))
	settings:add("EXPERT", "Float", "headShotFactorBots", m_Language:I18N("Factor for HeadShot"), p_Data.headShotFactorBots, 0.8, m_Language:I18N("Factor for damage if Bot does a headshot"))
	settings:add("EXPERT", "Boolean", "respawnWayBots", m_Language:I18N("Respawn Bots"), p_Data.respawnWayBots, true, m_Language:I18N("Bots on paths respawn if killed on startup"))
	settings:add("EXPERT", "Boolean", "attackWayBots", m_Language:I18N("Attack other players"), p_Data.attackWayBots, true, m_Language:I18N("Bots on paths attack player by default"))

	settings:add("OTHER", "Boolean", "disableChatCommands", m_Language:I18N("Disable Chat Commands"), p_Data.disableChatCommands, true, m_Language:I18N("if true, no chat commands can be used"))
	settings:add("OTHER", "Boolean", "traceUsageAllowed", m_Language:I18N("Allow Trace Usage"), p_Data.traceUsageAllowed, true, m_Language:I18N("if false, no traces can be recorded, deleted or saved"))
	settings:addList("OTHER", "language", m_Language:I18N("Language"), { "de_DE", "cn_CN", "en_US" }, p_Data.language, "en_US", m_Language:I18N("Select the language of this mod"))
	settings:add("OTHER", "Password", "settingsPassword", m_Language:I18N("Password"), p_Data.settingsPassword, nil, m_Language:I18N("Password protection of these Mod"))

	self._views:execute('BotEditor.openSettings(\'' .. settings:getJSON() .. '\')')
	self._views:show('settings')
	self._views:focus()
end

function FunBotUIClient:_onUIChangeLanguage(p_Language)
	if Config.DisableUserInterface == true then
		return
	end

	self._views:setLanguage(p_Language)
end

function FunBotUIClient:_onUISaveSettings(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Save_Settings (' .. p_Data .. ')')
	end

	NetEvents:Send('UI_Request_Save_Settings', p_Data)
end

function FunBotUIClient:_onBotEditorEvent(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: BotEditor (' .. p_Data .. ')')
	end

	-- Redirect to Server
	NetEvents:Send('BotEditor', p_Data)
end

function FunBotUIClient:_onUIShowToolbar(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Show_Toolbar (' .. tostring(p_Data) .. ')')
	end

	if (p_Data == 'true') then
		self._views:show('toolbar')
		self._views:focus()
	else
		self._views:hide('toolbar')
		self._views:blur()
	end
end

function FunBotUIClient:_onUIPasswordProtection(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Password_Protection (' .. tostring(p_Data) .. ')')
	end

	if (p_Data == 'true') then
		self._views:show('password_protection')
		self._views:focus()
	else
		self._views:hide('password_protection')
		self._views:blur()
	end
end

function FunBotUIClient:_onUIRequestPasswordError(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Request_Password_Error')
	end

	self._views:error('password', p_Data)
end

function FunBotUIClient:_onUIRequestPassword(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Request_Password (' .. tostring(p_Data) .. ')')
	end

	if (p_Data == 'true') then
		self._views:show('password')
		self._views:focus()
	else
		self._views:hide('password')
		self._views:blur()
	end
end

function FunBotUIClient:_onUISendPassword(p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Client.UI then
		print('UIClient: UI_Send_Password (' .. p_Data .. ')')
	end

	NetEvents:Send('UI_Request_Open', p_Data)
end

function FunBotUIClient:OnClientUpdateInput(p_DeltaTime)
	if Config.DisableUserInterface == true then
		return
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		if Debug.Client.UI then
			print('Client send: UI_Request_Open')
		end

		-- This request can use for UI-Toggle
		NetEvents:Send('UI_Request_Open')
	end
end

function FunBotUIClient:OnExtensionLoaded()
	self._views:OnExtensionLoaded()
end

function FunBotUIClient:OnExtensionUnloading()
	self._views:OnExtensionUnloading()
end

if g_FunBotUIClient == nil then
	g_FunBotUIClient = FunBotUIClient()
end

return g_FunBotUIClient
