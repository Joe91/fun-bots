class('BotManager')

require('Bot')

local m_Utilities = require('__shared/Utilities')
local m_Logger = Logger("BotManager", Debug.Server.BOT)

function BotManager:__init()
	self._bots = {}
	self._botsByName = {}
	self._botsByTeam = {{}, {}, {}, {}, {}} -- neutral, team1, team2, team3, team4
	self._botInputs = {}
	self._shooterBots = {}
	self._activePlayers = {}
	self._botAttackBotTimer = 0
	self._destroyBotsTimer = 0
	self._botsToDestroy = {}
	self._botCheckState = {}
	self._pendingAcceptRevives = {}
	self._lastBotCheckIndex = 1
	self._initDone = false
end

function BotManager:registerActivePlayer(p_Player)
	self._activePlayers[p_Player.name] = true
end

function BotManager:getBotTeam()
	if Config.BotTeam ~= TeamId.TeamNeutral then
		return Config.BotTeam
	end
	local botTeam
	local countPlayers = {}
	for i = 1, Globals.NrOfTeams do
		countPlayers[i] = 0
		local players = PlayerManager:GetPlayersByTeam(i)
		for i = 1, #players do
			if m_Utilities:isBot(players[i]) == false then
				countPlayers[i] = countPlayers[i] + 1
			end
		end
	end

	local lowestPlayerCount = 128
	for i = 1, Globals.NrOfTeams do
		if countPlayers[i] < lowestPlayerCount then
			botTeam = i
		end
	end

	return botTeam
end

function BotManager:configGlobals()
	Globals.RespawnWayBots = Config.RespawnWayBots
	Globals.AttackWayBots = Config.AttackWayBots
	Globals.SpawnMode = Config.SpawnMode
	Globals.YawPerFrame = self:calcYawPerFrame()
	--self:killAll()
	local maxPlayers = RCON:SendCommand('vars.maxPlayers')
	maxPlayers = tonumber(maxPlayers[2])
	if maxPlayers ~= nil and maxPlayers > 0 then
		Globals.MaxPlayers = maxPlayers

		m_Logger:Write("there are "..maxPlayers.." slots on this server")
	else
		Globals.MaxPlayers = MAX_NUMBER_OF_BOTS --only fallback
	end
	self._initDone = true
end

function BotManager:calcYawPerFrame()
	local dt = 1.0/SharedUtils:GetTickrate()
	local degreePerDt = Config.MaximunYawPerSec * dt
	return (degreePerDt / 360.0) * 2 * math.pi
end

function BotManager:findNextBotName()
	for i = 1, MAX_NUMBER_OF_BOTS do
		local name = BOT_TOKEN..BotNames[i]
		local skipName = false
		for _,ignoreName in pairs(Globals.IgnoreBotNames) do
			if name == ignoreName then
				skipName = true
				break
			end
		end
		if not skipName then
			local bot = self:getBotByName(name)
			if bot == nil and PlayerManager:GetPlayerByName(name) == nil then
				return name
			elseif bot ~= nil and bot.m_Player.soldier == nil and bot:getSpawnMode() < 4 then
				return name
			end
		end
	end
	return nil
end

function BotManager:getBots(p_TeamId)
	if (p_TeamId ~= nil) then
		return self._botInfo.team[p_TeamId+1]
	else
		return self._bots
	end
end

function BotManager:getBotCount()
	return #self._bots
end

function BotManager:getActiveBotCount(p_TeamId)
	local count = 0
	for _, bot in pairs(self._bots) do
		if not bot:isInactive() then
			if p_TeamId == nil or bot.m_Player.teamId == p_TeamId then
				count = count + 1
			end
		end
	end
	return count
end

function BotManager:getPlayers()
	local allPlayers = PlayerManager:GetPlayers()
	local players = {}

	for i=1, #allPlayers do
		if not m_Utilities:isBot(allPlayers[i]) then
			table.insert(players, allPlayers[i])
		end
	end
	return players
end

function BotManager:getPlayerCount()
	return PlayerManager:GetPlayerCount() - #self._bots
