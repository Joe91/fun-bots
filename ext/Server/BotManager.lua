class('BotManager')

require('Bot')

local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("BotManager", Debug.Server.BOT)

function BotManager:__init()
	self._Bots = {}
	self._BotsByName = {}
	self._BotsByTeam = {{}, {}, {}, {}, {}} -- neutral, team1, team2, team3, team4
	self._BotInputs = {}
	self._ShooterBots = {}
	self._ActivePlayers = {}
	self._BotAttackBotTimer = 0
	self._DestroyBotsTimer = 0
	self._BotsToDestroy = {}
	self._BotCheckState = {}
	self._PendingAcceptRevives = {}
	self._LastBotCheckIndex = 1
	self._InitDone = false
end

function BotManager:registerActivePlayer(p_Player)
	self._ActivePlayers[p_Player.name] = true
end

function BotManager:getBotTeam()
	if Config.BotTeam ~= TeamId.TeamNeutral then
		return Config.BotTeam
	end

	local s_BotTeam
	local s_CountPlayers = {}

	for i = 1, Globals.NrOfTeams do
		s_CountPlayers[i] = 0
		local s_Players = PlayerManager:GetPlayersByTeam(i)

		for j = 1, #s_Players do
			if not m_Utilities:isBot(s_Players[j]) then
				s_CountPlayers[i] = s_CountPlayers[i] + 1
			end
		end
	end

	local s_LowestPlayerCount = 128

	for i = 1, Globals.NrOfTeams do
		if s_CountPlayers[i] < s_LowestPlayerCount then
			s_BotTeam = i
		end
	end

	return s_BotTeam
end

function BotManager:configGlobals()
	Globals.RespawnWayBots = Config.RespawnWayBots
	Globals.AttackWayBots = Config.AttackWayBots
	Globals.SpawnMode = Config.SpawnMode
	Globals.YawPerFrame = self:calcYawPerFrame()
	--self:killAll()
	local s_MaxPlayers = RCON:SendCommand('vars.maxPlayers')
	s_MaxPlayers = tonumber(s_MaxPlayers[2])

	if s_MaxPlayers ~= nil and s_MaxPlayers > 0 then
		Globals.MaxPlayers = s_MaxPlayers

		m_Logger:Write("there are ".. s_MaxPlayers .." slots on this server")
	else
		Globals.MaxPlayers = 127 -- only fallback. Should not happens
		m_Logger:Error("No Playercount found")
	end

	self._InitDone = true
end

function BotManager:calcYawPerFrame()
	local s_DeltaTime = 1.0/SharedUtils:GetTickrate()
	local s_DegreePerDeltaTime = Config.MaximunYawPerSec * s_DeltaTime
	return (s_DegreePerDeltaTime / 360.0) * 2 * math.pi
end

function BotManager:findNextBotName()
	for _,name in pairs(BotNames) do
		local s_Name = BOT_TOKEN .. name
		local s_SkipName = false

		for _, l_IgnoreName in pairs(Globals.IgnoreBotNames) do
			if s_Name == l_IgnoreName then
				s_SkipName = true
				break
			end
		end

		if not s_SkipName then
			local s_Bot = self:getBotByName(s_Name)

			if s_Bot == nil and PlayerManager:GetPlayerByName(s_Name) == nil then
				return s_Name
			elseif s_Bot ~= nil and s_Bot.m_Player.soldier == nil and s_Bot:GetSpawnMode() ~= BotSpawnModes.RespawnRandomPath then
				return s_Name
			end
		end
	end

	return nil
end

function BotManager:getBots(p_TeamId)
	if p_TeamId ~= nil then
		return self._BotInfo.team[p_TeamId + 1]
	else
		return self._Bots
	end
end

function BotManager:getBotCount()
	return #self._Bots
end

function BotManager:getActiveBotCount(p_TeamId)
	local s_Count = 0

	for _, l_Bot in pairs(self._Bots) do
		if not l_Bot:IsInactive() then
			if p_TeamId == nil or l_Bot.m_Player.teamId == p_TeamId then
				s_Count = s_Count + 1
			end
		end
	end

	return s_Count
end

function BotManager:getPlayers()
	local s_AllPlayers = PlayerManager:GetPlayers()
	local s_Players = {}

	for i = 1, #s_AllPlayers do
		if not m_Utilities:isBot(s_AllPlayers[i]) then
			table.insert(s_Players, s_AllPlayers[i])
		end
	end

	return s_Players
