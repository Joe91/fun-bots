---@class GamemodeManager
---@overload fun():GamemodeManager
GamemodeManager = class('GamemodeManager')

local firstPlayerJoined = false

function GamemodeManager:OnExtensionLoaded()
    --RCON:SendCommand('vars.gameModeCounter', {tostring(1000)})
end

function GamemodeManager:OnLevelLoaded()
    firstPlayerJoined = false
end

function GamemodeManager:TeamChange(p_Player, p_TeamId, p_SquadId)
    if (firstPlayerJoined == false) then
        local maxTickets = RCON:SendCommand('vars.gameModeCounter')
        maxTickets = maxTickets[2]
        TicketManager:SetTicketCount(2, tonumber(maxTickets) - Config.PlayerLives)
        print("Team 1 tickets have been set to: " .. TicketManager:GetTicketCount(2))
        firstPlayerJoined = true
    end
    
end

function GamemodeManager:OnPlayedKilled(p_Player)
    --Should be a better way of doing this but I'm lazy :)
    --Prevents the human team from getting too many tickets
    if(p_Player.teamId == 2) then
        TicketManager:SetTicketCount(1, 0)
    end
end

function GamemodeManager:HumanTeamWin()
    TicketManager:SetTicketCount(1, 1000)
end

if g_GamemodeManager == nil then
	---@type GamemodeManager
	g_GamemodeManager = GamemodeManager()
end

return g_GamemodeManager