end

function BotManager:getKitCount(p_Kit)
	local count = 0
	for _, bot in pairs(self._bots) do
		if bot.m_Kit == p_Kit then
			count = count + 1
		end
	end
	return count
end

function BotManager:resetAllBots()
	for _, bot in pairs(self._bots) do
		bot:resetVars()
	end
end

function BotManager:setStaticOption(p_Player, p_Option, p_Value)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == p_Player then
			if bot:isStaticMovement() then
				if p_Option == "mode" then
					bot:setMoveMode(p_Value)
				elseif p_Option == "speed" then
					bot:setSpeed(p_Value)
				end
			end
		end
	end
end

function BotManager:setOptionForAll(p_Option, p_Value)
	for _, bot in pairs(self._bots) do
		if p_Option == "shoot" then
			bot:setShoot(p_Value)
		elseif p_Option == "respawn" then
			bot:setRespawn(p_Value)
		elseif p_Option == "moveMode" then
			bot:setMoveMode(p_Value)
		end
	end
end

function BotManager:setOptionForPlayer(p_Player, p_Option, p_Value)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == p_Player then
			if p_Option == "shoot" then
				bot:setShoot(p_Value)
			elseif p_Option == "respawn" then
				bot:setRespawn(p_Value)
			elseif p_Option == "moveMode" then
				bot:setMoveMode(p_Value)
			end
		end
	end
end

function BotManager:OnUpdateManagerUpdate(p_DeltaTime, p_UpdatePass)
	if p_UpdatePass ~= UpdatePass.UpdatePass_PostFrame then
		return
	end

	for _, bot in pairs(self._bots) do
		bot:onUpdate(p_DeltaTime)
	end

	if Config.BotsAttackBots and self._initDone then
		if self._botAttackBotTimer >= StaticConfig.BotAttackBotCheckInterval then
			self._botAttackBotTimer = 0
			self:_checkForBotBotAttack()
		end
		self._botAttackBotTimer = self._botAttackBotTimer + p_DeltaTime
	end

	if #self._botsToDestroy > 0 then
		if self._destroyBotsTimer >= 0.05 then
			self._destroyBotsTimer = 0
			self:destroyBot(table.remove(self._botsToDestroy))
		end
		self._destroyBotsTimer = self._destroyBotsTimer + p_DeltaTime
	end

	-- accept revives
	for i, botname in pairs(self._pendingAcceptRevives) do
		local botPlayer = self:getBotByName(botname)
		if botPlayer ~= nil and botPlayer.m_Player.soldier ~= nil then
			if botPlayer.m_Player.soldier.health == 20 then
				botPlayer.m_Player.soldier:SetPose(CharacterPoseType.CharacterPoseType_Stand, true, true)
				self._pendingAcceptRevives[i] = nil
			end
		else
			self._pendingAcceptRevives[i] = nil
		end
	end
end

function BotManager:_onHealthAction(p_Soldier, p_Action)
	if p_Action == HealthStateAction.OnRevive then --7
		if p_Soldier.player ~= nil then
			if m_Utilities:isBot(p_Soldier.player.name) then
				table.insert(self._pendingAcceptRevives, p_Soldier.player.name)
			end
		end
    end
end

function BotManager:_onGunSway(p_GunSway, p_Weapon, p_WeaponFiring, p_DeltaTime)
	if p_Weapon == nil then
		return
	end
	local soldier = nil
	for _,entity in pairs(p_Weapon.bus.parent.entities) do
		if entity:Is('ServerSoldierEntity') then
			soldier = SoldierEntity(entity)
			break
		end
	end
	if soldier == nil or soldier.player == nil then
		return
	end
	local bot = self:getBotByName(soldier.player.name)
	if bot ~= nil then
		local gunSwayData = GunSwayData(p_GunSway.data)
		if soldier.pose == CharacterPoseType.CharacterPoseType_Stand then
			p_GunSway.dispersionAngle = gunSwayData.stand.zoom.baseValue.minAngle
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Crouch then
			p_GunSway.dispersionAngle = gunSwayData.crouch.zoom.baseValue.minAngle
		elseif soldier.pose == CharacterPoseType.CharacterPoseType_Prone then
			p_GunSway.dispersionAngle = gunSwayData.prone.zoom.baseValue.minAngle
		else
			return
		end
	end
