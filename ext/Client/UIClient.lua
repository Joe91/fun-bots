class 'FunBotUIClient'

require('UIViews')
require('UISettings')
require('ClientNodeEditor')

local m_Language = require('__shared/Language')

function FunBotUIClient:__init()
	self._views = UIViews()
	self.m_InWaypointEditor = false
	self.m_LastWaypointEditorState = false

	if Config.DisableUserInterface ~= true then
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
		NetEvents:Subscribe('UI_Waypoints_Disable', self, self._onUIWaypointsEditorDisable)
		Events:Subscribe('UI_Waypoints_Disable', self, self._onUIWaypointsEditorDisable)
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
		--self._views:close()
	--else
		--self._views:open()
		--self._views:focus()
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
		self.m_InWaypointEditor = false
		self.m_LastWaypointEditorState = false
		NetEvents:Send('UI_CommoRose_Enabled', false)
		g_ClientNodeEditor:OnSetEnabled(false)
		g_ClientSpawnPointHelper:OnSetEnabled(false)
	else
		if Debug.Client.UI then
			print('UIClient: open UI_Waypoints_Editor')
		end

		Config.DebugTracePaths = true
		NetEvents:Send('UI_CommoRose_Enabled', true)
		g_ClientNodeEditor:OnSetEnabled(true)
		g_ClientSpawnPointHelper:OnSetEnabled(true)
		self._views:show('waypoint_toolbar')
		self._views:hide('toolbar')
		self.m_InWaypointEditor = true
		self.m_LastWaypointEditorState = false
		self._views:disable()
	end
end