end

function BotManager:getPlayerCount()
	return PlayerManager:GetPlayerCount() - #self._Bots
end

function BotManager:getKitCount(p_Kit)
	local s_Count = 0

	for _, l_Bot in pairs(self._Bots) do
		if l_Bot.m_Kit == p_Kit then
			s_Count = s_Count + 1
		end
	end

	return s_Count
end

function BotManager:resetAllBots()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetVars()
	end
end

function BotManager:setStaticOption(p_Player, p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			if l_Bot:IsStaticMovement() then
				if p_Option == "mode" then
					l_Bot:SetMoveMode(p_Value)
				elseif p_Option == "speed" then
					l_Bot:SetSpeed(p_Value)
				end
			end
		end
	end
end

function BotManager:setOptionForAll(p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if p_Option == "shoot" then
			l_Bot:SetShoot(p_Value)
		elseif p_Option == "respawn" then
			l_Bot:SetRespawn(p_Value)
		elseif p_Option == "moveMode" then
			l_Bot:SetMoveMode(p_Value)
		end
	end
end

function BotManager:setOptionForPlayer(p_Player, p_Option, p_Value)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			if p_Option == "shoot" then
				l_Bot:SetShoot(p_Value)
			elseif p_Option == "respawn" then
				l_Bot:SetRespawn(p_Value)
			elseif p_Option == "moveMode" then
				l_Bot:SetMoveMode(p_Value)
			end
		end
	end
end

function BotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	for _, l_Bot in pairs(self._Bots) do
		l_Bot:OnUpdatePassPostFrame(p_DeltaTime)
	end

	if Config.BotsAttackBots and self._InitDone then
		if self._BotAttackBotTimer >= StaticConfig.BotAttackBotCheckInterval then
			self._BotAttackBotTimer = 0
			self:_checkForBotBotAttack()
		end
		self._BotAttackBotTimer = self._BotAttackBotTimer + p_DeltaTime
	end

	if #self._BotsToDestroy > 0 then
		if self._DestroyBotsTimer >= 0.05 then
			self._DestroyBotsTimer = 0
			self:destroyBot(table.remove(self._BotsToDestroy))
		end
		self._DestroyBotsTimer = self._DestroyBotsTimer + p_DeltaTime
	end

	-- accept revives
	for i, l_Botname in pairs(self._PendingAcceptRevives) do
		local s_BotPlayer = self:getBotByName(l_Botname)

		if s_BotPlayer ~= nil and s_BotPlayer.m_Player.soldier ~= nil then
			if s_BotPlayer.m_Player.soldier.health == 20 then
				s_BotPlayer.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				self._PendingAcceptRevives[i] = nil
			end
		else
			self._PendingAcceptRevives[i] = nil
		end
	end
end

function BotManager:_onHealthAction(p_Soldier, p_Action)
	if p_Action == HealthStateAction.OnRevive then -- 7
		if p_Soldier.player ~= nil then
			if m_Utilities:isBot(p_Soldier.player.name) then
				table.insert(self._PendingAcceptRevives, p_Soldier.player.name)
			end
		end
	end
end

function BotManager:_onGunSway(p_GunSway, p_Weapon, p_WeaponFiring, p_DeltaTime)
	if p_Weapon == nil then
		return
	end

	local s_Soldier = nil

	for _, l_Entity in pairs(p_Weapon.bus.parent.entities) do
		if l_Entity:Is('ServerSoldierEntity') then
			s_Soldier = SoldierEntity(l_Entity)
			break
		end
	end

	if s_Soldier == nil or s_Soldier.player == nil then
		return
	end

	local s_Bot = self:getBotByName(s_Soldier.player.name)

	if s_Bot ~= nil then
		local s_GunSwayData = GunSwayData(p_GunSway.data)

		if s_Soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
			p_GunSway.dispersionAngle = s_GunSwayData.stand.zoom.baseValue.minAngle
		elseif s_Soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			p_GunSway.dispersionAngle = s_GunSwayData.crouch.zoom.baseValue.minAngle
		elseif s_Soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			p_GunSway.dispersionAngle = s_GunSwayData.prone.zoom.baseValue.minAngle
		else
			return
		end
	end
end

function BotManager:_checkForBotBotAttack()
	-- not enough on either team and no players to use
	local s_TeamsWithPlayers = 0

	for i = 1, Globals.NrOfTeams do
		if #self._BotsByTeam[i + 1] > 0 then
			s_TeamsWithPlayers = s_TeamsWithPlayers + 1
		end
	end

	if s_TeamsWithPlayers < 2 then
		return
	end

	local s_Players = self:getPlayers()
	local s_PlayerCount = #s_Players

	if s_PlayerCount < 1 then
		return
	end

	local s_Raycasts = 0
	local s_NextPlayerIndex = 1

	for i = self._LastBotCheckIndex, #self._Bots do
		local s_Bot = self._Bots[i]

		-- bot has player, is alive, and hasn't found that special someone yet
		if s_Bot ~= nil and s_Bot.m_Player and s_Bot.m_Player.alive and not self._BotCheckState[s_Bot.m_Player.name] then
			local s_OpposingTeams = {}

			for l_TeamId = 1, Globals.NrOfTeams do
				if s_Bot.m_Player.teamId ~= l_TeamId then
					table.insert(s_OpposingTeams, l_TeamId)
				end
			end

			for _, s_OpposingTeam in pairs(s_OpposingTeams) do
				-- search only opposing team
				for _, l_Bot in pairs(self._BotsByTeam[s_OpposingTeam + 1]) do
					-- make sure it's living and has no target
					if (l_Bot ~= nil and l_Bot.m_Player ~= nil and l_Bot.m_Player.alive and not self._BotCheckState[l_Bot.m_Player.name]) then
						local s_Distance = s_Bot.m_Player.soldier.worldTransform.trans:Distance(l_Bot.m_Player.soldier.worldTransform.trans)

						if s_Distance <= Config.MaxBotAttackBotDistance then
							-- choose a player at random, try until an active player is found
							for l_PlayerIndex = s_NextPlayerIndex, s_PlayerCount do
								if self._ActivePlayers[s_Players[l_PlayerIndex].name] then
									-- check this bot view. Let one client do it
									local s_BotPosition = s_Bot.m_Player.soldier.worldTransform.trans:Clone()
									local l_BotPosition = l_Bot.m_Player.soldier.worldTransform.trans:Clone()
									local s_InVehicle = (s_Bot.m_InVehicle or l_Bot.m_InVehicle)

									NetEvents:SendUnreliableToLocal('CheckBotBotAttack', s_Players[l_PlayerIndex], s_BotPosition, l_BotPosition, s_Bot.m_Player.name, l_Bot.m_Player.name, s_InVehicle)
									s_Raycasts = s_Raycasts + 1
									s_NextPlayerIndex = l_PlayerIndex + 1
									break
								end
							end

							if s_Raycasts >= s_PlayerCount then
								-- leave the function early for this cycle
								self._LastBotCheckIndex = i + 1
								return
							end
						end
					end
				end
			end
		end

		self._LastBotCheckIndex = i
	end

	-- should only reach here if every connection has been checked
	-- clear the cache and start over
	self._LastBotCheckIndex = 1
	self._BotCheckState = {}
end

function BotManager:OnPlayerLeft(p_Player)
	--remove all references of player
	if p_Player ~= nil then
		for _, l_Bot in pairs(self._Bots) do
			l_Bot:ClearPlayer(p_Player)
		end
	end
end

function BotManager:_getDamageValue(p_Damage, p_Bot, p_Soldier, p_Fake)
	local s_ResultDamage = 0
	local s_DamageFactor = 1.0

	if p_Bot.m_ActiveWeapon.type == WeaponTypes.Shotgun then
		s_DamageFactor = Config.DamageFactorShotgun
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Assault then
		s_DamageFactor = Config.DamageFactorAssault
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Carabine then
		s_DamageFactor = Config.DamageFactorCarabine
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.PDW then
		s_DamageFactor = Config.DamageFactorPDW
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.LMG then
		s_DamageFactor = Config.DamageFactorLMG
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Sniper then
		s_DamageFactor = Config.DamageFactorSniper
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Pistol then
		s_DamageFactor = Config.DamageFactorPistol
	elseif p_Bot.m_ActiveWeapon.type == WeaponTypes.Knife then
		s_DamageFactor = Config.DamageFactorKnife
	end

	if not p_Fake then -- frag mode
		s_ResultDamage = p_Damage * s_DamageFactor
	else
		if p_Damage <= 2 then
			local s_Distance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Soldier.worldTransform.trans)

			if s_Distance >= p_Bot.m_ActiveWeapon.damageFalloffEndDistance then
				s_ResultDamage = p_Bot.m_ActiveWeapon.endDamage
			elseif s_Distance <= p_Bot.m_ActiveWeapon.damageFalloffStartDistance then
				s_ResultDamage = p_Bot.m_ActiveWeapon.damage
			else -- extrapolate damage
				local s_RelativePosition = (s_Distance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance) / (p_Bot.m_ActiveWeapon.damageFalloffEndDistance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance)
				s_ResultDamage = p_Bot.m_ActiveWeapon.damage - (s_RelativePosition * (p_Bot.m_ActiveWeapon.damage - p_Bot.m_ActiveWeapon.endDamage))
			end

			if p_Damage == 2 then
				s_ResultDamage = s_ResultDamage * Config.HeadShotFactorBots
			end

			s_ResultDamage = s_ResultDamage * s_DamageFactor
		elseif p_Damage == 3 then -- melee
			s_ResultDamage = p_Bot.m_Knife.damage * Config.DamageFactorKnife
		end
	end

	return s_ResultDamage
end

function BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	-- soldier -> soldier damage only
	if p_Soldier.player == nil then
		return
	end

	local s_SoldierIsBot = m_Utilities:isBot(p_Soldier.player)

	if s_SoldierIsBot and p_GiverInfo.giver ~= nil then
		--detect if we need to shoot back
		if Config.ShootBackIfHit and p_Info.damage > 0 then
			self:OnShootAt(p_GiverInfo.giver, p_Soldier.player.name, true)
		end

		-- prevent bots from killing themselves. Bad bot, no suicide.
		if not Config.BotCanKillHimself and p_Soldier.player == p_GiverInfo.giver then
			p_Info.damage = 0
		end
	end

	--find out, if a player was hit by the server:
	if not s_SoldierIsBot then
		if p_GiverInfo.giver == nil then
			local s_Bot = self:getBotByName(self._ShooterBots[p_Soldier.player.name])

			if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil and p_Info.damage > 0 then
				p_Info.damage = self:_getDamageValue(p_Info.damage, s_Bot, p_Soldier, true)
				p_Info.boneIndex = 0
				p_Info.isBulletDamage = true
				p_Info.position = Vec3(p_Soldier.worldTransform.trans.x, p_Soldier.worldTransform.trans.y + 1, p_Soldier.worldTransform.trans.z)
				p_Info.direction = p_Soldier.worldTransform.trans - s_Bot.m_Player.soldier.worldTransform.trans
				p_Info.origin = s_Bot.m_Player.soldier.worldTransform.trans
				if (p_Soldier.health - p_Info.damage) <= 0 then
					if Globals.IsTdm then
						local s_EnemyTeam = TeamId.Team1

						if p_Soldier.player.teamId == TeamId.Team1 then
							s_EnemyTeam = TeamId.Team2
						end

						TicketManager:SetTicketCount(s_EnemyTeam, (TicketManager:GetTicketCount(s_EnemyTeam) + 1))
					end
				end
			end
		else
			--valid bot-damage?
			local s_Bot = self:getBotByName(p_GiverInfo.giver.name)

			if s_Bot ~= nil and s_Bot.m_Player.soldier ~= nil then
				-- giver was a bot
				p_Info.damage = self:_getDamageValue(p_Info.damage, s_Bot, p_Soldier, false)
			end
		end
	end

	p_HookCtx:Pass(p_Soldier, p_Info, p_GiverInfo)
end

function BotManager:OnServerDamagePlayer(p_PlayerName, p_ShooterName, p_MeleeAttack)
	local s_Player = PlayerManager:GetPlayerByName(p_PlayerName)

	if s_Player ~= nil then
		self:OnDamagePlayer(s_Player, p_ShooterName, p_MeleeAttack, false)
	end
end

function BotManager:OnDamagePlayer(p_Player, p_ShooterName, p_MeleeAttack, p_IsHeadShot)
	local s_Bot = self:getBotByName(p_ShooterName)

	if not p_Player.alive or s_Bot == nil then
		return
	end

	if p_Player.teamId == s_Bot.m_Player.teamId then
		return
	end

	local s_Damage = 1 --only trigger soldier-damage with this

	if p_IsHeadShot then
		s_Damage = 2 -- singal Headshot
	elseif p_MeleeAttack then
		s_Damage = 3 --signal melee damage with this value
	end

	--save potential killer bot
	self._ShooterBots[p_Player.name] = p_ShooterName

	if p_Player.soldier ~= nil then
		p_Player.soldier.health = p_Player.soldier.health - s_Damage
	end
end

function BotManager:OnShootAt(p_Player, p_BotName, p_IgnoreYaw)
	local s_Bot = self:getBotByName(p_BotName)

	if s_Bot == nil or s_Bot.m_Player == nil or s_Bot.m_Player.soldier == nil or p_Player == nil then
		return
	end

	s_Bot:ShootAt(p_Player, p_IgnoreYaw)
end

function BotManager:OnRevivePlayer(p_Player, p_BotName)
	local s_Bot = self:getBotByName(p_BotName)

	if s_Bot == nil or s_Bot.m_Player == nil or s_Bot.m_Player.soldier == nil or p_Player == nil then
		return
	end

	s_Bot:Revive(p_Player)
end

function BotManager:OnBotShootAtBot(p_Player, p_BotName1, p_BotName2)
	local s_Bot1 = self:getBotByName(p_BotName1)
	local s_Bot2 = self:getBotByName(p_BotName2)

	if s_Bot1 == nil or s_Bot1.m_Player == nil or s_Bot2 == nil or s_Bot2.m_Player == nil then
		return
	end

	if s_Bot1:ShootAt(s_Bot2.m_Player, false) or s_Bot2:ShootAt(s_Bot1.m_Player, false) then
		self._BotCheckState[s_Bot1.m_Player.name] = s_Bot2.m_Player.name
		self._BotCheckState[s_Bot2.m_Player.name] = s_Bot1.m_Player.name
	else
		self._BotCheckState[s_Bot1.m_Player.name] = nil
		self._BotCheckState[s_Bot2.m_Player.name] = nil
	end
end

function BotManager:OnLevelDestroy()
	m_Logger:Write("destroyLevel")

	self:resetAllBots()
	self._ActivePlayers = {}
	self._InitDone = false
	--self:killAll() -- this crashes when the server ended. do it on levelstart instead
end

function BotManager:getBotByName(p_Name)
	return self._BotsByName[p_Name]
end

function BotManager:createBot(p_Name, p_TeamId, p_SquadId)
	--m_Logger:Write('botsByTeam['..#self._BotsByTeam[2]..'|'..#self._BotsByTeam[3]..']')

	local s_Bot = self:getBotByName(p_Name)

	if s_Bot ~= nil then
		s_Bot.m_Player.teamId = p_TeamId
		s_Bot.m_Player.squadId = p_SquadId
		s_Bot:ResetVars()
		return s_Bot
	end

	-- check for max-players
	local s_PlayerLimit = Globals.MaxPlayers

	if Config.KeepOneSlotForPlayers then
		s_PlayerLimit = s_PlayerLimit - 1
	end

	if s_PlayerLimit <= PlayerManager:GetPlayerCount() then
		m_Logger:Write("playerlimit reached")
		return
	end

	-- Create a player for this bot.
	local s_BotPlayer = PlayerManager:CreatePlayer(p_Name, p_TeamId, p_SquadId)

	if s_BotPlayer == nil then
		m_Logger:Write("can't create more players on this team")
		return
	end

	-- Create input for this bot.
	local s_BotInput = EntryInput()
	s_BotInput.deltaTime = 1.0 / SharedUtils:GetTickrate()
	s_BotInput.flags = EntryInputFlags.AuthoritativeAiming
	s_BotPlayer.input = s_BotInput

	s_Bot = Bot(s_BotPlayer)

	local teamLookup = s_Bot.m_Player.teamId + 1
	table.insert(self._Bots, s_Bot)
	self._BotsByTeam[teamLookup] = self._BotsByTeam[teamLookup] or {}
	table.insert(self._BotsByTeam[teamLookup], s_Bot)
	self._BotsByName[p_Name] = s_Bot
	self._BotInputs[s_BotPlayer.id] = s_BotInput -- bot inputs are stored to prevent garbage collection
	return s_Bot
end


function BotManager:spawnBot(p_Bot, p_Transform, p_Pose, p_SoldierBp, p_Kit, p_Unlocks)
	if p_Bot.m_Player.soldier ~= nil then
		p_Bot.m_Player.soldier:Kill()
	end

	p_Bot.m_Player:SelectUnlockAssets(p_Kit, p_Unlocks)
	local s_BotSoldier = p_Bot.m_Player:CreateSoldier(p_SoldierBp, p_Transform)
	p_Bot.m_Player:SpawnSoldierAt(s_BotSoldier, p_Transform, p_Pose)
	p_Bot.m_Player:AttachSoldier(s_BotSoldier)

	return s_BotSoldier
end

function BotManager:killPlayerBots(p_Player)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			l_Bot:ResetVars()

			if l_Bot.m_Player.alive then
				l_Bot.m_Player.soldier:Kill()
			end
		end
	end
end

function BotManager:resetAllBots()
	for _, l_Bot in pairs(self._Bots) do
		l_Bot:ResetVars()
	end
end

function BotManager:killAll(p_Amount, p_TeamId)
	local s_BotTable = self._Bots

	if p_TeamId ~= nil then
		s_BotTable = self._BotsByTeam[p_TeamId + 1]
	end

	p_Amount = p_Amount or #s_BotTable

	for _, l_Bot in pairs(s_BotTable) do
		l_Bot:Kill()

		p_Amount = p_Amount - 1

		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:destroyAll(p_Amount, p_TeamId, p_Force)
	local s_BotTable = self._Bots

	if p_TeamId ~= nil then
		s_BotTable = self._BotsByTeam[p_TeamId + 1]
	end

	p_Amount = p_Amount or #s_BotTable

	for _, l_Bot in pairs(s_BotTable) do
		if p_Force then
			self:destroyBot(l_Bot)
		else
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end

		p_Amount = p_Amount - 1

		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:destroyDisabledBots()
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:IsInactive() then
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end
	end
end

function BotManager:destroyPlayerBots(p_Player)
	for _, l_Bot in pairs(self._Bots) do
		if l_Bot:GetTargetPlayer() == p_Player then
			table.insert(self._BotsToDestroy, l_Bot.m_Name)
		end
	end
end

function BotManager:freshnTables()
	local s_NewTeamsTable = {{},{},{},{},{}}
	local s_NewBotTable = {}
	local s_NewBotbyNameTable = {}

	for _,l_Bot in pairs(self._Bots) do
		if l_Bot.m_Player ~= nil then
			table.insert(s_NewBotTable, l_Bot)
			table.insert(s_NewTeamsTable[l_Bot.m_Player.teamId + 1], l_Bot)
			s_NewBotbyNameTable[l_Bot.m_Player.name] = l_Bot
		end
	end

	self._Bots = s_NewBotTable
	self._BotsByTeam = s_NewTeamsTable
	self._BotsByName = s_NewBotbyNameTable
end

function BotManager:destroyBot(p_Bot)
	if type(p_Bot) == 'string' then
		p_Bot = self._BotsByName[p_Bot]
	end

	-- Bot was not found.
	if p_Bot == nil then
		return
	end

	-- Find index of this bot.
	local s_NewTable = {}

	for _, l_Bot in pairs(self._Bots) do
		if p_Bot.m_Name ~= l_Bot.m_Name then
			table.insert(s_NewTable, l_Bot)
		end

		l_Bot:ClearPlayer(p_Bot.m_Player)
	end

	self._Bots = s_NewTable

	local s_NewTeamsTable = {}

	for _, l_Bot in pairs(self._BotsByTeam[p_Bot.m_Player.teamId + 1]) do
		if p_Bot.m_Name ~= l_Bot.m_Name then
			table.insert(s_NewTeamsTable, l_Bot)
		end
	end

	self._BotsByTeam[p_Bot.m_Player.teamId+1] = s_NewTeamsTable
	self._BotsByName[p_Bot.m_Name] = nil
	self._BotInputs[p_Bot.m_Id] = nil

	p_Bot:Destroy()
	p_Bot = nil
end

if g_BotManager == nil then
	g_BotManager = BotManager()
end

return g_BotManager