end

function BotManager:_checkForBotBotAttack()

	-- not enough on either team and no players to use
	local teamsWithPlayers = 0
	for i = 1, Globals.NrOfTeams do
		if #self._botsByTeam[i+1] > 0 then
			teamsWithPlayers = teamsWithPlayers + 1
		end
	end
	if teamsWithPlayers < 2 then
		return
	end

	local players = self:getPlayers()
	local playerCount = #players

	if (playerCount < 1) then
		return
	end

	local raycasts = 0
	local nextPlayerIndex = 1

	for i=self._lastBotCheckIndex, #self._bots do

		local bot = self._bots[i]

		-- bot has player, is alive, and hasn't found that special someone yet
		if (bot ~= nil and bot.m_Player and bot.m_Player.alive and not self._botCheckState[bot.m_Player.name]) then

			local opposingTeams = {}
			for t = 1, Globals.NrOfTeams do
				if bot.m_Player.teamId ~= t then
					table.insert(opposingTeams, t)
				end
			end
			for _,opposingTeam in pairs(opposingTeams) do
				-- search only opposing team
				for _, bot2 in pairs(self._botsByTeam[opposingTeam+1]) do

					-- make sure it's living and has no target
					if (bot2 ~= nil and bot2.m_Player ~= nil and bot2.m_Player.alive and not self._botCheckState[bot2.m_Player.name]) then

						local distance = bot.m_Player.soldier.worldTransform.trans:Distance(bot2.m_Player.soldier.worldTransform.trans)
						if distance <= Config.MaxBotAttackBotDistance then

							-- choose a player at random, try until an active player is found
							for playerIndex = nextPlayerIndex, playerCount do
								if self._activePlayers[players[playerIndex].name] then

									-- check this bot view. Let one client do it
									local pos1 = bot.m_Player.soldier.worldTransform.trans:Clone()
									local pos2 = bot2.m_Player.soldier.worldTransform.trans:Clone()
									local inVehicle =  (bot.m_Player.attachedControllable ~= nil or bot2.m_Player.attachedControllable ~= nil)

									NetEvents:SendUnreliableToLocal('CheckBotBotAttack', players[playerIndex], pos1, pos2, bot.m_Player.name, bot2.m_Player.name, inVehicle)
									raycasts = raycasts + 1
									nextPlayerIndex = playerIndex + 1
									break
								end
							end

							if (raycasts >= playerCount) then
								-- leave the function early for this cycle
								self._lastBotCheckIndex = i+1
								return
							end
						end
					end
				end
			end
		end
		self._lastBotCheckIndex = i
	end
	-- should only reach here if every connection has been checked
	-- clear the cache and start over
	self._lastBotCheckIndex = 1
	self._botCheckState = {}
end

function BotManager:OnPlayerLeft(p_Player)
	--remove all references of player
	if p_Player ~= nil then
		for _, bot in pairs(self._bots) do
			bot:clearPlayer(p_Player)
		end
	end
end