function FunBotUIClient:_onUIWaypointsEditorDisable()
	if self.m_InWaypointEditor then
		self._views:disable()
	end
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

	for _, l_Item in pairs(SettingsDefinition.Elements) do
		local s_TypeString = ""
		if l_Item.Type == Type.Enum then
			-- create table out of Enum
			local s_EnumTable = {}
			local s_Default = ""
			local s_Value = ""
			for l_Key, l_Value in pairs(l_Item.Reference) do
				table.insert(s_EnumTable, l_Key)
				if l_Value == p_Data[l_Item.Name] then
					s_Value = l_Key
				end
				if l_Value == l_Item.Default then
					s_Default = l_Key
				end
			end
			settings:addList(l_Item.Category, l_Item.Name, l_Item.Text, s_EnumTable, s_Value, s_Default, l_Item.Description)
		elseif l_Item.Type == Type.Table then
			settings:addList(l_Item.Category, l_Item.Name, l_Item.Text, l_Item.Reference, p_Data[l_Item.Name], l_Item.Default, l_Item.Description)
		elseif l_Item.Type == Type.Integer then
			s_TypeString = "Integer"
			settings:add(l_Item.Category, s_TypeString, l_Item.Name, l_Item.Text, p_Data[l_Item.Name], l_Item.Default, l_Item.Description)
		elseif l_Item.Type == Type.Float then
			s_TypeString = "Float"
			settings:add(l_Item.Category, s_TypeString, l_Item.Name, l_Item.Text, p_Data[l_Item.Name], l_Item.Default, l_Item.Description)
		elseif l_Item.Type == Type.Boolean then
			s_TypeString = "Boolean"
			settings:add(l_Item.Category, s_TypeString, l_Item.Name, l_Item.Text, p_Data[l_Item.Name], l_Item.Default, l_Item.Description)
		elseif l_Item.Type == Type.String then
			s_TypeString = "Language"
			settings:add(l_Item.Category, s_TypeString, l_Item.Name, l_Item.Text, p_Data[l_Item.Name], l_Item.Default, l_Item.Description)
		end
	end



	-- settings:addList("GLOBAL", "BotWeapon", m_Language:I18N("Bot Weapon"), BotWeapons, p_Data.BotWeapon, "Auto", m_Language:I18N("Select the weapon the bots use"))
	-- settings:addList("GLOBAL", "BotKit", m_Language:I18N("Bot Kit"), BotKits, p_Data.BotKit, "RANDOM_KIT", m_Language:I18N("The Kit a bots spawns with."))
	-- settings:addList("GLOBAL", "BotColor", m_Language:I18N("Bot Color"), BotColors, p_Data.BotColor, "RANDOM_COLOR", m_Language:I18N("The Kit-Color a bots spawns with."))
	-- settings:add("GLOBAL", "Boolean", "ZombieMode", m_Language:I18N("Zombie Mode"), p_Data.ZombieMode, false, m_Language:I18N("Bots act like zombies"))

	-- settings:add("DIFFICULTY", "Float", "BotAimWorsening", m_Language:I18N("Aim Worsening"), p_Data.BotAimWorsening, 0.6, m_Language:I18N("0 = hard, 1 (or higher) = easy"))
	-- settings:add("DIFFICULTY", "Float", "BotSniperAimWorsening", m_Language:I18N("Aim Worsening Sniper"), p_Data.BotSniperAimWorsening, 0.2, m_Language:I18N("0 = hard, 1 (or higher) = easy"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorAssault", m_Language:I18N("Factor for Assault-Weapon-Damage"), p_Data.DamageFactorAssault, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorCarabine", m_Language:I18N("Factor for Carabine-Weapon-Damage"), p_Data.DamageFactorCarabine, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorPDW", m_Language:I18N("Factor for PDW-Weapon-Damage"), p_Data.DamageFactorPDW, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorLMG", m_Language:I18N("Factor for LMG-Weapon-Damage"), p_Data.DamageFactorLMG, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorSniper", m_Language:I18N("Factor for Sniper-Weapon-Damage"), p_Data.DamageFactorSniper, 0.8, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorShotgun", m_Language:I18N("Factor for Shotgun-Weapon-Damage"), p_Data.DamageFactorShotgun, 0.5, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorPistol", m_Language:I18N("Factor for Pistol-Weapon-Damage"), p_Data.DamageFactorPistol, 0.8, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))
	-- settings:add("DIFFICULTY", "Float", "DamageFactorKnife", m_Language:I18N("Factor for Knife-Weapon-Damage"), p_Data.DamageFactorKnife, 1.2, m_Language:I18N("Origninal Damage from bots gets multiplied by this"))

	-- settings:addList("SPAWN", "SpawnMode", m_Language:I18N("Spawn Mode"), SpawnModes, p_Data.SpawnMode, "increment_with_players", m_Language:I18N("Mode the bots spawn with"))
	-- settings:add("SPAWN", "Boolean", "SpawnInBothTeams", m_Language:I18N("Spawn in both teams"), p_Data.SpawnInBothTeams, true, m_Language:I18N("Bots spawn in both teams"))
	-- settings:add("SPAWN", "Integer", "InitNumberOfBots", m_Language:I18N("Number of Bots for Spawn-Mode"), p_Data.InitNumberOfBots, 5, m_Language:I18N("Bots for the spawnmode"))
	-- settings:add("SPAWN", "Integer", "NewBotsPerNewPlayer", m_Language:I18N("Number Bots on new Player"), p_Data.NewBotsPerNewPlayer, 2, m_Language:I18N("number to increase Bots, when new players join, if mode is selected"))
	-- settings:add("SPAWN", "Float", "SpawnDelayBots", m_Language:I18N("Respawn Delay"), p_Data.SpawnDelayBots, 10.0, m_Language:I18N("time till bots respawn, if respawn enabled"))
	-- settings:add("SPAWN", "Integer", "BotTeam", m_Language:I18N("Default Bot Team"), p_Data.BotTeam, 0, m_Language:I18N("default bot team. 0 = auto, 1 = US (forced), 2 = RU (forced)"))
	-- settings:add("SPAWN", "Boolean", "BotNewLoadoutOnSpawn", m_Language:I18N("New Loadout on Spawn"), p_Data.BotNewLoadoutOnSpawn, true, m_Language:I18N("bots get a new kit and color, if they respawn"))
	-- settings:add("SPAWN", "Integer", "MaxAssaultBots", m_Language:I18N("Max Assault Bots"), p_Data.MaxAssaultBots, -1, m_Language:I18N("maximum number of Bots with Assault Kit. -1 = unlimited"))
	-- settings:add("SPAWN", "Integer", "MaxEngineerBots", m_Language:I18N("Max Engineer Bots"), p_Data.MaxEngineerBots, -1, m_Language:I18N("maximum number of Bots with Engineer Kit. -1 = unlimited"))
	-- settings:add("SPAWN", "Integer", "MaxSupportBots", m_Language:I18N("Max Support Bots"), p_Data.MaxSupportBots, -1, m_Language:I18N("maximum number of Bots with Support Kit. -1 = unlimited"))
	-- settings:add("SPAWN", "Integer", "MaxReconBots", m_Language:I18N("Max Recon Bots"), p_Data.MaxReconBots, -1, m_Language:I18N("maximum number of Bots with Recon Kit. -1 = unlimited"))

	-- settings:add("WEAPONS", "Boolean", "UseRandomWeapon", m_Language:I18N("Random Weapon"), p_Data.UseRandomWeapon, true, m_Language:I18N("use a random weapon out of the class list"))
	-- settings:addList("WEAPONS", "Pistol", m_Language:I18N("Bot Pistol"), PistoWeapons, p_Data.Pistol, "M1911_Lit", m_Language:I18N("Pistol of Bots"))
	-- settings:addList("WEAPONS", "Knife", m_Language:I18N("Bot Knife"), KnifeWeapons, p_Data.Knife, "Razor", m_Language:I18N("Knife of Bots"))
	-- settings:addList("WEAPONS", "AssaultWeapon",  m_Language:I18N("Weapon Assault"), AssaultPrimary, p_Data.AssaultWeapon, "M416", m_Language:I18N("Weapon of Assault class"))
	-- settings:addList("WEAPONS", "EngineerWeapon",  m_Language:I18N("Weapon Engineer"), EngineerPrimary, p_Data.EngineerWeapon, "M4A1", m_Language:I18N("Weapon of Engineer class"))
	-- settings:addList("WEAPONS", "SupportWeapon",  m_Language:I18N("Weapon Support"), SupportPrimary, p_Data.SupportWeapon, "M249", m_Language:I18N("Weapon of Support class"))
	-- settings:addList("WEAPONS", "ReconWeapon",  m_Language:I18N("Weapon Recon"), ReconPrimary, p_Data.ReconWeapon, "L96_6x", m_Language:I18N("Weapon of Recon class"))
	-- settings:addList("WEAPONS", "AssaultWeaponSet",  m_Language:I18N("Weaponset of Assault"), WeaponSets, p_Data.AssaultWeaponSet, "Class", m_Language:I18N("Weaponset of Assault class"))
	-- settings:addList("WEAPONS", "EngineerWeaponSet",  m_Language:I18N("Weaponset Engineer"), WeaponSets, p_Data.EngineerWeaponSet, "Class_PDW", m_Language:I18N("Weaponset of Engineer class"))
	-- settings:addList("WEAPONS", "SupportWeaponSet",  m_Language:I18N("Weaponset Support"), WeaponSets, p_Data.SupportWeaponSet, "Class_Shotgun", m_Language:I18N("Weaponset of Support class"))
	-- settings:addList("WEAPONS", "ReconWeaponSet",  m_Language:I18N("Weaponset Recon"), WeaponSets, p_Data.ReconWeaponSet, "Class", m_Language:I18N("Weaponset of Recon class"))

	-- settings:add("BEHAVIOUR", "Integer", "FovForShooting", m_Language:I18N("Bot FOV"), p_Data.FovForShooting, 200, m_Language:I18N("The Field Of View of the bots, where they can detect a player"))
	-- settings:add("BEHAVIOUR", "Integer", "MaxRaycastDistance", m_Language:I18N("View Distance Bots"), p_Data.MaxRaycastDistance, 150, m_Language:I18N("The maximum distance a Sniper Bot starts shooting at a player"))
	-- settings:add("BEHAVIOUR", "Integer", "MaxShootDistanceNoSniper", m_Language:I18N("Attack Distance no Sniper"), p_Data.MaxShootDistanceNoSniper, 70, m_Language:I18N("The maximum distance a non Sniper Bot starts shooting at a player"))
	-- settings:addList("BEHAVIOUR", "BotAttackMode", m_Language:I18N("Bot Attack Mode"), BotAttackModes, p_Data.BotAttackMode, "Random", m_Language:I18N("Mode the Bots attack with. Crouch or Stand"))
	-- settings:add("BEHAVIOUR", "Boolean", "ShootBackIfHit", m_Language:I18N("Attack if Hit"), p_Data.ShootBackIfHit, true, m_Language:I18N("Bots imidiatly attack player, if shot by it"))
	-- settings:add("BEHAVIOUR", "Boolean", "BotsAttackBots", m_Language:I18N("Bots Attack Bots"), p_Data.BotsAttackBots, true, m_Language:I18N("Bots attack bots from other team"))
	-- settings:add("BEHAVIOUR", "Boolean", "MeleeAttackIfClose", m_Language:I18N("Attack with Melee"), p_Data.MeleeAttackIfClose, true, m_Language:I18N("Bots attack the playe with the knife, if close"))
	-- settings:add("BEHAVIOUR", "Boolean", "BotCanKillHimself", m_Language:I18N("Bots can kill themself"), p_Data.BotCanKillHimself, false, m_Language:I18N("If false, Bots take no fall or Frag damage"))

	-- settings:add("ADVANCED", "Float", "DistanceForDirectAttack", m_Language:I18N("Direct Attack Distance"), p_Data.DistanceForDirectAttack, 5, m_Language:I18N("When this close to a bot, he starts attacking"))
	-- settings:add("ADVANCED", "Integer", "MaxBotAttackBotDistance", m_Language:I18N("Distance Bot Bot attack"), p_Data.MaxBotAttackBotDistance, 30, m_Language:I18N("The maximum distance a Bot attacks an other Bot"))
	-- settings:add("ADVANCED", "Float", "MeleeAttackCoolDown", m_Language:I18N("Melee Cooldown"), p_Data.MeleeAttackCoolDown, 3, m_Language:I18N("the time a Bot waits before attacking with melee again"))
	-- settings:add("ADVANCED", "Boolean", "AimForHead", m_Language:I18N("Aim for Head"), p_Data.AimForHead, false, m_Language:I18N("Bots aim for the head. If false for the body"))
	-- settings:add("ADVANCED", "Boolean", "JumpWhileShooting", m_Language:I18N("Allow Jump while shooting"), p_Data.JumpWhileShooting, true, m_Language:I18N("Bots jump over obstacles while shooting"))
	-- settings:add("ADVANCED", "Boolean", "JumpWhileMoving", m_Language:I18N("Allow Jump while moving"), p_Data.JumpWhileMoving, true, m_Language:I18N("Bots jump while moving. If false, only on obstacles!"))
	-- settings:add("ADVANCED", "Integer", "OverWriteBotSpeedMode", m_Language:I18N("Overwrite Speed-Mode"), p_Data.OverWriteBotSpeedMode, 0, m_Language:I18N("0 = no overwrite. 1 = prone, 2 = crouch, 3 = walk, 4 = run"))
	-- settings:add("ADVANCED", "Integer", "OverWriteBotAttackMode", m_Language:I18N("Overwrite Attack-Speed-Mode"), p_Data.OverWriteBotAttackMode, 0, m_Language:I18N("!!Affects Aiming!!! 0 = no overwrite. 1 = prone, 2 = crouch (good aim), 3 = walk, 4 = run"))
	-- settings:add("ADVANCED", "Float", "SpeedFactor", m_Language:I18N("Speed Reduction"), p_Data.SpeedFactor, 1.0, m_Language:I18N("reduces the movementspeed. 1 = normal, 0.1 = slow"))
	-- settings:add("ADVANCED", "Float", "SpeedFactorAttack", m_Language:I18N("Speed Reduction Attack"), p_Data.SpeedFactorAttack, 0.6, m_Language:I18N("reduces the movementspeed while attacking. 1 = normal, 0.1 = slow."))

	-- settings:add("TRACE", "Boolean", "DebugTracePaths", m_Language:I18N("Debug Trace Paths"), p_Data.DebugTracePaths, false, m_Language:I18N("Enable Trace Path Editing and Visualizations"))
	-- settings:add("TRACE", "Integer", "WaypointRange", m_Language:I18N("Waypoint Range"), p_Data.WaypointRange, 100, m_Language:I18N("Set how far away waypoints are visible (meters)"))
	-- settings:add("TRACE", "Boolean", "DrawWaypointLines", m_Language:I18N("Draw Waypoint Lines"), p_Data.DrawWaypointLines, true, m_Language:I18N("Draw waypoint connection Lines"))
	-- settings:add("TRACE", "Integer", "LineRange", m_Language:I18N("Line Range"), p_Data.LineRange, 15, m_Language:I18N("Set how far away waypoint lines are visible (meters)"))
	-- settings:add("TRACE", "Boolean", "DrawWaypointIDs", m_Language:I18N("Draw Waypoint IDs"), p_Data.DrawWaypointIDs, true, m_Language:I18N("Draw waypoint IDs"))
	-- settings:add("TRACE", "Integer", "TextRange", m_Language:I18N("Text Range"), p_Data.TextRange, 3, m_Language:I18N("Set how far away waypoint text is visible (meters)"))
	-- settings:add("TRACE", "Boolean", "DebugSelectionRaytraces", m_Language:I18N("Debug Selection Raytraces"), p_Data.DebugSelectionRaytraces, false, m_Language:I18N("Shows the last trace line and search area from Commo Rose selection"))
	-- settings:add("TRACE", "Float", "TraceDelta", m_Language:I18N("Trace Delta time"), p_Data.TraceDelta, 0.2, m_Language:I18N("update intervall of trace"))

	-- settings:add("EXPERT", "Float", "BotFirstShotDelay", m_Language:I18N("First Shot Delay"), p_Data.BotFirstShotDelay, 0.2, m_Language:I18N("delay for first shot"))
	-- settings:add("EXPERT", "Float", "BotMinTimeShootAtPlayer", m_Language:I18N("Min Time Shoot"), p_Data.BotMinTimeShootAtPlayer, 1.0, m_Language:I18N("the minimum time a Bot shoots at one player"))
	-- settings:add("EXPERT", "Float", "BotFireModeDuration", m_Language:I18N("Fire Mode Duration"), p_Data.BotFireModeDuration, 5.0, m_Language:I18N("the minimum time a Bot tries to shoot a player"))
	-- settings:add("EXPERT", "Float", "MaximunYawPerSec", m_Language:I18N("Maximum Degree per Sec"), p_Data.MaximunYawPerSec, 540, m_Language:I18N("in Degree. Maximum Rotaion-Movement of a Bot per second."))
	-- settings:add("EXPERT", "Float", "TargetDistanceWayPoint", m_Language:I18N("Target Distance Way-Point"), p_Data.TargetDistanceWayPoint, 1.2, m_Language:I18N("distance the bots have to reach to continue with next Waypoint."))
	-- settings:add("EXPERT", "Boolean", "KeepOneSlotForPlayers", m_Language:I18N("Keep one Player-Slot"), p_Data.KeepOneSlotForPlayers, true, m_Language:I18N("always keep one slot for new Players to join"))
	-- settings:add("EXPERT", "Integer", "DistanceToSpawnBots", m_Language:I18N("Distance to Spawn Bots"), p_Data.DistanceToSpawnBots, 30, m_Language:I18N("distance to spawn Bots away from players"))
	-- settings:add("EXPERT", "Float", "HeightDistanceToSpawn", m_Language:I18N("Height to Spawn Bots"), p_Data.HeightDistanceToSpawn, 2.5, m_Language:I18N("distance vertically, Bots should spawn away, if closer than distance"))
	-- settings:add("EXPERT", "Integer", "DistanceToSpawnReduction", m_Language:I18N("Reduce Distance on Fail"), p_Data.DistanceToSpawnReduction, 5, m_Language:I18N("reduce distance if not possible"))
	-- settings:add("EXPERT", "Integer", "MaxTrysToSpawnAtDistance", m_Language:I18N("Max Retrys on Distance"), p_Data.MaxTrysToSpawnAtDistance, 3, m_Language:I18N("try this often to spawn a bot away from players"))
	-- settings:add("EXPERT", "Float", "HeadShotFactorBots", m_Language:I18N("Factor for HeadShot"), p_Data.HeadShotFactorBots, 0.8, m_Language:I18N("Factor for damage if Bot does a headshot"))
	-- settings:add("EXPERT", "Boolean", "RespawnWayBots", m_Language:I18N("Respawn Bots"), p_Data.RespawnWayBots, true, m_Language:I18N("Bots on paths respawn if killed on startup"))
	-- settings:add("EXPERT", "Boolean", "AttackWayBots", m_Language:I18N("Attack other players"), p_Data.AttackWayBots, true, m_Language:I18N("Bots on paths attack player by default"))

	-- settings:add("OTHER", "Boolean", "DisableChatCommands", m_Language:I18N("Disable Chat Commands"), p_Data.DisableChatCommands, true, m_Language:I18N("if true, no chat commands can be used"))
	-- settings:add("OTHER", "Boolean", "TraceUsageAllowed", m_Language:I18N("Allow Trace Usage"), p_Data.TraceUsageAllowed, true, m_Language:I18N("if false, no traces can be recorded, deleted or saved"))
	-- settings:addList("OTHER", "Language", m_Language:I18N("Language"), { "de_DE", "cn_CN", "en_US" }, p_Data.Language, "en_US", m_Language:I18N("Select the language of this mod"))
	
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

function FunBotUIClient:OnClientUpdateInput(p_DeltaTime)
	if Config.DisableUserInterface == true then
		return
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		if Debug.Client.UI then
			print('Client send: UI_Request_Open')
		end
		-- This request can be used for UI-Toggle
		if self.m_InWaypointEditor then
			if self.m_LastWaypointEditorState == false then
				self._views:enable()
				self.m_LastWaypointEditorState = true
			else
				self._views:disable()
				self.m_LastWaypointEditorState = false
			end
		else
			NetEvents:Send('UI_Request_Open')
		end
		return
	elseif InputManager:WentKeyUp(InputDeviceKeys.IDK_LeftAlt) and self.m_InWaypointEditor then
		self._views:enable()
		self.m_LastWaypointEditorState = true
	elseif InputManager:WentKeyDown(InputDeviceKeys.IDK_LeftAlt) and self.m_InWaypointEditor then
		self._views:disable()
		self.m_LastWaypointEditorState = false
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