function BotManager:_getDamageValue(p_Damage, p_Bot, p_Soldier, p_Fake)
	local resultDamage = 0
	local damageFactor = 1.0

	if p_Bot.m_ActiveWeapon.type == "Shotgun" then
		damageFactor = Config.DamageFactorShotgun
	elseif p_Bot.m_ActiveWeapon.type == "Assault" then
		damageFactor = Config.DamageFactorAssault
	elseif p_Bot.m_ActiveWeapon.type == "Carabine" then
		damageFactor = Config.DamageFactorCarabine
	elseif p_Bot.m_ActiveWeapon.type == "PDW" then
		damageFactor = Config.DamageFactorPDW
	elseif p_Bot.m_ActiveWeapon.type == "LMG" then
		damageFactor = Config.DamageFactorLMG
	elseif p_Bot.m_ActiveWeapon.type == "Sniper" then
		damageFactor = Config.DamageFactorSniper
	elseif p_Bot.m_ActiveWeapon.type == "Pistol" then
		damageFactor = Config.DamageFactorPistol
	elseif p_Bot.m_ActiveWeapon.type == "Knife" then
		damageFactor = Config.DamageFactorKnife
	end

	if not p_Fake then -- frag mode
		resultDamage = p_Damage * damageFactor
	else
		if p_Damage <= 2 then
			local distance = p_Bot.m_Player.soldier.worldTransform.trans:Distance(p_Soldier.worldTransform.trans)
			if distance >= p_Bot.m_ActiveWeapon.damageFalloffEndDistance then
				resultDamage = p_Bot.m_ActiveWeapon.endDamage
			elseif distance <= p_Bot.m_ActiveWeapon.damageFalloffStartDistance then
				resultDamage =  p_Bot.m_ActiveWeapon.damage
			else --extrapolate damage
				local relativePosion = (distance-p_Bot.m_ActiveWeapon.damageFalloffStartDistance)/(p_Bot.m_ActiveWeapon.damageFalloffEndDistance - p_Bot.m_ActiveWeapon.damageFalloffStartDistance)
				resultDamage = p_Bot.m_ActiveWeapon.damage - (relativePosion * (p_Bot.m_ActiveWeapon.damage-p_Bot.m_ActiveWeapon.endDamage))
			end
			if p_Damage == 2 then
				resultDamage = resultDamage * Config.HeadShotFactorBots
			end

			resultDamage = resultDamage * damageFactor
		elseif p_Damage == 3 then --melee
			resultDamage = p_Bot.m_Knife.damage * Config.DamageFactorKnife
		end
	end
	return resultDamage
end

function BotManager:OnSoldierDamage(p_HookCtx, p_Soldier, p_Info, p_GiverInfo)
	-- soldier -> soldier damage only
	if p_Soldier.player == nil then
		return
	end

	local soldierIsBot = m_Utilities:isBot(p_Soldier.player)
	if soldierIsBot and p_GiverInfo.giver ~= nil then
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
	if not soldierIsBot then
		if p_GiverInfo.giver == nil then
			local bot = self:getBotByName(self._shooterBots[p_Soldier.player.name])
			if bot ~= nil and bot.m_Player.soldier ~= nil and p_Info.damage > 0 then
				p_Info.damage = self:_getDamageValue(p_Info.damage, bot, p_Soldier, true)
				p_Info.boneIndex = 0
				p_Info.isBulletDamage = true
				p_Info.position = Vec3(p_Soldier.worldTransform.trans.x, p_Soldier.worldTransform.trans.y + 1, p_Soldier.worldTransform.trans.z)
				p_Info.direction = p_Soldier.worldTransform.trans - bot.m_Player.soldier.worldTransform.trans
				p_Info.origin = bot.m_Player.soldier.worldTransform.trans
				if (p_Soldier.health - p_Info.damage) <= 0 then
					if Globals.IsTdm then
						local enemyTeam = TeamId.Team1
						if p_Soldier.player.teamId == TeamId.Team1 then
							enemyTeam = TeamId.Team2
						end
						TicketManager:SetTicketCount(enemyTeam, (TicketManager:GetTicketCount(enemyTeam) + 1))
					end
				end
			end
		else
			--valid bot-damage?
			local bot = self:getBotByName(p_GiverInfo.giver.name)
			if bot ~= nil and bot.m_Player.soldier ~= nil then
				-- giver was a bot
				p_Info.damage = self:_getDamageValue(p_Info.damage, bot, p_Soldier, false)
			end
		end
	end
	p_HookCtx:Pass(p_Soldier, p_Info, p_GiverInfo)
end

function BotManager:OnServerDamagePlayer(p_PlayerName, p_ShooterName, p_MeleeAttack)
	local player = PlayerManager:GetPlayerByName(p_PlayerName)
	if player ~= nil then
		self:OnDamagePlayer(player, p_ShooterName, p_MeleeAttack, false)
	end
end

function BotManager:OnDamagePlayer(p_Player, p_ShooterName, p_MeleeAttack, p_IsHeadShot)
	local bot = self:getBotByName(p_ShooterName)
	if not p_Player.alive or bot == nil then
		return
	end
	if p_Player.teamId == bot.m_Player.teamId then
		return
	end
	local damage = 1 --only trigger soldier-damage with this
	if p_IsHeadShot then
		damage = 2 -- singal Headshot
	elseif p_MeleeAttack then
		damage = 3 --signal melee damage with this value
	end
	--save potential killer bot
	self._shooterBots[p_Player.name] = p_ShooterName

	if p_Player.soldier ~= nil then
		p_Player.soldier.health = p_Player.soldier.health - damage
	end
end

function BotManager:OnShootAt(p_Player, p_BotName, p_IgnoreYaw)
	local bot = self:getBotByName(p_BotName)
	if bot == nil or bot.m_Player == nil or bot.m_Player.soldier == nil or p_Player == nil then
		return
	end
	bot:shootAt(p_Player, p_IgnoreYaw)
end

function BotManager:OnRevivePlayer(p_Player, p_BotName)
	local bot = self:getBotByName(p_BotName)
	if bot == nil or bot.m_Player == nil or bot.m_Player.soldier == nil or p_Player == nil then
		return
	end
	bot:revive(p_Player)
end

function BotManager:OnBotShootAtBot(p_Player, p_BotName1, p_BotName2)
	local bot1 = self:getBotByName(p_BotName1)
	local bot2 = self:getBotByName(p_BotName2)
	if bot1 == nil or bot1.m_Player == nil or  bot2 == nil or bot2.m_Player == nil then
		return
	end
	if bot1:shootAt(bot2.m_Player, false) or bot2:shootAt(bot1.m_Player, false) then
		self._botCheckState[bot1.m_Player.name] = bot2.m_Player.name
		self._botCheckState[bot2.m_Player.name] = bot1.m_Player.name
	else
		self._botCheckState[bot1.m_Player.name] = nil
		self._botCheckState[bot2.m_Player.name] = nil
	end
end

function BotManager:OnLevelDestroy()
	m_Logger:Write("destroyLevel")

	self:resetAllBots()
	self._activePlayers = {}
	self._initDone = false
	--self:killAll() -- this crashes when the server ended. do it on levelstart instead
end

function BotManager:getBotByName(p_Name)
	return self._botsByName[p_Name]
end

function BotManager:createBot(p_Name, p_TeamId, p_SquadId)

	--m_Logger:Write('botsByTeam['..#self._botsByTeam[2]..'|'..#self._botsByTeam[3]..']')

	local bot = self:getBotByName(p_Name)
	if bot ~= nil then
		bot.m_Player.teamId = p_TeamId
		bot.m_Player.squadId = p_SquadId
		bot:resetVars()
		return bot
	end

	-- check for max-players
	local playerlimt = Globals.MaxPlayers
	if Config.KeepOneSlotForPlayers then
		playerlimt = playerlimt - 1
	end
	if playerlimt <=  PlayerManager:GetPlayerCount() then
		m_Logger:Write("playerlimit reached")
		return
	end

	-- Create a player for this bot.
	local botPlayer = PlayerManager:CreatePlayer(p_Name, p_TeamId, p_SquadId)
	if botPlayer == nil then
		m_Logger:Write("cant create more players on this team")
		return
	end

	-- Create input for this bot.
	local botInput = EntryInput()
	botInput.deltaTime = 1.0 / SharedUtils:GetTickrate()
	botInput.flags = EntryInputFlags.AuthoritativeAiming
	botPlayer.input = botInput

	bot = Bot(botPlayer)

	local teamLookup = bot.m_Player.teamId+1
	table.insert(self._bots, bot)
	self._botsByTeam[teamLookup] = self._botsByTeam[teamLookup] or {}
	table.insert(self._botsByTeam[teamLookup], bot)
	self._botsByName[p_Name] = bot
	self._botInputs[botPlayer.id] = botInput -- bot inputs are stored to prevent garbage collection
	return bot
end


function BotManager:spawnBot(p_Bot, p_Transform, p_Pose, p_SoldierBp, p_Kit, p_Unlocks)
	if p_Bot.m_Player.soldier ~= nil then
		p_Bot.m_Player.soldier:Kill()
	end

	p_Bot.m_Player:SelectUnlockAssets(p_Kit, p_Unlocks)
	local botSoldier = p_Bot.m_Player:CreateSoldier(p_SoldierBp, p_Transform)
	p_Bot.m_Player:SpawnSoldierAt(botSoldier, p_Transform, p_Pose)
	p_Bot.m_Player:AttachSoldier(botSoldier)

	return botSoldier
end

function BotManager:killPlayerBots(p_Player)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == p_Player then
			bot:resetVars()
			if bot.m_Player.alive then
				bot.m_Player.soldier:Kill()
			end
		end
	end
end

function BotManager:resetAllBots()
	for _, bot in pairs(self._bots) do
		bot:resetVars()
	end
end

function BotManager:killAll(p_Amount, p_TeamId)

	local botTable = self._bots
	if (p_TeamId ~= nil) then
		botTable = self._botsByTeam[p_TeamId+1]
	end

	p_Amount = p_Amount or #botTable

	for _, bot in pairs(botTable) do

		bot:kill()

		p_Amount = p_Amount - 1
		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:destroyAll(p_Amount, p_TeamId, p_Force)

	local botTable = self._bots
	if (p_TeamId ~= nil) then
		botTable = self._botsByTeam[p_TeamId+1]
	end

	p_Amount = p_Amount or #botTable

	for _, bot in pairs(botTable) do

		if (p_Force) then
			self:destroyBot(bot)
		else
			table.insert(self._botsToDestroy, bot.m_Name)
		end

		p_Amount = p_Amount - 1
		if p_Amount <= 0 then
			return
		end
	end
end

function BotManager:destroyDisabledBots()
	for _, bot in pairs(self._bots) do
		if bot:isInactive() then
			table.insert(self._botsToDestroy, bot.m_Name)
		end
	end
end

function BotManager:destroyPlayerBots(p_Player)
	for _, bot in pairs(self._bots) do
		if bot:getTargetPlayer() == p_Player then
			table.insert(self._botsToDestroy, bot.m_Name)
		end
	end
end

function BotManager:freshnTables()
	local newTeamsTable = {{},{},{},{},{}}
	local newBotTable = {}
	local newBotbyNameTable = {}

	for _,bot in pairs(self._bots) do
		if bot.m_Player ~= nil then
			table.insert(newBotTable, bot)
			table.insert(newTeamsTable[bot.m_Player.teamId + 1], bot)
			newBotbyNameTable[bot.m_Player.name] = bot
		end
	end

	self._bots = newBotTable
	self._botsByTeam = newTeamsTable
	self._botsByName = newBotbyNameTable
end

function BotManager:destroyBot(p_Bot)

	if (type(p_Bot) == 'string') then
		p_Bot = self._botsByName[p_Bot]
	end

	-- Bot was not found.
	if p_Bot == nil then
		return
	end

	-- Find index of this bot.
	local newTable = {}
	for i, checkBot in pairs(self._bots) do
		if p_Bot.m_Name ~= checkBot.m_Name then
			table.insert(newTable, checkBot)
		end
		checkBot:clearPlayer(p_Bot.m_Player)
	end
	self._bots = newTable


	local newTeamsTable = {}
	for i, checkBot in pairs(self._botsByTeam[p_Bot.m_Player.teamId + 1]) do
		if p_Bot.m_Name ~= checkBot.m_Name then
			table.insert(newTeamsTable, checkBot)
		end
	end
	self._botsByTeam[p_Bot.m_Player.teamId+1] = newTeamsTable
	self._botsByName[p_Bot.m_Name] = nil
	self._botInputs[p_Bot.m_Id] = nil

	p_Bot:destroy()
	p_Bot = nil
end

if g_BotManager == nil then
	g_BotManager = BotManager()
end

return g_BotManager
